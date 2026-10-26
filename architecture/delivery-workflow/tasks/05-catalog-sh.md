# Task Spec: T05 `catalog.sh` (W1 item 5, resource catalog script)

> Written 2026-10-26 (W0 item 2b) from design `part-06` §7 row 5-7, card 8 (`part-02` §2.2), `part-04` §5.6, INTERFACES 1.1.0 (AM-1; Script interfaces, A.1, A.3 Break, A.5, A.5.1, A.5.2), `part-05` §6.1 row 3 and the runtime matrix (M14).
> Author: one execute-tier agent, about 2 h with its tests; integrate serially (0.3 h). Not split. Review path: code gate (PR to `agent-hq`, `pr-review` 7 seats, mapped hermetic tests), not Rung 1.

**Done condition (one, machine-checkable):** the command block in section 9 exits 0 and its last stdout line is `SCRIPT-05-OK`.
**Tier:** execute. **Rung:** code gate. **Depends on:** INTERFACES 1.1.0; nothing else to build. Consumers: item 18 (`resource-catalog`), 19 (`delivery-cleanup`), 23 (shepherd `list --live`), 20 (`pre-pr-gate`). `tools/port-check.sh` (PR #9) is called by the caller, not by this script.

## 1. Objective
Write `tools/delivery/catalog.sh`, the only appender of `RUN_HOME/catalog.tsv`, with the call forms, stdout and exit codes of the INTERFACES Script interfaces table, running under `/bin/bash` 3.2 on a BSD userland with no `flock`.

## 2. Context package
- CLI (Script interfaces): env `RUN_HOME` required, absolute, last segment the run-id (unset: exit 2); `register <kind> <handle> <unit|-> <correlation_id> <source> <subtask|run> <owner_agent>`; `start|release|fail <kind> <handle>`; `keep <kind> <handle> <reason>`; `list --live [--subtask <st>]`; `audit`. stdout: the `row_id` for the five writers, the rows for `list`, `MATCH<TAB><row_id>` / `GHOST<TAB><row_id>` / `SQUATTER<TAB>-<TAB><kind>:<handle>` for `audit`. Exit 0 ok; 2 usage or rejected row; 3 lane-lease held; 4 lock timeout.
- Row (A.5): 12 TAB fields `ts, run_id, subtask, row_id, correlation_id, kind, handle, owner_agent, unit, state, keep_reason, source`. `row_id` = `<yyyymmddThhmmssZ>-<owner_agent>-<n>`, `n` = row count + 1 read and appended under `mkdir RUN_HOME/catalog.lock`. Supersede key `kind`+`handle`; latest row is the state. Rejected: a control character, a row over 400 bytes, a path-kind handle whose realpath is not under `RUN_HOME` or the registered `worktree_base` (read from the optional env `WORKTREE_BASE`, RESOLVED Q2).
- Lifecycle: `register` writes `planned`; `start` `live`; `release` `released`; `fail` `failed`; `keep` `kept` with the reason (else column 11 is `-`). `start/release/fail/keep` copy columns 3, 5, 8, 9, 12 from the latest row of the pair (A:230 reading, finding s3-9 L). `lane-lease` `register` is compare-and-append under the lock: exit 3 when the latest row is `planned` or `live`, else it writes `live` directly.
- Lock: `mkdir` lock with an `owner` file `<pid> <ISO UTC>` written by temp file plus `mv`; stale when the pid fails `kill -0`, or `owner` is missing or unparsable and the directory is older than 120 s; break = `mv <lock> <lock>.broken-<pid>-<utc>`, re-read `owner` in the renamed directory, on mismatch rename back only if `<lock>` does not exist and start over, else `mkdir`, then remove the renamed directory; retry every 1 s, exit 4 after 60 s (A.3 Break, R4-J10).
- Audit (A.5): classify against `kill -0`, `lsof -nP -iTCP:<port> -sTCP:LISTEN`, `git worktree list`. Audit rules (RESOLVED Q5, PLAN-CHECK DEFAULT, AM-2 row 3; the first-draft reading is adopted): consider rows whose latest state is `planned` or `live`; alive is `MATCH`, gone is `GHOST`; `worktree` checks `git -C <repo> worktree list --porcelain`, `branch`/`tag` `git show-ref --verify`, `process` `kill -0`, `port` `lsof`, `bus` `kill -0` on the `pid=` of `RUN_HOME/<subtask>/bus.endpoint`, `tmpdir|file|clone` `test -e`, `lane-lease` always `MATCH`, `pm2-app` `pm2 jlist` (skipped when `pm2` or `jq` is absent); `container|image|workspace|db|cron|bgtask` are not checkable from a shell and print no line; `SQUATTER` = a git worktree under `worktree_base` named `<run-id>-*` with no open row, found through the repos named in the catalog's worktree rows.
- Port rows (AM-1, A.5.1, A.5.2): `kind=port` handle is an int 1-65535; the script does not call `port-check.sh`; the caller claims first, then `register port` (`planned`), launches, `start` (`live`); release of the registry row is the caller's step before `catalog.sh release`.
- Runtime matrix (M14, §6.1 row 3): `/bin/bash` 3.2.57, no `flock`, `mapfile`, `timeout`, `gtimeout`; BSD `sed`, `date`, `du`, `stat`; no `sed -i`, `date -d`, `du -b`; tests under `/bin/bash` with `mktemp -d "$TMPDIR/x.XXXXXX"` fixtures and a scratch `HOME` (M18).

## 3. Scope
**In (write only these):** `tools/delivery/catalog.sh`; `tools/delivery/catalog-audit.sh` (sourced by `catalog.sh`; split to stay under the 300-line source default, ADR 0016); `tools/delivery/test_catalog.sh`. Directory: `tools/delivery/`; the file names are disjoint from items 6 and 7.
**Out:** `tools/delivery/scope-check.sh`, `desk-req.sh` and their tests/helpers; `tools/port-check.sh`; `tools/code-gate/test-map.tsv` (the integrator adds the rows `tools/delivery/catalog.sh<TAB>tools/delivery/test_catalog.sh` and `tools/delivery/catalog-audit.sh<TAB>tools/delivery/test_catalog.sh` at integration, rows sorted); INTERFACES; any skill.
**Do NOT create:** a shared `lib-*.sh` or `test-lib.sh` (items 5-7 are file-disjoint, so the lock and the test harness are inline here, RESOLVED Q1); a `cleanup` or `init` subcommand; a column, kind or state outside A.5; a `verify_cmd` column; symlinks; cost metrics.

## 4. Contracts
| Contract | Field / value | Authority |
|---|---|---|
| Script interfaces | call forms, stdout, exit codes 0/2/3/4 above | INTERFACES §Script interfaces |
| Regexes | `unit` `^([ui][0-9]+\|-)$`; subtask `^(st[0-9]+\|pm\|run)$`; owner `agent_id` `^[a-z0-9-]+$`; audit lines `^(MATCH\|GHOST)\t[0-9]{8}T[0-9]{6}Z-[a-z0-9-]+-[0-9]+$` and `^SQUATTER\t-\t[a-z0-9-]+:.+$` | A.1, A.5, Script interfaces |
| Handle grammar | path kinds (`tmpdir file clone bus`) abs path; `branch` `<repo>#<ref>@<base>`; `tag` `<repo>#<ref>@-`; `worktree` `<abs-path>#<repo>@<base>`; `process` pid; `port` int; `pm2-app container image workspace db` `^[A-Za-z0-9._/:-]+$`; `cron bgtask` tool id; `lane-lease` `gate-runner/<n>` or `lane/<name>` | A.5 |
| correlation_id | `<JIRA-KEY>` \| `PR-<n>` \| `run` | A.5 col 5 |
| Timestamps | ISO UTC in `ts`; compact form only in `row_id` | A.1 |
| Lock | `catalog.lock`, A.3 Break, 1 s retry, 60 s, exit 4 | Script interfaces, R4-J10 |

## 5. Inherited module API
None: `catalog.sh` is a leaf script. External commands only: `git`, `kill`, `lsof`, `awk`, `sed`, `cut`, `wc`, `date`, `stat -f %m` (BSD; `stat -c %Y` fallback), `readlink` (no `-f`); `jq` and `pm2` only inside the optional `pm2-app` check.

## 6. What you inherit
| Thing | Source | Note |
|---|---|---|
| Worktree | `~/projects/agent-hq-worktrees/delivery-w0` | write only section 3 paths |
| Gate | `tools/code-gate/` (`scope.conf` puts `*.sh` in scope; `test-map.tsv`) | the test must be mapped by the integrator |
| Style models | `tools/check-doc-length.sh` + `tools/test_check-doc-length.sh` | hermetic test layout (`pass/fail/eq/has`, mktemp root) |
| Measured | the sandbox denies `/var/folders` writes; `git` may print `xcrun_db` cache errors: set `TMPDIR` to the session dir and ignore that noise only if rc is 0 | draft-run observation |

## 7. Known risky values
| Value | Correct | Wrong | Source |
|---|---|---|---|
| Lock | `mkdir` + owner file | `flock`, `lockf` | §6.1 row 3 |
| `awk -v` with a handle | pass through `ENVIRON[...]` | `-v k="$handle"` (it interprets backslashes) | draft-run |
| Empty TSV field in `read` | no empty fields: `keep_reason` is `-` | tab-IFS `read` over empty fields (tab collapses) | A.5 col 11 |
| macOS temp paths | resolve `/var`->`/private/var` with `cd -P` before the under-root test | string-compare the unresolved path | draft-run |
| Concurrency test | set `DL_LOCK_TIMEOUT` (test hook, default 60) at least 30 s for 10 writers, or a sub-second retry hook | 2 s timeout: 5 of 10 writers exit 4 | draft-run |
| Newline in a test argument | `$'a\nb'` | `$(printf '\n')` (command substitution strips it) | draft-run |
| Banned words check | the section 9 grep also reads comments: write "no lock utility", not the banned names | a comment saying "no flock" fails the check | section 9 |
| Row size | row incl. its newline at most 400 bytes (RESOLVED Q3: the newline counts) | unbounded | A.5 |

## 8. Acceptance criteria
- [ ] Every call form, stdout shape and exit code in section 2 behaves as stated; `RUN_HOME` unset, relative, or with a last segment outside `[a-z0-9-]+` exits 2.
- [ ] Rejections exit 2 and append nothing: unknown kind, bad `unit`/`correlation_id`/`subtask`/`owner_agent`/`source`, control character (TAB, newline, DEL) in any argument, handle outside both roots, `..` segment, relative path, symlink escaping `RUN_HOME`, port outside 1-65535, bad `branch`/`tag`/`worktree`/`lane-lease` grammar, row over the cap (a row of exactly 400 bytes passes, 401 fails), `keep` with an empty reason, a transition on a pair with no row.
- [ ] `WORKTREE_BASE` (optional env): a path-kind handle under it is accepted; unset, only `RUN_HOME` is a root; a relative or whitespace value exits 2 (RESOLVED Q2).
- [ ] `start|release|fail|keep` copy columns 3, 5, 8, 9, 12; `release` and `fail` write `-` in column 11.
- [ ] `list --live` prints the latest row of every pair whose state is `live`, in first-seen order, optionally filtered by `--subtask`; no catalog is rc 0 and empty.
- [ ] Lane-lease: first acquire writes `live`; a second exits 3 with no row; re-acquire after `release` works; different handles are independent.
- [ ] 10 concurrent registers yield 10 whole 12-field rows with `n` = 1..10 exactly once; the lock directory is gone afterwards.
- [ ] Lock: a live holder makes a waiter exit 4; a dead-pid lock and a 120 s-old ownerless lock are broken (no `.broken-*` directory left); a fresh ownerless lock is not broken.
- [ ] Audit emits MATCH, GHOST and SQUATTER for fixtures of `process` (alive, dead), `tmpdir`, `worktree` (a real `git worktree add`), `branch`, `bus` (via `bus.endpoint`), `lane-lease`, a stray worktree, and nothing for `container`; a released resource drops out; every line matches the Contracts regexes.
- [ ] No GNU-only flag, no `flock|mapfile|timeout|gtimeout|readlink -f|sed -i`, no associative array; each file at most 300 lines; the test passes under `/bin/bash` with a scratch `HOME`.

## 9. Verification commands
```bash
set -eu; W=~/projects/agent-hq-worktrees/delivery-w0; D=$W/tools/delivery
for f in catalog.sh catalog-audit.sh test_catalog.sh; do test -f "$D/$f"; [ "$(wc -l < "$D/$f")" -le 300 ]; done
test -x "$D/catalog.sh"; test -x "$D/test_catalog.sh"
! grep -nE '(^|[^a-zA-Z_-])(flock|mapfile|readarray|gtimeout)([^a-zA-Z_-]|$)|readlink -f|sed -i|date -d|du -b|declare -A' "$D/catalog.sh" "$D/catalog-audit.sh" || { echo "FAIL: forbidden match"; exit 1; }
head -1 "$D/catalog.sh" | grep -q '^#!/usr/bin/env bash$'
( cd "$W" && env -i PATH=/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/opt/homebrew/bin TMPDIR="${TMPDIR:-/tmp}" HOME=/nonexistent /bin/bash tools/delivery/test_catalog.sh ) | tail -3 | grep -q ', 0 failed'
! grep -rniE 'notion|touri|ofw|runfrist|jetblue|/Users/xavier|brain(Alpha|Beta|Gamma)|hermesAuth' "$D/catalog.sh" "$D/catalog-audit.sh" "$D/test_catalog.sh" || { echo "FAIL: forbidden match"; exit 1; }
find "$D" -type l | grep -q . && { echo symlink; exit 1; }
echo SCRIPT-05-OK
```

## 10. Branch and worktree
Write in `~/projects/agent-hq-worktrees/delivery-w0` (branch `wt/delivery-w0`). No `git add`, commit, branch or push (Worker1 integrates). No symlinks, installs or web. **Integration step (one):** the integrator adds the two `test-map.tsv` rows, runs `bash tools/code-gate/gate-invariants.sh`, then the PR goes through `pr-review`.

## 11. Decision Gate reminder
Write `.decisions/T05.md` and stop on: an INTERFACES call form, kind or column that differs from section 2; a need for a subcommand the table lacks; any need to edit outside section 3; a criterion that cannot be checked with section 9.

## Plan-check resolutions (2026-10-26; report `reviews/plan-check-w1-specs.md`)
1. RESOLVED (PLAN-CHECK DEFAULT; Rule 7, build-common "disjoint files"): no shared library in W1. The `mkdir` lock (A.3 Break) and the test harness are inline in items 5 and 7 (item 6 needs no lock). Extracting a `tools/delivery/lib-lock.sh` is a later refactor owned by the integrator (Worker1) after all three scripts pass the code gate, with its own `pr-review` and mapped tests; no W1 author writes it.
2. RESOLVED (PLAN-CHECK DEFAULT; INTERFACES is silent, AM-2 row 1): optional env `WORKTREE_BASE` (absolute, the profile key `worktree_base`, A.2.2); unset means only `RUN_HOME` is a legal root; a relative or whitespace value exits 2. Callers that register worktrees (`delivery-run`, `feature-change` team mode, `delivery-cleanup`) pass it inline on the call from the profile.
3. RESOLVED (PLAN-CHECK DEFAULT, AM-2 row 2): the 400-byte cap counts the trailing newline (400 passes, 401 fails), keeping the single-write append margin (§6.1 row 4).
4. RESOLVED (INTERFACES Script interfaces table and A.5 subcommand list `register start release keep fail list audit`, closed; AM-2 row 2): `catalog.sh` implements only the verify column of A.5.1 (inside `audit`); the cleanup column is applied by the `delivery-cleanup` executor citing A.5.1 (spec 19 Q2). No cleanup subcommand.
5. RESOLVED (PLAN-CHECK DEFAULT, AM-2 row 3): the section 2 audit reading is adopted as written (open = latest `planned|live`; alive `MATCH`, gone `GHOST`; unverifiable kinds silent; `SQUATTER` only for stray worktrees; ports are never catalog squatters, `port-check.sh --audit` owns port squatters).
6. RESOLVED (INTERFACES A.5.1 `port` row "... then `catalog.sh release`" and the A.5.2 order; the Script interfaces table gives `catalog.sh` no side effect): `catalog.sh` never calls `port-check.sh`; the caller runs the registry claim or release and the catalog call as two commands. Identical answer in spec 18 Q1 and spec 19 Q3.
