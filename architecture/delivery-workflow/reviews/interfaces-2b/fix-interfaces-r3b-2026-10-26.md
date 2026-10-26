# Fix record r3b (narrow fix after verify-fix-interfaces-r3 and preround-interfaces-r3c), 2026-10-26

Scope: V3-1..V3-4 from `verify-fix-interfaces-r3-2026-10-26.md`; C1, C2, C5 (part-c:20, N10, N11) from `preround-interfaces-r3c-2026-10-26.md`. Freeze-status line untouched. No git commands run.

V3-1 FIXED INTERFACES.md:125 slot-row unit regex now `^([ui][0-9]+\|-)$`, matching part-a-state.md:185.
V3-2 FIXED interfaces/part-a-state.md:219 catalog column 9 now `^([ui][0-9]+\|-)$` (unit id, Integrator `i<N>`, or `-`), DEFAULT (integrator); part-a-state.md:16 H2 list adds "catalog row"; INTERFACES.md:37 `catalog.sh register` `<unit\|->` given the same regex; DEF row INTERFACES.md:164.
V3-3 FIXED interfaces/part-d-enums-topics.md:69 input-transport rule names `resource-catalog` (row 8, part-d:80) as the one exception whose `RUN_HOME` is env, because `catalog.sh` requires it (INTERFACES.md:37); DEF row INTERFACES.md:165.
V3-4 FIXED interfaces/part-d-enums-topics.md:73,74 new input `PRIMARY_REPO` (path) on `delivery-pipeline` (required with `INTENT`) and `delivery-intake`; part-a-state.md:50 primary repo named by the human at stage 1, recorded as `primary_repo` before `plans_dir` is created, `architecture.md` §3 restates it; part-a-state.md:62 field source; DEFAULT (integrator); DEF row INTERFACES.md:163.
C1 FIXED INTERFACES.md:27 ADR 0055 cite `:257-271` -> `:259-273` (section heading :259 to OP10 :273, opened and matched).
C2 FIXED interfaces/part-c-waves-control.md:52 D55 -> `owner-decisions.md:7` (D6 adoption) and `part-03-personas-and-concurrency.md:35`; M17 -> `changelog.md:199`; ADR 0023 rule 12 -> `decisions/0023-wave-execution-workflow-grafts.md:137-138`; D7 -> `owner-decisions.md:8`. All opened and matched.
C5 FIXED interfaces/part-c-waves-control.md:20 rule-11 restatement and lead-side exclusion tagged `DEFAULT (integrator)`.
C5 FIXED INTERFACES.md:29 (N10) "Recommended answer (proposed, owner to decide): ..."; note stays open and undecided.
C5 FIXED INTERFACES.md:31 (N11) "Recommended answer (proposed, owner to decide): ..."; note stays open and undecided.

Doc-length: `bash tools/check-doc-length.sh <W>`: 0 blocking files over 500 lines; 2 informational over 40000 bytes (changelog.md, interfaces/part-a-state.md 43203 bytes / 300 lines), non-blocking.
