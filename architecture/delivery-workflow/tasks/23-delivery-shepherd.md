# Task Spec: 23 `delivery-shepherd` (W1 pilot draft)

Dispatch: execute-tier author. Branch: `wt/delivery-w0` (integrator commits; the author never does). Source: design part-02 §2.2 card 7, part-06 §7 row 23-25, INTERFACES 1.1.0 (AM-1 port guard and security-audit, re-read at spec finish; rows D2.2 7, C7, A.5.1 unchanged by AM-1).

## 1. Objective
Author the skill `skills/delivery-shepherd/`: a tick-driven (every 10 minutes, D10) checker that, for a sub-task with 3 or more live agents, raises the shepherd-half flags `DRIFT`, `CREEP` and `FREE-CANDIDATE`, sends fixed-template nudges, and never decides `TaskStop` or re-dispatch (the lead does). `Provenance: pending pilot` (D14, M31).

## 2. Context Package
- Card: `architecture/delivery-workflow/part-02-skill-inventory.md` §2.2 card 7. Slot budget: part-03 §4 (shepherd is one reserved slot, no row file; `substate.md` `reserved.shepherd: 1`, A.3, A.4).
- Merged tick prompt (verbatim home): part-03 §4 "Merged tick". The lead arms the cron in its own session (C7); this skill does not arm a cron.
- Flag authority: INTERFACES `interfaces/part-c-waves-control.md` C7 (flag table, nudge template, "Not a stall", "After every TaskStop", "Observation means", "Merged tick").
- Status line: C3 (`NEXT: <unit>.<n> <one line>`, `^NEXT: (u[0-9]+)\.([0-9]+) .+$`, file `RUN_HOME/<subtask>/status/<agent-id>.md`).
- Inputs: D2.2 row 7 (`RUN_HOME` path, `SUBTASK`, `PLANS_DIR` path); Step 0 per D1 (`INPUT-ERROR <field> <reason>`, line regex in D1). Path rule A.1 (`DELIVERY_ROOT` env, unset = `INPUT-ERROR DELIVERY_ROOT unset`).
- Derived inputs: `dispatch-plan.md` in `PLANS_DIR`; slot rows A.4; `dispatch/*.jsonl` and `status/*.verdict` for `FREE-CANDIDATE` (C2 reader idiom: `peek:true`, fresh `agent_id`, `limit 200`; C4); `catalog.tsv` A.5; `scope-check.sh` (INTERFACES "Script interfaces").
- Anatomy: `tools/skill-authoring.md` §2-§5 (frontmatter "Use when", `## Trigger`, `## Steps`, `## Red flags`, `## Exit criteria`, `## Provenance`; body under 5k tokens; depth in `references/`).
- Dependencies: none blocking. Needs `scope-check.sh` and `catalog.sh` to exist only at run time (W1 items 5-7 / script items), not for authoring; cite their CLI from INTERFACES.

## 3. Scope
In scope (directory-disjoint; no other item writes here):
- `skills/delivery-shepherd/SKILL.md`
- `skills/delivery-shepherd/references/flags-and-nudges.md` (flag table copy-by-anchor to C7, nudge template, ticks.md line format, the "not a stall" rule)

Out of scope: arming the cron (lead, `delivery-run`); the `STALLED` and `PROMPT-OPEN` flags and the bus-down check (watchdog half, `delivery-run`, C7); `TaskStop`, re-dispatch, freeing slot rows, orphan sweep execution (lead); any edit to INTERFACES, `delivery-run`, `scripts`.
Do NOT create: scripts, hooks, a `disable-model-invocation` key (D16), any file outside the two paths, symlinks, installs, web fetches.

## 4. Contracts
| Contract | Value | Authority |
|---|---|---|
| Flag line | `<FLAG> <agent-id>` appended to `RUN_HOME/<subtask>/shepherd/ticks.md` only when something changed | C7 |
| Flags raised | `DRIFT`, `CREEP`, `FREE-CANDIDATE` | C7 table "shepherd half"; D2.2 row 7 |
| Nudge | `NUDGE <agent-id> \| <FLAG> \| next: <unit>.<n> \| <one line copied from the plan>`, `SendMessage`, no free text | C7 |
| `CREEP` source | `scope-check.sh <tasks-file> <worktree> <base-sha>`; tasks file `<primary_repo>/.tasks/<unit>-<slug>.md`; `primary_repo` = parent of `PLANS_DIR`'s `plans/`; `base-sha` = `git -C <worktree> merge-base HEAD <sub-task branch>`, never stored; exit 1 = creep, lines `CREEP <path>` | C7, R4-J21 |
| `FREE-CANDIDATE` | terminal record (bus post or `.verdict`) exists and slot row not yet `.freed`; the shepherd never frees | C7, A.4 |
| Authority | flags and redirects only; the lead decides `TaskStop` (D10) | C7, card 7 |
| Observation | catalog, `TaskList`, files, `git -C`, `kill -0`; no `ps` | C7 |
| Writes | only `shepherd/ticks.md` and `SendMessage` nudges | D6 plane table (`shepherd/` writer = shepherd) |

## 5. Inherited module API
`scope-check.sh` (exit 0 clean, 1 creep, 2 usage); `catalog.sh list --live [--subtask <st>]`; slot row fields A.4 (`agent_id persona unit tier taken_utc budget_min worktree backend pid`). Use them; do not reimplement.

