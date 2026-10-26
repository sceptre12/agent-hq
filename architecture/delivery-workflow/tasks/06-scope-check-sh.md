# Task Spec: T06 `scope-check.sh` (W1 item 6, scope-creep checker)

> Written 2026-10-26 (W0 item 2b) from design `part-06` §7 row 5-7, `part-03` §4 rule 2 and 8d, card 7 (`part-02` §2.2), INTERFACES 1.5.0 (Script interfaces; C1.1 scope globs row; C7 `CREEP` row; R4-J21), `part-05` §6.1 row 3 / runtime matrix.
> Author: one execute-tier agent, about 1 h with its tests; integrate serially (0.3 h). Not split. Review path: code gate (PR, `pr-review` 7 seats, mapped hermetic tests).

**Done condition (one, machine-checkable):** the command block in section 9 exits 0 and its last stdout line is `SCRIPT-06-OK`.
**Tier:** execute. **Rung:** code gate. **Depends on:** INTERFACES 1.5.0 only. Consumers: item 23 (`delivery-shepherd`, `CREEP` flag), item 20 (`pre-pr-gate`, preventive check).

## 1. Objective
Write `tools/delivery/scope-check.sh <tasks-file> <worktree> <base-sha>`: print `CREEP <path>` for every path changed in the worktree since `<base-sha>` that matches none of the unit's scope globs, under `/bin/bash` 3.2 and BSD userland.

## 2. Context package
- CLI (Script interfaces): `<tasks-file>` = `<primary_repo>/.tasks/<unit>-<slug>.md`; `<base-sha>` = `git -C <worktree> merge-base HEAD <sub-task branch>`, computed by the caller and never stored (R4-J21). stdout: one line per changed path outside the globs, `CREEP <path>`. Exit 0 clean; 1 creep found; 2 usage.
- Globs (C1.1 scope-globs row): they live in the tasks file section 3 only: the heading `## 3`, one glob per line as `- <glob>`, until the next `## `. Matching is git pathspec `:(glob)` semantics (`*` within one segment, `**` across segments) against `git diff --name-only <base-sha>...HEAD` in the worktree.
- Design carried from a first draft (consistent with the above): read the globs; get changed paths with `git -C <wt> diff --name-only -z --no-renames <base>...HEAD`; get the in-scope subset with the same command plus `-- ':(glob)g1' ':(glob)g2' ...`; the difference is the creep. Compare in bash with a delimiter that cannot occur in a path (`$'\x01'`) so odd names work. Print control characters in a path as `?`. `--no-renames` so both sides of a rename are checked.
- Validation (exit 2, message on stderr, nothing on stdout): tasks file unreadable; no `## 3` heading; zero globs; a glob with a control character or starting with `:` (pathspec magic) ; `<worktree>` not a git work tree; `<base-sha>` not `^[0-9a-f]{40}$` or not a commit; the git diff fails.
- Runtime matrix: `/bin/bash` 3.2.57, BSD userland, no GNU-only flags, no `mapfile`, no associative arrays (`read -d ''` loops and indexed arrays are fine); hermetic tests with `mktemp -d "$TMPDIR/x.XXXXXX"` and a scratch `HOME`; tests build their own git repos (`git init`, `-c user.email -c user.name`, `commit --allow-empty` forms).

## 3. Scope
**In (write only these):** `tools/delivery/scope-check.sh`; `tools/delivery/test_scope-check.sh`. Directory `tools/delivery/`; file names disjoint from items 5 and 7.
**Out:** `catalog.sh`, `desk-req.sh` and their files; `tools/code-gate/test-map.tsv` (integrator adds `tools/delivery/scope-check.sh<TAB>tools/delivery/test_scope-check.sh`); INTERFACES; any skill; `.tasks/` templates.
**Do NOT create:** a shared lib or harness file (RESOLVED in T05 Q1); a second glob source (no globs from the dispatch plan; the tasks file only); a sensitive-path deny list or an auto-fix mode (RESOLVED Q2); symlinks.

## 4. Contracts
| Contract | Field / value | Authority |
|---|---|---|
| Call | `scope-check.sh <tasks-file> <worktree> <base-sha>` | Script interfaces |
| stdout | `CREEP <path>`, one per path, nothing else | Script interfaces; C7 `CREEP` row |
| Exit codes | 0 clean, 1 creep, 2 usage | Script interfaces |
| Glob section | `## 3` until next `## `, lines `- <glob>` | C1.1 scope globs |
| Semantics | `:(glob)`; range `<base-sha>...HEAD` | C1.1 |
| sha | full 40-hex | A.1 token shapes |

## 5. Inherited module API
None. External: `git` (`diff`, `rev-parse`, `cat-file`), `sed`, `grep`; no `ps`/`pgrep`.

