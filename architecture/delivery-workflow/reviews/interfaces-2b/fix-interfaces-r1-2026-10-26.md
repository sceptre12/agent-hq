# Fix record: INTERFACES 2b, round 1 (2026-10-26)

Fixer: review-7-panel fixer role (Opus), round 1. Input: `reviews/interfaces-2b/panel7-interfaces-r1-2026-10-26.md` (2 B, 38 M, 6 L). Paths: A/B/C/D = `interfaces/part-*.md`, I = `INTERFACES.md`. Line numbers are after the fix. The freeze-status line (I:3), the ADRs, the design and "Owner questions: None open" were not changed; Q1-Q3 were not reopened.

F1 FIXED A:163,171,174; C:19-22 reservation slot row per work_item (stem = work_item id, 3 units) converted to the controller-minted `agent_id` via a new dispatch record `RUN_HOME/<subtask>/dispatch/<invocation>.jsonl` (JSON shape given); `max_concurrent = 30 - live_rows - 3 x reservation_rows - sum(reserved)`; the lead leases lanes per work_item before dispatch. ADR 0054 Q3 is Owner note N1 (I:37), DEF row I:109.
F2 FIXED B:17,40 conductor-only verbs (`pr-merge`, epic `jira-create`, `publish`, `tag-push`, `test-report-push`) valid only with `<subtask>` = `run` and sender = `conductor_id`, else `sender`; the conductor never relays a conductor-only verb. Stated as an addition to Q1 (`owner-decisions.md:58`).
F3 FIXED A:134-144 (substate `phase`, `prepr`, `head`, `pr`, `review_record`, `integrated`, `ci`, `postmerge` + transport sentence); A:84 source of every `subtasks[].state` transition; C:129 lead-to-conductor row.
F4 FIXED B:133-143 `GATE <run-id> ...` and `ANSWER <run-id> ...` with anchored regexes, gate x verdict matrix, `by`/`ref`/`notes` sources (also A:91-99); D2.2 row 15 (D:83) lists both lines as inputs and the gate/inbox files as outputs.
F5 FIXED B:61-84 B4 gains a Requester (phase) / result-reader column for every verb (pr-create/pr-attach/pr-comment by `delivery-run` after PREPR: PASS, then pr-comment with the URLs; pr-comments-read and ci-* by `ci-fix-loop`; push by the lead's gate step); D2.2 rows 6, 11, 12, 14 name the verbs; `pr-body.md` names lanes files only (B:88, A.6).
F6 FIXED B:68,127 B4 reworded to "unscanned images (labelled) and scanned traces"; B7 image rule marked DEFAULT, owner to decide (ADR 0055 OP 9); Owner note N3.
F7 FIXED A:15,59-61,105-108 `<epic>` defined (original case, regex); `epic`, `plans_dir`, `primary_repo` added to A.2 and the example.
F8 FIXED A:16,72; D:51 `session` = launcher session token `^[a-z0-9-]+$`, used by the machine row and `subtasks[].session`; `session_id` is bus only; examples changed.
F9 FIXED C:32 dependents are never released; the lead TaskStops only already-live agents, and on INVALIDATE.
F10 FIXED C:36-37 interim carrier: fixed `## Done condition` section of the work_item instruction (writer `delivery-dispatch-plan`, reader the gate agent), per ADR 0054 "Meanwhile"; owner to decide ADR 0054 Q2 (Owner note N2).
F11 FIXED C:13,23; A:147; D:111-112 bus_endpoint reworded to A9 (data_dir/pm2_app from file, port from `$data_dir/port`, preflight and step 5 run, step 8 posts and skips cleanup()); value `$DELIVERY_ROOT`-relative `<run-id>/<subtask>/bus.endpoint`; `session_id=`/`topic=` must equal the bundle's; `delivery-run` bootstraps and restarts; `delivery-dispatch-plan` writes the bundle fields.
F12 FIXED C:55-57,66,72; D:104-105 three record shapes on the topic and the lead filter rule (registered `from_agent` only); `-escalation` drain row mapped to reason `fix-loop-cap-exhausted`.
F13 FIXED A:14; B:32 `<subtask>` = `^(st[0-9]+|pm)$` (hyphen-free; `run` extra in desk ids); full named-group id regex in B2.
F14 FIXED B:18,40-41,55 step 1 binds only transport sender and id; the JSON-subtask cross-check moved to step 5 on the hashed copy, one code (`schema`); removed from the `sender` row.
F15 FIXED B:71 `subtask` added to the `pr-merge` fields (must equal the PR's sub-task and the `record_path` segment, else `schema`).
F16 FIXED B:55,98 numbered checks including freshness, gate-missing, order and policy; first failure wins; envelope null rules, `request_sha256` null before step 4, ISO `utc`.
F17 FIXED B:33,55 retry uses a new `<n>`; no `.out` for `sender`; `desk/<id>.inflight` (mkdir) with read-back reconcile; repeat id compares stored `request_sha256`.
F18 FIXED B:18,22; A:40; C:103 relayed file renamed `<id>.desk.relayed`; relay every conductor tick (DEFAULT 1 minute); lead polls `.out` 5 minutes then re-sends the same id once; resume scans `desk/*.req` without `.out`.
F19 FIXED C:113; A:83; C:156 4-digit O_EXCL `<seq>`, lexical order, crash replay, `<name>.consumed`, INVALIDATE supersedes unconsumed RELEASE; the conductor clears `merge_sha` with `predecessor-reentered`.
F20 FIXED A:145,183; C:144 lifetime `substate.lock`, owner via temp+`mv`, unparsable owner stale after 120 s; machine row gains `pid=`, `build=` and a dead-pid reaper.
F21 FIXED A:16,105-108; C:84-88; I:70,94 one token-shape statement (40-hex sha, unit, agent_id, `step_id`, JIRA-KEY); examples now full 40-hex; `step-id` renamed `step_id`; `NEXT` step called `next_step` with a regex.
F22 FIXED A:91,96; B:141,146 only `H1.ok` unlocks `jira-create`; Jira approval is typed as `GATE <run-id> H1 ok ref=jira:<KEY>@<comment-id> ...`; separate state.md pointer path removed.
F23 FIXED B:61,85,100,104-115,127 field-type list (int, abs path, regex, enum; `tool` enum `zephyr`); closed CI / review states and `reviewDecision` incl. empty; stage names from the profile; `jira-get` readable set incl. `status`; every string field scanned.
F24 FIXED A:249,259; B:92; D:83,95 one record `review/<subtask>/record-<head>.md` (line 1 marker and line 2 Reviewed-By by `pr-review`, line 3 Verified-By by the verifying seat; seat-ids must differ; latest head governs); `record_path` input added to `pr-review` in D2.3.
F25 FIXED D:11-28 D1.1 token rule (line 1 of record file, else last stdout line) with an anchored regex, carrier and consumer per token; `POSTMERGE:` added; INTEGRATED and LANE mapped to substate/C2 fields; review-tailor seat-table path and columns; `FACTS:`/`DRAFTS:` added to D2.2.
F26 FIXED D:98-100; A:260; B:84 `TICKET-EVENT` line (regex, writer conductor, `RUN_HOME/ticket-events.log`), "seven events" each mapped to one `to`, `unblocked` -> prior status from `tickets.tsv`; `tickets.tsv` defined; `to: archive` added.
F27 FIXED I:47-55; A:199,210,213 script-interface table (catalog.sh, desk-req.sh, scope-check.sh: args, stdout, exit codes); `<n>` per-run counter under lock; `row_id` n per-file sequence under `catalog.lock`; compare-and-append lease; per-kind handle grammar.
F28 FIXED A:267; B:66 HUSKY=0 on commits allowed inside a unit/batch gated before its push; GATE-PASS gates push, PR creation and desk; `expect_head` added to `pr-create`.
F29 FIXED C:66 reasons `arch`, `source-bug`, `env-bug`, `merge-conflict`, `human-step` (and `fix-loop-cap-exhausted`), all taking the ESCALATE action; D:88 maps NLTA SOURCE_BUG/ENV_BUG.
F30 FIXED B:44,92,103 ancestor / patch-id re-derivation against `merged_into`; failure is `marker`, never `DONE deleted=false`; `none` dropped from `merged_check`.
F31 FIXED A:210 handle grammar `<repo-abs-path>#<ref>@<base>` for branch/tag, `<abs-path>#<repo>@<base>` for worktree.
F32 FIXED A:14,87; C:155 stages 6-7 host = `pm` lead (subtasks[] entry `id: pm`, started by `RELEASE pm` after the last merge); DEFAULT, from §5.0.
F33 FIXED C:171; D:75 the lead arms the cron in its own session for both backends; watchdog half in `delivery-run`, shepherd half in `delivery-shepherd`.
F34 FIXED D:76; A:34,256 `subtask`, `mode` (subtask|final) inputs, `merge-<sha>.md` evidence, record `cleanup-<run-id>-<subtask|final>.md`, token `CLEANUP DONE <subtask|final>`, approver and executor per pass.
F35 FIXED C:33 `Brief: references/briefs/<persona>.md` line written by `delivery-dispatch-plan`; `delivery-run` copies the file into the dispatch brief.
F36 FIXED C:115; A:73 `REGISTER <run-id> <subtask> <identity> <session>` in `outbox/register` (regex given), consumed by the conductor into `subtasks[]`.
F37 FIXED B:61,74-75,111 CI fields renamed `ci_run_id`.
F38 FIXED C:20 `dispatch_budget` row: bundle field by `delivery-dispatch-plan`, `work_items x (1 + (fix_loop_cap + 1) x g)` per ADR 0054 A5; ADR 0054 Q5 Owner note N9.
PR2-C1 FIXED C:3,23 ADR 0054 cites widened to Decision `:37-181`, A9 `:168-181`.
PR2-C2 FIXED I:27,86,92,145; B:17,18,66,68; C:23,129; D:89,90 bare owner Q1/Q2/Q3 now cite `owner-decisions.md:58`/`:59`/`:60`.
F39 FIXED (L, OWNER) B:12 `DESK_ADDRESS` constant, DEFAULT `desk`; Owner note N7 (ADR 0055 OP 4).
F40 PARTIAL (L, OWNER) I:41,145-146 errata E12, E13 added and ADR 0054 Q4/Q9 listed as Owner note N8 (gating W1 items 9 and 28). Not added under "Owner questions": the brief keeps that section at "none open".
F41 FIXED (L) I:29,33-43 DONE form reworded to "DEFAULT pending ADR 0055 OP 2"; OP 1/2/3/7/9 listed as Owner notes N3-N6.
F42 FIXED (L) A:222; I:84 cleanup acts only on catalog rows (the sweep registers first); row B2.1 relabelled DEF.
F43 PARTIAL (L) A:50,145,163; C:144 added: `pid=pending`, atomic temp+`mv`, run-id collision suffix, spawn count resets on hand-over, TaskStop/sweep/re-read/free order, multi-writer names, limit-200 cursor, no whitespace in DELIVERY_ROOT. Not added: nothing left out by intent; minor wording may still be tightened.
F44 PARTIAL (L) D:51-53 `INBOX`, `NUDGE`, `REGISTER` added to the message enums; compact timestamp scope widened (A:17); `step_id` spelling unified. Not done: `RELEASE <subtask>` vs `RELEASE: LIVE` rename, `id`/`subtask_id` spelling, archive executing step, per-work_item tier, plan-header `interfaces_version`, per-wave `gate_type` (trivial-only rule; left for round 2).

## Checks

- `bash tools/check-doc-length.sh <W>`: 0 blocking files over 500 lines (INTERFACES.md 152, A 280, B 151, C 171, D 154); one informational byte-size note on `changelog.md` (not mine).
- Table column-count script over the five files: no row with a column count different from its header.
- grep: no 7-char sha left in examples; `step-id` remains only as "formerly `<step-id>`" (I:94); no bare "owner Q1/Q2/Q3" without a `owner-decisions.md:<line>` cite in the edited spots.
- Freeze-status line I:3 unchanged; "Owner questions" still "None open"; new DEFAULTs logged in I "Decisions added by the round-1 fix" (Kind DEF).
