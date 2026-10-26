# 25-release-track — Rung 1 loop record

- **Artifact:** `skills/release-track/` (`SKILL.md`, `references/zephyr-leg.md`, `references/hook-wiring.md`). Spec: `architecture/delivery-workflow/tasks/25-release-track.md`. Pilot draft (`Provenance: pending pilot`).
- **Scope:** this loop covers the prose and the allowlist logic in `scripts/zephyr-guard.sh`. The three scripts also go through the code gate (item 32) in a later PR with `pr-review`.
- **Loop:** one orchestrator (D35), and a separate agent for every role and every round, never reused across roles:
  - G48 pre-round screen: Haiku.
  - Review: Sonnet, running the installed `doc-reviewer`.
  - Fix: Opus.
  - Fix-verify: Sonnet, running the installed `fix-verifier`.
- **Round cap:** 3 rounds (D7). The screen ran before round 1 and after each fix, and its findings went to the fixer first.
- **Date:** 2026-10-26.
- **INTERFACES version checked:** 1.3.0 (AM-3). AM-3 does not touch card 13 or these files.
- **Sources:** the spec (RESOLVED Q1-Q6 binding), INTERFACES (`INTERFACES.md` and `interfaces/part-a..d`), part-02 card 13, part-03 and part-04 §5.5, and `delivery-workflow-sources/owner-decisions.md`.
- **Nits:** lint and typo nits were skipped.

## Round 1
- **Screen: 1 Blocking, 5 Medium, 9 Low.**
  - P1-1 was reclassified Medium by the orchestrator. B4 `test-report-push` writes Zephyr Scale test cases, which is a different product from the Zephyr Cloud `execute` reads. The finding was a naming ambiguity, not a scope breach (part-05 §6.3, part-b:98,105).
- **Review: 0 Blocking, 8 Medium, 7 Low. Verdict: READY WITH CONDITIONS.** The Mediums:
  - R1-1: extra `tool_input` keys bypass the allowlist.
  - R1-2: a hook that fails to launch fails open.
  - R1-3: the profile the hook reads is agent-writable, and its `@sha` pin is not honoured.
  - R1-4: the human vs desk `publish` path is unclear.
  - R1-5: the hook can only enforce at session level.
  - R1-6: per-run values never reach the hook.
  - R1-7: the keyword check blocks the "deployment" reads the leg needs.
  - R1-8: plan v1 has no step for the D7 stop.
- **Fix:** every Medium was closed or routed. Guard allowlist logic changed:
  - `tool_input` keys are now a closed set, `operation|method|path|params`, labelled "assumption until P0".
  - Non-scalar values are refused, and so is non-ASCII text.
  - `read_ops` counts only as a direct child of `zephyr:`; a duplicate key is refused as ambiguous.
  - Tests went from 48/0 to 63/0. The 15 new cases were added and none of the 48 existing cases changed.
  - Wiring is now stated in the prose:
    - the command form `|| exit 2`;
    - a broken-path positive control;
    - a 0444 profile snapshot taken at the pinned sha;
    - the guarantee is "`pm` lead session, read ops only".
- **Verify: CLEAN, with 2 Low.**

## Round 2
- **Screen: 0 Blocking, 6 Medium, 9 Low.**
  - P2-1: grant-then-desk `publish` vs D15. Routed to the owner as OQ-3.
  - P2-2: the `ZEPHYR_*` env contract is not in INTERFACES.
  - P2-3: the `pm/outbox/.seq` citation. A false positive; C5.1 defines it at part-c:125. The fixer's decline was accepted.
  - P2-4: the G3 simulation is not defined.
  - P2-5: the D6 loop rules are not carried.
  - P2-6: duplicate of OQ-1.
- **Fix:** the G3 simulation is now defined inside the skill. The env contract is marked as a proposed INTERFACES amendment. D6 is cited.
- **Verify: CLEAN, with 2 Low.**

## Round 3
- **Screen: 0 Blocking, 2 Medium, 7 Low.**
  - P3-1: the G3 gate does not cover every tag.
  - P3-3: the D6 rules are cited but not carried or run.
