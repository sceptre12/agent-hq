---
name: panel-review
description: >
  Real 11-agent architecture review panel: each agent independently runs domain checks,
  deliberates live over the swarm communication bus, and a synthesizer compiles a findings
  table with full RACI attribution. Use when asked to: panel review, run the panel on
  this, full review, cross-role review, bring in the panel, or any variation of "multiple
  expert perspectives" on a document, spec, architecture decision, or codebase. This is
  Rung 4 — the top rung — on the review ladder (tools/review-ladder.md): 11 independent
  agents + live bus quorum deliberation, reserved for large architecture docs,
  one-way-door decisions, and high-blast-radius artifacts where perspective independence
  actually matters. For a substantial code diff/PR that doesn't need the full 11-agent
  quorum, use pr-review instead (Rung 3).
disable-model-invocation: true
---

# Panel Review

A real 11-agent architecture review panel. Each agent reads the artifact independently,
runs domain-specific checks, and deliberates via the swarm communication bus. A 12th
synthesizer compiles a findings table with full RACI attribution and presents Phase B.

## Trigger

Use when asked to "panel review," "run the panel on this," "full review," "cross-role
review," "bring in the panel," or any variant of "multiple expert perspectives" on a
document, spec, architecture decision, or codebase. This is **Rung 4** — the top rung — on
the review ladder (`tools/review-ladder.md`): 11 independent agents deliberating live over
the swarm bus, reserved for large architecture docs, one-way-door decisions, and
high-blast-radius artifacts where perspective independence — not simulation — actually
matters. It is stronger than doc-reviewer (Rung 1, single-agent checklist) and
panel-consultation (Rung 2, single-context simulated panel) for exactly this reason: real
independent agent instances, not one agent roleplaying several. For a substantial code
diff/PR that doesn't need the full 11-agent quorum, use pr-review instead (Rung 3); there
is no rung above this one.

Note: this skill is deliberately `disable-model-invocation` — the Skill tool will refuse
it. Dispatch prompts must instruct the operator agent to READ this SKILL.md and follow its
steps directly, never to "invoke panel-review via the Skill tool."

The Integration Architect performs **flow-scope tracing**: for every bus topic in the
artifact, it locates producer/consumer in `~/.claude/skills/`, compares topic strings and
payload schemas exactly, and verifies registration in `references/bus-schema.md`.

## Bus session rules (mandatory — architecture/swarm-communication-layer.md)

Every step below that touches the bus must observe two verified discrepancies:

