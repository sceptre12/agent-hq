# Catalog kinds and handles

Authority: INTERFACES part A.5 (columns, handle grammar, lifecycle) and A.5.1 (the per-kind verify and cleanup table inside `catalog.sh`; not restated here). Every call is `catalog.sh register <kind> <handle> <unit|-> <correlation_id> <source> <subtask|run> <owner_agent>`, then `start`, then `release`, with `keep <kind> <handle> <reason>` and `fail <kind> <handle>` as the other exits. `RUN_HOME` is set in the environment: an absolute path to an existing directory whose last segment is the run-id, matching `[a-z0-9-]+` (example run-id: `found-1234-20261102`). The path kinds (`tmpdir`, `file`, `clone`, `bus`) and the path part of a `worktree` handle must be absolute, contain no `..`, and have a realpath strictly under `RUN_HOME` or `WORKTREE_BASE`; pass `WORKTREE_BASE` inline from the profile (absolute, no whitespace) on calls that register worktrees and on `audit`. Rows are 12 TSV fields, at most 400 bytes including the newline, no control characters, no empty argument.

One line per kind: handle form, then the register example.

- `worktree`: `<abs-path>#<repo-abs-path>@<base>`. `WORKTREE_BASE=/abs/wt catalog.sh register worktree ...` (path under `WORKTREE_BASE`).
- `branch`: `<repo-abs-path>#<ref>@<base>` (base: the branch it must be content-merged into; never `-`).
- `tag`: `<repo-abs-path>#<ref>@-`; no delete verb exists, cleanup keeps and reports it.
- `process`: a pid. Register the pid, not a name pattern.
- `pm2-app`: a name matching `^[A-Za-z0-9._/:-]+$`; by convention (not checked by the script) `<run-id>-<subtask>-<name>`, e.g. `found-1234-20261102-st1-api`.
- `port`: an integer 1-65535. Always preceded by a claim: `references/ports.md`.
- `bus`: its `data_dir`, an absolute path (root rule above).
- `tmpdir`, `file`, `clone`: an absolute path (root rule above).
- `container`, `image`, `workspace`, `db`: a name matching `^[A-Za-z0-9._/:-]+$`.
- `lane-lease`: `gate-runner/<n>` or `lane/<name>`; register writes `live`, exit 3 when held.
- `cron`, `bgtask`: the tool id returned by the creating tool.

Examples (7 arguments after `register`):

```
catalog.sh register tmpdir $RUN_HOME/tmp/st1 u07 <JIRA-KEY>-1234 delivery-run st1 impl-u07
catalog.sh register bus $RUN_HOME/st1/bus - <JIRA-KEY>-1234 delivery-run st1 lead
catalog.sh register lane-lease lane/e2e-a - <JIRA-KEY>-1234 delivery-run run lead
```

Then `catalog.sh start tmpdir $RUN_HOME/tmp/st1` after creating it and `catalog.sh release tmpdir $RUN_HOME/tmp/st1` after it is removed. `unit` is `-` for run-level rows and `u<N>` or `i<N>` otherwise.
