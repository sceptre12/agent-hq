# INTERFACES.md: the frozen interface set of the delivery workflow

- **Freeze status:** `FROZEN 2026-10-26 after 2b review round 4 (record: reviews/interfaces-2b.md)` (design §7 item 2; reviewed on the ported `review-7-panel`, W0). `version: 1.1.0` (1.0.0 at the freeze; 1.1.0 by amendment AM-1, 2026-10-26).
- **Date:** 2026-10-26. **Integrator:** Worker1 (W0 item 2 integration). Section authors: A (state), B (desk), C (waves and control), D (enums, topics, planes).
- **Authority:** design v2 (`architecture/delivery-workflow/part-01-summary-and-process-map.md:1-84`, `part-02-skill-inventory.md:1-103`, `part-03-personas-and-concurrency.md:1-95`, `part-04-templates.md:1-72`, `part-05-execution-constraints.md:1-60`, `part-06-build-plan-and-sources.md:1-98`) is the source; this set fixes the grammars the design names. Where the design implies an answer the part cites the section; where it is silent the part says `DEFAULT (integrator)` and the decisions log below lists it. Owner rulings (`architecture/delivery-workflow-sources/owner-decisions.md:1-84`; the INTERFACES owner answers at `:57-60`, the ADR 0055 open-point answers at `:62-72`, the ADR 0054 answers at `:73-74`, the INTERFACES 2b answers at `:78-84`) bind throughout; no ruling is reopened here.
- **Consumers:** every W1 skill, template, task spec (item 2b) and persona brief (item 27b); ADR 0054 (`decisions/0054-adr-0023-amendment-delivery-workflow.md:1-290`) and ADR 0055 (`decisions/0055-desk-verb-permission-tiers-02.md:1-271`) (consistency noted per part, no edit to either ADR).

## Index

| Part | File | Contents |
|---|---|---|
| A | `interfaces/part-a-state.md` | `DELIVERY_ROOT`/`RUN_HOME` and every derived path; `state.md`, `substate.md`, slot row, machine row; gate files and pointers; `catalog.tsv` columns and the per-kind table; port claims (A.5.2) and the security-audit run directory (A.5.3); artifact names and writers; the single `HUSKY=0` / `GATE-PASS` statement |
| B | `interfaces/part-b-desk.md` | transport identity; `DESK`/`DONE`/`REJECTED` grammar and reason-code mapping; request file and copy-and-hash; the closed verb table and request schemas; marker re-derivation and the H-pr read-back; result envelope and per-verb result fields; redaction; human gate lines |
| C | `interfaces/part-c-waves-control.md` | unit table to `waves/` mapping and the wave files per sub-task; invocation values (`session_id`, `output_topic`, `max_concurrent`, `bus_endpoint`); preflight rules 13-15; the `UNIT-VERDICT` record and lead handling; `NEXT:`; the status-file fallback; inbox, outbox, escalations; resume; `RELEASE`/`INVALIDATE`; shepherd and watchdog flags |
| D | `interfaces/part-d-enums-topics.md` | Step 0 `INPUT-ERROR`; every enum; per-skill named inputs and output tokens; status vocabulary and transitions; bus topics; `bus.endpoint`; artifact-to-plane table; change control |

## Change-control rule (M21; detail in part D7)

After the freeze a change is a diffed amendment plus a consumer re-check list; a failing consumer blocks the amendment. Rung 1 for a change consumed by at most three skills, 2b otherwise. Approver: the owner before the move (via the item 33 packet), the executing human after it (D18). Each amendment is a row in the Amendments table below and a `version:` bump; `state.md` `interfaces_version` pins the version a run uses.

| Amendment | Date | Sections | Consumers re-checked | Approver |
|---|---|---|---|---|
| AM-1 (1.0.0 -> 1.1.0) | 2026-10-26 | A.2 `security_audit`; A.4 security-audit agents; A.5.1 `port` cleanup; new A.5.2 port claims, A.5.3 security-audit run directory; A.6 row; C1.1 lane lease; D2.1 `persona`, `security_audit`; D2.2 rows 4, 6, 10; D2.3 `pr-review`; D4 namespacing; D5 writer; D6 rows; D7 record; errata E18, E19 | pending, see "Amendment AM-1" below | the owner, via the item 33 packet (pending) |

### Amendment AM-1: port guard and security-audit integration

- **Rulings:** port guard, owner 2026-10-26 "PORT GUARD" (`architecture/delivery-workflow-sources/owner-decisions.md:85-87`), build-pause record "Port guard"; security-audit, owner YES 2026-10-26 (`owner-decisions.md:77`), build-pause record "security-audit integration". Rows O-PG, O-SA.
- **Diff, port guard:** every port a run binds (lanes, dev servers, review buses) is claimed with `tools/port-check.sh` before launch, refused on collision, never auto-picked; the bind is a catalog `port` row (kind already in A.5) that cleanup releases with a `released` registry row; the PreToolUse hook `tools/hooks/port-precheck.sh` catches launches outside that path; the move installs it from `config/settings.json` and fills `ports.tsv` / `app-ports.tsv`; P0 runs a positive control of the hook (part A.5.2, A.5.1, C1.1, D4, D5, D6). Lands as agent-hq PR #9 (branch `wt/port-guard`).
- **Diff, security-audit:** vendored unmodified at `skills/security-audit` plus `PROVENANCE.md`; new enum `security_audit` `guidance|full` (`state.md` field, input `SECURITY_AUDIT` of `delivery-run`, `review-tailor`, `pre-pr-gate`, `pr-review`); guidance mode in the security seat of `pre-pr-gate` and `pr-review`/panels, diff-scoped, no files, no extra agents; full mode only on an explicit operator request or a `security_sensitive: yes` epic, with `output-dir` `RUN_HOME/<subtask>/security-audit/run-<N>`, agents from the free slots under the 30/sub-task cap and counted in the slot ledger (persona `security-auditor`), target code no-network, and `node skills/security-audit/validate-findings.cjs <findings>` as a `pre-pr-gate` gate row (part A.2, A.4, A.5.3, A.6, D2.1-D2.3, D6).
- **Rung:** 2b (the change is consumed by more than three skills, D7).
- **Consumers to re-check (D7; a failing consumer blocks AM-1):** skills `delivery-pipeline` (sets `security_audit`), `delivery-architecture` (`security_sensitive:` header), `delivery-run` (input, bus port claim, lane ports), `review-tailor`, `pre-pr-gate`, `pr-review`, `panel-review` and `review-7-panel` security seats, `resource-catalog` (`catalog.sh` `port` cleanup), `delivery-cleanup`, `wave-execution` (lanes), `port-claim`; the persona brief `security-auditor` (item 27b); the task specs (item 2b) of those skills; the `state.md` and `dispatch-plan.md` templates. Status 2026-10-26: no W1 consumer is authored yet (no W1 item is dispatched before the freeze, D7), so each is checked against 1.1.0 when authored; the re-check record is added to this table row.

## Owner questions and notes

## Owner questions and notes

