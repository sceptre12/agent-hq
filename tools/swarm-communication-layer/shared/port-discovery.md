# Port Discovery — Swarm Communication Layer

Addendum 2026-05-05. Supersedes the hardcoded `7777` default in earlier docs.

---

## Problem

Multiple chat sessions each running their own isolated server instance need ports that don't conflict. A hardcoded default fails silently when the port is occupied.

---

## Solution: get-port + DATA_DIR/port file

At startup, the server resolves its port dynamically and writes it to `$DATA_DIR/port`. Agents read this file — they never hardcode a port number.

---

## Server Behaviour

```js
import getPort, { portNumbers } from 'get-port';

const port = await getPort({
  port: portNumbers(
    config.PORT_RANGE_START,  // default 7777
    config.PORT_RANGE_END     // default 7800
  ),
  reserve: true,  // locks port for process lifetime — prevents startup race
});
```

`reserve: true` is mandatory. Without it two servers starting within the 15-30s reservation window can resolve the same port and both attempt to bind.

Port file is written after the HTTP server binds, before `process.send('ready')`:
```js
await fs.writeFile(path.join(config.DATA_DIR, 'port'), String(port));
```

---

## Session Isolation

Each session sets its own `DATA_DIR`:

```bash
# Session 1 (default)
node src/server.js
# → port file: ./data/port

# Session 2
DATA_DIR=./data-session2 APP_NAME=swarm-mcp-session2 node src/server.js
# → port file: ./data-session2/port
```

`DATA_DIR` scopes everything for that session: DB (`swarm.db`), fallback buffer (`fallback.ndjson`), dead letter (`fallback.ndjson.error`), and port file (`port`). No other config needs to change.

---

## Agent Pre-flight (mandatory)

Before any tool call, an agent must read the port file. No port number is ever hardcoded.

```bash
# Step 0 — read port (abort if file missing)
PORT=$(cat /path/to/data/port 2>/dev/null)
if [ -z "$PORT" ]; then
  echo "ERROR: port file not found — server is not running"
  exit 1
fi

# Step 1 — health check
curl -s http://localhost:$PORT/health

# Step 2 — tool calls
curl -X POST http://localhost:$PORT/mcp \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  -d '...'
```

If `$DATA_DIR/port` does not exist: the server has not started. Do not proceed.

If the file exists but the health check fails: the server crashed after writing the port file. Delete the port file, restart the server, and retry.

---

## ENV Reference

| Var | Default | Notes |
|-----|---------|-------|
| `DATA_DIR` | `./data` | All session data lives here |
| `PORT_HINT` | `7777` | First port tried; maps to `PORT_RANGE_START` |
| `PORT_RANGE_START` | `7777` | Start of get-port search range |
| `PORT_RANGE_END` | `7800` | End of range — 24 slots, supports up to 24 concurrent sessions on one machine |

`PORT` is accepted as a legacy alias for `PORT_RANGE_START`. `config.js` reads `PORT` as a fallback when `PORT_HINT` is absent.

---

## Cleanup

Port files and DBs are cheap. After a session ends:
```bash
rm -rf ./data-session2   # removes DB, fallback, port file
pm2 delete swarm-mcp-session2
```

No cleanup is required for the default session's `./data/` — it persists across restarts.
