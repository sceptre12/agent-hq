# Fix record, round 2: delivery-pipeline (W2 item 29), 2026-10-26

Input: `panel7-delivery-pipeline-r2-2026-10-26.md` (2 B, 20 M incl. R2-15 OWNER and V1B-01). Fixer did not author the skill or the round-1 fixes. Edits are uncommitted on top of WIP 103cb53. Lows and NOTE rows not applied (dispatch prompt did not ask for them). Paths under `skills/delivery-pipeline/`.

| finding id | status | file:line after the fix | one-line change |
|---|---|---|---|
| R2-01 | FIXED | SKILL.md:22 (R2); refs/tick-relay.md:106-107; refs/provenance.md:60 (29-25) | RELEASE is recorded only by a `release` file newer than the receiver's latest `invalidate`; MERGED only by a file naming the current sha; `released_utc` set on every RELEASE |
| R2-02 | FIXED | SKILL.md:21-22; refs/tick-relay.md:106-107; refs/provenance.md:49, :60 | back-edge writes `reentered_utc` (kept); INVALIDATE due only to a successor whose `released_utc` precedes it and with no `invalidate` file newer than it |
| R2-03 | FIXED | refs/launcher.md:26-27; SKILL.md:19; refs/stages.md:72; refs/provenance.md:61 (29-26) | pending 31 / build=1 count only live pending launches (state released/building/pr-open/merged-not-cleaned, no row, no `.dead`, pid alive or launched <10 min) |
| R2-04 | FIXED | refs/resume.md:13; SKILL.md:15; refs/provenance.md:60 | applied-result scan applies only the newest `pr-merge` `.out` per sub-task with `expect_head` = current `head`, state `pr-open`, request later than any `reentered_utc` |
| R2-05 | FIXED | SKILL.md:22, :27; refs/tick-relay.md:19, :107; refs/stages.md:99; refs/resume.md:22 | `RELEASE pm` joins the R2 derivation (pm `session` set, all others merged, no `release` newer than pm `launched_utc`); step 12 no longer writes it directly |
| R2-06 | FIXED | SKILL.md:17; refs/stages.md:55; refs/resume.md:32; refs/provenance.md:52 (29-17) | `h1_handled` recorded only after the re-invocation returns; stage 2 skip needs `review-architecture.md` newer than the H1.changes `utc=` |
| R2-07 | FIXED | SKILL.md:19, :27; refs/stages.md:103; refs/tick-relay.md:20; refs/resume.md:33; refs/provenance.md:64 (29-29) | re-entry `st<N>` launch-ready only with its dispatch-plan row and a clean `plan-check.md` newer than `pm/new-units.md`, 29-23 read applied; same predicate at resume |
| R2-08 | FIXED | refs/stages.md:103; refs/provenance.md:55 (29-20 amended); SKILL.md:27 | row id -> test-plan owner column -> sub-task dispatch-plan `ticket`, else epic key; post names the key |
| R2-09 | FIXED | refs/tick-relay.md:84-88 (§7); refs/resume.md:23; SKILL.md:24 (9f) | skip live current-session pid or launch <10 min; read lock owner only for a lock newer than `launched_utc`; older lock is no relaunch trigger |
| R2-10 | FIXED | SKILL.md:19, :22; refs/launcher.md:29; refs/tick-relay.md:88; refs/provenance.md:48, :61 | `launched_utc` written with the intent; startup failure = 10 min after it with no pid file or a dead pid; `agent-tool` check only re-posts the ask, counted from its own row |
| R2-11 | FIXED | refs/launcher.md:28-29, :62; SKILL.md:19; refs/stages.md:72 | fail-closed checks and worktree add run before the intent write; failure writes no intent |
| R2-12 | FIXED | refs/launcher.md:26, :29; refs/resume.md:49; SKILL.md:19 | sub-task being (re)launched excluded from the pending sum; new `session` replaces the old token in the same write |
| R2-13 | FIXED | refs/tick-relay.md:73; refs/stops-and-posts.md:27, :31; refs/stages.md:102; refs/provenance.md:66 (29-31) | `pm` `human` + POSTMERGE: STOP record read as the STOP row (state kept); `human` row applies to `st<N>` only |
| R2-14 | FIXED | SKILL.md:27; refs/stages.md:102; refs/stops-and-posts.md:31, :64; refs/tick-relay.md:73 | no `GATE ... H-destructive` line is emitted; post names the row and states the desk does not yet accept an H-destructive grant (owner question R2-15) |
| R2-15 | OWNER | - | not resolved; see Owner questions |
| R2-16 | FIXED | SKILL.md:27; refs/stages.md:99; refs/launcher.md:44; refs/provenance.md:63 (29-28) | pm launch prompt carries STAKES/CONTENTION/NOVELTY from `review-architecture.md` lines 2-4; absent: no pm launch, human step; pm INPUT-ERROR posted with `lead.log`/`substate.md` |
| R2-17 | FIXED | SKILL.md:26; refs/resume.md:45; refs/launcher.md:12 | `agent-tool` relaunch post carries the full `delivery-run` call with the new `SESSION` plus the brief |
| R2-18 | FIXED | SKILL.md:29; refs/stages.md:56, :109; refs/resume.md:36; refs/provenance.md:65 (29-30) | final cleanup runs once; without `CLEANUP DONE final` post the `.tmp` path and SPOT-CHECK block, advance nothing, re-run only on the owner's word |
| R2-19 | FIXED | SKILL.md:24 (9i); refs/tick-relay.md:21 (4d), :80 (§6); refs/stops-and-posts.md:37; refs/provenance.md:42, :50 | `blocked`/`unblocked` derived from `ticket-events.log` (latest event per ticket), not from the previous post; 29-8 and 29-15 amended |
| R2-20 | FIXED | refs/resume.md:32 (new row "2 -> 3, tickets"); refs/provenance.md:52 | `gates.H1` set and (`epic` empty or `tickets.tsv` absent) re-runs ticket-clerk, the epic copy and missing `published` events |
| R2-21 | FIXED | SKILL.md:16; refs/stages.md:42; refs/tick-relay.md:20; refs/provenance.md:62 (29-27) | tick armed right after the `run` claim; 4c invokes `delivery-intake` once REGISTERED ok is in hand and `repo_profile` is empty |
| V1B-01 | FIXED | refs/tick-relay.md:9; SKILL.md:15, :22 (R4); refs/resume.md:18, :20; refs/provenance.md:51 (29-16), :62 (29-27) | `run` REGISTER-SENDER claim and its no-reply re-send exempt from the send gate; re-sent after REBIND; lead REGISTER-SENDERs stay gated |

