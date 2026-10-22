---
name: pr-review
description: >
  Real 7-agent code review panel: each agent independently reads the PR diff, runs
  domain-specific checks, and deliberates live over the swarm communication bus; an 8th
  synthesizer compiles a findings table with full RACI attribution and presents Phase B.
  Use when asked to: review this PR, run the panel on this PR, check this PR, review this
  substantial PR/diff before merge (for a small or mechanical diff, review directly at
  Rung 0 or use doc-reviewer, Rung 1), or any variation of "review before we merge." This is Rung 3
  on the review ladder (tools/review-ladder.md): independent-agent bus deliberation for
  substantial code diffs/PRs. For a single-context simulated panel on a design, doc, or
  idea with no code diff, use panel-consultation instead (Rung 2, no infra). For a
  one-way-door or high-blast-radius decision needing 11-agent quorum, escalate to
  panel-review instead (Rung 4).
---

# PR Review

A real 7-agent code review panel. Each agent reads the PR diff independently, runs
domain-specific checks, and deliberates via the swarm communication bus. An 8th
synthesizer compiles a findings table with RACI attribution and presents Phase B.

## Trigger

Use when asked to review a PR, "run the panel," "check this PR," "review these changes,"
"look at this diff," or any variant of "review before we merge." This is **Rung 3** on the
review ladder (`tools/review-ladder.md`): independent agents + live bus deliberation,
reserved for substantial code diffs/PRs. It is not a substitute for panel-consultation
(Rung 2) when there's no code diff — a design decision, an architecture question, or a
prose/doc artifact belongs there instead, without the bus overhead. It is not a substitute
for panel-review (Rung 4) when the decision is a one-way door with high blast radius and
11-agent quorum is warranted.

## What makes this different from a solo review

A solo reviewer anchors on their domain and fills in gaps from context. These 7 agents
cannot see each other's findings during Phase 1 — each arrives at findings independently.
They exchange challenges, validations, and escalations live over the bus. The output shows
which findings were challenged, escalated, or unanimously validated.

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
  the PM2-managed log files), not the advertised `log_file`.

Measured on the live bus, 2026-10-09 (T-141/T-159 reviews) — facts, not rules:

- Each member session starts its own bus app on its own port; none binds 7777 or another member's port.
- Before binding, `lsof -nP -iTCP:$PORT -sTCP:LISTEN` must be empty; otherwise add 10 and re-check. (owner rule 2026-10-08 19:08Z, R-x)
- `read_messages` takes `session_id` (mandatory on every call), `agent_id` and `topics` as an ARRAY.
- `broadcast` posts need `session_id` (mandatory on every call), `from_agent`, `topic` and `content`.
- A reply's `data_dir` shows the app's directory, not the session id (expected).

Port discovery is **never hardcoded**: every step below reads `$DATA_DIR/port`, written by
the server itself after `get-port` resolves it — this matches the live-bus fact that the
port is discovered from `data/port`, currently 7777 for the standing `swarm-mcp` PM2 app,
but each review session in this skill starts its **own** isolated bus instance (own
`DATA_DIR`, own `APP_NAME`, own port) rather than reusing that standing instance — per the
architecture record, each session gets its own DB file and port; a shared server would
serialize all concurrent reviews through one writer.

## Pre-flight

Mode: env `PR_REVIEW_MODE` — unset or `pr` = the PR flow below; `local-diff` = see "Local-diff mode"
(next subsection). Everything in this skill is pr mode unless a step says "In local-diff mode".

Required caller inputs in pr mode (must be present in the dispatch prompt):
- `REPO` — repository in `owner/repo` format (e.g., `octocat/hello-world`)
- `PR_NUMBER` — pull request number (integer)

In pr mode, if the work unit has no GitHub PR (this workspace's default integration is worktree →
local merge → push, Rule 6/ADR 0017), this skill does not apply — review the diff at Rung
1/2, or create a PR first if Rung 3 independence is genuinely warranted.

These values must be substituted into the dispatch prompt before invoking the skill. The
skill does not prompt for missing inputs.

