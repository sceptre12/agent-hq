# ci-fix-loop: class to action table

Tokens are the 14 D2.2 row 11 tokens, exactly. `signature = class + job`. Budget is 3 failures per signature, then `CI: HUMAN budget`; capacity sub-cases are outside it (`provenance.md`).
"Human" means: write `CI: HUMAN <class>` to line 1 of `RUN_HOME/ci/<pr>.md`, with the evidence excerpt and what was tried below it, then stop. The class token is kept; only a D23 check that fires (below) writes `policy` instead.

| Class | Action | Notes |
|---|---|---|
| `code-defect` | fix | Fixer briefed from the record. D23 check on `file_set` first. Includes a code-level hang in PR code, and a real scan finding in PR-changed lines. |
| `deterministic-test` | fix | Fix the code under test; never weaken, skip or delete the test. If the test itself is wrong, human. |
| `flake` | one `ci-rerun`, then human | Second failure of the same job: write the quarantine proposal (job, run ids, evidence) into `ci/<pr>.md`, a proposal never an edit, and end `CI: HUMAN flake`. The three Sonar sub-cases are this class (`provenance.md`); a failed retry of a capacity sub-case ends `CI: HUMAN infra-runner` instead. |
| `infra-runner` | human | Runner or capacity fault outside the repo. |
| `missing-secret-or-permission` | human, always | Excerpt and what was tried. Never request or supply a secret. |
| `external-service` | human, always | Third party outage or quota. Also a failing required check with `ci_run_id: null` (no Actions run, e.g. an external status context): set by SKILL.md step 2 without a diagnoser, one line `no-ci-run: <check name>` (AM-10). |
| `policy` | human, always | Also the D23 stop token. |
| `commit-message-format` | human | Not code-caused; a fix would rewrite pushed history, which needs force (never). `file_set` is empty. |
| `label-policy` | human | Labels are set by people. |
| `static-analysis-gate` | human | Any scan-gate failure that is neither a Sonar sub-case (`flake`) nor a real finding in PR-changed lines (`code-defect`). Scan configuration is never edited. |
| `timeout` | human | The pipeline or runner time limit was hit. A code-level hang is diagnosed `code-defect`, not `timeout`. |
| `artifact-path` | human | Usually a pipeline definition fault; no edit. |
| `workspace-mismatch` | human | Pipeline or checkout layout; no edit. |
| `approval-timeout` | human, always | A gate waiting on a person. |

`ci-rerun` is for `flake` only (Sonar sub-cases included). The desk refuses it for any other class with `policy` (B4).

## D23 check (before any fixer dispatch)
1. Read the profile `sensitive_paths[]` (A.2.2, a required key; missing is `INPUT-ERROR sensitive_paths[] missing` at Step 0).
2. Any `file_set` path matching one of its EREs, any fix that needs a pipeline definition, shared pipeline repo, trigger, required-check or scan configuration change, or an empty list: no fixer, no edit.
3. Write `CI: HUMAN policy` (RESOLVED Q3); the lead sets `stop_reason: stop-the-line:D23`. In every other case the line carries the record's class token, except `budget` (step 4) and the round-3 review stop `d7-round3` (SKILL.md step 9, AM-5).
