# Profile keys for delivery-intake (writer of every key; part A.2.2 and part-04 section 5.8)

Authority: the profile is the sole authority for repo facts (D22); other docs link `@<sha>` and never copy. Key names and types come from INTERFACES part A.2.2 and are not restated beyond what you need to measure them.

## Serialization
- One YAML document at `<PRIMARY_REPO>/plans/repo-profile.md`. A dotted name is a nested map (`ci.required_checks[]` = list `required_checks` under map `ci`).
- `yes`/`no` values are quoted strings (`"yes"`, `"no"`), never YAML booleans. Regex values are single-quoted POSIX ERE.
- Skeleton: `references/templates/repo-profile.md` (item 27, with the seed rows) when present; this file never writes `references/templates/`.

## The sentinel
An unmeasured, unanswered value is written as the bare scalar `FILL_IN_BEFORE_DISPATCH` (list keys: `[FILL_IN_BEFORE_DISPATCH]`). Never a guess, never a default of your own. Every sentinel is listed as an open item in `brief.md` or as a `cannot measure:` row in `facts.md` (SKILL.md step 9).

## Source of a value (one of three, nothing else)
1. measured: an explorer row `measured: <cmd -> result>` in `facts.md`;
2. human-answered: a grilling answer recorded in `brief.md` (use for preferences the repo cannot show);
3. the sentinel.

## A.2.2 keys
| Key | Type | How to measure | Sentinel when unmeasured |
|---|---|---|---|
| `clones[]` | list of abs paths | `git -C <PRIMARY_REPO> rev-parse --show-toplevel`; other clones on this machine only from the human | `[FILL_IN_BEFORE_DISPATCH]` (the primary path itself is always measured) |
| `linked_profiles[]` | list of `{clone, profile: <abs path>@<40-hex sha>}`; primary profile only | one entry per other repo of a multi-repo epic (human names them; each linked repo gets its own profile and `hash-object` sha); `[]` for a single-repo epic | `[FILL_IN_BEFORE_DISPATCH]` only when the human said more repos exist and has not named them |
| `worktree_base` | abs path under `$DELIVERY_ROOT` | the human confirms; default proposal `$DELIVERY_ROOT/worktrees` as the recommended answer | `FILL_IN_BEFORE_DISPATCH` |
| `merge_method` | `squash\|merge\|rebase` | docs (`CONTRIBUTING*`); hosting-service settings are `cannot measure`, ask the human | `FILL_IN_BEFORE_DISPATCH` |
| `merge_reach` | one-line string | what a merge deploys: deploy and publish workflow triggers on the main branch | `FILL_IN_BEFORE_DISPATCH` |
| `ci.required_checks[]` | list of check names | job names in the CI workflow that gate a merge; the hosting-service required-checks list is `cannot measure` | `[FILL_IN_BEFORE_DISPATCH]` |
| `ci.min_push_spacing_s` | int | workflow concurrency or rate settings; else ask | `FILL_IN_BEFORE_DISPATCH` |
| `ci.max_open_pr_pipelines` | int | docs; else ask | `FILL_IN_BEFORE_DISPATCH` |
| `merge_pipeline.stages[]` | list of stage names | main-branch workflow job names in order | `[FILL_IN_BEFORE_DISPATCH]` |
| `jira.status_map` | map: canonical status (`Backlog`, `In Progress`, `In Review`, `Blocked`, `Verified`, `Done`) -> Jira status string | human only (the workflow lives in the Jira project) | `FILL_IN_BEFORE_DISPATCH` |
| `jira.archive_status` | Jira status string | human only | `FILL_IN_BEFORE_DISPATCH` |
| `secrets.pattern_file` | abs path of an ERE pattern file | scanner config in the repo; else ask | `FILL_IN_BEFORE_DISPATCH` |
| `gates.command` | string | the exact affected lint, test and typecheck command from `package.json` scripts or the task runner, with `--base`, `--head`, `--parallel` forms as the tool defines them | `FILL_IN_BEFORE_DISPATCH` |
| `gates.parallel`, `gates.min_free_kb`, `gates.runner_slots` | int | machine and CI settings; the human picks (recommend from `sysctl -n hw.ncpu`) | `FILL_IN_BEFORE_DISPATCH` |
| `node.prefix_cmd` | string | one-shot activation command for the pinned Node (`.nvmrc` plus the version manager found) | `FILL_IN_BEFORE_DISPATCH` |
| `zephyr.read_ops` | list of strings | only when the repo or human names a test-management tool | `[FILL_IN_BEFORE_DISPATCH]` |
| `durations.pr_review_min`, `durations.ci_round_min`, `durations.unit_median_min` | int minutes | a local record of past rounds if one exists; run history lives on the hosting service | `FILL_IN_BEFORE_DISPATCH` |
| `release_tags.used` | `"yes"\|"no"` | `git tag -l` empty and no release workflow: write `"no"` (N11, this skill writes it); tags present: `"yes"` | never a sentinel: measure it |
| `release_tags.pattern` | anchored ERE `'^...$'` | derived from existing tags; required when `used` is `"yes"`; omit when `"no"` | `FILL_IN_BEFORE_DISPATCH` when `used` is `"yes"` |
| `release_tags.approval` | `none\|human` | human only; required when `used` is `"yes"`; omit when `"no"` | `FILL_IN_BEFORE_DISPATCH` when `used` is `"yes"` (absent is never read as "no gate") |

## Fields outside A.2.2 (part-04 section 5.8)
Same three-source rule and the same sentinel.
- `PROJECT_ROOT` (a feature worktree path, never the main checkout), package scope and type, consumer repos, registry config.
- Exact command strings: install (`--frozen-lockfile --ignore-scripts` form), `install.rebuild_allowlist`, lint, typecheck, test, build, pack, clean, release, publish.
- `HUSKY=0`: do not restate; write a link to INTERFACES part A.7.
- `pr.author_identity`, `pr.approval_rule`, `version_bump_rule`, `plan_plane_pr`; PR template path, label rules, commit pattern; CI system and status-read skill; merge route.
- `e2e.harness: nlta|none`, `e2e.context_file`, `e2e.plugin_source`, `e2e.prefix`, `e2e.auth_mode`, `e2e.mock_gate`, `e2e.dist_scan_cmd`, `e2e.remotes_resolution`, `e2e.serve_targets`.
- Lane resource profile (ports are profile fields only, part A.5.2), sensitive-path deny list, review profile (mandatory seats, Blocking rules), coverage thresholds, secret retrieval by env-var name only, test-management tool, Jira project key.
- Pre-dispatch checklist: the list of every sentinel still in the file.

## Refresh
Start from the existing profile. Re-measure each measured key; keep a human-answered key unless the human changes it; report every changed value in `brief.md`. The refreshed file gets a new `hash-object` sha and a new `PROFILE:` line.
