# Subagent role contract — Fable ratification (ADR 0014 T5 + T6)

- **Verdict:** RATIFIED-WITH-AMENDMENTS (14 applied in place; 4 need the owner)
- **Date:** 2026-10-02 · **Ratifier:** Fable, dispatched one-shot (ADR 0014 §Decision 2)
- **Scope:** `wt/subagent-role-contract` @ `5b2815c` — `decisions/0043-subagent-role-contract.md`,
  `architecture/subagent-role-contract.md`, `plans/subagent-role-contract.md`, one `decisions/README.md` row
- **Governing intent (relayed, not witnessed):** owner 2026-10-02, "do not restrict agents from have
  nest sub agents. We just need agents to be aware of if they are a sub agent." Awareness only.
- **Ground truth re-read by the ratifier:** S0 `FINDINGS.md` + `payloads.log` (claude 2.1.287), the S0
  transcript dir, hooks.md and sub-agents.md (summarising fetch via WebFetch, 2026-10-02), ADRs 0014
  (+Addendum 1), 0021, 0029, 0037, `agents/topology-worker.md`, `config/settings.json` hooks block,
  `config/CLAUDE.md` Rules 2 and 9, memory notes `hq-main-push-grant-2026-09-17`,
  `no-large-state-log-files`, `cleanup-worktrees-keep-branches`, `scratchpad-shared-between-agents`.

## Independent verification table

