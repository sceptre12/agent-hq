---
name: delivery-cleanup
description: Remove only the resources a delivery run registered in catalog.tsv, after a sub-task merges, after post-merge verify (pm), or when a run is abandoned (stage: stopped). Use when the lead receives MERGED, when the pm lead sees RELEASE LIVE or ROLLED-BACK, or when the conductor finishes every sub-task before stage done. Runs a read-only dry run, an approved explicit list, a separate executor that re-measures and deletes by literal path, and a validator spot-check; releases port rows with their registry claims; deletes branches only when content-merged (D8).
version: 0.1.0
---

## Trigger
Use when: inbox `MERGED <subtask> <merge_sha>` arrives (mode `subtask`); the `pm` lead reads `release-<pm_sha>.md` line 1 `RELEASE: LIVE` or `RELEASE: ROLLED-BACK` (mode `subtask`, `SUBTASK=pm`); the conductor sees every `subtasks[]` entry `cleaned`, before `stage: done` (mode `final`); or the run is abandoned, `state.md` `stage: stopped` (mode `final`, no `MERGE_RECORD`). The scope is catalog rows only (D9). Never use it to tidy anything the catalog does not list.

## Steps
0. **Step 0, inputs.** Validate `RUN_HOME` (absolute path, exists), `MODE` (`subtask|final`), `SUBTASK` (required and `^(st[0-9]+|pm)$` for `subtask`; omitted for `final`), `MERGE_RECORD` (path of `merge-<sha>.md`, four lines `pr=`, `merge_sha=`, `method=`, `merge_reach=`; required for `st<N>`; for `pm` and `final` the evidence is the `release-<pm_sha>.md` line 1 or `state.md` `stage: stopped`, part C5.1). Read `WORKTREE_BASE` from the profile `worktree_base` and pass it inline to every `catalog.sh` call. A bad field prints one line `INPUT-ERROR <NAME> <reason>` (reason `missing|enum|path|unset|format`), one line per field, then stop; no retry, no prompt.
1. **Audit.** `RUN_HOME=$RUN_HOME catalog.sh audit`. `GHOST` and `SQUATTER` lines go into the dry run as findings; do not fix by hand.
2. **Dry run (read-only).** Read `catalog.tsv` (latest row per `kind`+`handle`; mode `subtask` filters `subtask`, mode `final` takes the rest, `pm` included). Build the table per `references/dry-run-table.md`: one row per live or planned resource, bytes by `du -sk`, files by `find <path> -type f | wc -l`, `.git` included and stated. Also list finds that are not in the catalog; they go to `## residual` and are never deleted (D9). Nothing is changed in this step.
3. **Approval.** The approver (sub-task lead for `subtask`, conductor for `final`) writes an explicit list of row ids to delete. No pattern, no "all", no force path. A row whose guard fails is listed as `keep` with a reason.
4. **Execute.** Dispatch a separate mechanical-tier `cleanup-executor` (persona brief `skills/delivery-run/references/briefs/cleanup-executor.md`). It re-measures every approved path first; a bytes or file-count basis that differs from the dry run is a stop (report, no workaround). It applies the cleanup column of INTERFACES A.5.1 per kind (cite it, see `references/executor-rules.md`), one `rm` per literal path, `kill -0` before and after every pid, and records each command it ran in `## executed`. After a listener stops, a `port` row gets the `released` claim via `port-check.sh --claim`, then `catalog.sh release`. A classifier or permission block is a stop: report it, never wrap or reroute it.
5. **Branches.** Local and remote are both gated by D8: delete only when content-merged into the base (ancestor, or `git cherry` / patch-id equality, squash patch-id too). The executor writes a `branch-delete` `.req`; the host session sends the `DESK` line. `REJECTED marker` means `catalog.sh keep` with a reason and a flag, not a retry.
6. **Spot-check.** A different agent, persona `validator`, never the executor or the approver, re-tests every path in `## executed` (`test -e` false, `kill -0` fails, `git worktree list` lacks it, ref gone, `lsof` shows no listener) and writes its result into `## residual`.
7. **Record.** Write `RUN_HOME/cleanup-<run-id>-<subtask|final>.md` atomically per `references/cleanup-record.md`: line 1 `CLEANUP DONE st<N>|pm|final`, then `## dry-run`, `## approved`, `## executed`, `## residual`. Temp name, then `mv` after `## residual` is complete.
8. **Verify.** `catalog.sh list --live --subtask <st>` shows 0 build resources (mode `final`: `list --live` shows none of the run's build resources). Send nothing else; the conductor reads line 1 of the record.

Never touched: ledger and records (`state.md`, `substate.md`, `catalog.tsv`, `merge-*`, `review/`, `desk/`, `gates/`, `cleanup-*`), `RUN_HOME/<subtask>/security-audit/run-<N>/` (a run record, A.5.3; the plane is archived at CYCLE DONE), other sessions' worktrees, open PR branches, credentials. A process or tmpdir a security-audit agent registered is a normal catalog row.

## Red flags
| Thought | Do instead |
|---|---|
| "This tmp dir looks like ours, delete it" | Not in `catalog.tsv`: report in `## residual`, never delete (D9). |
| "Branch is merged by ancestor check only" | Ancestor OR `git cherry` / patch-id equality; squash merges fail ancestor. Else keep and flag (D8). |
| "Remote branch delete is safe, only the local needs the check" | Local and remote are both gated; remote goes through desk `branch-delete`, never `git push`. |
| "Worktree has a few ignored files, remove anyway" | `git status --ignored` must show nothing uncaptured; capture first, then remove. Dirty porcelain means keep. |
| "Kill it by name, the pid changed" | Only by the pid in a catalog row, `kill -0` before and after. Never by name or pattern. |
| "Free the port in `ports.tsv` by hand" | Stop the listener, run the `released` claim with the claim's `port` and `source`, then `catalog.sh release`. |
| "Counts differ slightly, continue" | Count-basis mismatch is a stop. |
| "The executor can approve and check itself" | Approver, executor and validator are three different agents. |
| "Tag, container, image, workspace: delete it" | No delete verb exists; `kept` and reported (A.5.1). |
| "Abandoned run, clear every branch" | `stage: stopped`: unmerged branches and their worktrees are `kept` and flagged; processes, ports, leases, buses, temp dirs are released. |

## Exit criteria
- [ ] `list --live --subtask <st>` shows 0 build resources; every row of the sub-task is `released` or `kept` with a reason.
- [ ] The record's first line matches `^CLEANUP DONE (st[0-9]+|pm|final)$` and the four sections follow in order.
- [ ] The `validator` spot-check passed and is written in `## residual`; non-catalog finds are listed there, untouched.
- [ ] Every deleted branch was content-merged; every other branch is `kept` with a flag.
- [ ] Second pass done: mode `subtask` for `pm` after `RELEASE: LIVE|ROLLED-BACK`; mode `final` for the run (also when `stage: stopped`), which releases the stage 6 and 7 worktrees.
- [ ] No ledger, record, other-session worktree, open PR branch or credential was touched.

## Provenance
Provenance: pending pilot (<pilot-run-id>). Friction: cleanup facts C1-C3, C9; `worktree-cleanup-merged-vs-ancestor`; scope-control retro (capture before delete); simulator leases held 11 h. Rulings D8, D9, D7. Contract: INTERFACES 1.1.0 A.5.1-A.5.3, A.6, B4-B6, D1, D2.2 row 9. Spec: `architecture/delivery-workflow/tasks/19-delivery-cleanup.md`.
