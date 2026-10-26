# Dry-run table

Read-only, built by the host session that will approve it (Step 2). Nothing is changed while this table is built. It becomes the `## dry-run` section of the cleanup record.

## Bases (stated on every row)
- Bytes: `du -sk <path>` (KiB).
- Files: `find <path> -type f | wc -l`, `.git` included. A worktree's `.git` is a file, a clone's `.git` is a directory; both are counted and the row says `.git included`.
- Measured path: the handle for `tmpdir`, `file`, `clone`, `bus` (its `data_dir`); for `worktree` the path part of the handle before `#`.
- Non-path kinds (`branch`, `tag`, `process`, `pm2-app`, `port`, `container`, `image`, `lane-lease`, `db`, `cron`, `bgtask`, `workspace`): bytes and files are `-`.
- The executor re-measures with the same commands before it deletes; a difference is a stop.

## Header line
`bytes=du -sk; files=find <path> -type f | wc -l; .git included`

## Columns
| Column | Content |
|---|---|
| row_id | from `catalog.tsv` (latest row for the `kind`+`handle`) |
| kind | catalog kind |
| handle | exact handle as registered |
| state | `planned`, `live` or `failed` (proposed: `delete`, `release` or `keep <reason>`); `kept` (carried, proposed `keep` with its `keep_reason`); a `released` row is skipped |
| liveness | the verify result for the kind from INTERFACES A.5.1 (for example `kill -0` ok, `git worktree list` names it) |
| bytes_kb | `du -sk` |
| files | `find -type f | wc -l` |
| guard | `ok` or the failed guard (dirty porcelain, ignored files, `no-pr-evidence`, not content-merged into main, `no-merge-sha`, listener not a catalog row, `no-claim-row`); `pid-identity`, `clone-unpushed`, `no-profile-cmd`; guards and their evidence: `references/executor-rules.md` |
| proposed | `delete`; `release` (already gone: a `GHOST` or dead pid of a kind that leaves no residue; `port`, `bus` and `branch` stay `delete`, per `references/executor-rules.md` "Already-gone rows"); `keep <reason>`; or `report` (non-catalog find) |

## Example rows
| row_id | kind | handle | state | liveness | bytes_kb | files | guard | proposed |
|---|---|---|---|---|---|---|---|---|
| 20261026T101500Z-lead-st1-4 | worktree | `<worktree_base>/<run-id>-st1#<repo>@main` | live | listed | 48210 | 3120 | ok | delete |
| 20261026T101600Z-lead-st1-5 | branch | `<repo>#PROJ-123-login-form@main` | live | local ref present | - | - | not content-merged | keep, not merged |
| 20261026T101700Z-lead-st1-6 | process | 48211 | live | kill -0 ok | - | - | ok | delete |
| 20261026T101800Z-lead-st1-7 | port | 5173 | live | listener present | - | - | ok | delete |
| 20261026T101900Z-lead-st1-8 | tag | `<repo>#v1.2.0@-` | live | tag listed | - | - | no delete verb | keep, report |
| 20261026T102000Z-lead-st1-9 | tmpdir | `<run-home>/st1/tmp-e2e` | planned | GHOST (gone) | - | - | ok | release |

## Findings outside the catalog
A separate list: path or id, how it was found, why it looks related. Sources, all read-only: `SQUATTER` lines of `catalog.sh audit` (a worktree under `worktree_base` named `<run-id>-*` with no open row); port squatters from `port-check.sh --audit` (A.5); `git worktree list` and `git branch --list` of the run's repos compared with the catalog handles; a listener on a catalog port whose process is no catalog row. No file-system glob is a source. These are reported in `## residual`. Cleanup never deletes them (D9).

## Audit findings
Copy the `GHOST` and `SQUATTER` lines from `catalog.sh audit` verbatim. A line for a row outside this pass's scope is reported only; it gets no table row and no action.
