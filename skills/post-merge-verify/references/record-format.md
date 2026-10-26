# Record format (postmerge-<sha>.md)

Path: `RUN_HOME/postmerge-<PM_SHA>.md`. Writer: this skill (part-a A.6). Readers: conductor, `release-track` (as `POSTMERGE_RECORD`). Written only when no stop condition fired; it is assembled from the staged `RUN_HOME/pm/evidence/` files (`<row-id>.line`, `<row-id>.heal-review`, `ci-status-main.stages`; skill-local, `DEFAULT`) after the verify-tier verdict.

```
POSTMERGE: FAIL e2e.checkout,unit.core
pm_sha: <40-hex>
worktree: <WORKTREE_BASE>/<run-id>-pm
## Rows
<row-id> <class> <result> [<reason>] <one-line evidence> policy="<failure-policy text>" [retried=<n>] [cache-served] [auto-heal reviewed=yes|no] log=<RUN_HOME/pm/evidence/<row-id>.log>
## Hand-test rows
<row-id> human <what the human must do, from the plan>
## Merge pipeline
ci-status-main merge_sha=<PM_SHA> <stage>=<state> ...
## Reporting
<reporting row id> release-track
## Not tested
<copied from the plan's explicitly-not-tested list>
```

Rules:
- Line 1 matches `^POSTMERGE: (PASS|FAIL)( [A-Za-z0-9.,-]+)?$` (part-d D1.1). PASS has no row list; FAIL lists the failed gating row ids, comma-separated.
- `<class>` is `gating` or `informational`; `<result>` is `PASS` or `FAIL`. No other verdict words. Every post-merge and consumer-simulation row id appears exactly once under `## Rows` or `## Hand-test rows`.
- `<reason>` (C2 reason words, part-c C2) appears on a `FAIL` line when one applies: only `env-bug` (`ENV_BUG`). `source-bug` and `lane-unavailable` never appear here: `SOURCE_BUG`, a refused port pair and a held lane lease all stop the run before any record (SKILL.md stop conditions).
- Evidence keys defined by this record: `policy=` (the row's failure-policy text, quoted verbatim), `retried=<n>` (retries made under that policy), `cache-served` (a bare flag on a `FAIL` line: the tool reported the result as served from cache, so it was not a run; `row-execution.md`), `auto-heal reviewed=yes|no` (e2e rows, set from `<row-id>.heal-review`, `e2e-rows.md`), `log=` (evidence path). None of these is a C2 reason.
- `## Merge pipeline` is copied from `pm/evidence/ci-status-main.stages` (`merge-pipeline.md`).
- The test-management reporting row is listed under `## Reporting` as `release-track`'s and never enters line 1.
- Informational failures appear as `FAIL` lines and never enter line 1.
- The `pm/new-units.md` ids are a subset of the failed gating ids in line 1.
