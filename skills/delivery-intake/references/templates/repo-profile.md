# Template: repo-profile.md (design 5.8 plus the 5.8b <pilot-app> seed)

Purpose: the sole authority for facts about one target repo (D22, M17). Every other document links it as `<abs path>@<sha>` and never copies a value.
Writer: `delivery-intake` (every key; INTERFACES part A.2.2). Reader: conductor, `delivery-architecture`, `delivery-dispatch-plan`, `delivery-run`, gate runner, `pre-pr-gate`, `pr-review`, desk, `release-track`, `ci-fix-loop`, `ticket-clerk`.
Location: `<primary_repo>/plans/repo-profile.md` (part A.2, D1.1 `PROFILE:` token). Keys and types: INTERFACES part A.2.2 (not restated beyond the skeleton below); the measuring guide is `skills/delivery-intake/references/profile-keys.md`.

## 1. Serialization (INTERFACES A.2.2, row R4-J1)
- One YAML document. A dotted key is a nested map (`ci.required_checks[]` = list `required_checks` under map `ci`).
- The closed values `yes`/`no` are quoted strings (`"yes"`, `"no"`), never YAML booleans. Regex values are single-quoted POSIX ERE.
- Dates are `YYYY-MM-DD`. Hashes in links are 40-hex.
- `HUSKY=0` is not restated here: see INTERFACES part A.7 (one statement).

## 2. The FILL_IN_BEFORE_DISPATCH sentinel convention
- A value that is neither measured by an explorer (`facts.md` row `measured: <cmd -> result>`) nor answered by the human (cite the `brief.md` line) is the bare scalar `FILL_IN_BEFORE_DISPATCH`; a list key is `[FILL_IN_BEFORE_DISPATCH]`. Never a guess, never a default of the author's own.
- Every sentinel is listed in `brief.md` `## Open items` (key, what must be measured or decided, who answers) or as a `cannot measure:` row in `facts.md`.
- `delivery-dispatch-plan` and `delivery-run` Step 0 refuse to dispatch while `grep -c FILL_IN_BEFORE_DISPATCH <profile>` is above 0 for a key the sub-task reads (the section 6 checklist is the per-key list).
- `release_tags.used` is never a sentinel: measure it (`"no"` when the repo uses no release tags). With `used: "yes"`, an absent `pattern` or `approval` is a defect (`REJECTED policy`, A.2.2 malformed entry), so there they are sentinels until answered.

