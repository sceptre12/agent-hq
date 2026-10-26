# Fix r1: 26 delivery-desk (review-7-panel, 2026-10-26)

Fixer: Opus subagent (not the author, not a seat or verifier). Input: `panel7-delivery-desk-r1-2026-10-26.md`.
Scope: `skills/delivery-desk/` only (SK below). Lows R1-10..R1-23 left for the Low pass. Line numbers are after this fix;
the "before" baseline is fix r0 (uncommitted), snapshot taken before editing.

## Findings

| id | status | file:line after | change |
|---|---|---|---|
| R1-1 | FIXED | SCH:10 (git_ref), :19 (tag), :20 (package), :17 (label comment); SK/SKILL.md:80-81, :116-118, :199; verbs.md:10-18, :30, :34, :37, :46-47, :93-94, :100, :147-148, :155-156; checks.md:28, :97, :104 | git_ref and tag `^[A-Za-z0-9._/][A-Za-z0-9._/-]*$` (exact to desk-req-schema.sh:23-24); package `^(@[a-z0-9-]+/)?[a-z0-9._][a-z0-9._-]*$` (stricter than the sender, which has no guard). Leading `-` in ref/base/merged_into/tag/package = `schema` at check 5; a branch is `repo` at check 6 (its regex cannot start with `-`). Act lines: `--` on git fetch/push/ls-remote, `--end-of-options` on rev-parse/tag/merge-base/cherry/diff, `refs/...` names, `gh pr create --opt=<value>`. Each git form was run locally against git 2.54.0 in a temp repo. Labels keep the part B / sender pattern and are only passed attached (`--label=<x>`). |
| R1-2 | FIXED | SCH:11-12, :32 (minProperties removed), :210, :737 | `pr`, `ci_run_id` (and `predecessors[]` via `pr`) `minimum` 0, matching the sender's `int >= 0`; `minProperties` on Jira write fields and `minItems` on `pr-attach` `paths[]` / `jira-get` `fields[]` dropped. The desk now accepts every value the sender prints that part B4 allows, except a package starting with `-` (R1-1, deliberate). |
| R1-3 | OWNER (not changed) | SCH:21 unchanged | See owner notes. |
| R1-4 | FIXED | SK/SKILL.md:78-79, :163-168, :199, :202, :223; SCH:867, :872 | A non-B4 verb (approve, trigger-prod, pipeline-edit) is `REJECTED schema` at check 5 everywhere (step 8, the "not verbs" paragraph, reason-code table, Red flags); `policy` is only for in-schema never-granted requests. SCH policy row keeps the part B text and adds a `$comment` stating this. |
| R1-5 | FIXED | SCH:9; SK/SKILL.md:80-81, :88; checks.md:28-29, :48 | `definitions.branch` has no `pattern` (a `$comment` says check 6 applies the regex, code `repo`); SKILL step 8 and checks.md row 5 say the branch regex is deliberately not part of check 5; row 6 and the per-field table say it is `repo`. |
| R1-6 | FIXED | checks.md:62-68, :80-81; SK/SKILL.md:88-95, :202, :224 | Redaction fails closed: pattern file absent/unreadable/empty, or a grep exit other than 0/1, or an `unzip` failure = `REJECTED policy` (`detail` names the key/file; code `policy` marked author default, part B names none). |
| R1-7 | FIXED | checks.md:72-78; SK/SKILL.md:92-95, :225 | Image = `file --brief --mime-type` png/jpeg/gif/webp AND matching extension; everything else (including a text `.png`) is scanned. Method marked author default. |
| R1-8 | FIXED | checks.md:104; verbs.md:91-93; SK/SKILL.md:110-111 | content-merged first fetches `refs/heads/<merged_into>` and `refs/heads/<branch>` into `refs/remotes/<remote>/...` and uses only those (`M`, `H`) in all three methods; no local fallback; `merge_sha` must be reachable from `M`. |
| R1-9 | FIXED | SK/SKILL.md:18, :28-29, :112-113, :131-137; checks.md:109-112; SCH:889-891 | `STATUS` added to the Step 0 classifier and as step 15 (reply `BUSY <id> \| <what> \| <ETA>` within 2 minutes, cites permission-tiers-02.md:92, :100-101); push-spacing wait polls in slices of at most 60 s (author default) and serves `STATUS` between slices. `STATUS`/`BUSY` regexes added to SCH `regexes` with their source noted. Idle/unknown id reply marked owner to decide, proposed default `BUSY <id> \| idle \| -`. |
| PR2-C2a | FIXED | SK/SKILL.md:257-259 | Design panel cite now `SCRATCH/agent-workflow-design-panel.md:40` plus a verbatim quote. |
| PR2-C2b | FIXED | SK/SKILL.md:254-256 | gh-auth cite now `$HOME/claude-profiles/hermes/h1-home/skills/learnings/gh-auth/SKILL.md:12-22` plus a verbatim quote (SUB applied). |
| PR2-C2c | FIXED | SK/SKILL.md:173-174 | A.7 cite now `part-a-state.md:325-342`. |
| PR2-C5a | FIXED | checks.md:147-148 | Added "(default; source `part-b-desk.md:22`, marked `DEFAULT (integrator)`)". |
| PR2-C5b | FIXED | SK/SKILL.md:211-214 | Added owner ruling OP5 B with `architecture/delivery-workflow-sources/owner-decisions.md:67` verbatim quote and `part-b-desk.md:52-67`. |

