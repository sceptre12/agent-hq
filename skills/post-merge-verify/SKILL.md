---
name: post-merge-verify
version: 0.1.0
description: Run the post-merge rows of test-plan.md against a detached worktree of main at the merge sha, record one evidence line per row, and end with one POSTMERGE token plus new-units.md on failure. Use when a sub-task has merged to main and the pm lead must verify main (stage 6, delivery-run mode post-merge), or when asked to run the testing plan against main and record evidence per row.
---

# post-merge-verify

## Trigger
Use when: the `pm` lead (inside `delivery-run` mode `post-merge`, no seed, no waves, no bus) holds `PM_SHA`, the `merge_sha` of the last sub-task merge, and must prove main against `test-plan.md`. Output feeds the conductor (`PASS` maps to Verified; `FAIL` re-enters `delivery-dispatch-plan` with `NEW_UNITS`) and `release-track` (reads the record as `POSTMERGE_RECORD`).

## Inputs and Step 0
Inputs (`NAME=value` in the arguments): `RUN_HOME` (path; its last segment is `<run-id>`), `PM_SHA` (40-hex sha), `PLANS_DIR` (path; holds `test-plan.md`). `DELIVERY_ROOT` is the environment variable only. The repo path is `primary_repo` read from `RUN_HOME/state.md`; `WORKTREE_BASE` (profile `worktree_base`) arrives inline in the lead's call. Read the repo profile pinned in `state.md` for `merge_pipeline.stages[]` and the lane resource profile.

Step 0, before anything else: validate each input. Print one line per failing field, then stop (no retry, no prompt):
`INPUT-ERROR <field> <reason>` with reason in `missing|enum|path|unset|format`. Examples: `INPUT-ERROR DELIVERY_ROOT unset`, `INPUT-ERROR PM_SHA format`, `INPUT-ERROR PLANS_DIR path` (also when `test-plan.md` is absent or has no post-merge section). A row id outside `[A-Za-z0-9.-]+` is `INPUT-ERROR PLANS_DIR format`: report it, never rename the row.
Export `RUN_HOME` for `catalog.sh`.

## Steps
1. **Read the plan.** Read `PLANS_DIR/test-plan.md` post-merge section. Per row take: id, what it proves, command, lane, expected, evidence owner, cold-run, order or seed, `gating` or `informational`, failure policy. Also take hand-test rows, consumer-simulation rows, the test-management reporting row, and the explicitly-not-tested list. Quote each row's failure-policy text verbatim and apply it literally; an empty or unclear policy means no retry and the row fails.
2. **Worktree.** Detached worktree of main at `PM_SHA`: handle `<WORKTREE_BASE>/<run-id>-pm`. Run `catalog.sh register worktree '<abs-path>#<repo-abs-path>@main' - run post-merge-verify pm <agent_id>`, then `git -C <repo> worktree add --detach <abs-path> <PM_SHA>`, then `catalog.sh start worktree <handle>`. Verify `git -C <abs-path> rev-parse HEAD` equals `PM_SHA`. Activate node with the profile `node.prefix_cmd` inside this worktree; install with the profile frozen-lockfile command only. A stale or dirty worktree is not reused: a fresh path or stop.
3. **Ports before bind.** For every port a row binds (lane servers, dev servers): claim through the `port-claim` skill (`tools/port-check.sh --claim <port> <bind> <container_port> <service> <run-id> claimed <run-id>-pm <note>`, exit 0), then `catalog.sh register port <port> ...`, launch, `catalog.sh start port <port>`. Exit 1 or 2 refuses the launch; never auto-pick another port. The affected rows fail with reason `lane-unavailable` (C2). Exit 3 (registry unusable) is stop-the-line. Release is `delivery-cleanup`'s, not yours.
4. **Lane leases.** For each distinct lane name in the plan: `catalog.sh register lane-lease lane/<name> - run post-merge-verify pm <agent_id>` (writes `live`; exit 3 means held, so the rows of that lane wait or fail `lane-unavailable`, never steal). Rows sharing a lane run serially in the plan's order or seed; rows on different lanes run in parallel (execute-tier runners). Release the lease with `catalog.sh release lane-lease lane/<name>` when the lane's last row ends.
5. **Run rows, cold.** Each runner executes the row's command in the worktree with no cache: clear or bypass test and build caches named in the profile, and treat a cache-satisfied result as not run. Capture exit code and the output tail to `RUN_HOME/pm/evidence/<row-id>.log` (path in the record). Compare to the row's expected value. Details: `references/row-execution.md`.
6. **E2E rows.** Run through `nl-run-e2e` in the worktree. Review every auto-healed diff before accepting it; never accept blind. Class `SOURCE_BUG` always escalates to the human and stops the row; `ENV_BUG` fails the row with reason `env-bug`. Details: `references/e2e-rows.md`.
7. **Consumer simulation.** After one serial pack (the profile `pack` command, run once, in the worktree), run each consumer-simulation row against that one artifact. Details: `references/consumer-sim.md`.
8. **Hand-test rows.** List each as `human` in the record. An agent never executes a hand-test row (D17).
9. **Merge pipeline.** Write a desk request with `desk-req.sh <run-id> pm ci-status-main <fields-json-file>`, fields `{repo, merge_sha}` with `merge_sha` = `PM_SHA` (never a PR head). Read `stages[] {name, state}` for the profile `merge_pipeline.stages[]`, including the E2E stage and the deployment check. Record each stage as an evidence line; a stage the plan lists as a gating row follows that row's class.
10. **Verdict (verify tier).** A separate verify-tier agent reads the evidence lines, not the runners' summaries, and decides. PASS only if every `gating` row passed. `informational` failures are recorded and never change the token. No weighted score.
11. **Write the record.** `RUN_HOME/postmerge-<PM_SHA>.md`: line 1 `POSTMERGE: PASS` or `POSTMERGE: FAIL <id>,<id>` (failed gating row ids; regex `^POSTMERGE: (PASS|FAIL)( [A-Za-z0-9.,-]+)?$`), then the body per `references/record-format.md`: one evidence line per row id, gating and informational both, hand-test rows as `human`, plus the explicitly-not-tested list copied from the plan. Test-management reporting is not this skill's step; `release-track` writes the `test-report-push` payload and requests the verb.
12. **New units on FAIL.** Write `RUN_HOME/pm/new-units.md`, one line per failed gating row: `<row-id> <one line>` (regex `^[A-Za-z0-9.-]+ .+$`). Set `substate.md` `pm_sha` and `postmerge_record` (abs path). Do not edit code, open a PR, or retry a gating row beyond its failure-policy text.
13. **Release.** Release the lane-leases you took. Leave worktree and port rows for `delivery-cleanup`. Run `catalog.sh list --live --subtask pm` and report any row you still hold.

