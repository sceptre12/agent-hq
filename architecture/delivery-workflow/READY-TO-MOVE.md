# READY-TO-MOVE: delivery workflow, item 33 packet

- **Date:** 2026-10-26. **Item:** design §7 item 33 (`part-06-build-plan-and-sources.md:32`). **Integrator:** Worker1.
- **Branches:** `wt/delivery-w0` (docs, W1 skills, briefs, templates; worktree `~/projects/agent-hq-worktrees/delivery-w0`) and `ext/delivery-extends` (items 9-13; worktree `~/projects/agent-hq-worktrees/delivery-extends`, HEAD `3b59a5e` plus the item 33 fix). Scripts and the port guard are already on `main` (`4ee64a0`).
- **Contract:** `INTERFACES.md` version **1.7.0** (frozen 1.0.0, seven amendments AM-1..AM-7, all 2026-10-26).
- **State at writing:** the item 33 edits (AM-7, fixer rounds) are uncommitted in both worktrees; the integrator commits them. Nothing in this packet was pushed.
- **Records:** `SCRATCH/item33/` holds the resolver, viability, fixlog and sweep files named below (`SCRATCH` = the build session's scratchpad; copied nowhere in `agent-hq`).

## 1. What is built

| Area | Content | Where |
|---|---|---|
| Contract | `INTERFACES.md` + parts A (state), B (desk), C (waves and control), D (enums, topics, planes); errata E1-E48 | `architecture/delivery-workflow/` |
| Design | parts 01-06, changelog, measurements, task specs 05-29 | `architecture/delivery-workflow/` |
| ADRs | 0054 (ADR 0023 amendment, `wave-execution` caller-owned bus), 0055 (`DESK` verb, permission-tiers-02) | `decisions/` |
| NEW skills (0.x) | `delivery-pipeline`, `delivery-run`, `delivery-desk`, `delivery-dispatch-plan`, `delivery-architecture`, `delivery-intake`, `review-tailor`, `resource-catalog`, `delivery-cleanup`, `pre-pr-gate`, `post-merge-verify`, `ticket-clerk`, `delivery-shepherd`, `ci-fix-loop`, `release-track` | `skills/` (W) |
| EXTENDs (1.1.0) | `wave-execution`, `pr-review`, `fix-verifier`, `doc-reviewer`, `feature-change` | `skills/` (W') |
| Ports (item 8) | `review-7-panel`, `feature-change`, `port-claim` (1.1.1 after item 18), `sim-lease` (skill only, see §6) | `skills/` |
| Vendored | `security-audit` (unmodified, `PROVENANCE.md`) | `skills/security-audit` |
| Briefs, templates | 32 persona briefs; 12 templates | `skills/delivery-run/references/briefs/`, `skills/*/references/templates/` |
| Scripts (main) | `tools/delivery/catalog.sh`, `catalog-audit.sh`, `desk-req.sh`, `desk-req-schema.sh`, `scope-check.sh` + tests (PR #10); `tools/port-check.sh`, `tools/lib/port-check-lib.sh`, `tools/hooks/port-precheck.sh`, `tools/ports.tsv`, `tools/app-ports.tsv` + tests (PR #9) | `main` |

## 2. Per-item review outcomes and verdicts

The full table (item, commits, rung, rounds, open B/M/L, D7 stop, record) is the build record in `part-06-build-plan-and-sources.md` §7 "Build record (W0-W3, 2026-10-26)"; records are under `architecture/delivery-workflow/reviews/`. Summary:

| Item(s) | Rung | Verdict at end |
|---|---|---|
| 2 INTERFACES | 2b, 4 rounds (owner one-off r4) | FROZEN; r4 24 M fixed, verify 0/0/7 |
| 2b specs, W2 specs | plan-check | PASS, PASS |
| 3 ADR 0054; 3b ADR 0055 | 1 | 0/0/3; 0/1/1 (D7, OP1-OP10 "Accept all") |
| PR #9 port guard; PR #10 scripts | 3 | r3 PASS 0/0/5; r2 PASS 0/0/5 (both merged) |
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

## 5. Viability ratings (non-author auditors, literal dry read against INTERFACES 1.7.0 and the `wave-execution` EXTEND)

| Group | Items | Pass 1 works / needs rewrite / theater | Pass 2 (after fixes) |
|---|---|---|---|
| G1 conductors, desk, dispatch-plan, architecture docs | 56 (53 after regrouping) | 22 / 34 / 0 (1 theater row) | 39 / 14 / 0 |
| G2 other W1 skills, 32 briefs, 12 templates | 55 | 41 / 14 / 0 (1 theater row) | 49 / 6 / 0 |
| G3 EXTENDs, scripts on `main` | 12 | 7 / 5 / 0 | 8 / 4 / 0 |
| **Total** | 120 | 70 / 53 / 0 | **96 / 24 / 0** |

Records: `SCRATCH/item33/viability-G{1,2,3}-r{1,2}.md`; fixes `SCRATCH/item33/fixlog-{A,B,C,D}.md`. Script tests run in a temp copy: catalog 157, desk-req 558, scope-check 23, port-check 57, hook 43 pass; `wave-execution` example-spec 17/17.

**Still not `works` after two passes, for the owner** (each needs a decision INTERFACES does not make; no wording invented):

| # | Item | Conflict |
|---|---|---|
| V1 | `delivery-run`, `delivery-pipeline` | who writes `stale-session` and whether it maps to `stopped` (`delivery-run/references/resume.md` vs `part-a-state.md` A.2 mapping; O-1 is a lead default) |
| V2 | part A, `delivery-desk` | two writers of `stop_reason`: A.3 "lead only" vs A.8/B9 "the desk clears it on `RESUME`" |
| V3 | part A.7 vs C1.1 | depth rule: AM-6 C-5 lets a depth-1 unit dispatch its reviewer; C1.1/E16 put units at depth 2 dispatching nothing |
| V4 | D2.2 row 12 | `post-merge-verify` requires `WORKTREE_BASE`; no amendment names it as an input |
| V5 | E45 vs skills | version pins: `delivery-dispatch-plan` 0.2.0, `resource-catalog` 0.1.1, `delivery-cleanup` 0.1.1 vs "NEW skills stay 0.1.0" |
| V6 | part B4 | requesters with no producer: `jira-get` (`delivery-dispatch-plan`), `pr-comment` (`ci-fix-loop`) |
| V7 | `delivery-desk` | `pr-merge` check 5 code (`schema` vs `repo`); `jira-create` code for a parent missing at re-fetch; B7 log redaction method (mask vs refuse) |
| V8 | part-03, A.4 vs D2.2 row 14, D3 | clerk seat reserved per sub-task vs clerk runs only in the conductor session |
| V9 | `pre-pr-gate` | `gate/plan-check.md` is written but nothing reads it (theater until a reader or removal is ruled) |
| V10 | `post-merge-verify` | verdict agent renames slot rows `.freed`; A.1/C7 say the lead alone frees |
| V11 | briefs `implementer`, `test-writer`, `e2e-writer` | `HUSKY=0` on commits vs A.7 (non-desk commits run hooks; N10 names desk pushes only) |
| V12 | template `test-plan.md` | e2e rows and the batched `.feature` list have no writer after stage 2; the desk H-e2e hash and `post-merge-verify` read them |
| V13 | `wave-execution` | S4a (owner-ruled: a dependent branches only after the Integrator merged its blocker) has no engine step: Integrator items sit in the later barrier wave and rule 15 keeps edges inside a wave |
| V14 | `wave-execution`, A.7 | no producer of the unit-level `gate-runs/<head>.md` (A.7 names two writers; the gate agent lacks `gates.command` and a lease) |
| V15 | `pr-review` Step 0 | in-run call requires `REPO_DIR`, `SEAT_ID`, `MEMBER_SESSION_NAME`, `TASK_ID`; `pre-pr-gate` step 11 passes none and D2.3 names no producer |
| V16 | part D1.1 | `READ-BACK:` is defined in C8 but has no D1.1 token row (pipeline `SKILL.md`, `resume.md`, `stages.md` read it) |
| V17 | `catalog-audit.sh` (main) | `bus` verify reads the sub-task `bus.endpoint` for every row, so a live review bus reads `GHOST`; A.5.1 now says "beside the row's handle": a follow-up PR |

## 6. Cross-reference resolver

Round 1: W 85 broken (48 wrong line/file/path, 31 stale version pins, 6 AM-6 (a) cites superseded by AM-7), W' 1. Round 2 after the fixers: W 4, W' 0. The 4 are one item: `skills/sim-lease/SKILL.md:25,31,36,39` call `tools/sim-lease.sh`, which exists only in `hq`; the skill now says so and the Move step below copies it. Records: `SCRATCH/item33/resolver-{W,Wp}-r{1,2}.md`.

## 7. Final sweep and checks

- **Fix-verify sweep** (installed `fix-verifier`, non-author, 5 batches: W 142 files changed since `322c13f`, the last commit before the item 33 slices, plus uncommitted; W' 18 files since `7137f88`): `ISSUES_FOUND 8`, 0 Blocking. The four item-21 post-D7 edits (E38), E46-E48 and the W' `DIFF_PATH` fix are present and consistent. Record `SCRATCH/item33/sweep.md`.
- **Fixed after the sweep by the integrator (mechanical; §9 re-run):** 1 `control-channel.md:23` desk-VERDICT wording; 2 part C C5.1 inbox `type` list and writers gain `verdict` (AM-7); 3 `delivery-intake` fixture counts 17 -> 18 sentinels; 6 the verdict agent also reads an unconsumed desk `VERDICT pm` file; 7 `pre-pr-gate/SKILL.md:210` cites 1.7.0; 8 `changelog.md:239` dollar figures removed (B-4). Not re-run through a second fix-verifier pass.
- **Open from the sweep (Low):** 4 W' `feature-change/SKILL.md:131` exit criterion needs a verifier a team unit does not dispatch; 5 `post-merge-verify` stop list has no `verdict-timeout` bullet. About 20 stale "INTERFACES 1.5.0" labels remain as advisories (listed in the sweep record).
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
- `INTERFACES.md` `1.7.0`; `state.md` `interfaces_version` pins it per run.
- One bump per skill at the move, not before.

## 12. PR plan (both under Rule 10, the hq code gate; `INVARIANTS.md` "Code gate")

1. **`wt/delivery-w0` -> `main` first.** Commit the item 33 edits on `wt/delivery-w0`; rebase or merge `main` (`4ee64a0`) so `tools/delivery/` equals main's (item 32) and `tools/code-gate/test-map.tsv` keeps main's seven rows; `pr-review` on the diff (docs, skills; code-gate scope = release-track scripts + tests); desk posts the full-40-char-sha `CODE-GATE-REVIEW PASS` marker and merges `--no-ff`.
2. **`ext/delivery-extends` rebased onto the new `main`, then PR.** Expect a `test-map.tsv` conflict (W' lacks main's seven rows) and the stale W' INTERFACES 1.1.0 copy, which main's 1.7.0 supersedes; `pr-review` on the diff vs main; `wave-execution` tests 17/17; EXT-09..13 §9; merge by the desk.
3. **Follow-up PRs after both:** `desk-req-schema.sh` contract rows (AM-6 scripts); `catalog-audit.sh` `bus` verify per A.5.1 (V17).