- **Fix:**
  - Every `publish` and every `tag-push` now needs its simulation row recorded as `pass`. "Stable" was dropped because part-04 §5.5 never defines it.
  - The plan-v1 review now goes through `review-tailor` (`KIND=plan`).
  - The D6 text is quoted verbatim from part-03:94; the verifier checked it character by character.
- **Verify: CLEAN, with 2 Low.**
  - L-1: the skill gates more than spec §4's "stable publish" wording.
  - L-2: the `review-tailor` Trigger does not list `release-track` as a caller.
- **Post-fix screen (G48): 0 Blocking, 3 Medium, 2 Low.**

## Final state: D7 stop after round 3 (owner decides)
**Final counts: 0 Blocking, 3 Medium open, 2 Low.** All three open Mediums are in Step 3 of `SKILL.md`. P4-1 and P4-2 belong to the class that has stayed open since round 2: running the review loop for plan v1. Under D60 that class should get a different mechanism, not more wording.
- **P4-1 (Medium):** Step 3 tells the loop to run the D55 plan-check (Plan-checker, `plan-check.md`), but no input path is given, and no step reads the `PLAN-CHECK:` verdict.
- **P4-2 (Medium):** Step 3 calls `review-tailor` with "the other inputs of its Step 0", but `release-track` defines none of them: `SLUG`, `STAKES`, `CONTENTION`, `NOVELTY`, `SECURITY_AUDIT`, `ORCHESTRATOR_TIER`. The call would stop at `INPUT-ERROR`. That fails closed, but no exit is defined.
- **P4-3 (Medium):** a simulation outcome of `fail` has no route (stop, rollback or `WAITING-HUMAN`), so the run cannot reach a terminal `RELEASE` line. The orchestrator confirmed this by grep.
- **Lows:** P4-4 cites the Plan-checker at part-03 §3.4, but the row is in §3.2 (line 35). P4-5: the quoted D6 text carries the ledger tokens `RLM:85` and `D65`.
- **Recommended resolution (for the owner, not applied):**
  - P4-1 and P4-2: replace the inline loop wiring with one line, "plan v1 is reviewed by the run's standard Rung 1 loop (`review-tailor` with inputs set by the conductor)". Add the input set to INTERFACES A.6 as an integrator amendment.
  - P4-3: a `fail` sets the guarded row to not-run and writes `RELEASE: WAITING-HUMAN` with the failure listed; it never publishes.

## §9 done-condition (final; run by the round-3 verifier and re-run by the orchestrator)
```
bash s9.sh; echo exit=$?
SKILL-25-OK
exit=0
bash -n: ok check-zephyr-disallowed.sh, ok test_zephyr-guard.sh, ok zephyr-guard.sh
test_zephyr-guard.sh | tail -1
63 passed, 0 failed
```
Note: the expected count was 48/0. It is now 63/0 because round 1 added 15 allowlist and fail-closed cases.

## Owner questions (recommended answers; none ruled here)
- **OQ-1 (R1-7/P2-6): keyword check vs deployment reads.**
  - The spec §4 second check refuses any call text containing deploy, promote or rollback. The "deployment history" and "current version deployed" reads will probably be refused.
  - **Recommended:** at P0, narrow the check against the measured op ids: a verb-part check, or a measured denylist of write ops. Keep GET-only and the closed key set.
  - Until it is ruled, the prose fails closed: a colliding read is refused as S1.
- **OQ-2 (R1-5): must R2-1's "release-track alone" be enforced below the session?** The hook can only enforce "`pm` lead session, read ops only".
  - **Recommended:** no, for the P1 pilot.
  - Revisit with a dedicated release session if the DEV2-to-DEMO step is ever ruled in.
- **OQ-3 (P2-1): is grant-then-desk acceptable under D15?** The path is: the human grants `H-prod.<step_id>.ok`, then the desk runs `publish`/`tag-push` (B4/B8). Spec §4 contradicts itself: the Human-steps row vs the Gate row.
  - **Recommended:** A, grant-then-desk, as in the frozen B4. Amend the spec §4 Human-steps row by one line.
  - The alternatives are B, the human runs it by hand, which needs a B4 amendment, and C, a split: tag by desk, publish by hand.
- **D7 stop (P4-1, P4-2, P4-3):** accept the recommended resolution above for a round-4 fix, or rule otherwise.