No owner note remains open: N10 and N11 (below) are settled by the owner (2026-10-26; `architecture/delivery-workflow-sources/owner-decisions.md:80`, `:81-84`), rows O-N10 and O-N11. The INTERFACES questions Q1-Q3 are settled by the owner (2026-10-26; `architecture/delivery-workflow-sources/owner-decisions.md:58`, `:59`, `:60`). The former Owner notes N1-N9 (ADR 0054 / 0055 open points the round-1 contract was written around) are all settled by the owner's answers of 2026-10-26: ADR 0055 OP1-OP10 ("Accept all", `architecture/delivery-workflow-sources/owner-decisions.md:62-72`; `decisions/0055-desk-verb-permission-tiers-02.md:259-273`) and ADR 0054 Q2-Q11 (`architecture/delivery-workflow-sources/owner-decisions.md:73-74`; `decisions/0054-adr-0023-amendment-delivery-workflow.md:267-284`). Each is now a Kind O row in the decisions log ("Owner rulings of 2026-10-26"); where a round-1 `DEFAULT (integrator)` differed (N1 reservation rows, N5 `state.md` registry) the contract now follows the ruling. Still not the owner's: the forms ADR 0055 leaves to the freeze (`[freeze]`) are labelled `FROZEN (integrator, ADR 0055 [freeze])` in part B and logged below ("Freeze items"); the names ADR 0054 leaves to part C are `DEFAULT (integrator)` there. Both ADRs are accepted (2026-10-26).

- **N10 (settled, owner 2026-10-26, `owner-decisions.md:80`): `HUSKY=0` scope.** The owner ruled "N10: ALWAYS HUSKY=0 on desk pushes. The recorded affected lint/test/typecheck pass before each push (D21/R2-3) still applies." (`architecture/delivery-workflow-sources/owner-decisions.md:80`). Part A.7 states it once: every desk `push` carries `HUSKY=0` as an inline per-command assignment, never exported, `--no-verify` is never used, and the `GATE-PASS` record still gates every push (`DEFAULT (integrator)` wording of the ruling). The ruling does not name commits made outside a desk push, so part A.7 keeps D21 as written for them (`DEFAULT (integrator)` reading of `owner-decisions.md:28`; any wider skip is an owner question, not decided here). The r3 H36 first-push question is moot: every desk push skips hooks, so no push needs to be told apart as the first one and the `push` schema (part B4) gains no field (default). Row O-N10.

- **N11 (settled, owner 2026-10-26, `owner-decisions.md:81-84`): `tag-push` (r3 H14).** The owner ruled "tag-push behaviour is set per repo in repo-profile.md": "whether the repo uses release tags at all"; "if it does, its push and approval rule"; "With no profile entry, tag-push is refused." (`architecture/delivery-workflow-sources/owner-decisions.md:82-84`). The forms are `DEFAULT (integrator)`: the profile keys `release_tags.used` (`"yes"\|"no"`, quoted strings, row R4-J1), `release_tags.pattern` (the push rule, an anchored regex the `tag` must match) and `release_tags.approval` (`none\|human`; `human` requires `RUN_HOME/gates/H-prod.<step_id>.ok`, so `tag-push` carries `step_id`) in part A.2.2. The desk refuses `REJECTED policy` (terminal, B2.1) when `release_tags.used` is absent or `no` or the `tag` does not match `release_tags.pattern`, and `REJECTED gate-missing` when `release_tags.approval` is `human` and the gate file is absent (part B3 steps 6 and 8, B4; `DEFAULT (integrator)` codes). Rows O-N11 and R40-1.

## Script interfaces (`DEFAULT (integrator)`; producers per part A, consumers named)

| Script | Call | stdout | Exit codes |
|---|---|---|---|
| `catalog.sh` | env `RUN_HOME` required (absolute, its last segment the run-id; unset is exit 2); `register <kind> <handle> <unit\|-> <correlation_id> <source> <subtask\|run> <owner_agent>` (fill catalog columns 3 and 8, part A.5; `<unit\|->` matches `^([ui][0-9]+\|-)$`, catalog column 9); `start\|release\|fail <kind> <handle>`; `keep <kind> <handle> <reason>`; `list --live [--subtask <st>]`; `audit` | `register`/`start`/`release`/`keep`/`fail`: the `row_id`; `list`: the matching TSV rows; `audit`: `MATCH<TAB><row_id>`, `GHOST<TAB><row_id>` or `SQUATTER<TAB>-<TAB><kind>:<handle>` lines (`^(MATCH\|GHOST)\t[0-9]{8}T[0-9]{6}Z-[a-z0-9-]+-[0-9]+$` or `^SQUATTER\t-\t[a-z0-9-]+:.+$`) | 0 ok; 2 usage or rejected row (A.5); 3 lane-lease held (compare-and-append, A.5); 4 lock timeout |
| `desk-req.sh` | `desk-req.sh <run-id> <subtask\|run> <verb> <fields-json-file>` | the `DESK` line (B2) to send or to write to `outbox/<id>.desk` | 0 ok; 2 usage; 4 lock timeout |
| `scope-check.sh` | `scope-check.sh <tasks-file> <worktree> <base-sha>`; `<tasks-file>` = `<primary_repo>/.tasks/<unit>-<slug>.md`, `<base-sha>` = `git -C <worktree> merge-base HEAD <sub-task branch>` (computed by the caller, never stored; row R4-J21) | one line per changed path outside the unit's globs: `CREEP <path>` | 0 clean; 1 creep found; 2 usage |

All three take their lock with `mkdir` (`catalog.lock`, `desk/.lock`) and break it as `substate.lock` (A.3); a waiter retries every 1 s and exits 4 after 60 s, the same timeout as `machine/.lock` (`DEFAULT (integrator)`, row R4-J10).

## Regex dialect (`DEFAULT (integrator)`, row R4-J5)

Every regex in this set is POSIX ERE (`grep -E`, bash `[[ =~ ]]`): numbered groups only, POSIX classes (`[[:space:]]`, `[[:cntrl:]]`); `\|` inside a Markdown table cell is Markdown escaping of `|`; `\t` stands for a literal TAB. Part D1 restates it for Step 0. `desk-req.sh` allocates `<n>` as the per-run counter (B2); `catalog.sh` mints `row_id` `n` as the per-file sequence (A.5).

## Decisions log (how the 154 `OPEN`s and the authors' contradictions were resolved)

`D` = design-implied (section cited in the part); `DEF` = `DEFAULT (integrator)`; `O` = owner ruling (source and date cited in the row).

