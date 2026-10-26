# PR Review — Step 1 and Step 9 standalone (`RUN_HOME` unset)

Standalone use outside a run. Inside a run use `bus-start-run.md` instead. Compared with the 1.0.0
script, the one change is the pre-bind port check of owner rule R-x as made binding by OQ-2 (INTERFACES
1.3.0 A.5.2, D2.3 `BUS_PORT` "the same rule applies standalone"): check the candidate port, retry once
at +10, then start the bus pinned to that port. Everything else (session id, `/tmp` data dir, pm2
start, health, identity and loopback checks, outputs) is unchanged. This flow is for sessions where
`/tmp` is writable (the unchanged 1.0.0 flow, spec Q10-5); a sandboxed session (executor tier) cannot
write `/tmp`.

## Step 1 — start the bus (dispatch a `mechanical`-tier sub-agent to run this script)

The candidate P is `BUS_PORT` when the caller sets it (Step 0 validated it), else the bus server's
default start port 7777 (`PORT_RANGE_START` default in `tools/swarm-communication-layer/src/config.js`).
P and P+10 are the whole standalone range under OQ-2: no auto-pick, no scan of 7777-7800 as in 1.0.0.
The standing `swarm-mcp` app normally holds 7777, so a default standalone review lands on 7787, and a
second concurrent default review finds both taken and stops the line. The check is not a claim, so two
reviews starting at the same moment can race for P+10; the port-file equality check below stops the
loser. If `lsof` is missing or fails, the check stops: a failed check never counts as a free port.

```bash
PM2=${PM2_BIN:-$(which pm2 2>/dev/null)}
[ -n "${PM2}" ] && [ -x "${PM2}" ] || { echo '{"running":false,"error":"pm2 binary not found — set PM2_BIN or ensure pm2 is on PATH"}'; exit 1; }
# Pre-bind check (R-x / OQ-2): candidate, then exactly one retry at +10, then stop
command -v lsof >/dev/null 2>&1 || { echo "ERROR: lsof unavailable — cannot check the port, stop and report"; exit 1; }
port_taken() {  # 0 = listener present, 1 = free; any other lsof failure stops (stderr warnings ignored)
  OUT=$(lsof -nP -iTCP:"$1" -sTCP:LISTEN 2>/dev/null); RC=$?
  [ -n "$OUT" ] && [ $RC -eq 0 ] && return 0
  [ $RC -eq 1 ] && [ -z "$OUT" ] && return 1
  echo "ERROR: lsof failed on port $1 (rc=$RC) — stop and report"; exit 1
}
P=${BUS_PORT:-7777}
if port_taken "$P"; then
  P=$((P + 10))
  [ "$P" -le 65535 ] || { echo "ERROR: retry port $P out of range — stop and report"; exit 1; }
  if port_taken "$P"; then
    echo "ERROR: ports $((P - 10)) and ${P} both taken — one +10 retry used, stop and report"; exit 1
  fi
fi
SESSION_NAME="pr-review"
SESSION_UUID=$(uuidgen | tr '[:upper:]' '[:lower:]' | cut -c1-8)
SESSION_ID="swarm-${SESSION_NAME}-$(date +%Y%m%d)-${SESSION_UUID}"
DATA_DIR="/tmp/${SESSION_ID}"
APP_NAME="swarm-mcp-${SESSION_ID}"
mkdir -p "${DATA_DIR}/logs"
cd ~/projects/agent-hq/tools/swarm-communication-layer || { echo "ERROR: sibling repo not found at ~/projects/agent-hq/tools/swarm-communication-layer"; exit 1; }
export NVM_DIR="$HOME/.nvm"; [ -s "${NVM_DIR}/nvm.sh" ] && source "${NVM_DIR}/nvm.sh" && nvm use --lts > /dev/null 2>&1
# Pinned: get-port cannot choose another port
DATA_DIR="${DATA_DIR}" APP_NAME="${APP_NAME}" PORT_RANGE_START="${P}" PORT_RANGE_END="${P}" NODE_ENV=production "$PM2" start ecosystem.config.cjs
TRIES=0
until [ -f "${DATA_DIR}/port" ] || [ $TRIES -ge 30 ]; do sleep 0.3; TRIES=$((TRIES + 1)); done
if [ ! -f "${DATA_DIR}/port" ]; then echo "ERROR: port file not written after 9s"; exit 1; fi
PORT=$(cat "${DATA_DIR}/port")
[ "$PORT" = "$P" ] || { echo "ERROR: bus bound ${PORT}, not the checked port ${P} — stop and report"; exit 1; }
curl -sf http://localhost:${PORT}/health || { echo "ERROR: health check failed"; exit 1; }
# Identity check — sample /health 2-3x; app_name and data_dir must equal what this run
# just configured every time. A mismatch means another instance already owns this port
# (architecture/swarm-communication-layer.md discrepancy #8) — abort, don't proceed.
for i in 1 2 3; do
  RESP=$(curl -sf "http://localhost:${PORT}/health") || { echo "ERROR: health check failed on identity sample $i"; exit 1; }
  GOT_APP=$(echo "$RESP" | grep -o '"app_name":"[^"]*"' | cut -d'"' -f4)
  GOT_DIR=$(echo "$RESP" | grep -o '"data_dir":"[^"]*"' | cut -d'"' -f4)
  [ "$GOT_APP" = "${APP_NAME}" ] && [ "$GOT_DIR" = "${DATA_DIR}" ] || { echo "ERROR: /health identity mismatch on sample $i — expected app_name=${APP_NAME} data_dir=${DATA_DIR}, got app_name=${GOT_APP} data_dir=${GOT_DIR} — another instance owns this port, aborting"; exit 1; }
  sleep 0.2
done
# Bind-address guard — MCP server must be on loopback only
if ! lsof -nP -iTCP:${PORT} -sTCP:LISTEN | grep -qE '127\.0\.0\.1|::1'; then
  echo "ERROR: MCP server not bound to loopback — aborting"
  exit 1
fi
echo "SESSION_ID=${SESSION_ID}"
echo "DATA_DIR=${DATA_DIR}"
echo "APP_NAME=${APP_NAME}"
echo "PORT=${PORT}"
```

