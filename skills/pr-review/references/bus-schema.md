# PR Review — Bus Topic Schema

> **bus-schema.md is the single authoritative source for all message format definitions.**

> **Naming note (Gate 2 refit):** every per-check topic below is prefixed `pr-check-*`
> rather than the source corpus's bare `check-*`. doc-reviewer (already installed at
> `~/.claude/skills/doc-reviewer`) defines its own, unrelated Check 1–14 taxonomy,
> including its own "Check 7: Cold Read Gate" — the two taxonomies share no domain overlap
> (pr-review's checks are RACI-assigned code-review dimensions; doc-reviewer's are a fixed
> 14-step document QA sequence), so an operator saying "run check 7" or "the cold read
> check" once both skills are installed would otherwise be genuinely ambiguous. The
> `pr-check-*` prefix disambiguates at the topic-name level. This same collision applies to
> the not-yet-ported — pending `panel-review` skill (same source corpus); apply the same
> `pr-`-prefix convention there if/when it's ported, or a distinct prefix if that skill
> later needs its own namespace.

## Topics

| Topic | Purpose | Producer | Consumer | Payload Shape | Quorum Rule |
|-------|---------|----------|----------|---------------|-------------|
| `pr-check-cold-read` | Cold Read findings + C member responses | Responsible agent (integration-architect / strategic-reviewer) | C members | FINDING / VALIDATE pipe-delimited | All C members respond to each FINDING |
| `pr-check-cold-read-closed` | Integration Architect signals Cold Read quorum met | Integration Architect | gate-checker | `CLOSED | pr-check-cold-read | ...` | N/A |
| `pr-check-1` … `pr-check-9` | Per-check findings + C member responses | Responsible agent | C members | FINDING / VALIDATE pipe-delimited | All C members respond to each FINDING |
| `pr-check-1-closed` … `pr-check-9-closed` | Accountable signals quorum met | Accountable agent | gate-checker | `CLOSED | pr-check-N | ...` | N/A |
| `rendezvous` | Phase 1 completion signaling | All 7 Phase 1 agents | gate-checker | `PHASE1_DONE | [agent-id] | [SESSION_ID]` | 7 distinct agent_ids required |
| `phase2-rendezvous` | Phase 2 completion signaling | All 7 Phase 2 agents | phase2 gate-checker | `PHASE2_DONE | [agent-id] | [SESSION_ID]` | 7 distinct agent_ids required |

> **SESSION_ID / run_id equivalence:** In this skill `session_id` and `SESSION_ID` refer to the
> same value. All bus messages and MCP tool calls use the same string, and it must be passed
> **explicitly** on every call (`send_message`, `broadcast`, `read_messages`) — it is never
> ambient, even after `start_session` (architecture/swarm-communication-layer.md discrepancy
> #6). A call that omits it produces an untagged row `end_session` will never clean up.

## Message Shape

Every message posted to a check topic must be **pipe-delimited plain text** (canonical format).
Structured JSON is not used — agents pass content as plain text strings in the `content` field.

Canonical formats:
- FINDING: `FINDING | pr-check-N | [Blocking/Medium/Advisory] | [description] | Fix: [recommendation]`
- VALIDATE/CHALLENGE/ESCALATE/ADD: `VALIDATE | pr-check-N | from [agent-id] | [reasoning]`
- CLOSED: `CLOSED | pr-check-N | [agent-id] | [quorum summary]`
- PASS: `PASS | pr-check-N | No issues found`
- PHASE1_DONE: `PHASE1_DONE | [agent-id] | [SESSION_ID]`
- PHASE2_DONE: `PHASE2_DONE | [agent-id] | [SESSION_ID]`

## Rendezvous Topic Detail

### phase1 — `rendezvous`

| Field | Value |
|-------|-------|
| topic | `rendezvous` |
| producer | All 7 Phase 1 agents (broadcast after all owned checks confirmed) |
| consumer | gate-checker |
| quorum rule | 7 distinct agent_ids required; duplicates from retries are ignored |

### phase2 — `phase2-rendezvous`

| Field | Value |
|-------|-------|
| topic | `phase2-rendezvous` |
| producer | All 7 Phase 2 agents (broadcast after all deliberation complete) |
| consumer | phase2 gate-checker |
| quorum rule | 7 distinct agent_ids required; duplicates from retries are ignored |

## Quorum Rule

A check topic is eligible to close when every agent listed as Consulted (C) for that
check has posted at least one of VALIDATE / CHALLENGE / ESCALATE / ADD against each
FINDING on that topic.

The Accountable (A) agent monitors the topic, tracks which C agents have responded to
each finding_id, and posts CLOSED to `pr-check-N-closed` when all C responses are in.

## Timeouts

| Gate | Topic | Timeout | Quorum |
|------|-------|---------|--------|
| PHASE1_DONE gate (rendezvous) | `rendezvous` | 8 minutes | 7 distinct agent_ids |
| PHASE2_DONE gate (phase2-rendezvous) | `phase2-rendezvous` | 10 minutes | 7 distinct agent_ids |
| Per-check threads | `pr-check-N` | 10 minutes | All C members responded |

If quorum is not reached within the timeout, the Workflow marks the thread `TIMED_OUT`.
The synthesizer includes a note in the findings table for any timed-out thread.

## Reader idiom (C2)

Orchestrator, gate-checker and synthesizer reads use `peek:true`, a fresh `agent_id` per reader and per
read, `limit` 200, and one topic per call:

`{"name":"read_messages","arguments":{"session_id":"<SESSION_ID>","agent_id":"<fresh-id>","topics":["pr-check-1"],"limit":200,"peek":true}}`

Seats read with their own agent-id (harmless under `peek:true`, which never consumes unread state), also `limit` 200 and one topic per call. Without `peek` a read consumes the
unread state.

## Session Isolation

All messages include `session_id`, passed explicitly on every call (never ambient — see
above). Every `read_messages` call filters by `session_id`. Parallel review runs do not
bleed into each other.

## Bus health / troubleshooting

`GET /health`'s advertised `log_file` path does not exist under PM2
(architecture/swarm-communication-layer.md discrepancy #7). To debug a stuck or silent
agent, read the PM2 logs for the session's `APP_NAME` instead of the advertised path.
