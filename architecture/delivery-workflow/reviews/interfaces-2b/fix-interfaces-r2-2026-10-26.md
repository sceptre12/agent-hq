# Fix record: INTERFACES 2b, round 2 (fixer, 2026-10-26)

Input: `reviews/interfaces-2b/panel7-interfaces-r2-2026-10-26.md` (0 B / 37 M / 34 L). Paths below are under `architecture/delivery-workflow/`; A/B/C/D = `interfaces/part-a-state.md` / `part-b-desk.md` / `part-c-waves-control.md` / `part-d-enums-topics.md`; I = `INTERFACES.md`. Every new value is `DEFAULT (integrator)` with a Kind DEF row in I:117-135 (tagged "r2 G<n>"). ADRs, design and the freeze-status line untouched; FRZ-a..i unchanged.

G1 FIXED D:40 H1 verdict now `ok|changes|reject` (the B8 GATE token), files unchanged.
G2 FIXED A:96, B:152 notes written for `changes` and `reject`; a repeat H1 gate renames earlier H1 files to `<name>.<utc>` first.
G3 FIXED A:264, A:263 (`-` absence token), D:101 cursor file `RUN_HOME/ticket-events.cursor` (`^[0-9]+$`); unit-to-ticket via the dispatch-plan `ticket` column.
G4 FIXED B:22, C:118 lead sends no DESK before `register.consumed` (renamed only after `REGISTERED ok`); no-`.out` after resend or a `sender` reject -> `.req.noreply`, terminal, escalated; resume skips it.
G5 FIXED A:17, A.1 run files row, A.6 rows, D:131 slug regex `^[a-z0-9][a-z0-9-]*$`, `index` reserved; `review-tailor-<slug>.md` and `drafts/index.md` listed in A.6 and D6.
G6 FIXED A:87, A.3 rows `pm_sha` = last sub-task merge sha; `postmerge_record`, `release_record` in pm substate.
G7 FIXED A:213 lane-lease register writes `live` directly; acquire requires latest not `planned|live`.
G8 FIXED A:146 break = atomic `mv` to `.broken-<pid>-<utc>` then `mkdir`; loser restarts; all four locks.
G9 FIXED A:164,172, C:137 reserved seats get no row; unit `^(u[0-9]+|-)$`; C5.3 step 3b reconciles `dispatch/*.jsonl` vs `slots/`.
G10 FIXED (D21 wording) A:270 HUSKY=0 only on PR creation and first push (owner-decisions.md:28), gate once per push/batch (R2-3, :37). Conflict (hooks on every other commit run per commit, against R2-3's intent) left as open owner note N10, I:29; no new licence decided.
G11 FIXED A:222, B:100, B6 `merged_check` local and remote deletes both gated; squash patch-id check; value `squash`.
G12 FIXED A:13,18 provisional run-id `run-<n>-<yyyymmdd>` when no epic at stage 1 (matches FRZ-i regex), never renamed; `plans/<run-id>/`; `epic` from the jira-create read-back.
G13 FIXED I:35 audit lines `MATCH|GHOST<TAB><row_id>`, `SQUATTER<TAB>-<TAB><kind>:<handle>`, with regexes.
G14 FIXED A:121 seed keys `subtask_id session_id reserved frontier phase`; verbatim copy, never edited.
G15 FIXED A:132 `^stop-the-line:[A-Z]+[0-9]+[a-z]?$`, row id of the design §1 stop-the-line list.
G16 FIXED A:262 regexes for record lines 1-3.
G17 FIXED A:274 GATE-PASS written only on pass; line 1 regex, `utc=`/`runner=` on lines 2-3 before the tail.
G18 FIXED C:66 verdict -> reason table; exactly four keys (additionalProperties false).
G19 FIXED D:8 reason `format` and the INPUT-ERROR line regex.
G20 FIXED B:74 pr-create checks `record_path` root and name (`record-<expect_head>.md`, `repo`); content re-derived at pr-merge. FRZ-g not changed (adding a marker would reopen a freeze item).
G21 FIXED C:97 relay posts as the recorded `agent_id` (`from_agent`), must be in `dispatch/*.jsonl`; no-post rule (gate failure, fix-loop exception, ADR 0054:159-162).
G22 FIXED C:22, A:213 lead leases every `lane/<name>` of the invocation before calling wave-execution; releases after that lane's last accepted record.
G23 FIXED B:16, B:149, D:83 `REBIND <run-id> <sender-id>` typed by the human re-binds the `run` claimer.
G24 FIXED C:110,118, A:41, I:115 `.sending-<id>` rename before send persists the id; resume re-sends the same id.
G25 FIXED C:135, C:173 conductor tick `kill -0` on each lead's lock owner; lead tick bus check, `pm2 restart`, two failures -> stop.
G26 FIXED A:250 `fix-<agent-id>-<n>.md`; `<n>` = review round.
G27 FIXED B:18 requester -> host sender and `<subtask>` token table.
G28 FIXED C:116 inbox type `merged`, line `MERGED <subtask> <merge_sha>`; triggers `delivery-cleanup` mode `subtask`.
G29 FIXED A:140, D:21 one Integrator C2 record per merged unit.
G30 FIXED I:35 `catalog.sh` requires env `RUN_HOME` (exit 2 if unset).
G31 FIXED A:87, D:74 `delivery-run` `mode` `build|plan-pr|post-merge`; st0/pm have no seed, waves or bus.
G32 FIXED D:73,80,81 payload `bodies/test-report-<step_id>.json` written by release-track (pm lead) and requested via CONDUCTOR-REQUEST; `pm/new-units.md` -> dispatch-plan `new_units`.
G33 FIXED B:108 result types, required on DONE, arrays never null, `read_back`/`parent` shapes.
G34 FIXED C:31 `## 3` `- <glob>` lines; git `:(glob)` dialect; diff basis.
G35 FIXED C:36 `done_condition` = `{token, command}`.
PR6-1 FIXED A:41, C:110, I:115 rename set aligned: `.sending-<id>`, `.sent-<id>`, `.refused`.
PR6-2 FIXED B:37, A:41, A:213 DEFAULT (integrator) tags added.
L s1-9/s3-24 FIXED A:133 `lock_breaks` in A.3. Other 32 L: NOT-DONE (time budget; all class FIX, guessable per synth).

## Checks
- `bash tools/check-doc-length.sh .` (worktree): 0 blocking files over 500 lines. Lines: I 202, A 283, B 162, C 175, D 156.
- Every replacement was an exact single-match substitution (scripted; 0 misses). grep: no `ACCEPT`/`fix-<n>`/"per work_item, before dispatch" leftovers.
- Not run: an independent fix-verifier pass (verifier's job).
