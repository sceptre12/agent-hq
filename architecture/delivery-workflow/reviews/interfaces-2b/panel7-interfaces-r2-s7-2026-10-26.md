| id | sev | artifact file:line | defect | source | fix |
|---|---|---|---|---|---|
| s7-1 | B | interfaces/part-a-state.md:13,15 | run-id/plans_dir minted at stage 1 from the epic key, which exists only after H1 | part-01-summary-and-process-map.md:67; part-b-desk.md:89 | provisional run-id plus rename rule |
| s7-2 | M | interfaces/part-b-desk.md:15,43; part-a-state.md:127 | non-lead reserved agents (clerk, ci, cleanup executor) have no registered sender identity | part-a-state.md:127; part-b-desk.md:79,89 | state who sends their DESK lines |
| s7-3 | M | interfaces/part-b-desk.md:18,77,89 | no `<subtask>` token rule for conductor non-conductor-only verbs and stage-2 clerk verbs | part-b-desk.md:47 | add requester-to-token column |
| s7-4 | M | interfaces/part-a-state.md:259; part-d-enums-topics.md:100-101 | clerk log position has no field; unit-to-ticket map for TICKET-EVENT undefined | part-d-enums-topics.md:101 | add field and source |
| s7-5 | M | interfaces/part-a-state.md:36,139; part-d-enums-topics.md:24-25; part-b-desk.md:83 | pm records keyed by one sha though many merge shas; conductor cannot locate them | part-a-state.md:84 | define sha and add path fields |
| s7-6 | M | interfaces/part-c-waves-control.md:116,126 | no conductor-to-lead merged notice; cleanup trigger undefined | part-d-enums-topics.md:77 | merged inbox type or poll rule |
| s7-7 | M | interfaces/part-a-state.md:137 vs part-d-enums-topics.md:21 | integrated entries per merged unit vs single Integrator C2 record | part-c-waves-control.md:60 | define entry source |
| s7-8 | M | INTERFACES.md:33 | catalog.sh has no run-id/RUN_HOME input; inherited columns unstated | part-a-state.md:12,35,210 | add run-id arg |
| s7-9 | M | interfaces/part-a-state.md:253,255; part-b-desk.md:72 | no commit/push path for post-st0 repo artifacts | part-b-desk.md:72-73 | define path |
| s7-10 | M | interfaces/part-a-state.md:86; part-d-enums-topics.md:74 | pm (and st0) have no seed/waves/bus; delivery-run mode unstated | part-a-state.md:241 | state pm/st0 modes |
| s7-11 | L | interfaces/part-a-state.md:96 | H-e2e ref depends on ungrammared test-plan.md list | part-04-templates.md:21 | name the line |
| s7-12 | L | interfaces/part-b-desk.md:21,62 | REJECTED sender writes no .out; claude -p lead polls and resends | part-c-waves-control.md:118 | wait for registration |

totals B/M/L 1/9/2
