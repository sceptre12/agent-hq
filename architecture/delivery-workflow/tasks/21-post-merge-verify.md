# Task Spec 21: `post-merge-verify` (NEW skill, stage 6)

Spec of record for W1 item 21 (design part-06 §7 row "14-22"; card 12 in part-02 §2.2 item 12). Authority: `INTERFACES.md` 1.1.0 (FROZEN; amendment AM-1: port guard). Anchors are `interfaces/part-X` sections.

## 1. Objective
Author `skills/post-merge-verify/SKILL.md` (plus `references/*.md`) so the `pm` lead runs `test-plan.md` post-merge rows against a detached worktree of main at `PM_SHA` and ends with one `POSTMERGE:` token and, on failure, `pm/new-units.md`.

## 2. Context package
- Card 12; test plan shape part-04 §5.4 (post-merge rows: id, what it proves, command, lane, expected, evidence owner, cold-run, order or seed, gating or informational, failure policy; human hand-test rows; consumer-simulation rows; test-management reporting row; explicitly-not-tested list). E2E rules part-03 §3.6 steps 6 and 8 (auto-healed diffs reviewed, `SOURCE_BUG` escalates).
- Host: the `pm` lead inside `delivery-run` mode `post-merge`, no seed, no waves, no bus (part-a A.2 "Stages 6-7 host"); `PM_SHA` is the `merge_sha` of the last sub-task merge.
- Produced: `RUN_HOME/postmerge-<sha>.md` line 1 `POSTMERGE: PASS|FAIL [rows]` regex `^POSTMERGE: (PASS|FAIL)( [A-Za-z0-9.,-]+)?$` (part-d D1.1; PASS = every gating row passed; rows = failed gating row ids); `RUN_HOME/pm/new-units.md`, one line per failed gating row `<row-id> <one line>` regex `^[A-Za-z0-9.-]+ .+$` (part-d D2.2 row 12); desk `ci-status-main` (`{repo, merge_sha}`, part-b B4) for the merge-pipeline execution (profile `merge_pipeline.stages[]`).
- Consumed: `test-plan.md` in `PLANS_DIR`; catalog leases `lane/<name>` (part-a A.5); `substate.md` fields `pm_sha`, `postmerge_record` (part-a A.2). The conductor maps `PASS` to `Verified` (D3) and, on `FAIL`, reads `new-units.md` and re-invokes `delivery-dispatch-plan` with `NEW_UNITS` (part-a A.2).
- Successor: `release-track` (card 13) reads `postmerge-<sha>.md` as `POSTMERGE_RECORD`.

## 3. Scope
In: `skills/post-merge-verify/SKILL.md` (body under 5k tokens; `version:`; "Use when"; model-invocable, D16); `skills/post-merge-verify/references/*.md` at top level (for example `row-execution.md`, `e2e-rows.md`, `consumer-sim.md`).
Out: `references/templates/` and `references/briefs/` (items 27, 27b); `release-track`; any edit to `test-plan.md` templates; desk code; NLTA plugin skills.
Do NOT create: a new desk verb, a new token, a second verdict vocabulary, any action that runs a destructive test without a recorded grant, any step that promotes or deploys.
Directories written: `skills/post-merge-verify/` only.

## 4. Contracts
| Contract | Value | Authority |
|---|---|---|
| Step 0 inputs | `RUN_HOME`, `PM_SHA`, `PLANS_DIR`; `DELIVERY_ROOT` env; `INPUT-ERROR <field> <reason>` one line per failing field then stop | part-d D1, D2.2 row 12 |
| Token | `POSTMERGE:` line 1 of `postmerge-<sha>.md`, `<sha>` = `PM_SHA` | part-d D1.1 |
| Verdict rule | PASS only if every `gating` row passed; `informational` failures are recorded, never fail the token | part-d D2.1 (post-merge row), part-04 §5.4 |
| Worktree | detached worktree of main at `PM_SHA`, registered in the catalog (`worktree` kind) before start, released at the end; every bound port (lanes, dev servers) follows part-a A.5.2: `tools/port-check.sh --claim` via `port-claim`, then `catalog.sh register port`, launch, `catalog.sh start`; collision refuses the launch, never auto-pick, a lane maps to C2 reason `lane-unavailable`; release is cleanup's | part-a A.5, A.5.2 |
| Parallelism | rows serial per shared lane, parallel otherwise; the lane is a catalog `lane-lease` `lane/<name>`; cold runs, not cache | card 12 |
| E2E rows | via `nl-run-e2e`; auto-healed diffs reviewed, never accepted blind; `SOURCE_BUG` always escalates to the human; mapped reasons `source-bug`, `env-bug` | part-03 §3.6, part-d D2.2 note |
| Consumer simulation | after one serial pack | card 12 |
| Hand-test rows | the human's, never executed by an agent (D17) | card 12 |
| Test-result reporting | desk step; `dry_run` first; never send `folder` on a PUT to an existing case; conductor-only verb via `CONDUCTOR-REQUEST` | card 12; part-b B4; SPEC-QUESTION 1 |
| New units | `<row-id>` matches the test-plan row id | part-d D2.2 row 12 |

