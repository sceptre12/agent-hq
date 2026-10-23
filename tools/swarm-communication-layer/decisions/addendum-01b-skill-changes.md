# Addendum 01b — Skill Changes Checklist

> Companion to [addendum-01a](addendum-01a-fixes-and-session-lifecycle.md).
> Every item below is a required change to `~/.claude/skills/swarm-communication/SKILL.md`.

---

## Pre-existing Issues to Fix

### S-0 — Hardcoded port `7777`

Every reference to `http://localhost:7777` must be replaced. Port is dynamic
and written to `$DATA_DIR/port` at startup. No hardcoded port is ever valid.

**Pattern for all curl examples:**
```bash
PORT=$(cat $DATA_DIR/port)
curl -s http://localhost:$PORT/health
```

Apply to: Step 0 health check, Mid-Run Recovery section, MCP Server Connection
section, Tool Reference curl examples, Logs/Debugging health check example.

---

## Changes from Bug Fixes

### S-1 — `read_messages` side-effect description

Current text: *"Side effect: marks returned messages as `delivered` in the DB."*

Replace with:
> Side effect: marks returned messages as `delivered` in the DB, **unless
> `peek: true`** — in that case no receipts are written. Use `peek: true` for
> inspection without consuming messages.

### S-2 — Add `peek` param to `read_messages` tool reference block

Add to the parameter table:
```
peek:      boolean   — if true, skip receipt writes (default false, optional)
```

---

## Changes from Session Lifecycle

### S-3 — Add `session_id` to `send_message` tool reference

Add to the parameter table:
```
session_id:  string   — session tag; include for all messages in a swarm run (optional)
```

### S-4 — Add `session_id` to `broadcast` tool reference

Same as S-3.

### S-5 — Add `session_id` to `read_messages` tool reference

Add to the parameter table:
```
session_id:  string   — scope reads to a specific session (optional)
```

### S-6 — Add `start_session` tool reference section

New section after `broadcast`:

```
start_session — Register a new session

start_session({
  session_id:  string   — caller-defined session ID (required)
})

Returns: { session_id: string, created_at: string }
Idempotent — safe to call if session already exists.
Call this before dispatching any agents. Pass session_id to every agent brief.
```

### S-7 — Add `end_session` tool reference section

New section after `start_session`:

```
end_session — Clean up all messages for a session

end_session({
  session_id:  string   — session to clean up (required)
})

Returns: { session_id: string, deleted_messages: number }
Deletes all messages and receipts for the session, then the session record.
Call this when the swarm completes — success or failure.
```

### S-8 — Add session lifecycle guidance section

New section titled "Session Lifecycle" before Coordination Patterns:

> Every swarm run must open and close a session.
>
> 1. Orchestrator calls `start_session({ session_id: "<run-id>" })` before
>    dispatching any agents.
> 2. Pass `session_id` in every agent brief. Agents include it in every
>    `send_message` and `broadcast` call.
> 3. Orchestrator calls `end_session({ session_id: "<run-id>" })` when the
>    swarm finishes — success or failure.
>
> Without `end_session`, messages persist in the DB and will be visible to
> future sessions. This is the primary cause of stale-message contamination.
>
> Recommended ID format: `<swarm-name>-<YYYYMMDD>-<short-uuid>`

---

## Changes from Agent-Side Guidance

### S-9 — Add polling frequency guidance

Add a note under the `read_messages` description:

> **Polling frequency:** During active swarm runs, poll at **2–5s intervals**.
> A 30s poll interval causes gate stalls — orchestrators waiting on a
> PROCEED/HOLD response can be blocked for up to 30s.

### S-10 — Add gate handshake pattern (Coordination Pattern 4)

Add new pattern after Pattern 3:

```
Pattern 4: Gate request with tight-poll handshake

After sending a gate request, do NOT wait for the standard poll interval:

  1. send_message({ to: "o-memory", from_agent: "orchestrator", content: "...", topic: "gate-request" })
  2. Enter tight loop: poll read_messages every 2–3s until PROCEED or HOLD received
  3. Exit loop and act on the response

Using the standard poll interval for gate responses adds unnecessary latency.
The tight loop should have a timeout (e.g. 60s) to avoid infinite waits.
```

---

## Summary Table

| Item | Section in SKILL.md | Change type |
|------|---------------------|-------------|
| S-0  | All curl examples | Fix hardcoded port → read from `$DATA_DIR/port` |
| S-1  | `read_messages` description | Add peek condition to side-effect note |
| S-2  | `read_messages` params | Add `peek` param |
| S-3  | `send_message` params | Add `session_id` param |
| S-4  | `broadcast` params | Add `session_id` param |
| S-5  | `read_messages` params | Add `session_id` param |
| S-6  | Tool Reference | Add `start_session` section |
| S-7  | Tool Reference | Add `end_session` section |
| S-8  | Before Coordination Patterns | Add Session Lifecycle section |
| S-9  | `read_messages` description | Add polling frequency note |
| S-10 | Coordination Patterns | Add Pattern 4 (gate handshake) |
