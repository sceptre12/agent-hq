id | sev | artifact file:line | defect | source | fix
s5-1 | L | part-b-desk.md:86; part-a-state.md:290 | tag-push row and A.7 silent on whether tag-push (a desk git push) carries HUSKY=0 and needs the per-push gate-runs pass | owner-decisions.md:80 | state it explicitly
s5-2 | L | part-a-state.md:113-115 | release_tags.* readers omit release-track, which must know used/approval and the tag/step_id source | part-d:85; part-b:86 | add reader, say where tag and step_id come from
s5-3 | L | part-a-state.md:114-117 | used=yes with missing pattern/approval has no defined code | part-b-desk.md:54 | make it REJECTED policy
totals 0/0/3
