# Panel7 r1 s1: dispatch-plan consumer interop (arch15-r1-s1)

| id | sev | artifact file:line | defect | source file:line | fix |
|---|---|---|---|---|---|
| s1-1 | B | skills/delivery-architecture/SKILL.md:26; references/review-handoff.md:7-16 | review-tailor call omits required ORCHESTRATOR_TIER; review-tailor answers INPUT-ERROR ORCHESTRATOR_TIER missing, no rung record | interfaces/part-d-enums-topics.md:78; skills/review-tailor/references/step0-inputs.md:18,22 | add ORCHESTRATOR_TIER (state.md orchestrator_tier) to step 10, the handoff table and step 0 |
| s1-2 | M | SKILL.md:20; references/tree-rules.md:12,58 | item 5 only "tree by slug"; K6 equates item-5 slugs with draft stems; template's st0/st<N>, depends-on, merge-order columns uninstructed, st0 has no draft | references/templates/architecture.md:50-53; skills/delivery-dispatch-plan/SKILL.md:18-19 | specify item 5 columns, which node types are PR sub-tasks, K6 on ticket-slug column with st0 exempt |
| s1-3 | M | SKILL.md:20 (item 7 never mentioned) | item 7 (lanes, shared-file owners, ports to claim, no-parallel units) not instructed; fixed ports put in item 3 (no port column); consumer never reads architecture-named ports into its port table | templates/architecture.md:37-44,60-61; delivery-dispatch-plan/SKILL.md:25; references/shared-files-and-parallelism.md:42 | put fixed ports/lane/owner needs in item 7 in a fixed row shape; add a check |
| s1-4 | M | SKILL.md:22 | test-plan A3 needs sub-task and unit-slug columns and batched st<N>: .feature list (H-e2e ref); skill defines neither at v0 | templates/test-plan.md:33-43; delivery-dispatch-plan/SKILL.md:24 | define sub-task = st id from item 5, unit slug = draft slug, and when the list is final |
| s1-5 | M | references/contracts.md:26; references/tree-rules.md:66 (K14) | item 3 contract table specified as (name, owner path, consumers); template item 3 table has no consumers column | templates/architecture.md:42-44 | map contract fields onto template columns and make K14 match |
| s1-6 | L | references/decomposer-brief.md:7 | no :(glob) dialect for scope globs, no runnable-command requirement for Verifier; consumer copies globs to .tasks section 3 and needs a runnable verifier | delivery-dispatch-plan/SKILL.md:20-21; templates/ticket.md:130,136 | add both constraints |

totals B/M/L 1/4/1
