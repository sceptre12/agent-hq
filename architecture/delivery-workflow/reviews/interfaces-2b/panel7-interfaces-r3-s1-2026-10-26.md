# panel7 interfaces 2b, round 3, seat s1 (producer/consumer completeness)

| id | sev | artifact file:line | defect | source | fix |
|---|---|---|---|---|---|
| s1-1 | M | part-a-state.md:246; part-d-enums-topics.md:13,18,72 | review-tailor RUNG file has two writers (A.6 caller; D1.1/D2.2 the skill) and the no-file stdout rule contradicts "line 1" | part-d:18 vs part-a:246 | review-tailor writes the file itself; drop stdout fallback for it |
| s1-2 | M | part-a-state.md:140; part-c-waves-control.md:57-66 | Integrator C2 record (unit = merged unit) is indistinguishable from the worker PASS for that unit; lead's worktree-HEAD check cannot apply | part-c:29, :74 | own Integrator work_item id plus a way to carry the merged unit, or a discriminator |
| s1-3 | M | part-a-state.md:264; part-d-enums-topics.md:101; part-b-desk.md:18 | ticket-clerk runs in conductor and every lead; one cursor and one tickets.tsv, event line has no subtask, no lock | part-02-skill-inventory.md:76 | name the single event-processing session or add subtask, per-clerk cursor, append lock |
| s1-4 | M | part-a-state.md:253; part-b-desk.md:100,80 | merge-<sha>.md has no content grammar; desk squash check reads it; branch-delete has no pr/merge_sha; D6 readers omit desk | part-d:140 | freeze file lines and add pr or merge_sha to branch-delete |
| s1-5 | M | part-b-desk.md:79,122; part-d-enums-topics.md:99; part-a-state.md:175 | repo-profile keys merge_method, archive status, merge-pipeline stage list, durations are consumed but never named as keys | part-04-templates.md:33 | freeze a profile key list for fields INTERFACES reads |
| s1-6 | M | part-c-waves-control.md:33 | `Brief: references/briefs/<persona>.md` written by dispatch-plan, copied by delivery-run; no root or persona-to-skill map | part-06-build-plan-and-sources.md:27 | freeze root or a map |
| s1-7 | M | part-b-desk.md:90,63,108 | epic jira-create has no parent but closed schema rejects missing fields; request optionality undefined | part-b:49 | parent omitted only for Epic; add required column |
| s1-8 | L | part-a-state.md:250,186; part-d-enums-topics.md:93 | fix file has no grammar (fix-verifier file_set producer); machine row has no shared script for two writer skills; capture/ has no reader | part-d:93 | name file_set line; one owner for machine rows |

totals 0/7/1