| Part | Topic | Resolution | Kind |
|---|---|---|---|
| A.1 | run-id shape and minting; subtask id | `<epic-key-lowercased>-<yyyymmdd>`, minted by the conductor at stage 1; `st<N>`, `st0` = plan PR | DEF (shape); D (minting, card 1) |
| A.1 | timestamps | ISO 8601 UTC everywhere; compact form only inside desk ids | DEF |
| A.1 | `catalog.tsv` scope | one file per run (`RUN_HOME/catalog.tsv`); rows carry `subtask` | D (§5.6 columns, §1 stage 3) |
| A.1 | `status/`, `shepherd/`, record files' directories | `RUN_HOME/<subtask>/status/`, `shepherd/`, `gate-runs/`; run-level records directly under `RUN_HOME` | D (§5.0) / DEF (records) |
| A.1 | desk-inbox copy name and retention; desk log | `<id>.req`, kept to CYCLE DONE; `$DELIVERY_ROOT/desk-log/<run-id>.jsonl` | DEF |
| A.2 | `state.md` serialization; terminal stage; registered ids; installed hashes; interfaces version | one YAML document; `done`/`stopped`; no `conductor_id` (the desk holds the registry, OP3 B, row O-OP3); `lead_id` is the conductor's own record; `skill_versions` value `<version>@<sha256>`; `interfaces_version` | DEF (all; hash home satisfies §6.5) |
| A.2 | `subtasks[].state`; timestamp | `planned\|released\|building\|pr-open\|merged\|stopped\|cleaned`; ISO | DEF |
| A.2.1 | gate file names and contents; H0 as file; H1 CHANGES/REJECT; H-pr pointer; H-prod per step | `H0.ok`, `H1.ok\|.changes\|.reject`, `H-e2e.<subtask>.ok`, `H-prod.<step_id>.ok`; key=value `utc, by, ref, text`; H-pr = `gh:<o>/<r>#<pr>@<commit>` | DEF (names, content); D (M30 semantics) |
| A.2.1 | "desk refuses generation" | the desk writes the gate file; the lead enforces it before generation (lead-side NLTA step) | D (card 6, §3.6) + errata |
| A.3 | `frontier`, `waves_done`, `stop_reason`, lock contents, hand-over | unit ids; int; closed set; `owner` file `<pid> <utc>`; old lead removes the lock and exits first | DEF |
| A.3, D5 | `bus.endpoint` format and fields | key=value, atomic; adds `session_id`, `topic` (so §3.0 holds) | D (§3.0) + errata (§5.0 list) |
| A.4 | slot-row field order; `pid` for agent-tool; stale marking | §5.0 order (9 fields); `<lead-pid>/<agent-id>`; rename `.row` to `.stale` during resume | D (§5.0) / DEF (separator, rename) |
| A.4 | machine row format | `session= pid= live_count= build= utc=` | DEF |
| A.5 | `verify_cmd` vs "no executable column" | column dropped; 12 columns; per-kind table supplies verify and cleanup | D (M26 wins) + errata (§5.6 list) |
| A.5 | `row_id`, `correlation_id`, supersede key, subcommands, gate-runner kind | `<ts>-<owner>-<n>`; `<JIRA-KEY>\|PR-<n>\|run`; `kind+handle`; `register start release keep fail list audit`; `lane-lease` `gate-runner/<n>` | DEF |
| A.5.1 | per-kind verify and cleanup for every kind | table completed; tags, containers, images, workspaces are `kept` and reported (no delete verb; docker and Harness unmeasured) | DEF |
| A.5.1 | file-count basis | `find -type f \| wc -l`, `.git` included, stated | DEF |
| A.6 | unnamed stage 2 record and packet; drafts; plan-plane files | `review-architecture.md`, `h1-packet.md`, `drafts/`, all in `plans/<epic>/` | DEF |
| A.7 | `GATE-PASS` path; cold run counts for first push; "per commit" residue | `RUN_HOME/<subtask>/gate-runs/<sha>.md`; yes, same command and runner; errata listed | DEF / errata |
| B1 | `claude -p` lead sends `DESK`; desk learns registered ids | conductor relay via `outbox/`; owner 2026-10-26, Q1 YES: "the conductor relays DESK lines for claude -p leads, and the desk cross-checks the id and subtask" (`architecture/delivery-workflow-sources/owner-decisions.md:58`); the desk checks senders against its own registry, filled by the conductor over the transport (OP3 B, row O-OP3) | O |
| B2 | two `DONE` forms; `<subtask>` for conductor requests; `<utc>`; `REJECTED` detail | long grammar line; `run`; `yyyymmddThhmmssZ`; detail only in `.out` (rows O-OP1, O-OP2, O-OP7) | O |
| B2.1 | check-to-code mapping for branch, paths, redaction, `merge_reach`, CI | `repo`, `repo`, `policy`, `gate-missing`, `marker` | DEF (ADR 0055 §2 defines the codes, not the pairings) |
| B3 | request JSON keys; copy name; log; account lock | `{id, verb, subtask, fields}`; `<id>.req`; `desk-log/`; no lock (R2-4) | DEF / errata (changelog B1) |
| B4 | `method`; `predecessors[]`; `jira-get fields`; `jira-transition`; key vs parent; `publish` gate; `payload_path` root; attachments; `pr-create` title | `squash\|merge\|rebase` = profile; PR numbers; field names; `{key, to}`; create takes `parent`, others `key`; `H-prod.<step_id>.ok`; `bodies/`; new verb `pr-attach` (owner 2026-10-26, Q3 YES, `owner-decisions.md:60`, see row B5); title from branch | DEF / O (`pr-attach`) / D (§2.1b for title) |
| B5 | record path carrier; `pr-attach` verb | `record_path` field on `pr-create` and `pr-merge`, plus the `pr-attach` verb; owner 2026-10-26, Q3 YES: "add a pr-attach verb plus a record_path field on pr-create and pr-merge (ratify with 0055)" (`architecture/delivery-workflow-sources/owner-decisions.md:60`); ratified with ADR 0055 (accepted 2026-10-26) | O |
| B6 | result field names; `REJECTED` writes `.out` | table frozen as the authority for `skills/delivery-desk/references/schemas.json` (W1 target, written from this table; not on disk yet); yes | DEF |
| B7 | redaction hit; `ci-logs` scan; binary attachments | refuse with `policy`; desk scans itself; images unscanned and labelled, traces scanned (row O-OP9) | DEF / DEF / O |
| B8 | human confirmation capture | typed `GATE <run-id> <gate> <verdict> <text>` and `ANSWER <run-id> <subtask> <unit> <text>` lines in the desk session (part B8 grammar) | DEF |
| C1 | `max_concurrent` placement; globs, budget, review path, e2e fields; persona and lane level; DAG vs numbered files; rule 12 | caller argument (row O-Q9); brief text (globs live in `.tasks` and the unit table); per work_item (row O-Q10); one DAG wave `01-build.md` (plus `00-constitution.md`, `02-integrate.md`); rule 12 = deferred `spec_ref` | O / DEF / O / DEF (file set) / D |
| C1.1 | caller-owned bus and skip-teardown (ADR 0054 open item 1) | optional bundle field `bus_endpoint`; owner 2026-10-26, Q2 YES: "add an optional bus_endpoint to wave-execution; caller-owned bus attach and skip-teardown (ratify with 0054)" (`architecture/delivery-workflow-sources/owner-decisions.md:59`); ratified with ADR 0054 (accepted 2026-10-26) | O |
| C2 | `reason` vocabulary; head mismatch; text prefix; reader idiom | closed set with `none` on PASS; incomplete post, re-gated, two in a row = unit stop row; bare JSON; `peek:true`, fresh `agent_id`, `limit 200` | DEF / D (ADR 0054 A6) / DEF / DEF |
| C3 | `next_step` (formerly `<step-id>`); history | `<unit>.<n>` from `.tasks` §9; single overwritten line | DEF |
| C4 | precedence; consumed file | bus post wins; rename `.verdict.consumed`; the lead relays to the topic (ADR 0054 A7) | DEF / D |
| C5 | inbox naming and body; who writes answers; escalation location; SendMessage vs inbox; agent-tool resume; spawn-cap hand-over | `<seq>-<utc>-<type>.md` (r3 H21), message on line 1; the desk (after the human types `ANSWER`); `RUN_HOME/<subtask>/escalations/<unit>.md`; inbox canonical, `SendMessage` is a pointer `INBOX <subtask>`; same brief typed by the owner; lock removed before exit | DEF; "conductor topic" in changelog M19/M21 not adopted (design §5.0 governs) |
| C6 | `INVALIDATE` reason set; receiver vs predecessor id; successor past `pre-pr-gate` | closed set of four; receiver; re-run `pre-pr-gate` on head change, fresh `RELEASE` needed | DEF |
| C7 | nudge template; `FREE-CANDIDATE` condition; tick below 3 agents | fixed template; terminal record without `.freed`; watchdog half always, drift/creep by the lead per verdict | DEF |
| D1 | `INPUT-ERROR` behaviour and grammar | one line per field with a reason, then stop | DEF |
| D2 | `stakes/contention/novelty` values; ci-fix-loop tokens; lane tokens vs NLTA classes; intent vs `RUN_HOME`; `gate_type` set; `PR_REVIEW_MODE`; `UNIT_MODE` default | ladder axes; kebab-case; `LANE: PASS\|FAIL`, NLTA classes cited only; existing dir with `state.md`; ADR 0054 four values; `local-diff\|pr`; `solo` | DEF / D (ADR 0054) |
| D3 | transitions, archive status, event names | seven events plus `archive` mapped to the stage table, `TICKET-EVENT` line; profile field | DEF |
| D4 | other review buses; lead read idiom | cited, not frozen; `peek:true` idiom | DEF |
| D6 | `.decisions` fork writer; `CLAUDE.md`; planes for brief, drafts, seed, records; mailbox | unit agent; read only; `plans/<epic>/` and RUN per part A; one directory | D (§5.10) / DEF |
| D7 | amendment rung, approver, record, failing consumer | Rung 1 or 2b by fan-out; owner before the move, executing human after (D18); Amendments table plus `interfaces_version`; blocks | DEF / D (D18) |

