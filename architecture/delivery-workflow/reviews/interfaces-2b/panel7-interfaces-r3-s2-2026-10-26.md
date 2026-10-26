id | sev | artifact file:line | defect | source | fix
--- | --- | --- | --- | --- | ---
s2-1 | M | interfaces/part-b-desk.md:100 | merge_reach row absence is `marker` by B5 and B3 step 8 (markers then `marker`) but `gate-missing` in the code table | interfaces/part-b-desk.md:56; INTERFACES.md:68 | state merge_reach is a step-8 gate-missing check; drop it from the B5 marker list
s2-2 | M | interfaces/part-c-waves-control.md:36 | "done token" maps to `output_schema` (C2 record) and to `done_condition.token` (value undefined) in one row | interfaces/part-a-state.md:148 | rename the string key and define its value, keep "done token" for one thing
s2-3 | M | interfaces/part-c-waves-control.md:30 (:31, :90; part-a-state.md:244) | `.tasks/NN-slug.md` keyed NN-slug, other per-unit artifacts keyed by unit id; no unit to file rule; `<slug>` means ticket slug elsewhere | interfaces/part-d-enums-topics.md:134; part-c:29 | freeze `.tasks/<unit>-<slug>.md`
s2-4 | L | interfaces/part-a-state.md:78 | SendMessage identity named `lead_id`, `<identity>`, `<sender-id>` | interfaces/part-c-waves-control.md:118; part-b-desk.md:16 | one name
s2-5 | L | interfaces/part-b-desk.md:11 | "model tier execute" next to "executor tier"/"desk tier" (permission) | interfaces/part-b-desk.md:12; part-a-state.md:173 | say "permission tier" for tiers/*.json
s2-6 | L | interfaces/part-c-waves-control.md:57 | gate-agent `verdict` key has no value set; shares the key with unit and human verdicts | interfaces/part-d-enums-topics.md:50 | list gate verdict values in D2.1
totals 0/3/3
