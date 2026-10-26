---
name: release-track
version: 0.1.0
description: Carry a merged change toward production in the pm lead (stages 6-7), after post-merge-verify passes. Use when a PM_SHA has merged and release-plan.md v0 exists, to diff the plan against what merged, mark each release step agent or human, write plan v1, run the agent steps (staging, polling, rollback-criteria checks), prepare the exact command for every human step and wait, send tag-push, publish and test-report-push to the conductor, re-read Zephyr read-only to confirm a human promotion, and write release-<sha>.md ending in LIVE or ROLLED-BACK. Agents never run production, flag flips, money, prod data, external publication or store submission.
---

# release-track

Agents run staging and polling; humans run production; agents prepare the commands and track (D15). The only Zephyr access is a read-only leg through a hook (`references/zephyr-leg.md`, `references/hook-wiring.md`).

## Trigger
Use when: the `pm` lead has `post-merge-verify` passing for `PM_SHA` and the run has a `release-plan.md` v0. Do not use for a sub-task build (that is `delivery-run` mode `build`) or to run a production step.

## Inputs (Step 0)
`RUN_HOME` (path), `PM_SHA` (sha), `PLANS_DIR` (path; holds `release-plan.md` v0), `POSTMERGE_RECORD` (path), `REPO_PROFILE` (`<abs path>@<sha>`; reads `zephyr.read_ops`, `zephyr.execute_tool`, `release_tags.used|pattern|approval`). `DELIVERY_ROOT` is the environment variable.

## Steps
0. Validate inputs (part D1). Print one `INPUT-ERROR <NAME> <reason>` line per failing field (`missing|enum|path|unset|format`), then stop; never ask. Check `POSTMERGE_RECORD` line 1 is a passing token; if not, stop. Read `release-<sha>.md` if it exists: a terminal line 1 (`LIVE`, `ROLLED-BACK`) means done, report and stop; `WAITING-HUMAN` means resume at step 6.
1. Diff `PLANS_DIR/release-plan.md` v0 against what merged: the commits at `PM_SHA`, the sub-task merge shas, `POSTMERGE_RECORD`. List steps the merge made unnecessary, missing, or reordered. Keep every `step_id` of the v0 step table unchanged.
2. Mark each step `agent` or `human`. Human: production deploy, flag flips, money, prod data, external publication, store submission, and a tag push when `release_tags.approval` is `human`. Everything else (staging, consumer simulation, polling) is agent. When unsure, mark `human`.
3. Write `RUN_HOME/release-plan.md` v1 (RUN only, never `plans/<epic>/`): the step table with `step_id`, step, owner, `tag`; the rollback criteria per step (what is polled, threshold, window); the exact command for each human step. Review it at Rung 1 (`doc-reviewer`; D7: stop after round 3, then the owner decides). Do not run any step before the review is clean.
4. Simulation first (G3): before any stable publish or tag, run the published-artifact consumer simulation named in the plan. A release step ahead of its simulation is stop-the-line `G3`. A publish from the main checkout is `G1`.
5. Run agent steps in plan order. Staging health checks bind nothing; if a step starts a local process, claim the port first (INTERFACES A.5.2, `port-check.sh --claim`, see the `port-claim` skill). At every poll evaluate the step's rollback criteria; a criterion met sets the path to step 8 (rollback).
6. Human steps: write the exact command and its `step_id` into `release-plan.md` and the pending record, write `RELEASE: WAITING-HUMAN` as line 1 of `RUN_HOME/release-<sha>.md` (atomic: temp file in the same directory, then `mv`), and stop the step. Never run it. The human grants with `GATE ... H-prod.<step_id> ok`, which the desk writes as `RUN_HOME/gates/H-prod.<step_id>.ok`; the human then runs the command and reports. Never infer a grant; a missing gate file is a wait.
7. Conductor verbs. Write one line per request to `RUN_HOME/pm/outbox/<seq>.conductor-request` (C5.1 layout; the conductor renames `.sending-<id>`, `.sent-<id>` or `.refused`; never edit those):
   - `CONDUCTOR-REQUEST <run-id> pm <seq> tag-push {"repo":..,"tag":..,"sha":..,"step_id":..}` only if the profile `release_tags.used` is `"yes"` and `tag` matches `release_tags.pattern`; with `approval: human` wait for `H-prod.<step_id>.ok` first.
   - `... publish {"repo":..,"package":..,"version":..,"step_id":..}` only after `H-prod.<step_id>.ok` exists and the simulation passed.
   - `... test-report-push {"tool":..,"payload_path":..,"dry_run":true}`: write the payload to `RUN_HOME/bodies/test-report-<step_id>.json` first; send `dry_run: true` first, then the real request after the dry run is `.sent` clean.
   Read the result in the desk reply files; a refusal is data, handle it per the plan (report, never reroute).
