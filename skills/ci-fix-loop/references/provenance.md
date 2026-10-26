# ci-fix-loop provenance

Provenance: pending pilot. Source: design part-02 §2.2 card 11; INTERFACES 1.1.0 D2.2 row 11, D1.1 `CI:`, B4/B6 desk rows; owner rule D23 (`delivery-workflow-sources/owner-decisions.md` line 21).

## Sonar sub-cases (class `static-analysis-gate`)
Recorded on the pilot platform (`contribution-guidelines/04` §C; `architecture-04-cicd.md` Known Pipeline Bugs). Each is a one-retry flake class and is never fixed by editing scan configuration.

| Sub-case | Signal in the log | Action |
|---|---|---|
| Capacity-induced scan failure | Scanner or analysis server unavailable, queue or memory refusal, no finding list | One `ci-rerun`. Append `capacity: <job> <ci_run_id>` to the body of `ci/<pr>.md`. |
| Legacy smells already on `main` | Gate fails on issues in lines the PR did not change, the same issues present on `main` | One `ci-rerun`; if it repeats, human with the issue list. Do not touch scan configuration or suppress rules. |
| "No tasks were executed" false failure | Build reports no tasks executed, then the scan step fails | One `ci-rerun`. Append `capacity: <job> <ci_run_id>`. |

## Counting
- Signature failures: 3 of one `class + job` (RESOLVED Q1) -> `CI: HUMAN budget`.
- Capacity-induced failures: not counted against any signature. The run-wide count is derived: the number of lines `capacity: <job> <ci_run_id>` over `RUN_HOME/ci/*.md` (RESOLVED Q2). Nothing else stores it.
- When the run-wide count reaches the profile's tolerance, or the one retry fails again, the result is a human ping with `infra-runner`. This skill does not invent a threshold: if the profile has none, the one retry per failure is the only bound.

## Notes
- Hook skip and `GATE-PASS` are stated once in INTERFACES part A.7; this skill links there.
- Port guard: INTERFACES part A.5.2 (AM-1), fixer only.
- INTERFACES version checked at finish: 1.1.0 (AM-2 not yet landed at check time).
