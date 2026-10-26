| id | sev | artifact file:line | defect | source file:line | fix |
|---|---|---|---|---|---|
| s4-1 | M | SKILL.md step 12/14; references/h1-packet.md:46; review-handoff.md §8 | Item 12 filled (and Low pass edits) after the last review round, yet packet/handoff claim hashes are of files exactly as reviewed; human accepts unreviewed bytes | owner-decisions.md:2 (D1) | Fill item 12 before the final K-check/hash or declare it the one post-review edit |
| s4-2 | M | references/h1-packet.md:18-24,42-46 | Decisions needed has no answer channel; ok text is the only input, effect on recommended option undefined | part-a-state.md:98 | State ok accepts recommended options; other choice = CHANGES |
| s4-3 | M | references/h1-packet.md:42-46 | How-to-answer lacks consequence per verdict and that ACCEPT accepts open round-3 B/M findings | owner-decisions.md:8 (D7) | One consequence line per verdict |
| s4-4 | L | references/step0-inputs.md:48-54 | Re-entry fires on any live H1.changes, no guard against re-running after completed re-entry | part-a-state.md:98 | Compare mtime to record/packet |
| s4-5 | L | references/h1-packet.md:41-45 | <run-id> not defined as RUN_HOME basename | part-a-state.md:7-52 | Define it |
totals 0/3/2
