# panel7 delivery-architecture r2 s1 (dispatch-plan consumer interop)

| id | sev | artifact file:line | defect | source file:line | fix |
|---|---|---|---|---|---|
| s1-1 | M | skills/delivery-architecture/SKILL.md:29; references/review-handoff.md:19 | No line form is fixed for STAKES/CONTENTION/NOVELTY in review-architecture.md (step 13 body list omits them; handoff only says "write the reason"), but the consumer copies them from that file and fails with INPUT-ERROR if absent | skills/delivery-dispatch-plan/SKILL.md:29 | Specify record lines `STAKES: <v> - <reason>`, `CONTENTION: ...`, `NOVELTY: ...` in step 13 and handoff section 1 |
| s1-2 | M | skills/delivery-architecture/references/tree-rules.md:19,81 | Spike drafts and Story/Task drafts split into Subtasks carry full Agent fields but have item 5 sub-task "-", so the consumer has no sub-task to host a unit and must guess | skills/delivery-dispatch-plan/SKILL.md:19-20 | State whether such drafts are units (in which st<N>) or tracking-only, and mark it in item 5 or the draft |
| s1-3 | M | skills/delivery-architecture/SKILL.md:22; references/tree-rules.md:18-19 | A3 test-plan row needs an st<N> id, but a user-visible Story split into Subtasks has no st<N> row, so its e2e row has no valid sub-task id | interfaces/part-a-state.md:99; skills/delivery-dispatch-plan/SKILL.md:24 | Define the A3 sub-task id for a split Story and make K13 check it |
| s1-4 | L | skills/delivery-architecture/references/tree-rules.md:16-19 | Item 5 rows carry no repo per sub-task; item 3 lists other repos only as a set | skills/delivery-dispatch-plan/SKILL.md:19; interfaces/part-d-enums-topics.md:80 | Require the scope cell to name the repo root per st<N> row |

totals B/M/L 0/3/1
