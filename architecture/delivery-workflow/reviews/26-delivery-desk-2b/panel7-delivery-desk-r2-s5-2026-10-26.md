| id | sev | artifact file:line | defect | source file:line | fix |
|---|---|---|---|---|---|
| s5-1 | L | skills/delivery-desk/SKILL.md:172-176 (also :247, references/verbs.md:36-37) | Restates the HUSKY=0 form (inline, never exported, never --no-verify) though A.7 says it is the single statement and others only link | interfaces/part-a-state.md:327 | Keep the link and the GATE-PASS gate only |
| s5-2 | L | skills/delivery-desk/SKILL.md:172-173,247 vs references/verbs.md:96,150 | N10 scope in SKILL.md is push and pr-create; verbs.md also puts HUSKY=0 on branch-delete (push --delete) and tag-push | interfaces/part-a-state.md:327 ("every desk push"); part-b-desk.md:83-84 | State one scope in both files |
| s5-3 | L | skills/delivery-desk/SKILL.md:87; references/checks.md:53 | record_path root is `review/<subtask>/` with no note that for pr-merge (id subtask `run`) it is fields.subtask | part-b-desk.md:88 (pr-merge row); tools/delivery/desk-req-schema.sh dr_paths | Add "pr-merge: <subtask> = fields.subtask" |
| s5-4 | L | skills/delivery-desk/references/source-keys.md:1-35 | Claims every bare id resolves, but C5.1, C5.3, AM-2, R2-7, R1-6, R1-7 have no row; Q2 row is the task-spec RESOLVED Q2, not owner Q2 (bus_endpoint) | architecture/delivery-workflow-sources/owner-decisions.md:59 | Add rows; label Q2 as task-spec |

totals B/M/L 0/0/4
