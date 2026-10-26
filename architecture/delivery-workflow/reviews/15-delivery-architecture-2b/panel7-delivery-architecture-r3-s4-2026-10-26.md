# Panel7 r3 s4 (H1 gate and packet), arch15-r3-s4

id | sev | artifact file:line | defect | source file:line | fix
---|---|---|---|---|---
s4-1 | L | references/step0-inputs.md:45 | Notes are numbered 1..k "in file order", but H1.notes.md is written from the single typed GATE line; how one line splits into notes is unstated | interfaces/part-b-desk.md:157,162 | State the split rule (single-line text is note 1, else one note per line)
s4-2 | L | SKILL.md:15 vs references/step0-inputs.md:43-44 | SKILL says run Re-entry (renames) "first"; step0-inputs says before step 1; a rename before an INPUT-ERROR stop would break "nothing written" | interfaces/part-d-enums-topics.md:6-11 | Say the rename runs after Step 0 passes
s4-3 | L | references/step0-inputs.md:46 | Re-entry deletes drafts of removed nodes but is silent on contracts/ files the notes orphan; they stay in ARTIFACTS and the packet table | interfaces/part-a-state.md:287-328 | Add one sentence for removed contracts

totals B/M/L 0/0/3
