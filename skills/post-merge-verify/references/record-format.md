# Record format (postmerge-<sha>.md)

Path: `RUN_HOME/postmerge-<PM_SHA>.md`. Writer: this skill. Reader: conductor, `release-track` (as `POSTMERGE_RECORD`).

```
POSTMERGE: FAIL e2e.checkout,unit.core
pm_sha: <40-hex>
worktree: <WORKTREE_BASE>/<run-id>-pm
## Rows
<row-id> <class> <result> <one-line evidence> log=<RUN_HOME/pm/evidence/<row-id>.log>
## Hand-test rows
<row-id> human <what the human must do, from the plan>
## Merge pipeline
ci-status-main merge_sha=<PM_SHA> <stage>=<state> ...
## Not tested
<copied from the plan's explicitly-not-tested list>
```

Rules:
- Line 1 matches `^POSTMERGE: (PASS|FAIL)( [A-Za-z0-9.,-]+)?$`. PASS has no row list; FAIL lists the failed gating row ids, comma-separated.
- `<class>` is `gating` or `informational`; `<result>` is `PASS` or `FAIL`. No other verdict words. Every post-merge row id appears exactly once under `## Rows` or `## Hand-test rows`.
- A failed row names its reason after the result when one applies: `lane-unavailable`, `env-bug`, `source-bug`.
- Informational failures appear as `FAIL` lines and never enter line 1.
- The `pm/new-units.md` ids are a subset of the ids in this file.
