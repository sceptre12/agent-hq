# Operations — Swarm Communication Layer

> Updated 2026-06-08.

---

## Startup Sequence

```
1. Read ENV → validate; resolve DATA_DIR-relative paths; mkdirSync fallback + log dirs
2. Resolve port via get-port (PORT_HINT, range PORT_RANGE_START–PORT_RANGE_END, reserve: true)
3. Connect to Turso; run initSchema()
4. Start reconnection loop (db.js) — polls only when Turso fails
5. Register MCP tools
6. Start HTTP server on resolved port
7. Write resolved port to $DATA_DIR/port
8. if (process.send) process.send('ready')  — pm2 readiness signal (guard: undefined outside pm2)
9. Log server_start
```

Step 7 (port file write) must complete before step 8 (ready signal). Agents must not be dispatched until the port file exists.

---

## Per-Session Startup and Teardown

### Start a session server

```bash
PM2=$HOME/.nvm/versions/node/<version>/lib/node_modules/pm2/bin/pm2
# Portable alternative: PM2=$(npm root -g)/pm2/bin/pm2

SESSION_NAME="pr-review"  # replace with your swarm purpose slug
SESSION_UUID=$(uuidgen | tr '[:upper:]' '[:lower:]' | cut -c1-4)
SESSION_ID="swarm-${SESSION_NAME}-$(date +%Y%m%d)-${SESSION_UUID}"
export DATA_DIR="/tmp/${SESSION_ID}"
export APP_NAME="swarm-mcp-${SESSION_ID}"

mkdir -p "${DATA_DIR}/logs"

cd ~/projects/agent-hq/tools/swarm-communication-layer
DATA_DIR="${DATA_DIR}" APP_NAME="${APP_NAME}" NODE_ENV=production \
  $PM2 start ecosystem.config.cjs  # NODE_ENV=production enables pino file transport (logs to $DATA_DIR/logs/)

# Poll until port file is written (server signals ready via process.send('ready'))
TRIES=0
until [ -f "${DATA_DIR}/port" ] || [ $TRIES -ge 30 ]; do
  sleep 0.3
  TRIES=$((TRIES + 1))
done
[ -f "${DATA_DIR}/port" ] || { echo "ERROR: server did not start within 9s"; exit 1; }

PORT=$(cat "${DATA_DIR}/port")
curl -s http://localhost:${PORT}/health
```

Expected health response: `{ "status": "ok", "turso": "connected" }`

### Agents connect

Every agent reads the port file for its session:
```bash
PORT=$(cat $DATA_DIR/port)
# Then call: http://localhost:$PORT/mcp
```

`DATA_DIR` must be passed to every agent brief. Agents never hardcode a port.

### Tear down a session server

```bash
# end_session is optional for per-session servers — rm -rf destroys the DB.
# Call it for explicit MCP-layer cleanup if the session is still active.
$PM2 delete "${APP_NAME}"
rm -rf "${DATA_DIR}"
```

Call `end_session` via the MCP tool before tearing down to confirm message cleanup. Then delete the pm2 process and remove the data directory.

---

## Health Check

```
GET /health
```
```json
{
  "status": "ok | degraded",
  "turso": "connected | disconnected",
  "fallback_active": boolean,
  "uptime_seconds": number,
  "log_file": string
}
```

`degraded` = server running, Turso unreachable, fallback active.

---

## pm2 Configuration

```javascript
// ecosystem.config.cjs — .cjs required (pm2 uses require())
const dataDir = process.env.DATA_DIR || './data';
module.exports = {
  apps: [{
    name: process.env.APP_NAME || 'swarm-mcp',
    script: './src/server.js',
    exec_mode: 'fork',       // SQLite single-writer — never cluster, never pm2 reload (use restart)
    instances: 1,            // mandatory — see architecture.md
    autorestart: true,
    watch: false,
    max_memory_restart: '200M',
    kill_timeout: 5000,      // must match graceful shutdown drain timeout
    wait_ready: true,
    error_file: `${dataDir}/logs/pm2-error.log`,
    out_file: `${dataDir}/logs/pm2-out.log`,
    log_date_format: 'YYYY-MM-DD HH:mm:ss Z'
  }]
}
```

> Note: `wait_ready: true` in ecosystem.config.cjs is pm2's internal health tracking. It does not block the shell — use the poll loop above to wait for the port file from a script.

For multiple sessions, set `APP_NAME` and `DATA_DIR` per session before starting:
```bash
APP_NAME=swarm-mcp-session2 DATA_DIR=./data-session2 $PM2 start ecosystem.config.cjs
```

Restart commands:
- `pm2 restart $APP_NAME` — use for all restarts (normal ops and recovery)
- Never `pm2 reload $APP_NAME` — SQLite single-writer: reload's zero-downtime overlap runs old+new workers simultaneously against the same file and will crash-loop (`Locking error: Failed locking file`).

---

## Graceful Shutdown (SIGTERM)

```
1. Stop accepting new connections
2. Drain in-flight tool calls (5s timeout)
3. Flush fallback write queue (sync to Turso deferred to next startup if unreachable)
4. Close Turso connection
5. Flush log
6. process.exit(0)
```

---

## Fallback Sync Protocol

Triggered by reconnection loop (db.js) when Turso becomes reachable:

```
1. Set fallback_draining = true — reject new fallback writes
2. Drain p-queue: wait for queue.size === 0 && queue.pending === 0
3. Read fallback file line-by-line (NDJSON)
4. Batch into groups of FALLBACK_SYNC_BATCH_SIZE (default 50)
5. Per batch: INSERT INTO messages (...) VALUES (...) ON CONFLICT(id) DO NOTHING (idempotent — UUID prevents duplicates)
6. Batch failure: retry 3x with exponential backoff
   - Still failing: log fallback_sync_error, leave file intact, abort (retry next reconnect)
   - Malformed record: move to $DATA_DIR/fallback.ndjson.error (dead letter), continue
7. Full success: truncate fallback file to 0 bytes
8. Set fallback_active = false, log fallback_deactivated
```

NDJSON format (one line per message, maps directly to `messages` row):
```json
{"id":"<uuid>","topic":"<topic>","from_agent":"<id>","to_agent":"<id|null>","content":"<text>","timestamp":"<ISO 8601 UTC>"}
```

---

## Structured Logging (pino)

```json
{
  "timestamp": "ISO 8601",
  "level": "info|warn|error",
  "service": "swarm-mcp",
  "event": "<event-type>",
  "msg": "human-readable summary",
  "data": {}
}
```

Required lifecycle events: `server_start`, `turso_connected`, `turso_disconnected`, `fallback_activated`, `fallback_deactivated`, `fallback_sync_start`, `fallback_sync_complete`, `fallback_sync_error`, `message_sent`, `message_read`, `broadcast_sent`, `health_check` (debug), `server_shutdown`.
