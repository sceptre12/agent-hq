# Task Spec: T07 `desk-req.sh` (W1 item 7, desk request-file writer and validator)

> Written 2026-10-26 (W0 item 2b) from design `part-06` §7 row 5-7, card 15 (`part-02` §2.2), `part-05` §6.3, INTERFACES 1.1.0 (Script interfaces; part B1-B4, B2.1; A.1 path rule and token shapes; A.3 Break), ADR 0055 (accepted 2026-10-26), `part-05` §6.1 row 3.
> Author: one execute-tier agent, about 2 h with its tests; integrate serially (0.3 h). Not split. Review path: code gate (PR, `pr-review` 7 seats, mapped hermetic tests).

**Done condition (one, machine-checkable):** the command block in section 9 exits 0 and its last stdout line is `SCRIPT-07-OK`.
**Tier:** execute. **Rung:** code gate. **Depends on:** INTERFACES 1.1.0; ADR 0055 accepted (done). Consumer: item 26 (`delivery-desk` reads the `.req` this writes) and every requester skill. The desk itself is not built or called here.

## 1. Objective
Write `tools/delivery/desk-req.sh <run-id> <subtask|run> <verb> <fields-json-file>`: validate the fields against the closed B4 schema, allocate `<n>`, write `RUN_HOME/desk/<id>.req` (0600) and print the one `DESK` line, under `/bin/bash` 3.2 and BSD userland with no `flock`.

## 2. Context package
- CLI (Script interfaces): stdout is the `DESK` line to send or to write to `outbox/<id>.desk`; exit 0 ok; 2 usage; 4 lock timeout (`desk/.lock`, 1 s retry, 60 s, A.3 Break).
- Paths (A.1): `RUN_HOME` = `$DELIVERY_ROOT/<run-id>`; env `DELIVERY_ROOT` unset or not `^/[^[:space:]]+$` is exit 2 with exactly `INPUT-ERROR DELIVERY_ROOT unset` (unset) or `INPUT-ERROR DELIVERY_ROOT format` (not matching) on stderr (RESOLVED Q2, part D1).
- Id (B2): `<id>` = `<run-id>-<subtask>-<utc>-<n>`, regex `^([a-z0-9-]+)-(st[0-9]+|pm|run)-([0-9]{8}T[0-9]{6}Z)-([0-9]+)$`; `<n>` is the per-run counter allocated under `mkdir RUN_HOME/desk/.lock`.
- Request file (B3 sender step): one JSON object `{"id","verb","subtask","fields":{...}}`, written under `umask 077`, mode 0600, by temp file in `desk/` then `mv`; then sha256 of the file as written; then the line `DESK <id> | <verb> | <abs RUN_HOME/desk/<id>.req> | sha256=<64 lowercase hex>` (single spaces; regex in B2).
- Closed validation (B4; the desk re-validates the copy, this script stops a bad request before it is sent): verb in the 20 B4 verbs (`push pr-create pr-attach pr-comment pr-comments-read pr-approval-state pr-merge branch-delete ci-status ci-logs ci-rerun ci-status-main fetch tag-push publish test-report-push jira-get jira-create jira-update jira-transition`; the B4 table is the authority); fields object has exactly the verb's key set, every key required except `parent` on `jira-create`, which is present exactly when `fields.issuetype` is not `Epic`; types per B4 "Field types" (abs path, branch `^[A-Z][A-Z0-9]+-[0-9]+(-[a-z0-9-]+)?$`, ref `^[A-Za-z0-9._/-]+$`, ints, 40-hex shas, `method` in `squash|merge|rebase`, arrays not strings, `labels[]` regex, `tool` `zephyr`, `dry_run` bool, `to` enum, Jira `fields` keys from the allowlist `summary description issuetype parent labels priority components` with string or string-array values, `jira-get fields[]` from the readable set); no raw flag, no `force`, no unknown key at any level; envelope `subtask` equals the CLI argument; conductor-only verbs (`pr-merge publish tag-push test-report-push`) require subtask `run`; `pr-merge` `fields.subtask` is `^(st[0-9]+|pm)$`; path roots per B4 per-field rules (`body_path`, `payload_path` realpath under `RUN_HOME/review/` or `RUN_HOME/bodies/` and `payload_path` of `test-report-push` under `bodies/`; `record_path` under `RUN_HOME/review/<subtask>/` and named `record-<expect_head>.md`; `pr-attach` `paths[]` under `RUN_HOME/<fields subtask or envelope subtask>/lanes/`). `repo` is checked as an absolute path only: the registered-clone test is the desk's (B3 step 6).
- Failure output: exit 2, one stderr line `desk-req: schema: <field or rule>`, no `.req` written, no counter consumed.
- Design carried from a first draft: JSON parsing with `/usr/bin/jq` (RESOLVED Q1; exit 2 with `desk-req: jq missing` if absent); `n` = 1 + the highest `n` among existing `RUN_HOME/desk/<run-id>-<subtask>-*` names for any subtask of the run (stateless, found under the lock; RESOLVED Q4); `jq -S -c` for a stable one-line file; a `.req` file name that already exists is never overwritten (exit 2).
- Runtime matrix (M14, §6.1 row 3): `/bin/bash` 3.2.57, BSD `date`/`stat`/`sed`, no `flock`, `mapfile`, `timeout`; hash with `shasum -a 256` (present) not `sha256sum`; hermetic tests with `mktemp -d "$TMPDIR/x.XXXXXX"` and a scratch `HOME`.