### Decisions added by the round-1 fix (2b review, 2026-10-26; all Kind DEF)

| Part | Topic | Resolution | Kind |
|---|---|---|---|
| A.1 | token shapes; `<epic>`; `session`; `pm`; `DELIVERY_ROOT` whitespace; run-id collision | 40-hex sha, `^u[0-9]+$`, `agent_id`, `step_id`, `JIRA-KEY`; original-case epic; launcher session token distinct from bus `session_id`; `pm` post-merge host; no whitespace; `-2` suffix | DEF |
| A.2 | `epic`, `plans_dir`, `primary_repo`; state transition sources; stages 6-7 host | fields added; each `subtasks[].state` value mapped to its source; `pm` lead released by `RELEASE pm` | DEF |
| A.3 | lead-to-conductor fields; lock | `phase`, `prepr`, `head`, `pr`, `review_record`, `integrated`, `ci`, `postmerge`; lifetime lock, temp+`mv` owner, unparsable = stale after 120 s | DEF |
| A.4 | slot rows for controller-dispatched agents; machine row | one row per agent named in the dispatch record, written as it appears; no reservation rows (gate and fix agents count toward `max_concurrent`, row O-Q3); `pid=pending`; machine row `pid=`, `build=`, dead-pid reaper | DEF |
| A.5 | `row_id` `n`; lease acquire; handle grammar | per-file sequence under `catalog.lock`; compare-and-append; per-kind handle grammar with `repo` and `base` | DEF |
| A.6 | review record; tickets map; cleanup record | one `record-<head>.md` (3 lines); `tickets.tsv`, `ticket-events.log`; `cleanup-<run-id>-<subtask\|final>.md` | DEF |
| A.7 | `HUSKY=0` scope | "ALWAYS HUSKY=0 on desk pushes" (owner 2026-10-26, `owner-decisions.md:80`), inline per command, never exported, no `--no-verify`; commits outside a desk push follow D21 as written (`owner-decisions.md:28`, `DEFAULT (integrator)` reading); `GATE-PASS` gates push, PR creation and desk; H36 first-push signal moot | O (row O-N10; was DEF) |
| B1 | conductor-only verbs; relay tick; `.out` wait; desk address | `<subtask>` = `run` required; 1-minute tick and `.desk.relayed`; 5-minute poll then one resend; `DESK_ADDRESS` = `desk` (`run` itself is row O-OP7; the desk tier is row O-OP4) | DEF |
| B2, B3 | id regex; idempotency; check order | anchored regex, `<n>` from `desk-req.sh`; a repeat returns the stored `.out` without a hash compare (ADR 0055 §3, row FRZ-order), new `<n>` per retry, no `.out` for `sender`, `.inflight` reconcile; numbered checks, first failure wins, JSON-subtask check on the copy (`schema`) | DEF |
| B4, B6 | field types; requester map; new fields | type list, requester and reader column; `subtask` on `pr-merge`, `expect_head` on `pr-create`, `ci_run_id`, `jira-get` readable set with `status`, `to: archive`; closed CI and review state sets; envelope null rules | DEF |
| B5 | `branch-delete` content-merged | ancestor or patch-id re-derivation, else `marker`; `merged_check` loses `none` | DEF |
| B8 | human lines | `GATE <run-id> ...` and `ANSWER <run-id> ...` with regexes and gate x verdict matrix; `by=` OS login; `ref=` computed; `H1.notes.md` | DEF |
| C1.1 | dispatch record; `dispatch_budget`; `bus_endpoint` value and attach; lane lease | `dispatch/<invocation>.jsonl`; A5 formula (row O-Q5); `$DELIVERY_ROOT`-relative, A9 behaviour; lead leases per lane name per invocation (r2 G22) | DEF |
| C1.2 | done condition field name; persona brief | `done_condition` (the field is row O-Q2; the name is left to part C by ADR 0054 A4); `Brief:` line, read by the dispatched agent itself (row R4-J14) | DEF |
| C2 | topic records and lead filter; extra reasons | registered `from_agent` only; `fix-loop-cap-exhausted`, `arch`, `source-bug`, `env-bug`, `merge-conflict`, `human-step` | DEF |
| C5, C6 | inbox `<seq>`; `REGISTER`; INVALIDATE supersede; `merge_sha` clear | 4-digit counter via an `O_EXCL` marker `inbox/.seq/<seq>`, `<seq>` order (r3 H21); `outbox/register`, relayed to the desk as `REGISTER-SENDER`; supersedes unconsumed RELEASE; conductor clears it | DEF |
| C7 | cron owner; watchdog half | the lead arms it; watchdog half in `delivery-run`, shepherd half in `delivery-shepherd` | DEF |
| D1.1, D3 | token carriers and regexes; ticket events | line 1 of record file; `POSTMERGE:`, `FACTS:`, `DRAFTS:`, seat table; seven events plus `archive`, `TICKET-EVENT` line | DEF |
| I | script interfaces | `catalog.sh`, `desk-req.sh`, `scope-check.sh` CLI table | DEF |
| B2, B6 | duplicate-action guard for a fresh-id resend after `action-failed` (r1e V3) | `.inflight` is a directory (`mkdir`) whose file `target` holds `<verb> <target>`; the desk reads back the target before acting on any request whose `<verb> <target>` has an `.inflight` without a `DONE` `.out` | DEF |
| B1, B2.1, B3 | `<subtask>` `run` enforcement (r1e V4) | registry's `run` id is the conductor; any `<id>` with `run` from another sender is `REJECTED sender` | DEF |
| C5.1, B4, D2.2 | `pm` lead to conductor request for conductor-only verbs (r1e V5) | `CONDUCTOR-REQUEST <run-id> pm <seq> <verb> <fields-json>` in `pm/outbox/<seq>.conductor-request`; conductor renames it `.sending-<id>` before send, `.sent-<id>` after, `.refused` on a bad line | DEF |
| I | `catalog.sh register` columns 3 and 8 (r1e V6) | `<subtask\|run> <owner_agent>` args | DEF |
| A.1, B2 | run-id when no epic exists at stage 1 (r2 G12) | provisional `run-<n>-<yyyymmdd>`, never renamed; `plans/<run-id>/`; `epic` filled from the `jira-create` read-back | DEF |
| A.1, A.6, D1.1 | `<slug>`; `index` reserved; `review-tailor-<slug>.md` (r2 G5) | `^[a-z0-9][a-z0-9-]*$`; tailor slug `<subtask\|run>-<kind>-<n>` | DEF |
| A.2, D2.2 | `pm` record sha and paths; `delivery-run` `mode` (r2 G6, G31) | `pm_sha` = last merge sha; `postmerge_record`, `release_record`; `build\|plan-pr\|post-merge` | DEF |
| A.2.1, B8 | H1 notes on `reject`; repeat H1 gate (r2 G2) | notes for `changes` and `reject`; earlier H1 files renamed `<name>.<utc>` | DEF |
| A.3 | seed keys; `stop_reason` row id; `lock_breaks`; lock break (r2 G14, G15, G8) | `subtask_id session_id reserved frontier phase`; `^stop-the-line:[A-Z]+[0-9]+[a-z]?$`; break = `mv` to `.broken-<pid>-<utc>` then `mkdir`, all four locks | DEF |
| A.3, D1.1 | `integrated` source (r2 G29) | one Integrator C2 record per merged unit, under work_item id `i<N>` (r3 H2) | DEF |
| A.4, C5.3 | slot rows for reserved seats, unit `-`, reconcile (r2 G9) | reserved seats no row; unit `^([ui][0-9]+\|-)$` (r3b V3-1); C5.3 step 3b | DEF |
| A.5, C1.1 | lane lease (r2 G7, G22) | `lane-lease` register writes `live`; acquire needs latest not `planned\|live`; leased per lane name per invocation | DEF |
| A.5.1, B5, B6 | branch deletes; squash check (r2 G11) | local and remote both gated; squash patch-id; `merged_check` `squash` | DEF |
| A.6 | fix and verify file names; review record regexes; `tickets.tsv` `-` and cursor (r2 G26, G16, G3) | `fix-<agent-id>-<n>.md`; line 1-3 regexes; `ticket-events.cursor` | DEF |
| A.7 | `GATE-PASS` file (r2 G17) | written only on a pass; lines `GATE-PASS`, `utc=`, `runner=`, tail | DEF |
| B1, B8 | re-claim; non-lead requesters; register-before-DESK; no-reply (r2 G23, G27, G4) | `REBIND <run-id> <sender-id>`; host session sends; `register.consumed` after `REGISTERED ok`; `.req.noreply` | DEF |
| B4, B6 | `pr-create` `record_path` check; result types (r2 G20, G33) | root + name and content re-derivation at `pr-create` (r3 H17); type list, required on `DONE`, arrays never null | DEF |
| C1.2 | `done_condition` shape; scope glob dialect (r2 G35, G34) | `{token, command}`; `## 3` `- <glob>` lines, git `:(glob)` | DEF |
| C2, C4 | verdict-reason matrix; fallback relay identity (r2 G18, G21) | `ROLLED` reasons `budget lane-unavailable env-bug merge-conflict`; relay as the recorded `agent_id`; no post = gate failure | DEF |
| C5, C7 | `.sending-<id>`; `MERGED` inbox; dead lead and bus-down ticks (r2 G24, G28, G25) | rename before send; `MERGED <subtask> <merge_sha>`; `kill -0` lock owner; `pm2 restart`, two failures stop | DEF |
| D1, D2.2, D3 | `INPUT-ERROR format`; `new-units.md`; test-report payload; unit-to-ticket (r2 G19, G32, G3) | `format` reason and line regex; `pm/new-units.md` into `new_units`; `bodies/test-report-<step_id>.json` by `release-track`; unit table `ticket` column | DEF |
| I | `catalog.sh` run input; audit lines (r2 G30, G13) | env `RUN_HOME`; `SQUATTER<TAB>-<TAB><kind>:<handle>` | DEF |

