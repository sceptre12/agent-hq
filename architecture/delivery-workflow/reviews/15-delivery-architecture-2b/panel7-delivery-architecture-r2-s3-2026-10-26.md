# panel7 delivery-architecture r2 s3 (review loop and rung rules)

| id | sev | artifact file:line | defect | source file:line | fix |
|---|---|---|---|---|---|
| s3-1 | M | SKILL.md:28; references/review-handoff.md:61; references/h1-packet.md:49 | Item 12 of architecture.md is filled at step 12, after the last round, while the packet claims files are hashed as the last round left them; no seat reviews item 12 | owner-decisions.md:2 (D1); h1-packet.md:49 | Fill item 12 with a stable link before round 1; keep rounds/open findings only in the review record |
| s3-2 | M | SKILL.md:26; references/review-handoff.md:25 | Card 3 floor 2b for an epic is unreachable via the rubric for a common epic (M, none/known or one of contested/novel gives Rung 2); skill halts with no resume path | review-tailor/references/rung-rules.md:15-17; part-02-skill-inventory.md:54 | State conductor resume path or how the architect inputs land epic-scale at 2b |
| s3-3 | M | references/review-handoff.md:36 | Orchestrator brief omits records/ledger directory and round-numbering base; record paths cited in packet undefined; re-entry restarting at r1 reuses names | review-7-panel/SKILL.md:62-69; h1-packet.md:27 | Add a per-SLUG records directory and require record paths in the review record |
| s3-4 | L | SKILL.md:27; references/review-handoff.md:61 | "round-3 synthesizer's open rows" has no source at Rungs 1-2 | review-tailor/references/rung-rules.md:104-107 | Say final round's reviewer report |
| s3-5 | L | references/review-handoff.md:52 | Pre-round slot before fix-verifier differs from mechanism order | review-7-panel/SKILL.md:53,56 | State override in brief or move slot to round start |
| s3-6 | L | SKILL.md:24 | Step 8 decomposer re-sync after a fix is an author edit outside fixer/verifier | review-handoff.md:41,52 | Route sync through the fixer or the pre-round check plus verifier |

totals B/M/L 0/3/3
