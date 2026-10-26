| id | sev | artifact file:line | defect | source file:line | fix |
|---|---|---|---|---|---|
| s5-1 | M | skills/delivery-desk/SKILL.md:158-160; references/verbs.md:175-179 | tag-push refusal list omits `release_tags.used` absent or not "yes"/"no" when an entry exists; operator may proceed on pattern match alone | part-a-state.md:136; INTERFACES.md:47 | refuse `policy` unless `used` is exactly "yes"; detail names `release_tags.used` |
| s5-2 | L | skills/delivery-desk/SKILL.md:155-156 | "GATE-PASS record still gates every push" follows a list naming branch-delete and tag-push, which have no expect_head/gate-runs record | part-b-desk.md:108 (B5); part-a-state.md:343 | say it gates push, pr-create (and pr-merge) only |
| s5-3 | L | skills/delivery-desk/references/verbs.md:48-51 | first/later evidence reads lead-written substate.md and accepts any line of ci/<pr>.md containing the sha; not stated as requester-host-written | part-b-desk.md:83; part-d-enums-topics.md:25; part-a-state.md:174,184 | match line 1 `CI: GREEN <expect_head>`; note anchor is the desk-checked gate-runs record |

totals 0/1/2
