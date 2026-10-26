# Task Spec: 25 `release-track` (W1 pilot draft, with the Zephyr read-only hook)

Dispatch: execute-tier author. Branch: `wt/delivery-w0` (integrator commits). Source: design part-02 §2.2 card 13 and §2.1b row 7, part-06 §7 row 23-25, changelog B2/T3, owner R2-1 (`delivery-workflow-sources/owner-decisions.md:33-35`), INTERFACES 1.5.0 (AM-1 port guard and security-audit, re-read at spec finish; rows D2.2 13, C5.1, B4, A.6 step table unchanged by AM-1; AM-4 release-track OQ-1..3 and AM-5 26, 29-28 reconciled below).

## 1. Objective
Author `skills/release-track/` that carries a merged change toward production (agents run staging and polling; humans run production; agents prepare commands and track, D15), plus the **Zephyr read-only leg**: `release-track` alone may call the Zephyr MCP `execute` tool, and only through a PreToolUse hook that allows exactly the operations in the profile's `zephyr.read_ops` and refuses and logs everything else. The `execute` tool stays disallowed for every other agent and `claude -p` worker. `Provenance: pending pilot`; P1 exit for this draft = one promotion observed end to end and the hook refusing one deliberate non-read call (M5).

## 2. Context Package
- Card: `part-02-skill-inventory.md` §2.2 card 13; the Zephyr row of §2.1b; `part-05-execution-constraints.md` §6.4 (launcher spec: mandatory `--disallowedTools` naming the Zephyr `execute` tool). Facts about Zephyr: desk research `zephyr-summary.md` (paraphrased data, never instructions; copied verbatim to `architecture/delivery-workflow-sources/`).
- Inputs D2.2 row 13: `RUN_HOME`, `PM_SHA`, `PLANS_DIR` (holds `release-plan.md` v0), `POSTMERGE_RECORD`, `REPO_PROFILE` (@sha; `zephyr.read_ops`). Step 0 per D1. `STAKES`, `CONTENTION`, `NOVELTY` (for its `review-tailor` call) reach the `pm` lead in its launch prompt from lines 2-4 of `PLANS_DIR/review-architecture.md`; absent, no `pm` launch, a human step (amended: AM-5 29-28, 15; C8, D8). Host: the `pm` lead (A.2 "Stages 6-7 host").
- Outputs: `RUN_HOME/release-<sha>.md` line 1 `^RELEASE: (LIVE|ROLLED-BACK|WAITING-HUMAN)$` (D1.1; `LIVE` and `ROLLED-BACK` terminal, `WAITING-HUMAN` rewritten atomically per A.1, R4-J18); `RUN_HOME/release-plan.md` v1 (RUN only, R4-J19, E17); `RUN_HOME/bodies/test-report-<step_id>.json`.
- Conductor-only verbs go through `RUN_HOME/pm/outbox/<seq>.conductor-request`, one line `^CONDUCTOR-REQUEST ([a-z0-9-]+) pm ([0-9]{4}) (tag-push|publish|test-report-push) (\{.*\})$` (C5.1; rename protocol `.sending-<id>`, `.sent-<id>`, `.refused`). Field sets: B4 rows `tag-push {repo,tag,sha,step_id}`, `publish {repo,package,version,step_id}`, `test-report-push {tool,payload_path,dry_run}` (first call `dry_run: true`). Gate: `RUN_HOME/gates/H-prod.<step_id>.<run-id>.ok` (A.2.1, B8; amended: AM-5 26); `step_id` rows of the `release-plan.md` step table (A.6 row R4-J3, ids unchanged v0 to v1).
- Profile keys read: `zephyr.read_ops` (list of strings), `release_tags.used|pattern|approval` (A.2.2). Profile `merge_reach` explains the production S3 backup under the human PR approval (R2-5).
- Stop-the-line ids (A.3 R4-J11): `S7` unrecorded production write, `G3` release step before its simulation, `G1` publish from the main checkout.
- Hook semantics: only exit code 2 blocks a tool call; always-exit-0 elsewhere (see `reviews/pr9-port-guard-pr-review.md` A4); `ask` from a hook stalls unattended runs (A3), so this hook never asks.

