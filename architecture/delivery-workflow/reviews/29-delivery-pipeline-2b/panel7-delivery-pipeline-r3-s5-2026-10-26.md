# Round 3, seat s5: hand-offs to W1 stage skills

| id | sev | artifact file:line | defect | source file:line | fix |
|---|---|---|---|---|---|
| s5-1 | M | skills/delivery-pipeline/references/stages.md:103 | On POSTMERGE: FAIL re-entry the conductor derives the new st<N> ticket key (29-20) but passes it nowhere dispatch-plan reads: the subtasks[] entry has no ticket field and NEW_UNITS lines carry none; delivery-dispatch-plan takes the sub-task `ticket` from tickets.tsv (no row exists for st<N>) with the draft slug standing in (none exists), so the plan's `ticket`/`branch <key>-<slug>` for st<N> is a guess and can differ from the key the post names | skills/delivery-dispatch-plan/SKILL.md:16,30; skills/delivery-dispatch-plan/references/unit-and-waves.md:57; part-a-state.md:74-85 | Conductor writes the chosen key as line 1 note or a `ticket: <key>` line in state.md st<N> entry (proposed field) and dispatch-plan step 13 reads it; or conductor reads the plan's `ticket` and does not derive its own |

totals B/M/L 0/1/0
