# Slot ledger, spawn cap, machine row and leases

Depth for the SKILL.md steps "machine-ledger row" and "invocation loop", and for every dispatch the lead makes. Authority (INTERFACES 1.4.0): part A A.3 (`live`, `reserved`, `spawns`, lock), A.4 (slot row, free slots, machine row, security-audit agents), A.5 (leases), A.7 (gate runner); part C C1.1 (`max_concurrent`, dispatch record, lane lease), C5.3 (hand-over); spec 28 RESOLVED Q1, Q2, PC-W2-1, PC-W2-2, PC-W2-6; AM-4 rows W2-2, W2-8, W2-9, 13.

## The slot row

`RUN_HOME/<subtask>/slots/<agent-id>.row` holds one line with nine space-separated fields in A.4 order: `agent_id persona unit tier taken_utc budget_min worktree backend pid`. The file stem equals `agent_id`. Each row is written to a temp file in `slots/` and `mv`d into place (A.1). Example (A.4):

```
impl-u07 implementer u07 execute 2026-11-02T10:31:00Z 45 /abs/delivery/wt/found-1234-20261102-st1-u07 claude-p 48213
```

- `tier` is a tier name, never a model (M19).
- `pid`: an `agent-tool` row has `<lead-pid>/<agent-id>`, where `<lead-pid>` is the lead session's pid as recorded in its `substate.lock` `owner`. A `claude-p` row starts with `pending` and is rewritten once the child's pid is known (the catalog `process` row registered for that child, D25).
- `live` in `substate.md` is derived from the count of `slots/*.row` (`<n>/30`), never set by hand.

## Who gets a row

| Agent | Row | Fields the lead fills |
|---|---|---|
| The `wave-execution` controller task (one per invocation) | yes, written **before** its Agent call (Q1, AM-4 W2-2) | `persona` `wave-controller` (no brief file), `unit` `-`, `tier` = the wave `agents` tier, `budget_min` = the sum of the invocation's work_item budgets (an upper bound), `worktree` = the sub-task worktree, `pid` `<lead-pid>/<agent-id>` |
| Each `dispatch/<invocation>.jsonl` line (worker, gate, fix agents) | yes, one row per recorded `agent_id`, as the line appears (A.4, C1.1) | `persona`, `unit`, `tier`, `backend` from the line. `worktree` is derived by the lead: `<worktree_base>/<run-id>-<subtask>-<unit>` for `u<N>`, the sub-task worktree for `i<N>`, the served work_item's worktree for gate and fix agents (C1.1). `budget_min` for a worker is the work_item budget, copied from its brief text (C1.2 `budget` row). A gate or fix agent gets `durations.unit_median_min` (A.4 field 6; A.2.2). A wave-level gate agent has `unit` `wave-<N>` in its record (AM-4 9), so its row takes `unit` `-` (the A.4 field-3 grammar) and the sub-task worktree. |
| Lead-own agents: Wave 0 gate runner, Wave 0 Explorer, constitution agent, Integrator for `st0`, `delivery-cleanup` executor and validator | yes, before the Agent call | `persona` per D2.1. `budget_min` from `durations.*`. `unit` `-` unless the agent serves one. |
| Agents of hosted skills: `pre-pr-gate`'s gate runner, G48 checker, fixer, fix-verifier, validator, Verified-By seat and security auditors; `ci-fix-loop`'s gate runner | yes, before each dispatch (PC-W2-6) | `budget_min` `durations.pr_review_min` for `pre-pr-gate` agents and `durations.ci_round_min` for `ci-fix-loop` agents |
| `security-audit` hunters and verifiers (full mode, inside `pre-pr-gate`) | yes, before each starts (A.4 AM-1) | `persona` `security-auditor`, `unit` `-`, `tier` `verify`. Their total `budget` is the free-slot count at launch, and none starts without a free slot. |
| Reserved seats: the shepherd, `pre-pr-gate` review seats (`review: 10`), `ci-fix-loop`'s diagnoser, fixer, G48 checker and fix-verifier (one at a time under `ci: 1`) | **no row**; counted through `reserved` (A.3, A.4, PC-W2-6) | none. `clerk: 1` stays reserved but unused: the clerk runs only in the conductor (A.6). |

A slot is never reserved ahead: there are no reservation rows (A.4). Gate and fix agents count toward `max_concurrent`, and one with no free slot waits (C1.1).

## Rows for dispatch-record agents

The controller appends the line before it dispatches the agent, and the lead writes the row when it reads that line. Reads happen in the C2 handling cron while the invocation is live, on every tick, and once more after the controller returns. Because the controller mints the ids, these rows always follow the dispatch. The ceiling still holds because the controller admits at most `max_concurrent` agents (A.4). An `agent_id` already present as `.row`, `.stale` or `.freed` gets no second row.

