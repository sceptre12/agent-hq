# Task Spec: T19 `delivery-cleanup` (W1 item 19, stage 5c and the second pass)

> Written 2026-10-26 (W0 item 2b) from design card 9 (`part-02-skill-inventory.md` §2.2), `part-01` §1 stage 5c and the two exits, INTERFACES `1.1.0` (FROZEN; amendment AM-1 landed: A.5.1 `port` row, A.5.2, A.5.3), owner rulings D8 and D9 (`architecture/delivery-workflow-sources/owner-decisions.md:18-19`).
> Author: one execute-tier agent, about 1 h. Not split, no integration step. Reviewer path: Rung 1 trio, at most 3 rounds, then the owner (D7).

**Done condition (one, machine-checkable):** the command block in section 9 exits 0 and its last stdout line is `SKILL-19-OK`.
**Tier:** execute (the executor persona it describes is mechanical, §3.1). **Rung:** 1.
**Depends on:** INTERFACES 1.1.0 (done); item 18 (`resource-catalog`, called by name); item 5 (`catalog.sh`, for `list --live` and `release`/`fail`/`keep`); item 8 (`port-claim`). Desk verbs `branch-delete`, `fetch` are specified by ADR 0055 and INTERFACES part B (item 26 builds the desk; no runtime dependency in the checks).

## 1. Objective
Write the skill `delivery-cleanup`: after a sub-task merges, or a run is abandoned, remove only what `catalog.tsv` says the run created (D9), through a read-only dry run, an explicit approved list, a separate executor that re-measures and deletes by literal path, and a different agent's spot check; it releases `port` rows with their registry claims; it deletes branches only when content-merged (D8).