| Claim (doc) | My check | Result |
|---|---|---|
| Hook stdin keys per event (ADR Ctx 4) | `cat payloads.log` (4 payloads) | Match: SubagentStart `session_id,transcript_path,cwd,prompt_id,agent_id,agent_type,hook_event_name`; PreToolUse adds `permission_mode,tool_name,tool_input,tool_use_id`; main-thread payload has no `agent_id` |
| `tool_input.subagent_type` absent when omitted | payloads 0 and 2 `tool_input` keys | `description,prompt,model` only — confirmed |
| `meta.json` has `spawnDepth`/`parentAgentId` | `cat` depth-2 meta in S0 dir + 2 more under `~/.claude/projects/*/…` | `spawnDepth:2`, `parentAgentId` present; absent at depth 1 |
| Depth path `${transcript_path%.jsonl}/subagents/agent-<id>.meta.json` | derived with jq from this session's payload shape, then `cat` | Resolves; `spawnDepth: 1` |
| `meta.json` readable at SubagentStart (S1 check item) | `stat -f %SB` vs `hook_success` timestamp, depth-1 | Born 05:57:33Z, hook done 05:57:32.841Z → **not readable**; depth-2 inconclusive (1 s resolution) |
| Banner lands at transcript lines 1–2 after the brief | `head -3 agent-a2126….jsonl \| jq` | user .824Z, `SubagentStart:general-purpose` hook_success .841Z, `hook_additional_context` .027Z |
| Hook latency < 1 s | `durationMs` across S0 transcripts | 12, 59 ms (SubagentStart); 141, 54 ms (PreToolUse:Agent) |
| S0 proved PreToolUse delivery only with `"allow"` | `cat log-stdin.sh` | Script emits `permissionDecision:"allow"` — confirmed; context-only delivery is a docs claim (docs list `additionalContext` as a PreToolUse output; fallback in design stands) |
| Docs: `agent_id` only inside a subagent; `agent_type` also for `--agent` | hooks.md fetch | Verbatim match |
| Docs: SubagentStart cannot block; PreToolUse exit 2 blocks; timeout does not block | hooks.md fetch | Match; default command timeout 600 s (design's `timeout: 5` is a tighter backstop) |
| Docs: several hooks' `additionalContext` all delivered | hooks.md fetch | "Claude receives all of the values" — match |
| Docs: Explore/Plan skip CLAUDE.md; `omitClaudeMd`; 3-layer default; env var | sub-agents.md fetch | Match; also: at the depth limit the `Agent` tool is withheld (loop ends structurally) |
| `general-purpose`/`claude` carry the Agent tool | agent listing in this dispatch | Both `Tools: *`; Explore/Plan `All tools except Agent` |
| No `Agent` matcher in live hooks; one SubagentStart hook | `jq .hooks config/settings.json` | PreToolUse matchers `Edit\|Write\|Read\|Glob\|Grep`, `Bash`; SubagentStart = agentmemory only |
| Symlinks live | `ls -la ~/.claude/CLAUDE.md ~/.claude/settings.json` | Both → `hq/config/…` |
| Current Rule 2 text / Rule 9 | `sed` on `config/CLAUDE.md` | As quoted in ADR Ctx 2; Rule 9 forbids agent-made conventions without owner approval |
| Topology workers are leaves (ADR 0037) | `agents/topology-worker.md` frontmatter | `disallowedTools: ["Agent"]` — design leaves them untouched |
| `jq` 1.7.1 at `/usr/bin/jq`; bash 3.2.57 | `--version` | Match |
| `reason` jq expression | run on 2 fixtures | Indented/lower-case markers → `null`; valid line → trimmed string |
| `date -u …Z`, `find -mtime +14 -delete` on macOS | ran both | Work (exit 0) |
| Main has uncommitted `config/settings.json` edit | `git -C ~/projects/agent-hq diff -- config/settings.json` | `modelSettings.claude-fable-5-1.effortLevel: "high"`, +5 lines — confirmed |
| 0043 number free | `ls decisions/`, `git for-each-ref`+`ls-tree`, code-gate worktree | Only this branch has 0043 |
| 2026-09-17 grant excludes settings.json; keep `wt/` branch | memory notes | Both confirmed verbatim |
| Eval-log line format | `cat retros/2026-09-model-tier-policy-eval.md` | `T<n> \| <date> \| <problem> \| … \| fable-changed-course: y/n` |
| Doc cap / index parity | `tools/check-doc-length.sh .` ; `HQ=$PWD tools/check-invariants.sh --fast` | exit 0 ; exit 0 (9/9 OK) — before and after edits |

## Rulings

**Q1 — No restriction anywhere.** `grep -nE 'deny|ask|permissionDecision|only when|must not spawn|refuse|block'`
over the three docs: every hit is a negation ("never emits deny/ask", "no mechanism may block"), the rejected
NESTING-REASON gate in Alternatives, a docs quotation, or the plan's stop-on clauses that forbid *agents* from
adding a block. The PROPOSED Rule 2 says "You may dispatch further subagents whenever that genuinely helps".
C2's table has no deny/ask branch; a missing `permissionDecision` leaves the permission flow untouched. PASS.

**Q2 — Gap closed, with one precision.** Rule 2 is in the system prompt; the banner is an attachment at
transcript lines 1–2, so a subagent reads Rule 2 *before* the banner but has both before its first action
(amendment A2). Explore/Plan skip CLAUDE.md *and* lack the Agent tool, so they cannot loop; the banner still
reaches them (settings-level SubagentStart, no matcher — the S0 hook was wired the same way and fired at
depth 1 and 2). `omitClaudeMd` agents: same. Forks: 38 `agentType:"fork"` meta files exist on disk; whether
SubagentStart fires for a fork is unmeasured (open check, architecture §Open checks). PASS with A2/A10.

**Q3 — Interfaces exact; two things were presented more firmly than measured.** Fields, output shapes, the
meta path (no cwd encoding needed — `transcript_path` is literal in every payload), jq/bash/date/find all
verified above. (a) L1 "depth N" was "unverified"; measurement says *absent* at depth 1 — recorded (A3, A7).
(b) L3's notice is delivered "next to the tool result", i.e. after the spawn is issued, so "at the moment of
the spawn" overstated it (A4, A8). Added: outputs must be jq-encoded, never printf (A9); the cap check is a
benign TOCTOU race (A9). Log schema and caps are internally consistent. PASS with amendments.

**Q4 — PROPOSED Rule 2 is consistent.** The orchestrator clause is byte-for-byte the current obligation;
the session-startup exception is kept and scoped to the orchestrator; "Rules 3 and 4 apply to any agent you
spawn" matches Rules 3/4; nothing touches Rule 5; Rule 9 is honoured by keeping the text PROPOSED. The
no-banner fallback ("began with a dispatch brief … rather than a message from the owner") works for hq's
brief style; a brief written in the owner's voice falls back to today's behaviour (no regression), and a
script-driven `claude -p` run self-identifies as a worker, which is the desired outcome. 25 hq docs cite
Rule 2 (`grep -rln`); all describe the *orchestrator's* duty and are unaffected. PASS, owner approval pending.

**Q5 — Plan executable as ordered.** Models fit Rule 4 (fable mandatory; sonnet bash build; opus verifier
for an every-session hook; haiku for mechanical S5; owner for S4b). Verifier ≠ author at S1/S2, S4a, S5.
The settings exclusion is handled by merging `~1`; added a guard so a fix loop cannot push the wiring commit
off the tip (A13). Rule 7 note present and correct (1 of 7 parallel, S5 after owner approval). Cleanup keeps
the branch per the 2026-09-06 ruling. The S3 "separate sonnet applies amendments" step was overtaken by the
orchestrator's brief (Fable applies small ones) — plan updated (A12). PASS with A11–A14.

**Q6 — Caps and parity.** `tools/check-doc-length.sh .` → exit 0 (0 blocking); `HQ=$PWD
tools/check-invariants.sh --fast` → exit 0, 9/9 OK. Re-run after all edits: both exit 0. README row matches
the ADR title and status. This record is under 200 lines.

**Q7 — Risks named that the docs understated.** (1) Latency: C1 runs on every subagent start on this Mac
(~3,900 meta files on disk show the volume); measured 12–141 ms per hook, acceptable, now recorded. (2) L1 depth
is effectively nil, not merely unverified (A3/A7). (3) L3 is post-hoc for the observed spawn (A4/A8). (4) Log
cap race and concurrent appends — benign, named (A9). (5) The banner is a hook attachment telling the model
to read a global rule as not binding it; the S0 haiku agents treated such text as context, but until L2 lands
a model may rank CLAUDE.md above it — that is why L2 stays a layer. (6) Forks and Workflow-tool agents are
unmeasured (A10). (7) Rule 9: the banner/notice wording, the `NESTING-REASON:` convention, and the C5 log are
agent-authored; memory `no-large-state-log-files` (owner, 2026-09-13) requires agreement before any new
state log — routed to the owner at S4b (A5, A14), not applied.

## Amendments applied (file:line, post-edit)

- A1 `decisions/0043-subagent-role-contract.md:3-6` — status: ratified-with-amendments; owner items named.
- A2 `decisions/0043-subagent-role-contract.md:130-133` — reading-order fact (system prompt before banner).
- A3 `decisions/0043-subagent-role-contract.md:149-152` — depth-1 `meta.json` measured absent at SubagentStart.
- A4 `decisions/0043-subagent-role-contract.md:153-155` — L3 notice delivered with the tool result.
- A5 `decisions/0043-subagent-role-contract.md:164-169` — owner confirmations folded into S4b (Rule 9).
- A6 `architecture/subagent-role-contract.md:3-5` — status line.
- A7 `architecture/subagent-role-contract.md:57-64` — depth measurement; no cwd encoding needed.
- A8 `architecture/subagent-role-contract.md:101-103` — C2 delivery timing.
- A9 `architecture/subagent-role-contract.md:158-163` — jq-built output; cap race accepted.
- A10 `architecture/subagent-role-contract.md:214-219` — open checks: forks, Workflow-tool agents.
- A11 `plans/subagent-role-contract.md:3` and `:25` — status and S3 row.
- A12 `plans/subagent-role-contract.md:41-44` — S3 done text matches how amendments were applied.
- A13 `plans/subagent-role-contract.md:57-58` — wiring commit re-tipped after any fix loop.
- A14 `plans/subagent-role-contract.md:105-110` — S4b presents banner/notice/convention/log for confirmation.

## Needs owner (not applied — would change intent or add a standing convention)

- N1 ADR 0043 §PROPOSED Rule 2 wording — approve verbatim or amend (Rule 9; plan S5).
- N2 Banner and notice text — they assert how Rule 2 binds a subagent; confirm at S4b.
- N3 `NESTING-REASON:` line — an agent-proposed convention; keep, or strike (only the log's `reason` field
  changes).
- N4 C5 spawn log — a new append-only state file; memory `no-large-state-log-files` requires prior
  agreement. Caps proposed: 100 lines/session, 240-char fields, 14-day prune. Approve, change, or drop C5
  (the notice still works without it).

No stop-the-line. No amendment reopens L1–L3 or the accepted losses; none lets any layer block a spawn.
