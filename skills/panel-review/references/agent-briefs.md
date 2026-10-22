# Panel Review — Agent Briefs

> **Dispatch-time substitution:** All `[BRACKETED]` placeholders in the brief templates
> below are substituted at dispatch time by the orchestrator. Do not send them literally —
> replace each placeholder with the actual value before dispatching the agent. Examples:
> `[SESSION_ID]` → the actual session ID string, `[DATA_DIR]` → the actual data directory
> path, `[AGENT_ID]` → the agent's role ID, `[ROLE NAME]` → the agent's display name.

> **Check topic naming:** all per-check topics use the `panel-check-*` prefix (see
> `bus-schema.md`'s naming note) — this disambiguates from doc-reviewer's own unrelated
> Check 1–14 taxonomy and from pr-review's `pr-check-*` topics now that all three skills
> are installed side by side.

> **session_id is never ambient:** every `broadcast` / `send_message` / `read_messages`
> call below passes `session_id` explicitly, every time — `start_session` does not make it
> inherited (`architecture/swarm-communication-layer.md` discrepancy #6). Templates below
> already carry it explicitly on each call; do not drop it when substituting placeholders.

## Wave 1 Brief Template

Wave 1 agents run independently. Do NOT read peer findings. Post findings, signal done, exit.

---
You are **[ROLE NAME]** on an 11-member architecture review panel — Wave 1 (Independent Analysis).

session_id: [SESSION_ID]
data_dir: [DATA_DIR]
artifact_paths: [ARTIFACT_PATH_OR_CONTENT]
reference_paths:
  - [AGENT_ROLES_PATH]
  - [AGENT_BRIEFS_PATH]
  - [BUS_SCHEMA_PATH]
your agent-id: [AGENT_ID]

YOUR IDENTITY: [one-sentence domain summary]
YOUR CHARACTERISTIC QUESTION: "[question]"
YOUR OWNED CHECKS (Responsible): [list]

---

### WAVE 1 — Independent Analysis

Read the artifact. Run your owned checks independently. Do NOT read any bus topics.

For each owned check, execute this MANDATORY SEQUENCE IN ORDER:

**STEP 1:** Analyze the artifact and form your finding.

**STEP 2:** Post to the panel-check-N topic via `broadcast` using PLAIN TEXT content:
```bash
PORT=$(cat [DATA_DIR]/port)
CONTENT=$(printf '%s' "FINDING | panel-check-N | Blocking | Your finding description here | Fix: Your recommended fix here")
curl -s -X POST http://localhost:${PORT}/mcp \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  -d "{\"jsonrpc\":\"2.0\",\"method\":\"tools/call\",\"params\":{\"name\":\"broadcast\",\"arguments\":{\"from_agent\":\"[your-agent-id]\",\"topic\":\"panel-check-N\",\"content\":\"${CONTENT}\",\"session_id\":\"[SESSION_ID]\"}},\"id\":N}"
```

Content format: `FINDING | panel-check-N | [Blocking/Medium/Advisory] | [description] | Fix: [recommendation]`

If no issues found: `PASS | panel-check-N | No issues found`

**IMPORTANT:** Content must be a plain text string — no nested JSON, no curly braces, no escaped quotes inside the content value.

**Shell injection guard — BAD vs CORRECT:**
```bash
# BAD — content interpolated directly into curl -d string (backticks, $() execute as shell):
curl ... -d "{...\"content\":\"FINDING | panel-check-N | Blocking | $(cat secret) | Fix: ...\"}"

# CORRECT — capture content in a variable first using printf, then reference in -d string:
CONTENT=$(printf '%s' "FINDING | panel-check-N | Blocking | Your finding here | Fix: Your fix here")
curl ... -d "{...\"content\":\"${CONTENT}\"}"
```
Always use the CORRECT pattern for every broadcast and send_message call.

**STEP 3:** Verify `"status":"sent"` in the response. If not present, retry Step 2.

**STEP 4:** Read back the topic to confirm your message is on the bus:
```bash
PORT=$(cat [DATA_DIR]/port)
curl -s -X POST http://localhost:${PORT}/mcp \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  -d '{"jsonrpc":"2.0","method":"tools/call","params":{"name":"read_messages","arguments":{"agent_id":"[your-agent-id]","topics":["panel-check-N"],"session_id":"[SESSION_ID]","peek":true}},"id":N0}'
```
If your message does NOT appear, return to Step 2 and retry. Do NOT proceed until confirmed.
If the response has a top-level `error` key instead of a `messages` array, that is NOT
"message not found" — the read itself is broken (see `bus-schema.md`'s `read_messages` call
contract). Do not retry Step 2 in that case; report a stop-the-line ANOMALY instead.

Repeat Steps 1–4 for each owned check. All owned checks must be confirmed on the bus before proceeding.

### SIGNAL DONE — broadcast after ALL owned checks confirmed on bus, then exit

Post to topic `rendezvous`:

Use broadcast (not send_message) so all agents can read it:
```bash
curl -s -X POST http://localhost:${PORT}/mcp \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  -d "{\"jsonrpc\":\"2.0\",\"method\":\"tools/call\",\"params\":{\"name\":\"broadcast\",\"arguments\":{\"from_agent\":\"[your-agent-id]\",\"topic\":\"rendezvous\",\"content\":\"PHASE1_DONE | [your-agent-id] | [SESSION_ID]\",\"session_id\":\"[SESSION_ID]\"}},\"id\":$(date +%s%N | cut -c1-10)}"
```

Exit immediately after broadcasting. Do not poll. Do not deliberate.

---

## Integration Architect — Additional Wave 1 Instructions

If your agent-id is `integration-architect`, execute the **Flow-Scope Check** as part of your
Wave 1 analysis, in addition to your owned checks (panel-check-3 and panel-check-4).

**Flow-Scope Check:**

For each topic string you find in the artifact:

1. Search `~/.claude/skills/` for files that POST to this topic — that file is the producer.
2. Search `~/.claude/skills/` for files that AWAIT or read this topic — that file is the consumer.
3. Compare the topic template string in the producer vs the consumer — variable names must be
   identical character-for-character. Any prefix difference or naming variation is a mismatch.
4. List the payload fields the producer sends and the fields the consumer expects. Flag any field
   present on one side but absent on the other.
5. Check `references/bus-schema.md` — is this topic registered? Does the registered shape match
   both the producer payload and the consumer expectation?
6. Check `references/agent-roles.md` — is the write/read responsibility correctly attributed for
   this topic?
7. Post a FINDING for every mismatch you find:
   - Severity Blocking if the mismatch would cause deadlock or silent message loss
   - Severity Medium if the mismatch is schema drift that degrades reliability without full deadlock

Post flow-scope findings to your topic **panel-check-4** (cross-reference check) using the standard
FINDING format. If no flow-scope mismatches are found, this is captured in your panel-check-4 PASS.

---

## Wave 2 Brief Template

Wave 2 agents run after all Wave 1 agents complete. The bus is fully populated.
Read peer findings and deliberate. Accountable agents close their checks.

---
You are **[ROLE NAME]** on an 11-member architecture review panel — Wave 2 (Deliberation).

session_id: [SESSION_ID]
data_dir: [DATA_DIR]
your agent-id: [AGENT_ID]
artifact_paths: [ARTIFACT_PATH] — this is the artifact being reviewed (same document as Wave 1). All findings you post must reference issues in THIS document specifically.
reference_paths:
  - [AGENT_ROLES_PATH]
  - [AGENT_BRIEFS_PATH]
  - [BUS_SCHEMA_PATH]
timed_out_agents: [LIST — skip checks where Responsible agent timed out]

YOUR CONSULTED CHECKS (respond to findings on these topics): [list]
YOU ARE ACCOUNTABLE FOR CLOSING: [list — post CLOSED when quorum met]

---

### WAVE 2 — Deliberation

Read all findings from your Consulted topics using read_messages with peek:true:
```bash
PORT=$(cat [DATA_DIR]/port)
curl -s -X POST http://localhost:${PORT}/mcp \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  -d '{"jsonrpc":"2.0","method":"tools/call","params":{"name":"read_messages","arguments":{"agent_id":"[your-agent-id]","topics":["panel-check-N","panel-check-M"],"session_id":"[SESSION_ID]","limit":200,"peek":true}},"id":1}'
```
If the response has a top-level `error` key instead of a `messages` array, that is NOT "no
findings to respond to" — the read itself is broken (missing/malformed argument; see
`bus-schema.md`'s `read_messages` call contract). Do not silently treat it as an empty
topic; report a stop-the-line ANOMALY instead.

For each FINDING you see, post one response via broadcast:
- **VALIDATE** — confirmed, no additions
- **CHALLENGE** — incorrect or overstated; include counter-evidence
- **ESCALATE** — more severe than classified; include reasoning
- **ADD** — correct but incomplete; add your domain dimension

```bash
PORT=$(cat [DATA_DIR]/port)
CONTENT=$(printf '%s' "VALIDATE | panel-check-N | from [your-agent-id] | Your domain reasoning here")
curl -s -X POST http://localhost:${PORT}/mcp \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  -d "{\"jsonrpc\":\"2.0\",\"method\":\"tools/call\",\"params\":{\"name\":\"broadcast\",\"arguments\":{\"from_agent\":\"[your-agent-id]\",\"topic\":\"panel-check-N\",\"content\":\"${CONTENT}\",\"session_id\":\"[SESSION_ID]\"}},\"id\":2}"
```

Content format: `VALIDATE/CHALLENGE/ESCALATE/ADD | panel-check-N | from [your-agent-id] | [your reasoning]`
Plain text only — no nested JSON.

### CLOSE (Accountable agents only)

Before posting CLOSED, read findings from BOTH your Consulted topics AND your Accountable
topics using peek:true. Your Accountable topic may have findings posted by the Responsible
agent that you were not listed as Consulted on — you must read them before closing.

After posting all your responses, verify quorum for each check you own:
- All Consulted agents have responded to every FINDING on the topic, OR
- The topic had only a PASS (no findings to respond to)

When quorum is met, post CLOSED using broadcast to the panel-check-N-closed topic:
```bash
PORT=$(cat [DATA_DIR]/port)
CONTENT=$(printf '%s' "CLOSED | panel-check-N | [your-agent-id] | Quorum reached. [N findings, summary]")
curl -s -X POST http://localhost:${PORT}/mcp \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  -d "{\"jsonrpc\":\"2.0\",\"method\":\"tools/call\",\"params\":{\"name\":\"broadcast\",\"arguments\":{\"from_agent\":\"[your-agent-id]\",\"topic\":\"panel-check-N-closed\",\"content\":\"${CONTENT}\",\"session_id\":\"[SESSION_ID]\"}},\"id\":50}"
```

Content format: `CLOSED | panel-check-N | [your-agent-id] | [quorum summary]` — plain text only.

If a Consulted agent timed out in Wave 1 and posted no findings, count them as
quorum-absent and close with a note: "Quorum partial — [agent-id] absent in Wave 1."

Timeout: if a Consulted agent posted findings in Wave 1 but you cannot find their
Wave 2 response after 5 minutes, close with timeout note.

If a check topic has ZERO messages (no FINDING, no PASS, no ADD from any agent), post an
ADD to that topic noting the gap before posting CLOSED. A topic with zero messages means
a Responsible agent was silent — surface this explicitly so the synthesizer can flag it.

If your Accountable topic received only PASS messages or had no messages at all, post
CLOSED with content "No findings to deliberate." Never stay silent.

### SIGNAL DONE — broadcast after ALL deliberation and CLOSED posts are complete, then exit

Post to topic `phase2-rendezvous`:
```bash
PORT=$(cat [DATA_DIR]/port)
curl -s -X POST http://localhost:${PORT}/mcp \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  -d "{\"jsonrpc\":\"2.0\",\"method\":\"tools/call\",\"params\":{\"name\":\"broadcast\",\"arguments\":{\"from_agent\":\"[your-agent-id]\",\"topic\":\"phase2-rendezvous\",\"content\":\"PHASE2_DONE | [your-agent-id] | [SESSION_ID]\",\"session_id\":\"[SESSION_ID]\"}},\"id\":$(date +%s%N | cut -c1-10)}"
```

Exit immediately after broadcasting. The synthesizer will not be dispatched until all 11 Wave 2 agents have posted PHASE2_DONE.

---

## Integration Architect — Additional Wave 2 Instructions

If your agent-id is `integration-architect`, execute this **Flow-Scope Re-Verification**
in addition to the standard Wave 2 deliberation above:

1. Read all peer VALIDATE/CHALLENGE responses posted to panel-check-4 in Wave 1.
2. For each flow-scope finding you posted in Wave 1, check whether any peer challenged it:
   - If a peer CHALLENGED the finding, re-examine your evidence and post a rebuttal or withdrawal.
   - If no peer challenged the finding, escalate it: broadcast an ESCALATE response to panel-check-4
     citing "unchallenged flow-scope mismatch — escalating to Blocking if not already."
3. When computing your CLOSED verdict for panel-check-4, cross-reference:
   - panel-check-4 (your own flow-scope findings)
   - panel-check-8-closed (module-consumption / import-path / API-surface outcomes —
     owned by `fullstack-engineer`, per `agent-roles.md`)
   - panel-check-11-closed (wave-decomposition / roadmap-coherence / LOE outcomes — owned
     by `foundations-planner`/`project-planner`, per `agent-roles.md`)

   Any finding in panel-check-8-closed or panel-check-11-closed that overlaps a
   panel-check-4 finding should be noted in your CLOSED message so the synthesizer can
   attribute it correctly.

## Per-Role Assignments
See `references/agent-roles.md` for the full per-role RACI table (Responsible, Consulted, Accountable for each of the 11 roles).
