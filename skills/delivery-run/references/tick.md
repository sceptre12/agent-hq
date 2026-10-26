# The merged 10-minute tick (watchdog half)

Depth for the SKILL.md step "arm the merged tick", and the procedure for each tick. Authority (INTERFACES 1.4.0): part C C7 (flag table, nudge template, flag discipline, not-a-stall, after `TaskStop`, bus down, observation means, merged tick), C1.1 (call model and its fallback), C4 (relay), C5.3 (order after `TaskStop`); part A A.1 (`shepherd/ticks.md` writers), A.5.1 (`process`, `cron`, `bgtask` rows); design part-03 §4 "Merged tick"; spec 28 RESOLVED R-3, PC-W2-5, PC-W2-7; AM-4 row 23.

## Arming

- **Who:** the lead, in its own session, on both backends. TaskList and slot rows are lead-session state; the conductor arms only its own 1-minute relay tick (C7, B1).
- **When:** after `bus.endpoint` is written and before the first `wave-execution` invocation; again after every resume (a session cron does not survive a restart). The `plan-pr` and `post-merge` modes also arm it before their first own Agent call.
- **How:** one session cron, every 10 minutes (`*/10 * * * *`, CronCreate), `run_in_background`, with this prompt verbatim from design §4 (`architecture/delivery-workflow/part-03-personas-and-concurrency.md:92`):

```
Stall watchdog and shepherd tick: for every subagent and background task, check state now (row files, output files, elapsed vs budget, TaskList). Past budget with no result: flag STALLED; a pending tool call with no result: flag PROMPT-OPEN; the lead TaskStops and re-dispatches one tier up or escalates, never grants one more budget; **after every TaskStop the lead sweeps for orphan processes under that agent's worktree (verified by cwd and pid, never by pattern), kills them by pid and records each in the catalog** (`stopped-agent-orphan-loop:17-20`; a stopped runner once kept starting suites). For live build agents also run the shepherd checks (NEXT vs plan, scope-check, creep). One line only if something changed; otherwise noop.
```

- **Catalog:** register the cron as a `cron` row (handle = the cron id; `register`, then `start`), so `delivery-cleanup` can `CronDelete` it (A.5.1). Register the controller background task as a `bgtask` row once its task id is known.
- **Probe (PC-W2-7):** it is unmeasured whether a session cron fires inside a `claude -p` lead. The first invocation of a `claude -p` lead checks that one tick ran (the `substate.md` `tick_utc` line moved) within 12 minutes. If none did, the lead switches to the C1.1 fallback for the rest of its life: each invocation runs blocking in the lead's own turn, and the watchdog half below runs between invocations.

## Watchdog half: every tick, in order

The watchdog half belongs to `delivery-run` and runs on every tick, also below 3 live agents (C7, R-3).

1. **Inbox.** Process `inbox/` (`control-channel.md`).
2. **Bus down.** Run `kill -0 <pid>` and `lsof -nP -iTCP:<port> -sTCP:LISTEN` on the `bus.endpoint` values. If either fails, `pm2 restart` the app. Two failed restarts in a row write `stop_reason: stop-the-line:S8` (`bus-and-ports.md`). Until the bus is back, agents use the C4 fallback.
3. **Dispatch records.** Read new `dispatch/<invocation>.jsonl` lines: write their slot rows and update `spawns` (`ledger.md`).
4. **Verdicts.** Read the rendezvous topic (peek idiom), drain `<session_id>-escalation`, and relay `status/*.verdict` (C4). All three are covered in `verdicts.md`.
5. **`STALLED`.** For each `slots/*.row`, the agent is stalled when now minus `taken_utc` exceeds `budget_min` with no result: no accepted or logged terminal post, no `.verdict`, and no Agent return in TaskList. For the `wave-controller` row the budget is the invocation's summed `budget_min`.
6. **`PROMPT-OPEN`.** An agent whose task output (TaskList output file) ends in a tool call with no result, unchanged since the previous tick, is flagged `PROMPT-OPEN`. An approval dialog once held an agent 83 minutes unseen.
7. **Flag line and nudge.** For each new flag, append exactly one line `<FLAG> <agent-id>` to `RUN_HOME/<subtask>/shepherd/ticks.md` (single-line append; the shepherd appends to the same file). Then send exactly one nudge by `SendMessage`, using the fixed template and no free text:
   ```
   NUDGE <agent-id> | <FLAG> | next: <unit>.<n> | <one line copied from the plan>
   ```
   If the line is already present (written by either half), no second line and no second nudge are sent. A cleared flag that returns is not re-flagged (PC-W2-5, AM-4 23).