Capture `SESSION_ID`, `DATA_DIR`, `APP_NAME` and `PORT`. Derive `SESSION_SUFFIX` from the
`SESSION_ID` leaf (e.g. `20260704-a3f2`); Step 2 standalone uses
`DIFF_PATH="/tmp/pr-review-${SESSION_SUFFIX}.diff"`. Any `ERROR` after `pm2 start` ran: run the Step 9
cleanup below for this `APP_NAME` and `DATA_DIR` before reporting.

`PM2_BIN` may be set by the caller's environment to point at a specific pm2 binary; otherwise
`which pm2` resolves it. This is the single PM2-resolution snippet, used again verbatim in Step 9 and in
`bus-start-run.md`; edit all call sites together, and reconcile with the `swarm-communication` skill's
bus-lifecycle reference so the copies do not drift.

## Step 9 — cleanup (dispatch a `mechanical`-tier sub-agent)

Call `end_session` with `SESSION_ID` via the MCP tool (`session_id` passed explicitly), then run:

```bash
APP_NAME="${APP_NAME}" DATA_DIR="${DATA_DIR}" DIFF_PATH="${DIFF_PATH}" bash -c '
  PM2=${PM2_BIN:-$(which pm2 2>/dev/null)}
  [ -n "$PM2" ] && [ -x "$PM2" ] && "$PM2" delete "$APP_NAME" 2>/dev/null || true
  [[ -n "$DATA_DIR" && "$DATA_DIR" == /tmp/* ]] && rm -rf "$DATA_DIR"
  [[ -n "$DIFF_PATH" && "$DIFF_PATH" == /tmp/* ]] && rm -f "$DIFF_PATH"
'
```

The `/tmp/*` guard belongs to this standalone flow only; it never matches an in-run path.
