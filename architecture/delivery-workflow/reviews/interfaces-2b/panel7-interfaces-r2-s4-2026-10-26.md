# panel7 interfaces 2b, round 2, seat s4 (design and owner-ruling fidelity), 2026-10-26

| id | sev | artifact file:line | defect | source | fix |
|---|---|---|---|---|---|
| s4-1 | M | interfaces/part-d-enums-topics.md:20; part-a-state.md:131 | D7 round-3 stop must hand open B/M findings to the owner; no file, path or token carries them (record-<head>.md exists only for PASS; PREPR STOP lists row ids only) | owner-decisions.md:8; part-02:68 card 10 step 9; part-01:70 | name an open-findings artifact and a d7-round3 token |
| s4-2 | M | interfaces/part-a-state.md:265, :272-275 | HUSKY=0 licensed on commit and every push; D21 allows it only on PR creation/first push; R2-3 changes cadence only | owner-decisions.md:28, :37 | restrict to D21 wording or ask the owner |
| s4-3 | M | interfaces/part-a-state.md:219 | local branch delete unconditional; only remote gated on content-merged | owner-decisions.md:18 (D8); part-01:74 | gate local and remote delete on content-merged |
| s4-4 | M | interfaces/part-b-desk.md:99, :115 | git cherry per-commit patch-id never matches a squash of 2+ commits; D8 requires a squash content check | owner-decisions.md:18; part-02:66 card 9 | add squash patch-id/tree check and merged_check value |
| s4-5 | L | interfaces/part-b-desk.md:85, :55 | tag-push has no human gate; publish does; D15 | owner-decisions.md:15; part-02:74 card 13 | require H-prod.<step_id>.ok or state tags never deploy |
| s4-6 | L | interfaces/part-a-state.md:245; part-b-desk.md:81-82, :86-87 | renames/additions vs design (review-<head>.md, run_id, publish/test-report-push fields) logged DEF but not in errata | part-01:70; part-05:43 | add errata rows |
| s4-7 | L | interfaces/part-d-enums-topics.md:40 vs part-b-desk.md:144, part-a-state.md:95 | H1 verdict ACCEPT vs ok | owner-decisions.md:55; part-01:67 | state mapping once |
| s4-8 | L | interfaces/part-a-state.md:272; part-b-desk.md:99 | repo-profile facts copied, not linked | owner-decisions.md:13 (D22) | link to profile@sha |
| s4-9 | L | interfaces/part-c-waves-control.md:23 | "delivery-run starts the pm2 app (C5.3 step 4)" but step 4 is resume re-check; initial start has no step | owner-decisions.md:59; part-c:137; part-02:62 | cite a start step |

totals 0/4/5
