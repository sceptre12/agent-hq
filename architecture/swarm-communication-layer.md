# swarm-communication-layer — bus design record (ADR 0011)

One-line summary: a per-session Node.js MCP server acting as a pub/sub message bus for
multi-agent swarms — agents call 5 tools over HTTP instead of coordinating through files.

## What This Is

Agents communicate through structured MCP tool calls instead of shared files, enabling
real-time coordination, escalation, and orchestrator-to-worker signaling during swarm
execution. Each chat session runs its own isolated server instance with its own DB file
and port — sessions never share message state (libSQL allows one writer per file, so a
shared server would serialize all concurrent reviews through one process).

## Components

- **`src/server.js`** (entry — `package.json` `main`, verified) — creates the raw
  `node:http` server, mounts `GET /health` and `POST /mcp`, resolves the port via
  `get-port`, writes `$DATA_DIR/port`, registers all 5 tools per-request via
  `createMcpServer()` (a fresh `McpServer` instance every call — a **module-level
  singleton throws "Already connected" on the second request**, mcp-api.md, confirmed by
  the per-request factory at server.js:34-96), and handles `SIGTERM` drain/shutdown.
- **`src/db.js`** — `connect()` via `@tursodatabase/database` (better-sqlite3-style API,
  bare absolute path, no `file:` prefix), `execute()` abstraction (reads return
  `{rows}`, writes return `{changes}` or `null` when buffered to fallback),
  `initSchema()` (runs `schema.sql` + an idempotent-guarded `ALTER TABLE` for
  `session_id` every startup), and a reconnect-poll loop that triggers fallback sync.
- **`schema.sql`** — `messages` (content-only, no status column), `message_receipts`
  (sole delivery-status authority, PK `(message_id, agent_id)`), `sessions`. 4 indexes.
  The `session_id` column/index is deliberately *not* in the DDL file (not idempotent in
  libSQL) — it's applied by `db.js:initSchema()` inside a try/catch that swallows
  "duplicate column name" (schema.sql:35-38, db.js:89-97).
- **`src/fallback.js`** — p-queue (concurrency 1) serializes NDJSON `appendFile` when
  Turso is unreachable; sync-on-reconnect batches `FALLBACK_SYNC_BATCH_SIZE` records with
  3x exponential-backoff retry per batch; malformed records route to
  `fallback.ndjson.error` (dead letter); full success truncates the buffer.
- **`src/health.js`** — `GET /health` → `{status: ok|degraded, turso, fallback_active,
  uptime_seconds, log_file}`. `degraded` = fallback active.
- **`src/logger.js`** — pino; `pino/file` transport in production, pretty stdout
  otherwise. Fixed shape `{timestamp, level, service: "swarm-mcp", event, msg, data}`.
- **`src/errors.js`** — `ERROR_CODES` (10, frozen object) + `makeError()`. Tools never
  throw; every tool returns `{error: {code, message, data?}}` on failure.
- **The 5 MCP tools** (`src/tools/*.js`, one-line contracts, verified against source —
  not the stale mcp-api.md signatures, see Discrepancies):
  - `send_message({to, from_agent, content, topic?='direct', session_id?})` →
    `{id, timestamp, status: 'sent'|'queued'}` — Turso write, NDJSON fallback on failure.
  - `read_messages({agent_id, topics?, since?, limit?<=200, peek?=false, session_id?})` →
    `{messages: [...]}` — direct query anti-joins `message_receipts` (unread only,
    fixed 2026-05-13, see Findings below); broadcast fan-out lazily creates receipts on
    first read; `peek: true` skips the receipt insert/update transaction entirely.
  - `broadcast({from_agent, topic, content, session_id?})` → `{id, timestamp, topic,
    status}` — `to_agent = NULL`; no recipient list at write time.
  - `start_session({session_id})` → `{session_id, created_at}` — **`session_id` is a
    required, caller-supplied string** (not server-generated); idempotent via
    `INSERT ... ON CONFLICT(id) DO NOTHING`.
  - `end_session({session_id})` → `{session_id, deleted_messages}` — deletes
    `message_receipts` → `messages` → `sessions` row in FK order; fetches message IDs
    first and deletes per-ID inside a transaction (libSQL cannot do
    `DELETE ... WHERE id IN (SELECT ...)`, see Constraints).

## Interfaces

