CLEAN 0/0/1

Round 2 fix verification, delivery-pipeline (W2 item 29), diff against WIP 103cb53. Checks: (1) every B/M row closed at the cited place; (2) no contradiction, R2-15 still OWNER; (3) no regression, SKILL.md 3783 words (<= 3800), step and 29-N references resolve; (4) scope: 7 modified files under skills/delivery-pipeline/ (SKILL.md, launcher, provenance, resume, stages, stops-and-posts, tick-relay), no new files, templates untouched; (5) `bash SCRATCH/s9-29.sh` last line PIPELINE-29-OK, no failure words.

Closed: R2-01 (RELEASE recorded only by a `release` file newer than the receiver's latest `invalidate`; MERGED by file naming the current sha; SKILL.md:22, tick-relay:106-109), R2-02, R2-03 (pending 31 / build=1 count only live pending launches, own sub-task excluded; launcher:26-27, SKILL.md:19), R2-04..R2-14, R2-16..R2-21, V1B-01 (run REGISTER-SENDER claim and re-send exempt from the gate in tick-relay:9, SKILL.md:15/22/R4, resume:18/20; lead REGISTER-SENDERs stay gated). R2-15 stayed OWNER: post names the row and the open decision, no GATE line is emitted, listed under owner questions.

| id | sev | file:line | issue | source | fix |
|---|---|---|---|---|---|
| V2-01 | L | references/templates/state-and-substate.md:51 | The state template carries `released_utc` only; the new `launched_utc` and `reentered_utc` keys (29-25, 29-26) are not in it. They are marked proposed, and templates are outside the fixer's scope. | provenance.md:60-61 | Add the two keys to the state template when INTERFACES ratifies 29-25/29-26 (integrator step). |
