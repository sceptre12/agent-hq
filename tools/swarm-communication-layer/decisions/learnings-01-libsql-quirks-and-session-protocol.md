# Learnings 01 — libSQL Quirks & Session Protocol

> Authored 2026-05-13. Records three libSQL runtime limitations discovered
> during the session-lifecycle feature implementation, plus the anti-join fix
> and peek parameter. These apply to any future work touching `db.js` or
> adding new tools.

---

## 1. libSQL Limitations

These are runtime failures — libSQL accepts the query at parse time but throws
at execution. None appear in standard SQLite documentation.

---

### 1.1 `INSERT OR IGNORE` is not supported

**Symptom:** `INSERT OR IGNORE INTO t (...) VALUES (...)` throws at runtime.

**Fix:** Replace with the ANSI upsert form:
```sql
INSERT INTO t (...) VALUES (...)
ON CONFLICT(col) DO NOTHING
```

This applies everywhere a uniqueness conflict is expected and silent skipping
is the desired behavior (e.g. writing receipts, inserting sessions idempotently).

---

### 1.2 `ALTER TABLE ADD COLUMN` is not idempotent

**Symptom:** `ALTER TABLE t ADD COLUMN c TEXT` throws `"duplicate column name"`
if the column already exists. Unlike `CREATE TABLE IF NOT EXISTS`, there is no
`IF NOT EXISTS` qualifier for `ALTER TABLE` in libSQL.

**Fix:** Wrap in try/catch and re-throw only on unexpected errors:
```js
try {
  await db.execute(`ALTER TABLE messages ADD COLUMN session_id TEXT`);
} catch (err) {
  if (!err.message.includes('duplicate column name')) throw err;
}
```

Apply this pattern for any additive schema migration that may run on a DB
where the column already exists (e.g., on server restart after a partial init).

---

### 1.3 `DELETE ... WHERE id IN (SELECT ...)` is not supported

**Symptom:** `DELETE FROM t WHERE id IN (SELECT id FROM other WHERE ...)` throws
a libSQL error. Subqueries inside `WHERE ... IN (SELECT ...)` are not supported
— this applies to both SELECT and DELETE statements.

**Fix for SELECT:** Use `LEFT JOIN ... IS NULL` anti-join (see §2 below).

**Fix for DELETE:** Fetch the IDs first with a SELECT, then delete per-ID
inside a transaction:
```js
const rows = await db.execute(
  `SELECT id FROM messages WHERE session_id = ?`, [sessionId]
);
const ids = rows.rows.map(r => r.id);
await db.batch(ids.map(id =>
  ({ sql: `DELETE FROM message_receipts WHERE message_id = ?`, args: [id] })
));
await db.batch(ids.map(id =>
  ({ sql: `DELETE FROM messages WHERE id = ?`, args: [id] })
));
```

The batch approach keeps all deletes in a single round trip. For very large
sessions (thousands of messages) consider chunking the batch.

---

## 2. Anti-Join Pattern for Unread-Messages Queries

The `read_messages` tool must return only messages the requesting agent has
not yet received. The natural implementation uses a subquery:

```sql
-- THIS DOES NOT WORK IN libSQL:
WHERE id NOT IN (
  SELECT message_id FROM message_receipts WHERE agent_id = ?
)
```

The required pattern is a `LEFT JOIN` anti-join:

```sql
SELECT m.id, m.from_agent, m.to_agent, m.content, m.topic, m.timestamp
FROM messages m
LEFT JOIN message_receipts mr
       ON m.id = mr.message_id AND mr.agent_id = ?
WHERE  m.to_agent = ?
  AND  mr.message_id IS NULL
```

`LEFT JOIN` keeps all `messages` rows; rows with no matching receipt get
`NULL` on the receipt columns; `IS NULL` selects only those rows.

**Apply this to both query paths in `read_messages.js`:**
- Direct (point-to-point): `WHERE m.to_agent = ?`
- Broadcast (topic fan-out): `WHERE m.topic = ?`

Prior to the 2026-05-13 session, the direct path lacked this anti-join and
re-delivered all messages on every poll. The broadcast path was already
correct (fixed 2026-05-02). Both paths are now consistent.

---

## 3. Session Lifecycle Protocol

### 3.1 When to use sessions

Tag all messages with a `session_id` whenever work is part of an identifiable
swarm run. Untagged messages persist in the DB indefinitely. Tagged messages
can be cleaned up atomically with `end_session`.

### 3.2 Orchestrator responsibilities

```
1. Call start_session({ session_id: "<run-id>" }) before dispatching agents.
2. Pass session_id in every agent brief.
3. Every agent includes session_id in all send_message and broadcast calls.
4. Call end_session({ session_id: "<run-id>" }) when the swarm completes
   — whether success or failure.
```

`end_session` is the cleanup gate. Without it, messages remain in the DB and
will surface on the next session's `read_messages` poll.

### 3.3 Recommended session_id format
```
<swarm-name>-<YYYYMMDD>-<short-uuid>
e.g. foundations-wave3-20260513-a3f2
```

### 3.4 Deletion order inside end_session

Deletion must respect the FK chain:
1. `message_receipts` WHERE `message_id` IN messages for this session
2. `messages` WHERE `session_id = ?`
3. `sessions` WHERE `id = ?`

libSQL quirk 1.3 applies: fetch IDs first, then delete per-ID (see §1.3).

---

## 4. peek Parameter on read_messages

`peek: boolean` (default `false`) on `read_messages` — when `true`, the
receipt-insert step is skipped entirely. The SELECT query runs normally but
no `message_receipts` row is written.

**Use cases:**
- Bootstrap agents verifying bus health without consuming messages
- Diagnostic tooling inspecting inboxes mid-run
- Orchestrators sampling queue depth without side effects

**Not a default** — standard reads should always write receipts to prevent
duplicate delivery. Only use `peek: true` when inspection without consumption
is explicitly required.
