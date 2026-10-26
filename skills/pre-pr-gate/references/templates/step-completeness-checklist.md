# Template: step-completeness checklist (design 5.7)

Purpose: the pre-PR completeness record for one sub-task head. `PASS` only if every row has evidence.
Writer: `pre-pr-gate` (the completeness validator, a verify-tier agent, re-runs each row and writes line 1; INTERFACES part A.6, B9, card 10). Reader: the lead (copies the verdict to `substate.md` `prepr`), the desk (reads line 1 and cross-checks `substate.md` `prepr`; both must agree, else `REJECTED marker`, B9), the conductor, the human.
Path: `RUN_HOME/review/<subtask>/checklist-<subtask>.md` (INTERFACES A.6). Write to a temp file, then `mv`.

## 1. Line 1 (INTERFACES D1.1 `PREPR:`)
Exactly one token on line 1, regex `^PREPR: (PASS|STOP( [A-Za-z0-9.,-]+)?)$`:
```
PREPR: PASS
PREPR: STOP C4,C9,C26
```
`STOP` names the failed row ids below, comma-separated, no spaces (PC-8). A row without evidence is failed. Never write both tokens.

## 2. Header (below line 1)
```
subtask: <st id>        head: <40-hex sha>        utc: <YYYY-MM-DDTHH:MM:SSZ>
security_audit: guidance|full      (from state.md, INTERFACES A.2 / D2.1)
profile: <abs path>@<40-hex sha>
```

## 3. Rows C1-C26 (ids = the design 5.7 rows in their written order; C24-C26 added by card 10)
Fill the evidence cell with a path, a command and its exit status, or a sha. `n/a` needs a one-line reason.

| Id | Check | Evidence to record | Result |
|---|---|---|---|
| C1 | Ticket linked and status correct | ticket key, `tickets.tsv` row, Jira status | PASS/FAIL |
| C2 | Child coverage: every child ticket of the sub-task has a unit and a commit | child keys -> unit ids -> shas | |
| C3 | Branch rebased onto the base | base sha, `git merge-base --is-ancestor` exit, head sha (40-hex) | |
| C4 | Each acceptance criterion has a test | AC id -> test path | |
| C5 | Each e2e row exists, its Gherkin checkpoint is recorded and its spec ran | test-plan row -> spec path -> run output path | |
| C6 | `GATES` (profile `gates.command`) exit 0 | command, exit status, runner id | |
| C7 | CI-parity commands pass in CI order (cold run, `--skip-nx-cache` form) | ordered command list with exit statuses | |
| C8 | Standardization pre-check passes | profile pre-check command, exit status | |
| C9 | GATE-PASS: a `GATE-PASS` record exists for every pushed batch on the branch (D21, R2-3) | each `RUN_HOME/<subtask>/gate-runs/<sha>.md` with line 1 matching `^GATE-PASS ([0-9a-f]{40}) (.+)$`; the head's record exists. `HUSKY=0` rule: INTERFACES A.7 | |
| C10 | Redaction gate clean | scan command with `secrets.pattern_file`, 0 hits | |
| C11 | Scope-check clean, or each extra or sensitive path justified by a desk `INSTALLED` row or a grant file `RUN_HOME/gates/grant.<subtask>.<n>.<run-id>.ok` naming it (INTERFACES A.2.1, AM-4 20 Q1) | scope-check output; `INSTALLED` row or grant path per extra path | |
| C12 | Ports claimed (the port row: the review-bus `BUS_PORT` claim, at most one +10 retry; a second refusal is `PREPR: STOP C12`, INTERFACES 1.6.0 AM-6 B-7, D2.2 row 10), then reviewer record path and 0 Blocking / 0 Medium | claim line or refusal line; record path `RUN_HOME/review/<subtask>/record-<head>.md`; line 1 matches the record regex in section 4 with the current head | |
| C13 | Verified-By seat is distinct from the Reviewed-By seat | line 2 `seat-id` vs line 3 `seat-id` of the record | |
| C14 | Fixer shas listed, each with a `fix:` field | `fix-<agent-id>-<n>.md` paths, shas | |
| C15 | `fix-verifier` result CLEAN | `verify-<seat-id>-<n>.md` path, verdict line | |
| C16 | Docs and changelog updated | paths changed | |
| C17 | Migrations have a rollback | migration path -> rollback path, or n/a | |
| C18 | No leftovers (debug code, TODO without ticket, stray files) | grep command, 0 hits | |
| C19 | Adjacent defects ticketed | ticket keys or `none` | |
| C20 | Fix commits pushed | `git rev-parse` of the remote branch equals head | |
| C21 | Catalog has no `planned` rows for this sub-task (design 5.7; leases, ports and bus rows are released by cleanup only, INTERFACES A.5.1, A.5.2, so `live` rows do not fail this row) | `catalog.sh list --live --subtask <st>` output (latest rows that are `planned` or `live`), 0 `planned` | |
| C22 | PR body built from the template | `RUN_HOME/review/<subtask>/pr-body.md` path | |
| C23 | Plan unit list equals the branch unit list | dispatch-plan units vs `git log` units, diff empty | |
| C24 | Version bump: each affected app has its `package.json` `version` bumped per the profile `version_bump_rule` (card 10 step 2b) | affected-app list, old -> new version | |
| C25 | Dist scan clean (card 10 step 2c): profile `e2e.dist_scan_cmd` on a production build of affected apps finds no mock | command, exit status | |
| C26 | Security-audit validator (full mode only, INTERFACES A.5.3): `node skills/security-audit/validate-findings.cjs <output-dir>/findings.json` exits 0, where `<output-dir>` = `RUN_HOME/<subtask>/security-audit/run-<N>`. Under `guidance` write `n/a (guidance)`; a non-zero exit is `PREPR: STOP C26` | `validate-findings.cjs` command line, exit status, run dir | |

## 4. Review record (INTERFACES A.6, read-only here)
`pr-review` writes `RUN_HOME/review/<subtask>/record-<head>.md`; this checklist only reads it. Three lines:
```
CODE-GATE-REVIEW: PASS head=<sha> blocking=0 medium=0
Reviewed-By: <seat-id> <session> <TASK id>
Verified-By: <seat-id> head=<sha>
```
Regexes (C12, C13 re-derive them):
- line 1 `^CODE-GATE-REVIEW: PASS head=([0-9a-f]{40}) blocking=0 medium=0$`
- line 2 `^Reviewed-By: ([a-z0-9-]+) ([a-z0-9-]+) ([A-Za-z0-9_-]+)$`
- line 3 `^Verified-By: ([a-z0-9-]+) head=([0-9a-f]{40})$`; its `seat-id` differs from line 2's; both `head` values equal the checklist head.

## 5. Rules
- Result `PASS` needs evidence in the cell; no evidence = FAIL, whatever the author believes.
- Row C9 is the `GATE-PASS` row: a failed gate run writes no file (INTERFACES A.7), so a missing file is the evidence of failure.
- Review loops stop after round 3 and the owner decides (D7): the lead writes `substate.md` `stop_reason: d7-round3` (INTERFACES A.3). A failing row outside the review loop is `PREPR: STOP <id>` (lead: `stop-the-line:S2`); a second review-bus port refusal is `PREPR: STOP C12` (lead: `port-refused`) (INTERFACES D2.2 row 10, AM-4 20). Line 1 stays `PREPR: PASS` or `PREPR: STOP <rows>`; there is no third token (INTERFACES D1.1).
- The verdict is derived from the rows by the validator; an agent never writes `PASS` over a FAIL row (M30).
- Keep this file near 500 lines or less.
