# Fix record: delivery-run (W2 item 28), review-7-panel round 2

Input: `panel7-delivery-run-r2-2026-10-26.md`. Fixer: Opus, not the author. Diff base: `SCRATCH/snap28-r2/`.
Paths: S = skills/delivery-run/SKILL.md, T/L/V/C/H/RS/B = skills/delivery-run/references/{tick,ledger,verdicts,control-channel,handoffs-and-modes,resume,bus-and-ports}.md. Line numbers are post-fix.

| finding id | status | files:lines changed | what changed (one sentence) |
|---|---|---|---|
| R2-01 | FIXED | T:22-23,25 (removed),44; S:165-167,214-215; H:33-34,153 (CV21) | Pending dispatch moved to new tick step 9a after the TaskStop handling and gated on `MODE=build`, step 10 reached this session, `phase` `seeded\|building\|integrating`, no invocation live, no unit escalation open and empty `stop_reason`; the loop end now persists `phase: prepr`. |
| R2-02 | FIXED | V:37,44; S:206-207,296; H:161 (CV33) | `i<N>` PASS now requires `head` to be an ancestor of the sub-task worktree HEAD (`git merge-base --is-ancestor`), load-bearing command at current HEAD; `u<N>` keeps strict equality. |
| R2-03 | FIXED | L:82,87; S:185-189; H:163 (CV35) | Every lease the invocation took is released when the controller returns or after its TaskStop (CV24 order), and 10.2 skips a lane whose live lease is this `SESSION`'s. |
| R2-04 | FIXED | V:51,62-67; C:31; S:178,281; T:76; H:33,121; H:162 (CV34) | New "Escalation closure": open = unrenamed `escalations/<[ui]N>.md`; ANSWER appends `Resolved:` and renames `.resolved-<ts>`; per-reason re-dispatch via CV42; lead tier-up closes a drained `fix-loop-cap-exhausted` resolved-by-lead; non-unit escalation names never block. |
| R2-05 | FIXED | S:89-93; H:9-10; H:164 (CV36) | After reconcile (build, plan-pr) the lead requires the sub-task worktree with a live catalog row and adds it as the conductor does (29-22) when absent; failure is `stop_reason: human`. |
| R2-06 | FIXED | T:22; S:138; T:74; H:165 (CV37) | New watchdog step 0 checks `register.refused`/`register.consumed` and the 20-minute bound while steps 4-5 are pending and continues startup at step 5 once consumed. |
| R2-07 | FIXED | RS:45,50-63,78; S:85-86,89-90,191,268-271; C:32; T:23; H:88; H:166 (CV38) | Resume re-entry table keyed on `phase` (never lowered; `building` only from `seeded`); `merged` without `CLEANUP DONE` re-runs `delivery-cleanup` from Step 1; `MERGED` renamed `.consumed` only after `CLEANUP DONE`. |
| R2-08 | FIXED | C:73-74; S:254-256,268-271; H:89; H:167 (CV39) | Desk `noreply`/`sender` and cleanup `SPOT-CHECK FAIL` or no final record now write `escalations/desk-<id>.md` / `escalations/cleanup.md` (`human-step`) plus `stop_reason: human`, paths printed. |
| R2-09 | FIXED | H:100; H:168 (CV40) | `plan-pr` Integrator gets slot row `unit` `i0`, a stated instruction, return through `status/<agent-id>.verdict` (no bus) and the Agent return, and `HEAD` = `git rev-parse HEAD` of the `st0` worktree checked against the record. |
| R2-10 | FIXED | T:44; L:66; S:169-170 | Before the shepherd (any own call during a live invocation) the check includes the live invocation's remaining `dispatch_budget`; a failed check skips the shepherd that tick (Q2). |
| R2-11 | FIXED | T:38; C:59; S:162-163; H:154 (CV24) | After a controller TaskStop, and first on INVALIDATE, the lead reads the invocation's new dispatch lines and writes their rows before the sweep. |
| R2-12 | FIXED | T:77; L:42; S:185-186; H:169 (CV41) | New Wait-states row for the lane-lease/free-slot wait, ended by 10.2 passing via step 9a, with one `escalations/lane-wait.md` (`human-step`) past `durations.unit_median_min`, `stop_reason` unchanged. |
| R2-13 | FIXED | H:122; H:170 (CV42) | The lead appends a `Decision:`/`Answer:` absolute-path pointer line to the unit's `.tasks/<unit>-<slug>.md` (outside `spec_root`) before the re-dispatch. |
| R2-14 | FIXED | S:239,259; H:43,71 | `prepr` stores only the word after `PREPR: ` and `ci` the text after `CI: ` (A.3 forms). |
| R2-15 | FIXED | H:112-113,159 (CV25) | Any stop `release-track` reports (S1, G3, S7, d7-round3) goes to `stop_reason` and the lead stops; CV25 re-invocation only while `stop_reason` is empty. |
| R2-16 | FIXED | V:70; S:214-215; H:171 (CV43) | A `-escalation` post without `work_item` is written `escalations/wave-<N>.md` (`unit` `-`) with `stop_reason: human`, so the loop cannot treat it as progress. |
| R2-17 | FIXED | H:109 | The O1 interim is replaced: STAKES/CONTENTION/NOVELTY are read from the `PLANS_DIR/review-architecture.md` header block (AM-5 rows 15, 17), `INPUT-ERROR <NAME> missing\|enum` only when absent/invalid; counterpart note on `delivery-architecture`. |
| R2-18 | FIXED | B:21-24; S:114-116; RS:45; H:159 (CV31) | New step-0 branch: no `bus.endpoint` but a `planned\|live` `port`/`bus` row (or app listed) takes `port` from the row, no claim or register, enters at step 3 (unlisted) or 4 (listed), then 5-6. |
| R2-19 | OWNER | none | Not resolved (OBJECTION CV32); listed below. |
| L1 | FIXED | S:211; V:51 | "One tier up" = one above the unit's highest tier in `dispatch/*.jsonl` (CV7). |
| L2 | FIXED | S:181; L:67 | "Lines so far" = this invocation's dispatch record only (0 at 10.1). |
| L3 | FIXED | T:44 | Closed with R2-01 (step 9a after step 9). |
| L5 | PARTIAL | S:268-271 | Step 15 now names `CLEANUP DONE` -> `phase: done`; Exit criteria not changed (word cap). |
| L6 | FIXED | T:44 | Shepherd deadline = dispatch plus one tick interval, then TaskStop (default, proposed CV22). |
| L10 | FIXED | S:141-142; T:23 | Inbox bullet leaves a `pm` `verdict` file unconsumed. |
| L12 | FIXED | S:85-86; RS:45 | Reconcile step (4) names the one start of an unlisted app (CV31 extended). |
| L13 | FIXED | S:254 | Step 13 adds the second 5-minute poll. |
| L16 | FIXED | S:61-63,101; H:15 | Catalog existence check moved to step 3, before the tick's `cron` row. |
| L17 | FIXED | S:58 | AM-5 29-2 marked proposed in SKILL.md (L:74 left; not the same edit). |
| L18 | FIXED | RS:45 | Resume step 4 no longer re-arms the tick (armed at step 3). |
| L19 | FIXED | H:33; H:138 (CV6) | The wait is stated: no new invocation for any unit while a unit escalation is open; CV6 "runs on" limited to the live invocation. |
| L20 | FIXED | T:74 | Register re-check each minute marked default, proposed CV23. |
| L4, L7, L8, L9, L11, L14, L15 | not touched | none | Lows not closed by the same edits. |

