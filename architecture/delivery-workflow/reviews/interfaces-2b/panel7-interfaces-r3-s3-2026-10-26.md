# panel7 interfaces r3 s3 (grammar machine-checkability)

| id | sev | artifact file:line | defect | source | fix |
|---|---|---|---|---|---|
| s3-1 | M | interfaces/part-d-enums-topics.md:67-83 | D2.2 named inputs are prose, not identifiers; INPUT-ERROR <field> cannot be validated and callers cannot pass inputs consistently | part-d-enums-topics.md:8 | identifier tokens plus transport per input |
| s3-2 | M | interfaces/part-a-state.md:171; interfaces/part-c-waves-control.md:33 | persona has no token set; used as slot field, wave field and briefs file name | part-03-personas-and-concurrency.md:10-26 | closed persona token table in D2.1 |
| s3-3 | M | interfaces/part-d-enums-topics.md:53 | closed conductor-message set omits MERGED | interfaces/part-c-waves-control.md:116 | add MERGED |
| s3-4 | M | interfaces/part-b-desk.md:100,119 | required-check set has no source/flag; ci-status aggregate state rule undefined | part-d-enums-topics.md:79; part-04-templates.md:53 | name profile field; define state precedence |
| s3-5 | L | interfaces/part-a-state.md:128 | reserved.review value ambiguous | part-a-state.md:200 | state storage form |
| s3-6 | L | interfaces/part-a-state.md:140 vs part-d-enums-topics.md:21 | integrated entry form vs INTEGRATED: regex | same | bare entry regex |
| s3-7 | L | interfaces/part-c-waves-control.md:159,163 | flag/NUDGE lines lack regex; "changed" undefined | same | regexes |
| s3-8 | L | interfaces/part-b-desk.md:28-30 | DESK/DONE line regex absent (sha length, verdict text), jira parent duplicate rule | part-b-desk.md:4 | full regexes |

totals 0/4/4