### Decisions added by the round-3 fix (2b review, 2026-10-26; all Kind DEF)

| Part | Topic | Resolution | Kind |
|---|---|---|---|
| A.1, A.6, D1.1, D2.2 | review-tailor file writer (r3 H1) | `review-tailor` writes `review-tailor-<slug>.md`; the caller mints `SLUG`; a file-carried token is never printed instead | DEF |
| A.1, A.3, A.4, B8, C1.1, C1.2, C2, D1.1 | Integrator record identity (r3 H2) | work_item id `i<N>` merges `u<N>`; unit fields `^[ui][0-9]+$`; head check on the sub-task worktree; `integrated` entry `^u[0-9]+ [0-9a-f]{40}$` | DEF |
| A.6, B1, D3 | `ticket-clerk` host (r3 H3) | conductor session only; every `jira-*` request carries `run` | DEF |
| A.6, B4, B5 | merge and cleanup records; `branch-delete` (r3 H4) | `merge-<sha>.md` four key=value lines; cleanup sections written then `mv`; `branch-delete` adds `merge_sha`; host session sends | DEF |
| A.2.2, A.4, B5, B6, D2.2, D3 | profile keys (r3 H5) | `merge_method`, `merge_reach`, `ci.required_checks[]`, `merge_pipeline.stages[]`, `jira.archive_status`, `durations.*` | DEF |
| A.4, C1.2, D2.1 | persona tokens; briefs root (r3 H6) | closed kebab-case set; `skills/delivery-run/references/briefs/<persona>.md` | DEF |
| B4 | required fields (r3 H7) | all required; `jira-create` `parent` present iff not `Epic` | DEF |
| B3, B5 | `merge_reach` code (r3 H8) | checked at step 8, `gate-missing` | DEF |
| C1.2 | done condition vs completion record (r3 H9) | two rows; `token` = last stdout line of `command` on exit 0 | DEF |
| A.6, C1.2, C3, D6 | `.tasks` file name (r3 H10) | `.tasks/<unit>-<slug>.md` | DEF |
| D2.2 | input identifiers and transport (r3 H11) | UPPER_SNAKE `NAME=value` args, `DELIVERY_ROOT` env only | DEF |
| B6 | `ci-status` aggregate (r3 H13) | precedence over `ci.required_checks[]`: failure > pending (or absent) > cancelled > success | DEF |
| C1 | Wave 0 setup (r3 H15) | in-lead steps of `delivery-run` before the first `wave-execution` call | DEF |
| C1.1 | `dispatch_budget` (r3 H16) | rule 11 sum: A5 term for `01-build.md`, 0023 term for barrier waves | DEF |
| C5.3 | resume catalog handling; lease reclaim (r3 H18, H19) | `catalog.sh audit`, `release`/`fail` only; new lead releases dead holders' `lane-lease` rows | DEF |
| C5.1, B1 | register per lead start (r3 H20) | earlier `register*` renamed at start | DEF |
| A.2 | state back-edge; post-merge re-entry (r3 H22) | `pr-open`/`merged` -> `building` with `merge_sha` cleared; conductor adds `st<N>` and re-invokes dispatch-plan with `NEW_UNITS` | DEF |
| A.2, A.6, D1.1, D2.2 | intake inputs and profile token (r3 H23) | conductor creates `RUN_HOME`, `PLANS_DIR`; `PROFILE:` token; new profile at `<primary_repo>/plans/repo-profile.md` | DEF |
| C1.3 | Plan-checker invocation (r3 H24) | dispatched by `delivery-dispatch-plan`; fix loop to `clean` or round 3 | DEF |
| D3 | unit-to-ticket writer (r3 H25) | `delivery-dispatch-plan` from `tickets.tsv`; conductor never edits the unit table | DEF |
| B4 | first push (r3 H26) | no push before 4b; first push at stage 5, fast-forward after | DEF |
| A.1, A.2, D2.2 | primary repo at stage 1 (r3b V3-4) | `PRIMARY_REPO` input of `delivery-pipeline` (with `INTENT`) and `delivery-intake`; recorded as `primary_repo` before `plans_dir` is created | DEF |
| A.1, A.5, I | catalog `unit` column (r3b V3-2) | `^([ui][0-9]+\|-)$`; `catalog.sh register` `<unit\|->` the same | DEF |
| D2.2 | `resource-catalog` input transport (r3b V3-3) | `RUN_HOME` env, the named exception to the `NAME=value` rule | DEF |
| C5.1, D2.2 | `pm` and `final` cleanup (r3 H27) | `pm` lead after `release-<pm_sha>.md`; conductor `final` before `stage: done`; `SUBTASK` omitted for `final` | DEF |

