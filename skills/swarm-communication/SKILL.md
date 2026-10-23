---
name: swarm-communication
description: >
  Use when an agent needs to send messages, read messages, broadcast to a topic, or
  open/close a session on the swarm communication bus — the local MCP message bus used
  for multi-agent coordination. Covers verifying the bus is live via its data/port file,
  calling the five MCP tools (send_message, read_messages, broadcast, start_session,
  end_session), the mandatory explicit session_id rule, PM2-only log access, the
  persistence guarantee (messages survive server restarts), and fallback/retry handling
  when the bus is degraded. This is bus-usage infrastructure, not
  a review mechanism — no review-ladder rung applies (tools/review-ladder.md). Triggers:
  swarm bus, message bus, send message to agent, read messages, broadcast to swarm,
  agent coordination, inter-agent messaging, start_session, end_session.
---

## Trigger

Use when an orchestrator or worker agent needs to talk to other agents through the swarm
bus: sending a direct message, reading pending messages, broadcasting to a topic, or
managing a session's lifecycle. This is infrastructure for bus I/O, not a review
mechanism — the review-escalation ladder (`tools/review-ladder.md`) does not apply here.
All communication is **persistent** — messages survive server restarts. Writes buffer to
a local fallback file when Turso is down, then sync on reconnect (see step 2).

## Steps

1. **Confirm which deployment mode is live before assuming anything about `DATA_DIR`.**
   The bus's design targets one isolated PM2 instance per chat session (its own
   `DATA_DIR`/`APP_NAME`/DB file). The instance actually running today may instead be a
   single, generically-named shared app (commonly `swarm-mcp`). Run `pm2 list` and look
   for one shared app vs. several session-suffixed apps — do not assume per-session
   isolation is live without checking.
   - **Shared/single-instance mode** (confirm via `pm2 list`): `DATA_DIR` defaults to
     `./data` inside the bus repo (e.g. `~/projects/agent-hq/tools/swarm-communication-layer/data`) and
     `APP_NAME` is the shared name shown by `pm2 list`. Never delete or casually reload
     this instance — it may be serving other sessions (see Red flags and step 9).
   - **Per-session mode** (only if `pm2 list` shows a session-suffixed app for *your*
     run): `DATA_DIR`/`APP_NAME` are the values your orchestrator set at session start;
     use those, not the shared defaults.

   **Warning — native MCP tools are unsafe for per-session mode.** If `mcp__swarm-bus__*`
   tools appear directly available in your toolset (registered via this repo's `.mcp.json`,
   which is loaded automatically when a session's cwd is inside
   `~/projects/agent-hq/tools/swarm-communication-layer`), do NOT use them for per-session or concurrent
   work. `.mcp.json` hardcodes `http://127.0.0.1:7777/mcp` unconditionally — it has no
   awareness of `$DATA_DIR` or which port your session's instance actually bound. Using it
   in a concurrent multi-session context will silently connect you to whatever instance
   happens to be on port 7777, which may be a different session entirely. Always use the
   raw HTTP/curl flow below, addressed at your own session's port from `$DATA_DIR/port`,
   for any per-session work — even if native tools are present.

