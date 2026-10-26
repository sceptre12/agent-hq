# Panel 7 r1 seat s2 (INTERFACES exactness), delivery-architecture, 2026-10-26

| id | sev | artifact file:line | defect | source file:line | fix |
|---|---|---|---|---|---|
| s2-1 | B | SKILL.md:26; references/review-handoff.md:7-16 | review-tailor call omits required ORCHESTRATOR_TIER; review-tailor Step 0 stops with INPUT-ERROR ORCHESTRATOR_TIER missing | interfaces/part-d-enums-topics.md:78; part-a-state.md:59; skills/review-tailor/references/step0-inputs.md:18 | add ORCHESTRATOR_TIER = state.md orchestrator_tier to the call |
| s2-2 | M | references/security-sensitive.md:3,17,31; SKILL.md:21 | criterion still "plan-check default, pending OQ-1, not an owner ruling"; adds items beyond the ruled list | architecture/delivery-workflow-sources/owner-decisions.md:88; interfaces/part-a-state.md:71 | restate as the OQ-1 ruling with the A.2:71 list |
| s2-3 | M | references/step0-inputs.md:21; decomposer-brief.md:7; tree-rules.md:10 | FILL_IN_BEFORE_DISPATCH accepted for durations.unit_median_min; A.2.2 says int and sentinel only for ports | interfaces/part-a-state.md:129,111,135 | non-int is INPUT-ERROR ... format; drop sentinel or amend INTERFACES |
| s2-4 | M | SKILL.md:26; references/review-handoff.md:16; security-sensitive.md:35 | "conductor/operator says full" has no input channel | interfaces/part-d-enums-topics.md:63,77; part-a-state.md:71 | read RUN_HOME/state.md security_audit and pass it |
| s2-5 | L | SKILL.md:68 vs 8 reference files line 3 (and security-sensitive.md:15) | Provenance 1.3.0 vs references cite INTERFACES 1.1.0 | INTERFACES.md:3 | replace with 1.3.0 |
| s2-6 | L | references/step0-inputs.md:20 | e2e.harness treated as A.2.2 profile key; A.2.2 lists none | interfaces/part-a-state.md:109-135; part-d-enums-topics.md:49 | mark as skill-local read per design 5.8 |
| s2-7 | L | SKILL.md:15, :29 | on H1.changes re-entry old review-architecture.md with ARCH: ready stays until step 14 | interfaces/part-d-enums-topics.md:12; part-a-state.md:98 | move old record aside at re-entry |
| s2-8 | L | SKILL.md:20 | item 3 port fields omit container_port needed by the claim | interfaces/part-a-state.md:277 | add container_port |

Anchors checked and resolving: Provenance A.1 :7-52, A.2 :53-90, A.2.1 :91-104, A.2.2 :105-153, A.5.2 :275-278, A.5.3 :279-282, A.6 :283-324, B8 :152, D1 :6-11, D1.1 :12-31, D2.1 :34-68, D2.2 rows 3-4 :77-78, D6 :133-161. Token regexes (ARCH, DRAFTS, RUNG), INPUT-ERROR forms, GATE line, draft front matter, SLUG form and step_id regex match.

totals B/M/L 1/3/4
