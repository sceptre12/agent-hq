# panel7 interfaces 2b, round 2, seat s1 (producer/consumer completeness)

| id | sev | artifact file:line | defect | source | fix |
|---|---|---|---|---|---|
| s1-1 | M | part-d-enums-topics.md:18,72 | `RUN_HOME/review-tailor-<slug>.md` carries `RUNG:`, but `<slug>` is undefined, review-tailor has no slug input, and the file is in no A.1/A.6/D6 path table | part-a-state.md:21-46,232-259 | add an out-path input or define slug; list the file in A.1/A.6/D6 |
| s1-2 | M | part-c-waves-control.md:21 | wave-execution writes `dispatch/<invocation>.jsonl` but neither the invocation counter nor a RUN_HOME/subtask path is a named input | part-d-enums-topics.md:91; part-c-waves-control.md:23 | add `invocation` and a dispatch dir as caller arguments in C1.1 and D2.3 |
| s1-3 | M | part-d-enums-topics.md:101 | ticket-clerk "records its position" in tickets.tsv, which has no cursor column (slug key parent status utc) | part-a-state.md:259 | name a cursor file or row kind |
| s1-4 | M | part-a-state.md:252-253 | `postmerge-<sha>.md` / `release-<sha>.md`: `<sha>` undefined for the pm lead run after the last merge (N merge shas) | part-02-skill-inventory.md:72,74; part-a-state.md:86 | define `<sha>` and record it in pm substate |
| s1-5 | M | part-b-desk.md:87 | `test-report-push` payload file has no named producer; B4 makes release-track requester at stage 6-7 while card 12 puts reporting in post-merge-verify and D2.2 row 12 lists only ci-status-main | part-02-skill-inventory.md:72; part-d-enums-topics.md:80-81 | assign payload writer and stage-6 requester |
| s1-6 | M | part-d-enums-topics.md:73,80 | "failure becomes a new unit and re-enters stage 4" has no carrier: post-merge-verify "new units" has no file/grammar, dispatch-plan inputs include no failure record | part-01-summary-and-process-map.md:81; part-02-skill-inventory.md:72 | define failure-unit carrier and dispatch-plan input |
| s1-7 | L | part-d-enums-topics.md:78 | review record line 3 `Verified-By` appended by pre-pr-gate step 11 into a file pr-review wrote; D2.2 row 10 says pre-pr-gate only consumes it | part-02-skill-inventory.md:68; part-a-state.md:245,257 | list the append under pre-pr-gate outputs; add atomic rule |
| s1-8 | L | part-a-state.md:97,111 | H-pr pointer needs `<owner>/<repo>` but `pr-approval-state` result emits none | part-b-desk.md:112 | add slug field or derive from `url` |
| s1-9 | L | part-a-state.md:143 | `lock_breaks` written to substate.md is not in the A.3 field table | part-a-state.md:122-139 | add the field |

totals B/M/L 0/6/3
