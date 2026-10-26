# Plan-check: the 23 W1 task specs (design §7 item 2b, D55)

- **Date:** 2026-10-26. **Checker:** Plan-checker (verify persona; never an author of the specs). **Scope:** `architecture/delivery-workflow/tasks/*.md`, 23 files.
- **Authorities, in order:** INTERFACES 1.1.0 (`INTERFACES.md` and `interfaces/part-a..d`); ADR 0054 and ADR 0055 (accepted); the design (`part-01..06`, `changelog.md`); owner rulings (`architecture/delivery-workflow-sources/owner-decisions.md`); `measurements-2026-10-26.md`.
- **Method:** each question in each spec was answered from the first authority that settles it; where none does, the simplest choice that keeps every ruling is taken and marked `PLAN-CHECK DEFAULT`. Each spec was edited in place: every `SPEC-QUESTION` became a `RESOLVED (<authority or DEFAULT>): <answer>` entry (the question lists are now headed "Plan-check resolutions"). INTERFACES, the ADRs and the design were not edited. Nothing was committed.

**PLAN-CHECK: PASS** (no owner fork blocks a spec from dispatch; the three owner questions below are non-blocking and each has a default in force).

## 1. Per-spec results

"Questions" counts distinct questions (the brief's figure of about 120 counted every line that mentions one; there are 94 distinct questions). "Defaults" is the subset answered by `PLAN-CHECK DEFAULT` or a cross-spec decision (PC-n); the rest cite an authority. "Other fixes" lists what the cross-spec pass changed beyond the questions.

| Spec | Item | Questions | Defaults | Owner forks | Other fixes |
|---|---|---|---|---|---|
| 05 `catalog.sh` | 5 | 6 | 4 | 0 | `! grep` checks made fatal (they were ignored under `set -e`); `WORKTREE_BASE` criterion added |
| 06 `scope-check.sh` | 6 | 3 | 1 | 0 | `! grep` checks made fatal |
| 07 `desk-req.sh` | 7 | 5 | 2 | 0 | `! grep` checks made fatal; inline question numbers corrected; exact D1 error text |
| 09 `wave-execution` | 9 | 4 | 2 | 0 | branch `ext/delivery-extends`; §9 rewritten so it can fail (old lines printed "MISSING" or nothing and still exited 0); `version: 1.1.0` criterion |
| 10 `pr-review` | 10 | 6 | 5 | 0 | branch; §9 rewritten to `EXT-10-OK`; new input `BUS_PORT` (PC-4); scope check fixed for the shared branch |
| 11 `fix-verifier` | 11 | 4 | 4 | 0 | branch; self-printing `OK-fixture` replaced by checks over saved verifier outputs; scope check fixed |
| 12 `doc-reviewer` | 12 | 5 | 4 | 0 | as 11 |
| 13 `feature-change` | 13 | 6 | 4 | 0 | as 11; `WORKTREE_BASE` on catalog calls |
| 14 `delivery-intake` | 14 | 2 | 1 | 0 | §9 rewritten (it never printed the `PASS` its done condition named); dry-run outputs checked |
| 15 `delivery-architecture` | 15 | 4 (+1 cross) | 3 | OQ-1 (non-blocking) | §9 rewritten; draft front matter (PC-11) |
| 16 `review-tailor` | 16 | 5 | 3 | 0 | §9 rewritten; fixture records checked; item cross-reference 21 -> 20 |
| 17 `delivery-dispatch-plan` | 17 | 4 (+1) | 3 | 0 | port table and budget criteria; sanitization grep skips `templates/` |
| 18 `resource-catalog` | 18 | 4 | 1 | 0 | `skills/port-claim/SKILL.md` added to scope (claim before bind); `templates/` excluded |
| 19 `delivery-cleanup` | 19 | 5 | 2 | 0 | tokens for the spot-check and abandoned-run rule |
| 20 `pre-pr-gate` | 20 | 4 | 2 | 0 | §9 rewritten; `PREPR:` ids (PC-8); port step moved to `pr-review` (PC-4); briefs dir removed; item cross-references 9-11 -> 10-11, 16 -> 18 |
| 21 `post-merge-verify` | 21 | 3 | 1 | 0 | §9 rewritten; reporting row handed to `release-track`; item cross-reference 16 -> 18 |
| 22 `ticket-clerk` | 22 | 4 | 2 | 0 | §9 rewritten; item cross-reference 18 -> 17 |
| 23 `delivery-shepherd` | 23 | 1 | 0 | OQ-3 (non-blocking) | §9 rewritten; it had no done condition |
| 24 `ci-fix-loop` | 24 | 4 | 2 | 0 | §9 rewritten; it had no done condition |
| 25 `release-track` | 25 | 6 | 4 | 0 | §9 rewritten; it had no done condition; test-map rows for its 3 scripts |
| 26 `delivery-desk` | 26 | 2 | 1 | 0 | none |
| 27 template pack | 27 | 3 | 2 | 0 | checklist row ids, draft front matter and port table added to the templates and the checks |
| 27b persona briefs | 27b | 4 | 2 | 0 | none |
| **Total** | 23 specs | **94** | **55** | **3 (none blocking)** | |

Resolved by an authority: 39. Taken as default: 55. Open: 0. `grep -rn SPEC-QUESTION tasks/` returns nothing.

## 2. Cross-spec decisions

- **PC-1 EXTEND branch and version (specs 9-13).** One branch `ext/delivery-extends`, worktree `~/projects/agent-hq-worktrees/delivery-extends`, created by the integrator (Worker1) from `wt/delivery-w0` after the plan-check commit, so it holds the W0 item 8 ports. Items 9-13 share it on disjoint directories (9 also owns `architecture/wave-execution.md`); it is reviewed separately and never reviews the family (M29). Version rule: an unversioned skill at `c1ba30e` or the item 8 port counts as `1.0.0`; each EXTEND writes `version: 1.1.0`; every NEW skill starts at `version: 0.1.0` (the A.2 example); later wording fixes bump the patch, a new input or behaviour bumps the minor. Each EXTEND §9 checks the union of the five EXTEND scopes with `git status --porcelain`, because a per-item `git diff` on a shared branch would flag the other four items.
- **PC-2 Done conditions.** Every spec now has one machine-checkable done condition. For specs 9-16 and 20-25 that is "the §9 block exits 0 and its last line is `<TOKEN>-OK`" under `set -eu`. Three defects were removed: `! grep` lines (ignored by `set -e`), lines that printed `MISSING` and went on, and `echo OK-fixture` lines that printed regardless of the outcome. Where a check needs an agent run (the prose EXTENDs, the dry runs of 14-16), a non-author verifier saves the outputs under `FIXTURE_DIR` and §9 checks those files. Every command a §9 block runs is either a system tool, a file in that spec's own scope, or `tools/check-doc-length.sh` (on disk). Each block passes `bash -n`.
- **PC-3 Directory disjointness (Rule 7).** No two specs write the same file.
  - Item 27 owns every `skills/*/references/templates/` directory it lists. Specs 14, 15, 17, 18 and 20 exclude it, and their checks skip it.
  - Persona briefs have one root, `skills/delivery-run/references/briefs/` (INTERFACES C1.2, D2.1, R4-J14). Spec 20 no longer names a briefs directory of its own, and 27b's four pieces are file-disjoint inside that root. The W2 specs for 28 and 29 must exclude `templates/` (and, for 28, `briefs/`).
  - Items 5-7 share `tools/delivery/` with disjoint file names and no shared library. The `mkdir` lock is inline in 5 and 7; a later `lib-lock.sh` extraction belongs to the integrator, after all three scripts pass the code gate, as a separately reviewed change.
  - `skills/port-claim/SKILL.md` is now in spec 18's scope only.
  - `tools/code-gate/test-map.tsv` is written only by the integrator, serially: rows for 5-7, 9 (`tests/run.sh`) and 25 (three scripts). Item 32's code gate covers all of these.
- **PC-4 Ports (specs 9, 10, 17, 18, 20, 21, 24, 25, 27, 27b).** A.5.2 is the one mechanism: claim before bind, refuse on collision, never auto-pick.
  - The design's "+10 rule" survives only as the dispatch plan's candidate formula `<base> + 10·k`, fixed before any check. `st<N>` bus `k = 2N`, review bus `k = 2N + 1`; lanes use their lane index (lane leases are run-wide, so the `pm` lead reuses them). A serial lane whose ports are fixed in the app config keeps them.
  - The bases come from the proposed profile keys `ports.bus_base` and `ports.lane_base`. When a key is absent the plan writes `FILL_IN_BEFORE_DISPATCH`, which fails the pre-dispatch checklist.
  - The launcher claims its candidate. A refusal is `lane-unavailable` for a lane, or a report to the lead for a bus, and is never re-picked. The plan runs no `port-check.sh`.
  - The bus's `get-port` self-selection is neutralised by starting the server with `PORT_RANGE_START=PORT_RANGE_END=<claimed port>` and checking `$DATA_DIR/port` afterwards.
  - The sub-task bus is claimed by `delivery-run` (D5), so `wave-execution` adds no claim.
  - The per-review bus is claimed in `pr-review` Step 1 from a new input `BUS_PORT` that `pre-pr-gate` passes; `pre-pr-gate` claims nothing.
  - Standalone `pr-review`, run outside any delivery run, keeps today's flow.
  - The installed `port-claim` skill claims after the bind (Step 4). Spec 18 amends it to claim before the bind and keeps "Do not auto-pick".
- **PC-5 Shepherd vs watchdog (spec 23, card 7).** INTERFACES C7 governs. The shepherd raises `DRIFT`, `CREEP` and `FREE-CANDIDATE`. `delivery-run`'s watchdog half raises `STALLED` and `PROMPT-OPEN` and runs the bus-down check and the orphan sweep, on every tick, so it also runs below 3 live agents. Card 7 is design errata. Both halves append to `shepherd/ticks.md`.
- **PC-6 `test-report-push` owner (specs 21, 25).** `release-track` owns it (D2.2 row 13). `post-merge-verify` records per-row results in `postmerge-<sha>.md` only.
- **PC-7 `GATE-PASS` writer (spec 13 vs A.7).** The gate runner writes it, never the author (A.7). In the §2.3 `feature-change` card, "record `GATE-PASS`" now reads "obtain from the gate runner and cite" (errata).
- **PC-8 `PREPR:` values (spec 20, 27).** The token is `PREPR: PASS` or `PREPR: STOP <ids>`.
  - Ids `C1`-`C23` are the §5.7 rows in their written order. `C24` is the version-bump check, `C25` the dist scan, and `C26` the `validate-findings.cjs` row (full audit only).
  - The ids are defined in item 27's checklist template. A.5.3's "`PREPR: FAIL`" becomes `PREPR: STOP C26`.
  - A full audit runs after the G48 pre-round check and before round 1, because the security seat reads its `findings.json`.
  - When fixes move the head, the gate runner re-runs the same cold command on the final head (A.7 cadence, B5 marker; row `C9`).
- **PC-9 Profile sha (spec 14).** `@<sha>` is the git blob id from `git -C <primary_repo> hash-object -w <profile>`. It exists before any commit, and readers check it with `git hash-object`.
- **PC-10 Review-tailor record (spec 16).** The seat table runs from line 2 to the first blank line. Four `key: value` lines follow it: `mechanism`, `tiers`, `budget`, `dispatch`. Seats by rung: Rung 0 has 0; Rung 1 has 1; Rung 2 at most 9; Rung 2b at most 7; Rung 3 exactly 7; Rung 4 has 11. `SECURITY_AUDIT` is a required input. The `SLUG` is minted by the caller: `run-doc-<n>` (15), `run-plan-<n>` (17) and `<subtask>-diff-<n>` (20).
- **PC-11 Ticket drafts (specs 15, 22, 27).** `drafts/<slug>.md` opens with YAML front matter `slug`, `issuetype`, `parent` (`-` for the epic).

## 3. Coverage

Every W1 item of design §7 has exactly one spec: 5, 6, 7 (scripts); 9, 10, 11, 12, 13 (EXTENDs); 14-22 (nine NEW skills); 23, 24, 25 (pilot drafts); 26 (`delivery-desk`); 27 (templates); 27b (briefs). That makes 23 specs for 23 items. Items 28 (`delivery-run`) and 29 (`delivery-pipeline`) are W2 and have no spec yet. Their authors inherit these constraints:
- 28 excludes `references/briefs/` and `references/templates/`.
- 28 owns the bus claim (PC-4), the watchdog half (PC-5) and the C2 wording for `step_complete` (spec 9 Q3).
- 29 adds the Zephyr `--disallowedTools` entry to the launcher spec (spec 25 Q6).
- 28 and 29 must not edit the W1 directories.

## 4. Proposed amendment AM-2 (for the integrator; INTERFACES not edited)

The rung is 2b, because the change has more than three consumers (D7). Approver: the owner, through the item 33 packet. Bump to `1.2.0`. Each row gives the section, the exact text to add or replace, and the consumers to re-check.

| # | Section | Exact text | Consumers |
|---|---|---|---|
| 1 | §Script interfaces, `catalog.sh` row; A.5 "Rejected" sentence | Add: "env `WORKTREE_BASE` optional (absolute, `^/[^[:space:]]+$`, the profile `worktree_base`); unset: only `RUN_HOME` is a legal root; a bad value is exit 2." | `catalog.sh`, `resource-catalog`, `delivery-run`, `feature-change`, `delivery-cleanup` |
| 2 | A.5.1 heading and A.5 "Rejected" | Replace "(fixed inside `catalog.sh`; M26)" with "(fixed in this table, M26; `catalog.sh audit` implements the verify column; the cleanup column is applied by the `delivery-cleanup` executor; `catalog.sh` has no cleanup subcommand)"; replace "a row over 400 bytes" with "a row over 400 bytes including its trailing newline". | `catalog.sh`, `delivery-cleanup`, `resource-catalog` |
| 3 | A.5 Lifecycle, after "`audit` classifies" | Add: "Audit reads every pair whose latest state is `planned` or `live`: alive is `MATCH`, gone is `GHOST`; `lane-lease` is always `MATCH`; `container`, `image`, `workspace`, `db`, `cron`, `bgtask` print no line; `SQUATTER` is only a git worktree under `worktree_base` named `<run-id>-*` with no open row; port squatters are `port-check.sh --audit`'s." | `catalog.sh`, `delivery-run` (resume), `delivery-cleanup` |
| 4 | A.2 `repo_profile` row; D1.1 `PROFILE:` | Add: "`<sha>` is the git blob id of the profile file, `git -C <primary_repo> hash-object -w <path>`; a reader verifies `git hash-object <path>` or reads `git cat-file blob <sha>`." | `delivery-intake`, conductor, `delivery-desk` (profile resolution), every `REPO_PROFILE` reader |
| 5 | A.2.2 key table | Add rows: `ports.bus_base`, `ports.lane_base` (int; lead, `delivery-dispatch-plan`); `sensitive_paths[]` (list of ERE; includes CI and pipeline definitions; `pre-pr-gate` step 5, `ci-fix-loop` D23); `review_profile.mandatory_seats[]`, `review_profile.blocking_rules[]` (list; `review-tailor`; absent = none, not an `INPUT-ERROR`); `zephyr.execute_tool` (string; `release-track`, launcher). Writer `delivery-intake`. | `delivery-intake`, `delivery-dispatch-plan`, `pre-pr-gate`, `ci-fix-loop`, `review-tailor`, `release-track`, `delivery-pipeline` |
| 6 | A.5.2, after "Order before launch" | Add: "The candidate port is fixed before any check by the dispatch-plan port table: `<base> + 10·k` (`st<N>` bus `k = 2N`, review bus `k = 2N + 1`, lanes by lane index; fixed app ports keep `k = 0`). A bus server is started with `PORT_RANGE_START=PORT_RANGE_END=<port>` and its `$DATA_DIR/port` must equal the claim. The +10 offset is never applied after a refusal." | `delivery-dispatch-plan`, `delivery-run`, `pr-review`, `port-claim`, lane runner brief |
| 7 | D2.3 `pr-review` row | Add input: "`BUS_PORT` (int 1-65535; the claimed per-review bus port, passed by `pre-pr-gate` from the port table; required when `RUN_HOME` is set, absent standalone; Step 1 runs the A.5.2 order with it)." | `pr-review`, `pre-pr-gate`, `delivery-dispatch-plan` |
| 8 | D1.1 `PREPR:` row; A.5.3 | D1.1: replace "`<rows>` = comma-separated failed §5.7 row ids" with "`<rows>` = comma-separated failed checklist ids `C1`-`C26` (`C1`-`C23` the §5.7 rows in order, `C24` version bump, `C25` dist scan, `C26` `validate-findings.cjs`), defined in the `step-completeness-checklist.md` template". A.5.3: replace "(a non-zero exit is `PREPR: FAIL`)" with "(a non-zero exit fails row `C26`: `PREPR: STOP C26`)". | `pre-pr-gate`, checklist template, `delivery-run`, conductor |
| 9 | D1.1 `RUNG:` row | Add: "the seat table runs to the first blank line; then the lines `mechanism:`, `tiers:`, `budget:`, `dispatch:`. Seat counts: Rung 0 = 0, Rung 1 = 1, Rung 2 at most 9, 2b at most 7, 3 = 7, 4 = 11." | `review-tailor`, `pr-review`, callers 15, 17, 20 |
| 10 | A.6 `drafts/<slug>.md` | Add: "each draft opens with YAML front matter of exactly `slug`, `issuetype` (D2.1 ticket issue type), `parent` (parent slug, `-` for the epic)." | `delivery-architecture`, `ticket-clerk`, ticket template |
| 11 | A.1 derived paths row `shepherd/ticks.md`; D6 | Replace writer "shepherd" with "shepherd (shepherd half) and the lead (watchdog half, part C7), single-line appends only". | `delivery-shepherd`, `delivery-run` |
| 12 | D2.2 row 11 | Replace "budget fixed at 3 per signature" with "budget fixed at 3 per signature, signature = diagnoser `class` + `job`; capacity-induced failures are `capacity:` lines in `ci/<pr>.md`, counted run-wide, outside the signature budget". | `ci-fix-loop` |
| 13 | D6 RUN rows | Add: "`pm/zephyr-refusals.log` (RUN `pm/`; writer the `release-track` Zephyr hook; reader human, conductor)". | `release-track` |
| 14 | C5.1 "`pm` and `final` cleanup" | Add: "Abandoned run: after `stage: stopped` the conductor runs mode `final` with evidence `state.md` `stage: stopped` and no `MERGE_RECORD`; D8 and D9 keep unmerged branches and their worktrees, flagged." | `delivery-cleanup`, `delivery-pipeline` |
| 15 | B6, last paragraph | Add: "`schemas.json` layout: JSON Schema draft-07; top keys `verbs` (per verb `request` and `result` object schemas with `required` and `additionalProperties: false`), `reason_codes` (`class`, `trigger`), `envelope`, `regexes` (B1, B2, B8 line regexes)." | `delivery-desk`, `desk-req.sh` (item 33 diff) |
| 16 | Design errata table (W3 item 33 applies) | E20 card 7: `STALLED`, `PROMPT-OPEN` and the orphan sweep are the `delivery-run` watchdog half (C7). E21 §2.3 `feature-change` "record `GATE-PASS`" -> "obtain from the gate runner and cite" (A.7). E22 card 8 "+10 rule" -> the plan-time candidate formula of A.5.2 only. E23 card 12 test-result reporting -> `release-track` (D2.2 row 13). E24 part-06 item 27b "in the owning skills" -> one root `skills/delivery-run/references/briefs/` (C1.2). | item 33 |

## 5. Owner questions (non-blocking; a default is in force for each)

- **OQ-1 When is an epic `security_sensitive: yes`?** No source gives the criterion; it decides when the full audit runs (a safety control). *Recommended answer, in force as the spec 15 default:* `yes` when the epic changes authentication or authorization, session or token handling, secrets or credential sources, payment or money flows, personal data, the e2e mock or auth-bypass gate (M25, M26), network-reachable input parsing, or adds a third-party dependency; when unsure, `yes`. A `yes` only adds the audit and never removes a control.
- **OQ-2 Does the port guard retire the 2026-10-08 "+10 and re-check" rule (R-x) inside delivery runs?** The PORT GUARD ruling and A.5.2 ("never auto-picks") already imply it for every port a run binds. *Recommended answer:* yes inside runs, where the +10 offset survives only as the plan-time candidate formula (PC-4); R-x is unchanged for standalone `pr-review` use outside a run.
- **OQ-3 Is D10's "shepherd flags stalls" met by C7's split?** C7 has `delivery-run`'s watchdog half raise `STALLED` and `PROMPT-OPEN` on every tick, also below 3 live agents, while the shepherd keeps `DRIFT`, `CREEP` and `FREE-CANDIDATE`. *Recommended answer:* yes; keep C7. It flags stalls at least as often, and the lead still decides `TaskStop`.

## 6. Checks run

- `grep -rn 'SPEC-QUESTION' architecture/delivery-workflow/tasks/`: no output.
- `bash -n` on every spec's §9 block (extracted with python3): 23 of 23 parse.
- `bash tools/check-doc-length.sh .` on the worktree: result recorded in the plan-checker's reply.
- Item cross-references `item N (\`skill\`)` across the 23 specs agree with design §7 numbering after the fixes listed in section 1.