## 6. What you inherit
The COMMON block conventions (design §3.0), the tier name `execute` (not a model, M19), the owner rule D10 (Sonnet-class mechanical sweep), D16 (model-invocable).

## 7. Known risky values
| Value | Correct | Wrong | Source |
|---|---|---|---|
| Tick interval | 10 minutes | 5 or 30 | D10, part-03 §4 |
| Who raises `STALLED`, `PROMPT-OPEN` | `delivery-run` watchdog half | this skill | C7 "Merged tick" |
| Who stops/frees | the lead | the shepherd | D10, C7 |
| Cadence gate | runs only with 3 or more live agents; below that the lead checks drift/creep on each verdict | always | card 7, C7 |
| Token for `next` | `next_step` form `<unit>.<n>`, never `step_id` | `step_id` | C3, A.1 |

## 8. Acceptance criteria
- [ ] `SKILL.md` frontmatter: `name: delivery-shepherd`, `description` at most 1024 chars with "Use when", no `disable-model-invocation`.
- [ ] Body has `## Trigger`, `## Steps` (numbered), `## Red flags` (table), `## Exit criteria`, and a final line `Provenance: pending pilot` (plus friction links: `brain-group-process-retro:153-158` for the open-prompt case, `caretaker-turn-timeout:12-19`).
- [ ] Steps cover: Step 0 input validation (D1); gate on 3 or more live agents; per agent read `NEXT:` and compare to the plan; run `scope-check.sh`; `FREE-CANDIDATE` scan; append a flag line only on change; send the fixed nudge; spec check before redirecting a `DRIFT`; creep is a named defect and an adjacent defect is ticketed, never fixed; end with "one line or noop".
- [ ] States explicitly that it never calls `TaskStop`, never frees a slot row, never edits worktrees, and that PROMPT-OPEN/STALLED/orphan sweep belong to the lead's tick (C7), with the SPEC-QUESTION below resolved or left marked.
- [ ] The `claude -p` lead turn-close rule is stated as "not a stall" (C7).
- [ ] Token regexes and paths match INTERFACES exactly (checked by script below).
- [ ] No cost metrics anywhere (B-4); no personal-project terms.

SPEC-QUESTION 1: card 7 and the owner's item text list `PROMPT-OPEN`, orphan sweep and `STALLED` as shepherd flags; frozen INTERFACES C7 and D2.2 row 7 assign them to the `delivery-run` watchdog half and list only `DRIFT`, `CREEP`, `FREE-CANDIDATE` for this skill. This spec follows INTERFACES (frozen, authoritative). The plan-checker decides whether to amend INTERFACES (change control D7, consumers `delivery-run`, `delivery-shepherd`: Rung 1) or the card. Until then the skill's reference file carries the full C7 table with a "raised by" column so a reader sees all five flags and who owns each.

## 9. Verification commands
```bash
W=$HOME/projects/agent-hq-worktrees/delivery-w0; S=$W/skills/delivery-shepherd
test -f $S/SKILL.md && test -f $S/references/flags-and-nudges.md
head -5 $S/SKILL.md | grep -q '^name: delivery-shepherd$'
grep -q 'Use when' $S/SKILL.md; ! grep -q 'disable-model-invocation' $S/SKILL.md
for h in '## Trigger' '## Steps' '## Red flags' '## Exit criteria'; do grep -q "^$h" $S/SKILL.md || echo MISSING $h; done
grep -q 'Provenance: pending pilot' $S/SKILL.md
for t in DRIFT CREEP FREE-CANDIDATE 'scope-check.sh' 'shepherd/ticks.md' 'NUDGE'; do grep -q -- "$t" $S/SKILL.md $S/references/flags-and-nudges.md || echo MISSING $t; done
! grep -n -E '\bps -|pgrep' $S/SKILL.md   # no ps (measured); TaskStop appears only as the lead's action (reviewer reads)
[ $(wc -w < $S/SKILL.md) -lt 3500 ]
bash $W/tools/check-doc-length.sh $W
! grep -rn -i -E 'touri|ofw|runfrist|jetblue|notion|/Users/[a-z]+|\$[0-9]|cost' $S
```
Verifier re-runs these plus the Rung 1 trio.

## 10. Branch and worktree
Work in `~/projects/agent-hq-worktrees/delivery-w0` (branch `wt/delivery-w0`); no git add/commit/branch/push. Tier: execute. Review rung: Rung 1 trio (reviewer, fixer, `fix-verifier`; D7 stop after round 3, then the owner). File scope dirs: `skills/delivery-shepherd/` only.

## 11. Decision Gate reminder and amendment note
Write `.decisions/23.md` and stop (do not guess) on: a flag name or regex differing between card 7 and C7 beyond SPEC-QUESTION 1; a need to arm a cron; any need to touch a file outside scope. AM-1 (1.1.0): port guard, A.5.2 and the A.5.1 `port` row. The shepherd claims and binds no port. Its touch points: (a) it reads `catalog.sh list --live` and may see `port` rows; it never releases them (release is cleanup's, A.5.1); (b) the advisory PreToolUse port hook can leave a pending `ask` that holds an agent, which is the PROMPT-OPEN case the lead's watchdog flags (C7), so `references/flags-and-nudges.md` notes it in one line. `security-audit` (A.5.3, persona `security-auditor`): not used here; a live `security-auditor` agent counts toward the 3-agent gate like any other. Re-read INTERFACES before finishing; record the version checked.
