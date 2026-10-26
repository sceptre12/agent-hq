ISSUES_FOUND 0/1

Paths as in the fix record (S = SKILL.md, T = tick.md, H = handoffs-and-modes.md, RS = resume.md, L = ledger.md). Sources opened: W' wave-execution/SKILL.md:183-200, post-merge-verify SKILL.md:27,43,50, release-track SKILL.md:17, part-b-desk.md:22, swarm-communication SKILL.md:88, part-a-state.md:186, unit-and-waves.md:14, SCRATCH/am5-queue.md.

id | check | result | file:line | note
---|---|---|---|---
PR1-C2a | 1 | closed | T:54; H:27 | P-C:182 and part-02-skill-inventory.md:60/62 resolve (:60 card 6, :62 card 7 and the Stop text).
PR1-C5a | 1,5 | closed | L:73,76; B:41; RS:26; C:73 | Each timing now has an anchor; the lock line (part-a-state.md:186), swarm-communication:88 and part-b-desk.md:22 match.
R1-01 | 1 | closed | S:191-193; H:142 | Bundle-root `spec_root` and the `.wave-execution-state` sibling match W' SKILL.md:185. Marked CV20.
R1-02/03/04 | 1 | closed | S:170-183,208-219; H:24-33 | Consistent with W' :190-197 (resume at unpassed items; "All passed" exits). Marked CV21.
R1-05 | 1 | closed | S:103-104; H:19,140 | Matches unit-and-waves.md:14 (`constitution.md` at the bundle root).
R1-08 | 1 | closed | T:57-64; S:226-229 | Marked CV22; the `ci_round_min` / `pr_review_min` deadlines are proposed.
R1-09 | 1 | closed with M-1 | S:62-63,70-72; T:8; C:48,55 | Early tick and the 20-minute register bound are present and marked CV23. See M-1 for the side effect.
R1-11 | 1 | closed with M-1 | S:179-183; T:25; L:42,86 | Lease and slot checks now precede the controller row. The tick re-entry is the M-1 source.
R1-12 | 1 | closed | S:133-135; T:16 | The `claude -p` blocking fallback is the C1.1 branch, now the default until PC-W2-7 is measured (CV23). The CV8 text is marked superseded.
R1-13 | 1 | PARTIAL, accepted | T:66-78 | Reason stated: the `claude -p` mechanism is O5, an owner decision. The `agent-tool` column is complete.
R1-14 | 1 | closed | S:159-160; T:38 | TaskList confirm, sweep of every live row, rows stay `.row` until gone (CV24).
R1-16 | 1,3 | OWNER, fail closed | H:105 | The interim is labelled and stops before `release-track`. No carrier is picked.
R1-17/18/19 | 1 | closed | H:103-107; C:22-23,33 | Consistent with post-merge-verify :27,:43,:50. The `verdict` type is left unconsumed by the tick.
R1-20 | 1 | closed | H:108; T:76 | CV25; the bound is left as O6.
R1-21/22/23 | 1 | closed | S:233-257; H:43-72 | CV26-28 are marked proposed. Counterpart notes are listed in the fix record.
R1-24/25/26 | 1,5 | closed | T:61; L:40,66,74-76; S:52-62 | The "31" is cited as AM-5 29-2. In am5-queue.md:10 that row is "proposed", not decided (see L-1).
R1-27/28 | 1 | closed | S:76-78,108-115; C:24; RS:35,48 | CV30, CV31.
R1-06/07/10/15/35-38 | 3 | OWNER, not decided | S:106-108; H:11 | R1-07 only states that the early tick cannot fire during a blocking call and names O3. No owner option is picked.
M-1 | 2 | REGRESSION (M) | T:25-26; S:35-40,179-183 | The new "Pending dispatch" tick step fires when no `wave-controller` row exists, the step 10 loop has not ended, no escalation is open and `stop_reason` is empty. Nothing names a state meaning "step 10 has been entered and released". The tick is now armed at step 3. So an `agent-tool` lead idling in the register wait (step 4), the `RELEASE` wait (step 5, `pm` and every successor sub-task) or the bus phase meets all four conditions at the first tick. It then runs 10.1 and dispatches before `register.consumed` or `RELEASE`, which breaks C6 ordering and B1 "no DESK before register.consumed". The `plan-pr`/`post-merge` modes have no step 10, so the same text is read as "loop not ended". Fix: give the step a precondition, for example `RELEASE` consumed (or not required), `register.consumed` present, `bus.endpoint` present, `phase` in `seeded`/`building`/`integrating`, and mode `build`; or add a `loop_state` key.
scope | 3 | OK | only SKILL.md and 7 refs | `diff -rq` against snap28-r1 shows exactly those 8 files. briefs/ and templates/ are untouched (live-only dirs). CV20-CV32 are listed in H "Conventions pending INTERFACES" and marked proposed.
s9 | 4 | OK | - | `bash SCRATCH/s9-28.sh` ends VERBATIM-OK, SKILL-28-OK. `wc -w SKILL.md` = 3461 (<= 3700).
rules kept | 2 | OK | - | No rule dropped, compared with the diff. D4, D7 (third `ci` cycle = `d7-round3`), D10 (flag only, the lead decides every stop) and AM4-1/AM4-2 all hold.

## New Lows
- L-1 (S:59; L:76): AM-5 29-2 is cited like a decided row but is "proposed" in am5-queue.md:10. Add "(proposed)" at both places.
- L-2 (RS:45 vs S:62): resume reconcile step 4 still says "re-arm the merged tick", while the tick is now armed at step 3 on every start, so a resume can arm two crons. Reword RS:45 to "already armed at step 3".
- L-3 (S:62-63; S:52): the tick is armed at step 3 and registered as a catalog `cron` row before the step 7 catalog-exists check. Say that a missing `catalog.tsv` at step 3 is the same `human` stop.
- L-4 (H:312 "Loop end" vs H CV6 text "the rest of the sub-task runs on"): "no invocation while an escalation is open" means a ROLLED tier-up on another unit also waits for the ANSWER. State this, or reword CV6.
- L-5 (T:545): "in-turn re-check each minute" for a `claude -p` register wait has no anchor or "default, proposed" mark.