- **Explicit `session_id`, never ambient (discrepancy #6).** `start_session` does not make
  later `send_message`/`broadcast`/`read_messages` calls inherit the session. Pass
  `session_id` explicitly on every single call. A call that omits it produces an untagged
  row that `end_session` will never clean up, and other agents filtering by `session_id`
  will silently miss it.
- **PM2 logs, not the health-advertised path (discrepancy #7).** `GET /health`'s
  `log_file` field does not point at a path that exists under PM2. To debug a stuck or
  silent agent, read the PM2 logs for the session's `APP_NAME` (`pm2 logs <app_name>` or
  the PM2-managed log files under the session's `DATA_DIR/logs`), not the advertised
  `log_file`.

Port discovery is **never hardcoded**: every step below reads `$DATA_DIR/port`, written by
the server itself after `get-port` resolves it. This matches the live-bus fact that the
port is discovered from `data/port` (currently 7777 for the standing `swarm-mcp` PM2 app),
but each review session in this skill starts its **own** isolated bus instance (own
`DATA_DIR`, own `APP_NAME`, own port) rather than reusing that standing instance — per the
architecture record, each session gets its own DB file and port; a shared server would
serialize all concurrent reviews through one writer.

## Pre-flight

Required caller inputs (must be present in the dispatch prompt):
- The artifact to review — a file path, or content written to a temp file if it doesn't
  already live on disk.
- A unique session suffix for this run (e.g. `doc-name-YYYYMMDD`).

Before dispatching Wave 1, confirm the artifact is actually readable (file exists). Do not
dispatch Wave 1 if the artifact cannot be read.

## Execution model — model pin per dispatch (Rule 3/4, `tools/model-routing.md`)

Every dispatch below must pin a model explicitly per hq global Rule 3, matched to task
difficulty per Rule 4. A full run is up to 28 dispatches; the mechanical ones are cheap,
the judgment ones are not:

| Dispatch | Count | Model | Rationale |
|---|---|---|---|
| Step 1 — bus startup | 1 | Haiku | Mechanical: start pm2, poll for the port file, health-check |
| Step 2 — start session | 1 | Haiku | Mechanical: single `start_session` MCP call |
| Step 3 — Wave 1 domain-check agents | 11 | Sonnet | Judgment: read the artifact, form findings against owned checks |
| Step 4 — Gate 1 checker | 1 | Haiku | Mechanical: poll a bus topic, count distinct agent ids |
| Step 5 — Wave 2 deliberation agents | 11 | Sonnet | Judgment: evaluate peer findings, VALIDATE/CHALLENGE/ESCALATE/ADD |
| Step 6 — Gate 2 checker | 1 | Haiku | Mechanical: same as Gate 1 |
| Step 7 — synthesizer | 1 | Sonnet | Judgment: compile findings table, deliberation trails, verdict |
| Step 8 — cleanup | 1 | Haiku | Mechanical: `end_session`, pm2 delete, remove scratch data dir |

Each dispatch states an explicit, verifiable done condition and a stop-on-anomaly clause
per `tools/model-routing.md`'s dispatch checklist — a blocked gate or safety stop in any
report is stop-the-line for the orchestrator, never bypassed.

## Steps

### Step 1 — Start the per-session swarm bus

Dispatch a sub-agent (Haiku) to run this bash script:

```bash
PM2=${PM2_BIN:-$(which pm2 2>/dev/null)}
[ -n "${PM2}" ] && [ -x "${PM2}" ] || { echo '{"running":false,"error":"pm2 binary not found — set PM2_BIN or ensure pm2 is on PATH"}'; exit 1; }
SESSION_NAME="panel-review"
SESSION_UUID=$(uuidgen | tr '[:upper:]' '[:lower:]' | cut -c1-8)
SESSION_ID="swarm-${SESSION_NAME}-$(date +%Y%m%d)-${SESSION_UUID}"
DATA_DIR="/tmp/${SESSION_ID}"
APP_NAME="swarm-mcp-${SESSION_ID}"
mkdir -p "${DATA_DIR}/logs"
cd ~/projects/agent-hq/tools/swarm-communication-layer || { echo "ERROR: sibling repo not found at ~/projects/agent-hq/tools/swarm-communication-layer"; exit 1; }
export NVM_DIR="$HOME/.nvm"; [ -s "${NVM_DIR}/nvm.sh" ] && source "${NVM_DIR}/nvm.sh" && nvm use --lts > /dev/null 2>&1
DATA_DIR="${DATA_DIR}" APP_NAME="${APP_NAME}" NODE_ENV=production "$PM2" start ecosystem.config.cjs
TRIES=0
until [ -f "${DATA_DIR}/port" ] || [ $TRIES -ge 30 ]; do sleep 0.3; TRIES=$((TRIES + 1)); done
if [ ! -f "${DATA_DIR}/port" ]; then echo "ERROR: port file not written after 9s"; exit 1; fi
PORT=$(cat "${DATA_DIR}/port")
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

Capture `SESSION_ID`, `DATA_DIR`, `APP_NAME`, and `PORT` from the output.

Note: `PM2_BIN` may be set by the caller's environment to point at a specific pm2 binary;
otherwise `which pm2` resolves it. This is the single PM2-resolution snippet used again
verbatim in Step 8 — edit both together if the discovery pattern ever changes.

### Step 2 — Start the swarm session

Dispatch a sub-agent (Haiku). Using the MCP server at `http://localhost:${PORT}/mcp`, call
`start_session` with the `SESSION_ID` from Step 1. Include header
`Accept: application/json, text/event-stream`. Pass `session_id` explicitly — it is never
ambient (Bus session rules, above).

### Step 3 — Wave 1: Independent Analysis (11 agents in parallel)

In a **single message**, dispatch all 11 agents simultaneously using the Agent tool, each
pinned to **Sonnet** (see Execution model). Each agent prompt must include:
- `session_id`: the SESSION_ID from Step 1 — pass it explicitly on every bus call the
  agent makes (Bus session rules, above); never assume it carries over from `start_session`.
- `data_dir`: the DATA_DIR from Step 1 (agent reads `$DATA_DIR/port` to connect)
- `artifact_paths`: path to the document being reviewed
- `reference_paths`: the three reference files every agent needs:
  - `~/.claude/skills/panel-review/references/agent-roles.md`
  - `~/.claude/skills/panel-review/references/agent-briefs.md`
  - `~/.claude/skills/panel-review/references/bus-schema.md`
- Instruction to read their **Wave 1 brief** from `references/agent-briefs.md`
- Instruction to read the bus schema from `references/bus-schema.md`
- Instruction: "After posting all findings, broadcast `PHASE1_DONE` to topic
  `rendezvous` with content `PHASE1_DONE | [your-agent-id] | [SESSION_ID]` and exit."

The 11 roles to dispatch (agent-id in parentheses):
1. Platform Engineer (`platform-engineer`)
2. DevOps Engineer (`devops-engineer`)
3. Staff Full Stack Engineer (`fullstack-engineer`)
4. Integration Architect (`integration-architect`)
5. Agent Context Designer (`context-designer`)
6. Orchestration Architect (`orchestration-architect`)
7. Project Planner (`project-planner`)
8. Principal Frontend Engineer (`frontend-engineer`)
9. Security Engineer (`security-engineer`)
10. Documentation Architect (`doc-architect`)
11. Foundations Technical Planner (`foundations-planner`)

> **Check ownership note:** `context-designer` owns the heaviest check load — panel-check-cold-read,
> panel-check-1, and panel-check-7. `integration-architect` owns panel-check-3 and panel-check-4, where
> panel-check-4 includes the full flow-scope trace (producer/consumer topic string comparison and
> payload schema verification). Operators debugging stalled reviews should inspect these agents first.

Wave 1 agents that have not signalled within 8 minutes will be treated as timed out by Gate 1.

Wait for all 11 Wave 1 agents to complete.

### Step 4 — Gate 1: Wait for all Phase 1 signals

Dispatch a single gate-checker sub-agent (Haiku). It polls topic `rendezvous` every 5
seconds, accumulating distinct `from_agent` values from `PHASE1_DONE | [agent-id] |
[SESSION_ID]` messages. It stops when 11 distinct agent IDs are collected or after 8
minutes.

**Exact `read_messages` call shape (mandatory — do not infer or abbreviate this).** Connect
to the MCP server exactly as in Step 1/2 (port from `$DATA_DIR/port`, header
`Accept: application/json, text/event-stream`). Every poll must be this literal shape:

```bash
curl -sf http://localhost:${PORT}/mcp \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  -d '{"jsonrpc":"2.0","method":"tools/call","params":{"name":"read_messages","arguments":{"agent_id":"gate1-checker","topics":["rendezvous"],"session_id":"[SESSION_ID]","peek":true}},"id":1}'
```

- `agent_id` is **REQUIRED** — the tool call fails without it. Use the fixed string
  `"gate1-checker"` as this poller's identity on every call.
- `topics` is the **plural array** `topics: ["rendezvous"]` — never singular `topic`.
  Without `topics`, `read_messages` returns ONLY messages addressed directly to
  `agent_id` and silently omits ALL broadcasts — `rendezvous` messages are broadcasts, so a
  call missing `topics` looks like a normal empty poll (no error) while actually seeing
  nothing, ever.
- `peek: true` is **REQUIRED** on every poll. Without it, a successful read writes delivery
  receipts for `gate1-checker`, and the SAME broadcast messages will never be returned to
  `gate1-checker` again on a later poll (the bus anti-joins rows this agent_id has already
  received) — the distinct-agent-id count would silently shrink back down instead of
  accumulating across polls.

**Distinguish an error response from a legitimately empty result — do not conflate them.**
- Empty-but-healthy poll: `{"messages": [], "data_dir": ..., "port": ...}` — no `error` key.
  Nobody has signalled yet; this is a normal reason to keep polling.
- Broken poll: `{"error": {"code": "...", "message": "..."}, "data_dir": ..., "port": ...}`
  — `read_messages` returns this as ordinary tool output (not a thrown exception, not an
  MCP-protocol-level error) whenever a required argument is missing or malformed, e.g.
  `agent_id` omitted or `topic` used instead of `topics`. **If ANY poll ever returns a
  top-level `error` key, stop polling immediately.** Do not treat it as "no messages yet"
  and do not continue polling to timeout. Report a stop-the-line ANOMALY instead of the
  normal gate result: `{ anomaly: true, reason: "bus read is broken", error: <the error
  object verbatim> }`.

The authoritative agent-id for each message comes from the `from_agent` field of the
message object — NOT from the content body. Use `from_agent` to de-duplicate signals.

Return `{ done: boolean, found: number, agents: string[], timedOut: boolean }` on a normal
(non-anomalous) poll cycle.

If `timedOut` is true and `found === 0`, halt — no findings available.

Capture the list of agents that did NOT signal (gate1TimedOut).

### Step 5 — Wave 2: Deliberation (11 agents in parallel)

Once Gate 1 confirms Phase 1 complete (or times out), dispatch all 11 agents again in a
**single message** for deliberation, each pinned to **Sonnet**. Each agent prompt must
include:
- `session_id`, `data_dir`, `artifact_paths` (session_id explicit on every call — Bus
  session rules, above)
- `reference_paths`: the three reference files every agent needs (same as Step 3)
- Instruction to read their **Wave 2 brief** from `references/agent-briefs.md`
- The list of agents that timed out in Wave 1 (gate1TimedOut, so they can skip orphaned checks)

Wave 2 agents start with a fully populated bus. They:
1. Read all findings from their Consulted topics
2. Post VALIDATE / CHALLENGE / ESCALATE / ADD responses
3. Accountable agents verify quorum and post CLOSED

Wait for all 11 Wave 2 agents to complete.

### Step 6 — Gate 2: Wait for all Phase 2 signals

Dispatch a gate-checker sub-agent (Haiku) to poll topic `phase2-rendezvous` until 11
distinct `PHASE2_DONE` signals are received (or 10 minutes have elapsed). Each Wave 2 agent
broadcasts `PHASE2_DONE | [agent-id] | [SESSION_ID]` to `phase2-rendezvous` after
completing deliberation.

**Exact `read_messages` call shape (mandatory — identical contract to Step 4/Gate 1, only
the topic and this poller's `agent_id` differ):**

```bash
curl -sf http://localhost:${PORT}/mcp \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  -d '{"jsonrpc":"2.0","method":"tools/call","params":{"name":"read_messages","arguments":{"agent_id":"gate2-checker","topics":["phase2-rendezvous"],"session_id":"[SESSION_ID]","peek":true}},"id":1}'
```

- `agent_id` is **REQUIRED** — use the fixed string `"gate2-checker"` on every call.
- `topics` is the **plural array** `topics: ["phase2-rendezvous"]` — never singular
  `topic`. Omitting it returns zero broadcasts with no error, indistinguishable from "nobody
  has signalled yet" unless you know to look for the missing key.
- `peek: true` is **REQUIRED** on every poll, for the same reason as Step 4 — without it,
  each read consumes the broadcast for `gate2-checker` and it will not reappear on the next
  poll, so the accumulated distinct-agent-id count would shrink instead of growing.

**Distinguish an error response from a legitimately empty result — do not conflate them**,
exactly as specified in Step 4: an empty `{"messages": []}` (no `error` key) is a healthy
"nobody yet" result and a reason to keep polling; a response carrying a top-level `error`
key (missing/malformed argument, e.g. `agent_id` omitted or `topic` instead of `topics`)
means the read is broken. If ANY poll ever returns an `error` key, stop polling
immediately — do not treat it as empty and do not poll to timeout. Report a stop-the-line
ANOMALY: `{ anomaly: true, reason: "bus read is broken", error: <the error object
verbatim> }` instead of the normal gate result.

Return the same structure as Step 4 (Gate 1) on a normal (non-anomalous) poll cycle. Capture
the list of agents that did NOT signal (gate2TimedOut).

If `timedOut` is true and `found === 0`, proceed to the synthesizer with a warning.

If an agent's deliberation content is present on its topics but its PHASE2_DONE signal is
absent, a completion-check agent may verify and relay the signal, recording the relay in
the final report — a stalled signal with genuine posted content is not a Wave 2 timeout.

### Step 7 — Dispatch the synthesizer

Dispatch a single synthesizer agent (Sonnet) with:
- `session_id` and `data_dir` (session_id passed explicitly, per Bus session rules above)
- Instruction to read `references/synthesizer-brief.md`
- `timed_out_checks`: structured as `{ gate1: [...], gate2: [...] }` — agent IDs from
  gate1TimedOut and gate2TimedOut respectively, so the synthesizer can distinguish Wave 1
  vs Wave 2 timeouts and label findings WAVE 1 UNRESOLVED, WAVE 2 UNRESOLVED, or FULLY
  UNRESOLVED accordingly

The synthesizer reads all bus messages and produces the Phase B report.

### Step 8 — Cleanup

Dispatch a cleanup agent (Haiku) to call `end_session` with the `SESSION_ID` via the MCP
tool (session_id passed explicitly — Bus session rules, above), then run:

```bash
APP_NAME="${APP_NAME}" DATA_DIR="${DATA_DIR}" bash -c '
  PM2=${PM2_BIN:-$(which pm2 2>/dev/null)}
  [ -n "$PM2" ] && [ -x "$PM2" ] && "$PM2" delete "$APP_NAME" 2>/dev/null || true
  [[ -n "$DATA_DIR" && "$DATA_DIR" == /tmp/* ]] && rm -rf "$DATA_DIR"
'
```

This is the identical PM2-resolution snippet from Step 1 — a single source of truth kept
in sync by editing both call sites together (see the note at the end of Step 1).

See `references/phase-b-c-severity.md` for Phase B (Requester Decides), Phase C (Apply
Approved Fixes), Severity Reference, and Reference Files.

## Red flags

| Rationalization | What to do instead |
|---|---|
| "This is a big, high-stakes doc, but I'll just run it through panel-consultation myself to save the bus overhead." | That's under-escalating a one-way-door / high-blast-radius artifact (`tools/review-ladder.md` §4) — panel-consultation (Rung 2) shares one context, so independence is only real at this rung. If the artifact genuinely needs this rung, use it; if it's medium-stakes, drop to Rung 2 instead of assuming panel-review is always safer. |
| "My Wave 1 agent finished fast, let it peek at peer findings for context." | Wave 1 is independent by design — reading peer bus topics during Wave 1 defeats the anchoring-avoidance premise real independent agents exist for. |
| "`start_session` already ran, so my broadcast/send_message will pick up the session automatically." | `session_id` is never ambient (discrepancy #6) — pass it explicitly on every single bus call, or the row is untagged and `end_session` won't clean it up. |
| "The agent looks stuck — check the health endpoint's `log_file` to see what it's doing." | That advertised path doesn't exist under PM2 (discrepancy #7) — read the PM2 logs for the session's `APP_NAME` instead. |
| "panel-check-9 sounds like doc-reviewer's Check 9, let's treat them as the same finding." | They are unrelated taxonomies (panel-check-9 is Security Engineer's domain; doc-reviewer's Check 9 is the Export Surface Check) — see `references/bus-schema.md`'s naming note. Never cross-reference by bare number. |
| "The PM2 binary isn't where I expect — hardcode a machine-specific fallback path back in." | Resolve via `which pm2` or the `PM2_BIN` env var (Step 1/8); a hardcoded work-machine path is exactly what the Gate 2 hygiene pass removed and must not be reintroduced. |

## Exit criteria

- [ ] All 11 Wave 1 agents posted FINDING/PASS for every owned check and signalled
      `PHASE1_DONE`, or timeouts are recorded and passed through to Wave 2 and the
      synthesizer.
- [ ] All 11 Wave 2 agents completed deliberation and each Accountable agent posted
      `CLOSED` for every check it owns, or timeouts are recorded.
- [ ] The synthesizer's Phase B report includes: severity summary, findings table with
      RACI + C responses, deliberation trails for Blocking findings, a timed-out-threads
      section (if any), and an overall verdict.
- [ ] No fix is applied without explicit requester confirmation (Phase C gate).
- [ ] Session cleaned up: `end_session` called, pm2 app deleted, scratch `DATA_DIR` removed.

## Provenance

Provenance: Hermes skill learnings/skill-sharing (imported from learnings/skill-sharing.md; the recorded port friction)
Lineage: X-context-docs skills/panel-review@0e9281e
