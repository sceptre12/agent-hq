# The merged 10-minute tick (watchdog half)

Depth for the SKILL.md step "arm the merged tick", and the procedure for each tick. Authority (INTERFACES 1.7.0): part C C7 (flag table, nudge template, flag discipline, not-a-stall, after `TaskStop`, bus down, observation means, merged tick), C1.1 (call model and its fallback; lane release, AM-6 C-4), C4 (relay), C5.3 (order after `TaskStop`), C8 (AM-5: CV13, CV17, CV47, controller `TaskStop`); part A A.1 (`shepherd/ticks.md` writers), A.5.1 (`process`, `cron`, `bgtask` rows), A.8 (`tick_utc`; cron probe first, AM-6 (d)); design part-03 §4 "Merged tick"; spec 28 RESOLVED R-3, PC-W2-5, PC-W2-7; AM-4 row 23.

## Arming

- **Who:** the lead, in its own session, on both backends. TaskList and slot rows are lead-session state; the conductor arms only its own 1-minute relay tick (C7, B1).
- **When:** right after the machine-ledger row (SKILL.md step 3), before `REGISTER`, so the `register.consumed` and `RELEASE` waits are observed; again after every resume (a session cron does not survive a restart). Until `bus.endpoint` exists, and always in `plan-pr` and `post-merge`, steps 2 and the bus read of step 4 are skipped (proposed CV23; the mode precedent is SKILL.md step 6).
- **How:** one session cron, every 10 minutes (`*/10 * * * *`, CronCreate), `run_in_background`, with this prompt verbatim from design §4 (`architecture/delivery-workflow/part-03-personas-and-concurrency.md:92`):

```
Stall watchdog and shepherd tick: for every subagent and background task, check state now (row files, output files, elapsed vs budget, TaskList). Past budget with no result: flag STALLED; a pending tool call with no result: flag PROMPT-OPEN; the lead TaskStops and re-dispatches one tier up or escalates, never grants one more budget; **after every TaskStop the lead sweeps for orphan processes under that agent's worktree (verified by cwd and pid, never by pattern), kills them by pid and records each in the catalog** (`stopped-agent-orphan-loop:17-20`; a stopped runner once kept starting suites). For live build agents also run the shepherd checks (NEXT vs plan, scope-check, creep). One line only if something changed; otherwise noop.
```

- **Catalog:** register the cron as a `cron` row (handle = the cron id; `register`, then `start`), so `delivery-cleanup` can `CronDelete` it (A.5.1). Register the controller background task as a `bgtask` row once its task id is known.
- **`claude -p` lead (PC-W2-7; INTERFACES 1.6.0 AM-6 (d)):** the 12-minute cron probe runs first. The lead arms the cron, notes `tick_utc` at its first invocation and waits on that invocation in a timed slice of 12 minutes (a background Bash `sleep 720` whose return wakes it). A `tick_utc` that moved means the cron fires: carry on idling between ticks. No move within the 12 minutes means the cron does not fire (A.8 "A.3 fields"), and only then the lead switches to the C1.1 fallback for the rest of its session: each invocation runs blocking in its own turn, and it runs the watchdog half below between invocations and at every wait-slice boundary (`Hosted skills`, `Wait states`). It keeps rewriting `tick_utc` either way.

## Watchdog half: every tick, in order

The watchdog half belongs to `delivery-run` and runs on every tick, also below 3 live agents (C7, R-3).

