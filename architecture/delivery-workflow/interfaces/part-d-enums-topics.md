# INTERFACES.md part D: enums, topics, planes, change control

- **Status:** draft, pending 2b review (design §7 item 2). Integrated 2026-10-26; every former `OPEN` is resolved with a one-line rationale; `DEFAULT (integrator)` marks a choice the design does not imply (logged in `INTERFACES.md`).
- **Sources:** design v2 §2 intro, §2.2, §2.3, §2.4, §3.0, §3.1, §4, §5.0, §5.6, §5.8, §5.11, §6.3, §6.4; ADR 0054 (gate types); part A (schemas), part B (verbs), part C (waves, control).

## D1. Step 0 input validation (M22)

- Every delivery skill (15 NEW, 5 EXTEND) names its inputs; Step 0 validates them against D2 and prints `INPUT-ERROR <field> <reason>` with `reason` in `missing|enum|path|unset|format|sha` (`format`: a value fails its regex; `sha`: a `@<sha>` does not match `git hash-object` of the file, AM-4 20; `DEFAULT`: a reason part is added), line regex `^INPUT-ERROR [A-Za-z_][][A-Za-z0-9_.]* (missing|enum|path|unset|format|sha)$` (the bracket class admits `[]`, so `ci.required_checks[]` is a valid field; row R4-J7), **one line per failing field, then stops**; no retry, no prompt (`DEFAULT`: a skill that asks would stall unattended runs, part C7 PROMPT-OPEN). An `INPUT-ERROR` response carries no verdict: it counts as neither a D7 round nor a `fix-verifier` iteration and gets no `verify-*` record; the caller fixes the input and re-dispatches with the same iteration number (AM-4 11-Q11-R1).
- `DELIVERY_ROOT` unset is `INPUT-ERROR DELIVERY_ROOT unset` (M12).
- **Regex dialect (`DEFAULT (integrator)`, row R4-J5):** every regex in parts A-D is POSIX ERE (`grep -E`, bash `[[ =~ ]]`): numbered groups only, POSIX classes such as `[[:space:]]`; `\|` inside a Markdown table cell is Markdown escaping of `|`, not part of the regex; `\t` in a regex stands for a literal TAB.

### D1.1 Output token rule (`DEFAULT (integrator)`)

A token is **line 1 of its record file**, or the last stdout line when the skill writes no file; a token whose Carrier names a file is only written there, never printed instead. Each token matches its anchored regex; producer and consumer are the D2.2 row and the reader named here.

| Token | Regex | Carrier | Consumer |
|---|---|---|---|
| `ARCH:` | `^ARCH: ready$` | `review-architecture.md` line 1 | conductor |
| `RUNG:` | `^RUNG: (0\|1\|2\|2b\|3\|4) seats: [0-9]+$` | `RUN_HOME/review-tailor-<slug>.md` line 1; lines 2+ the seat table `seat-id<TAB>role<TAB>reason`, from which `pr-review` `ROLES` derives; written by `review-tailor` itself under the caller-minted `SLUG` (part A.1); the seat table runs to the first blank line; then the lines `mechanism:`, `tiers:`, `budget:`, `dispatch:`. Seat counts: Rung 0 = 0, Rung 1 = 1, Rung 2 at most 9, 2b at most 7, 3 = 7, 4 = 11 (AM-2 row 9, PC-10). A profile-mandatory seat outside a fixed-count rung's set is noted in the `mechanism:` line and the seat set stays fixed (D12, RT-Q1); a high-blast-radius code diff stays at Rung 3 and the one-way decision behind it is reviewed separately as `KIND=plan` at Rung 4 (RT-Q2) (AM-4 16) | caller of `review-tailor`, `pr-review` |
| `PROFILE:` | `^PROFILE: (/[^[:space:]]+)@([0-9a-f]{40})$` | last stdout line of `delivery-intake` (it writes no record file for it); the path is the profile created or refreshed (part A.6); `<sha>` is the git blob id of the profile file, `git -C <primary_repo> hash-object -w <path>`; a reader verifies `git hash-object <path>` or reads `git cat-file blob <sha>` (AM-2 row 4, PC-9) | conductor (copies it to `state.md` `repo_profile`, part A.2) |
| `PLAN-CHECK:` | `^PLAN-CHECK: (clean\|[0-9]+ findings)$` | `plan-check.md` line 1 | conductor |
| `PLAN-REVIEW:` | `^PLAN-REVIEW: STOP round-3$` | the review section of `dispatch-plan.md`, written by `delivery-dispatch-plan` when the plan's review loop hits the D7 cap (the 29-23 marker, AM-6 g) | conductor (stage 3 round-3 detection) |
| `PREPR:` | `^PREPR: (PASS\|STOP( [A-Za-z0-9.,-]+)?)$` (`<rows>` = comma-separated failed checklist ids `C1`-`C26` (`C1`-`C23` the §5.7 rows in order, `C24` version bump, `C25` dist scan, `C26` `validate-findings.cjs`), defined in the `step-completeness-checklist.md` template; AM-2 row 8, PC-8) | `review/<subtask>/checklist-<subtask>.md` line 1; copied to `substate.md` `prepr` | lead, conductor |
| `INTEGRATED:` | `^INTEGRATED: u[0-9]+ [0-9a-f]{40}$` | not a bus record: an entry of `substate.md` `integrated` written by the lead from the Integrator's C2 record (`unit` `i<N>` written as `u<N>`, `head`), one record per merged unit (part A.3) | conductor |
| `LANE:` | `^LANE: (PASS\|FAIL)$` | not a second output_schema: the lane runner's C2 record with `verdict` PASS (`LANE: PASS`) or ESCALATE/ROLLED with a reason (`LANE: FAIL`); the line is also written as `lanes/<lane>.md` line 1 | lead |
| `CI:` | `^CI: (GREEN [0-9a-f]{40}\|HUMAN [a-z0-9-]+)$` (`HUMAN` reason = a D2.2 row 11 class token or `budget`) | `ci/<pr>.md` line 1; copied to `substate.md` `ci` | lead, conductor |
| `POSTMERGE:` | `^POSTMERGE: (PASS\|FAIL)( [A-Za-z0-9.,-]+)?$` (PASS = every gating row passed; rows = failed gating row ids) | `postmerge-<sha>.md` line 1 | conductor (maps PASS to `Verified`), `release-track` |
| `RELEASE:` | `^RELEASE: (LIVE\|ROLLED-BACK\|WAITING-HUMAN)$`; `LIVE` and `ROLLED-BACK` are terminal, `WAITING-HUMAN` is rewritten atomically (A.1) when the state changes (row R4-J18) | `release-<sha>.md` line 1 | conductor (stage 8 and `pm` cleanup start only on a terminal token, part C5.1) |
| `CLEANUP DONE` | `^CLEANUP DONE (st[0-9]+\|pm\|final)$` | `cleanup-<run-id>-<subtask\|final>.md` line 1 | conductor |
| `FACTS:` / `DRAFTS:` | `^FACTS: [0-9]+ facts$` / `^DRAFTS: [0-9]+ drafts$` | `facts.md` line 1 / `drafts/index.md` line 1 | `delivery-architecture`, `ticket-clerk` |
| `TICKET-EVENT` | D3 | `RUN_HOME/ticket-events.log`, one line per event | `ticket-clerk` |

