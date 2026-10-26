# Row execution (post-merge-verify)

## Scheduling
- Only runner rows (SKILL.md Step 1) are scheduled here: rows with `evidence owner` `human` (Step 8) and stage-covered rows (Step 9) never reach a runner, a lane lease, a port or a slot.
- Group rows by `lane`. A group is serial, in the plan's order or seed column. Groups run in parallel, each by its own execute-tier runner.
- Rows with lane `-` or empty take no lease and run in parallel; such a row that starts a server or names a port to bind is not run (no port-table candidate): stop and report to the `pm` lead (SKILL.md Step 4).
- Parallelism is bounded by free slots: the lead writes the A.4 slot row `RUN_HOME/pm/slots/<agent-id>.row` before each dispatch and dispatches only while the A.4 free-slot count `30 - live_rows - sum(A.3 reserved)` is above 0 (`live_rows` = `pm/slots/*.row` files). Never start a runner without a slot.
- The lead holds the lane's `lane-lease` (`lane/<name>`) for that lane's runner for the whole group, and releases it after the group's last row (SKILL.md Step 14). The lead takes the lease before any port claim or launch for that lane (SKILL.md Step 3). A lease that cannot be acquired (`catalog.sh register` exit 3: held) is a stop condition: report the lane to the `pm` lead, no wait, never release another holder's lease. It is not reported as `lane-unavailable`, which C2 defines only for a refused port pair (A.5.2).

## Cold run
- Run the row's `command` exactly as written, in `<WORKTREE_BASE>/<run-id>-pm`, with the profile `node.prefix_cmd` first.
- Cold means no cache (card 12; `enforcement-gates:141`). The worktree is fresh at `PM_SHA`. A result the tool reports as served from cache (for example a task runner's cache-hit line) is not a run: record the row `FAIL` with evidence key `cache-served` (`record-format.md`); the row's own command must carry the tool's no-cache form.
- A row whose `cold-run` column says no is still run cold unless the plan states why; if the plan is silent, run cold.

## Judging
- Pass: exit code and output satisfy the `expected` column. Anything else is a fail.
- Failure policy: quote the row's policy text into the evidence line. Apply it literally (for example "retry once"). Empty or unclear: no retry, the row fails.
- A retry that passes is recorded as `PASS` with evidence key `retried=<n>`, so the verify tier sees it.
- A row that needs a product decision to judge, or a destructive row with no recorded grant, is a stop condition (SKILL.md): do not run it.

## Evidence
- Output tail and exit code go to `RUN_HOME/pm/evidence/<row-id>.log`; the runner then writes the staged line `RUN_HOME/pm/evidence/<row-id>.line` in the record format. One writer per file: the runner for the `.line` of each runner row it runs; the lead for the `.line` of each stage-covered row (`merge-pipeline.md`) and the `human` `.line` of each hand-test row (SKILL.md Step 8); the Test-adequacy seat for `<row-id>.heal-review` (`e2e-rows.md`); the lead for `ci-status-main.stages`. The verdict reads them only after every runner and the seat have finished. All paths under `RUN_HOME/pm/` here are skill-local (`DEFAULT`), not INTERFACES paths.
- The evidence owner column names who may read the log; the record stores only the path and a one-line summary.
- Never put secrets in a log. Redact with the profile `secrets.pattern_file` before writing.
