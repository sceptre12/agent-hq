# Item 21 `post-merge-verify` — Rung 1 loop record

- **Artifact:** `skills/post-merge-verify/SKILL.md` plus `references/` (`row-execution.md`, `e2e-rows.md`, `consumer-sim.md`, `record-format.md`, and the new `ports-and-servers.md` and `merge-pipeline.md`).
- **Spec:** `architecture/delivery-workflow/tasks/21-post-merge-verify.md`. INTERFACES is 1.2.0, and the A.5.2 text already carries the AM-3 +10 retry from owner OQ-2.
- **Loop:** one orchestrator (D35), with a separate agent for every role and none reused:
  - G48 pre-round screen: Haiku.
  - Review: Sonnet, running the installed `doc-reviewer`.
  - Fix: Opus, a new agent each round.
  - Fix-verify: Sonnet, running the installed `fix-verifier`, a new agent each round.
- **Round cap:** 3 (D7).
- **Date:** 2026-10-26.
- **Treated as legitimate (dispatch note):**
  - The skill reads `state.md` `primary_repo` (A.2 readers).
  - `WORKTREE_BASE` arrives inline (AM-2).
  - No failure token is written on a stop condition. This is a spec gap: it is reported here and not fixed.
- **Lint and typo nits:** skipped.

## Round 1
- **G48 screen:** B1 M10 L5.
- **doc-reviewer:** B1 M8 L7. Verdict: NOT READY.
- **Blocking findings:**
  - `catalog.sh` needs `WORKTREE_BASE` exported.
  - A port refusal lacked the OQ-2 rule: one retry at candidate+10, then stop the line.
- **Medium findings:**
  - The candidate-port source was missing.
  - Launched servers were not catalogued.
  - `substate.md` `postmerge` was never set.
  - `SOURCE_BUG` was handled at row scope in one place and run scope in another.
  - The `ci-status-main` send, poll and `REJECTED` handling were missing.
  - A pipeline stage with no plan row was unhandled.
  - Step 0 did not check the profile keys.
  - A desk `INSTALL` verb was used.
  - The destructive-test grant carrier was undefined.
  - The hand-test verdict effect was unstated, and D17 was mis-cited.
  - Verdict evidence was not staged before the verdict.
  - A held lease was "wait or fail" in one place.
  - Provenance was incomplete.
- **Fix:** every Blocking and Medium finding was fixed, along with every Low. Two new references were added. Owner questions OQ-A to OQ-E are listed below.
- **Fix-verify:** ISSUES_FOUND, B0 M1 L6. The heal-diff review had no single writer.

## Round 2
- **Findings from the r1 verify and the post-fix screen:** M6 open in total.
  1. The heal-review writer.
  2. A held lease was mapped to `lane-unavailable`, a reason C2 does not define for that case.
  3. Worktree-row release, where the spec and INTERFACES differ.
  4. `cache-served` was undefined.
  5. The pending-stage re-request had no bound.
  6. Stage evidence had no staged path.
- **Fix:** all fixed.
  - The seat-owned `.heal-review` file was added.
  - A held lease is now stop-and-report.
  - INTERFACES A.5.1/A.5.2/C5.1 was followed: cleanup releases worktree and port rows.
  - `.stages` was added, with the lead as its only writer.
  - The wait is bounded by `durations.ci_round_min`.
- **Fix-verify:** ISSUES_FOUND, B0 M1 L4. The fixer had extended the B6 rule "`skipped` counts as `success`" beyond `required_checks[]`.
- **G48 screen:** B2 M5 L6.
  - No selector picked out hand-test rows.
  - A lane-less row could bind a port without a claim.
  - `.line` had two writers.
  - E2E rows had no selector.
  - The B6 reading overreached.
  - The B1 no-reply escalation was missing.
  - There was no `catalog.sh fail` path.

## Round 3 (final, D7)
- **Fix:** both Blocking and all 5 Medium findings fixed, plus all Lows.
  - Rows with evidence owner `human` go to Step 8 only.
  - A lane-less port bind is now a stop.
  - Each evidence file has a single writer.
  - An e2e row is selected by a §A3 `.feature` path.
  - `skipped`, `pending` and absent stages are stop-and-report.
  - The B1 `ESCALATE human-step` path was added.
  - `catalog.sh fail` runs on a failed add or launch.
- **Fix-verify:** ISSUES_FOUND, B0 M2 L2. No round 1 or 2 fix regressed.
- **G48 screen:** B0 M7 L6.

