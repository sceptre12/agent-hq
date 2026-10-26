# delivery-run r3 seat s7 (bus/ports, rulings, CV1-CV43)

| id | sev | artifact file:line | defect | source file:line | fix |
|---|---|---|---|---|---|
| s7-1 | L | references/bus-and-ports.md:11,47 | data_dir shown with trailing slash; step 5 `catalog.sh start bus <data_dir>` differs from the handle registered at step 2 (no slash); exact match fails | tools/delivery/catalog.sh:169-172,201-207 | one spelling without trailing slash everywhere |
| s7-2 | L | references/bus-and-ports.md:21-25 | crash between claim and register leaves no catalog row; step 1 re-claim exits 1, retry uses candidate+10 and orphans the candidate claim | tools/port-check.sh:201-215; part-a A.5.2 | step 0 also checks the registry for an active claim by source `<run-id>-<subtask>` and reuses it |
| s7-3 | L | references/bus-and-ports.md:40 | "from the bus repo" names no path | skills/swarm-communication/SKILL.md:80-84 | name the default bus repo path |
| s7-4 | L | references/handoffs-and-modes.md:161 | OBJECTION CV33: ancestor-only check accepts a record trailing unrecorded commits | part-c-waves-control.md:83 | owner decides; or compare to HEAD captured at dispatch return |

totals B/M/L 0/0/4
