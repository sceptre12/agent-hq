# Profile keys for delivery-intake (writer of every key; part A.2.2 and part-04 section 5.8)

Authority: the profile is the sole authority for repo facts (D22); other docs link `@<sha>` and never copy. Key names and types come from INTERFACES 1.10.0 part A.2.2 (with the AM-2 keys, AM-4 20 `default_branch`, AM-5 17 `e2e.harness`, AM-5 19 `lanes[].db.cleanup_cmd`, AM-5 21 `commands.install`, `commands.pack`, `repo.consumer_repos[]`) and are not restated beyond what you need to measure them. Use the A.2.2 spelling exactly; a skeleton that spells a key differently is corrected to A.2.2, never followed.

## Serialization
- One YAML document: a new profile at `<PRIMARY_REPO>/plans/repo-profile.md`; a refreshed one at the path it was read from (repo `plans/` or the context store its header names, A.6). A dotted name is a nested map (`ci.required_checks[]` = list `required_checks` under map `ci`).
- `yes`/`no` values are quoted strings (`"yes"`, `"no"`), never YAML booleans. Regex values are single-quoted POSIX ERE.
- Skeleton: `references/templates/repo-profile.md` (item 27, with the seed rows) when present; this file never writes `references/templates/`.

## The sentinel
An unmeasured, unanswered value is written as the bare scalar `FILL_IN_BEFORE_DISPATCH` (list keys: `[FILL_IN_BEFORE_DISPATCH]`). Never a guess, never a default of your own. Every sentinel has its own line in `brief.md` `## Open items` (SKILL.md step 8).

## Source of a value (one of three, nothing else)
1. measured: an explorer row `measured: <cmd -> result>` in `facts.md`;
2. human-answered: a grilling answer recorded in `brief.md` (use for preferences the repo cannot show; a desk `SUMMARY` only informs the recommended answer, recorded under `## Research`);
3. the sentinel.