8. Zephyr read leg (`references/zephyr-leg.md`): confirm each human promotion by the human's report; read the state with `execute` only when `hook-wiring.md` records a working wiring with a positive control at P0. Until then make no `execute` call at all. Only operations in `zephyr.read_ops`. Never call a promote or rollback workflow. A hook refusal is a harness block: stop with `stop_reason: stop-the-line:S1`, report, do not retry or rephrase. A production write that is not recorded is `S7`.
9. Rollback: if a criterion is met on a step an agent ran, undo the staging step and record it; for a production step prepare the rollback command for the human, write `RELEASE: WAITING-HUMAN`, and after the human reports and a read confirms (or the human's report stands, pre-wiring) finish as `ROLLED-BACK`.
10. Write `RUN_HOME/release-<sha>.md`: line 1 exactly `RELEASE: LIVE` or `RELEASE: ROLLED-BACK` (terminal, regex `^RELEASE: (LIVE|ROLLED-BACK|WAITING-HUMAN)$`), then per step: owner, outcome, evidence path, gate file, request seq. Report to the conductor through the `pm` `substate.md`. `WAITING-HUMAN` is never terminal.

## Red flags
| Rationalization | What to do instead |
|---|---|
| "The change is small, I'll run the production deploy." | Production is human. Prepare the exact command, write `WAITING-HUMAN`. |
| "The profile does not require approval, so no gate." | Only a `none` in `release_tags.approval` skips a tag gate; `publish` always needs `H-prod.<step_id>.ok`. |
| "The hook refused a read-looking call; I'll rephrase it." | A refusal is `S1`. Stop and report. Rephrasing is evading the hook. |
| "I can call promote, the human already said yes." | No agent promotes or rolls back in P1. The human runs it; you re-read to confirm. |
| "No wiring is measured yet, but a read is harmless." | No measured wiring means no `execute` call. Fail closed. |
| "Skip the dry run, the payload is the same." | `test-report-push` goes `dry_run: true` first. |
| "The step id is clumsy, I'll rename it in v1." | Ids are unchanged v0 to v1; gates and requests name them. |
| "Poll later; the criteria passed an hour ago." | Evaluate rollback criteria at every poll. |
| "I will commit plan v1 to `plans/<epic>/`." | RUN only; committing is a human step after CYCLE DONE. |

## Exit criteria
- [ ] `RUN_HOME/release-plan.md` v1 written, `step_id`s unchanged, Rung 1 review clean (or D7 stop recorded).
- [ ] Every human step has its exact command prepared and no production command was run by an agent.
- [ ] Every `publish` and gated `tag-push` request has its `H-prod.<step_id>.ok` and a passed simulation.
- [ ] Rollback criteria were evaluated at every poll; results are in the record.
- [ ] Zero `execute` calls outside `zephyr.read_ops`; every refusal is in `RUN_HOME/pm/zephyr-refusals.log` and stopped the run.
- [ ] `release-<sha>.md` line 1 matches `^RELEASE: (LIVE|ROLLED-BACK|WAITING-HUMAN)$`; `LIVE` or `ROLLED-BACK` before cleanup.

Provenance: pending pilot (release-track P1 pilot run; exit = one promotion observed end to end and the hook refusing one deliberate non-read call, M5)
