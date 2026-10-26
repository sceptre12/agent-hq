CLEAN

Fix-verifier (Sonnet, not the fixer), round 1, 26 delivery-desk. Scope: `git diff -- skills/delivery-desk` (4 files). Counts B 0 / M 0; new Lows 3 (informational, do not change the verdict). R1-3 (OWNER) and the review's Lows untouched by scope.

## Closure of the B/M FIX rows

| id | sev | status | evidence (file:line) | source |
|---|---|---|---|---|
| R1-1 | B | closed | schemas.json git_ref/tag `^[A-Za-z0-9._/][A-Za-z0-9._/-]*$`, package `^(@[a-z0-9-]+/)?[a-z0-9._][a-z0-9._-]*$`; `python3 -I` rejects `-x`, `--upload-pack=x`, `--force`, `-d`, `--registry=x`, `@a/-x`, empty; accepts main, release/1.2, v1.0.0, rel/1, left-pad, @scope/pkg. SKILL.md:78-80, verbs.md:10-17, checks.md:28. All Act forms use `--`/`--end-of-options`/`refs/...`/`--opt=`. | ADR:198, PB:77, PB:79 |
| R1-2 | M | closed | pr/ci_run_id minimum 0 (matches sender int >= 0); no minItems/minProperties anywhere in schemas.json (grep) | PB:79, DRS:28-44 |
| R1-4 | M | closed | SKILL.md:78, 163-168, 199, 223 and checks.md:28 all say non-B4 verb = `schema` at check 5; `policy` only for in-schema never-granted forms | PB:41, PB:73 |
| R1-5 | M | closed | definitions.branch has no pattern (schemas.json:9); SKILL.md:80, 88, checks.md:28, :48 say branch regex is `repo` at check 6; reason_codes.repo matches | PB:61, PB:73 |
| R1-6 | M | closed | checks.md:63-68, SKILL.md:89-92: absent/unreadable/empty pattern file or grep exit other than 0/1 is `policy` (detail never content); red-flag row SKILL.md:224 | PB:146-147 |
| R1-7 | M | closed | checks.md:72-78, SKILL.md:93-95: image only if `file --brief --mime-type` is png/jpeg/gif/webp and extension agrees; else scanned. Tested: text in x.png reports text/plain (scanned) | PB:147 |
| R1-8 | M | closed | checks.md:104, verbs.md:91-93, SKILL.md:107-108: desk-side fetch into `refs/remotes/<remote>/...`, no local fallback, all three methods use M/H. Git forms tested in a scratch repo (git 2.54): `--end-of-options` accepted by rev-parse, tag, merge-base, cherry, diff; `push -- origin <sha>:refs/heads/B`, `push --delete -- origin refs/heads/B`, `fetch -- origin refs/heads/B:refs/remotes/origin/B`, `ls-remote --`, `patch-id --stable` all valid. `gh pr merge --match-head-commit`, `gh pr create --base/--head/--title/--body-file/--label`, `gh pr checks --json bucket`, `gh run rerun --failed` exist in gh 2.102 | PB:110 |
| R1-9 | M | closed | STATUS added to Step 0 (SKILL.md:27-28), regexes.STATUS/BUSY, Step 15 (:131-137), 60 s slices for push-spacing (SKILL.md:109-110, checks.md:109-112); BUSY line matches the BUSY regex | PB:20, permission-tiers-02:92,100-101 |
| PR2-C2a..c | M | closed | Provenance now cites `SCRATCH/agent-workflow-design-panel.md:40` (quote verified), gh-auth `SKILL.md:12-22` (quote verified), part-a-state.md:325-342 (A.7 heading at 325) | preround r1b C2 |
| PR2-C5a..b | M | closed | checks.md:146-148 cites part-b-desk.md:22 `DEFAULT (integrator)` (verified); SKILL.md:210-214 cites owner-decisions.md:67 OP5 B (quote verified) | preround r1b C5 |

## Regression checks (none found at B/M)
- Forbidden actions: no raw flag, force, approve, prod trigger, `--no-verify` or file-sourced sender is reachable; `--admin`/`--auto` appear only as prohibitions. `step_id`/`job` can start with `-` but are never argv words (path segment / matched in gh output).
- SKILL, checks, verbs, schemas.json agree on codes, the 20 verbs and field sets; `bash SCRATCH/s9-26.sh` prints DESK-SCHEMAS-OK; schemas.json parses; no sanitization hits.
- Sender vs desk: sender (desk-req-schema.sh) printed requests are accepted by the desk except the known gaps: semver (R1-3, OWNER) and package with a leading `-` (sender has no guard; the desk's refusal is the intended R1-1 tightening, a sender-side guard is optional).

## New Lows (informational)
| id | sev | file:line | issue | source |
|---|---|---|---|---|
| V1-1 | L | skills/delivery-desk/SKILL.md (22317 bytes, 3436 words; was 18986 bytes) | fix r1 grew the body about 3.3 KB; at 4 chars/token it is near or above the 5k-token L2 target. Move step 8-9 detail already in checks.md to references if a measurement says over | tools/skill-authoring.md:66 |
| V1-2 | L | skills/delivery-desk/references/schemas.json reason_codes.policy `trigger` | text still lists approve/trigger-prod/pipeline edit as policy triggers (part B quote); only the `$comment` says they are `schema` at check 5. No behaviour change | PB:64 |
| V1-3 | L | skills/delivery-desk/SKILL.md:199 | reason-code table row `schema` names ref/tag/package but not base/merged_into (Step 8 :79 lists them) | PB:79 |
