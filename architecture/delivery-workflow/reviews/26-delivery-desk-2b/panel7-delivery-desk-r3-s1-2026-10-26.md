id | sev | artifact file:line | defect | source file:line | fix
s1-1 | L | skills/delivery-desk/references/checks.md:97 | "nothing the requester wrote counts" but push first/later evidence (substate.md prepr, ci/<pr>.md) is lead-written | part-b-desk.md:83,110 | say it is a lead-written file read as B4 names it
s1-2 | L | skills/delivery-desk/SKILL.md:78 | pr-merge method vs merge_method in check 5 as schema, needs profile before check 6, not marked DEFAULT | part-b-desk.md:89,59 | mark DEFAULT (author)
s1-3 | L | tools/delivery/desk-req-schema.sh:63 | sender accepts jira-create fields.parent / missing summary,issuetype; desk refuses schema | schemas.json verbs.jira-create.request; part-b-desk.md:100 | add rules to sender
s1-4 | L | skills/delivery-desk/references/verbs.md:196-197 | test-report-push first-call dry_run:true has no detection or code | part-b-desk.md:98 | name detection and code as DEFAULT

totals 0/0/4
Note: JSON-level check with jsonschema 4.25.1: 20 verbs, request required sets/types/additionalProperties false, B6 result fields, envelope, jira-create parent carrier, tag-push step_id, pr-attach, record_path all match part B; 21 probe cases passed.