0. **Startup wait (proposed CV37).** While SKILL.md steps 4-5 are pending: `outbox/register.refused` is the C5.1 stop; no `register.consumed` 20 minutes after the write is the CV23 stop (`escalations/register.md`, reason `human-step`, `stop_reason: human`); `register.consumed` present: after this tick the lead continues the SKILL.md step sequence at step 5. The prompt above stays verbatim; this step is part of the watchdog half.
1. **Inbox.** Process `inbox/` (`control-channel.md`). A `MERGED` file is renamed `.consumed` only after `CLEANUP DONE` (proposed CV38); a `pm` `verdict` file is left unconsumed (C8 "C5.1 inbox": the `verdict` message type; `control-channel.md`).
2. **Bus down.** Run `kill -0 <pid>` and `lsof -nP -iTCP:<port> -sTCP:LISTEN` on the `bus.endpoint` values. If either fails, `pm2 restart` the app. Two failed restarts in a row write `stop_reason: stop-the-line:S8` (`bus-and-ports.md`). Until the bus is back, agents use the C4 fallback.
3. **Dispatch records.** Read new `dispatch/<invocation>.jsonl` lines: write their slot rows and update `spawns` (`ledger.md`). The first `i<N>` line sets `phase: integrating` (proposed CV21).
4. **Verdicts.** Read the rendezvous topic (peek idiom), drain `<session_id>-escalation`, and relay `status/*.verdict` (C4). All three are covered in `verdicts.md`.
5. **`STALLED`.** For each `slots/*.row`, the agent is stalled when now minus `taken_utc` exceeds `budget_min` with no result: no accepted or logged terminal post, no `.verdict`, and no Agent return in TaskList. For the `wave-controller` row the budget is the invocation's summed `budget_min`. Rows of a stopped invocation (step 9, "Stopped invocations") are not flagged again.
6. **`PROMPT-OPEN`.** An agent whose task output (TaskList output file) ends in a tool call with no result, unchanged since the previous tick, is flagged `PROMPT-OPEN` when that call is not a registered catalog `process` row or the agent is past `budget_min` (C8 CV17, restricted by owner answer O8). An approval dialog once held an agent 83 minutes unseen.
7. **Flag line and nudge.** For each new flag, append exactly one line `<FLAG> <agent-id>` to `RUN_HOME/<subtask>/shepherd/ticks.md` (single-line append; the shepherd appends to the same file). Then send exactly one nudge by `SendMessage`, using the fixed template and no free text:
   ```
   NUDGE <agent-id> | <FLAG> | next: <unit>.<n> | <one line copied from the plan>
   ```
   If the line is already present (written by either half), no second line and no second nudge are sent. A cleared flag that returns is not re-flagged (PC-W2-5, AM-4 23).
8. **Act (the lead decides; D10).** Two flags for one agent, from the watchdog and the shepherd, collapse to one lead action (R-3).
   - `STALLED`: `TaskStop`, then re-dispatch one tier up (`tier_override`, a fresh invocation) or escalate. **Never one more budget.** The `TaskStop` target is the task the lead holds: the agent itself for a lead-dispatched agent; for an agent the controller dispatched, the controller task. That task's checkpoint keeps every passed work_item, and the next invocation re-dispatches the stalled unit with the raised tier. A stalled `wave-controller` row is likewise `TaskStop` and never one more budget (Q1).
   - `PROMPT-OPEN`: answer the prompt when the lead holds the answer within the plan, else stop the agent as for `STALLED`.
9. **After every `TaskStop`, in this order:** TaskStop, orphan sweep, re-read verdicts (bus and `status/*.verdict`), then free rows (C5.3).
   - **Controller stop (proposed CV24).** After a `TaskStop` of a `wave-controller` task, first confirm in TaskList that the task is stopped, then read the new lines of that invocation's `dispatch/<invocation>.jsonl` and write their rows (step 3), so an agent dispatched since the last read is swept and counted. The sweep then covers the worktree of every `.row` whose `agent_id` is in that invocation's `dispatch/<invocation>.jsonl`, and every `gate-runner/<n>` lease those agents hold. Whether depth-2 agents die with their controller is unmeasured, so a row is freed only when its agent is confirmed gone: a `claude-p` pid fails `kill -0`, or an `agent-tool` agent has a terminal post or `.verdict`, or one full tick has passed since the stop with no new post and no process under its worktree. Until then the row stays `.row` and counts in `max_concurrent` and `live_count`. The invocation's lane leases are released after the rows are freed. The lead also writes `dispatch/<invocation>.stopped` (one line, the stop UTC) and marks `ROLLED` each unit that had a live row in the invocation and no accepted record, so the next invocation re-dispatches it per CV7 (owner answer O7; C8 "C7 `STALLED`": a controller `TaskStop` mid-run stops the controller task, sweeps orphans and marks the affected units `ROLLED`).
   - **Orphan sweep:** list processes whose cwd is under the stopped agent's worktree (`lsof -a -d cwd` output filtered to that path, then `kill -0` on each pid). For each one: `catalog.sh register process <pid> <unit|-> <ticket> delivery-run <subtask> <SESSION>`, then `kill <pid>`, then check with `kill -0` that it is gone, then `catalog.sh release process <pid>`. Never kill by pattern or name.
   - If the stopped agent held a `gate-runner/<n>` lease, write its `released` row (AM-4 13).
   - Then re-read verdicts, so a record that landed during the stop is not lost, and only then rename rows `.freed`.
   - **Stopped invocations, every tick (proposed CV24).** For each `dispatch/<invocation>.stopped` file: apply the confirm rule above to every `.row` whose `agent_id` is in that invocation's record, and free each confirmed row (after its sweep and a verdict re-read). When none is left, release the invocation's remaining lane leases and rename the marker `.stopped.done`.