## Open after round 3 (for the owner, D7). Final count, deduplicated: B0 M8 L7
Medium:
1. **No `.line` writer for consumer-simulation rows.** These §C rows are outside Step 1's three sets, and the exit criterion names no writer for them. (verify and screen)
2. **Stop list incomplete.** The SKILL.md stop list leaves out stops that the references declare:
   - `desk-req.sh` exit 2 or 4;
   - `register.consumed` absent or refused;
   - a curable `REJECTED`;
   - a tmpdir that cannot be created;
   - a missing lockfile dependency;
   - a `FILL_IN_BEFORE_DISPATCH` port candidate. (verify)
3. **Test-adequacy seat never dispatched.** No step dispatches the seat, and `e2e-rows.md` gives it "its own slot row", against A.4: review seats are counted under A.3 `reserved`. (screen)
4. **No return carrier for the verdict.** Step 10's verdict-agent decision has no named carrier, and `pm` has no bus (A.2). (screen)
5. **Slot rows incomplete.** The A.4 slot rows lack `persona`, `tier` and `budget`, and no step renames a row `.freed`. (screen)
6. **Profile keys outside INTERFACES.** `commands.install`, `commands.pack` and `repo.consumer_repos[]` are defined only in design §5.8 and the intake template. The A.2.2 Readers column does not list this skill. This needs an integrator amendment (D7). (screen)
7. **Runner tier conflict.** Spec 21 says "execute runners", but design part-03 says the E2E lane runner is `mechanical`, "never debugs". This is a spec-versus-design conflict. (screen)
8. **Possible second verdict vocabulary.** The heal-review uses `accept|reject` per diff, and spec §3 forbids a second verdict vocabulary. Recommended reading: it is a per-diff review decision, not a row verdict, so it is allowed. The owner should confirm. (screen)

Low:
- `log=` has no form for stage-covered or hand-test rows.
- Step 4.4 never runs `catalog.sh start pm2-app`.
- The `k` lane-index formula and the dispatch-plan consecutive-index rule give different candidates.
- Whether Step 6 replaces Step 5 for e2e rows is unstated.
- "Report to the `pm` lead" points at the skill's own host.
- The 5k-token body budget is unmeasured; the body is 2794 words.
- A.2.2 readers.

## Owner questions (each with a recommended answer)
- **OQ-A:** a failed merge-pipeline stage that no plan row covers. **Recommended:** require one post-merge row per `merge_pipeline.stages[]` entry.
- **OQ-B:** where a destructive-test grant is recorded. **Recommended:** a desk-written gate file `RUN_HOME/gates/H-destructive.<row-id>.ok`, in the form of `H-prod`.
- **OQ-C:** gating hand-test rows. **Recommended:** hand-test rows may only be `informational`, and `delivery-architecture` refuses a gating one.
- **OQ-D:** consumer-simulation rows have no class column. **Recommended:** add `class (gating|informational)` to the test-plan template (item 27).
- **OQ-E:** `REPO_PROFILE` is taken inline but is not in D2.2 row 12. **Recommended:** add it to row 12 through an amendment.
- **OQ-F:** a lane lease is held at post-merge. **Recommended:** stop and report; do not invent a reason word.
- **OQ-G:** a pending stage's wait bound. **Recommended:** one `durations.ci_round_min` round, then stop and report.
- **OQ-H:** a `skipped` merge-pipeline stage. **Recommended:** it is not `success`.
- **OQ-I:** the escalation `<unit>` for a desk request. **Recommended:** the desk `<id>`, which the skill already uses as its own `DEFAULT`.
- **OQ-J:** a stop condition emits no `POSTMERGE` or failure token. This is a spec gap, reported only, with no recommendation.

## Spec gaps (author / integrator)
- Spec §4 and §8 say the skill releases the worktree and other catalog rows "at the end". INTERFACES A.5.1, A.5.2 and C5.1 leave release to cleanup, and the skill follows INTERFACES.
- The test-plan §B table has no e2e marker and no rule for lane-less port binds (item 27).
- Spec 21 §4 and §8 lack the failure token on stop (OQ-J).
- The runner tier (open Medium 7).
- `tools/port-check.sh` is absent from this worktree. It lands with PR #9, so the integrator should confirm the order.

## §9 done-condition
The non-author verifier ran it in round 3: exit 0, last line `SKILL-21-OK`. The orchestrator re-ran it after round 3:
```
SKILL-21-OK
exit=0
```
The done-condition's second half, "the review trio returns CLEAN", is **not met**. 8 Medium findings remain open for the owner (D7).
