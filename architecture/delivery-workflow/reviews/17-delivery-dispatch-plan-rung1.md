# Rung 1 loop record: item 17 `delivery-dispatch-plan`

- Date: 2026-10-26. Orchestrator: one loop orchestrator for this artifact (D35). Item: `skills/delivery-dispatch-plan/` (`SKILL.md` + `references/{unit-and-waves,shared-files-and-parallelism,predispatch-checklist,plan-check-loop}.md`); `references/templates/` excluded (item 27). Spec: `tasks/17-delivery-dispatch-plan.md`.
- INTERFACES checked: 1.3.0 (AM-3 applied; the loop brief named 1.2.0). Dispatch asked for three specific checks: lane-port `k`, `constitution.md`/`bundle.md` naming, the one +10 retry. All three are recorded under "1.3.0 checks".
- Roles, one agent each, none reused: G48 pre-round (Haiku) x4 (before round 1, after each fix); reviewer (Sonnet, installed `doc-reviewer`); fixer (Opus) x3, a fresh agent each round and never the author; fix-verifier (Sonnet, installed `fix-verifier`) x3. The round-3 verifier also did the non-author §9 dry run.
- Rounds: 3, the owner D7 cap. **Stopped at round 3 with open Mediums**, listed below for the owner. Final: Blocking 0, Medium 4 open, Low 10 open.

## 1.3.0 checks

- **Lane-port `k`.**
  - A.5.2 and RESOLVED 4 say "lanes by lane index". For a multi-port lane, that reading gives every bind the same candidate.
  - The item now reads it as follows:
    - Lane rows are written once per lane for the run, because leases are run-wide.
    - Each bind takes the next consecutive `k` from 0, so `k` equals the lane index when a lane has one bind.
    - Fixed app-config ports are written as the candidate with `k = 0`. They take no index and sit outside the formula, but they are inside the distinctness check.
    - `bus` (`k = 2N`) and `review-bus` (`k = 2N + 1`) rows are per build-mode sub-task. `st0` gets `review-bus` only, and `pm` gets none (A.2 modes, D2.3 `BUS_PORT`).
  - Wording question: OQ-17-1.
- **`constitution.md` / `bundle.md`.** Both sit at the bundle root next to `waves/`. `constitution.md` is not a wave file, is never named `00-`, and the lead runs it before `01-build.md`, only when the repo has "no profile yet" (C1, AM-3 errata (c)/(d), E26). The item is consistent on this. How "no profile yet" is detected is OQ-17-4.
- **One +10 retry.** Stated the same way in SKILL step 8, the Red flags, sfp §3 and checklist row 8 (A.5.2, C1.1, C2, owner OQ-2):
  - exactly one retry at candidate + 10, claimed before bind;
  - a bus is pinned to the retry port;
  - a second refusal stops the line, and a lane maps to `lane-unavailable`;
  - exit 3 stops the line with no retry;
  - checklist row 8's "never re-pick" applies to plan-time clashes only.

## Round 1 (G48 screen + doc-review, merged; fix: Opus; verify: CLEAN)

| Id | Sev | Finding | Status |
|---|---|---|---|
| M1 | Medium | Lane `k` described as both "bind index" and "lane index"; rows written per sub-task contradicted "one candidate across sub-tasks" | Fixed (see 1.3.0 checks) |
| M2 | Medium | `k = 0` meant both "fixed app port" and "lane 0" | Fixed: fixed rows are outside the formula but included in distinctness |
| M3 | Medium | Bus rows given to `st0`/`pm`, which have no bus (A.2:89) | Fixed: build-mode only; `st0` gets `review-bus` |
| M4 | Medium | Seed and `waves/` required "per sub-task", but A.2 says `st0`/`pm` have no seed and no waves | Fixed across all files and the exit criteria |
| M5 | Medium | Peak cap given as 27, but A.3 seed `reserved` sums to 13, so 30 - 13 = 17 | Fixed |
| M6 | Medium | `port-check.sh` exit 3 (no retry) omitted | Fixed |
| M7 | Medium | `review-tailor` call missing `RUN_HOME`, `ARTIFACTS`, `ORCHESTRATOR_TIER` (D2.2 row 4) | Fixed |
| M8 | Medium | G48 ran only before round 1; part-03:94 says "and after every fix" | Fixed |
| M9 | Medium | Description promised re-planning after `INVALIDATE`, which C6 does not route here | Fixed: claim removed |
| M10 | Medium | "Escalates the fixer one tier", but the fixer is already design tier | Fixed (re-scoped in round 2 R2-M5) |
| L1-L4 | Low | "never re-pick" scope; bare "D7"; overloaded `cap`; constitution condition | Fixed |

## Round 2 (findings from the post-fix G48 screen; fix: Opus; verify: CLEAN)

| Id | Sev | Finding | Status |
|---|---|---|---|
| R2-M1 | Medium | Step 13 re-entry omitted `bundle.md`, the bus/review-bus rows and the sub-task row | Fixed: "every step-10 output for `st<N>` only" |
| R2-M2 | Medium | Absent profile keys: three rules disagreed | Fixed per A.2.2: a missing key is `INPUT-ERROR`; `ports.*` gets `FILL_IN_BEFORE_DISPATCH` (A.2.2:111); `durations.*` is required |
| R2-M3 | Medium | No G48 after a review fix | Fixed |
| R2-M4 | Medium | Machine line left out the reserved seats | Fixed: peak + `sum(reserved)` per concurrent build, against 200 |
| R2-M5 | Medium | Round 1 dropped the E25 escalation half | Fixed: cites D2.1 `tier` row and E25, paraphrases neither |
| R2-M6 | Medium | `ARTIFACTS`/`STAKES`/`CONTENTION`/`NOVELTY` had no values | Fixed: `ARTIFACTS` listed; the other three are "caller's values per D2.1" (OQ-17-7) |
| R2-L1-L3 | Low | Rung wording; split "sub-task" vs "bundle"; invented `fix_loop_cap` profile clause | Fixed |

