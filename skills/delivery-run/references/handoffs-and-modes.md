# Hand-offs and modes

Depth for the SKILL.md steps Wave 0, `02-integrate.md` and `INTEGRATED`, the `fetch` before integrate and before `pre-pr-gate`, `pre-pr-gate`, the stage-5 desk requests, `ci-fix-loop`, `MERGED` -> `delivery-cleanup`, and the `plan-pr` and `post-merge` modes. Authority (INTERFACES 1.4.0): part C C1 (Wave 0, wave files), C5.1 (`MERGED`, `pm` cleanup); part A A.2 (modes, stages 6-7 host), A.2.2 (`default_branch`), A.3 (transport fields, push and merge preconditions), A.6 (dispatch-plan additions, review record), A.7 (`GATE-PASS`); part B B4 (`push`, `pr-create`, `pr-attach`, `pr-comment`, `fetch`); part D D1 (`INPUT-ERROR`), D2.2 rows 9-13; spec 28 RESOLVED R-5, AM4-1, AM4-2, Q5, PC-W2-3, PC-W2-4; AM-4 rows 24-Q2, 11-Q11-R1, W2-4, W2-7.

## Sub-task values

The dispatch-plan sub-task table gives `ticket`, `branch` (`<key>-<slug>`) and `repo` (= `REPO`). The sub-task worktree is `<worktree_base>/<run-id>-<subtask>` on `branch`, and each unit worktree is `<worktree_base>/<run-id>-<subtask>-<unit>` (A.6). The PR base is the profile `default_branch` (A.2.2; "main" in the design means this key).

## Wave 0, in-lead (C1; part-03 §4 Wave shape)

Wave 0 is not a wave file. The lead runs it before its first `wave-execution` call and before the bus step (`bus-and-ports.md`): the worktree adds are serial, the other steps parallel. Its agents post only to their `status/` files, never to the bus, and run as blocking Agent calls in the lead's turn. The tick is armed before `REGISTER` (proposed CV23) but cannot fire during a blocking call; how a stalled Wave 0 agent is caught is owner question O3. No bus-reading agent starts before `bus.endpoint` is written.

1. **Catalog check:** `RUN_HOME/catalog.tsv` exists (created empty at stage 3, A.5). If it is missing, write `stop_reason: human` and stop.
2. **Unit worktrees, serially:** for each unit `u<N>` of the sub-task, `git -C <REPO> worktree add --detach <worktree_base>/<run-id>-<subtask>-u<N> <sub-task branch head>`, one at a time (ref and index locks, M13). Register each one as catalog `worktree` (`<abs-path>#<repo-abs-path>@<branch>`), `planned` before the add and `start` after.
3. **In parallel, each with a slot row (`ledger.md`):**
   - the **gate runner** (persona `gate-runner`, mechanical tier) runs the baseline gates on `origin/<default_branch>` under a `gate-runner/<n>` lease. Its result goes to its `status/` file, and no `GATE-PASS` is written (C1);
   - the **Explorer** (persona `explorer`) re-measures the facts, rows in its `status/` file. It runs at mechanical tier by default and at execute tier when the facts need multi-step derivations (AM4-3, D2.1).
4. **Lane leases** for the first invocation (`ledger.md`, C1.1). Set `phase: building` before that invocation (A.3; the conductor maps it to `building`, A.2).
5. **Constitution:** only when the repo has no profile yet (the planner then writes `PLANS_DIR/subtasks/<subtask>/constitution.md` at the bundle root, next to `waves/`, C1, `skills/delivery-dispatch-plan/references/unit-and-waves.md:14`; the lead runs it when that file exists), the lead runs `constitution.md` serially before `01-build.md`. It dispatches one constitution-and-contracts agent with that file as its instruction, with a slot row and the persona the file names, and verifies its record as a C2 `PASS` (`verdicts.md`). `constitution.md` is not a numbered wave (spec-format rule 4, AM-3 errata (d)).
6. **e2e:** the lead refuses to start e2e generation until `RUN_HOME/<subtask>/gates/H-e2e.<subtask>.ok` exists (A.2.1). A unit that needs it waits blocked, and the batched `.feature` checkpoint is the human's.

## Integrate (`02-integrate.md`) and `INTEGRATED`

