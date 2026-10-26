id | sev | artifact file:line | defect | source file:line | fix
--- | --- | --- | --- | --- | ---
s5-1 | B | skills/delivery-desk/references/schemas.json:10,19; verbs.md:88,135 | git_ref and tag patterns allow a leading '-' and Act lines pass ref/base/merged_into/tag unquoted to git/gh, so a raw flag (e.g. --upload-pack=) is reachable; desk-req.sh rejects it, the desk does not | decisions/0055-desk-verb-permission-tiers-02.md:198; interfaces/part-b-desk.md:79 | reject a leading '-' in git_ref and tag in schemas.json and use '--' in every Act line
s5-2 | L | skills/delivery-desk/SKILL.md:146-150,216 | N10 rule and exit criterion name only push and pr-create and restate the form already in A.7; tag-push and branch-delete also push with HUSKY=0 | interfaces/part-a-state.md:329; part-b-desk.md B4 push row | link A.7 only; cover every desk git push
s5-3 | L | tools/delivery/desk-req-schema.sh:28,31,50 vs schemas.json:11,12,211,738 | sender accepts pr/ci_run_id 0, empty pr-attach paths, empty jira-get fields, leading-zero semver that the desk schema rejects | interfaces/part-b-desk.md:79 | align minimums on one side
s5-4 | L | references/checks.md:66 | images exempt from the redaction scan by extension only; a text file named .png is attached unscanned | interfaces/part-b-desk.md B7 | test content type, not extension
s5-5 | L | SKILL.md:164; references/verbs.md:52 | 'request changes only on a Blocking finding' names an act no verb/field can request | interfaces/part-b-desk.md B4 pr-comment row; ADR 0055:195 | state no request-changes path in v1 or name the field
s5-6 | L | SKILL.md:103,122,131,134 | measured-at-the-move items marked only in verbs.md; Step 12 does not say what the desk replies while unmeasured | interfaces/part-b-desk.md B4; verbs.md:44-46 | add a Step 12 line: no guessed command, REJECTED action-failed 'unmeasured'

totals 1/0/5