## A.2.2 keys
| Key | Type | How to measure | Sentinel when unmeasured |
|---|---|---|---|
| `ports.bus_base`, `ports.lane_base` | int | machine choice: the human answers; recommend a free base from `tools/ports.tsv` and `tools/app-ports.tsv` (read only) | `FILL_IN_BEFORE_DISPATCH` (A.2.2: absent = the plan writes the sentinel; intake writes it so the key is present) |
| `sensitive_paths[]` | list of single-quoted ERE | measured candidates: CI and pipeline definitions (`.github/workflows/`, `.gitlab-ci.yml`), `CODEOWNERS`, migrations, infra, credentials paths; the human confirms the list (CI and pipeline definitions always included) | `[FILL_IN_BEFORE_DISPATCH]` |
| `review_profile.mandatory_seats[]`, `review_profile.blocking_rules[]` | lists | human only; `[]` when the human says none (A.2.2: absent = none) | `[FILL_IN_BEFORE_DISPATCH]` |
| `zephyr.execute_tool` | string | the Zephyr MCP `execute` tool name as Claude Code exposes it; the human or the move verifies it (A.2.2: unmeasured, verify at move) | `FILL_IN_BEFORE_DISPATCH` |
| `clones[]` | list of abs paths | `git -C <PRIMARY_REPO> rev-parse --show-toplevel` (or `rev-parse --show-cdup` from the repo path: no output = the path is the top level); ask the human whether other clones exist on this machine | the primary path is always measured; other clones unanswered: `[<primary>, FILL_IN_BEFORE_DISPATCH]`, listed in the open items |
| `linked_profiles[]` | list of `{clone, profile: <abs path>@<40-hex sha>}`; primary profile only | one entry per other repo of a multi-repo epic (human names them; each linked repo gets its own profile and `hash-object` sha); `[]` for a single-repo epic | `[FILL_IN_BEFORE_DISPATCH]` only when the human said more repos exist and has not named them |
| `default_branch` | string | the branch the merge workflow runs on push (`on: push: branches:`), else `git -C <PRIMARY_REPO> symbolic-ref refs/remotes/origin/HEAD`; the human confirms (A.2.2: absent = `INPUT-ERROR default_branch missing`) | `FILL_IN_BEFORE_DISPATCH` |
| `e2e.harness` | `nlta\|none` | an NLTA config or plugin in the repo: `nlta`; no e2e harness: `none`; else ask | `FILL_IN_BEFORE_DISPATCH` |
| `commands.install`, `commands.pack` | strings | `package.json` scripts and lockfile (`--frozen-lockfile --ignore-scripts` form for install); no pack script: ask | `FILL_IN_BEFORE_DISPATCH` |
| `repo.consumer_repos[]` | list of consumer clone paths | human only (consumers live outside the repo); `[]` when none | `[FILL_IN_BEFORE_DISPATCH]` |
| `lanes[].db.cleanup_cmd` | string per lane with a `db` resource | human only; `lanes: []` when no lane has a db | `FILL_IN_BEFORE_DISPATCH` in that lane's entry |
| `worktree_base` | abs path under `$DELIVERY_ROOT` | the human confirms; default proposal `$DELIVERY_ROOT/worktrees` as the recommended answer | `FILL_IN_BEFORE_DISPATCH` |
| `merge_method` | `squash\|merge\|rebase` | docs (`CONTRIBUTING*`); hosting-service settings are `cannot measure`, ask the human | `FILL_IN_BEFORE_DISPATCH` |
| `merge_reach` | one-line string | what a merge deploys: triggers of workflows that run on a main-branch push, and whether any deploys or publishes (`grep` the workflows); docs only when no workflow exists | `FILL_IN_BEFORE_DISPATCH` |
| `ci.required_checks[]` | list of check names | job names in the CI workflow that gate a merge; the hosting-service required-checks list is `cannot measure` | `[FILL_IN_BEFORE_DISPATCH]` |
| `ci.min_push_spacing_s` | int | workflow concurrency or rate settings; else ask | `FILL_IN_BEFORE_DISPATCH` |
| `ci.max_open_pr_pipelines` | int | docs; else ask | `FILL_IN_BEFORE_DISPATCH` |
| `merge_pipeline.stages[]` | list of stage names | jobs of the workflows that run on a main-branch push, in `needs:` order (file order when there is no `needs:`; say so in the row) | `[FILL_IN_BEFORE_DISPATCH]` |
| `jira.status_map` | map: canonical status (`Backlog`, `In Progress`, `In Review`, `Blocked`, `Verified`, `Done`) -> Jira status string | human only (the workflow lives in the Jira project) | `FILL_IN_BEFORE_DISPATCH` |
| `jira.archive_status` | Jira status string | human only | `FILL_IN_BEFORE_DISPATCH` |
| `secrets.pattern_file` | abs path of an ERE pattern file | scanner config in the repo; else ask | `FILL_IN_BEFORE_DISPATCH` |
| `gates.command` | string | the exact affected lint, test and typecheck command from `package.json` scripts or the task runner, with `--base`, `--head`, `--parallel` forms as the tool defines them. No affected-capable runner (no `nx`, `turbo` or similar): write a `cannot measure:` row naming the full-repo scripts found, write the sentinel, and ask the human (never compose a command yourself) | `FILL_IN_BEFORE_DISPATCH` |
| `gates.parallel`, `gates.min_free_kb`, `gates.runner_slots` | int | machine and CI settings; the human picks (recommend from `sysctl -n hw.ncpu`) | `FILL_IN_BEFORE_DISPATCH` |
| `node.prefix_cmd` | string | one-shot activation command for the pinned Node (`.nvmrc` plus the version manager found) | `FILL_IN_BEFORE_DISPATCH` |
| `zephyr.read_ops` | list of strings | only when the repo or human names a test-management tool | `[FILL_IN_BEFORE_DISPATCH]` |
| `durations.pr_review_min`, `durations.ci_round_min`, `durations.unit_median_min` | int minutes | a local record of past rounds if one exists; run history lives on the hosting service | `FILL_IN_BEFORE_DISPATCH` |
| `release_tags.used` | `"yes"\|"no"` | `git tag -l` empty and no release or publish workflow: write `"no"` (N11, this skill writes it); tags present: `"yes"`; no tags but a release or publish workflow: ask the human (cite the workflow file) and record the answer in `brief.md` | never a sentinel: measure it |
| `release_tags.pattern` | anchored ERE `'^...$'` | derived from existing tags; required when `used` is `"yes"`; omit when `"no"` | `FILL_IN_BEFORE_DISPATCH` when `used` is `"yes"` |
| `release_tags.approval` | `none\|human` | human only; required when `used` is `"yes"`; omit when `"no"` | `FILL_IN_BEFORE_DISPATCH` when `used` is `"yes"` (absent is never read as "no gate") |

## Fields outside A.2.2 (part-04 section 5.8)
Same three-source rule and the same sentinel.
- `PROJECT_ROOT` (a feature worktree path, never the main checkout), package scope and type, consumer repos, registry config.
- Exact command strings (install and pack are A.2.2 keys above): `install.rebuild_allowlist`, lint, typecheck, test, build, clean, release, publish.
- `HUSKY=0`: do not restate; write a link to INTERFACES part A.7.
- `pr.author_identity`, `pr.approval_rule`, `version_bump_rule`, `plan_plane_pr`; PR template path, label rules, commit pattern; CI system and status-read skill; merge route.
- `e2e.context_file`, `e2e.plugin_source`, `e2e.prefix`, `e2e.auth_mode`, `e2e.mock_gate`, `e2e.dist_scan_cmd`, `e2e.remotes_resolution`, `e2e.serve_targets`.
- Lane resource profile (ports are profile fields only, part A.5.2; the port bases are A.2.2 `ports.*`), coverage thresholds, secret retrieval by env-var name only, test-management tool, Jira project key.
- Pre-dispatch checklist: the list of every sentinel still in the file.
- Keys that only the skeleton carries (for example `profile_version`, `measured_utc`, `repo.type`, `lane_profile.*`): measure as the skeleton's comment says, else the sentinel.

## Refresh
Start from the existing profile and write it back to the same path. Re-measure each measured key; keep a human-answered key unless the human changes it; report every changed value in `brief.md`. The refreshed file gets a new `hash-object` sha and a new `PROFILE:` line.
