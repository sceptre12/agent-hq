# Executor rules

For the separate `cleanup-executor` (mechanical tier; persona brief `skills/delivery-run/references/briefs/cleanup-executor.md`) and the `validator` spot-check. Per-kind verify and cleanup commands are in INTERFACES A.5.1; this file adds only the guards and the flow. Apply that table by citation; do not copy it.

## Ground rules
- Act only on row ids in `## approved`. A path not in the approved list is never touched (D9).
- One `rm` per literal path, no `-r` on a computed or globbed path. A directory is removed by `rm -r <literal path>` only for the registered `tmpdir`, `clone` or `bus` `data_dir` handle, after re-measuring.
- Re-measure first (`du -sk`, `find <path> -type f | wc -l`, `.git` included). A mismatch with the dry run is a stop: write the mismatch to `## residual`, delete nothing for that row.
- A denied command or a sandbox or classifier block is a stop and a report. Do not wrap, reroute or retry through another channel.
- Write every command you ran, with its exit code, into `## executed`.

## Per kind (A.5.1 holds the commands)
- worktree: `git status --porcelain` empty, `git status --ignored` shows no uncaptured ignored file, and the PR is open or merged. Any failure: `catalog.sh keep` with the reason. Capture ignored files you must preserve before removal, never delete them to satisfy the guard.
- branch: local `git branch -D` and remote delete both only when content-merged into the handle's base: `git merge-base --is-ancestor`, or `git cherry <base> <branch>` with no `+` lines (patch-id equality), or the squash patch-id (B5). Remote delete: desk `branch-delete`, `{repo, branch, merged_into, merge_sha}`; use `fetch` `{repo, ref}` to verify the remote. The executor writes the `.req`; the host session sends the `DESK` line. `DONE` carries `deleted` and `merged_check`; `REJECTED marker` means `catalog.sh keep` plus a flag. The skill never runs `git push` or `gh`.
- process: pid from the row; `kill -0` before (a dead pid is just released), `kill <pid>`, `kill -0` after must fail. Never by name or pattern.
- port: `lsof -nP -iTCP:<port> -sTCP:LISTEN` must show no listener (stop the owning process first, a catalog row). Then `port-check.sh --claim <port> <bind> <container_port> <service> <project> released <source> <note>` with the claim's `port` and `source`; then `catalog.sh release port <port>`. Never edit `ports.tsv` by hand.
- pm2-app, bus, cron, bgtask: exact name or id from the row only.
- tmpdir, file, clone: `test -e`, then one `rm` per literal path.
- tag, container, image, workspace: `catalog.sh keep` with a reason, reported with the correlation id.
- db, lane-lease: as A.5.1.
- After each success: `catalog.sh release <kind> <handle>` (`fail` on a failed attempt, `keep <reason>` for a guard). Always pass `WORKTREE_BASE` inline.

## Abandoned run (`stage: stopped`)
Mode `final`, no `MERGE_RECORD`. Unmerged branches and their worktrees are `kept` and flagged (D8, D9). Processes, ports, leases, buses and temp dirs are released as usual.

## Spot-check protocol (`validator`)
A different agent from the executor and the approver. For every path or id in `## executed`: `test -e` is false; `kill -0` fails; `git worktree list` lacks the worktree; `git show-ref --verify` fails for a deleted local ref; `lsof` shows no listener; `catalog.sh list --live --subtask <st>` is empty of build resources. Write one line per check, then `SPOT-CHECK PASS` or `SPOT-CHECK FAIL <n>` under `## residual`. A fail goes back to the approver; it is not fixed by the validator.