## 5. Inherited module API
`catalog.sh` (register/start/release, leases), `tools/port-check.sh` and the `port-claim` skill (A.5.2), desk request writer `desk-req.sh` only for `ci-status-main`, NLTA plugin skills (work environment, installed yes/no table from W0 item 1; cite, do not copy). Names fixed by the INTERFACES script table.

## 6. What you inherit
Anatomy per `tools/skill-authoring.md` §2-§5. Provenance: NLTA guides (auto-heal review, `SOURCE_BUG`, `push-zephyr-test-cases --dry-run`, NLTA part 2 on `folder`), `enforcement-gates:141` for cold runs.

## 7. Known risky values
| Value | Correct | Wrong | Source |
|---|---|---|---|
| runs | cold, no cache | cache-satisfied | card 12 |
| `SOURCE_BUG` | escalate to human | auto-accept heal | §3.6 step 6 |
| reporting PUT | omit `folder` on an existing case | send `folder` | NLTA part 2 |
| `ci-status-main` field | `merge_sha` (= `PM_SHA`) | PR head | part-b B4 |
| row ids | `[A-Za-z0-9.-]+` | spaces, underscores | part-d D2.2 row 12 |
| verdict | gating rows only | weighted score | `brain-workflow-shift:26` |
| tier | execute for runners, verify for the verdict | verdict by the runner | card 12 |

## 8. Acceptance criteria
- [ ] Five sections; Step 0 with the exact inputs of section 4.
- [ ] Steps: read `test-plan.md` post-merge rows; catalog the main worktree; claim ports before bind; acquire lane leases; run rows (serial per lane, parallel otherwise, cold); review auto-healed diffs; consumer simulation after one serial pack; `ci-status-main`; write `postmerge-<sha>.md` with evidence per row; write `pm/new-units.md` on FAIL; release catalog rows.
- [ ] The record body has one evidence line per row id, gating and informational both, and lists hand-test rows as `human`.
- [ ] Stop conditions named: product decision needed; destructive test without a grant; `SOURCE_BUG`.
- [ ] A FAIL never edits code, never opens a PR, never retries a gating row beyond the plan's failure policy column.
- [ ] No cost metric, no personal-project term, no Notion, no `/Users/<name>` path.

## 9. Verification commands
```bash
S=skills/post-merge-verify/SKILL.md
test -f "$S" && head -1 "$S" | grep -qx -- '---'
grep -E '^name: post-merge-verify$' "$S"; grep -E '^version: ' "$S"
awk '/^description:/{ if (length($0) > 1036) print "DESC-TOO-LONG" }' "$S"
grep -E '^description:.*Use when' "$S"
! grep -E '^disable-model-invocation: *true' "$S"
for s in Trigger Steps 'Red flags' 'Exit criteria' Provenance; do grep -qx "## $s" "$S" || echo MISSING "$s"; done
test "$(wc -w < "$S")" -le 3500
for t in 'INPUT-ERROR' 'POSTMERGE:' 'new-units.md' 'ci-status-main' 'SOURCE_BUG' 'nl-run-e2e' 'lane-lease' 'port-check' 'gating' 'informational' 'dry-run'; do grep -q -- "$t" "$S" skills/post-merge-verify/references/*.md || echo ABSENT "$t"; done
! grep -riE '/Users/[a-z]+|brainAlpha|brainBeta|brainGamma|hermesAuth|Xavier|touri|ofw|runfrist|jetblue|notion' skills/post-merge-verify
bash tools/check-doc-length.sh skills/post-merge-verify
```
Done condition: no `MISSING`, `ABSENT` or `DESC-TOO-LONG` line, no failing command, and the review trio returns CLEAN.

## 10. Branch
No branch for the author; Worker1 integrates on `wt/delivery-w0`. No commit.

## 11. Decision Gate reminder
Stop and write `.decisions/21.md` if: AM-1 changes the worktree or port rule; a row needs a desk verb not in part-b B4; the test-plan template lacks a column this skill needs; any step would run a destructive action. Do not guess.

## Metadata
- Tier: execute (author); runtime: execute runners, verify for the verdict (card 12).
- Review rung: Rung 1 trio, up to 3 rounds then the owner (D7).
- Dependencies: INTERFACES 1.1.0 (landed; hard); items 5 (`catalog.sh`), 16 (`resource-catalog`), 27 (test-plan template) soft; consumed by item 28 `delivery-run` mode `post-merge` and by item 25 `release-track`.
- Not a split item.

## SPEC-QUESTIONs
1. Card 12 says test-result reporting is a desk step of this skill; part-d D2.2 row 13 makes `release-track` the writer of the `test-report-push` payload and requester through `CONDUCTOR-REQUEST`, and row 12 lists no payload output. Which skill owns the report step? Default if unanswered: this skill records the results in `postmerge-<sha>.md` and leaves the payload to `release-track`.
2. Whether `PM_SHA` main worktree location is `<worktree_base>/<run-id>-pm` (part-a A.2 example pattern) is inferred from the sub-task pattern; confirm.
3. The failure-policy column values (retry count, quarantine) are not enumerated in INTERFACES; the skill must quote the row's own text and never invent a policy.
