# panel7 interfaces 2b, round 2, seat s5 (consistency with accepted ADRs 0054, 0055)

| id | sev | artifact file:line | defect | source | fix |
|---|---|---|---|---|---|
| s5-1 | M | part-b-desk.md:73,99 (B4 pr-create; B5, FRZ-g) | pr-create carries required record_path but B5 re-derives the review record only for pr-merge | decisions/0055:167-171 | add record check to pr-create in B5/FRZ-g or drop the field |
| s5-2 | M | part-c-waves-control.md:97 (C4) | lead relay of .verdict not stated as posted under the dispatching agent's id; no-post = gate failure / stalled-dispatch exception omitted | decisions/0054:158-162, :150-157 | post under recorded agent_id; state no-post rule |
| s5-3 | M | part-c-waves-control.md:23 (C1.1 lane lease); part-a-state.md:161 | lead cannot lease a lane per work_item before dispatch; wave-execution dispatches frontier items itself, serializing only by lane name | decisions/0054:69-73, :97-99 | define the hook (lease before invoking, per lane name for the invocation) |
| s5-4 | L | part-c-waves-control.md:46 (rule 14) | any per-wave output_topic must be literal; ADR allows the placeholder form when no bundle value is declared | decisions/0054:168-170 | limit literal rule to bundle value / declared case |
| s5-5 | L | part-c-waves-control.md:47 (rule 15) | omits "a wave that declares edges enumerates its work_items" | decisions/0054:171-172 | add clause |
| s5-6 | L | part-a-state.md:179; part-c C1.1:19 | free-slot formula can be 0 or negative; max_concurrent is integer >=1 | decisions/0054:54-55 | lead waits until >=1 |
| s5-7 | L | part-b-desk.md:37,58 (B2, B3 step 10) | no .out for a sender reject; ADR stores every REJECTED as .out and makes .out authoritative for claude -p | decisions/0055:104-108,189 | write .out for all, or define lead behaviour on no .out |
| s5-8 | L | part-b-desk.md:48-55 (B2.1) | "a corrected request is a new request" contradicts terminal = never resent; redaction/path rejects classed terminal | decisions/0055:117-122 | align with OP5 or reclassify |
| s5-9 | L | part-c-waves-control.md:23 (C1.1 bus_endpoint) | end_session under attach has no named owner | decisions/0054:193-196 | name delivery-run |

Checked and consistent: all 20 verbs; ten reason codes and layout; DONE long form; id form and run token; sender registry and REGISTER-SENDER (FRZ-a); relay and JSON-subtask cross-check (FRZ-e); bus_endpoint attach, preflight, step 5, skip step 8 cleanup; max_concurrent as argument counting gate and fix agents; done_condition required under step_complete (rule 9); same-wave edges; checkpoint sole resume authority; bundle output_topic override; FRZ-a to FRZ-i present.

totals 0/3/6