## 3. Skeleton (copy, then replace each sentinel only with a measured or answered value)
```yaml
# repo-profile.md  (writer: delivery-intake; sole authority, D22)
profile_version: 1
measured_utc: FILL_IN_BEFORE_DISPATCH        # YYYY-MM-DDTHH:MM:SSZ of the last full measure
project_root: FILL_IN_BEFORE_DISPATCH        # a feature worktree, never the main checkout
worktree_base: FILL_IN_BEFORE_DISPATCH       # abs path under $DELIVERY_ROOT (A.2.2)
clones: [FILL_IN_BEFORE_DISPATCH]            # abs clone roots on this machine (A.2.2)
linked_profiles: []                          # primary only: {clone: <abs>, profile: <abs>@<40-hex>} per other repo
repo: {name: FILL_IN_BEFORE_DISPATCH, type: FILL_IN_BEFORE_DISPATCH, package_scope: FILL_IN_BEFORE_DISPATCH, consumer_repos: [FILL_IN_BEFORE_DISPATCH], registry: FILL_IN_BEFORE_DISPATCH}
commands:                                    # exact strings, run from project_root
  install: FILL_IN_BEFORE_DISPATCH           # --frozen-lockfile --ignore-scripts form
  install_rebuild_allowlist: [FILL_IN_BEFORE_DISPATCH]
  lint: FILL_IN_BEFORE_DISPATCH
  typecheck: FILL_IN_BEFORE_DISPATCH
  test: FILL_IN_BEFORE_DISPATCH
  build: FILL_IN_BEFORE_DISPATCH
  pack: FILL_IN_BEFORE_DISPATCH
  clean: FILL_IN_BEFORE_DISPATCH
  release: FILL_IN_BEFORE_DISPATCH
  publish: FILL_IN_BEFORE_DISPATCH
gates:                                       # A.2.2, gate runner (A.7)
  command: FILL_IN_BEFORE_DISPATCH           # with the tool's --base/--head/--parallel forms
  parallel: FILL_IN_BEFORE_DISPATCH          # int
  min_free_kb: FILL_IN_BEFORE_DISPATCH       # int
  runner_slots: FILL_IN_BEFORE_DISPATCH      # int
node: {prefix_cmd: FILL_IN_BEFORE_DISPATCH}  # one-shot activation of the pinned Node (A.2.2)
pr:
  author_identity: FILL_IN_BEFORE_DISPATCH   # R2-4
  approval_rule: FILL_IN_BEFORE_DISPATCH     # R2-4; who may approve (H-pr is another human)
  template_path: FILL_IN_BEFORE_DISPATCH
  label_rules: FILL_IN_BEFORE_DISPATCH
  commit_pattern: FILL_IN_BEFORE_DISPATCH    # single-quoted ERE
merge_method: FILL_IN_BEFORE_DISPATCH        # squash|merge|rebase (A.2.2)
merge_route: FILL_IN_BEFORE_DISPATCH         # D5
merge_reach: FILL_IN_BEFORE_DISPATCH         # one line: what a merge deploys (A.2.2, B3)
version_bump_rule: FILL_IN_BEFORE_DISPATCH   # checked by pre-pr-gate (C24)
plan_plane_pr: FILL_IN_BEFORE_DISPATCH       # M22
ci:
  system: FILL_IN_BEFORE_DISPATCH
  status_read_skill: FILL_IN_BEFORE_DISPATCH
  required_checks: [FILL_IN_BEFORE_DISPATCH] # names as the host sees them (A.2.2)
  min_push_spacing_s: FILL_IN_BEFORE_DISPATCH      # int (A.2.2, M9)
  max_open_pr_pipelines: FILL_IN_BEFORE_DISPATCH   # int (A.2.2, M9)
merge_pipeline: {stages: [FILL_IN_BEFORE_DISPATCH]}   # ordered stage names (A.2.2)
secrets:
  pattern_file: FILL_IN_BEFORE_DISPATCH      # abs path of an ERE file, one pattern per line (M31)
  retrieval_env_vars: [FILL_IN_BEFORE_DISPATCH]   # env-var NAMES only, never values
zephyr: {read_ops: [FILL_IN_BEFORE_DISPATCH], execute_tool_name: FILL_IN_BEFORE_DISPATCH}   # B2
test_management_tool: FILL_IN_BEFORE_DISPATCH
jira:
  project_key: FILL_IN_BEFORE_DISPATCH
  status_map: FILL_IN_BEFORE_DISPATCH        # map: Backlog|In Progress|In Review|Blocked|Verified|Done -> Jira status
  archive_status: FILL_IN_BEFORE_DISPATCH
release_tags:                                # N11; measured, never a sentinel for used
  used: "no"                                 # "yes"|"no"
  # pattern: '^...$'                         # required when used is "yes" (anchored ERE)
  # approval: none                           # none|human; required when used is "yes"
review_profile:
  mandatory_seats: [FILL_IN_BEFORE_DISPATCH]
  blocking_rules: FILL_IN_BEFORE_DISPATCH
  coverage_thresholds: FILL_IN_BEFORE_DISPATCH
sensitive_path_deny_list: [FILL_IN_BEFORE_DISPATCH]   # globs no unit may touch without a grant (M25)
lane_profile:                                # A5; ports are claimed per A.5.2, never auto-picked
  lanes_max: FILL_IN_BEFORE_DISPATCH
  ports: {bus_base: FILL_IN_BEFORE_DISPATCH, lane_base: FILL_IN_BEFORE_DISPATCH}   # candidates only
  dev_server_cmd: FILL_IN_BEFORE_DISPATCH
e2e:                                         # design 3.6
  harness: FILL_IN_BEFORE_DISPATCH           # nlta|none
  context_file: FILL_IN_BEFORE_DISPATCH
  plugin_source: FILL_IN_BEFORE_DISPATCH
  prefix: FILL_IN_BEFORE_DISPATCH
  auth_mode: FILL_IN_BEFORE_DISPATCH
  mock_gate: FILL_IN_BEFORE_DISPATCH
  dist_scan_cmd: FILL_IN_BEFORE_DISPATCH     # run by pre-pr-gate (C25)
  remotes_resolution: FILL_IN_BEFORE_DISPATCH
  serve_targets: [FILL_IN_BEFORE_DISPATCH]
durations:                                   # minutes, measured (M15); budgets derive from these (A.2.2, A.4)
  pr_review_min: FILL_IN_BEFORE_DISPATCH
  ci_round_min: FILL_IN_BEFORE_DISPATCH
  unit_median_min: FILL_IN_BEFORE_DISPATCH
```