1. The extended `wave-execution` runs waves 1..W in one invocation (W' `skills/wave-execution/SKILL.md` step 6) and takes no stop-after-wave argument, so the controller rolls from `01-build.md` into `02-integrate.md` on its own once every `01-build.md` work_item has passed its gate. The lead therefore sends desk `fetch {repo: REPO, ref: <default_branch>}` and reads its `.out` before **every** invocation (SKILL.md step 10.3; Q5, B4 `fetch` row), and every invocation, also one that resumes inside `02-integrate.md`, runs SKILL.md 10.1-10.8 (proposed CV21). The Integrator rebases onto the fetched remote ref and never sends `DESK`.
   - **Serial `i<N>` (M20).** `02-integrate.md` is a barrier wave unless its work_items carry `depends_on` edges, and a barrier wave dispatches all its work_items at once (W' `references/frontier-mode.md:8-14`). Before the first invocation the lead checks that the `i<N>` work_items form one `depends_on` chain or all name one `lane`; otherwise two writers of the sub-task branch are reachable, and the lead writes `stop_reason: human` and stops (the planner's contract is "merging serially", `skills/delivery-dispatch-plan/references/unit-and-waves.md:20`; proposed CV21).
2. The Integrator is the single writer of the sub-task branch (M20). It posts one C2 record per merged unit, `unit` `i<N>`, with `head` = the sub-task branch head after that merge. For each accepted record (`verdicts.md` `PASS` on the sub-task worktree) the lead appends `u<N> <head>` to `substate.md` `integrated`, which is the `INTEGRATED:` entry, regex `^INTEGRATED: u[0-9]+ [0-9a-f]{40}$` (D1.1).
3. `phase: integrating` from the first `i<N>` dispatch-record line (`tick.md` step 3, proposed CV21). A `merge-conflict` record is `ROLLED`, and a conflict that needs a decision is a stop for the human (card 6 Stop, `architecture/delivery-workflow/part-02-skill-inventory.md:60`).

## Loop end (proposed CV21)

- An invocation re-dispatches every work_item its checkpoint does not record as gate-passed (W' `SKILL.md:190-196`), escalated ones included. So while any unit has an open escalation (C2 `ESCALATE`, a drained `fix-loop-cap-exhausted`, a blocked unit, a paused head-mismatch unit) the lead starts no invocation: it waits for the `ANSWER` (`tick.md` "Wait states"), with `phase` unchanged and `stop_reason` empty. The rest of the sub-task ran on inside the invocation that raised it.
- After a return, the lead reads that invocation's `dispatch/<invocation>.jsonl`. A file with no line means the controller found nothing to run (W' `SKILL.md:197`, "All passed: report complete and exit without bus or dispatch"): with every unit's `u<N>` in `integrated`, the loop has ended and the lead goes to `pre-pr-gate`; otherwise the return made no progress, and the lead writes `stop_reason: human` and stops instead of re-invoking. A file with lines means progress: the loop goes on.
- The checkpoint stays the authority for what passed (O-Q6). It lives at `PLANS_DIR/subtasks/.wave-execution-state/<hash>.json` (the sibling of `spec_root`, W' `SKILL.md:185`), shared by every sub-task's bundle, so the lead never picks one by age; it reads only the dispatch record and its own accepted records.

## `pre-pr-gate` (D2.2 row 10)

- **Before each call:** desk `fetch {repo: REPO, ref: <default_branch>}`, then read its `.out` (Q5).
- **Inputs:** `RUN_HOME`, `SUBTASK`, `HEAD` (the sub-task branch head: the last `integrated` head, or the CI-fixed sha below), `WORKTREE` (the sub-task worktree), `REPO_PROFILE` (`@<sha>`), `SECURITY_AUDIT` (passed on unchanged). Set `phase: prepr` first. Hosting rules (own Agent calls, background slices, deadlines): `tick.md` "Hosted skills" (proposed CV22).
- **Reserved and slots:** its review seats run under `review: 10`; its other agents get rows (`ledger.md`, PC-W2-6).
- **Output:** `RUN_HOME/review/<subtask>/checklist-<subtask>.md` line 1, regex `^PREPR: (PASS|STOP( [A-Za-z0-9.,-]+)?)$`. Copy it into `substate.md` as `prepr` (`PASS` or `STOP`), set `head` to the gate's head, and set `review_record` to `RUN_HOME/review/<subtask>/record-<head>.md`. All three name the same sha.
- **`PREPR: STOP`:**

  `pre-pr-gate` names no port row id and no refusal-line text (its open point 5, `skills/pre-pr-gate/references/steps-detail.md:63`), so the lead classifies from the checklist evidence, first match wins (proposed CV26):

  | Evidence | `stop_reason` |
  |---|---|
  | a checklist line below line 1 holds the token `review-bus` and the word `refused` or `exit 3` (the refusal line `pre-pr-gate` step 11 records) | `port-refused` (Q3, AM-4 W2-1) |
  | a `RUN_HOME/review/<subtask>/verify-*-3.md` written by this call exists (round 3, `steps-detail.md:38,56`) | `d7-round3` (D7) |
  | anything else | `stop-the-line:S2` (a failed gate) |

  The lead stops and the conductor reports.
- **`INPUT-ERROR` from `pre-pr-gate`** (or from any skill the lead invokes) carries no verdict. It is not a D7 round and not a fix-verifier iteration. The lead fixes the input and re-invokes with the same iteration (AM4-2, D1).

## Stage 5: desk requests, in this order (B4)

Each request waits for its `DONE` `.out` before the next (`control-channel.md` for sending and polling).

1. **`push` `{repo, branch, expect_head: head}`.** The first push of the PR needs `PREPR: PASS` for that head and `gate-runs/<head>.md` (`GATE-PASS`, A.7; the `pre-pr-gate` cold run is that record). No push precedes `pre-pr-gate` (r3 H26). The desk adds `HUSKY=0` inline; the lead never skips hooks itself.
2. **`pr-create` `{repo, branch, base: <default_branch>, body_path: RUN_HOME/review/<subtask>/pr-body.md, labels[], record_path: <review_record>, expect_head: head}`**, sent only after `prepr: PASS` for `head` (A.3). Copy `pr` from the `.out` to `substate.md` and set `phase: pr-open`.
3. **`pr-attach` `{repo, pr, paths[]}`**, right after `pr-create`, with the lane artifacts under `RUN_HOME/<subtask>/lanes/`. It is skipped when `lanes/` holds no file.
4. **`pr-comment` `{repo, pr, body_path}`**, with a body under `RUN_HOME/bodies/` listing the URLs `pr-attach` returned. It never approves.

**Later pushes to the same PR** (CI fix rounds, through `ci-fix-loop`) need the `GATE-PASS` record for their head plus either `RUN_HOME/ci/<pr>.md` naming that head or `PREPR: PASS` for it (AM4-1, AM-4 24-Q2). They only fast-forward. `ci-fix-loop` writes `ci/<pr>.md` line 1 only at its Finish step (`skills/ci-fix-loop/SKILL.md:36`), and the desk accepts any line of that file containing `expect_head` (`skills/delivery-desk/references/verbs.md:48-50`). So before relaying each `ci-fix-loop` push the lead appends one line `push-head: <expect_head>` to `ci/<pr>.md`, creating the file when absent; line 1 stays `ci-fix-loop`'s, and the lead copies line 1 only after `ci-fix-loop` returns (proposed CV27).

## `ci-fix-loop` (D2.2 row 11)

- **Inputs:** `RUN_HOME`, `SUBTASK`, `REPO`, `PR`. Set `phase: ci`. Its diagnoser, fixer, G48 checker and fix-verifier run one at a time under `ci: 1`, and its gate runner gets a row (PC-W2-6). Its `DESK` lines go through this lead (B1).
- **Output:** `RUN_HOME/ci/<pr>.md` line 1, regex `^CI: (GREEN [0-9a-f]{40}|HUMAN [a-z0-9-]+)$`. Copy it to `substate.md` `ci` (the `CI:` copy).
- **`CI: GREEN <sha>`:**
  - `<sha>` = `head`: done. Wait for `MERGED`; the conductor merges once it reads `pr`, `ci: GREEN <sha>`, `prepr: PASS`, `head` = `<sha>` and `review_record` = `record-<sha>.md` (A.3 W2-7).
  - `<sha>` differs from `head` (CI fixes moved the head): `fetch`, then re-run `pre-pr-gate` with `HEAD=<sha>`. Its step 1 delta verify covers the change, and `prepr`, `head` and `review_record` then name `<sha>` before the conductor can merge (PC-W2-3).
  - That re-run's fix rounds can move the head again (`skills/pre-pr-gate/SKILL.md:128,135`). Then the lead later-pushes the new `head` (it has `GATE-PASS` and `PREPR: PASS`), re-runs `ci-fix-loop`, and repeats until `ci` names `head`. A third such cycle is `stop_reason: d7-round3` (D7 bound applied to this cycle, proposed CV28).
- **`pending`:** the bound on `ci-status` `pending` is in `tick.md` "Hosted skills" (proposed CV22).
- **`CI: HUMAN` mapping (PC-W2-4):**

  | `ci/<pr>.md` | `stop_reason` |
  |---|---|
  | `CI: HUMAN policy` | `stop-the-line:D23` |
  | a round-3 stop: open findings below line 1 and a round-3 `verify-*` that is not CLEAN | `d7-round3` |
  | any other `CI: HUMAN` | `human` |

## `MERGED` -> `delivery-cleanup` (C5.1, D2.2 row 9)

- On inbox `MERGED <subtask> <merge_sha>`: set `phase: merged` and run `delivery-cleanup` with `RUN_HOME`, `MODE=subtask`, `SUBTASK`, `MERGE_RECORD=RUN_HOME/merge-<merge_sha>.md`. The lead is the approver; the executor is a separate mechanical-tier agent with a slot row. Cleanup removes the bus, pm2 app, port claim, worktrees, the cron and the leases through their catalog rows.
- After `cleanup-<run-id>-<subtask>.md` line 1 reads `CLEANUP DONE <subtask>`: set `phase: done`, write `substate.md`, print its path, and end.
- **`pm` cleanup:** the `pm` lead runs `delivery-cleanup` mode `subtask` with `SUBTASK=pm` once `release-<pm_sha>.md` line 1 is terminal (`RELEASE: LIVE` or `RELEASE: ROLLED-BACK`). Its evidence is `postmerge-<pm_sha>.md` and `release-<pm_sha>.md`, the `substate.md` `postmerge_record` and `release_record`. There is no `MERGE_RECORD`.

## Ticket events (R-5)

The lead's hand-off to `ticket-clerk` is its `substate.md` fields (`phase`, `prepr`, `ci`), which the conductor turns into ticket events. The lead never invokes `ticket-clerk` and never sends any `jira-*` verb.

## Mode `plan-pr` (`st0`; A.2)

There is no seed, no waves and no bus. `substate.md` is initialized from `subtask_id`, `session_id`, `phase: seeded`. After reconcile:

1. Copy the `PLANS_DIR` files onto the `st0` branch in the sub-task worktree (A.6 dispatch-plan additions). The copy-and-commit is done by one Integrator agent the lead dispatches (slot row), because the branch has a single writer (M20).
2. Then `fetch`, `pre-pr-gate`, stage 5, `ci-fix-loop`, `MERGED` -> `delivery-cleanup`, as above.

## Mode `post-merge` (`pm`; A.2 stages 6-7 host)

There is no seed, no waves and no bus. `PM_SHA` is required.

1. Initialize `substate.md` as in `plan-pr` (with the `reserved` map, proposed CV29), and record `pm_sha`. The detached worktree `<worktree_base>/<run-id>-pm` is added by `post-merge-verify` Step 2 (`skills/post-merge-verify/SKILL.md:27`), not by the lead.
2. Run `post-merge-verify` (`RUN_HOME`, `PM_SHA`, `PLANS_DIR`, and inline `WORKTREE_BASE` = the profile `worktree_base` and `REPO_PROFILE` = the lead's own input; `skills/post-merge-verify/SKILL.md:13`, AM-5 row 21), with `phase: post-merge`. Its verdict arrives as a `verdict` inbox file (`control-channel.md`). Copy `postmerge-<pm_sha>.md` line 1 into `postmerge` (the bare `PASS` or `FAIL`) and its path into `postmerge_record`.
3. On `POSTMERGE: PASS`, run `release-track` (`RUN_HOME`, `PM_SHA`, `PLANS_DIR`, `POSTMERGE_RECORD`, `REPO_PROFILE`, `STAKES`, `CONTENTION`, `NOVELTY`), with `phase: release`, and record `release_record`. `release-track` Step 0 requires the last three (`skills/release-track/SKILL.md:17`), and no source names where the `pm` lead reads them (owner question O1). (interim, owner question O1): the lead passes them only from a carrier the owner has named; until then, for each absent one it prints `INPUT-ERROR <NAME> missing` (D1), writes `stop_reason: human`, prints the `substate.md` path and stops before `release-track`. Its conductor-only verbs leave through `RUN_HOME/pm/outbox/<seq>.conductor-request` (C5.1); the lead sends none of them.
4. On `POSTMERGE: FAIL` (proposed CV32): `postmerge: FAIL`, `phase` stays `post-merge`, `stop_reason` empty; the lead `CronDelete`s its own tick and writes that `cron` row's catalog `release`, leaves every other `pm` row to the conductor's `final` cleanup (C5.1; `post-merge-verify` Step 14 already released its lane leases), prints the `substate.md` path and ends. The re-entry (new `st<N>` from `pm/new-units.md`) is the conductor's (A.2).
5. On `POSTMERGE: STOP <reason>` (AM-5 row 21; `skills/post-merge-verify/SKILL.md:50`): leave `postmerge` empty, set `postmerge_record`, write `stop_reason: human`, print the record path and the `substate.md` path, and stop.
6. On `RELEASE: WAITING-HUMAN` (not terminal, `skills/release-track/SKILL.md:37`): wait per `tick.md` "Wait states"; every tick re-invokes `release-track`, which resumes at its Step 0 (proposed CV25). Its bound is owner question O6.
7. On a terminal `RELEASE:` line, run the `pm` cleanup above.

## `.decisions` fork flow (template `references/templates/decisions-fork.md`)

1. A unit that hits its Decision Gate writes `.decisions/<unit>.md` per the template, then posts `ESCALATE` `decision-gate`. The lead writes `escalations/<unit>.md` with that path (`verdicts.md`).
2. The lead reads the Fork, Options and Recommendation and never edits them. It resolves the fork itself (`resolved_by: lead`) only when the fork stays within the plan and the frozen contracts. A fork that touches an owner ruling or a one-way decision goes to the human, and the escalation stays open.
3. The human's answer arrives as inbox `ANSWER <run-id> <subtask> <unit> <text>`. The lead writes the Resolution with `resolved_by: human`, quoting the text.
4. The lead fills `## Re-dispatch instruction`: the exact value, the file, and the tier (`tier_override <unit>=<tier>` if raised). Until that section is filled the unit stays blocked.
5. Re-dispatch is a fresh invocation, once the live one has returned (`ledger.md`). The controller resumes at the unpassed items.

## Conventions pending INTERFACES

INTERFACES 1.4.0 is silent on the points below, so this skill fixes them here. SKILL.md and these references follow them. Each one is a proposed AM-5 row (queued in the build's `am5-queue.md` for item 33). Until AM-5 lands, these rows say which reading the skill uses, and they are not contract text.

- (28-CV1, proposed) C1 "Wave 0 setup": Wave 0 runs before the sub-task bus is claimed; its agents (baseline gate runner, Explorer, constitution agent) post only to their `status/` files, run as blocking Agent calls in the lead's turn, and no bus-reading agent starts before `bus.endpoint` is written.
- (28-CV2, proposed) A.3 `stop_reason`: a stop INTERFACES names without a reason is written `human`: `$DATA_DIR/port` not equal to the claim (A.5.2), a `bus.endpoint` `session_id`/`topic` mismatch (A.3), a missing `catalog.tsv` (C1), `register.refused` (C5.1), a controller `VALIDATION_FAILED` or `BUNDLE-ERROR` return (C1.1), a machine-ledger cap crossed (A.4); a `PREPR: STOP <rows>` for a row outside the review loop (D2.2 row 10) is `stop-the-line:S2`.
- (28-CV3, proposed) A.4 field 3: a wave-level gate agent whose dispatch record carries `unit` `wave-<N>` (C1, AM-4 9) gets slot row `unit` `-` and `worktree` = the sub-task worktree.
- (28-CV4, proposed) A.5.1: the lead registers its merged-tick cron as a catalog `cron` row (handle = cron id) and each controller background task as a `bgtask` row (handle = task id), `register` then `start`, so `delivery-cleanup` removes them.
- (28-CV5, proposed) A.2 Modes / A.6: in mode `plan-pr` the `PLANS_DIR` files reach the `st0` branch through one Integrator agent the lead dispatches (slot row); the lead never commits (M20).
- (28-CV6, proposed) C2 `PASS` row: "two consecutive mismatches on one unit are a stop row for that unit" means the unit is paused as for `ESCALATE` (`escalations/<unit>.md` holds both records and the observed head), its dependents stay unreleased and the rest of the sub-task runs on; the count is derived from the topic (two mismatching records for the unit with no accepted record between).
- (28-CV7, proposed) C2 `ROLLED`: earlier attempts per tier are counted from the unit's `dispatch/*.jsonl` lines; two recorded top-tier attempts mean blocked plus `ESCALATE` `tier-exhausted`; tier-up fits `budget`/`merge-conflict`, blocked plus escalation fits `lane-unavailable`/`env-bug`.
- (28-CV8, proposed) A.3 new field `tick_utc: <ISO UTC>`, rewritten by the lead on every tick; the PC-W2-7 measurement reads it. (The 12-minute probe first proposed here had no executor; superseded by CV23.)
- (28-CV9, proposed) C5.1 inbox: a file whose first line fails its grammar or names another sub-task is not acted on; the lead logs it as a `human-step` escalation and renames it `.consumed`.
- (28-CV10, proposed) A.4 machine ledger: `machine/.lock` carries an `owner` file as `substate.lock` (A.3); a waiter retries every 1 s for 60 s; a stale lock is broken by the A.3 procedure; rows whose pid fails `kill -0` are renamed `.dead` before the sum.
- (28-CV11, proposed) C2 readers / C5.3 paging: the lead's bus reader `agent_id` is `<SESSION>-read-<n>`, fresh per read, never a dispatched agent's id.
- (28-CV12, proposed) A.4 `.freed`: a worker row is freed after a verified `PASS` or a handled `ROLLED`/`ESCALATE` record from its registered `from_agent`; a gate or fix agent after its terminal post is logged or its invocation returns; a lead-own or hosted agent when its call returns and its result is read; any row after a `TaskStop` only in the C5.3 order; never on an unverified post.
- (28-CV13, proposed) C7 `STALLED`: for an agent the controller dispatched, the lead's `TaskStop` target is the controller task; its checkpoint keeps every passed work_item and the next invocation re-dispatches the stalled unit with `tier_override`.
- (28-CV14, proposed) A.5.2 launch failure after a claim (port check or identity preflight fails): `pm2 delete` the app, write the claim's `released` row, `catalog.sh fail` the `port`, `pm2-app` and `bus` rows, `stop_reason: human`.
- (28-CV15, proposed) C6 `RELEASE` wait: while waiting the lead may arm a session cron that only re-reads `inbox/`, deleted once `RELEASE` is consumed.
- (28-CV16, proposed) A.5 catalog keys for lead rows: `correlation_id` = the dispatch-plan sub-task `ticket`, `source` `delivery-run`, `owner_agent` = the lead's `SESSION`.
- (28-CV17, proposed) C7 `PROMPT-OPEN` observation: the agent's TaskList output file ends in a tool call with no result and is unchanged since the previous tick.
- (28-CV18, proposed) A.3 `phase`: the lead sets `phase: building` before its first `wave-execution` invocation.
- (28-CV19, proposed) C1 wave files: the lead runs `PLANS_DIR/subtasks/<subtask>/constitution.md` (bundle root, C1) when that file exists (the planner writes it only for a repo with no profile) and verifies its record as a C2 `PASS`.
- (28-CV20, proposed) C1 `spec_root`: the lead passes `spec_root` = `PLANS_DIR/subtasks/<subtask>`, the bundle root holding `bundle.md` and `waves/` (W' `references/spec-format.md:16-31`, preflight rules 1-2 at `:185-186`); INTERFACES C1's "a `waves/` spec_root" is read as naming the Option B layout. The checkpoint then lives in `PLANS_DIR/subtasks/.wave-execution-state/` (W' `SKILL.md:185`).
- (28-CV21, proposed) C1.1 invocation loop: before every invocation the lead sends `fetch` and runs SKILL.md 10.1-10.8; before the first it checks that the `i<N>` of `02-integrate.md` form a `depends_on` chain or share one `lane`, else `stop_reason: human`; `phase: integrating` is set at the first `i<N>` dispatch-record line; no invocation starts while an escalation is open; a return whose dispatch record has no line ends the loop when every unit is in `integrated`, else is `stop_reason: human`; a held lane lease or too few free slots releases this pass's leases and waits, and the tick re-enters step 10 when no invocation is live.
- (28-CV22, proposed) A.3 `spawns` / C7 for hosted skills: every Agent call a hosted skill makes is a lead-own call (spawn check, row or reserved seat), run in the background and waited in slices of at most 10 minutes with the watchdog half between them; an agent that dispatches on its own needs `spawns + 11 <= cap - 5` first and adds its reported count after; a hosted reserved-seat agent is `STALLED` past dispatch time plus `durations.pr_review_min` or `durations.ci_round_min`; `ci-fix-loop` `pending` gets one extra `durations.ci_round_min` wait and one re-poll, then `stop_reason: human`.
- (28-CV23, proposed) C7 arming / C5.1 register wait / PC-W2-7: the lead arms the merged tick right after its machine row, skipping the bus steps until `bus.endpoint` exists; no `register.consumed` within 20 minutes is an `escalations/register.md` `human-step` and `stop_reason: human`; a `claude -p` lead runs the C1.1 blocking fallback from its start until PC-W2-7 is measured.
- (28-CV24, proposed) C5.3 order after a controller `TaskStop`: confirm the task stopped in TaskList, sweep the worktree of every live row of the invocation and their `gate-runner/<n>` leases, free a row only when its agent is confirmed gone (pid dead, terminal post, or one quiet tick with no process under its worktree), then release the invocation's lane leases.
- (28-CV25, proposed) A.2 `pm` `WAITING-HUMAN`: while `release-<pm_sha>.md` line 1 is `RELEASE: WAITING-HUMAN`, every tick re-invokes `release-track`, which resumes at its Step 0.
- (28-CV26, proposed) D2.2 row 10 `PREPR: STOP` mapping: a checklist line holding `review-bus` and `refused` or `exit 3` is `port-refused`; else a round-3 `verify-*-3.md` written by the call is `d7-round3`; else `stop-the-line:S2`.
- (28-CV27, proposed) B4 later push: before relaying each `ci-fix-loop` push the lead appends `push-head: <expect_head>` to `RUN_HOME/ci/<pr>.md` (creating it when absent); line 1 stays `ci-fix-loop`'s.
- (28-CV28, proposed) A.3 PC-W2-3 cycle: when the `pre-pr-gate` re-run on a CI-fixed head moves the head again, the lead later-pushes, re-runs `ci-fix-loop` and repeats until `ci` names `head`; a third cycle is `d7-round3`.
- (28-CV29, proposed) A.3 `reserved` in `plan-pr`/`post-merge`: the lead writes the A.3 seed map `{shepherd: 1, clerk: 1, ci: 1, review: 10}` into `substate.md` at its lock step and uses it in the free-slot formula and the machine row.
- (28-CV30, proposed) C6 after `INVALIDATE`: only an inbox `RELEASE` with a higher `<seq>` than the `INVALIDATE` starts a waiting lead or clears `stop_reason: invalidate`, also on a resume.
- (28-CV31, proposed) C5.3 resume of Wave 0 and the bus: Wave 0 items the catalog, the `status/` files or the checkpoint show done are skipped, and an existing `bus.endpoint` takes the restart path with no new claim.
- (28-CV32, proposed) A.2 `pm` on `POSTMERGE: FAIL`: `phase` stays `post-merge`, `stop_reason` empty; the lead deletes its own tick cron (catalog `release`), leaves every other `pm` row to the conductor's `final` cleanup, prints the `substate.md` path and ends.

## Red flags

| Thought | Reality |
|---|---|
| "Push now and let `pre-pr-gate` catch up." | The first push follows `PREPR: PASS` and `GATE-PASS` for that head (B4). |
| "CI went green on a new sha, merge it." | Re-run `pre-pr-gate` with `HEAD=<sha>` first (PC-W2-3). |
| "Tell the clerk the PR is open." | The clerk runs only in the conductor; `substate.md` is the hand-off (R-5). |
| "The lead can commit the plan files itself." | Branch writes are the Integrator's (M20). |
| "`pre-pr-gate` said INPUT-ERROR, that is round 1 gone." | Not a round: fix the input, re-invoke with the same iteration (AM4-2). |
