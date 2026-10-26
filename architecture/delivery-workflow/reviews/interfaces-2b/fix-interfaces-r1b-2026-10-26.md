# Fix record, INTERFACES 2b, round 1b (2026-10-26)

Fixer: narrow fixer r1b (Opus), not the author, orchestrator or verifier (Rule 4). Inputs: `architecture/delivery-workflow-sources/owner-decisions.md:62-76`, `decisions/0054-adr-0023-amendment-delivery-workflow.md` (A0-A9, owner list `:267-284`), `decisions/0055-desk-verb-permission-tiers-02.md` (§1-§5, owner list `:257-271`), `reviews/interfaces-2b/preround-interfaces-r2-2026-10-26.md`. Files edited: `INTERFACES.md`, `interfaces/part-a-state.md`, `part-b-desk.md`, `part-c-waves-control.md`, `part-d-enums-topics.md`. No ADR, design or freeze-status line edited.

## Owner rulings folded in (settled, owner 2026-10-26)

- OWN-OP1: B2 `REJECTED` bullet cites OP1 A (`owner-decisions.md:63`); decisions-log row B2 Kind O; row O-OP1.
- OWN-OP2: B2 `DONE` bullet cites OP2 A (`:64`); errata E5 cites the ruling (design text still differs, kept); "DEFAULT pending OP 2" paragraph removed from INTERFACES.md.
- OWN-OP3: desk-held sender registry. B1 "Sender identity" row rewritten; B1 "Registered ids" row replaced by a "Registration line" row (`REGISTER-SENDER <run-id> | <subtask|run> | <sender-id>`, reply `REGISTERED ... | ok|refused`, run claim, replace on hand-over, re-send after conductor resume, desk-owned mirror `desk-inbox/<run-id>.registry`; form `DEFAULT (integrator)` as ADR 0055's `[freeze]`); B1 `claude -p` row and B2.1 `sender` trigger use the registered conductor; A.2 `conductor_id` field and example line removed, A.2 readers line says the desk never reads sender ids; `lead_id` demoted to the conductor's own record; C5.1 layout and lead-to-conductor paragraph relay the lead's `REGISTER` to the desk; D2.1 new "conductor to desk" row; D2.2 row 15 inputs; decisions-log rows A.2, B1, C5/C6 updated.
- OWN-OP4: B1 new "Permission tiers" row (desk tier, "never source" scoped to `INSTALL`, conductor and Agent-tool leads executor, `claude -p` no tier); "Who runs the desk" says model tier `execute`; "Desk address" row cites OP4 A and keeps the name as `DEFAULT (integrator)`.
- OWN-OP5: B2.1 gains a Class column and the terminal/curable rule; B2 idempotency bullet: stored `REJECTED` replay, curable resend with fresh id, terminal never resent. Classes other than `action-failed` marked `DEFAULT (integrator)` (terminal: sender, schema, hash, repo, policy; curable: marker, order, stale-session, gate-missing).
- OWN-OP6: part B scope line cites OP6 A (`:68`).
- OWN-OP7: B2 `<utc>` and `run` now cite OP7 A (`:69`); B1 `claude -p` row and "Allowed requesters" row cite OP7 A for `pr-merge`, the other four conductor-only verbs marked `DEFAULT (integrator)`; A.1 `<subtask>` row cites OP7.
- OWN-OP8: B1 "Credentials" row: no approved-account list for `DESK` in the work runtime, registered-clone `repo` check only, OP8 (a) B and (b) A (`:70`).
- OWN-OP9: B7 desk-side bullet and B4 `pr-attach` row cite OP9 A (`:71`); label form and `lanes/` root stay `DEFAULT (integrator)`.
- OWN-OP10: B2 grammar line now has ten codes (ADR 0055 `:55` verbatim) plus a note; B2.1 `action-failed` row (curable); B3 step 9 "else `action-failed`"; new errata E14.
- OWN-Q2: C1.2 "done token" row: one optional per-work_item field, required under `step_complete`, named `done_condition` (`DEFAULT (integrator)` name); "verifier" row walks `done_condition`; C1.3 rule 9 sentence; D2.3 `wave-execution` inputs.
- OWN-Q3: A.4 reservation scheme removed (rows written per dispatch-record agent, `DEFAULT (integrator)`); field 1 constraint simplified; A.4 free-slot formula `30 - live_rows - sum(reserved)`; C1.1 `max_concurrent` row and dispatch-record row updated; decisions-log row A.4 updated.
- OWN-Q4: C1 wave-files paragraph, C1.2 blocked-by row, C1.3 rule 15 cite Q4; errata E12, E13 kept (design text still differs) and cite the ruling.
- OWN-Q5: C1.1 `dispatch_budget` "pending Q5" replaced by the ruling; C1.2 blocked-by row (per-work_item gate, fix loop, budget); C2 escalation row.
- OWN-Q6: C2 `PASS` row cites A6 `:135-137` and Q6; C5.3 resume sentence: checkpoint is the sole resume authority.
- OWN-Q7: C4 pickup bullet: the caller consumes the fallback file (A7 `:159-163`).
- OWN-Q8: C1.3 rule 14: a differing per-wave `output_topic` is `VALIDATION_FAILED`.
- OWN-Q9: C1.1 `max_concurrent` row cites Q9 (A0 `:47-51`); D2.3; errata E12.
- OWN-Q10: C1.2 persona and lane rows cite Q10; D2.3.
- OWN-Q11: C1.2 verifier row: a barrier-wave `step_complete` gate passes only when every gate passes (A4 `:85-87`).
- OWN-N: INTERFACES.md "Owner questions" and "Owner notes" sections merged into "Owner questions and notes: None open"; N1-N9 retired into a new decisions-log table "Owner rulings of 2026-10-26" (rows O-OP1..O-OP10, O-Q2..O-Q11, Kind O, each with `owner-decisions.md:<line>` and the N row it retires); decisions-log rows B7, C1, C1.1, C1.2 point to those rows. Nothing genuinely open remains; the ADRs' `[freeze]` forms are marked `DEFAULT (integrator)` in the parts.

## Pre-round FAILs

- PR3-C1: part-b B1 "Allowed requesters" cite is now `architecture/delivery-workflow/part-05-execution-constraints.md:36-44` (opened: §6.3 heading at :36, grammar block :38-42, id rule :43).
- PR3-C2a: part-a A.4 non-verbatim quote of ADR 0054 A1 removed (paragraph rewritten for Q3, cites `:55-61`).
- PR3-C2b: part-c wave-files paragraph: quote marks dropped, cites ADR 0054 `:93-96`.
- PR3-C2c: part-c done-condition row: dead "Meanwhile" cite `:255-260` replaced by `:75-80`, `:174-176`.
- PR3-C2d: INTERFACES.md ADR mentions now carry path:line (consumers line `:1-290`/`:1-271`; notes paragraph `:257-271`, `:267-284`; owner-rulings table; E5, E12, E14); part-c status line cites updated to the current ADR (Decision `:38-197`, A9 `:179-197`).
- PR3-C4: inbox first line in part C5.1 is `ANSWER <run-id> <subtask> <unit> <text>`; INTERFACES.md decisions-log row B8 is `GATE <run-id> <gate> <verdict> <text>` and `ANSWER <run-id> <subtask> <unit> <text>` (part B8 form).
- PR3-C5a: part-a A.2.1 `by=`/`ref=` marked `DEFAULT (integrator)`; "Agents never write under `gates/`" cites §5.0, M30.
- PR3-C5b: part-a `bus.endpoint` mismatch sentence marked `DEFAULT (integrator)`.
- PR3-C5c: part-a A.7 commit sentence marked `DEFAULT (integrator)`, from R2-3.
- PR3-C5d: part-b "Allowed requesters": owner cite for `pr-merge`, `DEFAULT (integrator)` for the other verbs.
- PR3-C5e: part-b B5 content-merged method marked `DEFAULT (integrator)`; B5 lead-in cites the ADR 0055 `[freeze]` lines.
- PR3-C5f: part-b B8 matrix refusal marked `DEFAULT (integrator)`.
- PR3-C5g: part-c C1.1 bus restarter sentence marked `DEFAULT (integrator)`, citing A9 `:194-197`.
- PR3-C5h: part-c C1.2 blocked-by `TaskStop` sentence marked `DEFAULT (integrator)`.
- PR3-C5i: part-c C2 escalation "dependents stay unreleased" cites A5 `:106-112` and Q5.
- PR3-C5j: part-c merged-tick "armed by the lead" marked `DEFAULT (integrator)`.
- PR3-C5k: part-d D5 restarter sentence marked `DEFAULT (integrator)`.

## Checks

- `bash tools/check-doc-length.sh .`: 0 blocking files over 500 lines. INTERFACES.md 162, part-a 278, part-b 157, part-c 173, part-d 155 lines.
- grep `owner to decide|pending ADR|conductor_id|reservation|Done condition|ADR 0055 OP ` over the five files: no stale hits.
- grep of `GATE`/`ANSWER` line shapes across the five files: all `<run-id>`-first, matching part B8.
- Observed, not changed (no owner ruling; outside this brief): part B2 idempotency answers a repeated id with a differing hash with `REJECTED schema`, while ADR 0055 `:186-188` describes the part-b draft as returning the stored result. For the next round to settle.
