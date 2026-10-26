# panel7 interfaces r3 s5 (consistency with accepted ADRs 0054, 0055)

| id | sev | artifact file:line | defect | source | fix |
|---|---|---|---|---|---|
| s5-1 | M | interfaces/part-c-waves-control.md:20 | dispatch_budget formula is the frontier term only; barrier waves 00/02 keep the 0023 term, bundle sum undefined | decisions/0054:118-122; spec-format.md:120-128 | define as rule 11 sum over waves with both terms |
| s5-2 | L | part-c:19 | free-slot formula can yield <1, ADR requires integer >=1; no lead rule | decisions/0054 A1 | lead invokes only with >=1 free |
| s5-3 | L | part-c:47 | rule 15 omits "edges => enumerate work_items" | decisions/0054 A8 r15 | add clause |
| s5-4 | L | part-c:23 | start of pm2 app attributed to C5.3 step 4 (resume step) | interfaces/part-a-state.md:148 | cite part A for start |
| s5-5 | L | part-c:97 | C4 relay accepts ids from any dispatch file; C2/A7 count current invocation only | decisions/0054 A7 | restrict to current invocation |
| s5-6 | L | part-c:23 | bus.endpoint session_id/topic equality check has no rule/failure code; ADR A9 says no new preflight rule | decisions/0054 A9 | fold into identity preflight with VALIDATION_FAILED |
| s5-7 | L | part-b-desk.md:74 | pr-create does not re-verify record content; ADR says record_path re-verified before acting on both verbs | decisions/0055:167 | state deferral or verify at pr-create |
| s5-8 | L | part-b-desk.md:96 | "every file named by a path field is redaction-scanned" vs OP9 unscanned images | decisions/0055 OP9 A | add exception |

totals B/M/L 0/1/7