## Free slots and `max_concurrent`

```
max_concurrent = 30 - live_rows - sum(reserved)
```

- `live_rows` counts `slots/*.row`. `reserved` is the seed map (`shepherd: 1, clerk: 1, ci: 1, review: 10`), copied into `substate.md` and never edited by the lead (A.3). In `plan-pr` and `post-merge`, which have no seed, the lead writes the same map at SKILL.md step 2 (proposed CV29), so the formula and the machine row count `pre-pr-gate`'s `review: 10` seats.
- Compute it **after** the controller row exists, so the controller's own slot is already subtracted (Q1).
- `max_concurrent` is a caller argument passed on each invocation (C1.1). It is never a spec field and never a constant 30. Before the controller row is written, the lead requires `30 - live_rows - sum(reserved) - 1 >= 1`; otherwise it bumps nothing, writes no row, releases the leases it took in this pass, and waits. The tick's pending-dispatch step re-enters the loop at 10.1 (`tick.md` step 9a, proposed CV21); the wait has a row and a bound in `tick.md` "Wait states" (proposed CV41).
- A controller return of `VALIDATION_FAILED` or `BUNDLE-ERROR <field>` (C1.1, AM-4 9) dispatched nothing: free the `wave-controller` row, write `stop_reason: human` and stop.
- At most one live invocation per sub-task. A re-dispatch (`ROLLED`, `.decisions` resolution, resume) waits until the live invocation has returned (Q1).
- Before any lead-own or hosted dispatch the same formula must leave at least one free slot. A spawn without a free slot is stop-the-line S4.

## Freeing (`.freed`)

Each case renames `<agent-id>.row` to `<agent-id>.freed`. A row is never deleted.