### Local-diff mode (`PR_REVIEW_MODE=local-diff`)

Review a local `git diff` with no GitHub PR; the review record goes to a file instead of a PR
comment. Authority: `plans/task-pipeline/tasks/12-repo-port-02.md` and ADR 0048:216-222; every
choice here is a brain default under R-q (owner may veto). Differences from pr mode, all in one place:

- **Inputs** (replace `REPO`/`PR_NUMBER`, which are absent and not required): `REPO_DIR` (git checkout
  holding both refs; read-only for the whole run), `BASE_REF`, `HEAD_REF` (ref or sha), `RECORD_PATH`
  (absolute, outside the reviewed tree, e.g. the caller's scratchpad).
- **Step 2:** `git -C "$REPO_DIR" diff "$BASE_REF...$HEAD_REF"` replaces `gh pr diff`; capture `HEAD_SHA`.
- **Steps 4/6/8:** prompt fields `repo_dir`/`base_ref`/`head_ref`/`head_sha` replace `repo`/`pr_number`;
  agents read files only via `git -C "$REPO_DIR" show "$HEAD_SHA:<path>"`, never the working tree, never a write.
- **Step 8:** the orchestrator writes `RECORD_PATH` (header format and identity grep in Step 8).
- **No `gh` call, no network, no network-check** (see Network Unavailable). Phase C: approved fixes go in the author's `wt/` worktree, never `REPO_DIR`.

## Execution model — model pin per dispatch (Rule 3/4, `tools/model-routing.md`)

Every dispatch below must pin a model explicitly per hq global Rule 3, matched to task
difficulty per Rule 4 (mirrors how review-validator and fix-verifier already handle this).
A full run is up to 20 dispatches; the mechanical ones are cheap, the judgment ones are not:

| Dispatch | Count | Model | Rationale |
|---|---|---|---|
| Step 1 — bus startup | 1 | Haiku | Mechanical: start pm2, poll for the port file, health-check |
| Step 2 — diff fetch | 1 | Haiku | Mechanical: validate inputs, `gh pr diff` (local-diff: `git diff`), write to scratch |
| Step 4 — Phase 1 domain-check agents | 7 | Sonnet | Judgment: read the diff, form findings against owned checks |
| Step 5 — Gate 1 checker | 1 | Haiku | Mechanical: poll a bus topic, count distinct agent ids |
| Step 6 — Phase 2 deliberation agents | 7 | Sonnet | Judgment: evaluate peer findings, VALIDATE/CHALLENGE/ESCALATE/ADD |
| Step 7 — Gate 2 checker | 1 | Haiku | Mechanical: same as Gate 1 |
| Step 8 — synthesizer | 1 | Sonnet | Judgment: compile findings table, deliberation trails, verdict |
| Step 9 — cleanup | 1 | Haiku | Mechanical: `end_session`, pm2 delete, remove scratch files |

Each dispatch states an explicit, verifiable done condition and a stop-on-anomaly clause
per `tools/model-routing.md`'s dispatch checklist — a blocked gate or safety stop in any
report is stop-the-line for the orchestrator, never bypassed.

## Steps

### Step 1 — Start the per-session swarm bus

Dispatch a sub-agent (Haiku) to run this bash script:

```bash
PM2=${PM2_BIN:-$(which pm2 2>/dev/null)}
[ -n "${PM2}" ] && [ -x "${PM2}" ] || { echo '{"running":false,"error":"pm2 binary not found — set PM2_BIN or ensure pm2 is on PATH"}'; exit 1; }
SESSION_NAME="pr-review"
SESSION_UUID=$(uuidgen | tr '[:upper:]' '[:lower:]' | cut -c1-8)
SESSION_ID="swarm-${SESSION_NAME}-$(date +%Y%m%d)-${SESSION_UUID}"
DATA_DIR="/tmp/${SESSION_ID}"
APP_NAME="swarm-mcp-${SESSION_ID}"
mkdir -p "${DATA_DIR}/logs"
cd ~/projects/swarm-communication-layer || { echo "ERROR: sibling repo not found at ~/projects/swarm-communication-layer"; exit 1; }
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
Derive a `SESSION_SUFFIX` from the SESSION_ID leaf (e.g. `20260704-a3f2`).

Note: `PM2_BIN` may be set by the caller's environment to point at a specific pm2 binary;
otherwise `which pm2` resolves it. This is the single PM2-resolution snippet used again
verbatim in Step 9 — edit both together if the discovery pattern ever changes, and
reconcile with the swarm-communication skill's own bus-lifecycle reference once that skill
is ported (it documents the same start/health-check/cleanup sequence; the two must not
drift apart as independently-maintained copies).

### Step 2 — Fetch the PR diff

Dispatch a sub-agent (Haiku) to run:

```bash
DIFF_PATH="/tmp/pr-review-${SESSION_SUFFIX}.diff"
# Validate inputs before shell interpolation
echo "$REPO" | grep -qE '^[a-zA-Z0-9_.-]+/[a-zA-Z0-9_.-]+$' || { echo "ERROR: invalid REPO format — expected owner/repo"; exit 1; }
echo "$PR_NUMBER" | grep -qE '^[0-9]+$' || { echo "ERROR: invalid PR_NUMBER — must be an integer"; exit 1; }
gh pr diff --repo "$REPO" "$PR_NUMBER" > "$DIFF_PATH" || { echo "ERROR: gh pr diff failed — check repo and PR number"; exit 1; }
chmod 600 "$DIFF_PATH"
[ -s "$DIFF_PATH" ] || { echo "ERROR: diff is empty — PR may have no changes or gh failed silently"; exit 1; }
wc -c "${DIFF_PATH}"
```

Capture `DIFF_PATH`. Halt if the file is empty or gh fails.

In local-diff mode, dispatch the Haiku sub-agent to run this instead (no `gh`, no network):

```bash
DIFF_PATH="/tmp/pr-review-${SESSION_SUFFIX}.diff"
# Validate inputs; REPO_DIR is only ever read
git -C "$REPO_DIR" rev-parse --git-dir >/dev/null 2>&1 || { echo "ERROR: REPO_DIR is not a git checkout"; exit 1; }
git -C "$REPO_DIR" rev-parse --verify "$BASE_REF^{commit}" >/dev/null 2>&1 || { echo "ERROR: BASE_REF does not resolve"; exit 1; }
git -C "$REPO_DIR" rev-parse --verify "$HEAD_REF^{commit}" >/dev/null 2>&1 || { echo "ERROR: HEAD_REF does not resolve"; exit 1; }
case "$RECORD_PATH" in /*) ;; *) echo "ERROR: RECORD_PATH must be absolute"; exit 1;; esac; case "$RECORD_PATH" in "$(cd "$REPO_DIR" && pwd -P)"/*) echo "ERROR: RECORD_PATH is inside REPO_DIR"; exit 1;; esac
HEAD_SHA=$(git -C "$REPO_DIR" rev-parse "$HEAD_REF^{commit}")
git -C "$REPO_DIR" diff "$BASE_REF...$HEAD_REF" > "$DIFF_PATH" || { echo "ERROR: git diff failed"; exit 1; }
chmod 600 "$DIFF_PATH"
[ -s "$DIFF_PATH" ] || { echo "ERROR: diff is empty — nothing to review"; exit 1; }
wc -c "${DIFF_PATH}"
echo "HEAD_SHA=${HEAD_SHA}"
```

Capture `DIFF_PATH` and `HEAD_SHA`. Halt if the file is empty or either ref fails to resolve.

### Step 3 — Start the swarm session

Using the MCP server at `http://localhost:${PORT}/mcp`, call `start_session` with the
derived `SESSION_ID`. Include header `Accept: application/json, text/event-stream`.

### Step 4 — Phase 1: Dispatch all 7 panel agents in parallel

In a **single message**, dispatch all 7 agents simultaneously using the Agent tool, each
pinned to **Sonnet** (see Execution model). Each agent prompt must include:
- `session_id`: the SESSION_ID from Step 1 — pass it explicitly on every bus call the
  agent makes (bus session rules, above); never assume it carries over from `start_session`.
- `data_dir`: the DATA_DIR from Step 1 (agent reads `$DATA_DIR/port` to connect)
- `diff_path`: the DIFF_PATH from Step 2 (the PR diff being reviewed)
- `repo` and `pr_number` (pr mode); in local-diff mode instead `repo_dir`, `base_ref`, `head_ref`,
  `head_sha`, plus the instruction: read files only via `git -C "$REPO_DIR" show "$HEAD_SHA:<path>"`
  — never the working tree, never a write
- `agent-id`: the agent's own id from the list below
- `artifact_paths`: same as `diff_path` — listed separately so agents know it's the primary artifact
- `reference_paths`: the four reference files every agent needs:
  - `~/.claude/skills/pr-review/references/agent-roles.md`
  - `~/.claude/skills/pr-review/references/agent-briefs.md`
  - `~/.claude/skills/pr-review/references/bus-schema.md`
  - `~/.claude/skills/pr-review/references/phase-b-c-severity.md`
- Instruction to read their **Phase 1 brief** from `references/agent-briefs.md` and their
  role assignments from `references/agent-roles.md`
- Instruction to read the bus schema from `references/bus-schema.md`
- Instruction: "After posting all findings, broadcast `PHASE1_DONE` to topic `rendezvous`
  with content `PHASE1_DONE | [your-agent-id] | [SESSION_ID]` and exit."

The 7 roles to dispatch (agent-id in parentheses):
1. Platform/Infra Engineer (`platform-engineer`)
2. DevOps Engineer (`devops-engineer`)
3. Full Stack Engineer (`fullstack-engineer`)
4. Integration Architect (`integration-architect`)
5. Security Engineer (`security-engineer`)
6. Technical Writer (`technical-writer`)
7. Strategic Reviewer (`strategic-reviewer`)

> **Check ownership note:** `strategic-reviewer` is primary Responsible for
> `pr-check-cold-read`; `integration-architect` is co-Responsible. Operators debugging
> stalled cold reads should inspect strategic-reviewer first.

Each agent runs Phase 1 independently (no bus reads), then exits after signalling DONE.

Phase 1 agents that have not signalled within 8 minutes will be treated as timed out by Gate 1.

Wait for all 7 agents to complete.

### Step 5 — Gate 1: Wait for all Phase 1 signals

Dispatch a single gate-checker sub-agent (**Haiku**). It polls topic `rendezvous` every 5
seconds, collecting distinct `from_agent` values from messages whose content starts with
`PHASE1_DONE`. Stop when 7 distinct agent IDs are collected or after 8 minutes.

Return `{ done: boolean, found: number, agents: string[], timedOut: boolean }`.

If `timedOut` is true and `found === 0`, halt — no findings available.

Capture the list of agents that did NOT signal (gate1TimedOut).

### Step 6 — Phase 2: Deliberation (7 agents in parallel)

Once Gate 1 completes (or times out), dispatch all 7 agents again in a **single message**
for deliberation, each pinned to **Sonnet**. Each agent prompt must include:
- `session_id`: the SESSION_ID from Step 1 (explicit on every call — bus session rules, above)
- `data_dir`: the DATA_DIR from Step 1 (agent reads `$DATA_DIR/port` to connect)
- `diff_path`: the DIFF_PATH from Step 2 (the PR diff being reviewed)
- `repo` and `pr_number` (pr mode); in local-diff mode the same `repo_dir`/`base_ref`/`head_ref`/
  `head_sha` fields and `git show` read-only instruction as Step 4
- `agent-id`: the agent's own id
- `artifact_paths`: same as `diff_path`
- `reference_paths`: same four reference files as Step 4 (Phase 1 dispatch)
- Instruction to read their **Phase 2 brief** from `references/agent-briefs.md`
- The list of agents that timed out in Phase 1 (so they can skip orphaned checks)
- Instruction: "After posting all responses and CLOSED messages, broadcast `PHASE2_DONE`
  to topic `phase2-rendezvous` with content `PHASE2_DONE | [your-agent-id] | [SESSION_ID]`."

Wait for all 7 Phase 2 agents to complete.

### Step 7 — Gate 2: Wait for all Phase 2 signals

Dispatch a single gate-checker sub-agent (**Haiku**) to poll topic `phase2-rendezvous`
until 7 distinct `PHASE2_DONE` signals are received (or 10 minutes have elapsed). Return
the same structure as Step 5 (Gate 1). Capture gate2TimedOut agents.

If `timedOut` is true and `found === 0`, proceed to synthesizer with a warning.

### Step 8 — Dispatch the synthesizer

Dispatch a single synthesizer agent (**Sonnet**) with:
- `session_id` and `data_dir` (session_id passed explicitly, per bus session rules above)
- `repo`, `pr_number` (pr mode); in local-diff mode `repo_dir`, `base_ref`, `head_ref`, `head_sha`
- `timed_out_checks`: structured as `{ gate1: [...], gate2: [...] }` — agent IDs from
  gate1TimedOut and gate2TimedOut respectively, so the synthesizer can label findings
  PHASE 1 UNRESOLVED, PHASE 2 UNRESOLVED, or FULLY UNRESOLVED accordingly
- Instruction to read `references/synthesizer-brief.md`

The synthesizer reads all bus messages and produces the Phase B report.

In local-diff mode the orchestrator then writes `RECORD_PATH` from that report. Line 1 is
`CODE-GATE-REVIEW: PASS head=<HEAD_SHA> blocking=0 medium=0` only when both counts are 0, else
`CODE-GATE-REVIEW: FAIL head=<HEAD_SHA> blocking=<b> medium=<m>`. Line 2 is
`Reviewed-By: <member session name> <TASK id>`; then a blank line; then the Phase B report. File paths in
the record (`repo_dir`, `RECORD_PATH`, any path the report names) are written `~`-relative, never as an
absolute home path.

The orchestrator sets the snippet's inputs: `B`, `M` (counts from the Phase B verdict), `MEMBER_SESSION_NAME`,
`TASK_ID`, `PHASE_B_REPORT_FILE`.

```bash
# PASS only if B=0 and M=0; otherwise FAIL with the real counts
if [ "$B" -eq 0 ] && [ "$M" -eq 0 ]; then V=PASS; else V=FAIL; fi
printf 'CODE-GATE-REVIEW: %s head=%s blocking=%s medium=%s\nReviewed-By: %s %s\n\n' \
  "$V" "$HEAD_SHA" "$B" "$M" "$MEMBER_SESSION_NAME" "$TASK_ID" > "$RECORD_PATH"
cat "$PHASE_B_REPORT_FILE" >> "$RECORD_PATH"
# Identity check — no secrets or tokens in the record; must print 0
grep -cE 'sk-ant-|gh[opsu]_|github_pat_' "$RECORD_PATH"
```

The skill never writes `Verified-By:`; the D10 verifier (a different member) inserts it as line 3. Only a PASS
record is copied to `.review/`; a FAIL record stays with the author. The copy goes to `task-pipeline/.review/<head-sha>.md` in the merge commit (ADR 0049 §Gate). A grep
count other than 0 is a stop-on-anomaly: do not hand the record over.

### Step 9 — Cleanup

Dispatch a cleanup agent (**Haiku**) to call `end_session` with `SESSION_ID` via the MCP
tool (session_id passed explicitly — bus session rules, above), then run:

```bash
APP_NAME="${APP_NAME}" DATA_DIR="${DATA_DIR}" DIFF_PATH="${DIFF_PATH}" bash -c '
  PM2=${PM2_BIN:-$(which pm2 2>/dev/null)}
  [ -n "$PM2" ] && [ -x "$PM2" ] && "$PM2" delete "$APP_NAME" 2>/dev/null || true
  [[ -n "$DATA_DIR" && "$DATA_DIR" == /tmp/* ]] && rm -rf "$DATA_DIR"
  [[ -n "$DIFF_PATH" && "$DIFF_PATH" == /tmp/* ]] && rm -f "$DIFF_PATH"
'
```

This is the identical PM2-resolution snippet from Step 1 — a single source of truth kept
in sync by editing both call sites together (see the note at the end of Step 1).

See `references/phase-b-c-severity.md` for Phase B (Reviewer Decides), Phase C (Apply
Approved Fixes), Severity Reference, and Reference Files.

## Network Unavailable

In pr mode this skill makes outbound network calls: `gh pr diff` (GitHub API — fetches PR diff) and
`gh pr comment` (GitHub API — posts review comment).

In local-diff mode there is no `gh` call, no network use and no network-check; this section does not apply.

If network connectivity is unavailable when this skill is invoked (pr mode):
- Do not attempt any `gh` calls
- Log or echo: `[SKIPPED] network unavailable — pr-review skipped`
- Exit 0 in script/automated contexts (a non-zero exit would flip a launchd-tracked
  service unhealthy for what was an intentional skip)
- If running interactively: inform the user the review could not be completed and suggest
  retrying when connectivity is restored

Before any `gh` call (pr mode), run the connectivity pre-check at
`~/.claude/skills/network-check/scripts/check-network.sh` (exit 0 = reachable, exit 1 =
unreachable).

## Red flags

| Rationalization | What to do instead |
|---|---|
| "It's a big architecture doc, not code, but pr-review is already live — just point it at the doc." | pr-review is Rung 3 for substantial code diffs specifically (`tools/review-ladder.md`); prose/architecture docs go to panel-consultation (Rung 2) or panel-review (Rung 4), never pr-review. |
| "My Phase 1 agent finished fast, let it peek at peer findings for context." | Phase 1 is independent by design — reading peer bus topics during Phase 1 defeats the anchoring-avoidance premise this skill exists for (see "What makes this different from a solo review"). |
| "`start_session` already ran, so my broadcast/send_message will pick up the session automatically." | `session_id` is never ambient (discrepancy #6) — pass it explicitly on every single bus call, or the row is untagged and `end_session` won't clean it up. |
| "The agent looks stuck — check the health endpoint's `log_file` to see what it's doing." | That advertised path doesn't exist under PM2 (discrepancy #7) — read the PM2 logs for the session's `APP_NAME` instead. |
| (pr mode) "gh pr diff failed silently, but the bus started fine — proceed to Phase 1 anyway." | Step 2 explicitly halts on an empty diff file; a live bus with no diff produces a review of nothing. |
| "Local-diff mode: REPO_DIR is my own worktree, I'll just read the working tree." | Read only via `git -C "$REPO_DIR" show "$HEAD_SHA:<path>"`; the working tree may differ from `HEAD_SHA` and REPO_DIR is never written. |
| "The PM2 binary isn't where I expect — hardcode a machine-specific fallback path back in." | Resolve via `which pm2` or the `PM2_BIN` env var (Step 1/9); a hardcoded work-machine path is exactly what the Gate 2 hygiene pass removed and must not be reintroduced. |

## Exit criteria

- [ ] All 7 Phase 1 agents posted FINDING/PASS for every owned check and signalled
      `PHASE1_DONE`, or timeouts are recorded and passed through to Phase 2 and the
      synthesizer.
- [ ] All 7 Phase 2 agents completed deliberation and each Accountable agent posted
      `CLOSED` for every check it owns, or timeouts are recorded.
- [ ] The synthesizer's Phase B report includes: severity summary, findings table with
      RACI + C responses, deliberation trails for Blocking findings, a timed-out-threads
      section (if any), and an overall verdict.
- [ ] No fix is applied without explicit reviewer confirmation (Phase C gate).
- [ ] Session cleaned up: `end_session` called, pm2 app deleted, scratch `DATA_DIR` and
      diff file removed.

## Provenance

Provenance: Hermes skill learnings/skill-sharing (imported from learnings/skill-sharing.md)
Lineage: X-context-docs skills/pr-review@0e9281e