## 6. What you inherit
| Thing | Source | Note |
|---|---|---|
| Worktree | `~/projects/agent-hq-worktrees/delivery-w0` | write only section 3 paths |
| Gate | `tools/code-gate/` | test mapped by the integrator |
| Sandbox note | `git` may print `xcrun_db` cache errors when `/var/folders` is unwritable; set `TMPDIR` to a writable dir | draft-run observation |

## 7. Known risky values
| Value | Correct | Wrong | Source |
|---|---|---|---|
| Glob semantics | `*` stays in one segment, `**` crosses | shell `case` matching (`*` crosses `/`) | C1.1 |
| Range | `base...HEAD` (merge-base form) | `base..HEAD` is not what C1.1 says | C1.1 |
| `base-sha` source | caller passes it; the script stores nothing | reading a stored value | R4-J21 |
| Output name | `CREEP <path>` | `CREEP: <path>`, `creep` | Script interfaces |
| Renames | both old and new path checked | rename detection hiding the old path | draft decision |
| Banned words check | the section 9 grep also reads comments: write "no lock utility" style plain text and avoid the banned names | comment naming them | section 9 |

## 8. Acceptance criteria
- [ ] Clean change set (all paths match a glob): no stdout, rc 0. A path outside every glob: `CREEP <path>`, rc 1; several creeps print one line each, sorted as git emits them.
- [ ] `*` does not cross `/` while `**` does (fixture: `src/*.ts` vs `src/a/b.ts`; `src/**` covers both).
- [ ] Deleted, added, modified and renamed files are all checked; a path with a space is printed whole; a path with a control character prints it as `?`.
- [ ] Globs after the next `## ` heading, text before `## 3`, and lines not starting `- ` are ignored.
- [ ] Each exit-2 condition in section 2 gives rc 2, a stderr message and empty stdout; wrong arg count is rc 2.
- [ ] `<base-sha>...HEAD` is used: a change on the base branch after the merge base is not reported.
- [ ] No GNU-only flag or banned builtin; file at most 300 lines; the test passes under `/bin/bash` with a scratch `HOME`.

## 9. Verification commands
```bash
set -eu; W=~/projects/agent-hq-worktrees/delivery-w0; D=$W/tools/delivery
for f in scope-check.sh test_scope-check.sh; do test -f "$D/$f"; [ "$(wc -l < "$D/$f")" -le 300 ]; done
test -x "$D/scope-check.sh"; test -x "$D/test_scope-check.sh"
! grep -nE '(^|[^a-zA-Z_-])(flock|mapfile|readarray|gtimeout)([^a-zA-Z_-]|$)|readlink -f|sed -i|date -d|du -b|declare -A' "$D/scope-check.sh" || { echo "FAIL: forbidden match"; exit 1; }
head -1 "$D/scope-check.sh" | grep -q '^#!/usr/bin/env bash$'
( cd "$W" && env -i PATH=/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/opt/homebrew/bin TMPDIR="${TMPDIR:-/tmp}" HOME=/nonexistent /bin/bash tools/delivery/test_scope-check.sh ) | tail -3 | grep -q ', 0 failed'
! grep -rniE 'notion|touri|ofw|runfrist|jetblue|/Users/[a-z]+|brain(Alpha|Beta|Gamma)|hermesAuth' "$D/scope-check.sh" "$D/test_scope-check.sh" || { echo "FAIL: forbidden match"; exit 1; }
find "$D" -type l | grep -q . && { echo symlink; exit 1; }
echo SCRIPT-06-OK
```

## 10. Branch and worktree
Write in `~/projects/agent-hq-worktrees/delivery-w0` (branch `wt/delivery-w0`). No `git add`, commit, branch or push. No symlinks, installs or web. **Integration step (one):** the integrator adds the `test-map.tsv` row, runs `bash tools/code-gate/gate-invariants.sh`, then the PR goes through `pr-review`.

## 11. Decision Gate reminder
Write `.decisions/T06.md` and stop on: a call form or exit code differing from section 2; a need for a glob source other than the tasks file; any edit outside section 3; a criterion not checkable with section 9.

## Plan-check resolutions (2026-10-26; report `reviews/plan-check-w1-specs.md`)
1. RESOLVED (INTERFACES Script interfaces, exit 2 "usage"; PLAN-CHECK DEFAULT): a tasks file with no `## 3` heading or zero globs exits 2 with a stderr message (section 2 list).
2. RESOLVED (design card 10 step 5 puts the sensitive-path deny list in `pre-pr-gate`; the Script interfaces table has no flag or output for it): this script implements the table only. The deny list is read by `pre-pr-gate` step 5 from the profile (key proposed as `sensitive_paths[]`, AM-2 row 5).
3. RESOLVED (Script interfaces: one output form, `CREEP <path>`): every out-of-glob path is `CREEP`, whatever part of the tasks file mentions it.
