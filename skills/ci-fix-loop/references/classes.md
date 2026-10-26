# ci-fix-loop: class to action table

Tokens are the 14 D2.2 row 11 tokens, exactly. `signature = class + job`. Budget is 3 failures per signature, then `CI: HUMAN budget`.
"Human" means: write `CI: HUMAN <class>` to line 1 of `RUN_HOME/ci/<pr>.md`, with the evidence excerpt and what was tried below it, then stop.

| Class | Action | Notes |
|---|---|---|
| `code-defect` | fix | Fixer briefed from the record. D23 check on `file_set` first. |
| `deterministic-test` | fix | Fix the code under test; never weaken, skip or delete the test. If the test itself is wrong, human. |
| `flake` | one `ci-rerun`, then quarantine proposal | Second failure of the same job: write the proposal (job, run ids, evidence) into `ci/<pr>.md`. A proposal, never an edit. |
| `infra-runner` | human | Runner or capacity fault outside the repo. A capacity-induced Sonar failure is the exception, see `provenance.md`. |
| `missing-secret-or-permission` | human, always | Excerpt and what was tried. Never request or supply a secret. |
| `external-service` | human, always | Third party outage or quota. |
| `policy` | human, always | Also the D23 stop class. |
| `commit-message-format` | fix | Only when the fix is a new commit on the branch (no force, no amend of pushed history); otherwise human. |
| `label-policy` | human | Labels are set by people. |
| `static-analysis-gate` | see `provenance.md` | Three Sonar sub-cases are one-retry flake classes. Otherwise fix the flagged code (`code-defect` path). Scan configuration is never edited. |
| `timeout` | one `ci-rerun`, then human | A fix is allowed only when the log shows a code-level hang in `file_set`. |
| `artifact-path` | human | Usually a pipeline definition fault: D23. |
| `workspace-mismatch` | human | Pipeline or checkout layout: D23. |
| `approval-timeout` | human, always | A gate waiting on a person. |

`ci-rerun` is for `flake` (and the one-retry sub-cases) only. The desk refuses it for any other class with `policy`.

## D23 check (before any fixer dispatch)
1. Read the profile `sensitive_paths[]` list (proposed key).
2. If it is absent, use the CI config paths the profile names.
3. If neither exists, do not dispatch the fixer: `CI: HUMAN policy`.
4. Any `file_set` path matching the list, or any fix that needs a pipeline definition, shared pipeline repo, trigger or required-check change: no edit, `CI: HUMAN policy`, the lead sets `stop_reason: stop-the-line:D23`.
