# panel7 interfaces 2b, round 4, seat s3 (grammar machine-checkability)

| id | sev | artifact file:line | defect | source | fix |
|---|---|---|---|---|---|
| s3-1 | M | part-a-state.md:11; part-d-enums-topics.md:19; part-b-desk.md:36 | No regex dialect declared; set mixes `[[:space:]]` and PCRE named groups `(?<run>)` and table-escaped `\|`; no one engine accepts all | part-b-desk.md:137 (grep -E) | Declare one dialect for all regexes; drop named groups and POSIX classes; state `\|` is table escaping |
| s3-2 | M | part-b-desk.md:28-30 | DESK/DONE/REJECTED lines are templates only; no anchored regex, hex length unstated, DONE verdict free text may hold ` \| `, "no imperatives" unverifiable | part-b-desk.md:16, :147-149 (other lines have regexes) | Add anchored regexes (sha256 64-hex, verdict without pipe/newline); remove unverifiable clause |
| s3-3 | M | part-c-waves-control.md:144-147, :160-162, :78 | RELEASE, INVALIDATE, INBOX, NUDGE, flag lines have no regex; flag line has no utc or clear form; escalations/<unit>.md content undefined | part-c-waves-control.md:117; part-d-enums-topics.md:55 | Anchored regex per line; utc on flag lines; escalation file grammar |
| s3-4 | M | part-a-state.md:103-117 | repo-profile.md key syntax undefined (dotted, `[]`, maps, regex quoting, `yes\|no` as YAML bool, `merge_reach` "row verbatim") | part-04-templates.md:32-33; part-b-desk.md:116 | Define profile serialization; merge_reach = Value cell |
| s3-5 | M | part-a-state.md:113-117; part-b-desk.md:86, :54 | `release_tags.used=yes` with pattern/approval missing or malformed has no defined refusal; A.2.2 exempts these keys from INPUT-ERROR, so absent approval can read as no gate | owner-decisions.md:84 | Any missing/malformed release_tags.* = `REJECTED policy`; pattern must compile and be anchored |
| s3-6 | M | part-b-desk.md:86 | tag-push reads "the run's repo-profile.md" but ruling is per repo; multi-repo epics have one profile per repo | owner-decisions.md:81-82; part-a-state.md:50; part-04-templates.md:31 | Desk resolves the profile of the clone in `fields.repo`; none = policy |
| s3-7 | M | part-d-enums-topics.md:8 | INPUT-ERROR field class excludes `[]` yet A.2.2 reports `ci.required_checks[]`, `merge_pipeline.stages[]` through it | part-a-state.md:109-110, :117 | Allow `[]` or name keys without it |
| s3-8 | M | part-b-desk.md:69, :89-90 | `fields.` has two meanings (envelope.fields vs jira member `fields`); per-key string/array types of Jira allowlist undefined though array-for-string is `schema` | part-b-desk.md:49 | Rename jira member, full JSON paths, key-to-type table |
| s3-9 | M | INTERFACES.md:37; part-a-state.md:216-225 | catalog.sh start/release/fail/keep lack args for columns 3,5,8,9,12; copy rule and owner_agent source unstated; lease reclaim keys on owner_agent | part-c-waves-control.md:138 | State copy-from-latest-row and where owner_agent/source come from |
| s3-10 | L | part-a-state.md:152 | `prepr` typed `PASS\|STOP` but PREPR token copied into it carries rows | part-d-enums-topics.md:21 | Type as token tail or say rows dropped |
| s3-11 | L | part-a-state.md:280 | merge-<sha>.md `pr=`/`method=` "copied from .out" but pr-merge result has neither | part-b-desk.md:116, :108 | Source them from the request or add to result |
| s3-12 | L | part-b-desk.md:152 | GATE `ref=` override token has no regex; stripping from `text=`/H1.notes.md unstated | part-a-state.md:91 | Give regex and state it is stripped |

totals 0/9/3