### Owner rulings of 2026-10-26 (all Kind O; retire Owner notes N1-N11)

| Id | Ruling (source) | Where applied | Retires |
|---|---|---|---|
| O-OP1 | no detail on the `DESK` `REJECTED` line; detail in `.out` (`owner-decisions.md:63`) | B2, B6 | N4 |
| O-OP2 | the long `DONE` form (`owner-decisions.md:64`) | B2; errata E5 | N4 |
| O-OP3 | desk-held sender registry; the conductor registers ids over the transport (`owner-decisions.md:65`) | B1 `REGISTER-SENDER`, B2.1 `sender`, A.2 (no `conductor_id`), C5.1, D2.1 | N5 |
| O-OP4 | existing desk tier; "never source" scoped to `INSTALL`; conductor and Agent-tool leads executor tier, `claude -p` leads no tier (D25) (`owner-decisions.md:66`) | B1 permission tiers, desk address | N7 |
| O-OP5 | terminal vs curable codes; a curable code may be resent with a fresh id once its cause clears (`owner-decisions.md:67`) | B2 idempotency, B2.1 class column | (new) |
| O-OP6 | R2-7 runtime only; build-time git keeps the existing envelope (`owner-decisions.md:68`) | part B scope line | (new) |
| O-OP7 | reserved `<subtask>` token `run`; `<utc>` = `yyyymmddThhmmssZ` (`owner-decisions.md:69`) | A.1, B1, B2 | N6 |
| O-OP8 | (a) R2-4 lifts ADR 0053 item 6 in the work runtime; (b) the registered-clone `repo` check only (`owner-decisions.md:70`) | B1 credentials | (new) |
| O-OP9 | traces scanned; images attached unscanned and labelled (`owner-decisions.md:71`) | B4 `pr-attach`, B7 | N3 |
| O-OP10 | a tenth code `action-failed`, curable (`owner-decisions.md:72`) | B2, B2.1, B3 step 9; errata E14 | (new) |
| O-Q2 | one optional per-work_item done-condition field, required under `step_complete` (`owner-decisions.md:74`; ADR 0054 `:272-273`) | C1.2 `done_condition`, C1.3 rule 9, D2.3 | N2 |
| O-Q3 | gate and fix agents count toward `max_concurrent` (`owner-decisions.md:74`; ADR 0054 `:274`) | A.4, C1.1 | N1 |
| O-Q4 | `depends_on` edges same-wave only; declared waves stay barriers (`owner-decisions.md:74`; ADR 0054 `:275-276`) | C1, C1.2, C1.3 rule 15; errata E12, E13 | N8 |
| O-Q5 | per-work_item gate, fix loop and budget term in a frontier wave (`owner-decisions.md:74`; ADR 0054 `:277`) | C1.1 `dispatch_budget`, C1.2, C2 | N9 |
| O-Q6 | the checkpoint is the sole resume authority (`owner-decisions.md:74`; ADR 0054 `:278`) | C2 `PASS`, C5.3 | (new) |
| O-Q7 | the caller consumes the fallback file (`owner-decisions.md:74`; ADR 0054 `:279`) | C4 | (new) |
| O-Q8 | a differing per-wave `output_topic` fails validation (`owner-decisions.md:74`; ADR 0054 `:280`) | C1.3 rule 14 | (new) |
| O-Q9 | `max_concurrent` is an invocation argument (`owner-decisions.md:74`; ADR 0054 `:281`) | A.4, C1.1, D2.3; errata E12 | N8 |
| O-Q10 | `persona` and `lane` are per work_item (`owner-decisions.md:74`; ADR 0054 `:282`) | C1.2, D2.3 | (new) |
| O-Q11 | a barrier-wave `step_complete` gate passes only when every gate passes (`owner-decisions.md:74`; ADR 0054 `:283`) | C1.2 verifier | (new) |
| O-N10 | "ALWAYS HUSKY=0 on desk pushes"; the recorded affected pass before each push (D21/R2-3) still applies (`owner-decisions.md:80`) | A.7, B4 `push`, `pr-create` | N10, r3 H36 (moot) |
| O-N11 | "tag-push behaviour is set per repo in repo-profile.md": "whether the repo uses release tags at all"; "if it does, its push and approval rule"; "With no profile entry, tag-push is refused." (`owner-decisions.md:81-84`) | A.2.2 `release_tags.*`, B2.1, B3, B4 `tag-push`, B8 | N11, r3 H14 |

| O-PG | PORT GUARD: "ensure we have the port check hook setup in agent-hq and that its apart of this plan" (`architecture/delivery-workflow-sources/owner-decisions.md:85-87`) | A.5.1, A.5.2, C1.1, D4, D5, D6; errata E18 (amendment AM-1) | (new) |
| O-SA | security-audit skill: desk INSTALL into agent-hq, wired into the security seat in the pre-PR gate and panels (`owner-decisions.md:77`) | A.2, A.4, A.5.3, A.6, D2.1-D2.3, D6; errata E19 (amendment AM-1) | (new) |

`owner-decisions.md` = `architecture/delivery-workflow-sources/owner-decisions.md`; ADR 0054 = `decisions/0054-adr-0023-amendment-delivery-workflow.md`.