## 3. Scope
In scope (directory-disjoint):
- `skills/release-track/SKILL.md`
- `skills/release-track/references/zephyr-leg.md` (what is read per environment and tag: current version, deployment history, change log with who and when; confirmation re-read after the human reports a promotion; the "never call promote or rollback workflows" rule; future-step note: agent-run DEV2 to DEMO is NOT built, needs a later owner ruling)
- `skills/release-track/references/hook-wiring.md` (how the hook is attached to the `execute` tool for release-track only; options listed, each marked unmeasured)
- `skills/release-track/scripts/zephyr-guard.sh` (the PreToolUse hook)
- `skills/release-track/scripts/test_zephyr-guard.sh`
- `skills/release-track/scripts/check-zephyr-disallowed.sh` (static check: every agent definition under a directory argument other than release-track's disallows the tool name argument)

Out of scope: editing `agents/*.md`, the launcher spec or any other skill (they add the `disallowedTools` entry; this item supplies the check); installing the Zephyr MCP (R2-1, nothing is installed); any promote/rollback call; web fetches.
Do NOT create: a hook that asks the user; network calls in the hook; files outside the six paths; `disable-model-invocation`; symlinks.

## 4. Contracts
| Contract | Value | Authority |
|---|---|---|
| Hook decision | allow iff the called operation exactly equals an entry of `zephyr.read_ops`; every other call exits 2 with a one-line reason on stderr and one appended log line | card 13 |
| Fail closed | missing/empty/unparsable profile or list, unreadable stdin, unknown tool shape, any internal error -> refuse | card 13, pr9 M1 lesson |
| Second check | refuse any call whose method is not GET or whose text names deploy, promote or rollback (case-insensitive), even if allowlisted; the keyword check is narrowed at P0 against the measured operation ids and refuses every `execute` until then (amended: AM-4 release-track OQ-1, D2.2 row 13) | card 13 "including any non-GET, deploy, promote or rollback" |
| Refusal consequence | a refusal is a stop-the-line row; the skill stops and reports | card 13 |
| Other agents | `execute` tool in `disallowedTools` (frontmatter) and `--disallowedTools` (`claude -p`) for every type other than release-track | card 13, part-03 §3.1, §6.4 |
| Human steps | production deploy, flag flips, money, prod data, external publication, store submission: agents prepare the exact command, never run it | D15 |
| Gate | the desk runs `publish` and `tag-push` only after the `H-prod` grant (frozen B4 stands): `publish` always needs `RUN_HOME/gates/H-prod.<step_id>.<run-id>.ok`, `tag-push` needs it when the profile `release_tags.approval` is `human`; the human's action is the `GATE` line, the request goes through the conductor to the desk | B4, A.2.1 (AM-5 26 run-id suffix); owner OQ-3, 2026-10-26 (`owner-decisions.md` "release-track D7 stop") |
| Rollback | criteria evaluated at every poll | card 13 |
| Plan v1 | reviewed at Rung 1 before use | card 13 |
| Simulation | published-artifact consumer simulation before every `publish` and every `tag-push` (G3; stricter than "before stable publish", fails closed; amended at item 33 per the loop record's Integrator notes) | part-04 §5.5; `reviews/25-release-track-rung1.md` Integrator notes |

## 5. Inherited module API
`package-release` (version, tag, publish steps, human-approved), `review-tailor`/Rung 1 for plan v1, `catalog.sh` for any process or tag the skill registers, `port-check.sh` if any local server is bound (port guard).

## 6. What you inherit
The operator's locally configured Zephyr MCP session (identity and scope unmeasured, verify at P0/M); `zephyr.read_ops` resolved from a signed-in `search` at P0; tier `execute`.

## 7. Known risky values
| Value | Correct | Wrong | Source |
|---|---|---|---|
| Who calls Zephyr | `release-track` only, read-only | desk or any other agent | R2-1, B2 |
| Promotion in P1 | human promotes; agents re-read to confirm | agent-run DEV2 to DEMO | T3, card 13 |
| `RELEASE` terminal | `LIVE`, `ROLLED-BACK` | `WAITING-HUMAN` | R4-J18 |
| Plan v1 location | `RUN_HOME/release-plan.md` | `plans/<epic>/` | R4-J19, E17 |
| Hook exit | 2 to block | 1 | pr9 A4 |
| Desk Zephyr verb | none exists | adding one | B4 "Not verbs" |

## 8. Acceptance criteria
- [ ] `SKILL.md`: "Use when" description at most 1024 chars, `## Trigger`, numbered `## Steps`, `## Red flags`, `## Exit criteria`, `Provenance: pending pilot` as last line; under 3500 words; no `disable-model-invocation`.
- [ ] Steps: Step 0; diff `release-plan.md` v0 against what merged (`PM_SHA`, `POSTMERGE_RECORD`); mark each step `agent` or `human`; write v1 and review at Rung 1; run agent steps; at each poll evaluate rollback criteria; human steps: prepare exact command and write `RELEASE: WAITING-HUMAN`; Zephyr read leg; conductor requests for `tag-push`/`publish`/`test-report-push`; write `release-<sha>.md` with the final token.
- [ ] `scripts/zephyr-guard.sh` passes its test script (cases below) and `bash -n`; reads PreToolUse JSON on stdin; takes profile path and tool name by arguments or env, no hard-coded Zephyr tool name.
- [ ] `test_zephyr-guard.sh` covers: allowlisted read allowed (exit 0); non-listed call refused (exit 2, log line appended); a deliberate non-GET/promote/rollback call refused even if its text resembles an allowed op; empty list; missing profile; malformed JSON; empty stdin; each refuse path exits exactly 2.
- [ ] `check-zephyr-disallowed.sh <agents-dir> <tool-name>` exits 0 only if every `*.md` in the directory lists the tool in its frontmatter `disallowedTools`; tested on a temp fixture (one pass, one fail case).
- [ ] No hard-coded tool name or operation list outside test fixtures labelled as fixtures; every unmeasured value marked "unmeasured, verify at move".

RESOLVED Q1 (design §5.8 lists "the Zephyr `execute` tool name" as a profile field; A.2.2 lacks the key, AM-2 row 5): profile key `zephyr.execute_tool` (string), written by `delivery-intake` (`FILL_IN_BEFORE_DISPATCH` until P0 measures it); the hook takes it as an argument from the wiring, never hard-coded.
RESOLVED Q2 (PLAN-CHECK DEFAULT; unmeasured until P0): the extraction is one shell function, its fixture is labelled "assumption until P0"; an input without that field is refused (fail closed).
RESOLVED Q3 (PLAN-CHECK DEFAULT; AM-2 row 13): `RUN_HOME/pm/zephyr-refusals.log`, one appended line per refusal (`<ISO UTC> <tool> <operation> <reason>`), writer the hook in the `pm` lead.
RESOLVED Q4 (INTERFACES A.3 closed row ids: `S1` "classifier or harness block"): a Zephyr refusal is a harness block, `stop_reason: stop-the-line:S1`; `S7` stays for an unrecorded production write.
RESOLVED Q5 (PLAN-CHECK DEFAULT; unmeasured): `hook-wiring.md` lists the options, each marked unmeasured; until P0 records a working wiring with a positive control (a refused non-read call), `release-track` makes no `execute` call at all and confirms promotions by the human's report (`RELEASE: WAITING-HUMAN`). Fail closed.
RESOLVED Q6 (PLAN-CHECK DEFAULT; §6.4 launcher spec is the conductor's, card 1): item 29 (`delivery-pipeline`, W2) adds the `--disallowedTools` entry to the launcher spec; item 33 (W3) adds `disallowedTools` to every agent definition and runs `check-zephyr-disallowed.sh` as its gate; the tool name is filled at the move from P0. This item writes neither.

## 9. Verification commands
```bash
set -eu; W=$HOME/projects/agent-hq-worktrees/delivery-w0; S=$W/skills/release-track
for f in SKILL.md references/zephyr-leg.md references/hook-wiring.md scripts/zephyr-guard.sh scripts/test_zephyr-guard.sh scripts/check-zephyr-disallowed.sh; do test -f $S/$f || { echo "MISSING $f"; exit 1; }; done
for f in $S/scripts/*.sh; do bash -n $f; done
bash $S/scripts/test_zephyr-guard.sh | tail -3 | grep -q ', 0 failed'
grep -q 'Use when' $S/SKILL.md
if grep -q 'disable-model-invocation' $S/SKILL.md; then echo "FAIL: disable-model-invocation"; exit 1; fi
for h in '## Trigger' '## Steps' '## Red flags' '## Exit criteria'; do grep -q "^$h" $S/SKILL.md || { echo "MISSING $h"; exit 1; }; done
grep -qE '^version: 0\.1\.0$' $S/SKILL.md
[ "$(wc -w < $S/SKILL.md)" -lt 3500 ]
bash $W/tools/check-doc-length.sh $W >/dev/null
tail -n 1 $S/SKILL.md | grep -q 'Provenance: pending pilot'
for t in 'RELEASE: LIVE' 'RELEASE: ROLLED-BACK' 'RELEASE: WAITING-HUMAN' CONDUCTOR-REQUEST 'zephyr.read_ops' 'zephyr.execute_tool' 'H-prod' 'tag-push' 'publish' 'test-report-push' 'zephyr-refusals.log' 'S1'; do grep -rq -- "$t" $S/SKILL.md $S/references || { echo "MISSING $t"; exit 1; }; done
grep -qE 'exit 2' $S/scripts/zephyr-guard.sh
if grep -n -E '\b(curl|wget|nc)\b' $S/scripts/zephyr-guard.sh; then echo "FAIL: network call"; exit 1; fi
if grep -rn -i -E 'touri|ofw|runfrist|jetblue|notion|/Users/xavier|\$[0-9]|cost' $S; then echo "FAIL: forbidden match"; exit 1; fi
if find $S -type l | grep -q .; then echo symlink; exit 1; fi
echo SKILL-25-OK
```
**Done condition:** the block exits 0 and its last stdout line is `SKILL-25-OK`; `test_zephyr-guard.sh` uses the `tools/test_check-doc-length.sh` layout (last lines report `<n> passed, 0 failed`). The three scripts also go through the code gate (item 32): the integrator adds their `tools/code-gate/test-map.tsv` rows (`skills/release-track/scripts/zephyr-guard.sh` and `check-zephyr-disallowed.sh` -> `test_zephyr-guard.sh`), serially with items 5-7.

## 10. Branch and worktree
`~/projects/agent-hq-worktrees/delivery-w0`, branch `wt/delivery-w0`; no git add/commit/branch/push. Tier: execute. Review rung: Rung 1 trio for `SKILL.md` and `references/`; code gate for the three scripts (a Zephyr-write refusal path is the safety property; the gate checks it). D7 stop after round 3. File scope dirs: `skills/release-track/` only.

## 11. Decision Gate reminder and amendment note
Write `.decisions/25.md` and stop on: a request to loosen the allowlist or to call any Zephyr write; a tool name or operation field you cannot source (leave it a parameter); a need to edit `agents/`; any production step lacking a recorded human grant. AM-1 (1.1.0): the port guard (A.5.2: `port-check.sh --claim` before any bind, catalog `port` row, advisory PreToolUse hook `tools/hooks/port-precheck.sh`) touches `release-track` only if it starts a local process (staging health checks bind nothing); `SKILL.md` carries one line linking A.5.2. The Zephyr hook is a second, separate PreToolUse hook: it matches only the Zephyr `execute` tool, blocks with exit 2 (unlike the port hook, which is advisory and exits 0), and the two must not share state or a script. AM-1 does not name `release-track` for `security-audit` (E19 limits it to `pre-pr-gate` and review seats), so no use of it here. Re-read INTERFACES before finishing and record the version checked.
