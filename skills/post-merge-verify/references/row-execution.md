# Row execution (post-merge-verify)

## Scheduling
- Group rows by `lane`. A group is serial, in the plan's order or seed column. Groups run in parallel, each by its own execute-tier runner.
- Rows with lane `-` or empty are independent and parallel. Parallelism is bounded by free slots in the run's slot table; never start a runner without a slot.
- A runner holds its lane's `lane-lease` (`lane/<name>`) for the whole group. A lease that cannot be acquired (`catalog.sh register` exit 3) fails the group's rows with reason `lane-unavailable`; do not wait forever, do not release another holder's lease.

## Cold run
- Run the row's `command` exactly as written, in `<WORKTREE_BASE>/<run-id>-pm`, with the profile node activation first.
- Cold means no cache: remove or bypass the caches the profile names (build, test, task-runner). A result the tool reports as served from cache counts as not run and is rerun with the cache off.
- A row whose `cold-run` column says no is still run cold unless the plan states why; if the plan is silent, run cold.

## Judging
- Pass: exit code and the output satisfy the `expected` column. Anything else is a fail.
- Failure policy: quote the row's policy text into the evidence line. Apply it literally (for example "retry once"). Empty or unclear: no retry, the row fails.
- A retry that passes is recorded as `PASS` with `retried=1` in the evidence line, so the verify tier sees it.
- A gating row that needs a product decision to judge, or a destructive command with no recorded grant, is a stop condition; do not run it.

## Evidence
- Output tail and exit code go to `RUN_HOME/pm/evidence/<row-id>.log`. The evidence owner column names who may read it; the record only stores the path and a one-line summary.
- Never put secrets in a log. Redact per the profile `secrets.pattern_file` before writing.
