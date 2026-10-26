# panel7 delivery-pipeline r3 s2 (human gates)

id | sev | artifact file:line | defect | source file:line | fix
--- | --- | --- | --- | --- | ---
(none B/M) | - | - | Every gate path checked (H0, H1 ok/changes/reject with h1_handled, H-e2e, H-pr read-back + expect_head, H-prod via desk-enforced publish/tag-push, conductor-only verbs never relayed, pr-merge only through stage 5b with desk B5 re-derivation as backstop) is desk-file or read-back gated; no stale gate accepted that the desk would not also refuse. | A.2.1 part-a-state.md; B5 part-b-desk.md:110 | - 
(note, not counted) | - | references/resume.md:14 | applied-result scan appends a `pr-approval-state` pointer without the headRefOid = current GREEN sha check of stages.md 5b step 2 (evidence only; desk pr-merge re-checks H-pr, so no gate is passed) | stages.md 5b step 2; 29-12 | apply the same headRefOid check in the scan

totals 0/0/0
