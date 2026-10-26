# panel7 delivery-pipeline r2 s3 (stops reach the owner as packets)

id | sev | artifact file:line | defect | source file:line | fix
---|---|---|---|---|---
s3-1 | M | SKILL.md:27; references/tick-relay.md:73-74; references/stops-and-posts.md:23-31,64 | ROLLED-BACK and POSTMERGE: FAIL have no tick detection row, post line or stops-table row; the owner hears of a rolled-back release only in the final post after cleanup and capture | skills/release-track/SKILL.md:36-37 | tick row and stops row: post LIVE/ROLLED-BACK/FAIL with record and rollback evidence paths on the finding tick
s3-2 | M | SKILL.md:29 (14.3); references/stages.md:109,56 | final cleanup (and H1.reject cleanup) run until CLEANUP DONE final with no stop path; SPOT-CHECK FAIL leaves no final file and a C2 ESCALATE to the approver, who is the conductor | skills/delivery-cleanup/SKILL.md:21 | post a human step with the .tmp path after one run, do not advance, no auto re-run
s3-3 | M | references/tick-relay.md:80; references/stops-and-posts.md:37; SKILL.md step 9i | unblocked and once-only blocked keyed on "previous post listed it" (session memory); lost on resume, ticket stays Blocked | interfaces/part-d-enums-topics.md:108 | derive from tickets.tsv latest status plus open escalations/stops/INVALIDATE at resume and each tick
s3-4 | L | references/tick-relay.md:64-67; stops-and-posts.md:25 | no crash dedupe for blocked/dispatched/prepr-pass: state.md written, event lost | interfaces/part-d-enums-topics.md:109 | append event before state write or dedupe against ticket-events.log
s3-5 | L | SKILL.md step 4; tick-relay.md:20; stops-and-posts.md:43 | stage 2 round-3 not detectable from ARCH: ready; tick 4c skips the 29-23 check that step 5 and resume.md:32 apply | skills/delivery-architecture/SKILL.md:29-30,62; stages.md:65 | name open-findings section in the H1 post; apply 29-23 on the tick
s3-6 | L | SKILL.md step 4 (H1.reject), step 2 | stage: stopped written before final cleanup; resume does not resume stopped runs | skills/delivery-cleanup/SKILL.md:13 | resume re-runs final cleanup if no CLEANUP DONE final
s3-7 | L | SKILL.md step 3 end | "wait for H0.ok ... post" contradicts R3 | stops-and-posts.md:57 | post with GATE line, end turn, record on the tick
s3-8 | L | tick-relay.md:39 vs stops-and-posts.md:64 | relayed-line REJECTED both "advisory" and "posted" | tick-relay.md:56 | pick one
totals 0/3/5
