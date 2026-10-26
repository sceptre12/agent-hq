# Plan-checker loop (step 12)

Authority: INTERFACES C1.3 (invocation), D1.1 (`PLAN-CHECK:` token), D7 (round cap), design section 4 (G48, D55, D57, D60). This page is the procedure; it restates none of those tables.

## Before the first Plan-checker

1. G48 pre-round check: dispatch one mechanical-tier agent to read the plan files against the known finding classes (unmeasured claims, arithmetic, cross-document contradictions, missing done conditions, protected values) and report. Land its fixes, then re-run `references/predispatch-checklist.md`.
2. Freeze scope once the core stops changing: two consecutive rounds with no change to the core sections (D57).

## One round

1. Dispatch a fresh Plan-checker (depth 1, persona `plan-checker`, brief `skills/delivery-run/references/briefs/plan-checker.md`). Inputs: `PLANS_DIR` and `RUN_HOME`. A checker is never reused across rounds.
2. It runs spec-format rules 1-11 and 13-15 on every `waves/`, and writes `RUN_HOME/plan-check.md`. Line 1 is `PLAN-CHECK: clean` or `PLAN-CHECK: <n> findings`; the rest lists findings.
3. Read line 1 from the file (the file is the carrier; do not take the checker's chat reply as the token).
4. `clean`: stop the loop.
5. `<n> findings`: fix the plan files in one pass (exact edit per finding, protected values listed, no new scope). Re-run the checklist, then start the next round with a new checker. A finding that arrives mid-round waits for the next round start.

## Stop rules

- Round cap is 3 (D7). Round 3 not `clean`: stop, write the open findings and the round history into the plan's review section, tell the owner, and leave `plan-check.md` as the last checker wrote it. Do not start round 4.
- Same finding class in two consecutive rounds: replace the mechanism (rewrite the section or its source) and check the section got shorter in bytes (D60), rather than patching again.
- The fixer is design tier (INTERFACES D2.1 `tier` row, E25, AM-3). A second fix round that adds Mediums escalates the fixer one tier for that round; never a third top-tier attempt (ADR 0014 T1).
- A frozen "(fact)" contradicted by a finding: stop and re-measure it before anything else (D51).
- Plan-checker failure to write `plan-check.md`: treat it as a stalled agent; re-dispatch once as a fresh checker in the same round, else report to the conductor.

## After clean

Call `review-tailor` (inputs in SKILL.md step 12), run its rung (2b above 10 units, else 1; naming the rung, never inlining the mechanism), and loop to 0 blocking and 0 medium or round 3. If a review fix changes `waves/` or the unit table, re-run the checklist and dispatch a fresh Plan-checker in that same review round; the final line 1 of `plan-check.md` must be `clean` at exit unless the owner was told otherwise.
