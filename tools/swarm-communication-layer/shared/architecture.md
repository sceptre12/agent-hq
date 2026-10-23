# Architecture — Swarm Communication Layer

> Curated 2026-05-02. Updated 2026-05-05 (port discovery, doc split).

---

## What This Is

A Node.js MCP server acting as a pub/sub message bus for multi-agent swarms. Agents communicate through structured tool calls instead of files, enabling real-time coordination, dynamic escalation, and orchestrator-to-worker signaling during swarm execution.

Each chat session runs its own isolated server instance with its own DB and port. Sessions do not share message state.

---

## Technology Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Runtime | Node.js ≥ 18 | Already on system |
| Module format | ESM (`"type": "module"`) | `@modelcontextprotocol/sdk` ≥1.0 ships ESM; p-queue v8 is ESM-only |
| Backing store | `@tursodatabase/database` | MVCC handles concurrent agent writes. better-sqlite3-style API — `connect(path)`, `db.prepare(sql).run(...args)`. Bare absolute path only — no `file:` prefix. |
| MCP server | `@modelcontextprotocol/sdk` HTTP/SSE | Stateless. Agents connect independently — stdio would require agents to manage server lifecycle |
| Tool validation | Zod | Standard MCP SDK companion |
| Logging | pino | NDJSON, `pino/file` in production, pretty in development |
| Process management | pm2 | Single instance per session, `wait_ready: true`, `APP_NAME` env for multi-instance naming |
| Fallback buffer | NDJSON file + p-queue v8 | Atomic writes; p-queue serializes concurrent `fs.appendFile` calls |
| Port selection | `get-port` | Resolves available port from preferred range; `reserve: true` prevents race at concurrent startup |

---

## Architecture Pattern

```
agent → MCP tool call → stateless MCP server → Turso DB ($DATA_DIR/swarm.db)
                                ↓ (if Turso down)
                   local fallback ($DATA_DIR/fallback.ndjson) → sync on reconnect
```

One pm2 instance per session. Multiple instances would produce independent fallback buffers causing duplicate sync. See [operations.md](operations.md) for pm2 config and multi-instance naming.

---

## Per-Session Process Isolation

Each swarm review session runs its own isolated server process. This is the required model — do NOT run a shared persistent server.

**Why:** The backing store is a local libSQL file (`$DATA_DIR/swarm.db`). libSQL allows only one writer per file. A single shared server would serialize all concurrent reviews through one process. Per-session processes give each review its own DB file, its own port, and true isolation.

**How it works:**
- Each session sets a unique `DATA_DIR` (e.g. `/tmp/swarm-<sessionId>`) and `APP_NAME` (e.g. `swarm-mcp-<sessionId>`)
- `ecosystem.config.cjs` reads both from env — no file changes needed
- `server.js` picks a free port from the 7777–7800 range via `get-port`, writes it to `$DATA_DIR/port`
- The session's agents read `$DATA_DIR/port` to connect — they never hardcode a port
- On teardown: `pm2 delete <APP_NAME>` + `rm -rf $DATA_DIR`

**Session ID format:** `swarm-<name>-<YYYYMMDD>-<shortUUID>` e.g. `swarm-pr-review-20260608-a3f2`

---

## ENV Layer

All configuration via ENV. No hardcoded paths, ports, or connection strings in source.

| Var | Default | Notes |
|-----|---------|-------|
| `DATA_DIR` | `./data` | Root for all session data — set per session for isolated bus. Default `./data` is for standalone/default sessions only. Per-session isolation requires an absolute path (e.g. `/tmp/swarm-<session-id>`). See Per-Session Process Isolation section. |
| `APP_NAME` | `swarm-mcp` | pm2 instance name — set per session for multi-instance |
| `TURSO_DATABASE_URL` | `$DATA_DIR/swarm.db` | Bare absolute path; config.js resolves relative paths and strips `file:` prefix |
| `PORT_HINT` | `7777` | Preferred port — `get-port` resolves final port from range. Not a binding declaration. |
| `PORT_RANGE_START` | `7777` | Start of get-port search range |
| `PORT_RANGE_END` | `7800` | End of range — 24 slots, supports up to 24 concurrent sessions on one machine |
| `FALLBACK_FILE_PATH` | `$DATA_DIR/fallback.ndjson` | |
| `LOG_FILE_PATH` | `$DATA_DIR/logs/server.log` | Isolated per session |
| `NODE_ENV` | `development` | `production` enables pino file transport |
| `RECONNECT_POLL_INTERVAL` | `5000` | ms between Turso reconnect probes |
| `FALLBACK_SYNC_BATCH_SIZE` | `50` | Messages per batch during sync |