Refused: none.

## Owner questions
- R2-15 (OWNER, B8): how is the grant for a destructive post-merge row typed, given B8 has no `H-destructive.<row-id>` GATE alternative? Until decided the skill posts the row and names the open decision; it gives no GATE line.
- R2-38 (NOTE, KNOWN): what follows a `pm` POSTMERGE: STOP grant, since the `pm` lead has exited. Not touched.
- Proposed conventions to confirm or replace: 29-25..29-31 below, and the amended 29-8, 29-13, 29-14, 29-15, 29-16, 29-17, 29-20.
- No OBJECTION rows in this round.

## New proposed conventions (references/provenance.md §Conventions pending INTERFACES)
- 29-25 cycle keys (`released_utc` on every RELEASE, `launched_utc`, `reentered_utc`) for RELEASE/RELEASE pm/MERGED/INVALIDATE re-derivation and the pr-merge applied-result scan.
- 29-26 ledger counting and live launch (live pending launches only, own sub-task excluded, intent after fail-closed checks, lock newer than `launched_utc`).
- 29-27 `run` REGISTER-SENDER claim exempt from the send gate; tick armed after the claim; intake on REGISTERED ok.
- 29-28 STAKES/CONTENTION/NOVELTY to the pm launch prompt from `review-architecture.md` lines 2-4.
- 29-29 re-entry `st<N>` launch readiness (row + clean plan-check newer than `pm/new-units.md`).
- 29-30 final cleanup runs once, then a human step (default); resumed `stopped` run cleans once.
- 29-31 `pm` `human` + POSTMERGE: STOP read as the STOP row.

## Checks
- `bash SCRATCH/s9-29.sh` (from W): last line `PIPELINE-29-OK`, no other output.
- `wc -w SKILL.md`: 3783 (<= 3800).
- `bash tools/check-doc-length.sh .`: 0 blocking files over 500 lines.