2. **Discover the port from `$DATA_DIR/port` — never hardcode a port number.** The server
   picks a port from a range and writes it to this file before it signals ready; a
   hardcoded port breaks the moment an instance claims a different one.
   ```bash
   PORT=$(cat "$DATA_DIR/port")
   curl -s "http://localhost:$PORT/health"
   ```
   Expected: `{"status": "ok", "turso": "connected", "fallback_active": false, ...}`.
   - `ok` — proceed normally.
   - `degraded` — Turso is unreachable; writes buffer to a local fallback file and sync on
     reconnect; reads may fail meanwhile. Proceed for writes only.
   - Connection refused — the bus isn't running. Workers: do not try to start or restart
     it yourself — escalate to your orchestrator and wait. Orchestrators: see step 3.
   - **Identity check (per-session mode only):** a single `ok` response is not proof this
     port is yours — sample `/health` 2-3 times and require its `app_name` and `data_dir`
     to equal the `APP_NAME`/`DATA_DIR` this session configured in step 1, every time. Any
     mismatch means another instance already owns this port (cluster-mode port sharing,
     architecture/swarm-communication-layer.md discrepancy #8) — abort with a clear error
     instead of proceeding.

   **Every tool response now carries `data_dir` and `port` fields** identifying which bus
   instance actually handled the call (added to close the collision class documented in
   `swarm-communication-layer/docs/superpowers/plans/2026-07-21-port-collision-fix.md`).
   Check these on every `send_message`/`read_messages`/`broadcast`/`start_session`/
   `end_session` response, not just once at connect time via `/health` — a response whose
   `data_dir` doesn't match your own session's `$DATA_DIR` means you are talking to the
   wrong instance. Stop immediately and re-verify your port discovery (Step 2 above) rather
   than continuing to send/read messages against a mismatched instance.

3. **Orchestrator-only: bring the bus up if it's down**, from inside the bus repo
   (default `~/projects/agent-hq/tools/swarm-communication-layer`, or wherever it's cloned locally):
   ```bash
   cd ~/projects/agent-hq/tools/swarm-communication-layer   # or your local clone of the bus repo
   DATA_DIR="${DATA_DIR:-./data}" APP_NAME="${APP_NAME:-swarm-mcp}" NODE_ENV=production \
     pm2 start ecosystem.config.cjs
   TRIES=0
   until [ -f "${DATA_DIR:-./data}/port" ] || [ $TRIES -ge 30 ]; do sleep 0.3; TRIES=$((TRIES+1)); done
   PORT=$(cat "${DATA_DIR:-./data}/port")
   curl -s "http://localhost:$PORT/health"
   ```
   Resolve `pm2` however your shell normally resolves it (nvm-managed or a global
   install on `PATH`) — do not hardcode a specific nvm install path. Only start a **new,
   session-suffixed** `DATA_DIR`/`APP_NAME` pair if you deliberately want per-session
   isolation (step 1); never start a second instance on top of an already-running shared
   one. Before treating the freshly-started instance as ready, re-run step 2's identity
   check against it — a `pm2 start` that lands on an already-claimed port is exactly the
   failure the identity check exists to catch.

4. **Call the five MCP tools over `POST $BASE_URL/mcp`**, where `BASE_URL =
   http://localhost:$PORT`. Always send `Accept: application/json, text/event-stream` —
   without it the server returns `406` and silently drops the call (curl still exits 0,
   no error surfaces). Full parameter schemas and return shapes:
   [references/tools.md](references/tools.md).
   ```bash
   curl -s -X POST "http://localhost:$PORT/mcp" \
     -H "Content-Type: application/json" \
     -H "Accept: application/json, text/event-stream" \
     -d '{"jsonrpc":"2.0","method":"tools/call","params":{"name":"send_message","arguments":{"from_agent":"<your-agent-id>","to":"<recipient>","content":"...","session_id":"<SESSION_ID>"}},"id":1}'
   ```
   Use these exact argument names (`from_agent`, `to`, `content`, `session_id`) —
   do not guess `from`/`message` or similar shorthand; a wrong name fails the call. The
   only valid send confirmation is the parsed JSON response showing `status:"sent"` (plus
   a message id). Never confirm a send by grepping logs or re-reading the topic, and never
   blind-resend on an ambiguous check — the bus has no dedup, so a duplicate post is
   permanent.

5. **Pass `session_id` explicitly on every `send_message`, `broadcast`, and
   `read_messages` call — never rely on it being ambient or inherited from
   `start_session`.** The server does not enforce or auto-attach it: a call made without
   `session_id` writes a row that the later `end_session` for your run will never find, so
   it is never cleaned up and stays visible to future sessions — a silent, **permanent**
   leak, not just staleness.

6. **Open and close the session around the whole run.** Before dispatching any agents,
   call `start_session({session_id})` (idempotent) and pass that `session_id` in every
   agent's brief. When the run ends — success or failure — call
   `end_session({session_id})`. `session_id` is nullable in the schema, but treat it as
   required in practice per step 5.

7. **Debugging: PM2 logs are the only real production log path.** The `/health` payload
   advertises a `log_file` value; on a PM2-managed instance that path does not exist — only
   PM2's own log files do. Use:
   ```bash
   pm2 logs "$APP_NAME"
   ```
   as the sole authoritative production log accessor. Do not look for or tail a
   `server.log` under `$DATA_DIR/logs/` in production — that path is dev-mode-only. See
   [references/patterns.md](references/patterns.md) for coordination patterns,
   retry/error-code handling, and extended debugging notes.

8. **Mid-run recovery.** If `/health` stops responding mid-swarm:
   ```bash
   PORT=$(cat "$DATA_DIR/port")                # re-read — confirm the port hasn't changed
   curl -s "http://localhost:$PORT/health"      # 1. confirm it's actually down
   lsof -ti :$PORT | xargs kill -9              # 2. kill the hung process, if any
   pm2 restart "$APP_NAME"                      # 3. stop-then-start via pm2 (never reload —
                                                 #    reload overlaps old/new workers on the
                                                 #    SQLite file and crash-loops on a locking error)
   PORT=$(cat "$DATA_DIR/port")
   curl -s "http://localhost:$PORT/health"      # 4. confirm ok before resuming
   ```
   Never `pm2 delete` a shared instance to "fix" it (see Red flags) — `pm2 restart` is the
   recovery step. Re-poll after recovery before making any phase decision; buffered
   fallback messages sync automatically, so no messages are lost.

9. **Teardown is per-session-mode only.**
   ```bash
   pm2 delete "$APP_NAME"
   rm -rf "$DATA_DIR"
   ```
   is the per-session design's cleanup step, run after `end_session` (step 6) and after
   the run's final report has been returned. In shared/single-instance mode (step 1), do
   **not** run this — it would delete the bus out from under every other session using
   it. Confirm mode before tearing anything down.

## Red flags

| Rationalization | What to do instead |
|---|---|
| "I'll skip `session_id`, it's marked optional in the schema." | Pass it explicitly on every call anyway — omitting it produces a silently untagged row `end_session` can never clean up: permanent leakage, not just staleness (step 5). |
| "The `log_file` path advertised by `/health` is the production log — tail that." | It doesn't exist under PM2; `pm2 logs $APP_NAME` is the only real production log path (step 7). |
| "This skill mentions per-session `DATA_DIR`/`APP_NAME`, so that's what must be running." | Check `pm2 list` first (step 1) — today's live deployment may be one shared instance, not per-session; acting on the wrong assumption means looking for a port file that doesn't exist. |
| "The bus feels slow, let me `pm2 delete` and restart it." | If it's the shared instance, that deletes the bus for every other session using it; `pm2 restart` is the recovery step — delete is reserved for the per-session teardown you started yourself (steps 8-9). |
| "`pm2 reload` is gentler than `restart`, use that to recover." | `reload` overlaps old/new workers on the shared SQLite file and crash-loops on a locking error; `pm2 restart` (stop-then-start) is the only safe verb here (step 8). |
| "I need a smaller/faster model for this — let me shell out to `claude -p` with a different model." | Not supported here; model selection belongs to whichever agent or orchestrator dispatched this skill, not to a nested CLI re-invocation from inside it. |
| "This is reviewing another agent's output, so it's a review-ladder call." | It isn't — this is bus I/O infrastructure; `tools/review-ladder.md` rungs don't apply to it. |

## Exit criteria

- [ ] Deployment mode (shared vs. per-session) was confirmed via `pm2 list` before any
      `DATA_DIR`/`APP_NAME` assumption was acted on.
- [ ] The port used came from reading `$DATA_DIR/port` at call time — never a hardcoded
      number.
- [ ] Every `send_message`/`broadcast`/`read_messages` call in the run carried an explicit
      `session_id`.
- [ ] `start_session` ran before dispatch and `end_session` ran after the run finished
      (success or failure).
- [ ] Any log access used `pm2 logs $APP_NAME`, not a tailed `server.log` path.
- [ ] No shared/single-instance bus was deleted or torn down as part of this run.

## Provenance

Provenance: Hermes skill `learnings/skill-sharing` (was learnings/skill-sharing.md) (2026-07-04 entry, "Skills have no standardized
export path")
Lineage: X-context-docs skills/swarm-communication@0e9281e