## D2. Enum tables

### D2.1 Shared enums

| Field | Allowed values | Source |
|---|---|---|
| `persona` | kebab-case token of the §3.1-§3.3 display name (`architecture/delivery-workflow/part-03-personas-and-concurrency.md:10-44`): `conductor`, `lead`, `review-orchestrator`, `review-seat`, `synthesizer`, `gate-checker`, `implementer`, `test-writer`, `e2e-writer`, `fixer`, `fix-verifier`, `integrator`, `explorer`, `plan-checker`, `prefactor`, `docs-writer`, `migration-specialist`, `lane-runner`, `shepherd`, `catalog-keeper`, `cleanup-executor`, `validator`, `clerk`, `desk`, `capture-agent`, `read-back`, `grill-facilitator`, `architect`, `ticket-decomposer`, `review-tailor`, plus `gate-runner` (part A.7), `security-auditor` (full-audit hunters and verifiers, part A.4; amendment AM-1) and `wave-controller` (the background Agent task that runs `wave-execution` for the lead; slot row only, no brief file, AM-4 W2-2); closed set (the brief-file mapping excepts `wave-controller`); `explorer` is mechanical tier by default and execute tier for multi-step derivations (AM-4 27b); it names the slot row field, the `waves/` `persona` field and `skills/delivery-run/references/briefs/<persona>.md` (`DEFAULT (integrator)`) | §3.1-§3.3 |
| `tier` | `design`, `execute`, `verify`, `mechanical` (models only via `tools/model-routing.md` or `repo-profile.md`). The fixer is design tier (design §3.4), not the verify grouping of §3.1 (errata E25); a fixer failure escalates one MODEL step per ADR 0014 T1, never a third top-model attempt, not "one tier up" (AM-4 27b, correcting E25's wording) | §0.1, M19 |
| `BACKEND` | `agent-tool`, `claude-p` | §6.4 |
| `stage` | `1`, `2`, `3`, `4`, `4b`, `5`, `5a`, `5b`, `5c`, `6`, `7`, `8`, `done`, `stopped` | §1, part A.2 |
| `gate` | `H0`, `H1`, `H-e2e`, `H-pr`, `H-prod` | §0.1, §5.0 |
| H1 verdict | `ok`, `changes`, `reject` (the B8 `GATE` verdict token; files `H1.ok`, `H1.changes`, `H1.reject`, part A.2.1) | §1 stage 2 |
| `rung` | `0`, `1`, `2`, `2b`, `3`, `4` | `tools/review-ladder.md`, §2.4 |
| `kind` (review-tailor) | `doc`, `plan`, `diff` | card 4 |
| `stakes`, `contention`, `novelty` (review-tailor) | `reversible\|one-way`; `none\|contested`; `known\|novel` (`DEFAULT`, the ladder rubric's three axes) | card 4, `tools/review-ladder.md` |
| failure class (unit) | `Cosmetic`, `Structural`, `Systemic` | §1 back-edges |
| e2e per unit | `new`, `updated`, `none` | §5.3 |
| `e2e.harness` | `nlta`, `none` | §5.8 |
| ticket issue type | `Epic`, `Spike`, `Story`, `Task`, `Subtask` | §1 stage 2 |
| release step owner | `agent`, `human` | §5.5, D15 |
| post-merge row | `gating`, `informational` | §5.4 |
| `UNIT-VERDICT` `verdict` / `reason` | part C2 | |
| `subtasks[].state` | `planned\|released\|building\|pr-open\|merged\|stopped\|cleaned` | part A.2 |
| `stop_reason` | part A.3 | |
| conductor message | `RELEASE <subtask>`, `INVALIDATE <subtask> <reason>`, `reason` in `predecessor-reentered\|predecessor-rebased\|contract-changed\|plan-changed`; `ANSWER <run-id> <subtask> <unit> <text>` (desk-written); `INBOX <subtask>` (SendMessage wake-up pointer); `MERGED <subtask> <merge_sha>` (`^MERGED (st[0-9]+) ([0-9a-f]{40})$`, inbox type `merged`); `NUDGE ...` (C7 template) | part C5, C6, C7 |
| lead message | `REGISTER <run-id> <subtask> <identity> <session>` (`outbox/register`); `CONDUCTOR-REQUEST <run-id> pm <seq> <verb> <fields-json>` (`pm/outbox/<seq>.conductor-request`, `DEFAULT (integrator)`) | part C5.1 |
| conductor to desk | `REGISTER-SENDER <run-id> \| <subtask\|run> \| <sender-id>`; reply `REGISTERED <run-id> \| <subtask\|run> \| ok\|refused` (desk-held sender registry, owner 2026-10-26, OP3 B, `architecture/delivery-workflow-sources/owner-decisions.md:65`) | part B1 |
| human desk line | `GATE <run-id> <gate> <verdict> <text>`, `ANSWER <run-id> <subtask> <unit> <text>` | part B8 |
| `substate.md` `phase` | `seeded\|building\|integrating\|prepr\|pr-open\|ci\|merged\|post-merge\|release\|done` | part A.3 |
| `<run-id>`, `<subtask>`, `session_id`, `session` | `<epic-key-lowercased>-<yyyymmdd>` `^[a-z0-9-]+$`; `^(st[0-9]+\|pm)$` (plus `run` in desk ids and catalog rows); `<run-id>-<subtask>` (bus only); launcher session name `^[a-z0-9-]+$` (machine row, `subtasks[].session`) | part A.1 |
| token shapes | sha 40-hex; unit `^u[0-9]+$`; Integrator work_item `^i[0-9]+$` (unit fields `^[ui][0-9]+$`); `agent_id` `^[a-z0-9-]+$`; `step_id`; `JIRA-KEY`; `<epic>` | part A.1 |
| catalog `kind`, `state`, audit class | part A.5; audit `MATCH`, `GHOST`, `SQUATTER` | §5.6 |
| desk verbs, reason codes and class | part B4, B2.1 (ten codes, each terminal or curable; owner 2026-10-26, OP5 B, OP10 A, `owner-decisions.md:67`, `:72`) | |
| `security_audit` (`SECURITY_AUDIT`) | `guidance\|full`; `guidance`: the security seat loads `skills/security-audit` diff-scoped, writes no file, launches no agent; `full`: only on an explicit operator request or a `security_sensitive: yes` epic, per part A.5.3 (amendment AM-1; owner 2026-10-26, security-audit integration) | part A.2 `security_audit` |
| `gate_type` | `exit_criteria`, `adversarial_verify`, `judge_panel`, `step_complete` | ADR 0054 A4 |
| `method` (pr-merge) | `squash`, `merge`, `rebase`, equal to the profile's `merge_method` | part B4 |

### D2.2 The 15 NEW skills

**Input transport (`DEFAULT (integrator)`):** every named input is an UPPER_SNAKE identifier, passed as `NAME=value` in the skill's arguments, except `DELIVERY_ROOT`, which is the environment variable only, and the one named exception `resource-catalog` (row 8), whose `RUN_HOME` is the environment variable because `catalog.sh` requires it there (INTERFACES.md script table); `(path)` = absolute path, `(sha)` = 40-hex, `(@sha)` = `<abs path>@<sha>`; Step 0 prints `INPUT-ERROR <NAME> <reason>` with exactly these names and every caller passes them. `RUN_HOME` is `$DELIVERY_ROOT/<run-id>` (part A.1); a skill that writes under a sub-task takes `SUBTASK`.

| # | Skill | Named inputs (Step 0) | Enumerated fields | Output tokens |
|---|---|---|---|---|
| 1 | `delivery-pipeline` | `DELIVERY_ROOT` (env); `INTENT` (text) with `PRIMARY_REPO` (path; the primary repo clone root, named by the human at stage 1, part A.1; required with `INTENT`, `DEFAULT (integrator)`), or `RUN_HOME` (path; an existing directory under `$DELIVERY_ROOT` that contains `state.md`; anything else is `INTENT`; `DEFAULT`) | `stage`, `gate`, H1 verdict, `BACKEND` | conductor `DESK` verbs `pr-merge`, `pr-approval-state`, `publish`, `tag-push`, `test-report-push`, epic `jira-create` (part B1, B4; the `publish`, `tag-push`, `test-report-push` ones on a `CONDUCTOR-REQUEST`, part C5.1); one status post per gate; `state.md` path printed at end of turn |
| 2 | `delivery-intake` | `DELIVERY_ROOT` (env), `RUN_HOME` (path) and `PLANS_DIR` (path), both created by the conductor at stage 1 (part A.2), `PRIMARY_REPO` (path, passed on from row 1), `INTENT` (text) | none | `FACTS:`, `PROFILE:` (D1.1); `H0` recorded by the desk |
| 3 | `delivery-architecture` | `RUN_HOME` (path), `PLANS_DIR` (path; holds `brief.md`, `facts.md`), `REPO_PROFILE` (@sha) | `rung`; issue type | `ARCH: ready`; `DRAFTS:` (D1.1) |
| 4 | `review-tailor` | `RUN_HOME` (path), `SLUG` (`<subtask\|run>-<kind>-<n>`, part A.1), `ARTIFACTS` (comma-separated paths), `KIND`, `STAKES`, `CONTENTION`, `NOVELTY`, `SECURITY_AUDIT` (AM-1; the seat table names the security seat's mode), `ORCHESTRATOR_TIER` (from `state.md` `orchestrator_tier`, part A.2; the +1 rung modifier applies when it is not `design`; AM-3 errata (g)) | as D2.1 | `RUNG:` plus seat table (D1.1) |
| 5 | `delivery-dispatch-plan` | `RUN_HOME` (path), `PLANS_DIR` (path; holds `architecture.md`, `drafts/`), `REPO_PROFILE` (@sha), optional `NEW_UNITS` (path of `RUN_HOME/pm/new-units.md` on a post-merge re-entry, part A.2); reads `RUN_HOME/tickets.tsv` | e2e per unit; `tier`; `BACKEND`; `persona` | `PLAN-CHECK: clean` or `PLAN-CHECK: n findings`, written by the Plan-checker it dispatches (part C1.3) |
| 6 | `delivery-run` | `DELIVERY_ROOT` (env), `RUN_HOME` (path), `SUBTASK`, `MODE` `build\|plan-pr\|post-merge` (part A.2), `BACKEND`, `PLANS_DIR` (path; holds `dispatch-plan.md` and the seed), `REPO_PROFILE` (@sha), `REPO` (path; the sub-task's clone, the dispatch-plan sub-task table `repo`), `SESSION` (launcher session token, part A.1; for the `REGISTER` line and machine row), `PM_SHA` (sha; required when `MODE=post-merge`), `SECURITY_AUDIT` (`guidance\|full`, from `state.md` `security_audit`, passed on to `pre-pr-gate` and `pr-review`; AM-1), all passed by the conductor from `state.md` (`repo_profile`, `merge_sha` of the last sub-task) and the dispatch plan (row R4-J16); `substate.md` is derived (`RUN_HOME/<subtask>/`). Step 0 also compares the dispatch-plan header `interfaces_version` (and, in mode `build`, the seed copy's) with `state.md` `interfaces_version` and stops with `INPUT-ERROR interfaces_version format` on a mismatch (row R4-J23) | `BACKEND`; `gate_type: step_complete`; `session_id` | `UNIT-VERDICT` (part C2); `INTEGRATED:` and `LANE:` (D1.1); desk requests `push`, `pr-create`, `pr-attach`, `pr-comment`, `fetch` (part B4); `REGISTER`; the watchdog half `STALLED`, `PROMPT-OPEN` (part C7) |
| 7 | `delivery-shepherd` | `RUN_HOME` (path), `SUBTASK`, `PLANS_DIR` (path); status files, worktree list and slot rows are derived | flags `DRIFT`, `CREEP`, `FREE-CANDIDATE`, and `STALLED`, `PROMPT-OPEN` alongside the `delivery-run` watchdog half (part C7; AM-3, owner OQ-3) | `shepherd/ticks.md` line on change only |
| 8 | `resource-catalog` | `RUN_HOME` (env, as `catalog.sh`), then the `catalog.sh` positional arguments (INTERFACES.md script table) | `kind`, `state`, audit class | one TSV row |
| 9 | `delivery-cleanup` | `RUN_HOME` (path), `MODE` (`subtask\|final`), `SUBTASK` (required for `subtask`, omitted for `final`), `MERGE_RECORD` (path of `merge-<sha>.md`; mode `subtask` for `st<N>` only; evidence for `pm` and `final` per part C5.1); `catalog.tsv` derived; approver the sub-task lead (mode `subtask`) or the conductor (mode `final`), executor a separate mechanical-tier agent; desk `branch-delete`, `fetch` | `mode` | `CLEANUP DONE <subtask\|final>` (D1.1) |
| 10 | `pre-pr-gate` | `RUN_HOME` (path), `SUBTASK`, `HEAD` (sha of the rebased branch), `WORKTREE` (path), `REPO_PROFILE` (@sha), `SECURITY_AUDIT` (AM-1); checklists and gate evidence derived | `security_audit` | `PREPR:` (D1.1); consumes the review record `record-<head>.md` (part A.6); under `full`, runs the audit into `security-audit/run-<N>/` and the `validate-findings.cjs` gate row (part A.5.3). Loop decisions (AM-4 20): a sensitive-path hit passes only with a desk `INSTALLED` row or a `grant.<subtask>.<n>.ok` file (A.2.1); the gate's review loop runs a plan-check before round 1 (D55); a failure outside the review loop is `PREPR: STOP <id>`, never handed to the fixer; `fix-verifier` also verifies the G48 pre-round fixes; after the second per-review bus-port refusal the gate writes `PREPR: STOP C12` (`C12` = ports claimed, the checklist template's port row; AM-6 B-7) and the lead writes `stop_reason: port-refused`; "main" is the profile `default_branch` (A.2.2); a gate runner that dies holding its lease is released by the post-`TaskStop` orphan sweep |
| 11 | `ci-fix-loop` | `RUN_HOME` (path), `SUBTASK`, `REPO` (path), `PR` (int); required checks from the profile `ci.required_checks[]` (part A.2.2); budget fixed at 3 per signature, signature = diagnoser `class` + `job`; capacity-induced failures are `capacity:` lines in `ci/<pr>.md`, counted run-wide, outside the signature budget (AM-2 row 12) | diagnoser `class` tokens: `code-defect`, `deterministic-test`, `flake`, `infra-runner`, `missing-secret-or-permission`, `external-service`, `policy`, `commit-message-format`, `label-policy`, `static-analysis-gate`, `timeout`, `artifact-path`, `workspace-mismatch`, `approval-timeout` (`DEFAULT` kebab-case tokens for card 11's prose labels) | `CI:` (D1.1); desk requests `ci-status`, `ci-logs`, `ci-rerun`, `pr-comments-read`, `pr-comment` |
| 12 | `post-merge-verify` | `RUN_HOME` (path), `PM_SHA` (sha), `PLANS_DIR` (path; holds `test-plan.md`) (run by the `pm` lead, part A.2) | post-merge row | `POSTMERGE:` (D1.1); desk `ci-status-main`; on `FAIL`, `RUN_HOME/pm/new-units.md`, one line per failed gating row `<row-id> <one line>` (`^[A-Za-z0-9.-]+ .+$`), the carrier of the "new unit" into `delivery-dispatch-plan` `new_units` (`DEFAULT (integrator)`) |
| 13 | `release-track` | `RUN_HOME` (path), `PM_SHA` (sha), `PLANS_DIR` (path; holds `release-plan.md` v0), `POSTMERGE_RECORD` (path), `REPO_PROFILE` (@sha; `zephyr.read_ops`) | release step owner | `RELEASE: LIVE`, `RELEASE: ROLLED-BACK`, `RELEASE: WAITING-HUMAN`; `CONDUCTOR-REQUEST` lines in `pm/outbox/<seq>.conductor-request` (part C5.1); owner of `test-report-push` (PC-6, AM-2): writer of its payload `RUN_HOME/bodies/test-report-<step_id>.json` and requester of that verb through `CONDUCTOR-REQUEST` (stages 6-7 both run in the `pm` lead) (`DEFAULT (integrator)`). Owner answers (2026-10-26, `architecture/delivery-workflow-sources/owner-decisions.md` "release-track D7 stop", "Accept all"): the deploy/promote/rollback keyword check of the Zephyr hook is narrowed at P0 against the measured operation ids and refuses every `execute` until then (OQ-1); hook enforcement at the `pm`-lead session level is accepted for the pilot (OQ-2); the desk runs `publish` and `tag-push` only after the H-prod grant, frozen B4 stands (OQ-3) |
| 14 | `ticket-clerk` | `RUN_HOME` (path), `PLANS_DIR` (path; holds `drafts/` and `drafts/index.md`); `ticket-events.log` and its cursor derived (D3); runs only in the conductor session (part A.6) | desk verbs `jira-get`, `jira-create`, `jira-update`, `jira-transition`; field allowlist; status vocabulary | desk requests; `tickets.tsv` (part A.6) |
| 15 | `delivery-desk` | `DELIVERY_ROOT` (env); then the `DESK` line: id, verb, request path, sha256; `REGISTER-SENDER` lines (part B1); human lines `GATE`, `ANSWER` and `REBIND` (part B8) | verbs and reason codes (part B) | `DONE ...` or `REJECTED <id> \| <reason>`; gate files under `gates/`; inbox `answer` files |

E2E lane tokens: `LANE: PASS` or `LANE: FAIL` (§3.2; carrier D1.1). The NLTA failure classes (`SELECTOR_DRIFT`, `TIMING_BUG`, `TEST_BUG`, `SOURCE_BUG`, `ENV_BUG`, `AMBIGUOUS`) are **cited, not frozen**: they belong to the plugin (`DEFAULT`); `SOURCE_BUG` always escalates to the human (§3.6 step 6); the lane runner maps `SOURCE_BUG` to C2 reason `source-bug` and `ENV_BUG` to `env-bug`.

### D2.3 The 5 EXTEND skills

**Input transport (`DEFAULT (integrator)`, row R4-J22):** `wave-execution` keeps its snake_case names (they are spec and bundle fields or caller arguments of ADR 0054); every other EXTEND input is UPPER_SNAKE, passed as `NAME=value` as in D2.2.

| Skill | New named inputs | Enumerated fields | Source |
|---|---|---|---|
| `wave-execution` | `session_id`, `output_topic`, `bus_endpoint` (owner Q2, 2026-10-26, `owner-decisions.md:59`), `max_concurrent` (caller argument, owner 2026-10-26, ADR 0054 Q9, `owner-decisions.md:74`), caller inputs `invocation` (int) and `tier_override` (`<unit>=<tier>`, repeatable) (`DEFAULT (integrator)`, rows R4-J12, R4-J15; part C1.1), `persona`, `lane` (per work_item, Q10), `gate_type`, `depends_on`, `done_condition` (per work_item, Q2), `dispatch_budget`, `output_schema` | `gate_type` as D2.1; rules 13-15 (part C1.3) | ADR 0054, part C |
| `pr-review` | `ROLES` (comma list of seat ids; subset gated by D12), `SEAT_ID`, `RUN_ID`, `SUBTASK` (in-run identity for the review-bus path `RUN_HOME/review/<subtask>/<review-id>/bus/`, part A.1, D5; AM-5 10-B2), `BUS_PORT` (int 1-65535; the claimed per-review bus port, passed by `pre-pr-gate` from the port table; required when `RUN_HOME` is set, optional standalone (AM-5 10-B2); Step 1 runs the A.5.2 order with it and, on a refusal, exactly one claimed retry at `BUS_PORT + 10`, then stop the line; the same rule applies standalone; AM-2 row 7, PC-4, AM-3 OQ-2), `SECURITY_AUDIT` (AM-1: the security seat loads `skills/security-audit` in guidance mode, diff-scoped, no files, no extra agents; under `full` it also reads the latest `security-audit/run-<N>/findings.json`, `DEFAULT (integrator)`), `PR_REVIEW_MODE`, `STACK_BASE` and `STACK_HEAD` (sha; the stacked-PR base and head), `RECORD_PATH` (path; output: lines 1-2 of `record-<head>.md`, part A.6) | `PR_REVIEW_MODE`: `local-diff` (default in sandboxed tiers) or `pr` (the installed skill's GitHub mode; `DEFAULT` name); seat count 7 until the D12 remap and probe are recorded here | §2.3, D12 |
| `fix-verifier` | `FILE_SET` (comma list of repo-relative paths) | a change outside `FILE_SET` is `ISSUES_FOUND`; an `INPUT-ERROR` reply is not an iteration and writes no `verify-*` record (AM-4 11-Q11-R1) | §2.3, M24 |
| `doc-reviewer` | none (adds `references/delivery-doc-checks.md`) | DOC-label rules (AM-4 12): DOC-4, "a sub-task draft with no child unit draft" is Blocking and is checked under the DOC-4 label in the final sweep (AM-6 C-6); DOC-1 checks the single `security_sensitive: yes\|no` line once design §5.2 lists it (E29); DOC findings apply to delivery task specs only | §2.3 |
| `feature-change` | `UNIT_MODE` | `team` or `solo` (default `solo`, today's behaviour; `DEFAULT` name); branch `<JIRA-KEY>-<slug>` | §2.3, §3.0 |

## D3. Status vocabulary

- **Canonical ticket statuses:** `Backlog`, `In Progress`, `In Review`, `Blocked`, `Verified`, `Done` (§5.0). The profile maps them to Jira statuses (§5.8); the archive status is the profile key `jira.archive_status` (part A.2.2), requested as `to: archive`, not a seventh canonical value (`DEFAULT`).
- **Transitions (`DEFAULT (integrator)`, from the stage table):** these seven events are the status-event names `ticket-clerk` accepts, each mapped to one `jira-transition` `to`: `published` -> `Backlog` (publish after H1); `dispatched` -> `In Progress` (first unit dispatched); `prepr-pass` -> `In Review` (`PREPR: PASS`); `blocked` -> `Blocked` (D7 stop, `ESCALATE` or `INVALIDATE`); `unblocked` -> the prior status recorded in `tickets.tsv` (part A.6); `verified` -> `Verified` (`POSTMERGE: PASS`); `done` -> `Done` (CYCLE DONE); plus `archive` -> the profile's archive status (`to: archive`).
- **Event line:** `TICKET-EVENT <slug-or-key> <event>`, regex `^TICKET-EVENT ([a-z0-9-]+|[A-Z][A-Z0-9]+-[0-9]+) (published|dispatched|prepr-pass|blocked|unblocked|verified|done|archive)$`; writer the conductor (from `substate.md` and the stage table), appended to `RUN_HOME/ticket-events.log`; reader `ticket-clerk`, which records its position in `RUN_HOME/ticket-events.cursor` (part A.6). A unit maps to its ticket through the dispatch-plan unit table `ticket` column (part C1.2): `delivery-dispatch-plan` fills it from `tickets.tsv` (the latest row's `key`, else the draft slug, part A.1 `<slug>`); the conductor never edits the unit table and resolves a slug to a key through `tickets.tsv` (`DEFAULT (integrator)`). `ticket-clerk` runs only in the conductor session, so the log, the cursor and `tickets.tsv` each have one writer (part A.6).
- **Ticket parents (AM-4 22):** `tickets.tsv` `parent` column holds the Jira key of the parent; on `jira-create` the top-level `parent` is the only carrier (never a `fields` entry); drafts carry `team`, `priority` and `requested-by` in a short body header under the fixed front matter (AM-4 12).
- **Cadence:** loop hand-back or about every 30 minutes (D62). Never deletes; archives via the profile status (card 14).
- **Separate vocabularies, never mapped to Jira:** gate verdicts, catalog `state`, output tokens.

## D4. Bus topic table (B1, M9)

| Topic | Bus | Writer | Reader | Payload |
|---|---|---|---|---|
| `<run-id>-<subtask>-rendezvous` | the sub-task's bus: `session_id = <run-id>-<subtask>`, `data_dir` under `RUN_HOME/<subtask>/bus/`, owned by the lead (owner Q2, 2026-10-26, `owner-decisions.md:59`; part C1.1) | every worker the lead dispatches | the lead (`peek:true`, fresh `agent_id`, `limit 200`) and the shepherd, peek-only (AM-4 23) | the part C2 unit record, gate verdicts and the step 8 final result (lead filter rule, part C2) |
| `{SESSION_ID}-fix-loop-output`, `{SESSION_ID}-escalation` | same bus | `wave-execution` fix agents; controller | controller; the lead drains `-escalation` per part C2 (reason `fix-loop-cap-exhausted`) | unchanged from ADR 0023 (ADR 0054 A7) |
| `pr-check-N-closed`, N = 1-9 | `pr-review`'s own local bus and port per review (§4 rule 5) | the Accountable seat for check N | gate checker, orchestrator, synthesizer (`peek:true`, fresh `agent_id`, separate reads, `limit 200`) | `CLOSED \| pr-check-N \| <agent-id> \| <quorum summary>` (`skills/pr-review/references/bus-schema.md`) |

- **No conductor topic:** conductor messages travel only as inbox files (§5.0, fix-verifier follow-up); the conductor never reads a sub-task bus.
- **Other review buses:** `review-7-panel` and `panel-review` topics stay defined by those skills and are cited, not frozen here (`DEFAULT`).
- **Fallback:** part C4. **Namespacing:** every pm2 app, `data_dir`, temp dir and worktree name carries `<run-id>-<subtask>`; every bound port claimed per part A.5.2 before launch (`tools/port-check.sh` through `port-claim`; refuse on collision, never auto-pick; amendment AM-1); `pm2 jlist` checked before start (§4).

## D5. `bus.endpoint` file (B1)

- **Path:** `RUN_HOME/<subtask>/bus.endpoint` (card 6 governs; the §5.11 row placing it under `bus/` is design errata).
- **Writer:** the lead (`delivery-run`), after it claims the bus port (part A.5.2, AM-1) and starts the bus, and before any dispatch; **atomic** (temp file plus `mv`). `delivery-run` is also the only restarter (`pm2 restart`; `DEFAULT (integrator)`, part C1.1).
- **Readers:** every dispatched worker and `wave-execution` (`data_dir`, `pm2_app`; `port` from `$data_dir/port`, ADR 0054 A9); never the conductor. `session_id=` and `topic=` must equal the bundle's (part C1.1).
- **Format:** key=value lines: `port=`, `data_dir=`, `pm2_app=`, `pid=`, `session_id=`, `topic=` (the last two added so §3.0's "the topic named in `bus.endpoint`" holds; design errata for §5.0's four-field list).
- **Durability:** survives reboot; re-verified at resume (part C5.3 step 4). Mode inherits `umask 077`.

- **In-run review buses (AM-5 10-B2):** `pr-review` writes its own `bus.endpoint` at `RUN_HOME/review/<subtask>/<review-id>/bus.endpoint`, `data_dir` under `.../<review-id>/bus/`, a fresh review id `pr-review-<uuid8>` per review with bus `session_id` `<run-id>-<subtask>-review-<uuid8>` (AM-6 C-3); same fields and atomic write as the sub-task file; readers are that review's seats, gate checker and synthesizer only.

## D6. Artifact-to-plane table (M18; §5.11 extended with writers and readers)

Planes: **repo** (committed; plan-plane files go first through sub-task 0, M22); **RUN** = `RUN_HOME`; **ROOT** = `$DELIVERY_ROOT`; **TMP** = `$TMPDIR` (volatile); **store** = the context store.

| Artifact | Plane and path | Writer | Readers |
|---|---|---|---|
| `review-tailor-<slug>.md`, `ticket-events.cursor`, `pm/new-units.md` | RUN (`DEFAULT`) | `review-tailor`; `ticket-clerk`; `post-merge-verify` | `pr-review`; `ticket-clerk`; `delivery-dispatch-plan` |
| `pm/zephyr-refusals.log` | RUN `pm/` (AM-2 row 13) | the `release-track` Zephyr PreToolUse hook | human, conductor |
| `brief.md`, `facts.md`, `drafts/` (local tickets, `drafts/index.md`), `architecture.md`, `review-architecture.md`, `h1-packet.md`, `dispatch-plan.md`, `test-plan.md` v0, `release-plan.md` v0 | repo `plans/<epic>/` (`DEFAULT` for the five §5.11 did not list) | intake; `delivery-architecture`; `delivery-dispatch-plan` | per part A.6 |
| `subtasks/<subtask>/substate.seed.md`, `subtasks/<subtask>/waves/` | repo `plans/<epic>/` (copied into RUN at lead start) | `delivery-dispatch-plan` | lead, `wave-execution` |
| `contracts/`, `.tasks/<unit>-<slug>.md`, `.decisions/<unit>.md` | repo root | Architect; `delivery-dispatch-plan`; unit agent (fork) then lead or human (resolution) | units, lead, human |
| `CLAUDE.md` (repo) | repo | **read only**: this family never writes it | every agent |
| `repo-profile.md` | repo `plans/` or the store, per its header | `delivery-intake` | every skill, `@<sha>` |
| `state.md` | RUN | conductor | conductor, desk, human |
| `substate.md`, slot rows, `bus.endpoint`, `bus/`, `inbox/`, `outbox/`, `dispatch/`, `escalations/`, `status/`, `shepherd/`, `gate-runs/`, `lanes/`, `<subtask>/gates/` | RUN `<subtask>/` | per parts A and C | lead, shepherd, desk, workers |
| `gates/<gate-file>` | RUN `gates/` | desk only | desk; `state.md` pointer |
| `release-plan.md` v1, `retro.md`, `execution-log.md` | RUN only; committing them to `plans/<epic>/` is a human step after CYCLE DONE (part A.6, row R4-J19) | `release-track`; conductor | human |
| `catalog.tsv` (one per run), `plan-check.md`, `ci/`, `merge-<sha>.md`, `postmerge-<sha>.md`, `release-<sha>.md`, `cleanup-<run-id>-<subtask\|final>.md`, `tickets.tsv`, `ticket-events.log`, `capture/` | RUN | `catalog.sh`; Plan-checker; `ci-fix-loop`; conductor; `post-merge-verify`; `release-track`; `delivery-cleanup`; `ticket-clerk`; conductor; capture agent | lead, conductor, human, cleanup |
| `review/<subtask>/` (record, fixes, verifies, `checklist-<subtask>.md`, `pr-body.md`), `bodies/`, `desk/<id>.req`, `desk/<id>.out` | RUN | `pre-pr-gate` and seats; body writers; requester; desk | desk, validator, human |
| `desk-inbox/`, `desk-log/`, `machine/`, `homes/`, `pw-browsers`, worktrees under `worktree_base` | ROOT | desk; desk; each session; launcher; desk `INSTALL`; lead (cataloged) | desk; conductor; children; lanes |
| `security-audit/run-<N>/` (full audit mode only) | RUN `<subtask>/` (part A.5.3, AM-1) | `security-audit` and its `security-auditor` agents | `pre-pr-gate` (`validate-findings.cjs` gate row), `pr-review` security seat, human |
| `tools/ports.tsv`, `tools/app-ports.tsv`, `tools/hooks/port-precheck.sh` (hook wired in `config/settings.json`) | agent-hq repo; the registries filled at the move for the work machine (AM-1) | `tools/port-check.sh --claim` (append only); the move operator | `port-check.sh`, the hook, cleanup |
| `skills/security-audit/` plus `PROVENANCE.md` | agent-hq repo, vendored unmodified (AM-1) | desk `INSTALL` (ledger `desk-20261026T152909Z-1`) | security seats, `pre-pr-gate` |
| pm2 apps, scratch | TMP | lead (bus app), agents | re-verified at resume |
| session dump | store `projects/<name>/sessions/` | Context organizer | the curator |
| learnings | the Hermes port in `agent-hq` (D19) | capture agent via the API door | read-back agent |

The desk "mailbox" of §5.0 and `RUN_HOME/desk/` are one directory.

## D7. Change control after the freeze (M21)

- **Freeze point:** the 2b review of the integrated `INTERFACES.md` on the ported `review-7-panel` ends (t3.5 in §7). No W1 item is dispatched before it (§7 stop conditions).
- **Amendment:** a diffed amendment plus a consumer re-check list naming every skill, template, task spec (item 2b) and brief (item 27b) that cites the changed grammar; each consumer is re-checked and **a failing consumer blocks the amendment** until fixed (`DEFAULT`).
- **Review rung:** Rung 1 (`doc-reviewer`, fix, `fix-verifier`) for an amendment that changes one grammar consumed by at most three skills; 2b otherwise (`DEFAULT`, the ladder rubric by fan-out).
- **Approver:** before the move, the owner through the item 33 "ready to move" packet; after the move, the executing human (D18: sign-off is whoever executes the workflow; an interface amendment is a scope change). No agent approves (Rule 9).
- **Record:** an "Amendments" table in `INTERFACES.md` (date, sections, consumer list, approver) plus a `version:` bump; `state.md` `interfaces_version` carries `<version>@<sha256>` and a lead refuses to start a sub-task whose plan cites an older version: the dispatch-plan header and seed carry `interfaces_version` and `delivery-run` Step 0 compares them (part A.2, A.6, D2.2 row 6; `DEFAULT`).
- **Recorded:** AM-1 (version 1.1.0, 2026-10-26): port guard and security-audit integration; see the Amendments table in `INTERFACES.md`.
- **Expected post-freeze entries:** the D12 RACI remap and 3-seat probe; the installed yes/no table (item 1); every value marked "unmeasured, verify at move".

## D8. AM-5 additions

- **D1.1 tokens (21):** `POSTMERGE: STOP <reason>` is a third `POSTMERGE:` value (`^POSTMERGE: (PASS|FAIL|STOP [a-z0-9-]+)$`): the run pauses on a row the human must decide or a destructive row lacking `H-destructive.<row-id>.<run-id>.ok`.
- **D2.2 row 1 (29-9):** a `RUN_HOME` under `$DELIVERY_ROOT` without `state.md` prints `INPUT-ERROR RUN_HOME path`; an unparsable one `INPUT-ERROR RUN_HOME format`; the conductor then prints a rebuild report derived from the row files (`*/substate.md`, `merge-*.md`, `cleanup-*.md`, `gates/`, `tickets.tsv`, `desk/*.out`, the dispatch plan), writes nothing, and stops until the owner decides.
- **D2.2 row 3 output (17, 15):** `delivery-architecture` records `STAKES`, `CONTENTION` and `NOVELTY` as three `key: value` lines in a fixed header block of `review-architecture.md`; rows 5 and 13 consume them.
- **D2.2 row 4 (15):** an epic's review rung is at least `2b` (design card 3 wins over the generic table).
- **D2.2 row 12 (21):** `post-merge-verify` gains `REPO_PROFILE` (@sha) and reads `commands.install`, `commands.pack` and `repo.consumer_repos[]` (A.2.2).