Stop conditions (stop, write nothing past the stop, report to the `pm` lead with the reason): a product decision is needed to judge a row; a destructive test without a recorded grant; `SOURCE_BUG`; stop-the-line on port registry exit 3.

## Red flags
| Rationalization | Do instead |
|---|---|
| "The cache is warm, a cached pass is the same" | Cold run only; a cache-satisfied result is not run. |
| "The heal diff looks fine, accept it" | Review the diff; never accept blind. `SOURCE_BUG` goes to the human. |
| "The flaky gating row passed on rerun, call it PASS" | Retry only as the row's failure-policy text says; otherwise it failed. |
| "The informational row failed, so FAIL" | Informational failures are recorded, never fail the token. |
| "That port is taken, use the next one" | Refuse the launch; `lane-unavailable`; never auto-pick. |
| "Hand-test row is quick, run it" | It is the human's (D17); list it as `human`. |
| "A failing row is a small fix, patch main" | A FAIL never edits code or opens a PR; write `new-units.md`. |
| "Report results to the test tool now" | `release-track` owns the report; record the evidence line only. |
| "Use the PR head sha for the pipeline" | `ci-status-main` takes `merge_sha` = `PM_SHA`. |
| "The runner says it passed" | The verify-tier agent decides from the evidence lines. |

## Exit criteria
- [ ] Step 0 passed or printed one `INPUT-ERROR` line per failing field and stopped.
- [ ] Worktree HEAD equals `PM_SHA`; catalog rows for worktree, ports and lane-leases exist and no `planned` row of yours remains.
- [ ] Every port bind had an exit-0 claim first.
- [ ] `postmerge-<PM_SHA>.md` line 1 matches the token regex; one evidence line per post-merge row id; hand-test rows are `human`.
- [ ] Verdict is PASS only if every gating row passed.
- [ ] On FAIL, `pm/new-units.md` has one `<row-id> <one line>` per failed gating row, each id in the plan.
- [ ] `ci-status-main` was requested with `merge_sha` = `PM_SHA`.
- [ ] No code edited, no PR opened, no promotion or deploy, no destructive test without a grant.
- [ ] Lane-leases released; `substate.md` `pm_sha` and `postmerge_record` set.

## Provenance
Pending pilot (<pilot-run-id>). Design part-02 card 12, part-03 §3.6 steps 6 and 8, part-04 §5.4; INTERFACES part-a A.5, A.5.2, part-d D1.1, D2.2 row 12. Friction: NLTA guides (auto-heal review, `SOURCE_BUG`), enforcement-gates:141 (cold runs). References: `references/row-execution.md`, `references/e2e-rows.md`, `references/consumer-sim.md`, `references/record-format.md`. Successor skill: `release-track`.
