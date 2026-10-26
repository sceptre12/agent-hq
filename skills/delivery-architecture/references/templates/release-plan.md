# Template: release-plan.md (design 5.5)

Purpose: what ships, in what order, who runs each step, and how to undo it. v0 is written at stage 2 at `plans/<epic>/release-plan.md`; v1 is written by `release-track` at `RUN_HOME/release-plan.md` (RUN only in this contract version, INTERFACES A.6). Step ids are minted in v0 and kept unchanged in v1.

**Writer / Reader:** v0 writer `delivery-architecture`; v1 writer `release-track`; readers the human (reads each `step_id` before writing `H-prod.<step_id>.<run-id>.ok`), the desk (`tag-push`, `publish`), the conductor.

## The step_id table (INTERFACES A.6, R4-J3)
- First column `step_id`: `^[a-z0-9-]+$`, unique in the plan.
- `owner`: `agent` or `human` (INTERFACES D2.1).
  - `agent`: staging deploy, polling, reporting.
  - `human`: production deploy, flag flip, money, production data, external publication, store submission (D15).
- Every `human` step, and any `tag-push` whose profile `release_tags.approval` is `human`, is gated by `RUN_HOME/gates/H-prod.<step_id>.<run-id>.ok` (INTERFACES A.2.1, A.2.2). The id in the gate file name, the `GATE <run-id> H-prod ok ...` line, `publish` and `tag-push` `step_id`, and `bodies/test-report-<step_id>.json` all name a row of this table.
- `command` is the exact prepared command, copied from the repo profile or written out in full; a human step shows it for the human to run. Unknown parts are `FILL_IN_BEFORE_DISPATCH`.
- `tag` is filled only for a tag step and must match `release_tags.pattern` of the profile; with no profile entry a tag step is refused (INTERFACES N11).

## Skeleton
````markdown
# Release plan: <epic>   (v0)
correlation_id: <JIRA-KEY>|PR-<n>|run   (INTERFACES A.5 column 5 shape)
repo_profile: <path>@<40-hex sha>
Scope: <what ships; sub-tasks and merge shas once known (40-hex)>

## Version
Intent: <major|minor|patch, per the profile>
Gates: <version bump check, dist scan, others from the profile>
Pre-release naming: <pattern or "none">

## Environments and order
<env 1 -> env 2 -> prod>

## Flags, config, migrations
| item | change | applied by |
|---|---|---|

## Steps
| step_id | step | owner (agent\|human) | tag | command (exact) | signal and threshold | rollback criterion | rollback command | evidence |
|---|---|---|---|---|---|---|---|---|
| deploy-staging | Deploy to staging | agent | - | FILL_IN_BEFORE_DISPATCH | health OK for FILL_IN_BEFORE_DISPATCH | any failing signal | FILL_IN_BEFORE_DISPATCH | log path |
| poll-staging | Poll staging signals | agent | - | FILL_IN_BEFORE_DISPATCH | FILL_IN_BEFORE_DISPATCH | threshold breached | - | log path |
| deploy-prod | Deploy to production | human | - | FILL_IN_BEFORE_DISPATCH | FILL_IN_BEFORE_DISPATCH | FILL_IN_BEFORE_DISPATCH | FILL_IN_BEFORE_DISPATCH | gate file |
The three rows above are examples of the shape; replace them. Use `-` when a column does not apply.

## Pre-release cleanup rule
<which pre-release tags, packages or deployments are removed and by whom>

## Published-artifact consumer simulation
<run before any stable publish: install the artifact the way a consumer does and run the smoke check; step_id of that row>

## Changelog and notification
| row | audience | channel | owner (agent|human) |
|---|---|---|---|

## Adjustment log
| date (YYYY-MM-DD) | change | reason | by |
|---|---|---|---|
````

## Checks
- Every `human` row has a `command` the human can run unchanged.
- No two rows share a `step_id`; ids match `^[a-z0-9-]+$`.
- v1 keeps v0 ids; new steps get new ids, no id is reused.
