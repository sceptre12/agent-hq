# Swarm Dispatch — Swarm Communication Layer

> Updated 2026-06-08.

Required steps before dispatching any multi-agent swarm.

---

## 1. Start the Session Server

Each swarm run gets its own isolated server process. Do NOT assume a shared server is running.

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

If pm2 start fails with a port allocation error (all 24 slots 7777–7800 occupied):
```
$PM2 list | grep swarm-mcp    # list active sessions
```
Tear down completed sessions to free port slots before retrying.

**Migrating from a legacy shared server:** A legacy `swarm-mcp` process does not need
to be stopped before starting per-session servers — they pick different ports automatically.
To clean up the legacy process when no longer needed: `$PM2 delete swarm-mcp`

Pass `DATA_DIR` and `SESSION_ID` to every agent brief. Agents derive the port from `$DATA_DIR/port` — never hardcode it.

**Teardown (after swarm completes):**
```bash
# end_session is optional for per-session servers — rm -rf destroys the DB.
# Call it for explicit MCP-layer cleanup if the session is still active.
$PM2 delete "${APP_NAME}"
rm -rf "${DATA_DIR}"
```

---

## 2. Pre-flight Smoke Test (blocking prerequisite)

Dispatch a bootstrap agent first. The bootstrap agent must:
1. Read `$DATA_DIR/port`
2. Confirm `GET /health` returns `{ status: "ok", turso: "connected" }`
3. Run one end-to-end tool call: `send_message` → `read_messages` (include `session_id`)
4. Emit to topic `swarm-status`: `{ type: "smoke-test", status: "pass", session_id: "<SESSION_ID>" }`

Orchestrator polls `swarm-status` every 2s (timeout: 60s) for a message with
`type: "smoke-test"` and `session_id` matching the current session.
Do not dispatch agents until this message is received.
For MCP call syntax and required headers, see `mcp-api.md`.

A passing health check is not sufficient — health confirms the process is alive, not that tools work.

---

## 3. Heartbeat Instructions (required in every agent brief)

Every orchestrator and long-running worker brief must include verbatim:

> 1. Send a `swarm-status` heartbeat on every phase transition (start, checkpoint, complete, error).
> 2. If waiting more than 10 minutes with no progress, immediately send `status: stalled` before any other action.

Missing heartbeat instructions = brief defect, not agent defect.

---

## 4. Re-spawn Template

Include this in the orchestrator brief before dispatch. For any stalled agent:
- Write a fresh brief scoped to that agent's exact assignment
- Specify output artifact path explicitly
- Direct agent to work directly — no sub-agent delegation
- Set a hard time limit (default: 15 minutes unless the task spec specifies otherwise)

Do not pass the stalled agent's logs or prior context. Declare the stalled run closed, re-spawn from a clean brief.

---

## 5. Permission Settings

Sub-agents dispatched via the `Agent` tool do not inherit project-level `settings.local.json`. Only `~/.claude/settings.json` applies. For swarm operations, a bare `"Bash"` entry in the global allow list is required to prevent permission interrupts in sub-agents.

> **Caution:** This is a global persistent grant across all Claude sessions — not scoped to the swarm run. A hallucinating sub-agent could run destructive shell commands. Only set this if you understand and accept the implication.

---

## References

- `port-discovery.md` — port pre-flight commands, $DATA_DIR/port contract
- `mcp-api.md` — MCP tool signatures, required HTTP headers, error codes
- `operations.md` — full startup/teardown procedures, health check details