### Decisions added by the round-4-0 fix (2026-10-26; Kind DEF)

| Id | Topic | Resolution | Kind |
|---|---|---|---|
| R40-1 | `tag-push` profile forms for O-N11 | keys `release_tags.used` `"yes"\|"no"` (quoted, R4-J1), `release_tags.pattern` anchored regex, `release_tags.approval` `none\|human` (A.2.2); absent or `no` or no pattern match = `policy`; `human` = `H-prod.<step_id>.ok` else `gate-missing`; `tag-push` gains `step_id` (B4) | DEF |

### Decisions added by the round-4 fix (2b review r4, 2026-10-26; all Kind DEF)

| Id | Topic | Resolution | Kind |
|---|---|---|---|
| R4-J1 | `repo-profile.md` serialization, writer, keys | one YAML document, dotted = nested map, `"yes"`/`"no"` quoted, regexes single-quoted; writer `delivery-intake` for every key; added `clones[]`, `linked_profiles[]`, `worktree_base`, `ci.min_push_spacing_s`, `ci.max_open_pr_pipelines`, `jira.status_map`, `secrets.pattern_file`, `gates.*`, `node.prefix_cmd`, `zephyr.read_ops`; `release-track` reads `release_tags.*` (A.2.2) | DEF |
| R4-J2 | per-repo profile resolution (O-N11) | desk reads `state.md` `repo_profile`; primary `clones[]`, else `linked_profiles[]` entry; unresolved = `repo` (`policy` for `tag-push` on an unreadable linked profile) (A.2.2, B1, B4) | DEF |
| R4-J3 | `step_id` minting | `release-plan.md` step table, ids minted by `delivery-architecture` in v0, unchanged in v1 (A.6) | DEF |
| R4-J4 | malformed `release_tags` entry | `used: "yes"` with absent or bad `pattern` or `approval` = `policy`, key in `detail` (A.2.2, B2.1, B4) | DEF |
| R4-J5 | regex dialect | POSIX ERE, numbered groups; `\|` is Markdown escaping; `\t` literal TAB; `job` `^[^[:cntrl:]]{1,200}$` (§Regex dialect, B2, B4, D1) | DEF |
| R4-J6 | `DESK`/`DONE`/`REJECTED` regexes | anchored ERE per line, 64-hex, verdict `[^\|[:cntrl:]]+`; a non-matching `DESK` line is logged, no reply; "no imperatives" not machine-checked (B2) | DEF |
| R4-J7 | `INPUT-ERROR` field class | `[A-Za-z_][][A-Za-z0-9_.]*` (D1) | DEF |
| R4-J8 | duplicate-action guard targets | `repo#branch@expect_head` (`push`, `pr-create`), `repo#tag@sha` (`tag-push`); "already done" only on an equal remote sha (B2) | DEF |
| R4-J9 | applied-result scan on resume | each requester applies unrecorded `DONE` `.out` results of its verbs before any send (B1) | DEF |
| R4-J10 | lock break and timeout | after `mv`, re-read `owner`; on mismatch rename back and start over; 1 s retry, 60 s timeout, exit 4 (A.3, §Script interfaces) | DEF |
| R4-J11 | stop-the-line row ids | closed table `S1`-`S8` plus design ids `G1`, `G3`, `G4`, `G5`, `D23`; bus down = `S8` (A.3, C7) | DEF |
| R4-J12 | dispatch record contract | caller input `invocation` (`substate.md` `invocation`, written before each call); path `dirname(bus_endpoint)/dispatch/<invocation>.jsonl` only when `bus_endpoint` is declared, line written before dispatch; adds `persona`, `tier`, `backend`; gate `gate-checker`, fix `fixer`; lead derives `worktree` (A.3, C1.1, D2.3) | DEF |
| R4-J13 | `wave-execution` call model | background Agent task, lead idles, cron runs C2/C4/C7; controller depth 1, its agents depth 2 (none dispatches; measured limit 3); errata E16 (C1.1, C7) | DEF |
| R4-J14 | persona brief | instruction passed verbatim; the agent reads its `Brief:` file first; `delivery-run` copies nothing (C1.2; replaces the C1.2 row of the round-1 table) | DEF |
| R4-J15 | `ROLLED`/`ESCALATE` at the controller; re-dispatch | gate fails any non-`PASS` record (A5); caller input `tier_override` `<unit>=<tier>` on a fresh invocation (C1.1, C2, D2.3) | DEF |
| R4-J16 | `delivery-run` inputs | adds `REPO_PROFILE`, `REPO`, `SESSION`, `PM_SHA` (required for `post-merge`) (D2.2 row 6, A.2) | DEF |
| R4-J17 | sub-task branch, ticket, worktree | dispatch-plan sub-task table `ticket`, `branch` `<key>-<slug>`, `repo`; worktree `<worktree_base>/<run-id>-<subtask>`; `st0` copies `PLANS_DIR` files onto its branch before `pre-pr-gate` (A.6) | DEF |
| R4-J18 | `RELEASE:` terminal tokens | `LIVE`, `ROLLED-BACK` terminal; `WAITING-HUMAN` rewritten; `pm` cleanup and stage 8 only on terminal (C5.1, D1.1) | DEF |
| R4-J19 | v1, retro, execution-log route | RUN-only (`RUN_HOME/release-plan.md`, `retro.md`, `execution-log.md`); plan-plane commit is a human step after CYCLE DONE; errata E17 (A.6, D6) | DEF |
| R4-J20 | `pr-create` and `push` CI bounds | not a lease: `gh` open-PR count vs `ci.max_open_pr_pipelines`, `REJECTED marker` `pipeline-bound`; spacing wait up to 5 min, else `marker` `push-spacing` (B4) | DEF |
| R4-J21 | `scope-check.sh` inputs | tasks file under `primary_repo`; `base-sha` by `merge-base`, never stored (§Script interfaces, C7) | DEF |
| R4-J22 | EXTEND input names | UPPER_SNAKE except `wave-execution`: `ROLES`, `FILE_SET`, `STACK_BASE`, `STACK_HEAD`, `RECORD_PATH` (D2.3) | DEF |
| R4-J23 | `interfaces_version` producer | dispatch-plan header and seed key; `delivery-run` Step 0 compares with `state.md` (A.2, A.3, A.6, D2.2, D7) | DEF |

### Freeze items (ADR 0055 `[freeze]`, settled by the integrator at the 2b loop; all Kind DEF, "freeze item")

