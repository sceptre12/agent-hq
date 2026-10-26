# pre-pr-gate: step detail

Depth for `SKILL.md` Steps. Contracts: INTERFACES 1.1.0 (`architecture/delivery-workflow/INTERFACES.md`).

## Checklist row ids (PREPR rows)
`PREPR: STOP <ids>` names only `C1`-`C26`. `C1`-`C23` are the step-checklist rows in their written order (part-04 5.7); `C3` branch rebased, `C8` standardization pre-check, `C9` `GATE-PASS` for every pushed batch, `C11` scope-check, `C12` reviewer record path and 0B/0M, `C13` Verified-By distinct, `C14` fixer shas with `fix:`, `C15` fix-verifier CLEAN, `C21` catalog has no `planned` rows, `C22` PR body from template, `C23` plan unit list equals branch unit list. `C24` version bump, `C25` dist scan, `C26` `validate-findings.cjs` (full mode only). The authoritative list is `references/templates/step-completeness-checklist.md`.

## Gate runner (steps 2 and 15)
- Separate mechanical-tier agent, own slot row (persona `gate-runner`, unit `-`), `gate-runner/<n>` lane lease via `catalog.sh` (a held lease is exit 3: wait for the holder, do not break it).
- Preconditions (part A.7): lease, free space above `gates.min_free_kb`, node activated by `node.prefix_cmd`.
- A failure writes no `gate-runs` file; the runner's output goes to its `status/<agent-id>.md`. The lead fixes through the review loop, never by editing the record.
- The first cold run is the first-push `GATE-PASS`; when fix rounds move the head, the same command re-runs on the final head and writes `gate-runs/<final head>.md`.

## Install (step 2)
`--frozen-lockfile --ignore-scripts`, then `pnpm rebuild` of the profile's `install.rebuild_allowlist`, nothing else. A package outside the allowlist needing a lifecycle script is a profile gap: stop and report, do not widen it.

## Redaction (step 6)
Patterns come from `secrets.pattern_file` (ERE, one per line). Run with `command grep -E -f`; scan the diff, gate logs, and `pr-body.md`. Exit 0 from grep means a match and fails C10; a clean scan is exit 1. Do not print matched text into any record; print file and line only.

## Scope-check (step 7)
Per unit, `scope-check.sh <tasks-file> <WORKTREE> <base-sha>`: exit 0 clean, 1 `CREEP <path>` lines, 2 usage. Sensitive paths (manifests, lockfiles, hooks, CI config) are matched against `git diff --name-only <base-sha>..HEAD`. A hit needs an `INSTALLED` row (ADR 0055) or a human grant file; otherwise C11 fails.

## Review loop (steps 11-14)
- Round `r` writes `fix-<agent-id>-<r>.md` and `verify-<seat-id>-<r>.md`; `r` is 1..3.
- Bus facts: topics `pr-check-N-closed`, read with `peek:true`, fresh `agent_id` per reader, `limit 200`. The orchestrator does not read closed topics through an agent id that already consumed them.
- D57 freeze: two consecutive rounds with no change to the core sections freeze scope. D60: the same finding class in two consecutive rounds replaces the mechanism (change the fixer brief or the check), not another retry. D59: an edge enumeration is closed by one check.
- Advisory, never rules: D44, D54 (a class-wide fix hint line in the fixer brief), D58, D61, D65, D66.
- Head moved during a round: rebase, repeat steps 1-2 on the new head, then a non-author delta verify of reviewed-head..new-head.
- Round 3 ended with open findings: `PREPR: STOP <ids>`; the human gets `record-<HEAD>.md` and `checklist-<subtask>.md` paths; the sub-task halts, others continue.

## Validator (step 17)
Re-run each evidence command (do not trust earlier output). Diff the plan's unit list (`.tasks/` files named by `dispatch-plan.md`) against the units on the branch. Any failing Blocking row fails; there is no score.

## Output files
`checklist-<subtask>.md`, `pr-body.md`, `fix-*`, `verify-*` all under `RUN_HOME/review/<subtask>/`. Writes are atomic: temp name in the same directory, then `mv`.
