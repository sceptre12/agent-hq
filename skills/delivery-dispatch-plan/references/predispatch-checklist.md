# Pre-dispatch checklist (step 11)

Run before the Plan-checker and again after any fix. Record each row as `PASS <evidence>` or `FAIL <what>` in the plan's checklist section. Any `FAIL` blocks step 12.

## Whole plan

| # | Check | How |
|---|---|---|
| 1 | No sentinel left | `grep -rn 'FILL_IN_BEFORE_DISPATCH' PLANS_DIR .tasks` (and the spec-format placeholders `FILL_IN`, `TODO`, `TBD`) returns nothing in files this skill wrote |
| 2 | Every path named in the plan exists | `ls` each path (scope anchors, scripts in `command`, files the units read); a path that a unit creates is marked "created by u<N>" and not checked |
| 3 | Flags present | each command in a `done_condition` or `.tasks` section 9 uses flags that exist in the repo's tool version (`<tool> --help` output recorded) |
| 4 | Header complete | `interfaces_version`, `repo-profile.md` link plus sha, `security_sensitive:`, sub-task table with `ticket`, `branch`, `repo` |
| 5 | Ids and tokens | units `^u[0-9]+$`, sub-tasks `^(st[0-9]+\|pm)$`, `st0` present, shas 40-hex |
| 6 | Tickets | every unit and sub-task has a `key` from `tickets.tsv` or a draft slug |
| 7 | Scopes disjoint | the owner table shows no glob pair that can match one path, apart from files with a named owner |
| 8 | Port candidates distinct | no two candidates in the port table are equal; on a clash stop and report, never re-pick |
| 9 | Budgets | `dispatch_budget` and peak per sub-task, machine line at most 200, concurrent builds at most 3 |
| 10 | Waves valid | each `waves/` passes spec-format rules 1-11 and 13-15 by reading (the Plan-checker runs them again) |
| 11 | Briefs exist | each `Brief:` path resolves under `skills/delivery-run/references/briefs/`, or is listed as written by item 27b |
| 12 | Catalog | `RUN_HOME/catalog.tsv` exists and is empty |
| 13 | Stop rows stated | the plan's stop-the-line table lists: unit without verifier, overlapping scopes, unmeasured claim contradicted |

## Per unit: the six pre-flight checks (`part-04` section 5.3b)

For every `.tasks/<unit>-<slug>.md`:

1. The "What you inherit" section is present.
2. The "Known risky values" section is present.
3. The "Inherited module API" section is present.
4. The "Do NOT create" list is present.
5. Every acceptance criterion can be checked with the commands in section 9.
6. Every risky value is sourced from its authority contract (cite the anchor, never a second copy).

Also check: `## 3` holds one `- <glob>` per line and the unit's globs equal the plan's unit-table globs.
