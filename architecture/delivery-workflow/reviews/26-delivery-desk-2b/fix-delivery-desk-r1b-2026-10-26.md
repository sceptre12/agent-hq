# Fix r1b: 26 delivery-desk (2026-10-26)
Input: `preround-delivery-desk-r2-2026-10-26.md` (C2, C5 FAILs), `verify-fix-delivery-desk-r1-2026-10-26.md` (V1-2, V1-3 Lows). Mechanical; no behaviour change.

| id | status | file:line after | change |
|---|---|---|---|
| PR3-C2a | FIXED | references/source-keys.md:1-35 (new); SKILL.md:12-13; checks.md:6; verbs.md:6-7; human-gates.md:7 | one key table maps every bare id (design §6.3, D1, D3, D23, Q1-Q3, OP1/5/6/9/10, R2-4, N10, N11, M24/27/29/30, R4-J9, R4-J20, §Script interfaces, part A/B sections) to path:line; first-use note in SKILL and each reference |
| PR3-C2b | FIXED | checks.md:3-6; verbs.md:5-7; human-gates.md:5-7 | Authority lines now carry path:line-ranges (part-b-desk.md:7-76, :108-151, :77-143, :152-172; part-a-state.md:7-52, :105-153, :283-342, :91-104) |
| PR3-C5a | FIXED | SKILL.md:211-215 | resend rule is now two verbatim quotes (owner-decisions.md:67, part-b-desk.md:54) plus the replay pointer (part-b-desk.md:47) |
| PR3-C5b | FIXED | verbs.md:165-166; SKILL.md:158 | dry_run-first marked `DEFAULT` with pointer part-b-desk.md:98 (quoted in verbs.md) |
| V1-2 (V1-L2) | FIXED | schemas.json:872 | `policy.trigger` no longer lists approve/trigger-prod; says non-B4 verbs are `schema` at check 5 |
| V1-3 (V1-L3) | FIXED | SKILL.md:200 | `schema` row adds base, merged_into |
| PR3-C4 | OPEN (out of scope) | tasks/26-delivery-desk.md:5 | spec pins INTERFACES `1.1.0` vs skill `1.2.0`; spec not edited, integrator/spec owner to resolve |
| SKILL.md:219 (extra) | FIXED | SKILL.md:219 | "INTERFACES §Script interfaces" gains `INTERFACES.md:47-56` |

Hunk map (this fix only): SKILL.md 12-13 C2a; 158 C5b; 200 V1-3; 210-215 C5a; 219 C2a. checks.md 3-6 C2a/C2b. verbs.md 5-7 C2a/C2b; 165-166 C5b. human-gates.md 5-7 C2a/C2b. schemas.json 872 V1-2. source-keys.md new file C2a.

Checks: `bash SCRATCH/s9-26.sh` DESK-SCHEMAS-OK, 0 lines matching missing/fail/error; `json.load(schemas.json)` OK; `wc -c -w SKILL.md` 3301 words, 22509 bytes (was 22317); `check-doc-length.sh` 0 blocking.
Note: SKILL.md body is ~5.6k tokens at 4 chars/token (V1-1, pre-existing); trimming steps 8-9 is a behaviour-neutral move left for the integrator.
