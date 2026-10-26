# Panel 7 INTERFACES 2b, round 4, seat s2 (one name per thing)

| id | sev | artifact file:line | defect | source | fix |
|---|---|---|---|---|---|
| s2-1 | M | interfaces/part-a-state.md:16,99; part-b-desk.md:86,87,160 | `step_id` keys `H-prod.<step_id>.ok`, `GATE H-prod.<step_id>`, `publish`/`tag-push` fields and `bodies/test-report-<step_id>.json`, but no file says where a step_id is minted or recorded; release-plan.md (A.6:259,274) has no step_id field | design part-04-templates.md:24 | A.6: release-plan carries one step_id per step (minted by delivery-architecture, kept by release-track) with its regex |
| s2-2 | M | interfaces/part-a-state.md:103-117,:50,:63; part-b-desk.md:86 | dotted profile keys (`release_tags.*` etc.) have no serialization in repo-profile.md and no producer row; tag-push is per repo but state.md holds one `repo_profile`, so the desk cannot resolve a non-primary repo's profile; `yes/no` reads as YAML boolean | owner-decisions.md:81-84; part-04-templates.md:33 | state key syntax and writer (delivery-intake) in A.2.2; say how the desk finds the profile for a given `repo` |
| s2-3 | L | interfaces/part-d-enums-topics.md:84 vs :77 | `new_units` vs `NEW_UNITS` for one input | part-d:69 | use `NEW_UNITS` |
| s2-4 | L | interfaces/part-a-state.md:227,238 vs part-b-desk.md:80 | content-merge target is `base` in the catalog branch handle, `merged_into` in branch-delete | part-b-desk.md:80 | name it `merged_into` in A.5 |
| s2-5 | L | interfaces/part-d-enums-topics.md:26 vs part-c-waves-control.md:145 | `RELEASE` is both the release-record token and the inbox message, both met by the pm lead | part-a-state.md:87 | rename the token or declare the colon form the only token |
| s2-6 | L | interfaces/part-d-enums-topics.md:96,97 | EXTEND inputs mix case (`ROLES`, `PR_REVIEW_MODE` vs `record_path`; `UNIT_MODE` vs `file_set`); the UPPER_SNAKE rule covers only NEW skills | part-d:69 | extend the rule to D2.3 |
| s2-7 | L | interfaces/part-c-waves-control.md:90 vs :11, part-a-state.md:294 | status file is one overwritten NEXT line yet also receives gate-runner output and Explorer rows | part-a-state.md:294 | name a second file for bodies |

Note: one stray test message "x" was posted to topic findings-r4-s2 by mistake; ignore it.

totals B/M/L 0/2/5
