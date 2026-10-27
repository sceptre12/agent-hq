# pre-pr-gate: step detail

Depth for `SKILL.md` Steps. Contracts: INTERFACES 1.10.0 (AM-6 B-7, C-5; AM-7 touch-up 5; `architecture/delivery-workflow/INTERFACES.md`). Step numbers below are SKILL.md step numbers.

## Card 10 to SKILL step map
Card 10 (part-02 §2.2) step -> SKILL step: 1 -> 1; 2 -> 2 (and 15); 2b -> 3; 2c -> 4; 3 -> 5; 4 -> 6; 5 -> 7; 5b -> 8; 6 -> 9-11; 7 -> 12; 8 -> 13; 9 -> 11-14 (the round loop and its cap); 10 -> 16; 11 -> 17; 12 -> 18; 13 -> 19. SKILL step 20 writes the token. INTERFACES pointers that use card numbers (A.2.2 `sensitive_paths[]` "step 5", B7 "step 4") mean SKILL steps 7 and 6.

## Checklist row ids (PREPR rows)
`PREPR: STOP <ids>` names only `C1`-`C26`. `C1`-`C23` are the step-checklist rows in their written order (part-04 5.7); `C3` branch rebased AND plan-check verdict PASS (both; `gate/plan-check.md` line 1 `PLAN-CHECK: clean`, AM-8 V9, INTERFACES 1.9.0 AM-9 G2/7), `C8` standardization pre-check, `C9` `GATE-PASS` for every pushed batch, `C10` redaction gate, `C11` scope-check, `C12` ports claimed (the review-bus port; the port row, INTERFACES 1.6.0 AM-6 B-7) plus reviewer record path and 0B/0M, `C13` Verified-By distinct, `C14` fixer shas with `fix:`, `C15` fix-verifier CLEAN, `C21` catalog has no `planned` rows, `C22` PR body from template, `C23` plan unit list equals branch unit list. `C24` version bump, `C25` dist scan, `C26` `validate-findings.cjs` (full mode only). The authoritative list is `references/templates/step-completeness-checklist.md`.

## Profile fields
- INTERFACES A.2.2 keys (missing = `INPUT-ERROR <key> missing`): `gates.command`, `gates.parallel`, `gates.min_free_kb`, `gates.runner_slots`, `node.prefix_cmd`, `secrets.pattern_file`, `sensitive_paths[]` (list of ERE), `worktree_base`, `default_branch` (AM-4 20 Q6).
- From `RUN_HOME/state.md` (A.2): `primary_repo`, `plans_dir` (the dispatch plan is `<plans_dir>/dispatch-plan.md`, A.6).
- Design-only fields (part-04 §5.8, `part-04-templates.md:33`; not INTERFACES keys): `install.rebuild_allowlist`, `e2e.dist_scan_cmd`, `version_bump_rule`, PR template path, the exact lint, typecheck, test and build strings (the CI-parity commands, part-01 stage 4b). Absent = the dependent row has no evidence and fails; name the field in the row. The standardization pre-check is a §5.7 row (C8, `part-04-templates.md:30`); no §5.8 field names its command, which is left unspecified by design.

## Gate runner (steps 2 and 15)
- Separate mechanical-tier agent, own slot row (persona `gate-runner`, unit `-`), `gate-runner/<n>` lane lease (`n` in `1..gates.runner_slots`) via `catalog.sh` (a held lease is exit 3: wait for the holder, do not break it). A runner that dies holding its lease is released by the lead's post-`TaskStop` orphan sweep, which writes the `released` row (AM-4 20 Q9).
- Preconditions (part A.7): lease, free space above `gates.min_free_kb`, node activated by `node.prefix_cmd`.
- A failure writes no `gate-runs` file; the runner's output goes to `RUN_HOME/<subtask>/status/<agent-id>.md` (A.6). The record is never edited by hand.
- The first cold run is the first-push `GATE-PASS`; when fix rounds move the head, the same command re-runs on the final head and writes `gate-runs/<final head>.md`.
- The runner releases its lease after each run, pass or fail (`catalog.sh release lane-lease gate-runner/<n>`, A.5.1 `lane-lease`: write a `released` row). A lease left `live` would make the step 15 `register` exit 3. Step 18 confirms none is `live`.

## Install (step 2)
`--frozen-lockfile --ignore-scripts`, then `pnpm rebuild` of the profile's `install.rebuild_allowlist`, nothing else. A package outside the allowlist needing a lifecycle script fails C7 and is named as a profile gap; never widen the allowlist here.

