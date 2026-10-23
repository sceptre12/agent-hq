# Addendum 01a — Bug Fixes & Session Lifecycle Design

> Authored 2026-05-13. Addresses FINDINGS.md issues 1–5 from the FOUND-1194
> dispatch-v2 incident, plus session pruning (new feature).
> Continues in [addendum-01b](addendum-01b-skill-changes.md).

---

## 1. Bug Fixes

### 1.1 Direct messages re-deliver on every poll (FINDINGS Issue 1)

**Problem:** The direct SELECT in `src/tools/read_messages.js` (lines 49–57)
has no receipt anti-join. Every poll returns all messages ever sent to the
agent. Broadcast query correctly filters via `message_receipts`; direct does
not. Caused duplicate message processing in the incident.

**Fix:** Add LEFT JOIN anti-join to the direct query, mirroring broadcast:

```sql
SELECT m.id, m.from_agent, m.to_agent, m.content, m.topic, m.timestamp
FROM messages m
LEFT JOIN message_receipts mr
       ON m.id = mr.message_id AND mr.agent_id = ?
WHERE  m.to_agent = ?
  AND  mr.message_id IS NULL
```

After this fix, direct and broadcast queries are semantically consistent:
only rows with no existing receipt for the requesting agent are returned.

---

### 1.2 Add `peek` parameter to `read_messages` (FINDINGS Issue 4)

**Problem:** `read_messages` always writes delivery receipts. Bootstrap agents
and diagnostic tooling that inspect inboxes inadvertently consume messages,
causing agents to miss them on their next poll.

**Fix:** Add optional `peek: boolean` (default `false`) to `read_messages`.
When `peek: true`, the `INSERT OR IGNORE INTO message_receipts` transaction
block is skipped entirely. SELECT queries are unchanged — only the write step
is conditional.

Updated tool signature:
```typescript
read_messages({
  agent_id:   string     // required
  topics?:    string[]
  since?:     string
  limit?:     number     // default 50, max 200
  peek?:      boolean    // default false — if true, no receipts are written
  session_id?: string    // optional — scope reads to a session (see §3)
})
```

---

## 2. Agent-Side Guidance (no server changes)

These are protocol fixes — no code changes required.

### 2.1 Poll interval during active swarm runs (FINDINGS Issue 2)

The bus has no server-push model. A 30s poll interval causes gate stalls of up
to 30s. **During active swarm runs, agents waiting on a response must poll at
2–5s intervals.** This applies to O-MEMORY and any orchestrator blocking on a
PROCEED/HOLD signal.

### 2.2 Gate handshake — tight poll loop (FINDINGS Issue 3)

After sending a gate request, orchestrators must not wait for the standard poll
cycle. **Enter a tight poll loop (2–3s) immediately after sending the gate
request and exit only when PROCEED or HOLD is received.**

Both items are captured in the Skill Changes Checklist (addendum-01b).

---

## 3. Session Lifecycle (new feature)

### 3.1 Motivation

When a new Claude process connects to the bus and calls `read_messages`, it
receives all unread messages from previous swarm runs. There is no isolation
between sessions. Sessions must own their own cleanup.

### 3.2 Schema Changes

**New table — `sessions`:**
```sql
CREATE TABLE IF NOT EXISTS sessions (
  id          TEXT PRIMARY KEY,
  created_at  TEXT NOT NULL,
  ended_at    TEXT             -- NULL until end_session is called
);
```

**New column on `messages` — `session_id`:**
```sql
ALTER TABLE messages ADD COLUMN session_id TEXT;
CREATE INDEX IF NOT EXISTS idx_messages_session_id ON messages(session_id);
```

`session_id` is **nullable** for backwards compatibility. Existing messages
without it are unaffected and will not be pruned by `end_session`.

`message_receipts` does **not** get a `session_id` column — session membership
is always derivable through the FK chain (`message_receipts.message_id →
messages.session_id`). `end_session` reaches receipts via that join.

---

### 3.3 New Tools

**`start_session`**
```typescript
start_session({
  session_id: string    // caller-defined, e.g. "run42" or a UUID
})
// Returns: { session_id: string, created_at: string }
// Idempotent — if session already exists, returns existing row unchanged.
```

**`end_session`**
```typescript
end_session({
  session_id: string
})
// Returns: { session_id: string, deleted_messages: number }
// Deletes (in order):
//   1. message_receipts WHERE message_id IN (SELECT id FROM messages WHERE session_id = ?)
//   2. messages WHERE session_id = ?
//   3. sessions WHERE id = ?
```

Deletion is ordered to respect the FK chain. If any step fails, the operation
logs the error and returns a structured error — partial cleanup is possible;
callers should retry.

---

### 3.4 Tool Call Changes (existing tools)

`send_message` and `broadcast` gain an optional `session_id` field. When
provided, written to `messages.session_id`. The server does not validate that
the session exists — agents tag their own messages.

Updated `send_message`:
```typescript
send_message({
  to:          string
  from_agent:  string
  content:     string
  topic?:      string      // defaults to "direct"
  session_id?: string      // optional session tag
})
```

Updated `broadcast`:
```typescript
broadcast({
  from_agent:  string
  topic:       string
  content:     string
  session_id?: string      // optional session tag
})
```

---

### 3.5 Session Lifecycle Protocol

Orchestrators are responsible for the full session lifecycle:

```
1. On swarm start: call start_session({ session_id: "<run-id>" })
2. Pass session_id in every agent brief — agents include it in all tool calls
3. On swarm end (success or failure): call end_session({ session_id: "<run-id>" })
```

`end_session` is the cleanup gate. It must be called even on failure. If the
orchestrator crashes before calling it, messages remain in the DB until a
future session or manual cleanup.

Recommended `session_id` format: `<swarm-name>-<YYYYMMDD>-<short-uuid>`
e.g. `foundations-wave3-20260513-a3f2`
