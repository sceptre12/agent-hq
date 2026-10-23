# Conventions — swarm-communication-layer

Curated 2026-05-02.

---

## Module Format

All source files are ESM (`"type": "module"` in package.json). No CommonJS — the sole exception is `ecosystem.config.cjs` which uses `.cjs` explicitly because pm2 loads it via `require()`.

---

## Database Client

Package: `@tursodatabase/database`
API style: better-sqlite3 style — not the cloud `@libsql/client` pattern.

```js
// Correct
import { connect } from '@tursodatabase/database';
const db = await connect('/absolute/path/to/swarm.db'); // bare absolute path, no file: prefix
const rows = await db.prepare('SELECT ...').all(...args);
const result = await db.prepare('INSERT ...').run(...args);
await db.exec(multiStatementSql); // for DDL / schema init
const txn = db.transaction(fn); await txn(); // for transactions
```

`config.js` is responsible for stripping any `file:` prefix and resolving relative paths to absolute before the URL is passed to `connect()`.

---

## ENV Vars

All configuration comes through ENV vars. No hardcoded paths, ports, or connection strings anywhere in source. The `.env.example` file is the canonical list of all vars with their defaults.

All have defaults (no required vars — `config.js` provides safe defaults for everything):
- `DATA_DIR` → `./data` (scopes all session data; set per session for isolated bus)
- `APP_NAME` → `swarm-mcp` (pm2 instance name; set per session for multi-instance)
- `TURSO_DATABASE_URL` → `$DATA_DIR/swarm.db`
- `PORT_HINT` → `7777` (preferred start of get-port range; `PORT` accepted as legacy alias for `PORT_RANGE_START`)
- `PORT_RANGE_START` → `7777`
- `PORT_RANGE_END` → `7800` (24 slots — supports up to 24 concurrent sessions on one machine)
- `FALLBACK_FILE_PATH` → `$DATA_DIR/fallback.ndjson`
- `LOG_FILE_PATH` → `$DATA_DIR/logs/server.log`
- `NODE_ENV` → `development`
- `RECONNECT_POLL_INTERVAL` → `5000`
- `FALLBACK_SYNC_BATCH_SIZE` → `50`

---

## Error Handling

Tools never throw. All errors are returned as structured objects via `makeError()`:
```js
return makeError(ERROR_CODES.DB_WRITE_FAILED, 'human-readable message', optionalData);
// returns: { error: { code, message, data } }
```

`ERROR_CODES` lives in `src/errors.js` and is the single source of truth for all error codes.

---

## Logging

All log events use pino with this shape:
```json
{ "level": "info", "time": "...", "service": "swarm-mcp", "event": "<event-type>", "msg": "...", "data": {} }
```

`event` is always one of the taxonomy values defined in `architecture.md`. Never log freeform strings as the `event` field.

---

## Signal Files

Signal files used for inter-agent and inter-phase coordination:
- Path: `signals/<agent-id>.complete`
- Content: `ready`
- Written as the **very last step** — after the output file is fully written and closed
- Orchestrators gate on file content, not file existence alone

---

## pm2

Single instance only (`instances: 1`, `exec_mode: 'fork'` in `ecosystem.config.cjs`). This is non-negotiable — multiple instances (or cluster mode, which briefly overlaps old/new workers) produce independent fallback file buffers and concurrent SQLite writers, causing duplicate message sync and `Locking error: Failed locking file` on `data/swarm.db`.

Restart commands:
- `pm2 restart $APP_NAME` — use for all restarts (normal ops and recovery)
- Never `pm2 reload $APP_NAME` — reload's zero-downtime overlap runs old+new workers simultaneously against the same SQLite file and will crash-loop.

---

## SQL Conventions

**Never use correlated subqueries in `WHERE ... IN (SELECT ...)`.**  libSQL (Turso's embedded SQLite variant) does not support this pattern. The query will fail at runtime — it works in standard SQLite but not in Turso.

Always use a `LEFT JOIN ... IS NULL` anti-join instead:

```sql
-- Wrong (fails in libSQL)
WHERE id NOT IN (SELECT message_id FROM message_receipts WHERE agent_id = ?)

-- Correct
FROM messages m
LEFT JOIN message_receipts r
  ON m.id = r.message_id AND r.agent_id = ?
WHERE ...
  AND r.message_id IS NULL
```

This applies to any query that checks for the absence of a related row. It applies to **both** the direct (point-to-point) path and the broadcast fan-out path — when the anti-join was added to broadcast but not direct, direct queries returned all past messages on every poll.

---

## libSQL Quirks

Three SQL patterns that work in standard SQLite but fail in libSQL (Turso):

**1. `INSERT OR IGNORE` is not valid.**
Use `INSERT INTO ... ON CONFLICT(...) DO NOTHING` instead:
```sql
-- Wrong (libSQL rejects this syntax)
INSERT OR IGNORE INTO messages (...) VALUES (...);

-- Correct
INSERT INTO messages (...) VALUES (...) ON CONFLICT(id) DO NOTHING;
```

**2. `ALTER TABLE ADD COLUMN` is not idempotent.**
libSQL throws if the column already exists. Wrap in try/catch:
```js
try {
  await db.exec('ALTER TABLE messages ADD COLUMN session_id TEXT');
} catch (err) {
  if (!err.message.includes('duplicate column name')) throw err;
}
```

**3. `DELETE ... WHERE id IN (SELECT ...)` is not supported.**
libSQL does not support DELETE with a subquery in the IN clause. Workaround: SELECT the IDs first, then delete per-ID inside a transaction:
```js
const rows = await db.prepare('SELECT id FROM messages WHERE session_id = ?').all(sessionId);
const txn = db.transaction(() => {
  for (const row of rows) {
    db.prepare('DELETE FROM messages WHERE id = ?').run(row.id);
  }
});
await txn();
```

---

## MCP SDK Pitfalls

### Three-Argument `server.tool()` — Wrong Arguments Delivered to Handler

**Never call `server.tool(name, description, handler)` (three-argument form).**

In MCP SDK v1.29+, omitting the `inputSchema` parameter causes the SDK to pass the `extra` request metadata object as the first argument to the handler instead of the tool's input arguments. All tool calls silently return wrong or empty results — no error is thrown and the tool appears to register successfully.

```js
// Wrong — handler receives extra metadata, not tool arguments
server.tool('send_message', 'Send a message', async (args) => {
  // args is actually the MCP request "extra" object, not input args
});

// Correct — always provide inputSchema; use passthrough() to accept any object
import { z } from 'zod';
server.registerTool(
  'send_message',
  { description: 'Send a message', inputSchema: z.object({}).passthrough() },
  async (args) => {
    // args is now the actual tool input object
  }
);
```

Use `z.object({}).passthrough()` as the `inputSchema` to accept any object without stripping keys. Each handler validates its own specific args internally. This footgun was discovered in session pid-37584 (Bug 2) — see `decisions/mcp-sdk-three-arg-footgun.md`.

---

## Port Selection

Ports are resolved dynamically via `get-port` from the range `PORT_RANGE_START`–`PORT_RANGE_END` (default `7777`–`7800`). The resolved port is written to `$DATA_DIR/port`. Agents always read the port file — never hardcode a port number. See [port-discovery.md](port-discovery.md).

Avoid these ports as defaults on macOS:

| Port | Reason |
|------|--------|
| 7000 | macOS AirPlay Receiver — always occupied, returns 403 |
| 3000 | Common Node dev default — frequently occupied |
| 5000 | Frequently occupied by macOS ControlCenter |
