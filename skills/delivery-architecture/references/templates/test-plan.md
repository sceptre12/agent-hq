# Template: test-plan.md v0 (design 5.4)

Purpose: how the epic is proven, before merge and after. Path `plans/<epic>/test-plan.md` (v0, written at stage 2). `post-merge-verify` runs the post-merge rows and records results in `RUN_HOME/postmerge-<sha>.md`.

**Writer / Reader:** writer `delivery-architecture` (INTERFACES A.6); readers `delivery-dispatch-plan` (e2e per unit), `pre-pr-gate`, `post-merge-verify`, `release-track`, the human at H-e2e.

## Rules
- Strategy line and phase order come from the repo profile (`repo-profile.md`, INTERFACES A.2.2); link it as `@<40-hex sha>`, never copy it.
- e2e per unit is exactly `new`, `updated` or `none` (INTERFACES D2.1); `e2e.harness` is `nlta` or `none` (D2.1). With `none`, name the gap and use human hand-test rows (D17).
- Post-merge row class is `gating` or `informational` (D2.1).
- Unmeasured thresholds are `FILL_IN_BEFORE_DISPATCH`. Dates `YYYY-MM-DD`; shas 40-hex.
- The gate record `GATE-PASS` and the `HUSKY=0` rule are stated once in INTERFACES A.7; link, do not restate.

## Skeleton
````markdown
# Test plan: <epic>   (v0)
repo_profile: <path>@<40-hex sha>
Strategy: <one line from the profile>
Phase order: <from the profile, e.g. unit, integration, e2e, post-merge>

## A. Pre-merge
### A1. Per acceptance criterion
| ticket slug | AC (scenario) | test file | level (unit|integration|e2e) |
|---|---|---|---|

### A2. Parity and pre-checks
| row | what | command (from the profile) | expected |
|---|---|---|---|
| ci-parity | local gate equals CI | <profile command> | same result as CI |
| standardization-precheck | repo conventions satisfied | <profile command> | clean |

### A3. e2e rows (omit when every unit is `none`)
| unit slug | .feature path | Gherkin checkpoint date | generated spec path | nl-run-e2e result | auto-healed diffs reviewed (yes|no) |
|---|---|---|---|---|---|
Gherkin checkpoint date is `YYYY-MM-DD`; the human signs H-e2e per sub-task (INTERFACES A.2.1).

### A4. Coverage thresholds
| scope | threshold | source |
|---|---|---|
| <glob or package> | FILL_IN_BEFORE_DISPATCH | repo profile |

## B. Post-merge
| id | what it proves | command | lane | expected | evidence owner | cold-run (yes|no) | order or seed | class (gating|informational) | failure policy |
|---|---|---|---|---|---|---|---|---|---|
Human hand-test rows (no harness, D17): same columns, `command` is the written manual procedure, `evidence owner` is `human`.

## C. Consumer simulation
| id | consumer | how it is simulated | expected |
|---|---|---|---|

## D. Test-management reporting
| row | what is reported | via |
|---|---|---|
| report | results to the test-management system | desk verb `test-report-push` (INTERFACES B4; conductor only, via `release-track`) |

## E. Explicitly not tested
- <item>: <reason>
````

## Checks
- Every acceptance criterion in `drafts/` appears in A1.
- Every `gating` row has a failure policy.
- No `post-merge` row invents a command the profile does not provide; use `FILL_IN_BEFORE_DISPATCH`.
