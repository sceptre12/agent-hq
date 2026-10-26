# Seat s5 (regression sweep), round 3, arch15-r3-s5

Swept the full diff since snap-r0 (SKILL.md and 10 reference files plus new fixture state.md). Checked: INTERFACES 1.4.0 cites (A.2 :59/:71, A.2.1 :98-104, A.2.2 :132-136, D3 :110, D2.2 :78, B4 :100, AM-3 :25) all resolve; security_sensitive list matches OQ-1 (owner-decisions.md:89) with skill-default mappings labelled; SECURITY_AUDIT/ORCHESTRATOR_TIER are read from state.md in SKILL step 0, step 10, review-handoff section 1, step0-inputs rows 9-10 and the fixture stub, consistently; port naming agrees across SKILL step 5/checklist, contracts.md, tree-rules K14/K15 and A.5.2 (architect claims nothing); step numbering (0-15, 5a) and the references to steps 8/10/12/13/14 agree; no stale 1.1.0 / "pending OQ-1" strings remain.

| id | sev | artifact file:line | defect | source file:line | fix |
|---|---|---|---|---|---|
| s5-1 | L | references/fixtures/expected.md:9 | Says item 3 names port 4300 of admin-ui (127.0.0.1); new rule puts only `port <port> <service>` in item 3 and the bind in the owning contract file | SKILL.md:20; references/contracts.md:12 | Reword the row to match the sub-table form |
| s5-2 | L | SKILL.md:30 (step 12) | "Not fixed outside a review round" vs review-handoff.md section 4 "fails are fixed before any seat reads" after every fix, which covers the Low-pass fix | references/review-handoff.md section 4 | Exempt the post-Low-pass re-run from the fix clause |
| s5-3 | L | SKILL.md:25 (step 8) | Re-sync trigger lists steps 4-7 but not step 9 fixes to contracts, leaving pins stale until the pre-round slot | references/contracts.md:28 | Add step 9 to the trigger |

totals 0/0/3