| Id | Freeze item (ADR 0055 line) | Frozen form (home) | Kind |
|---|---|---|---|
| FRZ-a | conductor registration line (`:62-64`, `:213`) | `REGISTER-SENDER <run-id> \| <subtask\|run> \| <sender-id>` / `REGISTERED ... \| ok\|refused`, regexes in part B1 | DEF, freeze item |
| FRZ-b | desk session name (`:73-76`) | `DESK_ADDRESS` = `desk` (R-1 generic; one desk session per environment), part B1 | DEF, freeze item |
| FRZ-c | class of the nine non-`action-failed` codes (`:117-122`) | terminal `{sender, schema, hash, repo, policy}`; curable `{marker, order, stale-session, gate-missing}` (+ owner's `action-failed`), part B2.1 | DEF, freeze item |
| FRZ-d | conductor-only verb list (`:81-83`) | `^(pr-merge\|publish\|tag-push\|test-report-push)$` with `<subtask>` `run`; epic `jira-create` via `run`, part B1 | DEF, freeze item |
| FRZ-e | relayed `claude -p` cross-check (`:89-92`, `:159-161`) | JSON envelope `subtask` equals the `<id>` `<subtask>`, else `schema`, part B1, B3 step 5 | DEF, freeze item |
| FRZ-f | `pr-attach` root (`:100`, `:184`); `record_path` root (`:170-171`) | `RUN_HOME/<subtask>/lanes/`; `RUN_HOME/review/<subtask>/`, part B4 | DEF, freeze item |
| FRZ-g | per-verb marker list (`:178-180`) | `push` head + gate run; `pr-create` head, gate run, record (r3 H17, ADR 0055 `:166-168`); `pr-merge` head, gate run, record, H-pr, CI, order, `merge_reach`; `branch-delete` content-merged, part B5 | DEF, freeze item |
| FRZ-order | replay-check order (`:185-191`) | bind sender, then a stored `.out` answers a repeat id (no hash compare), then copy and hash, part B2, B3 | DEF, freeze item |
| FRZ-h | H-prod gate path (`:201-202`) | `RUN_HOME/gates/H-prod.<step_id>.ok`, part B4, B8 | DEF, freeze item |
| FRZ-i | id-form non-collision (`:219-223`) | `<run-id>-<subtask>` regex carries an 8-digit date segment no profile name has; checked 2026-10-26 and at the move, part B2 | DEF, freeze item |

## Design errata (not edited here; W3 item 33 applies them)

| # | Design text | Correction |
|---|---|---|
| E1 | §2.2 card 11 "before each commit (D21)"; changelog D21 row "per commit" | once per push or batch (R2-3); the single statement is part A.7 |
| E2 | §5.6 column list includes `verify_cmd` while the same section says "no executable column" | column dropped (M26); 12 columns, part A.5 |
| E3 | §5.0 `bus.endpoint` fields `port, data_dir, pm2_app, pid` | add `session_id`, `topic` (§3.0 depends on them), part A.3 and D5 |
| E4 | §5.11 row places `bus.endpoint` under `RUN_HOME/<subtask>/bus/` | the file sits at `RUN_HOME/<subtask>/bus.endpoint` (card 6), the `data_dir` under `bus/` |
| E5 | §6.3 prose and card 15 `DONE <id> \| <one-line verdict>` | the long grammar line (owner 2026-10-26, OP2 A, `owner-decisions.md:64`; `decisions/0055-desk-verb-permission-tiers-02.md:58-59`), part B2 |
| E6 | changelog B1 row "per-request account lock" | no accounts (R2-4); no lock, part B3 |
| E7 | changelog M19 and M21 "conductor topic" | inbox files only (§5.0, fix-verifier follow-up), part C5 and D4 |
| E8 | §5.0 "the desk refuses ... generation until `H-e2e.<subtask>.ok` exists" | the desk writes the file; the lead enforces it (generation is lead-side), part A.2.1 |
| E9 | §2.2 card 6 "in-session leads receive `SendMessage`" | the inbox file is canonical; a `SendMessage` is only a pointer `INBOX <subtask>`, part C5.2 |
| E10 | §1 stage 3 "empty `catalog.tsv`" with no path; §5.11 lists no plane for `brief.md`, `facts.md`, drafts, seed files or the run records | `RUN_HOME/catalog.tsv`; planes per part D6 |
| E11 | §6.3 `pr-create` and `pr-merge` schemas lack the review-record carrier | `record_path` field (owner Q3, `owner-decisions.md:60`, decisions log B5), part B4 |
| E12 | §2.2 / §4: `max_concurrent` as a spec value, "lane-waves 1..N" as numbered wave files | caller argument (owner 2026-10-26, ADR 0054 Q9, `owner-decisions.md:74`); one DAG wave `01-build.md` per sub-task with `depends_on` edges (owner Q4, same line; `decisions/0054-adr-0023-amendment-delivery-workflow.md:93-96`), part C1, C1.1 |
| E13 | design text places `depends_on` edges across waves | edges inside one wave only (preflight rule 15; owner 2026-10-26, ADR 0054 Q4, `owner-decisions.md:74`), part C1.3 |
| E14 | §6.3 grammar line lists nine `REJECTED` codes | ten codes: `action-failed` added, curable (owner 2026-10-26, OP10 A, `owner-decisions.md:72`; `decisions/0055-desk-verb-permission-tiers-02.md:58-59`, `:141-143`), part B2, B2.1 |
| E15 | §2.2 card 6 (`part-02-skill-inventory.md:60`) and §2.3 `wave-execution` row (`:84`): per-wave `max_concurrent`, no `bus_endpoint`, "cancellation = `TaskStop` of dependents" | `max_concurrent` per invocation (ADR 0054 A1, Q9); optional bundle `bus_endpoint` (A9, owner Q2); dependents are never released on gate failure (A5), part C1.1, C1.2 |
| E16 | §3.1 depth column: implementer, test writer, e2e writer, fixer, fix-verifier, Integrator, lane runner at "depth 1"; "Max depth below a lead is 2" | under the R4-J13 call model the `wave-execution` controller is depth 1 and the agents it dispatches depth 2 (none dispatches; review stays lead 0, orchestrator 1, seats 2), so max depth below a lead stays 2, within the measured limit 3 (`measurements-2026-10-26.md:115-118`); the §3.1 depth-2 fallback also covers waves (blocking call, part C1.1) |
| E17 | §1 stage 7-8 and card 13: `release-plan.md` v1, retro and execution-log rows committed to `plans/<epic>/` | RUN-only in this contract version; the commit is a human step after CYCLE DONE (row R4-J19), part A.6, D6 |
| E18 | §3 lanes, §4 namespacing ("ports from the `port-claim` register"), card 8 and card 9 `port` rows, the Move and P0 rows: no claim-before-launch rule, no hook, no positive control | port guard (AM-1, row O-PG): claim with `tools/port-check.sh` before every bind, refuse on collision, never auto-pick; catalog `port` row released at cleanup by a `released` registry row; `tools/hooks/port-precheck.sh` installed at the Move from `config/settings.json`, `ports.tsv` / `app-ports.tsv` filled at the Move; P0 positive control of the hook, part A.5.1, A.5.2, C1.1, D4 |
| E19 | §1 stage 4b, §2.2 card 10 (`pre-pr-gate`) and the §2.3 `pr-review` row: the security seat has no named skill or mode; §3 slot counting has no security-audit agents | `skills/security-audit` (AM-1, row O-SA): guidance mode in the security seat, diff-scoped, no files, no extra agents; full audit mode only on an operator request or a `security_sensitive: yes` epic, run directory `RUN_HOME/<subtask>/security-audit/run-<N>`, agents in the slot ledger, no-network target code, `validate-findings.cjs` gate row, part A.2, A.4, A.5.3, D2.1-D2.3 |

## Checks run at integration

- `bash tools/check-doc-length.sh .` on the worktree: result recorded in the integrator's reply.
- `grep -rn "OPEN" architecture/delivery-workflow/interfaces/`: no `OPEN:` markers remain (the word appears only in the phrase "former `OPEN`" in each part's status line).
- Every part is at or under 500 lines.
