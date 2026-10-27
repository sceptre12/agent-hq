# READY-TO-MOVE: delivery workflow, item 33 packet

- **Date:** 2026-10-26. **Item:** design §7 item 33 (`part-06-build-plan-and-sources.md:32`). **Integrator:** Worker1.
- **Branches:** `wt/delivery-w0` (docs, W1 skills, briefs, templates, the `feature-change` EXTEND, `release-track` scripts, vendored `security-audit`; worktree `~/projects/agent-hq-worktrees/delivery-w0`) is agent-hq PR #13. `ext/delivery-extends` (EXTENDs `wave-execution`, `pr-review`, `fix-verifier`, `doc-reviewer`, items 9-12; worktree `~/projects/agent-hq-worktrees/delivery-extends`, HEAD `a217e0d`) is the follow-up PR (§12); these four EXTENDs are not in PR #13. The delivery scripts, the port guard and the code-gate scope change are on `main` (PRs #9-#12, §2).
- **Contract:** `INTERFACES.md` version **1.10.0** (frozen 1.0.0, ten amendments: AM-1..AM-9 2026-10-26, AM-10 2026-10-27).
- **State at writing (PR #13 round 1):** every item 33 and AM-8/AM-9 edit is committed: `wt/delivery-w0` is pushed (PR #13, reviewed head `941ac56`, plus the round-1 fix commit); `ext/delivery-extends` (`a217e0d`) is committed locally, not pushed.
- **Records:** `SCRATCH/item33/` holds the resolver, viability, fixlog and sweep files named below (`SCRATCH` = the build session's scratchpad; copied nowhere in `agent-hq`).

## 1. What is built

| Area | Content | Where |
|---|---|---|
| Contract | `INTERFACES.md` + parts A (state), B (desk), C (waves and control), D (enums, topics, planes); errata E1-E48 | `architecture/delivery-workflow/` |
| Design | parts 01-06, changelog, measurements, task specs 05-29 | `architecture/delivery-workflow/` |
| ADRs | 0054 (ADR 0023 amendment, `wave-execution` caller-owned bus), 0055 (`DESK` verb, permission-tiers-02) | `decisions/` |
| NEW skills (0.x) | `delivery-pipeline`, `delivery-run`, `delivery-desk`, `delivery-dispatch-plan`, `delivery-architecture`, `delivery-intake`, `review-tailor`, `resource-catalog`, `delivery-cleanup`, `pre-pr-gate`, `post-merge-verify`, `ticket-clerk`, `delivery-shepherd`, `ci-fix-loop`, `release-track` | `skills/` (W) |
| EXTENDs (1.1.0) | `feature-change` (in PR #13); `wave-execution`, `pr-review`, `fix-verifier`, `doc-reviewer` (follow-up PR, not in PR #13) | `skills/` (W; W') |
| Ports (item 8) | `review-7-panel`, `feature-change`, `port-claim` (1.1.1 after item 18), `sim-lease` (skill only, see §6) | `skills/` |
| Vendored | `security-audit` (unmodified, `PROVENANCE.md`) | `skills/security-audit` |
| Briefs, templates | 32 persona briefs; 12 templates | `skills/delivery-run/references/briefs/`, `skills/*/references/templates/` |
| Scripts (main) | `tools/delivery/catalog.sh`, `catalog-audit.sh`, `desk-req.sh`, `desk-req-schema.sh`, `scope-check.sh` + tests (PR #10; `catalog-audit.sh` `bus` verify, V17, PR #11); `tools/port-check.sh`, `tools/lib/port-check-lib.sh`, `tools/hooks/port-precheck.sh`, `tools/ports.tsv`, `tools/app-ports.tsv` + tests (PR #9); `scope.conf` vendored `*.test.cjs` exclusion (PR #12) | `main` |
| Scripts (PR #13) | `skills/release-track/scripts/zephyr-guard.sh`, `check-zephyr-disallowed.sh` + `test_zephyr-guard.sh` (a fail-closed scaffold: its input key set is replaced at P0, §8); gate wrappers `skills/security-audit/tests/test_validate-findings.sh`, `test_validate-coverage-ledger.sh` | W |

## 2. Per-item review outcomes and verdicts

The full table (item, commits, rung, rounds, open B/M/L, D7 stop, record) is the build record in `part-06-build-plan-and-sources.md` §7 "Build record (W0-W3, 2026-10-26)"; records are under `architecture/delivery-workflow/reviews/`. Summary:

| Item(s) | Rung | Verdict at end |
|---|---|---|
| 2 INTERFACES | 2b, 4 rounds (owner one-off r4) | FROZEN; r4 24 M fixed, verify 0/0/7 |
| 2b specs, W2 specs | plan-check | PASS, PASS |
| 3 ADR 0054; 3b ADR 0055 | 1 | 0/0/3; 0/1/1 (D7, OP1-OP10 "Accept all") |
| PR #9 port guard | 3 | r1 0/6/8, r2 0/4/7, r3 PASS 0/0/5; merged (`42a5198`) |
| PR #10 delivery scripts | 3 | r1 FAIL, r2 PASS 0/0/5; merged (`4ee64a0`) |
| PR #11 `catalog-audit.sh` `bus` verify (V17), register handle checks | 3 | r1 FAIL 0/1/2, r2 PASS 0/0/2; merged (`383c43d`) |
| PR #12 code-gate scope: vendored `security-audit` `*.test.cjs` run via wrappers | 3 | r1 PASS; merged (`1bd844e`) |
| PR #13 `wt/delivery-w0` -> `main` | 3 | r1 FAIL 0/2/12 (M1 this packet and stale INTERFACES labels, M2 zephyr profile form); round-1 fix committed, re-review pending |
| 9, 11, 12 EXTENDs | 1 | 0/0/0, 0/0/4, 0/0/3 |
| 10 `pr-review` | 1 | D7 stop 1B, closed by lead decision 10-B2; post-D7 0/0 |
| 13 `feature-change` | 1 | 0/0/7 |
| 14, 17, 19, 21, 25 | 1 | D7 stops; post-D7 fixes owner-accepted, verified CLEAN (21: four edits verified in this sweep, E38) |
| 15 `delivery-architecture` | 2b | D7; "Accept all"; post-D7 CLEAN |
| 16, 18, 20, 22, 23, 24 | 1 | 0/0/3, 0/0/3, 0/0/1, 0/0/9, 0/0/2, 0/0/4 |
| 26 `delivery-desk` | 2b | D7; "Accept verified state" (0/3/11, M fixed+verified) |
| 27, 27b | 1 | 0/0/4; 0/0/12 |
| 28 `delivery-run` | 2b | D7; "Accept all" + S4a/S4b; post-D7 CLEAN |
| 29 `delivery-pipeline` | 2b | D7; "Accept"; 14 FIX M verified CLEAN, not re-panelled |
| 33 (this item) | verify | resolver, viability audit, fix rounds, sweep (§5, §7) |

## 3. D7 stops and the owner's rulings

From `owner-decisions.md` (`architecture/delivery-workflow-sources/owner-decisions.md`) and the build record:
- INTERFACES: one extra 7-seat round as a one-off (`:79`). ADR 0055: OP1-OP10 "Accept all" (`:62-72`, ratified `:76`).
- Item 15 "Accept all" (`:95`); 19 "Accept all" + functional fixture (`:93`); 25 "Accept all" (`:92`); 26 "Accept verified state" (`:94`); 28 "Accept all" + S4a/S4b (`:97`); 29 "Accept" (`:98`); 17 and 21 "Accept both" (record completeness line).
- Item 10: B2 closed by lead decision 10-B2 (no owner line). Item 14: S4-1 a lead mechanical decision reported to the owner.
- Owner rule 2026-10-26: no per-merge confirmation prompts; a PR that passed its CODE-GATE-REVIEW is merged by the desk.

## 4. Lead decisions pending the owner's sight

None of these reopens a ruling; each is mechanism only and awaits the owner's sight through this packet (Amendments table "Approver" column).
- **AM-1..AM-5** rows and the lead decisions listed in `part-06` §7 "Lead decisions for the owner to review": RT-Q1/RT-Q2, 10-B2 review-bus path, PR10-M4 `catalog-audit.sh` exit 5, the desk's double `PREPR` read, 19-F6 no-remote cleanup, desk defaults, 29-1..39 and 28-CV1..CV19 conventions, AM-4 rows and W2-1..W2-10.
- **Owner items still held back:** O-1 (second `pm` lead and stale `substate.md`: lead default `stale-session` refusal) and O-2 (dead-lead relaunch for `merged`-not-`cleaned`: lead default cleanup-only) (`INTERFACES.md` "Owner items from the item 29 panel").
- **AM-6 (1.6.0):** (a) the verdict is a C5.1 inbox message, the desk decides no verdict; (b) the `pm` lead creates its detached worktree; (c) Wave 0 per O3; (d) A.8 cron probe first; (e) CV20/CV33 not adopted; (f) `RESUME` semantics, B9 GATE `<run-id>`; (g) `PLAN-REVIEW: STOP round-3`; C-1, C-3..C-7, B-6..B-9; `desk-req-schema.sh` follow-up rows; spec 28 key.
- **AM-7 (1.7.0):** touch-up 6 `spec_root` = sub-task bundle root (E46); touch-up 7 the owner answers a post-merge row needing a human decision with the desk line `VERDICT <run-id> pm <row-id> <text>`, written as a `pm` inbox `verdict` message, then `RESUME.pm` relaunches the `pm` lead (E47); touch-up 5 C12 keeps both conditions (E48); item 33 consistency fixes listed in the AM-7 bullet.

## 5. Viability ratings (non-author auditors, literal dry read; passes 1-2 against INTERFACES 1.7.0, pass 3 against 1.8.0 (AM-8), then AM-9)

| Group | Items | Pass 1 works / needs rewrite / theater | Pass 2 (after fixes) | Pass 3 (after AM-8, r3) | After AM-9 |
|---|---|---|---|---|---|
| G1 conductors, desk, dispatch-plan, architecture docs | 56 (53 after regrouping) | 22 / 34 / 0 (1 theater row) | 39 / 14 / 0 | 47 / 6 / 0 | 53 / 0 / 0 |
| G2 other W1 skills, 32 briefs, 12 templates | 55 | 41 / 14 / 0 (1 theater row) | 49 / 6 / 0 | 52 / 3 / 0 | 55 / 0 / 0 |
| G3 EXTENDs, scripts on `main` | 12 | 7 / 5 / 0 | 8 / 4 / 0 | 12 / 0 / 0 | 12 / 0 / 0 |
| **Total** | 120 | 70 / 53 / 0 | 96 / 24 / 0 | 111 / 9 / 0 | **120 / 0 / 0** |

Records: `SCRATCH/item33/viability-G{1,2,3}-r{1,2}.md`, pass 3 `SCRATCH/item33/viability-am8-r3.md` (24 re-rated G1/G2 rows: 15 works, 9 needs rewrite) and `viability-G3-r3.md` (4 works; its W-side gaps 3a/3b closed by AM-8 V15 and AM-9 V15b); fixes `SCRATCH/item33/fixlog-{A,B,C,D}.md`. Pass 3 counts the rows not re-rated at their pass 2 rating. "After AM-9" counts the 9 rows below as closed by the AM-9 edits; no non-author auditor re-rated them (the AM-8/9 fix-verify in §13 read the same files). Script tests run in a temp copy: catalog 157, desk-req 558, scope-check 23, port-check 57, hook 43 pass; `wave-execution` example-spec 17/17 (18/18 after AM-8).

The 17 items that were still not `works` after pass 2 (V1-V16) were decided by the lead in AM-8 (INTERFACES 1.8.0, `am8-queue.md`); V17 (`catalog-audit.sh` `bus` verify) was fixed on the build branch (commit `5b8768d`). The pass 3 "needs rewrite" rows and how AM-9 (INTERFACES 1.9.0) closes each:

| Row | Item | Pass 3 gap | Closed by AM-9 |
|---|---|---|---|
| G1/6 | `delivery-run/references/resume.md` | no carrier for `STOP stale-session`; enum and mapping lack it; the conductor would be a second `substate.md` writer | G1/6: carrier `RUN_HOME/pm/outbox/stop-<utc>.md` (C5.1 outbox); the conductor records `stop_reason: stale-session` in `state.md` `subtasks[]` and maps `pm` to `stopped` (A.2, A.3). Consumers: `delivery-run` `resume.md`, `delivery-pipeline` `SKILL.md`, `tick-relay.md`, `stops-and-posts.md`, `resume.md`, `stages.md`, `templates/state-and-substate.md` |
| G1/14 | `delivery-pipeline/references/stages.md` | `pm` "not relaunched" vs relaunch once after `RESUME.pm` | edit-only set: `stages.md` states the `tick-relay.md` rule (no relaunch until `RESUME.pm.<run-id>.ok`, then once) |
| G1/38 | `delivery-desk/references/checks.md` | CI logs refused in checks/verbs/B7 vs masked in V7 | edit-only: B7 part-b:147 CI logs are masked, not refused; `checks.md` §Redaction and `verbs.md` `ci-logs` mask and store |
| G1/42 | part A (`part-a-state.md`) | A.3 "lead only" and S6 vs the desk clear and the conductor write | G1/42: lead writes for lead-detected stops, conductor for conductor-detected stops (stale-session, ledger refusal, relay refusal), desk clears on `RESUME`; S6 carve-out. Consumers: `delivery-desk` `SKILL.md`, `human-gates.md`, pipeline template |
| G1/43 | part A / C1.1 depth | C1.1:23 and R4-J13 keep the old depth wording | edit-only: C1.1:23 and `INTERFACES.md` R4-J13 use the E50 depth wording |
| G1/56 | `part-03` / A.3 example | `clerk: 1` left in the A.3 `reserved` example | edit-only: part A:203 drops `clerk: 1` |
| G2/7 | `pre-pr-gate` | C3 defined three ways; a non-clean plan-check has no action before step 16 | G2/7: C3 = branch rebased AND plan-check PASS (A.6, part-04 5.7, template); a non-clean plan-check before round 1 never blocks by itself, its findings go to the round-1 fixer first. Consumers: `pre-pr-gate` `SKILL.md`, `steps-detail.md`, checklist template |
| G2/8 | `pre-pr-gate` / `pr-review` | `Reviewed-By` 2-token form vs A.6 3 tokens | edit-only: W' `pr-review` record line 2 is the 3-token form from `SEAT_ID`; V15b adds `RUN_HOME` to the D2.3 in-run inputs (`pre-pr-gate` step 11 producer) |
| G2/53 | template `test-plan.md` | later A3 columns have no writer | G2/53: A.3 `substate.md` fields `e2e_gherkin_utc`, `e2e_spec_path` (the e2e-writer, after H-e2e) and `e2e_run_result`, `e2e_heal_review` (the lane-runner, after `nl-run-e2e`). Consumers: `test-plan.md` template (the columns point at those fields), briefs `e2e-writer.md`, `lane-runner.md` (COMMON block unchanged, BRIEFS-OK), the `substate.md` template |

## 6. Cross-reference resolver

Round 1: W 85 broken (48 wrong line/file/path, 31 stale version pins, 6 AM-6 (a) cites superseded by AM-7), W' 1. Round 2 after the fixers: W 4, W' 0. The 4 are one item: `skills/sim-lease/SKILL.md:25,31,36,39` call `tools/sim-lease.sh`, which exists only in `hq`; the skill now says so and the Move step below copies it. Records: `SCRATCH/item33/resolver-{W,Wp}-r{1,2}.md`.

## 7. Final sweep and checks

- **Fix-verify sweep** (installed `fix-verifier`, non-author, 5 batches: W 142 files changed since `322c13f`, the last commit before the item 33 slices, plus the then-uncommitted edits, since committed; W' 18 files since `7137f88`): `ISSUES_FOUND 8`, 0 Blocking. The four item-21 post-D7 edits (E38), E46-E48 and the W' `DIFF_PATH` fix are present and consistent. Record `SCRATCH/item33/sweep.md`.
- **Fixed after the sweep by the integrator (mechanical; §9 re-run):** 1 `control-channel.md:23` desk-VERDICT wording; 2 part C C5.1 inbox `type` list and writers gain `verdict` (AM-7); 3 `delivery-intake` fixture counts 17 -> 18 sentinels; 6 the verdict agent also reads an unconsumed desk `VERDICT pm` file; 7 `pre-pr-gate/SKILL.md:210` cites 1.7.0; 8 `changelog.md:239` dollar figures removed (B-4). Not re-run through a second fix-verifier pass.
- **Open from the sweep (Low):** 4 W' `feature-change/SKILL.md:131` exit criterion needs a verifier a team unit does not dispatch; 5 `post-merge-verify` stop list has no `verdict-timeout` bullet. The stale "INTERFACES 1.x" labels (sweep advisory) were bumped to 1.9.0 in the PR #13 round-1 fix; amendment citations (`1.6.0 AM-6 (a)`, `1.8.0 AM-8 V7`) and dated check stamps keep their version on purpose.
- **§9 blocks:** all pass: SKILL-14..25 (14, 15, 16 static part only: the dry-run lines need a verifier `FIXTURE_DIR`), 26 DESK-SCHEMAS-OK, 27 (template pack), 27b BRIEFS-OK, 28 SKILL-28-OK + VERBATIM-OK (scope-guard-free copy, item 33 edited briefs/templates on purpose), 29 PIPELINE-29-OK (prints `TEMPLATES-TOUCHED`, expected); W' EXT-09..13 OK (11-13 static part), `wave-execution` tests 17/17.
- **Lengths:** `check-doc-length.sh` 0 blocking in W and W'; `check-file-length.sh` 0 files over its limit in both.
- **Sanitization grep** (the build-common pattern: the owner's home path, the personal-project names, the note tool, and `cost` as a word; both worktrees, excluding `delivery-workflow-sources/` and vendored `security-audit`): after the fixes, 0 violations; remaining hits are rule statements ("no cost metric", "note tool removed"), §9 grep patterns and a source file name. Two `$HOME` substitutions were made in `reviews/28-delivery-run-2b/` panel files.

## 8. Verify at move (unmeasured; `part-05-execution-constraints.md` §6.1, `part-04-templates.md` §5.8b)

- §6.1 unmeasured list in full (`part-05:17`): session type vs sandbox/deny list; `ps`, pm2, docker and registry reachability from a lead session; `api.github.com` reachability; whether the session cap counts nested descendants; the per-session total spawn cap.
- Zephyr: MCP identity, scope model, spec location, read operations and tool names (signed-in `search`, T3, B2), into `zephyr.read_ops`.
- NLTA: plugin install source and prefix; whether NLTA skills run non-interactively (M23); `nl-context-provider.json`.
- CI: system, required-check names as GitHub sees them, merge method, Tier 1 e2e wiring to the merge pipeline E2E stage, `gates.runner_slots`, install and `nx affected` durations (M8).
- Second reviewer: H-pr is an approving review by another human (GitHub forbids self-approval, R2-4).
- CODEOWNERS and branch protection of the pilot repo (unmeasured).
- Sandboxes: which session carries which sandbox or deny list; the launcher `env -i` allowlist (part-05 M28).
- pm2: reachability and socket permissions from lead sessions; `pm2 save --force` after deletes.
- `claude -p`: login state and flags; Jira session path.
- Depth probe (measured limit 3, 3rd level without the Agent tool) and D12 3-seat probe.

## 9. Move step checklist (owner; design §7 "M Move")

1. Copy or clone `agent-hq` into the work environment; install skills by symlink per ADR 0009 (`decisions/0009-skills-authored-in-hq-symlink-installed.md`) into that environment's skills directory; record `<version>@<sha256>` per installed target (`ls -L`, `shasum`) in `state.md` `skill_versions`.
2. Copy `tools/sim-lease.sh` and `tools/test_sim-lease.sh` from `hq` into `agent-hq/tools/` (not ported in W0; the skill names it).
3. Set `CLAUDE_CODE_MAX_CONCURRENT_SUBAGENTS=30` for lead sessions.
4. Desk session credentials: GitHub, Harness, Jira (the desk has no Zephyr access).
5. Install the NLTA plugin; keep the operator's existing Zephyr MCP configuration (nothing installed by this design).
6. Set `DELIVERY_ROOT` (M12).
7. Fill `tools/ports.tsv` and `tools/app-ports.tsv` for the work machine; install the `tools/hooks/port-precheck.sh` PreToolUse(Bash) hook from `config/settings.json` (AM-1, E18).
8. Fill the §5.8b unmeasured row in the pilot repo's `repo-profile.md`.
9. One version bump per skill at the move (E45, AM-6 C-7/B-6); `post-merge-verify` body about 5.7k tokens accepted under its 3,500-word cap, a note for the pilot (B-8).

## 10. After the move (design §7)

| Wave | Content | Exit |
|---|---|---|
| P0 Re-measure | §6.1 facts; `claude --help`; pm2; depth probe; D12 3-seat probe on a real bus; signed-in Zephyr `search`; install and `nx affected` durations, `gates.runner_slots`; NLTA non-interactive; `contracts/`, `.tasks/` with repo owners; `merge_reach`, `pr.approval_rule`; positive control of every gate script and of the port-precheck hook | facts recorded, both ADRs ratified |
| P1a Pilot, build through merge | one small epic, 2 sub-tasks, real desk, CI, Jira; shepherd and `ci-fix-loop` as drafts | both PRs merged after human approving reviews, CLEANUP DONE, one real stall or creep flagged, one real red check closed |
| P1b Pilot, release observation | `release-track` observes DEV2 auto-deploy and one human Zephyr promotion; hook refuses one deliberate non-read call | one promotion tracked end to end |
| P2 Harden | full review of the three pilot drafts, close `pending pilot`, measured durations into the profile, D12 decision, Hermes capture | P1b done |

## 11. Version pins (E45)

- EXTENDs: `wave-execution`, `pr-review`, `fix-verifier`, `doc-reviewer`, `feature-change` at `1.1.0`.
- NEW skills at `0.1.0`, except `delivery-dispatch-plan` `0.2.0`, `resource-catalog` `0.1.1`, `delivery-cleanup` `0.1.1` (V5); `port-claim` `1.1.1`.
- `INTERFACES.md` `1.10.0`; `state.md` `interfaces_version` pins it per run.
- One bump per skill at the move, not before.

## 12. PR plan (both under Rule 10, the hq code gate; `INVARIANTS.md` "Code gate")

1. **`wt/delivery-w0` -> `main` first (PR #13, open).** Item 33 and AM-8/9 edits committed; `main` (`1bd844e`) merged in, so `tools/delivery/` equals main's. `tools/code-gate/test-map.tsv` = main's rows plus 4: `zephyr-guard.sh` and `check-zephyr-disallowed.sh` -> `test_zephyr-guard.sh`; `skills/security-audit/validate-findings.cjs` and `validate-coverage-ledger.cjs` -> `skills/security-audit/tests/test_validate-findings.sh` and `test_validate-coverage-ledger.sh`. Code-gate scope of the diff: the 3 `release-track` scripts, the 2 `security-audit` validators and their 2 wrappers, `test-map.tsv` (the vendored `*.test.cjs` are excluded by `scope.conf`, PR #12, and run through the wrappers). Not in this PR: the four EXTENDs above (step 2). `pr-review` r1 FAIL (0/2/12); after a PASS the desk posts the full-40-char-sha `CODE-GATE-REVIEW PASS` marker and merges `--no-ff`.
2. **`ext/delivery-extends` rebased onto the new `main`, then the follow-up PR** (EXTENDs `wave-execution`, `pr-review`, `fix-verifier`, `doc-reviewer`). Expect a `test-map.tsv` conflict (W' lacks main's rows) and the stale W' INTERFACES 1.1.0 copy, which main's 1.9.0 supersedes; `pr-review` on the diff vs main; `wave-execution` tests 17/17; EXT-09..13 §9; merge by the desk.
3. **Follow-up PRs after both:** `desk-req-schema.sh` contract rows (AM-6 scripts). (`catalog-audit.sh` `bus` verify per A.5.1, V17, merged as PR #11.)

## 13. Final sweep (AM-8/9)

- **AM-9 consumer edits (INTERFACES 1.9.0 AM-9, committed on both branches):** W: `delivery-run` `resume.md`; `delivery-pipeline` `SKILL.md`, `tick-relay.md`, `stops-and-posts.md`, `resume.md`, `stages.md` (also the `READ-BACK: ok <path>` completion line), `provenance.md`, `templates/state-and-substate.md` (`subtasks[].stop_reason`, `e2e_*` fields, S6 carve-out); `delivery-desk` `SKILL.md`, `human-gates.md`, `checks.md` (clear on `RESUME`, CI logs masked); `pre-pr-gate` `SKILL.md`, `steps-detail.md`, checklist template (C3 both conditions, non-clean plan-check to the round-1 fixer, `RUN_HOME` V15b); `delivery-architecture` template `test-plan.md`; briefs `e2e-writer.md`, `lane-runner.md` (COMMON block untouched); `delivery-dispatch-plan` `unit-and-waves.md` (`gates_command` bundle row, AM-8 V14). W': `pr-review` `SKILL.md`, `references/step0-inputs.md` (3-token `Reviewed-By` from `SEAT_ID`, `RUN_HOME` input).
- **Fix-verify** (installed `fix-verifier`, Sonnet, non-author; findings list `am8-queue.md` + `am9-queue.md`; W 45 files changed since `bb76ac7` in 2 batches, W' 11 files since `19c8b9a`): W1 `ISSUES_FOUND 3`, W2 `ISSUES_FOUND 3`, W' `CLEAN`. Fixed once: `gates_command` bundle row; `stops-and-posts.md` conductor-recorded stops and the `RESUME` clear of `state.md`; `provenance.md` O-1 carrier. Re-verify (iteration 2): the four fixed, 1 Low (test-plan heal column values `yes|no` -> `reviewed|none`), applied without a third pass. Records `SCRATCH/item33/final-am9/verify-{W1,W2,WP,r2}.md`.
- **Open, INTERFACES-owned (Low, for the AM-9 author):** part-b:189 says `pr-merge` "check 5" is `repo` (the desk's method check is check 6); part-a:175 A.3 enum list omits `stale-session` (A.8 :375 calls it a new value); E53 writes the 3-token form as `Reviewed-By: <SEAT_ID> head=<sha>` (A.6 and `pr-review` use `<seat-id> <session> <TASK-id>`). W' note: `architecture/wave-execution.md:15,71` ADR 0054 field lists omit `gates_command`.
- **§9 blocks (final run):** SKILL-14, 15, 16 static part rc=0 (dry-run lines need `FIXTURE_DIR`); SKILL-17..25 OK; DESK-SCHEMAS-OK; 27 template pack rc=0 (12 files, `EXEC-COLUMN` note expected); BRIEFS-OK; VERBATIM-OK + SKILL-28-OK; PIPELINE-29-OK (`TEMPLATES-TOUCHED`, expected; pipeline `SKILL.md` 3799 words, cap 3800); W' EXT-09..13 OK (11-13 static); `wave-execution` tests 18/18.
- **Lengths:** `check-doc-length.sh` 0 blocking in W and W'; `check-file-length.sh` 0 files over 300 in both.
- **Sanitization grep** (same pattern and exclusions as §7): W 191 hits, W' 176, the §7 baseline plus one meta hit (this file's §7 rule statement); 0 hits in any AM-8/9 changed line.