## 3. Scope
**In (write only these):** `tools/delivery/desk-req.sh`; `tools/delivery/desk-req-schema.sh` (sourced; the per-verb table and checks, split to stay under 300 lines, ADR 0016); `tools/delivery/test_desk-req.sh`. Directory `tools/delivery/`; names disjoint from items 5 and 6.
**Out:** the desk, any `.out`/`DONE`/`REJECTED` handling, `REGISTER-SENDER`, sending the line (the caller sends it or writes `outbox/<id>.desk`), redaction scanning (B7, the desk's), `catalog.sh`, `scope-check.sh`, INTERFACES, ADRs, `delivery-desk` and `references/schemas.json` (item 26, which may duplicate the schema; both are checked against B4, RESOLVED Q3); `tools/code-gate/test-map.tsv` (integrator adds rows for `desk-req.sh` and `desk-req-schema.sh` -> `test_desk-req.sh`).
**Do NOT create:** a shared lib or harness (RESOLVED in T05 Q1); a stored counter file other than what section 2 says; a sender field in the `.req`; a `--force` or raw-flag pass-through; symlinks.

## 4. Contracts
| Contract | Field / value | Authority |
|---|---|---|
| Call and exit codes | `desk-req.sh <run-id> <subtask\|run> <verb> <fields-json-file>`; 0 / 2 / 4 | Script interfaces |
| Id | regex above; `<utc>` compact `yyyymmddThhmmssZ` | B2, A.1 timestamps |
| `DESK` line | `^DESK +(<ID>) \| ([a-z-]+) \| (/[^ ]+) \| sha256=([0-9a-f]{64})$`, path equals `RUN_HOME/desk/<id>.req` | B2 line regexes |
| `.req` | `{"id","verb","subtask","fields"}`, 0600, `umask 077`, atomic | B3 sender |
| Verbs and fields | the B4 table (closed) | B4 |
| Conductor-only | `^(pr-merge\|publish\|tag-push\|test-report-push)$` with subtask `run` | B1 |
| Lock | `desk/.lock`, A.3 Break, 1 s retry, 60 s, exit 4 | Script interfaces, R4-J10 |
| run-id | `^[a-z0-9-]+$`; subtask `^(st[0-9]+\|pm\|run)$` | A.1 |

## 5. Inherited module API
None. External: `jq`, `shasum`, `date`, `stat`, `mv`, `mkdir`, `kill`.

## 6. What you inherit
| Thing | Source | Note |
|---|---|---|
| Worktree | `~/projects/agent-hq-worktrees/delivery-w0` | write only section 3 paths |
| Example requests | B4 "Notes" column and the Field types paragraph | derive one valid fixture per verb |
| Sandbox note | `git`/tools may print cache errors when `/var/folders` is unwritable; use `TMPDIR` | draft-run observation |

## 7. Known risky values
| Value | Correct | Wrong | Source |
|---|---|---|---|
| Envelope subtask for a conductor `pr-merge` | `run`, with `fields.subtask` `st<N>` | `st<N>` in the envelope | B4 |
| `jira-create` `parent` | present iff `issuetype` is not `Epic` | always, or never | B4 |
| `branch-delete` sender | the `.req` is written here; a host session sends the line | n/a | B4 |
| Hash input | the file exactly as written | a re-serialisation | B2 |
| Concurrent senders | `<n>` unique per run under the lock | read-then-write outside it | B2 |
| Lock test | timeout hooks for tests only (`DL_LOCK_TIMEOUT`, `DL_LOCK_INTERVAL`), 10 writers need a long enough timeout | 2 s with 10 writers (half exit 4 in the catalog draft) | draft-run |
| Banned words check | the section 9 grep also reads comments; write plain "no lock utility" | naming the banned tools in a comment | section 9 |

## 8. Acceptance criteria
- [ ] For each of the B4 verbs a valid fixture yields rc 0, a `.req` of mode 0600 whose JSON has exactly the four keys, and a `DESK` line matching the B2 regex whose `sha256=` equals `shasum -a 256` of the file and whose path equals the file.
- [ ] Id parsing: the printed id matches the B2 regex; `n` is 1 on an empty run, increments, and 10 concurrent runs give 10 distinct `n` values with no `.req` lost; the lock directory is gone afterwards; ids never repeat after a failed validation (no consumption).
- [ ] Rejections (rc 2, no file, stderr `desk-req: schema: ...`): unknown verb, unknown/missing/mistyped field, string where an array is required, `force` or any raw flag key, extra key at top level, bad branch/ref/sha/method, `jira-create` parent rule violated both ways, Jira `fields` key outside the allowlist, conductor-only verb with a non-`run` subtask, a path outside its root or relative, a `record_path` not named `record-<expect_head>.md`, run-id or subtask out of regex, unreadable or non-JSON fields file, `DELIVERY_ROOT` unset, missing `RUN_HOME`.
- [ ] Lock: a live holder gives rc 4; a dead-pid lock and a 120 s ownerless lock are broken; a fresh ownerless lock is not.
- [ ] The `.req` is never partially visible (temp file plus `mv`) and an existing name is not overwritten.
- [ ] No banned builtin or GNU-only flag; each file at most 300 lines; the test passes under `/bin/bash` with a scratch `HOME`.

## 9. Verification commands
```bash
set -eu; W=~/projects/agent-hq-worktrees/delivery-w0; D=$W/tools/delivery
for f in desk-req.sh desk-req-schema.sh test_desk-req.sh; do test -f "$D/$f"; [ "$(wc -l < "$D/$f")" -le 300 ]; done
test -x "$D/desk-req.sh"; test -x "$D/test_desk-req.sh"
! grep -nE '(^|[^a-zA-Z_-])(flock|mapfile|readarray|gtimeout|sha256sum)([^a-zA-Z_-]|$)|readlink -f|sed -i|date -d|du -b|declare -A' "$D/desk-req.sh" "$D/desk-req-schema.sh" || { echo "FAIL: forbidden match"; exit 1; }
head -1 "$D/desk-req.sh" | grep -q '^#!/usr/bin/env bash$'
( cd "$W" && env -i PATH=/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/opt/homebrew/bin TMPDIR="${TMPDIR:-/tmp}" HOME=/nonexistent /bin/bash tools/delivery/test_desk-req.sh ) | tail -3 | grep -q ', 0 failed'
# every B4 verb is named in the schema file
for v in push pr-create pr-attach pr-comment pr-comments-read pr-approval-state pr-merge branch-delete ci-status ci-logs ci-rerun ci-status-main fetch tag-push publish test-report-push jira-get jira-create jira-update jira-transition; do grep -qF -- "$v" "$D/desk-req-schema.sh" || { echo "missing verb $v"; exit 1; }; done
! grep -rniE 'notion|touri|ofw|runfrist|jetblue|/Users/xavier|brain(Alpha|Beta|Gamma)|hermesAuth' "$D/desk-req.sh" "$D/desk-req-schema.sh" "$D/test_desk-req.sh" || { echo "FAIL: forbidden match"; exit 1; }
find "$D" -type l | grep -q . && { echo symlink; exit 1; }
echo SCRIPT-07-OK
```

## 10. Branch and worktree
Write in `~/projects/agent-hq-worktrees/delivery-w0` (branch `wt/delivery-w0`). No `git add`, commit, branch or push. No symlinks, installs or web. **Integration step (one):** the integrator adds the `test-map.tsv` rows, runs `bash tools/code-gate/gate-invariants.sh`, then the PR goes through `pr-review`.

## 11. Decision Gate reminder
Write `.decisions/T07.md` and stop on: B4 and a requester skill's spec disagreeing on a field; an ADR 0055 schema rule absent from B4; a need to read the desk registry or sign a sender; any edit outside section 3; a criterion not checkable with section 9.

## Plan-check resolutions (2026-10-26; report `reviews/plan-check-w1-specs.md`)
1. RESOLVED (PLAN-CHECK DEFAULT; measured by the plan-checker 2026-10-26: `/usr/bin/jq` present on the build machine, macOS 26.6.2): call `/usr/bin/jq` by absolute path (no install, no fallback parser); absent is exit 2 `desk-req: jq missing`. The work machine re-checks it at P0 (part-06 P0 row, positive-control run of every gate script).
2. RESOLVED (INTERFACES Script interfaces call `desk-req.sh <run-id> ...` and A.1 `RUN_HOME = $DELIVERY_ROOT/<run-id>`): `RUN_HOME` is derived, never read from the environment (an exported `RUN_HOME` is ignored). `DELIVERY_ROOT` failures print the D1 lines exactly.
3. RESOLVED (INTERFACES B6: part B4 is the authority, `schemas.json` its machine copy): no cross-file test. This script's tests check every verb against B4, item 26's check 3 checks `schemas.json` against B4, so both agree through one authority; item 33's consistency pass diffs the two verb and field sets once.
4. RESOLVED (PLAN-CHECK DEFAULT; B2 says only "allocated under `desk/.lock`"): `<n>` = 1 + the highest `n` among `RUN_HOME/desk/<run-id>-*` names with any suffix (`.req`, `.req.noreply`, `.out`, `.inflight`), read under the lock; no counter file.
5. RESOLVED (INTERFACES B1 `claude -p` row and C5.1: the lead writes `outbox/<id>.desk`): stdout only; the caller writes the outbox file.
