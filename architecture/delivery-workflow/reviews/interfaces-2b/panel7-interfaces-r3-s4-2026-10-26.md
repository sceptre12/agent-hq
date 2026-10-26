# panel7 interfaces 2b, round 3, seat s4 (design and owner-ruling fidelity), 2026-10-26

| id | sev | artifact file:line | defect | source | fix |
|---|---|---|---|---|---|
| s4-1 | M | interfaces/part-b-desk.md:86 | tag-push has no human-gate precondition; only publish requires H-prod.<step_id>.ok (gate matrix :152) | part-02-skill-inventory.md:74 (tag/publish only where human approved); owner-decisions.md:20 (D15) | gate tag-push on H-prod.<step_id>.ok or state it is staging-only and where a prod tag is refused |
| s4-2 | M | interfaces/part-c-waves-control.md:11 | wave-file set omits design Wave 0 setup (catalog init, serial worktree add, baseline gates, facts re-measure, lane leases); owner of those steps undefined | part-03-personas-and-concurrency.md:80, :67 | state Wave 0 setup is lead-run by delivery-run with steps and producers, or add a setup wave |
| s4-3 | L | interfaces/part-b-desk.md:82 | ci-logs/ci-rerun field run_id renamed ci_run_id; not in errata list | part-05-execution-constraints.md:43 | add errata row for the rename and added fields |
| s4-4 | L | interfaces/part-a-state.md:270 (A.7); part-b-desk.md:73 | HUSKY=0 allowed on first push but push schema has no first-push signal and the push row never mentions HUSKY | part-01-summary-and-process-map.md:71; owner-decisions.md:28 | desk derives first push (remote branch absent) and sets HUSKY=0 only then; say so in B4 |

totals 0/2/2