## Hunk map (diff against the fix r0 state, for preround C3)

| file | hunk (after) | id |
|---|---|---|
| SKILL.md | :18 | R1-9 |
| SKILL.md | :28-29 | R1-9 |
| SKILL.md | :78-81 | R1-4, R1-1, R1-5 |
| SKILL.md | :88-95 | R1-5, R1-6, R1-7 |
| SKILL.md | :107-113 | R1-8, R1-9 |
| SKILL.md | :116-118 | R1-1 |
| SKILL.md | :131-137 | R1-9 |
| SKILL.md | :163-168 | R1-4, R1-9 (STATUS listed as not a verb) |
| SKILL.md | :173-174 | PR2-C2c |
| SKILL.md | :199 | R1-1, R1-4 |
| SKILL.md | :202 | R1-6 |
| SKILL.md | :211-214 | PR2-C5b |
| SKILL.md | :223-225 | R1-4, R1-6, R1-7 |
| SKILL.md | :254-260 | PR2-C2a, PR2-C2b |
| checks.md | :28-29 | R1-4, R1-1, R1-5 |
| checks.md | :48 | R1-5 |
| checks.md | :62-68 | R1-6 |
| checks.md | :72-78 | R1-7 |
| checks.md | :80-81 | R1-6 |
| checks.md | :97 | R1-1 |
| checks.md | :104 | R1-8, R1-1 |
| checks.md | :109-112 | R1-9 |
| checks.md | :147-148 | PR2-C5a |
| verbs.md | :10-18 | R1-1 |
| verbs.md | :30, :34, :37, :46-47 | R1-1 |
| verbs.md | :91-95 | R1-8, R1-1 |
| verbs.md | :100, :147-148, :155-156 | R1-1 |
| schemas.json | :9 | R1-5 |
| schemas.json | :10, :17, :19-20 | R1-1 |
| schemas.json | :11-12, :32, :210, :737 | R1-2 |
| schemas.json | :867 | R1-4, R1-1 |
| schemas.json | :872 | R1-4 |
| schemas.json | :889-891 | R1-9 |

## Owner notes (open, not decided here)

- R1-3 (OWNER): `tools/delivery/desk-req-schema.sh:34` semver accepts `01.2.3` and `1.2.3-a..b`; the desk (SCH:21,
  semver.org grammar) refuses them as `schema`. The desk semver is unchanged; the sender change is outside this scope.
- R1-1 sender gap: `desk-req-schema.sh:33` package has no leading-`-` guard; the desk now refuses `-x` packages
  (`schema`), so the sender can print a line the desk refuses. Aligning the sender is outside this scope.
- R1-OWN-1 (from the panel): if non-zero ids / non-empty arrays and Jira maps are wanted, the change is on both sides.
- R1-9: the `STATUS` reply for an idle or unknown id is not set by part B or ADR 0055; SKILL step 15 marks a
  proposed default (`BUSY <id> | idle | -`), owner to decide.
- Part B tension (panel note): PB:79 ref/tag regex allows a leading `-`; PB:64 lists approve/trigger-prod/pipeline
  edit under `policy`; PB:61 vs PB:79 on the branch regex. The skill follows the stricter / earlier-check reading.

## Checks run (from W)

- `bash SCRATCH/s9-26.sh`: ends `DESK-SCHEMAS-OK`; 0 MISSING / VIOLATION / NO-USE-WHEN / RULE-MISSING;
  check-doc-length 0 blocking; SKILL.md 3278 words.
- `python3 -I -c 'import json;json.load(open("skills/delivery-desk/references/schemas.json"))'`: OK.
- Regex probe (python3 -I): git_ref, tag, package reject `-x`, `--upload-pack=x`, `-d`, `--force`, `-`, and `@s/-x`
  for package; accept `main`, `v1.2.3`, `release/1.0`, `.x`, `a-b`, `pkg`, `@s/pkg`. `definitions.branch` has no
  pattern. `label` still admits `-x` (passed only as `--label=<x>`).
- Line counts: SKILL.md 264, checks.md 151, verbs.md 195, schemas.json 896, human-gates.md 67 (unchanged).
