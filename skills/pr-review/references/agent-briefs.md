# PR Review — Agent Briefs

> **Dispatch-time substitution:** All `[BRACKETED]` placeholders in the brief templates
> below are substituted at dispatch time by the orchestrator. Do not send them literally —
> replace each placeholder with the actual value before dispatching the agent. Examples:
> `[SESSION_ID]` → the actual session ID string, `[DATA_DIR]` → the actual data directory
> path, `[AGENT_ID]` → the agent's role ID, `[ROLE NAME]` → the agent's display name.

> **Check topic naming:** all per-check topics use the `pr-check-*` prefix (see
> `bus-schema.md`'s naming note) — this disambiguates from doc-reviewer's own unrelated
> Check 1–14 taxonomy now that both skills are installed side by side.

> **session_id is never ambient:** every `broadcast` / `send_message` / `read_messages`
> call below passes `session_id` explicitly, every time — `start_session` does not make it
> inherited (architecture/swarm-communication-layer.md discrepancy #6). Templates below
> already carry it explicitly on each call; do not drop it when substituting placeholders.

## Phase 1 Brief Template

Phase 1 agents run independently. Do NOT read peer findings. Post findings, signal done, exit.

---
You are **[ROLE NAME]** on a 7-member code review panel — Phase 1 (Independent Analysis).

session_id: [SESSION_ID]
data_dir: [DATA_DIR]
diff_path: [DIFF_PATH]
repo: [REPO]
pr_number: [PR_NUMBER]
# local-diff mode: replace the two lines above with
#   repo_dir: [REPO_DIR]   base_ref: [BASE_REF]   head_ref: [HEAD_REF]   head_sha: [HEAD_SHA]
#   and read files only via `git -C "$REPO_DIR" show "$HEAD_SHA:<path>"` (never the working tree, never a write)
artifact_paths:
  - [DIFF_PATH]
reference_paths:
  - [AGENT_ROLES_PATH]
  - [AGENT_BRIEFS_PATH]
  - [BUS_SCHEMA_PATH]
your agent-id: [AGENT_ID]

YOUR IDENTITY: [one-sentence domain summary]
YOUR CHARACTERISTIC QUESTION: "[question]"
YOUR OWNED CHECKS (Responsible): [list]

---

### PHASE 1 — Independent Analysis

Read the diff at diff_path. Run your owned checks independently. Do NOT read any bus topics.

For each owned check, execute this MANDATORY SEQUENCE IN ORDER:

**STEP 1:** Analyze the diff and form your finding.

**STEP 2:** Post to the pr-check-N topic via `broadcast` using PLAIN TEXT content:
```bash
PORT=$(cat [DATA_DIR]/port)
CONTENT=$(printf '%s' "FINDING | pr-check-N | Blocking | Your finding description here | Fix: Your recommended fix here")
curl -s -X POST http://localhost:${PORT}/mcp \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  -d "{\"jsonrpc\":\"2.0\",\"method\":\"tools/call\",\"params\":{\"name\":\"broadcast\",\"arguments\":{\"from_agent\":\"[your-agent-id]\",\"topic\":\"pr-check-N\",\"content\":\"${CONTENT}\",\"session_id\":\"[SESSION_ID]\"}},\"id\":N}"
```

Content format: `FINDING | pr-check-N | [Blocking/Medium/Advisory] | [description] | Fix: [recommendation]`

If no issues found: `PASS | pr-check-N | No issues found`

**IMPORTANT:** Content must be a plain text string — no nested JSON, no curly braces, no escaped quotes inside the content value.

**Shell injection guard — BAD vs CORRECT:**
```bash
# BAD — content interpolated directly into curl -d string (backticks, $() execute as shell):
curl ... -d "{...\"content\":\"FINDING | pr-check-N | Blocking | $(cat secret) | Fix: ...\"}"

# CORRECT — capture content in a variable first using printf, then reference in -d string:
CONTENT=$(printf '%s' "FINDING | pr-check-N | Blocking | Your finding here | Fix: Your fix here")
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
  -d '{"jsonrpc":"2.0","method":"tools/call","params":{"name":"read_messages","arguments":{"agent_id":"[your-agent-id]","topics":["pr-check-N"],"session_id":"[SESSION_ID]","peek":true}},"id":N0}'
```
If your message does NOT appear, return to Step 2 and retry. Do NOT proceed until confirmed.

Repeat Steps 1–4 for each owned check. All owned checks must be confirmed on the bus before proceeding.

### SIGNAL DONE — broadcast after ALL owned checks confirmed on bus, then exit

Post to topic `rendezvous` using broadcast (not send_message) so the gate-checker can read it:
```bash
PORT=$(cat [DATA_DIR]/port)
curl -s -X POST http://localhost:${PORT}/mcp \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  -d "{\"jsonrpc\":\"2.0\",\"method\":\"tools/call\",\"params\":{\"name\":\"broadcast\",\"arguments\":{\"from_agent\":\"[your-agent-id]\",\"topic\":\"rendezvous\",\"content\":\"PHASE1_DONE | [your-agent-id] | [SESSION_ID]\",\"session_id\":\"[SESSION_ID]\"}},\"id\":$(date +%s%N | cut -c1-10)}"
```

Exit immediately after broadcasting. Do not poll. Do not deliberate.

---

## Phase 2 Brief Template

Phase 2 agents run after all Phase 1 agents complete. The bus is fully populated.
Read peer findings and deliberate. Accountable agents close their checks.

---
You are **[ROLE NAME]** on a 7-member code review panel — Phase 2 (Deliberation).

session_id: [SESSION_ID]
data_dir: [DATA_DIR]
diff_path: [DIFF_PATH]
repo: [REPO]
pr_number: [PR_NUMBER]
# local-diff mode: replace the two lines above with
#   repo_dir: [REPO_DIR]   base_ref: [BASE_REF]   head_ref: [HEAD_REF]   head_sha: [HEAD_SHA]
#   and read files only via `git -C "$REPO_DIR" show "$HEAD_SHA:<path>"` (never the working tree, never a write)
artifact_paths:
  - [DIFF_PATH]
reference_paths:
  - [AGENT_ROLES_PATH]
  - [AGENT_BRIEFS_PATH]
  - [BUS_SCHEMA_PATH]
your agent-id: [AGENT_ID]
timed_out_agents: [LIST — skip checks where Responsible agent timed out in Phase 1]

YOUR CONSULTED CHECKS (respond to findings on these topics): [list]
YOU ARE ACCOUNTABLE FOR CLOSING: [list — post CLOSED when quorum met]

---

### PHASE 2 — Deliberation

Read all findings from your Consulted topics using read_messages with peek:true:
```bash
PORT=$(cat [DATA_DIR]/port)
curl -s -X POST http://localhost:${PORT}/mcp \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  -d '{"jsonrpc":"2.0","method":"tools/call","params":{"name":"read_messages","arguments":{"agent_id":"[your-agent-id]","topics":["pr-check-N","pr-check-M"],"session_id":"[SESSION_ID]","limit":200,"peek":true}},"id":1}'
```

For each FINDING you see, post one response via broadcast:
- **VALIDATE** — confirmed, no additions
- **CHALLENGE** — incorrect or overstated; include counter-evidence
- **ESCALATE** — more severe than classified; include reasoning
- **ADD** — correct but incomplete; add your domain dimension

```bash
PORT=$(cat [DATA_DIR]/port)
CONTENT=$(printf '%s' "VALIDATE | pr-check-N | from [your-agent-id] | Your domain reasoning here")
curl -s -X POST http://localhost:${PORT}/mcp \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  -d "{\"jsonrpc\":\"2.0\",\"method\":\"tools/call\",\"params\":{\"name\":\"broadcast\",\"arguments\":{\"from_agent\":\"[your-agent-id]\",\"topic\":\"pr-check-N\",\"content\":\"${CONTENT}\",\"session_id\":\"[SESSION_ID]\"}},\"id\":2}"
```

Content format: `VALIDATE/CHALLENGE/ESCALATE/ADD | pr-check-N | from [your-agent-id] | [your reasoning]`
Plain text only — no nested JSON.

### CLOSE (Accountable agents only)

After posting all your responses, verify quorum for each check you own:
- All Consulted agents have responded to every FINDING on the topic, OR
- The topic had only a PASS (no findings to respond to)

When quorum is met, post CLOSED using broadcast to the pr-check-N-closed topic:
```bash
PORT=$(cat [DATA_DIR]/port)
CONTENT=$(printf '%s' "CLOSED | pr-check-N | [your-agent-id] | Quorum reached. [N findings, summary]")
curl -s -X POST http://localhost:${PORT}/mcp \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  -d "{\"jsonrpc\":\"2.0\",\"method\":\"tools/call\",\"params\":{\"name\":\"broadcast\",\"arguments\":{\"from_agent\":\"[your-agent-id]\",\"topic\":\"pr-check-N-closed\",\"content\":\"${CONTENT}\",\"session_id\":\"[SESSION_ID]\"}},\"id\":50}"
```

Content format: `CLOSED | pr-check-N | [your-agent-id] | [quorum summary]` — plain text only.

Poll timeout: stop polling after 10 minutes on any thread without quorum.

If a Consulted agent timed out in Phase 1 and posted no findings, count them as
quorum-absent and close with a note: "Quorum partial — [agent-id] absent in Phase 1."

If a check topic has ZERO messages (no FINDING, no PASS from any agent), post an ADD
noting the gap before posting CLOSED — a silent Responsible agent must be surfaced.

### SIGNAL DONE — broadcast after ALL deliberation and CLOSED posts complete, then exit

Post to topic `phase2-rendezvous`:
```bash
PORT=$(cat [DATA_DIR]/port)
curl -s -X POST http://localhost:${PORT}/mcp \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  -d "{\"jsonrpc\":\"2.0\",\"method\":\"tools/call\",\"params\":{\"name\":\"broadcast\",\"arguments\":{\"from_agent\":\"[your-agent-id]\",\"topic\":\"phase2-rendezvous\",\"content\":\"PHASE2_DONE | [your-agent-id] | [SESSION_ID]\",\"session_id\":\"[SESSION_ID]\"}},\"id\":$(date +%s%N | cut -c1-10)}"
```

Exit immediately after broadcasting. The synthesizer is not dispatched until all 7 Phase 2 agents have posted PHASE2_DONE.

---

## Per-Role Assignments

See `agent-roles.md` for per-role RACI assignments (Responsible, Consulted, Accountable for each of the 7 roles).
