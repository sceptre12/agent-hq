# Seat s6 round 2 (arch15-r2-s6): tree, drafts, contracts mechanics
| id | sev | artifact file:line | defect | source file:line | fix |
|---|---|---|---|---|---|
| s6-1 | M | skills/delivery-architecture/SKILL.md:22 (step 6); skills/delivery-architecture/references/tree-rules.md:18-19 | A3 rows take sub-task = item 5 st<N> id, but a Story/Task split into Subtasks has sub-task '-' in item 5, so its e2e row has no id | templates/test-plan.md:32-43; part-a-state.md A.2.1 H-e2e | Say which st<N> carries a split Story's e2e row; make K13 check it |
| s6-2 | M | skills/delivery-architecture/references/tree-rules.md:48,64-67 (K5, K8) | Parents-before-children publish order is not checked by any K; Spike/Story/Task parent unconstrained, can conflict with spikes-first | part-02-skill-inventory.md:76; templates/ticket.md Lifecycle 2 | Add an order check and restrict parent types |
| s6-3 | L | skills/delivery-architecture/references/tree-rules.md:80,83 | K9 list keeps 'Spikes (first, timeboxed)' parenthetical the comparison rule strips | templates/ticket.md Epic additions | List stripped form or apply rule to both sides |
| s6-4 | L | skills/delivery-architecture/references/tree-rules.md:18-19 | depends-on cannot name a Spike with no st row | templates/architecture.md:51 | Define how a Spike-blocked sub-task is expressed |
| s6-5 | L | skills/delivery-architecture/references/tree-rules.md:66 vs :44, skills/delivery-architecture/SKILL.md:20 | K7 and exit criteria omit the required observability Scenario | templates/ticket.md Scenario 3 | Add to K7 |
| s6-6 | L | skills/delivery-architecture/references/contracts.md:32 | 'two distinctive lines' not mechanical; no pin form for non-contracts/ owners | skills/delivery-architecture/references/tree-rules.md:73 | Define selection and pin form |
totals 0/2/4
