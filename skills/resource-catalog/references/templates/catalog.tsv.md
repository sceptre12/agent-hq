# Template: `catalog.tsv` (the run's resource registry)

Purpose: the append-only ledger of every resource a run creates, so cleanup and resume act only on registered rows (INTERFACES A.5). This file documents the empty file `delivery-dispatch-plan` creates and the row grammar; it is not a data file.

**Writer / Reader:** writer `catalog.sh` only, by single-line `>>` append under `mkdir RUN_HOME/catalog.lock` (every agent writes through the script, none edits the file). Readers: `delivery-cleanup`, lead reconcile and resume, shepherd, `pre-pr-gate` (no `planned` rows), `catalog.sh audit`. Plane: `RUN_HOME/catalog.tsv` (D6).

## Row: 12 tab-separated columns (A.5)
| # | column | value |
|---|---|---|
| 1 | `ts` | ISO UTC |
| 2 | `run_id` | `<run-id>` |
| 3 | `subtask` | `<subtask>` or `run` |
| 4 | `row_id` | `<yyyymmddThhmmssZ>-<owner_agent>-<n>`, minted by `catalog.sh` (n = rows + 1) |
| 5 | `correlation_id` | `<JIRA-KEY>` or `PR-<n>` or `run` |
| 6 | `kind` | one of the kinds below |
| 7 | `handle` | per-kind grammar below |
| 8 | `owner_agent` | `agent_id` |
| 9 | `unit` | `^([ui][0-9]+\|-)$` |
| 10 | `state` | `planned\|live\|released\|failed\|kept` |
| 11 | `keep_reason` | text when `state=kept`, else `-` |
| 12 | `source` | the skill or script that appended |

Note, dropped column: the earlier `verify_cmd` column is dropped (M26). There is no executable column; the per-kind table in A.5.1 supplies the verify and cleanup actions. Rejected on append: a control character; a row over 400 bytes including its newline; a path-kind `handle` whose realpath is outside `RUN_HOME` or the registered `worktree_base`.

## The kinds and their handles (A.5, A.5.1)
| kind | handle | verify (liveness) |
|---|---|---|
| `worktree` | `<abs-path>#<repo-abs-path>@<base>` | `git worktree list` names it |
| `branch` | `<repo-abs-path>#<ref>@<base>` | `git show-ref --verify refs/heads/<branch>`; desk `fetch` for remote |
| `tag` | `<repo-abs-path>#<tag>@-` | `git tag -l <tag>` (kept; deletion is a human step) |
| `process` | pid | `kill -0 <pid>` |
| `pm2-app` | name `^[A-Za-z0-9._/:-]+$` | `pm2 jlist` lists the exact name |
| `port` | int | `lsof -nP -iTCP:<port> -sTCP:LISTEN` |
| `bus` | `data_dir` abs path | `kill -0` on the `bus.endpoint` pid |
| `tmpdir` | abs path | `test -e <path>` |
| `container` | name | not verifiable from a lead session; kept and reported |
| `image` | name | not verifiable from a lead session; kept and reported |
| `lane-lease` | `gate-runner/<n>` or `lane/<name>` | latest row is `live` |
| `db` | name | the profile lane's verify string (a profile key, not a column) |
| `clone` | abs path | `test -e <path>` |
| `cron` | tool id | `CronList` shows the id |
| `bgtask` | tool id | `TaskList` shows the id |
| `file` | abs path | `test -e <path>` |
| `workspace` | name | not verifiable from a lead session; kept and reported |

The kind enum is closed at the 17 values above, exactly as A.5 lists it (INTERFACES 1.3.0 A.5 row 6, AM-3 errata (b): 17 kinds, the count of 18 was a miscount; none is omitted). Cleanup actions are in A.5.1 and are applied by the `delivery-cleanup` executor.

## Lifecycle (A.5)
`register` (`planned`) before start; `start` (`live`) after; `release`, `keep <reason>`, `fail`; `list --live`; `audit`. The supersede key is `kind` + `handle`; the latest row for that pair is the resource's state. `audit` classifies `MATCH`, `GHOST`, `SQUATTER` against `kill -0`, `lsof`, `git worktree list`. A `lane-lease` is acquired by compare-and-append and written `live` directly; exit 3 means already held.

## Port claim order (AM-1, A.5.2; the single statement is there)
For every `port` row, before the launch:
1. Claim: `tools/port-check.sh --claim <port> <bind> <container_port> <service> <project> claimed <source> <note>` through the `port-claim` skill (`project` = `<run-id>`, `source` = `<run-id>-<subtask>`). The candidate comes from the dispatch-plan port table.
2. `catalog.sh register port <port> ...` writes the `planned` row.
3. Launch.
4. `catalog.sh start port <port>` writes `live`.

Collision: `port-check.sh` exit 1 (taken) or 2 (registry and `lsof` disagree) refuses the launch; the launcher never auto-picks another port; on the first refusal it makes exactly one retry at candidate + 10, itself claimed with `port-check.sh --claim` before any bind; a second refusal stops the line and is reported to its lead (a lane maps to C2 reason `lane-unavailable`). Exit 3 (registry unusable) is stop-the-line. The single statement is INTERFACES A.5.2 (AM-3, owner OQ-2). Release is cleanup only: after the listener is stopped, `port-check.sh --claim ... released ...` (a `released` row supersedes the claim), then `catalog.sh release`.

## Skeleton (example rows; tabs shown as `<TAB>`)
```
2026-11-02T10:00:00Z<TAB><run-id><TAB>st1<TAB><yyyymmddThhmmssZ>-<owner_agent>-1<TAB><JIRA-KEY><TAB>port<TAB><port><TAB><agent_id><TAB>u1<TAB>planned<TAB>-<TAB>delivery-run
```
The file starts empty (zero bytes); rows are only ever appended.
