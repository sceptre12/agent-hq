# ci-fix-loop provenance

Provenance: pending pilot. Source: design part-02 §2.2 card 11; INTERFACES 1.10.0 D2.2 row 11, D1.1 `CI:`, A.2.2 `sensitive_paths[]`, A.5.2, A.7, B4/B6 desk rows (B4 `push` first/later push, AM-4 24-Q2); A.3 `stop_reason` `d7-round3` (AM-5); owner rule D23 (`delivery-workflow-sources/owner-decisions.md` line 21).

## Sonar sub-cases (diagnosed as `flake`)
Recorded on the pilot platform (`contribution-guidelines/04` §C; `architecture-04-cicd.md` Known Pipeline Bugs). Card 11: each is a one-retry flake class and is never fixed by editing scan configuration. The diagnoser classifies each as `flake` and names the sub-case in `evidence`. A real finding in PR-changed lines is `code-defect`; any other scan-gate failure is `static-analysis-gate` (human).

| Sub-case | Signal in the log | Capacity | Action |
|---|---|---|---|
| Capacity-induced scan failure | Scanner or analysis server unavailable, queue or memory refusal, no finding list | yes | One `ci-rerun`. Append `capacity: <job> <ci_run_id>` to the body of `ci/<pr>.md`. Retry fails: `CI: HUMAN infra-runner`. |
| Legacy smells already on `main` | Gate fails on issues in lines the PR did not change, the same issues present on `main` | no | One `ci-rerun`; if it repeats, `CI: HUMAN flake` with the issue list. Do not touch scan configuration or suppress rules. |
| "No tasks were executed" false failure | Build reports no tasks executed, then the scan step fails | yes | One `ci-rerun`. Append `capacity: <job> <ci_run_id>`. Retry fails: `CI: HUMAN infra-runner`. |

## Counting
- Signature failures: 3 of one `class + job` (RESOLVED Q1) -> `CI: HUMAN budget`. A non-capacity sub-case counts against its `flake` signature.
- Capacity sub-cases: not counted against any signature. The run-wide count is derived: the number of lines `capacity: <job> <ci_run_id>` (the failing check's own `checks[]` run id, AM-10) over `RUN_HOME/ci/*.md` (RESOLVED Q2). Nothing else stores it.
- Each capacity failure gets one retry; a failed retry ends `CI: HUMAN infra-runner`. No run-wide threshold is defined here.

## Notes
- Hook skip and `GATE-PASS` are stated once in INTERFACES part A.7 (writer: the gate runner); this skill links there.
- Port guard: INTERFACES part A.5.2 (AM-1, AM-3), fixer only.
- INTERFACES version checked: 1.5.0, 2026-10-26.
