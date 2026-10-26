# Item 16 `review-tailor` — Rung 1 loop record

- **Artifact:** `skills/review-tailor/` (`SKILL.md`, `references/step0-inputs.md`, `seat-catalog.md`,
  `rung-rules.md`, `d12-gate.md`, `fixtures/case1-4`). Spec: `architecture/delivery-workflow/tasks/16-review-tailor.md`.
- **Loop:** one orchestrator (D35), and a separate agent for every role and round:
  - G48 pre-round screen: Haiku.
  - Review: Sonnet, running the installed `doc-reviewer` skill.
  - Fix: Opus, never the author.
  - Fix-verify: Sonnet, running the installed `fix-verifier` skill. The round 2 and round 3
    verifiers also did the non-author §9 dry run.
- **Round cap:** 3 (D7).
- **Date:** 2026-10-26.
- **INTERFACES:** 1.3.0. AM-3 landed during the loop and was folded into round 1 as finding P-AM3 (Medium).
- **Deviation:** in rounds 1 and 2 the G48 screen ran in parallel with the review rather than
  strictly before it. Its hits went to the fixer first, ahead of the review findings.

## Result

**Stopped after round 3 (D7) at B=0 M=0 L=3.** The final fix-verify was CLEAN. §9: `SKILL-16-OK`, exit 0.

| Round | Pre-check (G48) | Review | Fix | Fix-verify |
|---|---|---|---|---|
| 1 | 16 hits + P-AM3 (coordinator, verified against part-a:59, part-d:78) | B=1 M=7 L=4 | all B/M fixed per orchestrator rulings A-L; RT-Q1 left pending | ISSUES B=0 M=1 L=3 (stale "A.2.2 does not list" claim) |
| 2 | 8 hits (hit 7 rejected: the D2.3 phrase is at part-d:100) | B=0 M=1 L=5 (Rung 2 seat rule) | all fixed per rulings 1-14; RT-Q1 broadened | ISSUES B=0 M=1 L=5 (dispatch-line grammar vs Rung 2 peak); §9 dry run `SKILL-16-OK` |
| 3 | 12 hits | (no separate review; D7 last round, fix + verify only) | all fixed per rulings 1-13 | CLEAN B=0 M=0 L=3; §9 dry run `SKILL-16-OK` |

## Key changes
- **+1 modifier (AM-3 (g)):** required input `ORCHESTRATOR_TIER` (D2.2 row 4; enum is the D2.1 `tier`).
  - The shift applies when the value is not `design`.
  - A missing or bad value prints `INPUT-ERROR ORCHESTRATOR_TIER missing|enum`.
  - The author's absence rule is removed. This is settled by AM-3, so it is no longer an owner question.
  - Every fixture passes `ORCHESTRATOR_TIER=design`.
- **Profile seats:** the invented token `profile seat not covered: <id>` is removed. Its subject is
  now RT-Q1 below. The `review_profile.*` keys are cited to part-a-state.md:113.
- **Seat selection:**
  - Rung 2b: a fill-and-displace order, so fixture 3 is reproducible.
  - Rung 2: the members rule (3 to 9).
  - Every rung: the `tiers:` / `omitted:` grammar is defined.
  - Rung 4: a roster table with role names and reasons.
- **Dispatch:**
  - Format for every rung: `<base> per round, +2 when findings remain, peak <n>`.
  - Counts recomputed from the mechanism tables: Rung 3 is 21, Rung 4 is 29, Rung 2b is 9 (11 with findings).
  - Both slot anchors are stated: part-06 item 31 (12 per bus, build) and part-03 b=10 (runtime).
- **Citations:**
  - D7 and D12 are quoted verbatim.
  - G48 is cited to B-3 (owner-decisions.md:50), not to D6.
  - The ladder §3 text is quoted as written.
  - Provenance cites W-resident sources only.
  - The security `guidance` sentence is scoped to diffs.

## Open Lows (final verify)
- R3-1: the overlap note at `seat-catalog.md:56-58` splits the table, so rows 59-61 render as plain text.
- R3-2: the overflow paragraph sits between list items 3 and 4 at `seat-catalog.md:24-26`.
- R3-3: free-text record contents are not fixed, for example row order at 2b. Line 1, seat ids and seat count are determined.

## Owner questions
- **RT-Q1** (open in the spec: §6 "per-repo review profile adds mandatory seats" against RESOLVED Q1's
  fixed counts at Rungs 1, 3 and 4). Does a profile mandatory seat at a fixed-count rung (1, 3 or 4)
  that is not already in the fixed set get recorded, refused, or ignored, and with what exact text?
  - **Recommended:** keep the fixed set (D12 for Rung 3). Record the uncovered seat id in the
    record's `mechanism:` line so `pre-pr-gate` can see it. No new seat row.
  - **Meanwhile:** the skill says "pending owner question RT-Q1" and keeps the fixed set.
- **RT-Q2** (tension between part-02 §2.4 "code diff ... high blast radius: 4" and spec §7.1 / §9 case 1,
  which fix `KIND=diff` at `RUNG: 3 seats: 7` "whatever the risk surface"). Does a high-blast-radius
  code diff escalate to Rung 4?
  - **Recommended:** no. The diff stays at Rung 3 with 7 seats, and its one-way decision goes
    through a separate `KIND=plan` review at Rung 4.
  - **Meanwhile:** the skill follows the spec.

## Integrator notes (outside the item; not edited)
- Spec 16 RESOLVED Q3 says INTERFACES A.2.2 has no `review_profile.*` key. Part-a-state.md:113 now
  lists the keys.
- Spec 16 §7.4 attributes G48 to D6. G48 is adopted by B-3.
- Spec 16 predates AM-3 and should list the `ORCHESTRATOR_TIER` input (D2.2 row 4).
- `skills/review-7-panel/SKILL.md:119` says "About 9 dispatches per round (7 + synth + fix + verify)",
  which sums to 10.
- Rung 2b "1 to 7" seats (spec RESOLVED Q1, D1.1) conflicts with `review-7-panel`, which always runs 7 seats.
- `tools/review-ladder.md` §1 table has a "Cost" column (B-4).

## §9 result (final, non-author records)
```
$ FIXTURE_DIR=$TMPDIR/.../rt16/dry3 bash section9.sh   # block copied verbatim from spec §9
SKILL-16-OK
exit=0
case1 RUNG: 3 seats: 7 | case2 RUNG: 1 seats: 1 | case3 RUNG: 2b seats: 7 | case4 RUNG: 4 seats: 11
case4-bad.out: INPUT-ERROR STAKES enum (no record written for Run B)
```
Working files (scratch, not committed): rt16/r1..r3 pre-check, review, rulings, fixlog, verify; dry/, dry3/.
