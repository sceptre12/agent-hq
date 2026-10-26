# panel7 delivery-desk r2 s1 (verb and schema exactness)

JSON-level checks run (python3 -I, jsonschema Draft7): schemas.json is a valid draft-07 schema; all 20 verbs have request and result with additionalProperties false; request fields, required sets, types and enums match part B B4/B6 and desk-req-schema.sh; jira-create parent rule (Epic without / non-Epic with), string-for-array, unknown key, envelope DONE/REJECTED rules all behave as B4/B6. No schema-level defect found.

| id | sev | artifact file:line | defect | source file:line | fix |
|---|---|---|---|---|---|
| s1-1 | M | skills/delivery-desk/references/verbs.md:48,63,69,86,109,118-119,130 (also checks.md:102) | Every `gh` act names no repository (git acts use `git -C <repo>`); `gh` resolves the repo from the desk session cwd, so the request `repo` is not what the PR or run number is applied to | architecture/delivery-workflow/interfaces/part-b-desk.md:14 (repo is the desk's only target check), :106 (repo realpath rule) | State that every `gh` runs with cwd = the realpath'd request repo (or `--repo <owner/name>` from that clone's remote), and that `gh api repos/<o>/<r>` takes `<o>/<r>` from it |
| s1-2 | L | skills/delivery-desk/references/verbs.md:165-166,186 | test-report-push "first call for a payload is dry_run: true" and jira-create "parent re-fetched first and must exist" are Checks with no reason code and no definition of "first call" | architecture/delivery-workflow/interfaces/part-b-desk.md:98,114 (B4 rows give no code) | Name the author-default code (marker for a non-dry first call, action-failed for a missing parent) and define first call as no earlier DONE for that payload_path |
| s1-3 | L | skills/delivery-desk/SKILL.md:87-89 | `record_path` root is `RUN_HOME/review/<subtask>/` without saying that for `pr-merge` the segment is `fields.subtask` (the id subtask is `run`); a literal reading rejects every conductor pr-merge as `repo` | architecture/delivery-workflow/interfaces/part-b-desk.md:87,106 | Add "for pr-merge the segment is fields.subtask" to step 9, as checks.md:100 does for gate runs |

totals 0/1/2
