# panel7 delivery-architecture r3 s3 (review loop and rung rules)

| id | sev | artifact file:line | defect | source file:line | fix |
|---|---|---|---|---|---|
| s3-1 | M | skills/delivery-architecture/references/review-handoff.md:45 (and :70) | Orchestrator brief lists only "the D7 cap"; the record's budget line quotes D7 as "after fix round 3 with open B/M findings, STOPS" and review-7-panel step 5 dispatches a fixer on every NOT MET, so an orchestrator would run a round-3 fixer that §8 (:70) forbids, leaving bytes after the hashed round-3 state | skills/review-7-panel/SKILL.md:56,60; skills/review-tailor/references/rung-rules.md:144-145 | Add to the §3 brief list: a round-3 NOT MET ends the loop with no fixer, fix-verifier or pre-round slot; hand back the open B/M rows |
| s3-2 | L | skills/delivery-architecture/SKILL.md:28 (step 11); references/review-handoff.md:70 | "round-3 NOT MET" / "that synthesizer's open B/M rows" presume a synthesizer; Rung 1 and Rung 2 have none, so the source of open rows at a stop is unnamed | skills/review-tailor/references/rung-rules.md:44-48 | Say "the last round's verdict (synthesizer at 2b/4, reviewer at 1/2)" |

totals 0/1/1
