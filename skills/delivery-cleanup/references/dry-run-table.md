# Dry-run table

Read-only. Nothing is changed while this table is built. It becomes the `## dry-run` section of the cleanup record.

## Bases (stated on every row)
- Bytes: `du -sk <path>` (KiB).
- Files: `find <path> -type f | wc -l`, `.git` included. A worktree's `.git` is a file, a clone's `.git` is a directory; both are counted and the row says `.git included`.
- Non-path kinds (process, port, pm2-app, cron, bgtask, lane-lease, branch): bytes and files are `-`.
- The executor re-measures with the same commands before it deletes; a difference is a stop.

## Header line
`bytes=du -sk; files=find <path> -type f | wc -l; .git included`

## Columns
| Column | Content |
|---|---|
| row_id | from `catalog.tsv` (latest row for the `kind`+`handle`) |
| kind | catalog kind |
| handle | exact handle as registered |
| state | `planned` or `live` (a `released` row is skipped) |
| liveness | the verify result for the kind from INTERFACES A.5.1 (for example `kill -0` ok, `git worktree list` names it) |
| bytes_kb | `du -sk` |
| files | `find -type f | wc -l` |
| guard | `ok` or the failed guard (dirty porcelain, ignored files, PR not open or merged, not content-merged, base unknown) |
| proposed | `delete`, `keep <reason>` or `report` |

## Example rows
| row_id | kind | handle | state | liveness | bytes_kb | files | guard | proposed |
|---|---|---|---|---|---|---|---|---|
| 20261026T101500Z-lead-st1-4 | worktree | `<worktree_base>/<run-id>-st1#<repo>@main` | live | listed | 48210 | 3120 | ok | delete |
| 20261026T101600Z-lead-st1-5 | branch | `<repo>#feat-x@main` | live | local ref present | - | - | not content-merged | keep, not merged |
| 20261026T101700Z-lead-st1-6 | process | 48211 | live | kill -0 ok | - | - | ok | delete |
| 20261026T101800Z-lead-st1-7 | port | 5173 | live | listener present | - | - | ok | delete |
| 20261026T101900Z-lead-st1-8 | tag | `v1.2.0` | live | tag listed | - | - | no delete verb | keep, report |

## Findings outside the catalog
A separate list: path or id, how it was found, why it looks related. These are reported in `## residual`. Cleanup never deletes them (D9).

## Audit findings
Copy the `GHOST` and `SQUATTER` lines from `catalog.sh audit` verbatim.