## Round 3 (findings from the post-fix G48 screen; fix: Opus; verify: ISSUES_FOUND)

| Id | Sev | Finding | Status |
|---|---|---|---|
| R3-M1 | Medium | G48 re-ran only for fixes to `waves/` or the unit table | Partly fixed. **Open:** the text now says "on the fixed files" (SKILL.md:29, plan-check-loop.md:16, :28); part-03:94 says the check covers "the artifact". One-line fix: "on the plan files" |
| R3-M2 | Medium | Step 13 skipped steps 6, 7, 9; fix-loop scope undefined | Fixed |
| R3-M3 | Medium | A sentinel the skill cannot fill (an absent `ports.*` key) had no stop | Fixed: stop with the key named, back to intake |
| R3-L1-L3 | Low | Review-round checker wording; checklist row 11 "item 27b" escape and build labels; `st0` "no bus" | Fixed |

## Open after round 3 (owner D7: the owner decides)

**Medium (4):**
- **R3-M1 G48 scope.** Change "on the fixed files" to "on the plan files" in SKILL.md:29 and plan-check-loop.md:16 and :28. Recommended: apply as written; it is a mechanical fix.
- **F-M2 Review-round checker returning findings** (plan-check-loop.md:28). No rule says who fixes it or how it ends. Recommended: "the review fixer fixes in the next review round; the review loop's owner D7 cap governs".
- **F-M3 Step 13 omits step 8** (SKILL.md:30). New units' lanes get no lane-table or lane-port rows. Recommended: add step 8 to the step-13 list, with new lane rows appended to the run-wide lane table.
- **F-M4 Step 11 vs checklist row 8** (SKILL.md:28 vs predispatch-checklist.md:16). "Fix every failure" can read as re-picking a clashing port; row 8 says stop. Recommended: in step 11, "a port-candidate clash (row 8) stops and reports, like an unfillable sentinel".

**Low (10, no action proposed):**
- G48 fixes re-triggering G48 with no stated cap.
- Row 11 depends on the item-27b `plan-checker` brief existing at run time.
- Checklist row 1's `.tasks` path is relative to the working directory.
- The G48 agent has no `persona` token.
- The round count across re-entries is unstated.
- The bundle-split mechanics (a second `session_id`, seed and budget) are undefined.
- Step 0 reads profile keys that no step uses.
- Step 0 does not validate `state.md` `security_audit`/`orchestrator_tier`.
- "10 units" does not say per run or per sub-task.
- A build label ("item 9") remains at unit-and-waves.md:3.

## Owner / INTERFACES questions (recommended answers)

- **OQ-17-1** A.5.2 "lanes by lane index": word it "per-bind index across the run-wide lane rows, from 0; fixed app ports outside the formula". Recommended: yes, as the item already reads it.
- **OQ-17-2** The +10 retry lands on a sibling's candidate because candidates step by 10. Cases: bus `2N` retries onto review-bus `2N+1`; review-bus onto the next sub-task's bus; lane `k` onto lane `k+1`. The claim registry prevents a double bind, but refusals can cascade into false stop-the-lines. Options: (A) candidates step by 20 (`<base> + 20·k`), leaving each retry slot free; (B) reserve the odd slots as retries; (C) accept the cascade. Recommended: (A). This changes the owner-ruled formula, so it is the owner's call.
- **OQ-17-3** E25 / ADR 0014 T1 escalate "one tier up", but the fixer is already `design`, the top tier. Recommended: read it as a model step inside the design tier (`tools/model-routing.md`); `tier` stays `design`; never a third top-model attempt.
- **OQ-17-4** C1 "no profile yet": Step 0 requires `REPO_PROFILE`, and no marker for "no profile yet" is defined. Recommended: intake writes a profile key (for example `profile_state: new`) and C1 cites it.
- **OQ-17-5** A.2's post-merge re-entry list is a subset of the stage-3 outputs. Recommended: "every stage-3 output for `st<N>`", with no list.
- **OQ-17-6** `e2e.harness` is a part-D enum, not an A.2.2 key. Recommended: add it to A.2.2 so that a missing value is `INPUT-ERROR`.
- **OQ-17-7** No source says how this skill picks `STAKES`/`CONTENTION`/`NOVELTY`. Recommended: pick them by the `tools/review-ladder.md` §2 axes and record the reason in the plan.
- **INTERFACES erratum (no decision needed):**
  - A.6 (part-a:292) and D6 do not list `bundle.md` or `constitution.md`.
  - `wave-execution/references/spec-format.md` lacks the `bundle.md` cross-reference that C1 says it has (item 9).

## §9 done condition (final; non-author dry run by the round-3 verifier, re-run by the orchestrator)

`s9-17.sh` is identical to the spec §9 block (diff exit 0). Output: `SKILL-17-OK`, exit 0. `check-doc-length.sh`: 0 blocking. The diff covers 5 files, +52/-50. `references/templates/` was not touched.
