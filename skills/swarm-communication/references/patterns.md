# Swarm Communication — Patterns & Reference

Companion to [SKILL.md](../SKILL.md). Extended coordination patterns, error handling, and
debugging reference. The authoritative rules for `session_id` and log access live in
SKILL.md steps 5 and 7 — this file adds detail, it does not restate or override them.

---

## Agent Identity Convention

Agent IDs are freeform strings — there is no registration step. Choose IDs that are
descriptive and unique within a swarm run. Recommended format:

```
<role>-<swarm-id>       e.g. orchestrator-run42, worker-1-run42, researcher-run42
```

Pass your agent ID explicitly in every tool call as `from_agent`. Never share IDs between
concurrent agents.

---

## Topic Naming Convention

Topics are application-defined — the server has no topic registry. Standard topics for
orchestrator/worker swarms:

| Topic | Purpose |
|-------|---------|
| `orchestrator-broadcast` | Orchestrator → all workers (phase transitions, global signals) |
| `swarm-status` | Any agent → any agent (status updates, heartbeats) |
| `worker-results` | Workers → orchestrator (task completion reports) |
| `decision-required` | Any agent → orchestrator (blocked on a decision, needs input) |

Define your topics in the orchestrator brief and include them in every worker's prompt.

---

## Session Lifecycle (detail)

Recommended ID format: `<swarm-name>-<YYYYMMDD>-<short-uuid>`,
e.g. `research-sprint-20260704-b91c`.

Reiterating SKILL.md steps 5-6 in one place: every `send_message`/`broadcast`/
`read_messages` call in the run must carry the run's `session_id` explicitly, and the
orchestrator must call `end_session` when the run finishes (success or failure). Skip
either half and messages persist untagged or uncleaned, visible to future sessions.

---

## Coordination Patterns

### Pattern 1: Orchestrator → Workers (fan-out)

```
1. Orchestrator broadcasts phase start:
   broadcast({ from_agent: "orchestrator", topic: "orchestrator-broadcast",
     content: "Begin phase 2", session_id: "<run-id>" })

2. Each worker polls for instructions:
   read_messages({ agent_id: "worker-N", topics: ["orchestrator-broadcast"],
     session_id: "<run-id>" })

3. Workers execute, then report back:
   send_message({ to: "orchestrator", from_agent: "worker-N",
     content: JSON.stringify(result), session_id: "<run-id>" })

4. Orchestrator collects results:
   read_messages({ agent_id: "orchestrator", session_id: "<run-id>" })
```

### Pattern 2: Worker blocked — escalate to orchestrator

```
Worker hits ambiguity it cannot resolve:
  send_message({
    to: "orchestrator",
    from_agent: "worker-N",
    content: JSON.stringify({ status: "blocked", reason: "...", options: [...] }),
    topic: "decision-required",
    session_id: "<run-id>"
  })

Orchestrator reads, decides, responds:
  send_message({
    to: "worker-N",
    from_agent: "orchestrator",
    content: JSON.stringify({ decision: "...", proceed: true }),
    session_id: "<run-id>"
  })
```

### Pattern 3: Phase gate via message (alternative to .complete signal files)

```
Worker writes output → sends completion message to orchestrator:
  send_message({
    to: "orchestrator",
    from_agent: "worker-N",
    content: JSON.stringify({ phase: "2", status: "complete", output_path: "/tmp/..." }),
    session_id: "<run-id>"
  })

Orchestrator polls until N completion messages received:
  loop: read_messages({ agent_id: "orchestrator", session_id: "<run-id>" })
    until messages.length === expectedWorkerCount
```

### Pattern 4: Gate request with tight-poll handshake

After sending a gate request, do NOT wait for the standard poll interval:

```
1. send_message({ to: "o-memory", from_agent: "orchestrator",
     content: "...", topic: "gate-request", session_id: "<run-id>" })
2. Enter tight loop: poll read_messages every 2-3s until PROCEED or HOLD received
3. Exit loop on response — include a 60s timeout to avoid infinite waits
```

`"o-memory"` names a consumer-side orchestrator role belonging to a separate,
not-yet-ported pipeline (see `architecture/swarm-communication-layer.md`, Known Issues
#2-3) — not a role this skill defines. If your deployment has no such pipeline running,
address the gate-request to your own orchestrator's `agent_id` instead of `"o-memory"`.

---

## Error Handling

All tools return structured errors — never thrown exceptions:
```json
{ "error": { "code": "ERROR_CODE", "message": "human-readable description" } }
```

| Code | Meaning | Action |
|------|---------|--------|
| `DB_READ_FAILED` | Turso unreachable, reads unavailable | Wait and retry — check `/health` |
| `RECONNECTING` | Fallback is draining, sync in progress | Retry after 1-2 seconds |
| `FALLBACK_WRITE_FAILED` | Both Turso and fallback file failed | Critical — log and escalate |
| `PARAM_OUT_OF_RANGE` | `limit` exceeded 200 | Reduce limit |
| `MISSING_REQUIRED_PARAM` | Required field absent | Fix the tool call |
| `SERVER_SHUTTING_DOWN` | Server in drain phase | Retry after 1-2 seconds |
| `SESSION_NOT_FOUND` | Referenced session doesn't exist | Confirm `start_session` ran first |

**Retry guidance for transient failures:** 3 retries, 500ms exponential backoff.
Apply to: `ECONNREFUSED`, `RECONNECTING`, `SERVER_SHUTTING_DOWN`.

---

## Debugging (pointer only)

The authoritative log-access rule lives in SKILL.md step 7: `pm2 logs "$APP_NAME"` is the
sole production log accessor. Do not tail a `$DATA_DIR/logs/server.log` path in
production — that path is dev-mode-only and does not exist under PM2.

In dev mode (server run directly, not under PM2), logs go to stdout as pino
pretty-printed output — there is no file to tail; read the terminal the server is
running in.

Health check, pretty-printed:
```bash
PORT=$(cat "$DATA_DIR/port")
curl -s "http://localhost:$PORT/health" | python3 -m json.tool
```

---

## Per-Session Teardown (detail)

When operating in per-session mode (SKILL.md step 1) and the swarm run has completed:

```bash
pm2 delete "$APP_NAME"
rm -rf "$DATA_DIR"
```

Resolve `pm2` via your shell's normal resolution (nvm-managed or global) — do not
hardcode an nvm install path. Run this after `end_session` (SKILL.md step 6) and after
the run's final report has been returned. Never run this against a shared/single-instance
bus (SKILL.md step 9) — see Red flags there; it would destroy the bus for every other
session using it.