## 4. Unmeasured fields (each is a sentinel until measured or answered)
| Field(s) | Why it is unmeasured by default | Who answers |
|---|---|---|
| `project_root`, `worktree_base`, `clones[]` | machine-specific | explorer plus human confirm |
| `measured_utc`, `repo.*`, `commands.*` | read from `package.json`, task runner, docs; absent command = ask | explorer |
| `gates.parallel`, `gates.min_free_kb`, `gates.runner_slots`, `gates.command`, `node.prefix_cmd` | machine and tool specific; the human picks (M8) | human |
| `pr.author_identity`, `pr.approval_rule`, `merge_method`, `merge_route` | hosting-service settings are `cannot measure` | human |
| `merge_reach`, `merge_pipeline.stages[]`, `ci.required_checks[]` | read from workflows; the host's required-check list is not readable | explorer plus human |
| `ci.min_push_spacing_s`, `ci.max_open_pr_pipelines` | docs or ask (M9) | human |
| `secrets.pattern_file`, `secrets.retrieval_env_vars[]` | scanner config, else ask (M31) | explorer / human |
| `zephyr.*`, `test_management_tool`, `jira.*` | the tool lives outside the repo | human |
| `review_profile.*`, `sensitive_path_deny_list[]` | policy, not code (M25) | human |
| `lane_profile.*` | machine resources and free ports; claimed at launch per A.5.2 | human |
| `e2e.*` | harness wiring is repo-specific (design 3.6) | explorer plus human |
| `durations.*` | no local run history until a first cycle (M15) | measured after a run |
| `version_bump_rule`, `plan_plane_pr`, `pr.template_path`, `pr.label_rules`, `pr.commit_pattern` | docs or ask | explorer / human |

## 5. Rules
- A missing A.2.2 key fails the reader's Step 0 as `INPUT-ERROR <key> missing`; the sole exception is `release_tags.*` (absent = tag-push refused, A.2.2).
- `linked_profiles[]` entries pin `@<40-hex sha>`; a linked profile is read at its pin.
- Refresh: start from the existing file, re-measure measured keys, keep human-answered keys unless the human changes them, report every change in `brief.md`; the new file gets a new `hash-object` sha and a new `PROFILE:` line (D1.1).
- A hq `wave-execution` port dropped command-token registries on purpose; this file is the caller-side home for them.

## 6. Pre-dispatch checklist
- [ ] `grep -c FILL_IN_BEFORE_DISPATCH <profile>` is 0, or each remaining sentinel is outside the keys this sub-task reads and is listed in `brief.md` `## Open items`.
- [ ] Every A.2.2 key is present (value, answer or sentinel); `"yes"`/`"no"` quoted; regexes single-quoted.
- [ ] `release_tags.used` is set; `pattern` and `approval` present when `"yes"`.
- [ ] `project_root` is a feature worktree, not the main checkout.

---