8. **Act (the lead decides; D10).** Two flags for one agent, from the watchdog and the shepherd, collapse to one lead action (R-3).
   - `STALLED`: `TaskStop`, then re-dispatch one tier up (`tier_override`, a fresh invocation) or escalate. **Never one more budget.** The `TaskStop` target is the task the lead holds: the agent itself for a lead-dispatched agent; for an agent the controller dispatched, the controller task. That task's checkpoint keeps every passed work_item, and the next invocation re-dispatches the stalled unit with the raised tier. A stalled `wave-controller` row is likewise `TaskStop` and never one more budget (Q1).
   - `PROMPT-OPEN`: answer the prompt when the lead holds the answer within the plan, else stop the agent as for `STALLED`.
9. **After every `TaskStop`, in this order:** TaskStop, orphan sweep, re-read verdicts (bus and `status/*.verdict`), then free rows (C5.3).
   - **Orphan sweep:** list processes whose cwd is under the stopped agent's worktree (`lsof -a -d cwd` output filtered to that path, then `kill -0` on each pid). For each one: `catalog.sh register process <pid> <unit|-> <ticket> delivery-run <subtask> <SESSION>`, then `kill <pid>`, then check with `kill -0` that it is gone, then `catalog.sh release process <pid>`. Never kill by pattern or name.
   - If the stopped agent held a `gate-runner/<n>` lease, write its `released` row (AM-4 13).
   - Then re-read verdicts, so a record that landed during the stop is not lost, and only then rename rows `.freed`.
10. **Shepherd half.** When the sub-task has 3 or more live agents (`slots/*.row`, `wave-controller` excluded), invoke `delivery-shepherd` with `RUN_HOME`, `SUBTASK`, `PLANS_DIR`. It runs as one shepherd agent in the reserved `shepherd: 1` seat (no slot row; it counts in `spawns`), at most one at a time. It reads peek-only and appends `DRIFT`, `CREEP`, `FREE-CANDIDATE`, `STALLED`, `PROMPT-OPEN` lines plus their one nudge. Its one-line reply lists the flags appended this tick, or `noop`. The lead acts on that reply:
    - `DRIFT`: run a spec check first, then redirect;
    - `CREEP`: record a named defect, never a fix; adjacent defects are ticketed;
    - `FREE-CANDIDATE`: the lead runs its own C2 checks, then frees;
    - `STALLED` / `PROMPT-OPEN`: as in step 8, collapsed with the watchdog's own.

    Below 3 live agents the lead runs the drift and creep check itself on each verdict (`verdicts.md`). The shepherd never decides a `TaskStop`.
11. **Ledgers.** Rewrite the machine row's `live_count` and `utc` atomically (`ledger.md`). Rewrite `substate.md` atomically (`live`, `spawns`, `frontier`, `waves_done`, and `tick_utc: <ISO UTC>`, the line the probe reads; a proposed A.3 field, `handoffs-and-modes.md` "Conventions pending INTERFACES").
12. **Output:** one line only if something changed; otherwise noop.

## Not a stall

- A `claude -p` lead's result followed by a still-running background task is not a stall (turn-close rule, card 7). The live controller task after the lead's turn has closed is the normal call model (C1.1).
- An agent within its `budget_min` is not stalled, however quiet it is. Budgets come from measured `durations.*`, never from the tick interval (part-03 §4 Reboot).

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