## New proposed conventions
- CV33: `i<N>` PASS accepts `head` as an ancestor of the sub-task worktree HEAD; counterpart note on `briefs/integrator.md` strict-check wording.
- CV34: escalation open/closed definition, ANSWER closure by append + rename, per-reason re-dispatch, lead-resolved tier-up, non-unit names never block.
- CV35: release all of an invocation's leases on return/TaskStop; skip own-held lanes.
- CV36: lead ensures the sub-task worktree (build, plan-pr) as the conductor does for `claude -p`.
- CV37: watchdog step 0 startup wait for `register.consumed`.
- CV38: resume re-entry by `phase`, never lowered; `MERGED` consumed only after `CLEANUP DONE`.
- CV39: non-unit stops (desk noreply/sender, cleanup fail) are escalation file + `stop_reason: human`.
- CV40: `plan-pr` Integrator dispatch details (`i0`, status-file record, HEAD source).
- CV41: lane-lease/free-slot wait row and `lane-wait.md` escalation.
- CV42: `.tasks` pointer line delivers a decision or answer to the re-dispatched worker.
- CV43: drained escalation without `work_item` -> `escalations/wave-<N>.md`, `stop_reason: human`.
- Extended in place: CV6 (L19), CV21 (step 9a gate, loop end `phase: prepr`), CV24 (dispatch read before sweep), CV25 (release-track stops), CV31 (partial-start bus resume, unlisted-app start).

## Owner questions
- R2-19 (OBJECTION CV32): on `POSTMERGE: FAIL`, does the `pm` lead run `delivery-cleanup` mode `subtask` for `pm` before it ends, or does the second `pm` lead use a new worktree path? Not decided here.
- O1 (narrowed by R2-17): who makes `delivery-architecture` write the STAKES/CONTENTION/NOVELTY header block (counterpart).

## Checks
- `bash SCRATCH/s9-28.sh`: last lines `VERBATIM-OK`, `SKILL-28-OK`.
- `wc -w SKILL.md`: 3683 (cap 3700; was 3461).
- Lines: SKILL.md 328; bus-and-ports 84, control-channel 82, handoffs-and-modes 181, ledger 100, resume 79, tick 95, verdicts 113. `check-doc-length.sh`: 0 blocking files.
- Only the eight permitted files edited; briefs/ and templates/ untouched (s9 check); no new files under the skill.