# Appendix 5.8b: <pilot-app> seed (D13; verified 2026-10-26 against the cited sources; every row is re-verified at move)

Writer / Reader: `delivery-intake` copies rows it re-measures into the <pilot-app> profile; this appendix is evidence for the pilot, not a profile. Source paths are under the context store (`XC/projects/<platform-capabilities-project>`) unless stated. Unmeasured items stay sentinels in the real profile.

| Field | Value | Source | Re-verify |
|---|---|---|---|
| Repo, type | `<app-repo>`; NX monorepo of Module Federation MFEs (rspack), about 4 host shells and about 23 remotes, consuming `<platform-repo>` generators and packages | `playwright-generator/02-repo-findings-<app>-overview.md`, `meta.md` | re-verify at move |
| Toolchain | Node `v22.13.0` via `.nvmrc`, pnpm `9.15.3` pinned, NX `20.3.3` exact; `nvm use` runs inside each worktree before any node or pnpm command (activation does not carry over) -> `node.prefix_cmd` | `contribution-guidelines/00`; `shared/conventions.md` | re-verify at move |
| Branching | Trunk-based; branch `<JIRA-KEY>` or `<JIRA-KEY>-<desc>`; every branch carries a Jira key; PR to `main`; no release branches; hotfix flow is human-only | `contribution-guidelines/02` section A | re-verify at move |
| Hooks | `pre-commit`: `pnpm nx affected -t lint test typecheck --parallel=9` (10+ min); `prepare-commit-msg`: interactive commitizen against `/dev/tty`. `HUSKY=0` rule: INTERFACES part A.7. D21/R2-3: run `pnpm nx affected -t lint test typecheck` once per push or batch and record `GATE-PASS` | `contribution-guidelines/00`, `04` section A | re-verify at move |
| PR open pipelines (Harness, org `<harness-org>`, project `<harness-project>`) | `<pr-build-pipeline>`, `<pr-standards-pipeline>` (app repos get the broader check), `<pr-sonar-pipeline>`; `<pr-branch-deploy-pipeline>` deploys the PR to a per-user Zephyr tag | `shared/architecture-04-cicd.md`, `contribution-guidelines/02` section A | re-verify at move |
| PR merge pipeline and `merge_reach` | `<merge-deploy-pipeline>` (`<merge-pipeline>.yaml` in `<platform-cicd-repo>/.harness/<pipeline-dir>/apps/default/`): NX set SHA (`NX_BASE=HEAD~1`), setup, E2E check, pre-prod Zephyr build (`WITH_ZE=1`), pre-prod S3 build and upload, production S3 build with `ALLOW_DEPLOYMENT_CHECK=true` exported inline in that step (not a pipeline variable; foundations-owned, human-only, D23), then `<prod-s3-upload-step>` east and west in parallel. `<deployment-check>` fails the production build for any affected app under `apps/` (excluding `apps/examples/` and any `e2e` path) whose `package.json` `version` equals the merge-base version; bump direction is not checked. S3 is the secondary backup; live production is the human Zephyr promotion. A merge reaches the production S3 backup; the human approving review covers that (R2-5). Known bug: `<prod-s3-upload-step> East` lacks `stripPrefix` | `shared/architecture-04-cicd.md:47-54`; `shared/open-questions.md:46-47`; `shared/architecture-05-platform.md:13-19`; `XC/projects/<pipeline-cleanup-project>/shared/architecture.md:75-90`; `XC/projects/<semver-project>/decisions/<deployment-check>.md` | re-verify at move |
| PR author and approval (R2-4) | PRs, pushes and Jira writes use the operator's own locally configured auth; no bot, no approved-account list. The PR author is the operator, GitHub forbids self-approval, so H-pr is an approving review by another human (CODEOWNERS teams `<platform-team>`, `<zephyr-team>` for the platform repo; <pilot-app>'s own CODEOWNERS and branch protection unmeasured) | `contribution-guidelines/04` section A; `owner-decisions.md` R2-4 | re-verify at move |
| Version-bump rule | Every sub-task that affects an app under `apps/` (excluding examples and e2e) bumps that app's `package.json` `version` in the same PR; the dispatch plan lists affected apps per sub-task; `pre-pr-gate` checks it (C24); no bump for unaffected apps | `<semver-project>/decisions/<deployment-check>.md` | re-verify at move |
| Plan-plane PR (M22) | Sub-task 0 commits `plans/<epic>/*`, `contracts/`, `.tasks/` first in merge order; acceptability of `contracts/` and `.tasks/` at the repo root is confirmed with the repo owners at P0 | design | re-verify at move |
| Known CI failure modes | Sonar capacity-induced failures (concurrent scans; <JIRA-KEY>-2281 scopes the scan, ceiling unresolved), legacy smells on `main` blocking unrelated PRs, Harness "No tasks were executed" false failures; `<prod-s3-upload-step> East` missing `stripPrefix` | `contribution-guidelines/04` section C; `architecture-04-cicd.md` Known Pipeline Bugs | re-verify at move |
| Release and environments | Merge auto-deploys to DEV2; DEV2 to DEMO manual in 9:00 and 12:00 EST windows; DEMO to RGR to STAGE to PROD manual with Staff/Principal approval in Zephyr; Zephyr primary, S3 secondary, Fastly in front; tags and environments keep change logs with the actor; a protected environment restricts updates to listed members | `contribution-guidelines/02` section A; `shared/architecture-05-platform.md`; `zephyr-summary.md` 4-5 | re-verify at move |
| Review profile | PR template (description, type, test steps, screenshots, checklist, Jira link) read by `create-pr`; CODEOWNERS and branch protection unmeasured; automated reviewers never approve; generator or shared-package changes add the Generator/migration seat (`migration-assessment`, `pr-check-migration-needed`) | `contribution-guidelines/04` section A, `03` | re-verify at move |
| Shared-file owners | Root `package.json` is the version authority and auto-singletons root deps; `neat-*` not singleton; `tailwind-merge` excluded from sharing; zustand singleton; no `eager` remotes; remote versions resolved at runtime via Zephyr. Root manifest, lockfile and MF shared config have exactly one owning unit per sub-task | `contribution-guidelines/05`; `architecture-06-remote-state-zustand.md` | re-verify at move |
| Testing | Digital Test Pyramid: Jest/Vitest unit, mandatory contract tests, E2E stage first in the merge pipeline (post-merge); whether Tier 1 e2e also runs on the PR is unmeasured (M24); Tier 2 nightly, Tier 3 HeadSpin real devices; e2e authored via NLTA (D17); reference `apps/banners-e2e` | `contribution-guidelines/04` section B; `playwright-generator/02` | re-verify at move |
| Skills the desk wraps | `create-pr`, `package-release`, `migration-assessment`, `dft-monorepo-mfe-setup` (at the work machine's `~/.claude/skills`) | `contribution-guidelines/03`, `04` | re-verify at move |
| Unmeasured, verify at move | merge method (squash vs merge); required-check names as GitHub sees them; branch protection; Zephyr and Harness credentials and which session holds them; whether the NLTA plugin is installed; whether `nl-context-provider.json` exists; Tier 1 e2e wiring to the merge pipeline's E2E stage; Jira project key for the pilot epic; Zephyr MCP identity (whose OAuth), read-only or protected-environment setup, live OpenAPI location and exact read operations (a signed-in `search` at P0), rate limits, the `execute` and `search` tool names as Claude Code exposes them (B2); CODEOWNERS and a second human reviewer (R2-4, M6); Harness stale PR and branch cleanup thresholds (M4); per-user Zephyr tag derivation (M9); whether NLTA skills run non-interactively in a subagent (M23); acceptability of `contracts/` and `.tasks/` at the repo root (M22); `gates.runner_slots`, install and `nx affected` durations (M8) | n/a | each is a `FILL_IN_BEFORE_DISPATCH` in the real profile; re-verify at move |