## Redaction (step 6)
Patterns come from `secrets.pattern_file` (ERE, one per line). Run with `command grep -E -f`; scan the diff, gate logs, and `pr-body.md`. Exit 0 means a match and fails C10; exit 1 is clean; exit 2 or more (unreadable pattern file, invalid ERE, unreadable input) fails C10 and is reported, never read as clean. Do not print matched text into any record; print file and line only.

## Scope-check (step 7)
- Unit list: `substate.md` `integrated` (A.3). Per unit, `scope-check.sh <tasks-file> <unit worktree> <base-sha>` (INTERFACES script table): `<tasks-file>` = `<primary_repo>/.tasks/<unit>-<slug>.md` (`primary_repo` from `state.md`; `<slug>` the unit's ticket slug, A.6), unit worktree `<worktree_base>/<run-id>-<subtask>-<unit>` (A.6 `dispatch-plan.md` additions), `<base-sha>` = `git -C <unit worktree> merge-base HEAD <sub-task branch>` (branch from the dispatch-plan sub-task table), computed, never stored. Exit 0 clean, 1 `CREEP <path>` lines, 2 usage (fails C11).
- Sensitive paths: `git -C <WORKTREE> diff --name-only <merge-base of HEAD and the PR base>..HEAD` matched against each ERE of `sensitive_paths[]` (A.2.2).
- Each `CREEP` or sensitive hit passes only with a desk `INSTALLED` row for that path (ADR 0055) or the human grant file `RUN_HOME/gates/grant.<subtask>.<n>.<run-id>.ok`, written by the desk after `GATE grant.<subtask>.<n> ok <text>`, whose `ref=` names the path (A.2.1, B8, AM-4 20 Q1, AM-5 26). With neither, C11 fails (checklist rule "no evidence = FAIL").

## Seat set (step 10)
`ROLES` is all 7 seats until the D12 RACI remap and 3-seat probe are recorded in D2.3 (owner D12, `owner-decisions.md:9`; D2.3 `pr-review`). After that, when the profile asks, `review-tailor` inputs (D2.2 row 4): `RUN_HOME`, `SLUG=<subtask>-diff-<n>`, `ARTIFACTS` (the diff and the plan's unit list), `KIND=diff`, `STAKES`, `CONTENTION`, `NOVELTY` (the ladder rubric axes, `tools/review-ladder.md`), `SECURITY_AUDIT`, `ORCHESTRATOR_TIER` (from `state.md` `orchestrator_tier`). It writes `RUN_HOME/review-tailor-<slug>.md`; `ROLES` = the seat-id column of its seat table (D1.1 `RUNG:`). No A.2.2 key says when the profile "asks for" a tailored set (`review_profile.*` are `review-tailor` inputs); integrator gap.

## Review loop (steps 11-14)
- Round `r` writes `fix-<agent-id>-<r>.md` and `verify-<seat-id>-<r>.md`; `r` is 1..3. Each fixer dispatch has its own `agent-id`, so a G48 fix (step 8; `r` = the round it precedes, 1 before round 1) never shares a name with a review-loop fix (A.6 "agent-id makes parallel writers disjoint").
- Each fix file carries the fix commit sha (card 10 Out "fix commits"; C14).
- After a head move `HEAD` is the new sha and the record is `record-<new head>.md`.
- `RECORD_PATH` is absolute: `RUN_HOME/review/<subtask>/record-<HEAD>.md`.
- Bus port: `BUS_PORT` is the P8 `review-bus` candidate `ports.bus_base + 20·(2N+1)` (A.5.2, AM-4 W2-3); `pr-review` also gets `RUN_ID` and `SUBTASK` and runs its bus under `RUN_HOME/review/<subtask>/<review-id>/bus/` with a fresh `pr-review-<uuid8>` session (A.1, D5, AM-5 10-B2). `pr-review` claims and launches; on a refusal (`port-check.sh` exit 1 taken, 2 registry and `lsof` disagree) it makes exactly one claimed retry at `BUS_PORT + 10`, then a second refusal stops the line and is reported to the lead; on that stop the refusal line is recorded in the checklist, line 1 is `PREPR: STOP C12` (no review record; D2.2 row 10 names `C<port row>` and no C1-C26 row is a port row) and the lead writes `stop_reason: port-refused` (AM-4 20 Q5, W2-1). Exit 3 (registry unusable) stops the line with no retry (A.5.2, D2.3, AM-3 OQ-2). `pre-pr-gate` never claims or picks a port.
- Bus facts: topics `pr-check-N-closed`, read with `peek:true`, fresh `agent_id` per reader, `limit 200`. The orchestrator does not read closed topics through an agent id that already consumed them.
- D57 "freeze scope once the core stops changing" (trigger, stated in `review-tailor`: two consecutive rounds with no change to the core sections). D60: the same finding class in two consecutive rounds replaces the mechanism (change the fixer brief or the check), not another retry, and the verifier checks the affected section got shorter, measured in bytes (part-03 §4). D59: "an edge enumeration is closed by one check and labelled, and a parked owner item is asked, not re-worded". D35: one review orchestrator per loop.
- Advisory, never rules: D44, D54 (a class-wide fix hint line in the fixer brief), D58, D61, D65, D66.
- Before round 1 a `plan-checker` (verify tier) checks the round's inputs (D55, AM-4 20 Q2) and writes its verdict to `RUN_HOME/<subtask>/gate/plan-check.md` (A.6 row; INTERFACES 1.6.0 AM-6 B-9b; the run's `RUN_HOME/plan-check.md` is the stage 3 record and is not written here). A non-clean `PLAN-CHECK: <n> findings` never blocks by itself: its findings go to the round-1 fixer first, then the plan-checker re-runs (INTERFACES 1.9.0 AM-9 G2/7). `fix-verifier` verifies every G48 fix as well as the review-loop fixes (AM-4 20 Q4); an `INPUT-ERROR` reply is not a round and writes no `verify-*` record (AM-4 11-Q11-R1).
- Head moved during a round, or `ci-fix-loop` moved it (AM-4 W2-7): rebase, repeat steps 1-2 (and step 9 under `full`) on the new head, then a non-author delta verify of reviewed-head..new-head. Steps 3-7 are re-checked on the final head by the validator (step 16), which re-runs every evidence command.
- Round 3 ended with open findings: step 20 writes `PREPR: STOP <ids>` to checklist line 1 (never printed, D1.1) with `C12`, `C15` if the last verify is not CLEAN, and every other failed row; the human gets `record-<HEAD>.md` and `checklist-<subtask>.md` paths; the sub-task halts, others continue.

## Validator (step 16)
Re-run each evidence command (do not trust earlier output) on the final head. Diff the plan's unit list (`.tasks/` files named by `<plans_dir>/dispatch-plan.md`) against `substate.md` `integrated`. It skips C13, C21, C22 in its first pass and walks them after step 19, when their evidence exists. Any failing Blocking row fails; there is no score.

## Catalog check (step 18)
`catalog.sh list --live --subtask <SUBTASK>` prints the latest row of every `kind`+`handle` pair that is `planned` or `live` (script table, AM-4 20); none may be `planned` (C21).

## Output files
`checklist-<subtask>.md`, `pr-body.md`, `fix-*`, `verify-*` all under `RUN_HOME/review/<subtask>/`. Writes are atomic: temp name in the same directory, then `mv`.

## Settled points (INTERFACES 1.10.0 D2.2 row 10, AM-4 20, AM-6 B-7, AM-7 touch-up 5; formerly open points 1-9)
1. Sensitive-path or `CREEP` evidence: a desk `INSTALLED` row or the A.2.1 grant file (Q1).
2. D55 applies: a plan-check before round 1 of this loop (Q2).
3. A failing row outside the review loop is `PREPR: STOP <id>`, never handed to the fixer; the lead writes `stop_reason: stop-the-line:S2` (Q3, A.8 A.3).
4. `fix-verifier` verifies G48 fixes too (Q4).
5. A second bus-port refusal is `PREPR: STOP C12` with `stop_reason: port-refused` (Q5, W2-1); `C12` is the port row (INTERFACES 1.6.0 AM-6 B-7).
6. The PR base is the profile `default_branch` at the ref the lead's desk `fetch` updated (Q6, W2-4).
7. A profile sha mismatch is `INPUT-ERROR REPO_PROFILE sha` (D1).
8. `list --live` prints latest rows that are `planned` or `live` (script table).
9. A dead runner's lease is released by the lead's post-`TaskStop` orphan sweep (Q9).

Still open (integrator): no A.2.2 key says when the profile asks for a tailored seat set (step 10, "Seat set" above).