## 2. Context package
- Card 9 steps (read-only dry run with a `du -sk` basis; lead approves an explicit list; separate executor re-measures and deletes by literal path, one `rm` per path; processes by pid with `kill -0` before and after; worktree removal only with clean `git status --porcelain`, `git status --ignored` showing no uncaptured ignored files, and its PR open or merged; dry-run table states bytes basis `du -sk` and file-count basis `find -type f | wc -l` with `.git` stated; branch deletion local and remote via `delivery-desk branch-delete` only when content-merged, by ancestor OR `git cherry`/patch-id content equality, else keep and flag; catalog rows only, non-catalog finds reported never deleted; a different agent spot-checks).
- Must never touch: ledger and records, other sessions' worktrees, open PR branches, credentials.
- Exit: `CLEANUP DONE` per sub-task at 5c (every catalog row the sub-task's build created is `released`, PR open or merged, worktrees gone; M32); a second pass after stage 8 releases the stage 6 and 7 worktrees.
- Friction (Provenance): cleanup facts C1-C3, C9; `worktree-cleanup-merged-vs-ancestor`; scope-control retro capture-before-delete; simulator leases held 11 h (`part-06` §7b stage 5c).

## 3. Scope
**In (write only under `skills/delivery-cleanup/`):**
- `SKILL.md` (body under 5k tokens): frontmatter (`name`, "Use when" description of 1024 characters or fewer, `version: 0.1.0`), `## Trigger`, `## Steps` (Step 0 first), `## Red flags`, `## Exit criteria`, `## Provenance`.
- `references/dry-run-table.md` (columns, both count bases, the stated `.git` inclusion, example rows).
- `references/executor-rules.md` (per-kind handling by pointer to A.5.1, one `rm` per literal path, `kill -0` before/after, worktree/branch guards, desk request flow, spot-check protocol).
- `references/cleanup-record.md` (the `cleanup-<run-id>-<subtask|final>.md` layout, sections in order, atomic write).

**Out:** `tools/**`, `skills/resource-catalog/**`, `skills/delivery-run/**` (briefs, including the cleanup-executor persona brief, item 27b), INTERFACES, ADRs, `skills/port-claim/**`.
**Do NOT create:** a script that deletes, a symlink, a restated copy of the A.5.1 table (cite it), any delete verb for tags/containers/images/workspaces (they are `kept` and reported, A.5.1), a "force" or "pattern" delete path, cost metrics.

## 4. Contracts
| Contract | Field / value | Authority |
|---|---|---|
| Step 0 inputs | `RUN_HOME`, `MODE` (`subtask\|final`), `SUBTASK` (required for `subtask`, omitted for `final`), `MERGE_RECORD` (path of `merge-<sha>.md`; mode `subtask` for `st<N>`; evidence for `pm` and `final` per C5.1); `catalog.tsv` derived; `INPUT-ERROR <NAME> <reason>` one line per field then stop | `part-d-enums-topics.md` D1, D2.2 row 9 |
| Output | `RUN_HOME/cleanup-<run-id>-<subtask\|final>.md`; line 1 `CLEANUP DONE st[0-9]+\|pm\|final` (regex `^CLEANUP DONE (st[0-9]+\|pm\|final)$`); then `## dry-run`, `## approved`, `## executed`, `## residual` in that order; executor writes a temp name, `mv`s after `## residual` is complete | A.6; D1.1 |
| Roles | approver: sub-task lead (mode `subtask`) or conductor (mode `final`); executor: a separate mechanical-tier agent (`cleanup-executor`); spot-check: a different agent | D2.2 row 9; `part-03` §3.1 |
| Triggers | inbox `MERGED <subtask> <merge_sha>` runs mode `subtask`; the `pm` lead runs mode `subtask` for `pm` once `release-<pm_sha>.md` line 1 is `RELEASE: LIVE` or `RELEASE: ROLLED-BACK`; the conductor runs mode `final` once every `subtasks[]` entry is `cleaned`, before `stage: done` | C5.1 |
| Merge evidence | `merge-<sha>.md` four lines `pr=`, `merge_sha=`, `method=`, `merge_reach=` | A.6 |
| Catalog use | read rows by `kind`+`handle` latest state; act via `catalog.sh release`/`fail`/`keep`; `list --live --subtask <st>` must be empty of build resources at exit; run `audit` first | A.5; Script interfaces table |
| Per-kind cleanup | the table in A.5.1 (worktree, branch, process, port, pm2-app, bus, tmpdir/file/clone, tag, container/image/workspace, db, cron, bgtask, lane-lease) | A.5.1 |
| Port rows | liveness `lsof -nP -iTCP:<port> -sTCP:LISTEN`; only after the listener is stopped, `port-check.sh --claim <port> <bind> <container_port> <service> <project> released <source> <note>` with the claim's `port` and `source` (a `released` row supersedes the claim), then `catalog.sh release`; never a hand edit of `ports.tsv` | A.5.1 `port` row; A.5.2 |
| security-audit output | `RUN_HOME/<subtask>/security-audit/run-<N>/` is a RUN record (full mode only), not a catalog build resource: never deleted by cleanup; any process or tmpdir its agents registered is a normal catalog row | A.5.3; D6 row; card 9 never-touch |
| Branch delete | desk `branch-delete` `{repo, branch, merged_into, merge_sha}`; the executor writes the `.req`, the host session (lead or conductor) sends the `DESK` line; `DONE` carries `deleted` and `merged_check` in `ancestor\|patch-id\|squash`; `REJECTED marker` means keep and flag | B4, B5, B6; R3 H4 |
| `fetch` | desk verb `{repo, ref}` used to verify the remote branch | B4 |
| Never touch | ledger and records (`state.md`, `substate.md`, `catalog.tsv`, `merge-*`, `review/`, `desk/`, `gates/`, `cleanup-*`), other sessions' worktrees, open PR branches, credentials | card 9; A.5.1 |
| Count bases | bytes `du -sk`; files `find <path> -type f \| wc -l`, `.git` included, stated on every row | A.5.1 |

## 5. Inherited module API
- `catalog.sh` and `skills/resource-catalog` for row transitions; `delivery-desk` verbs by request file only (the skill never runs `git push`/`gh`).
- `git status --porcelain`, `git status --ignored`, `git cherry`, `git merge-base --is-ancestor`, `kill -0`, `lsof`, `git worktree list`, `pm2 jlist`. No `ps`/`pgrep` (blocked in some sessions). No `rm -rf` on a computed or globbed path.
- The cleanup-executor persona brief lives in `skills/delivery-run/references/briefs/cleanup-executor.md` (item 27b); cite by path.

## 6. What you inherit
| Thing | Source | Note |
|---|---|---|
| Worktree | `~/projects/agent-hq-worktrees/delivery-w0`, branch `wt/delivery-w0` | write only your paths |
| Standards | `STANDARDS.md`, `tools/skill-authoring.md`, `tools/check-doc-length.sh` | |
| SUB rules | build-common | no personal-project text, `$HOME` paths |
| Owner rules | D8, D9, D7 | cite by id |

## 7. Known risky values
| Value | Correct | Wrong | Source |
|---|---|---|---|
| Branch merged check | ancestor OR `git cherry`/patch-id equality (squash patch-id too) | ancestor only | card 9 D8; B5 |
| Branch scope | local and remote both gated | remote only gated | A.5.1 |
| Deletion scope | catalog rows only | anything found by glob or pattern | D9 |
| Kill | by pid from a row, `kill -0` before and after | by name or pattern | A.5.1, C7 |
| File-count basis | `.git` included, stated | unstated | A.5.1 |
| Tags, containers, images, workspaces | `kept` and reported | deleted | A.5.1 |
| Second pass | mode `subtask` for `pm`, mode `final` for the run | a third mode | C5.1 |
| `CLEANUP DONE` carrier | line 1 of the record file only | stdout | D1.1 |

## 8. Acceptance criteria
- [ ] SKILL.md has the five required sections; Step 0 validates the four inputs and prints `INPUT-ERROR`.
- [ ] Steps in order: audit, read-only dry run, lead/conductor approves an explicit list, executor re-measures then deletes, spot-check by a different agent, record written atomically; a stop on a count-basis mismatch and on a classifier block (no workaround).
- [ ] Guards stated for worktrees (clean porcelain, `--ignored` shows no uncaptured files, PR open or merged), branches (D8 as in section 7, `REJECTED marker` keeps and flags), processes, ports (registry release plus catalog release), and the never-touch list.
- [ ] Non-catalog finds go to `## residual` and are never deleted (D9).
- [ ] Exit criteria include: `list --live --subtask <st>` shows 0 build resources, the first line of the record matches the `CLEANUP DONE` regex, and the second-pass modes for `pm` and `final`.
- [ ] AM-1 reflected: a `port` row is released only after the listener is stopped, by the `released` claim (same port and source) then `catalog.sh release`; `security-audit/run-<N>/` under `RUN_HOME` is listed as a record that cleanup never deletes, and a catalog row from an audit agent is cleaned like any other.
- [ ] No cost metric, no personal-project text, no restated A.5.1 table.

## 9. Verification commands
```bash
set -eu; W=~/projects/agent-hq-worktrees/delivery-w0; S=$W/skills/delivery-cleanup; F=$S/SKILL.md
test -f "$F"; head -1 "$F" | grep -qx -- '---'
grep -qE '^name: delivery-cleanup$' "$F"; grep -qE '^version: ' "$F"
d=$(grep -E '^description:' "$F"); [ "${#d}" -le 1040 ]; printf '%s' "$d" | grep -q 'Use when'
if grep -q 'disable-model-invocation' "$F"; then echo "FAIL: forbidden match"; exit 1; fi
for h in Trigger Steps 'Red flags' 'Exit criteria' Provenance; do grep -qE "^## $h" "$F"; done
[ "$(wc -c < "$F")" -le 20000 ]; [ "$(wc -l < "$F")" -le 500 ]
for t in RUN_HOME MODE SUBTASK MERGE_RECORD INPUT-ERROR 'CLEANUP DONE' 'du -sk' 'find' 'type f' 'wc -l' '.git' 'git status --porcelain' \
  'git status --ignored' 'git cherry' 'patch-id' 'branch-delete' 'kill -0' 'literal path' 'one `rm`' 'D8' 'D9' 'dry-run' 'approved' \
  'executed' 'residual' 'spot-check' 'catalog.sh' 'list --live' 'port-check.sh' 'A.5.1' 'ancestor' 'released' 'security-audit' \
  'validator' 'stage: stopped' 'WORKTREE_BASE'; do
  grep -rqF -- "$t" "$S" || { echo "missing: $t"; exit 1; }; done
awk '/## dry-run/ && !a{a=NR} /## approved/ && !b{b=NR} /## executed/ && !c{c=NR} /## residual/ && !d{d=NR}
  END{exit !(a&&b&&c&&d&&a<b&&b<c&&c<d)}' "$S/references/cleanup-record.md"
if grep -rnE 'rm +-[a-zA-Z]*r[a-zA-Z]* +[^ ]*[*$]' "$S"; then echo "FAIL: forbidden match"; exit 1; fi
if grep -rniE 'pkill|killall|kill +\$\(' "$S" | grep -vi 'never'; then echo "FAIL: forbidden match"; exit 1; fi
if grep -rniE 'notion|touri|ofw|runfrist|jetblue|/Users/xavier|brain(Alpha|Beta|Gamma)|hermesAuth|cost' "$S"; then echo "FAIL: forbidden match"; exit 1; fi
find "$S" -type l | grep -q . && { echo symlink; exit 1; }
for f in $(find "$S" -name '*.md'); do [ "$(wc -l < "$f")" -le 500 ] || { echo "over 500: $f"; exit 1; }; done
bash "$W/tools/check-doc-length.sh" "$W" >/dev/null
echo SKILL-19-OK
```

## 10. Branch and worktree
Write in `~/projects/agent-hq-worktrees/delivery-w0` (branch `wt/delivery-w0`). No `git add`, commit, branch or push (integrator Worker1 commits). No symlinks, installs or web.

## 11. Decision Gate reminder
Stop and report `STUCK` (or write `.decisions/T19.md`) if: a catalog kind has no row in the A.5.1 table (RESOLVED Q2: the executor applies A.5.1 by citation); a guard would need deletion of a non-catalog path; the 1.1.0 amendment contradicts section 4; a criterion cannot be checked with section 9; you must edit outside section 3.

## Plan-check resolutions (2026-10-26; report `reviews/plan-check-w1-specs.md`)
1. RESOLVED (INTERFACES A.5.1 general rules "never touched: ledger and records"; D6 row `security-audit/run-<N>/` is a RUN record): never deleted, never archived by cleanup; the RUN plane is archived as a whole at CYCLE DONE (A.1).
2. RESOLVED (INTERFACES Script interfaces subcommand list, closed; A.5.1 table; AM-2 row 2): no script subcommand; the executor applies the cleanup column of A.5.1 by citation (no restated copy in this skill) and records each command it ran in `## executed`.
3. RESOLVED (INTERFACES A.5.1 `port` row "... then `catalog.sh release`"; identical to T05 Q6 and T18 Q1): the executor runs the `released` claim, then `catalog.sh release`; `catalog.sh` runs nothing itself.
4. RESOLVED (PLAN-CHECK DEFAULT; D2.1 persona `validator`, verify tier): the spot-check is a `validator` agent, never the executor or the approver; it re-tests every path in `## executed` (`test -e` false, `kill -0` fails, `git worktree list` lacks it, the ref is gone, `lsof` shows no listener) and writes its result into `## residual`.
5. RESOLVED (PLAN-CHECK DEFAULT; AM-2 row 14): an abandoned run is `stage: stopped`; the conductor runs mode `final` with no `MERGE_RECORD`, evidence `state.md` `stage: stopped`. D8 and D9 still bind: unmerged branches and their worktrees are `kept` and flagged, processes, ports, leases, buses and temp dirs are released.