## Integrator notes
- Add two rows to `tools/code-gate/test-map.tsv`: `skills/release-track/scripts/zephyr-guard.sh` and `skills/release-track/scripts/check-zephyr-disallowed.sh`, both mapped to `test_zephyr-guard.sh`. Do this serially with items 5-7. Not edited by this loop.
- N-1: amend INTERFACES (M21) with the `pm`-lead hook env/arg contract. The variables are `ZEPHYR_PROFILE` (0444 snapshot), `ZEPHYR_TOOL`, `ZEPHYR_REFUSAL_LOG` and `RUN_HOME`, plus the positional fallback. The launcher (item 29) exports them.
- N-2: add `release-track` to the `merge_reach` consumer column (part-a-state.md:119).
- N-5: add an A.6 note for the skill's own simulation row (`simulation for <step_id>`, outcome `pass|fail`).
- Add `release-track` to the callers in the `review-tailor` Trigger (round-3 L-2).
- Spec §4 says the simulation comes before a "stable publish". The skill now gates every `publish` and `tag-push`, which is stricter and fails closed. Confirm or amend the spec wording.
- The guard does not enforce the profile-snapshot rule: it strips `@<40-hex>` and reads any path. That rule rests on the launcher. The code gate should look at it.
- Loop artifacts: `SCRATCH/rt25-loop/` (r1-r4 screens, r1 review, r1-r3 fixlogs and verify files).

## Post-D7 fix (owner-authorized, 2026-10-26; no new review round)
Owner ruling "release-track D7 stop" ("Accept all", `owner-decisions.md`): one fix+verify pass for P4-1..3, and OQ-1..3 recorded.
- **P4-1:** `SKILL.md` Step 3 runs the plan-check loop of `skills/delivery-dispatch-plan/references/plan-check-loop.md` with input `RUN_HOME/release-plan.md` and output `RUN_HOME/pm/plan-check.md` (so the dispatch plan's `RUN_HOME/plan-check.md` is kept), and reads `PLAN-CHECK:` from line 1 of that file.
- **P4-2:** Step 3 calls `review-tailor` with all ten inputs. The six it lacked: `SLUG=run-plan-<n>` (first free `n`), `STAKES`, `CONTENTION`, `NOVELTY` (new skill inputs set by the conductor, a proposed INTERFACES amendment), `SECURITY_AUDIT` and `ORCHESTRATOR_TIER` (from `RUN_HOME/state.md`). An `INPUT-ERROR` from it stops the skill with the same line.
- **P4-3:** Step 4: a simulation `fail` sends no request, records `fail` with evidence, sets the guarded row to `not-run`, writes `RELEASE: WAITING-HUMAN` with the failure listed; the human decides.
- **OQ-1:** `references/zephyr-leg.md` (keyword check narrowed at P0 against measured op ids, refusing until then), `hook-wiring.md` positive control item 4, `SKILL.md` Step 8.
- **OQ-2:** `references/hook-wiring.md` "Guarantee" and `zephyr-leg.md` "Who and how": `pm`-lead session-level enforcement accepted for the P1 pilot.
- **OQ-3:** `SKILL.md` Step 6: grant-then-desk stands (frozen B4); the desk runs `publish`/`tag-push` only after the `H-prod` grant. The spec §4 amendment named in the ruling is not in this pass's write set (integrator).
- **Test map:** `tools/code-gate/test-map.tsv` gained the two rows from "Integrator notes" (LC_ALL=C sorted, unique).
- **Checks:** `s9.sh` printed `SKILL-25-OK`, exit 0; `test_zephyr-guard.sh` ended `63 passed, 0 failed` (scripts unchanged).
- **Fix-verify (Sonnet, installed `fix-verifier`): CLEAN, 0 Blocking, 0 Medium, 4 Low.** D60 data: Step 3 grew 2337 to 2784 bytes, because the ruling requires the input path, verdict read and inputs. Lows, left to the integrator and the pilot: the `pm/plan-check.md` path exists only in this skill; the first Exit criterion does not name the simulation-fail path; `STAKES`/`CONTENTION`/`NOVELTY` are not yet in INTERFACES; `not-run` and the human's resume decision have no defined carrier.
- Working files: `SCRATCH/postd7/` (`orig/`, `rt25.diff`, `testmap.diff`, `verify.md`).