`DATA_DIR` is the single source of truth for session isolation. Change it to run a second instance without touching any other config.

---

## File Structure

```
src/
  server.js        # Entry: MCP HTTP transport, tool registration, HTTP server, SIGTERM handler
  config.js        # ENV vars → validated config object; derives DATA_DIR-relative paths
  db.js            # Turso connect(), db.execute() abstraction, initSchema(), reconnect loop
  fallback.js      # p-queue write serializer, NDJSON append, sync-on-reconnect
  health.js        # GET /health handler
  logger.js        # pino instance
  errors.js        # ERROR_CODES enum, makeError() factory
  tools/
    send_message.js
    read_messages.js
    broadcast.js
schema.sql         # Idempotent DDL
ecosystem.config.cjs  # pm2 config (.cjs — pm2 uses require())
package.json       # "type": "module"
.env.example       # All ENV vars with defaults
```

---

## Doc Map

| Doc | Contents | Load when... |
|-----|----------|-------------|
| [schema.md](schema.md) | Tables, indexes, initialization, evolution policy | modifying DB or writing queries |
| [mcp-api.md](mcp-api.md) | Tool API, bus transport, error codes, client retry | making tool calls |
| [operations.md](operations.md) | Health check, logging, pm2, graceful shutdown, fallback sync, startup sequence | operating or implementing the server |
| [port-discovery.md](port-discovery.md) | get-port algorithm, DATA_DIR, port file contract, agent pre-flight, multi-instance | starting a server session or connecting to one |
| [swarm-dispatch.md](swarm-dispatch.md) | Pre-flight smoke test, heartbeat protocol, re-spawn template, permissions | orchestrating a multi-agent swarm |
| [conventions.md](conventions.md) | Module format, DB client API, ENV rules, error handling, logging, SQL patterns, port policy | implementing any part of the server |

---

## Session Lifecycle

Optional grouping mechanism for swarm runs. Orchestrators may create a session before dispatch and delete it on completion to prune messages from that run.

```
start_session() → { session_id }
  ↓
Pass session_id in send_message / broadcast calls
  ↓
end_session(session_id) → deletes receipts, messages, session row
```

Lifecycle ownership: the orchestrator calls `start_session` before dispatch and `end_session` on swarm completion (success or failure). Sub-agents receive `session_id` in their brief and include it in every tool call.

Deletion order for `end_session` (FK constraint): receipts first, then messages, then session row. libSQL quirk 3 applies — cannot use `DELETE WHERE id IN (SELECT ...)`. Implementation must fetch IDs then delete per-ID inside a transaction. See conventions.md for the pattern.

Messages without a `session_id` are never touched by `end_session`. Old/untagged messages are always preserved.

---

## Resolved Design Decisions

| Question | Decision |
|----------|----------|
| Agent identity | `from_agent` required param in every tool call |
| Broadcast delivery | Fan-out on read via `message_receipts` |
| Fallback write safety | p-queue v8 + NDJSON |
| Multiple server instances | One pm2 instance per session — isolated bus model |
| McpServer lifecycle | Per-request factory (`createMcpServer()`) — singleton throws "Already connected" |
| Port selection | `get-port` from range `PORT_RANGE_START`–`PORT_RANGE_END`; resolved port written to `$DATA_DIR/port` |
| Session isolation | `DATA_DIR` scopes all session data (DB, fallback, port file) |
| session_id on messages | Nullable — backward compat; old messages never pruned by end_session |
| Per-session vs shared server | Per-session pm2 — libSQL single-writer constraint; shared server serializes all concurrent reviews. Each session gets its own DATA_DIR, DB file, and port. |
