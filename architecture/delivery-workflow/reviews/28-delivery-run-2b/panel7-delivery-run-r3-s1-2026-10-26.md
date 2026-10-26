# delivery-run R3 seat s1 (cold lead walkthrough)

id | sev | artifact file:line | defect | source file:line | fix
---|---|---|---|---|---
s1-1 | M | skills/delivery-run/SKILL.md:247; references/handoffs-and-modes.md:62 | `pr-create` requires `labels[]` but no step or reference names where the lead reads its values (nor says empty is allowed); a cold lead must guess | skills/delivery-desk/references/schemas.json:98,104 (labels required array); verbs.md:61,67 (`--label=<each>`) | Name the source (a profile key or the dispatch-plan) or fix a convention: `labels: []` unless the profile names PR labels
s1-2 | M | references/handoffs-and-modes.md:82 | The CI `d7-round3` mapping requires "a round-3 `verify-*` that is not CLEAN", but ci-fix-loop writes no `verify-*` file anywhere; only "open findings below line 1" exists, so the conjunction is never true and a CI round-3 stop is classed `human`, not `d7-round3` (or is confused with pre-pr-gate `review/<subtask>/verify-*-3.md` left from the earlier gate) | skills/ci-fix-loop/SKILL.md:33 (step 9 writes `CI: HUMAN <class>` with open findings below line 1; no verify file) | Key the mapping on the ci-fix-loop evidence only (open findings below line 1 of `ci/<pr>.md` after fix-verifier round 3), drop the `verify-*` clause
s1-3 | L | skills/delivery-run/SKILL.md:269; references/ledger.md:77 | At `phase: done` the lead never sets its machine row `build=0`/`live_count` low; "never deletes its row" and the reaper only reaps dead pids, so a finished `agent-tool` lead whose session stays alive keeps counting toward rule 8 (3 builds) and the 200 sum | interfaces/part-a-state.md:230 (machine row) | At CLEANUP DONE rewrite the row with `build=0` and the real `live_count`

totals 0/2/1
