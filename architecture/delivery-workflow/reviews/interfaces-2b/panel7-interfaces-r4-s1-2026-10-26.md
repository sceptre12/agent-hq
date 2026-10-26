# Panel7 INTERFACES 2b round 4, seat s1 (producer/consumer completeness)

| id | sev | artifact file:line | defect | source | fix |
|---|---|---|---|---|---|
| s1-1 | M | interfaces/part-a-state.md:105-117 | Profile dotted keys (release_tags.*, ci.required_checks[], merge_pipeline.stages[], merge_reach, jira.archive_status) are read by the desk and about 8 skills but the profile's serialization is undefined (unlike state.md, A.2:55) | part-04-templates.md:3, :33 | A.2.2 rule: profile is one YAML document, nested dotted keys, quoted regex values |
| s1-2 | M | interfaces/part-a-state.md:113-117 | release_tags.* has no named writer (intake outputs and 5.8 list omit it) and release-track, the tag-push requester, is not a listed reader | interfaces/part-d-enums-topics.md:74,85; part-04-templates.md:33 | add to intake duties; add release-track as reader |
| s1-3 | M | interfaces/part-b-desk.md:86-87 | step_id (tag-push, publish, H-prod file, A.2.1:99 ref=) has no minter; release-plan template and D2.2 rows 3/13 name no step id | part-04-templates.md:24; interfaces/part-a-state.md:16,99 | delivery-architecture mints step_id in a release-plan step table; release-track v1 keeps it |
| s1-4 | M | interfaces/part-b-desk.md:14,69,92 | Desk-read profile data without key or locator: registered clones, Jira status map; desk state.md reads omit repo_profile (A.2:55); per-repo tag-push profile for a non-primary repo undefined | interfaces/part-a-state.md:50,55,105-115; part-d-enums-topics.md:103 | add clones[] and jira.status_map keys; list repo_profile as desk read; tag-push reads its repo's linked profile |
| s1-5 | M | interfaces/part-a-state.md:97 | H-e2e ref= hashes a batched .feature list "named in test-plan.md for that sub-task" that has no writer or format | part-04-templates.md:21; part-03-personas-and-concurrency.md:59 | lead-written RUN_HOME/<subtask>/gates/e2e-batch.txt, ref = its sha256 |
| s1-6 | M | interfaces/part-d-enums-topics.md:159 | "plan cites an older interfaces version" has no producer: seed keys closed (A.3:137), dispatch-plan header lacks it | interfaces/part-a-state.md:69,137; part-04-templates.md:15 | add interfaces_version to dispatch-plan header and seed; delivery-run Step 0 checks |
| s1-7 | L | interfaces/part-a-state.md:96 | H1.notes.md has no named reader input in delivery-architecture; H1.reject consumer action unstated | interfaces/part-d-enums-topics.md:75 | add input and conductor action |
| s1-8 | L | interfaces/part-c-waves-control.md:149 | INVALIDATE reasons contract-changed/plan-changed have no producing event; "run log" (C5.1:119) undefined; .refused has no reader | interfaces/part-d-enums-topics.md:55; part-a-state.md:85 | name triggers, run-log path, pm-lead handling |
| s1-9 | L | interfaces/part-d-enums-topics.md:84 | new_units vs NEW_UNITS for one input | interfaces/part-d-enums-topics.md:77 | use NEW_UNITS |

totals B/M/L 0/6/3