9a. **Pending dispatch (proposed CV21).** Re-run SKILL.md step 10 from 10.1 only when all hold: `MODE=build`; this lead session has reached SKILL.md step 10 (so `register.consumed`, the `RELEASE`, Wave 0 and `bus.endpoint` are behind it); `phase` is `seeded`, `building` or `integrating` (the loop end sets `phase: prepr`, so an ended loop never re-enters); no invocation is live (no `wave-controller` `.row`, and no `.row` of a stopped invocation, step 9, "Stopped invocations"); no unit escalation is open (`verdicts.md` "Escalation closure", proposed CV34); `stop_reason` is empty. This is the wake for a lane-lease or free-slot wait. It runs after step 9 so an escalation opened this tick is seen first.
10. **Shepherd half.** When the sub-task has 3 or more live agents (`slots/*.row`, `wave-controller` excluded), invoke `delivery-shepherd` with `RUN_HOME`, `SUBTASK`, `PLANS_DIR`. It runs as one shepherd agent in the reserved `shepherd: 1` seat (no slot row; it counts in `spawns`), at most one at a time. Before the call, with an invocation live, require `spawns + 1 + (dispatch_budget - lines so far in the live invocation's dispatch record) <= cap - 5`, else `spawns + 1 <= cap - 5`; a failed check skips the shepherd this tick and the lead runs the drift and creep check itself (Q2, `ledger.md`). The shepherd's deadline is its dispatch time plus one tick interval; past it with no reply the lead `TaskStop`s it (default, proposed CV22). It reads peek-only and appends `DRIFT`, `CREEP`, `FREE-CANDIDATE`, `STALLED`, `PROMPT-OPEN` lines plus their one nudge. Its one-line reply lists the flags appended this tick, or `noop`. The lead acts on that reply:
    - `DRIFT`: run a spec check first, then redirect;
    - `CREEP`: record a named defect, never a fix; adjacent defects are ticketed;
    - `FREE-CANDIDATE`: the lead runs its own C2 checks, then frees;
    - `STALLED` / `PROMPT-OPEN`: as in step 8, collapsed with the watchdog's own.

    Below 3 live agents the lead runs the drift and creep check itself on each verdict (`verdicts.md`). The shepherd never decides a `TaskStop`.
11. **Ledgers.** Rewrite the machine row's `live_count` and `utc` atomically (`ledger.md`). Rewrite `substate.md` atomically (`live`, `spawns`, `frontier`, `waves_done`, and `tick_utc: <ISO UTC>`, the line the probe reads; an A.3 field adopted by AM-5, A.8 "A.3 fields", CV8).
12. **Output:** one line only if something changed; otherwise noop.

## Stopping with live agents (proposed CV46)

Any mid-run stop (S8, `port-refused`, `human` from a tick or step 10, a 10.6 return) with agents still live: the lead decides (D10) either to stop them, running the step 9 order on every live task (controller first, then the step 9 "Stopped invocations" check until its rows are freed), or to let them finish, keeping the session and the tick until they return. Only then does it write `stop_reason` and exit. A `claude -p` lead's cron dies with it, so it never exits with an agent live. The `spawn-cap` hand-over already waits for no live invocation.

## Not a stall

- A `claude -p` lead's result followed by a still-running background task is not a stall (turn-close rule, card 7: `interfaces/part-c-waves-control.md:182`, `part-02-skill-inventory.md:62`). The live controller task after the lead's turn has closed is the normal call model (C1.1).
- An agent within its `budget_min` is not stalled, however quiet it is. Budgets come from measured `durations.*`, never from the tick interval (part-03 §4 Reboot).

## Hosted skills (proposed CV22)

`pre-pr-gate`, `ci-fix-loop`, `delivery-cleanup`, `post-merge-verify` and `release-track` run in the lead's turn, where a session cron cannot fire (the C7 merged tick fires while the lead idles on a background invocation, C1.1 call model). So while hosting:

- Every Agent call the hosted skill makes is the lead's own: the `spawns + 1 <= cap - 5` check first and `spawns` + 1 after (A.3 `spawns`); a slot row or a reserved seat per `ledger.md`. Before an agent that itself dispatches (a review orchestrator), require `spawns + 1 + 10 <= cap - 5` (the A.3 `review: 10` pool, default), and after it returns add the agent count its record reports (else 10). A failed check mid-skill: dispatch nothing more, let live agents return, then hand over (`ledger.md`); the new lead re-invokes the hosted skill from its Step 0.
- Each such call runs with `run_in_background`, and the lead waits on it in slices of at most 10 minutes (bounded Monitor wait); between slices, and at each `.out` or `ci-status` poll, it runs watchdog steps 1-9 inline when `tick_utc` is 10 minutes old or more.
- A hosted reserved-seat agent (review seat, `ci-fix-loop` diagnoser, fixer, G48 checker, fix-verifier) has no row, so the lead keeps its deadline: dispatch time plus `durations.pr_review_min` (`pre-pr-gate`) or `durations.ci_round_min` (`ci-fix-loop`), the budgets `ledger.md` gives that skill's rowed agents (PC-W2-6). Past it with no result it is `STALLED` (step 8).
- `ci-fix-loop` step 1 `pending`: after the first `pending` poll, one more `durations.ci_round_min` wait and one re-poll; still `pending` is `stop_reason: human` (after `post-merge-verify` Step 9, OQ-G).

## Wait states

A wait is never an exit while the sub-task is live. In every wait `stop_reason` stays as written (empty, or `invalidate` for the C6 pause) and `phase` keeps its value.

| Wait | Ends on | `agent-tool` lead | `claude -p` lead |
|---|---|---|---|
| `register.consumed` | the rename (C5.1) | idle, tick armed; step 0 above checks the bound of SKILL.md step 4 | in-turn re-check each minute (default, proposed CV23), same bound |
| `RELEASE` (C6), `INVALIDATE` pause | inbox `RELEASE` (`control-channel.md`, proposed CV30) | idle, tick armed; also `INBOX` wakes | clean exit, relaunched on the wake file (C8 CV47) |
| open unit escalation (`ESCALATE`, blocked unit, loop paused per CV21) | inbox `ANSWER`, closed per CV34 (`verdicts.md`) | idle, tick armed | clean exit, relaunched on the wake file (CV47) |
| lane-lease or free-slot wait (SKILL.md 10.2) | 10.2 passes; step 9a re-enters step 10 | idle, tick armed; past `durations.unit_median_min` of waiting, write `escalations/lane-wait.md` (reason `human-step`, the held lane or the slot sums) once, `stop_reason` unchanged; rename it `.resolved-<ts>` when the wait ends (proposed CV41) | clean exit, relaunched on the conductor's next tick (CV47) |
| `MERGED` after `ci: GREEN <head>` | inbox `MERGED` | idle, tick armed | clean exit, relaunched on the wake file (CV47) |
| `RELEASE: WAITING-HUMAN` (`pm`) | `release-track` line 1 terminal | idle, tick armed; every tick re-invokes `release-track`, whose Step 0 re-checks `gates/H-prod.<step_id>.<run-id>.ok` (A.2.1, AM-5 26) and the human's report (proposed CV25) | clean exit, relaunched on the conductor's next tick (CV47) |

The `WAITING-HUMAN` wait has no lead-side timer: the owner is its bound (owner answer O6, item 28 loop record `reviews/28-delivery-run-2b.md`). A `claude -p` lead exits cleanly only with no invocation live (C8 "C5.3 relaunch limits", CV47; owner answer O5). The conductor lists open escalations in its status posts (`verdicts.md`).

## Observation means (C7)

Catalog, `TaskList`, files, `git -C`, `kill -0`, `lsof`. Never `ps` in any form.

## Red flags

| Thought | Reality |
|---|---|
| "It is close, give it another budget." | Never one more budget: `TaskStop`, then tier-up or escalate (part-03 §4). |
| "The shepherd flagged it, so the shepherd stops it." | The shepherd flags only; the lead decides every `TaskStop` (D10). |
| "Kill everything named `node` under the run." | Orphans are found by cwd and pid under one worktree, killed by pid, and catalogued. |
| "Below 3 agents there is no tick." | The watchdog half runs every tick; only the shepherd half waits for 3 live agents. |
| "Nudge again, it ignored the first one." | One nudge per flag line, from whichever half wrote it. |