| Row | Freed when |
|---|---|
| worker `u<N>` or Integrator `i<N>` | after its C2 record passed the `verdicts.md` checks: for `PASS`, the head equals `git rev-parse` and the load-bearing command passed; for `ROLLED` or `ESCALATE`, the record is schema-valid from the registered `from_agent` and has been handled |
| gate or fix agent | after its terminal post (gate verdict or fix-loop output) from its registered id is logged, or when the invocation returns |
| any dispatch-record row still `.row` when the controller task returns | at that return: the controller ends only when no agent of the invocation is live (W' step 8) |
| `wave-controller` | when the task returns (TaskList) and its step 8 final result is noted, or after a `TaskStop` |
| lead-own or hosted agent | when its Agent call returns and its result (a status file, `GATE-PASS` record or record file) has been read, or after a `TaskStop` |
| any row after a `TaskStop` | only in the order TaskStop, orphan sweep, re-read verdicts (bus and `status/*.verdict`), then free rows (C5.3, C7) |

The shepherd never frees a row. It flags `FREE-CANDIDATE`, and the lead frees only after its own C2 verification (C7). An unverified post never frees a row.

## Spawn count and the hand-over (Q2, AM-4 W2-8)

- `<cap>` = env `CLAUDE_CODE_MAX_SUBAGENTS_PER_SESSION`, read at ORCHESTRATOR-CHECK. If it is unset or not an integer, the check fails and the lead stops (fail closed).
- `spawns` counts every Agent call made in this lead session, its own and those of the skills it hosts (`pre-pr-gate`, `ci-fix-loop`, `delivery-cleanup`, the shepherd, review seats), plus every dispatch-record line of the invocations this session started. Nested spawns are counted because it is unmeasured whether the session cap counts them. The lead writes `spawns: <n>/<cap>` to `substate.md` atomically after each Agent call and after each read of new record lines.
- Before any own Agent call: `spawns + 1 <= cap - 5`; while an invocation is live, an own call (the shepherd included) also keeps that invocation's remaining budget: `spawns + 1 + (dispatch_budget - lines so far in its dispatch record) <= cap - 5` (Q2; a failed check skips the shepherd, `tick.md` step 10). Agent calls of a hosted skill are own calls; the headroom before an agent that dispatches on its own, and the mid-skill hand-over, are in `tick.md` "Hosted skills" (proposed CV22).
- Before each invocation: `spawns + 1 + (dispatch_budget - lines so far) <= cap - 5`, where `dispatch_budget` is the `bundle.md` field and "lines so far" counts only this invocation's `dispatch/<invocation>.jsonl` (0 at 10.1).
- When either check fails: dispatch nothing more. Once no invocation is live, run the C5.3 hand-over: write `stop_reason: spawn-cap`, remove the lifetime `substate.lock`, and exit (`resume.md`). The new lead is a new session, so its count starts at 0 (A.3), and it clears `spawn-cap` at resume (PC-W2-8).

## Machine ledger row (PC-W2-1, PC-W2-2, AM-4 W2-9)

- **When:** after the seed copy and before `REGISTER`, for every lead on either backend.
- **Lock:** `mkdir $DELIVERY_ROOT/machine/.lock`, with an `owner` file as for `substate.lock` (A.3). A waiter retries every 1 s and gives up after 60 s. A stale lock is broken by the A.3 break procedure (A.3 lock rule, `interfaces/part-a-state.md:186`, which covers `machine/.lock`).
- **Under the lock:** reap first, renaming every `machine/*.row` whose `pid` fails `kill -0` to `.dead`. Then sum `live_count` over the remaining rows plus 31 for this session (at most 30 slot and reserved agents plus its own seat, AM-5 29-2). The total must be at most 200. When `MODE=build`, the count of rows with `build=1`, including this one, must be at most 3 (rule 8).
- **Over either cap:** remove the lock, write `stop_reason: human`, print the reason (the sums and the cap crossed), and stop. A `claude -p` lead was already summed by the conductor before launch; this re-check under the lock closes the race.
- **Row:** `$DELIVERY_ROOT/machine/<SESSION>.row`, holding one line `session=<SESSION> pid=<lead-pid> live_count=<n> build=<0|1> utc=<ISO>`. Here `build=1` only in `MODE=build`, and `live_count` = this session's `.row` count + `sum(reserved)` + 1 for the lead itself (the real value; the 31 above is only the admission sum). It is written atomically (temp file plus `mv`) and then the lock is removed.
- **Every tick:** rewrite `live_count` and `utc` atomically. The lead never deletes its row. After it exits, the reaper renames it `.dead`.
- **ORCHESTRATOR-CHECK:** `CLAUDE_CODE_MAX_CONCURRENT_SUBAGENTS` must be at least 30 in the lead's env. An `agent-tool` lead is not started by the launcher, which asserts this only for `claude -p` (PC-W2-2).

## Lane leases (C1.1, A.5)

- Before each invocation, read the invocation's wave file(s) under `<PLANS_DIR>/subtasks/<subtask>/waves/` and lease every `lane/<name>` that any work_item names, skipping a lane whose latest catalog `lane-lease` row is `live` with `owner_agent` = this `SESSION` (a lease an earlier pass of this lead kept; proposed CV35):
  ```
  catalog.sh register lane-lease lane/<name> <unit> <ticket> delivery-run <subtask> <SESSION>
  ```
  For `lane-lease`, `register` writes `live` directly. Exit 3 means the lane is held, for example by another sub-task's lead on a shared lane: never touch the holder's lease, release the leases this pass already took (so two leads cannot each hold a lane the other needs), make no call, and let the tick's pending-dispatch step retry (proposed CV21). An invocation never starts with a lane unleased.
- Release a lease (`catalog.sh release lane-lease lane/<name>`) after the last work_item of that lane in the invocation has had its C2 record accepted, or after the work_item escalated. When the controller task returns, or after its `TaskStop` (once the CV24 order has freed the rows), release every lease the invocation took that is still `live`, so a `ROLLED` unit, a checkpoint-passed unit or a no-op invocation never keeps one into the next pass (proposed CV35). Inside the run, one live work_item per lane is the controller's rule (ADR 0054 A3; barrier-wave release on gate pass or escalate, AM-4 9).
- **`gate-runner/<n>` leases** (`n` in `1..gates.runner_slots`) are taken by each gate runner itself (A.7 preconditions). The lead releases a dead holder's lease: after a `TaskStop`, its orphan sweep writes the `released` row (AM-4 13 / 20 Q9); at resume, step 3a does it (`resume.md`).
- **Unit gates** are not the gate runner's: a unit posts its record, and the engine's per-work_item gate agent runs the gate command and writes `GATE-PASS` for that head (AM-4 13). The lead never requests a gate runner for a unit.

## Red flags

| Thought | Reality |
|---|---|
| "One slot is free somewhere, dispatch now and write the row after." | The row comes first for every lead-dispatched agent. A spawn without a free slot is S4. |
| "The controller is only a coordinator, it needs no row." | It is a live subagent: `wave-controller` row before its call (Q1). |
| "Pass `max_concurrent: 30`." | It is the free-slot formula, recomputed per invocation (C1.1, E12). |
| "Reserve 4 slots for the gate agents." | Gate and fix agents count toward `max_concurrent`; there are no reservation rows (A.4). |
| "The post says PASS, free the slot." | Only after head verification and the load-bearing command (`verdicts.md`). |
| "Near the cap, squeeze one more spawn." | At `cap - 5`, hand over (`spawn-cap`, lock removed, exit). |
