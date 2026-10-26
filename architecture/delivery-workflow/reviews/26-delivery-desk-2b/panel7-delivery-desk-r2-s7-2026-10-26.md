# panel7 delivery-desk r2 s7 (cold implementer / desk operator)

| id | sev | artifact file:line | defect | source file:line | fix |
|---|---|---|---|---|---|
| s7-1 | L | skills/delivery-desk/SKILL.md:40-42; references/checks.md:13 | Registry mirror file format and the unreadable/corrupt-mirror case on restart are unspecified | interfaces/part-b-desk.md:16 | State the line format and that an unreadable mirror means the run is unknown until re-claimed |
| s7-2 | L | SKILL.md:65-68,112-121; checks.md:119-121 | Crash resume: after an empty read-back, whether to continue at step 6 with checks 6-8 re-run, the mkdir-exists case and an empty `target` (crash between mkdir and write) are not stated | interfaces/part-b-desk.md:47 | Say: resume at step 6, reuse the inflight dir, rewrite an empty target |
| s7-3 | L | SKILL.md:69-70 | Step 6 (copy) names no failure code; `schema` for a missing .req is only in checks.md:28 | interfaces/part-b-desk.md:73 | Add "missing .req: REJECTED schema, request_sha256 null" to step 6 |
| s7-4 | L | SKILL.md:99-100 | "Atlassian session answers" has no probe; "Zephyr verbs" is not a verb name (test-report-push) | interfaces/part-b-desk.md:73 (7) | Name the probe or mark it measured at the move |
| s7-5 | L | SKILL.md:1-265 (22,509 bytes, 3,301 words) | Body est. 5.6k-6.5k tokens, over the 5,000-token target; spec word proxy (3,800) met | tools/skill-authoring.md:66, :92 | Move reason-code table and Fixed-rules prose to references/ |
| s7-6 | L | SKILL.md:259,263 | Provenance cites SCRATCH/ paths not in the repo or in source-keys.md | tasks/26-delivery-desk.md:81 | Cite resolvable paths or add SCRATCH keys |
| s7-7 | L | references/checks.md:30; schemas.json reason_codes.schema | Leading-dash list says "ref, tag or package"; SKILL.md:81 and verbs.md:13-14 add base and merged_into | SKILL.md:81 | Make the lists identical |
| s7-8 | L | SKILL.md:125 | "except sender" reads as an envelope-field exception; it means reason `sender` (no .out) | interfaces/part-b-desk.md:73 (10) | Write "except reason sender (step 4)" |

Anatomy and spec §8: frontmatter, Trigger, Steps, Red flags (all 7 required items present), Exit criteria, Provenance present; 20 verbs, 10 codes, step order and codes consistent across the six files; description 618 chars.

totals B/M/L 0/0/8
