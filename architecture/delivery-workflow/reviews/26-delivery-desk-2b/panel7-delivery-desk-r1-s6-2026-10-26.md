# panel7 delivery-desk r1 s6: wire interop with desk-req.sh

| id | sev | artifact file:line | defect | source file:line | fix |
|---|---|---|---|---|---|
| s6-1 | M | tools/delivery/desk-req-schema.sh:28 vs skills/delivery-desk/references/schemas.json:11-12 | Sender accepts pr, ci_run_id, predecessors[] = 0 (int >= 0); desk schema has minimum 1, so a printed DESK line gets terminal `schema` (verified: pr 0 produced a DESK line) | part-b-desk.md:79 (int, no bound) | one bound in both |
| s6-2 | M | tools/delivery/desk-req-schema.sh:41-44 vs references/schemas.json:33,738 | Sender accepts jira fields `{}` (create/update) and jira-get `fields: []`; schema has minProperties/minItems 1 (verified: both produced DESK lines) | part-b-desk.md:79,99 | align both |
| s6-3 | M | tools/delivery/desk-req-schema.sh:34 vs references/schemas.json:21 | semver differs: sender accepts `01.2.3` and `1.2.3-a..b`, schema refuses (verified: both produced DESK lines for publish) | part-b-desk.md:79 | one semver regex |
| s6-4 | M | references/schemas.json:10,19 and SKILL.md:75 | git_ref and tag allow a leading `-` (fetch ref `--force`, base, merged_into, tag); sender refuses it; SKILL says "no raw flag" with no rule, so a flag can reach git/gh argv | part-b-desk.md:59,77; desk-req-schema.sh:7-8,23-24 | leading char `[A-Za-z0-9._/]` in schema; state in SKILL step 8 |
| s6-5 | L | tools/delivery/desk-req.sh:19 vs SKILL.md:70, checks.md:28 | Sender accepts DELIVERY_ROOT with trailing slash (DESK path then has `//` and every body/record path is refused); desk's "path equals RUN_HOME/desk/<id>.req" does not say string or realpath compare | part-b-desk.md:41 | say exact string on the desk's DELIVERY_ROOT; sender refuses trailing slash |

Checked and consistent: DESK line form and id regex, .req location/name/0600 and content `{id,verb,subtask,fields}`, sha256 of the file as written, conductor-only set and `run` rule, pr-merge fields.subtask vs record_path, per-verb required/unknown keys for all 20 verbs, branch/sha/label/job/package/step/key/to enums, REGISTER-SENDER/REGISTERED regex and first-line/replace/REBIND rules, .out reading and `sender` no-.out.

totals 0/4/1