- **HTTP MCP endpoint**: `POST /mcp` uses `StreamableHTTPServerTransport`
  (stateless, `sessionIdGenerator: undefined`) — **not** plain JSON-RPC. Every POST must
  send `Accept: application/json, text/event-stream` or the server returns
  `406 Not Acceptable` and the message is silently dropped (curl exits 0, no error
  thrown). `GET /health` is plain REST, no `Accept` header needed.
- **`GET /health` identity contract** (fixed @40fd1d6, see discrepancy #8): payload now
  includes `app_name`, `data_dir` (absolute path), and `pid` alongside `status`, `turso`,
  `fallback_active`, `uptime_seconds`, `log_file` — a caller can confirm `/health` is
  answering for *its own* configured instance, not one that merely happens to be first to
  respond on a shared port.
- **`GET /health` `db_ok` field** (added @59e9ed8, durability pass 1): a cheap `SELECT 1`
  run at request time, never throwing — `false` on no client yet, a dropped connection,
  or a query error. `status` now flips to `degraded` on **either** of two independent
  triggers: `fallback_active` (unchanged) **or** `db_ok: false` (new) — there is no third
  status string, `status` is still only `ok`/`degraded`, but `degraded` now has two
  distinct causes a caller must not conflate. Callers should treat anything other than
  `status: ok` **and** `db_ok: true` (when the field is present) as not-ready.
- **Port discovery**: server resolves the port via `get-port` (`reserve: true`, mandatory
  — prevents a same-port race between two servers starting within the reservation
  window) from `PORT_RANGE_START`-`PORT_RANGE_END` (default 7777-7800, 24 slots), writes
  it to `$DATA_DIR/port` *before* signaling pm2 `ready`. Agents read this file — a port is
  never hardcoded client-side.
- **Env config surface** (`.env.example` / `config.js`, all optional, all defaulted):
  `DATA_DIR` (./data), `APP_NAME` (swarm-mcp), `TURSO_DATABASE_URL` ($DATA_DIR/swarm.db),
  `PORT_HINT`/`PORT_RANGE_START` (7777, `PORT` accepted as a legacy alias),
  `PORT_RANGE_END` (7800), `FALLBACK_FILE_PATH`, `LOG_FILE_PATH`, `NODE_ENV`
  (development), `RECONNECT_POLL_INTERVAL` (5000ms), `FALLBACK_SYNC_BATCH_SIZE` (50).
  `DATA_DIR` is the single source of truth for per-session isolation.

## Constraints and verified code facts

- Entry point is `src/server.js` (`package.json:6` `"main": "src/server.js"` — the
  ADR 0010 known gap, bus source missing from the transfer, is closed).
- **Bind is hardcoded to loopback**: `server.js:228`
  `httpServer.listen(resolvedPort, '127.0.0.1', (err) => {...})`. Request URLs are also
  built against localhost: `server.js:123`
  `const url = new URL(req.url, \`http://localhost:${resolvedPort}\`);`. Both verified by
  direct read of the shipped file (259 lines total).
- **PM2 process model** (`ecosystem.config.cjs`, 19 lines, `.cjs` because pm2 loads via
  `require()`): `instances: 1` (mandatory — multiple instances would produce independent
  fallback buffers and duplicate sync), `wait_ready: true` + `kill_timeout: 5000` (must
  match the server's own 5s graceful-drain timeout), `APP_NAME`/`DATA_DIR` read from env
  with `./data`/`swarm-mcp` fallbacks — no per-session values hardcoded in the file
  itself.
- **libSQL quirks**, all three confirmed live in shipped code (not just documented):
  `INSERT OR IGNORE` is rejected at runtime → every insert uses
  `INSERT ... ON CONFLICT(...) DO NOTHING` (`read_messages.js:89`, `start_session.js:26`);
  `ALTER TABLE ADD COLUMN` isn't idempotent → `db.js:90-94` wraps it in try/catch
  swallowing "duplicate column name"; `DELETE ... WHERE id IN (SELECT ...)` isn't
  supported → `end_session.js:38-59` fetches message IDs via SELECT first, then deletes
  `message_receipts`/`messages` per-ID inside a transaction.
- **MCP SDK footgun** (`decisions/mcp-sdk-three-arg-footgun.md`): all 5 tools register
  via `server.registerTool(name, {description, inputSchema: z.object({}).passthrough()},
  handler)` — confirmed at server.js:44-93. The 3-arg `server.tool()` form silently
  delivers request metadata instead of tool args and is banned.
- **Test layout**: `node:test` (built-in runner), no test framework dependency.
  `test/tools/read_messages.test.js` (66 lines), `test/tools/session_lifecycle.test.js`
  (85 lines), `test/helpers/db.js` (40 lines, in-memory `:memory:` DB + schema seed).
  Tests exercise SQL query logic directly against a real in-memory DB, not the HTTP
  handler layer — no integration/HTTP-level test exists in the transfer.

## Session/message lifecycle

Per `docs/superpowers/plans/2026-05-13-bug-fixes-and-session-lifecycle.md`, verified
against `tools/*.js`:

```
start_session({session_id}) → {session_id, created_at}
  ↓ orchestrator passes session_id to every agent brief
send_message / broadcast (session_id optional, tags the message)
  ↓ agents poll read_messages({agent_id, session_id?, peek?})
end_session({session_id}) → {session_id, deleted_messages}
  deletes message_receipts → messages → sessions, per-ID (libSQL quirk 3)
```

`session_id` on `messages` is nullable — untagged/legacy messages are never touched by
`end_session`. Session tagging is voluntary, not enforced server-side (no FK validation
that a `session_id` on a message actually exists in `sessions` — open question, not yet
resolved, per `shared/open-questions.md`).

## Known issues from FINDINGS.md — status against current code

- **Issue 1 (direct messages re-delivered on every poll)** — **fixed**. The anti-join
  (`LEFT JOIN message_receipts ... WHERE mr.message_id IS NULL`) is present in the
  shipped direct-message query (`read_messages.js:29-32`), matching the broadcast path.
- **Issue 4 (no peek/non-consuming read)** — **fixed**. `peek: boolean` (default false)
  is present and skips the receipt-write transaction (`read_messages.js:84-107`).
- **Issue 5 (unbounded message accumulation)** — **still true**. No TTL field, no expiry
  column, no cleanup job. Confirmed absent from `schema.sql` and `src/config.js` (49
  lines — no retention config of any kind).
- **Issues 2 & 3 (O-MEMORY 30s poll interval; no gate-request handshake)** — out of scope
  for this codebase: both are consumer/orchestrator-side application behavior, not
  server code. Nothing to fix here.

## SETTLED DECISIONS (ratified this session — record, do not reopen)

- Deploys as a **sibling repo** `~/projects/agent-hq/tools/swarm-communication-layer` — code never
  lives in hq (ADR 0010).
- Bind host becomes **env-driven `BIND_HOST`**, defaulting `127.0.0.1` — a one-line
  `server.js` change (swap the literal at line 228) plus a `config.js` entry.
  Container reachability is deferred to the container-lane design (ADR 0008
  constraints — no host `~/.claude` mount, lines 22/53); host-gateway DNS +
  `DATA_DIR` mount or a `BUS_URL` override are listed as future wiring, not built now.
- MCP registration is **project-scoped only** (ADR 0004 freeze) — the frozen
  user-scope MCP list is untouched.
- Work-machine paths get **localized at port time** (D1, see dispatch plan).

## Discrepancies found (doc vs. code — code wins)

1. **`start_session`/`end_session` signatures in `shared/mcp-api.md` are stale.**
   mcp-api.md documents `start_session({from_agent, label?}) → {session_id, started_at}`
   and `end_session({from_agent, session_id}) → {deleted_messages, deleted_receipts}`.
   The shipped code (`src/tools/start_session.js`, `src/tools/end_session.js`) takes
   `session_id` as a **required, caller-supplied** string on both tools, no `from_agent`
   param on either, and returns `{session_id, created_at}` /
   `{session_id, deleted_messages}` — no `started_at`, no `deleted_receipts` count.
   `shared/architecture.md`'s own lifecycle diagram (`start_session() → {session_id}`)
   is also ambiguous/wrong in the same direction (implies server-generated ID). This
   record's tool contracts above use the verified code shape.
2. **`ERROR_CODES` count**: mcp-api.md's Error Codes list has 9 entries and omits
   `SESSION_NOT_FOUND` entirely (predates the 2026-05-13 addendum). The 2026-05-13 plan
   doc's Task 2 additionally specifies adding `SESSION_ALREADY_EXISTS`. The shipped
   `src/errors.js` (34 lines) has **10** codes: the original 9 plus `SESSION_NOT_FOUND`
   only — `SESSION_ALREADY_EXISTS` was never added (start_session's idempotent
   `ON CONFLICT DO NOTHING` path never needs it).
3. **`end_session.js`'s literal delete pattern differs from the plan doc's Task 6 code
   snippet**, which shows `DELETE FROM message_receipts WHERE message_id IN (SELECT id
   FROM messages WHERE session_id = ?)`. Real libSQL rejects IN-subqueries (confirmed by
   `decisions/learnings-01-libsql-quirks-and-session-protocol.md` §1.3 and
   `shared/conventions.md`); the shipped code instead SELECTs message IDs first and
   deletes per-ID in a transaction. The plan doc's snippet was superseded; the learnings
   doc and shipped code agree with each other and are what this record follows.
4. **Receipt/session inserts use `ON CONFLICT(...) DO NOTHING`, not the plan doc's
   literal `INSERT OR IGNORE`** shown in its Task 3/5 code snippets — libSQL rejects
   `INSERT OR IGNORE` at runtime (same learnings doc, §1.1). Same pattern as #3: plan
   doc snippet stale, shipped code and learnings doc correct.
5. **The settled decision's premise that a work-machine nvm path lives "in
   `ecosystem.config.cjs`" doesn't hold against the file itself.** The tracked
   `ecosystem.config.cjs` (19 lines) has no nvm path and no `/Users/...` reference — it
   reads `APP_NAME`/`DATA_DIR` from env with generic fallbacks. The nvm PM2 binary path
   and the `<work-user home>/projects/swarm-communication-layer` working directory
   actually appear in `shared/operations.md`'s example startup shell script. D1's
   path-localization pass should target that doc's examples (and any other `shared/*.md`
   file carrying the same path), not `ecosystem.config.cjs`.

6. **Session scoping is explicit, not ambient (found live by D5, 2026-07-04).**
   `start_session` does NOT make later `send_message`/`broadcast` calls inherit the
   session — `session_id` must be passed explicitly on every call (`src/tools/
   send_message.js`, `broadcast.js`) or the rows are untagged and `end_session`
   deletes nothing. Any consumer assuming implicit scoping silently leaks rows.
7. **`/health`'s advertised `log_file` path does not exist under PM2 (D5, live).**
   Logging is captured by PM2 (`data/logs/pm2-out-0.log`), not the path the health
   payload reports. Read PM2 logs, not the advertised file.
8. **Cluster-mode port sharing let concurrent instances silently share one port (found
   live, wave-2; fixed @40fd1d6).** Root cause: pm2 cluster `exec_mode` + Node cluster's
   OS-level port-sharing meant multiple server processes could all bind the same port;
   `get-port`'s reservation was process-local (TOCTOU race across processes), and
   `listen()`'s error callback never fired to surface the collision. Fix: `server.js`
   now binds with `exclusive: true` and walks the configured port range on `EADDRINUSE`
   until it finds a truly free one — concurrent instances land on distinct ports. `/health`
   now also reports `app_name`/`data_dir`/`pid` (see Interfaces) so callers can verify they
   own the instance they think they do, not just that *some* instance answered.
9. **`pm2 reload` crash-loops this app; `pm2 restart` is the only safe verb (found live,
   wave-2; still open in the bus repo).** `reload` starts the new worker before killing
   the old one so both hold the same SQLite file open at once, producing a locking error
   crash-loop. `restart` (stop-then-start) never overlaps workers. No code fix shipped
   yet — this is a usage-only workaround; skills invoking recovery must use `restart`.

## 2026-07-05 — durability hardening pass 1 (bus repo @59e9ed8)

Explicit `PRAGMA journal_mode=WAL` + 5000ms `busy_timeout` at connect; PM2 crash-loop
containment (`max_restarts`/`min_uptime`/backoff, after #8's 17x-restart incident);
fail-loud DB open (`process.exit(1)` + one structured diagnostic, no retry); `db_ok` on
`/health` (see Interfaces); 7-day orphan-session sweep at startup. Also confirmed live:
the engine enforces cross-process DB file exclusivity — a second process cannot open
the same file while the server holds it, so an accidental double-server on one
`DATA_DIR` fails loudly. Remaining durability tiers deferred until observed need.

Lineage: X-context-docs custom-projects/swarm-communication-layer@87ed5a6
