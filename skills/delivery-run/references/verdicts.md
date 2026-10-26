# Verdicts: the `UNIT-VERDICT` record and lead handling

Depth for the SKILL.md invocation-loop step (C2 and C4 handling) and the tick's verdict read. Authority (INTERFACES 1.5.0): part C C2 (record, lead filter, lead table, readers), C3 (`NEXT:`), C4 (status-file fallback), C1.2 (`step_complete` verifier row), C5.3 (read order, paging), C7 (drift and creep below 3 live agents), C8 (AM-5: CV6, CV7, CV11, the `UNIT-VERDICT` filter); part D D4; spec 28 RESOLVED R-2, AM4-3; AM-4 rows 22, 23.

## Reading the topic

- The bus is the sub-task bus named in `bus.endpoint`; the topic is its `topic=` value (`<run-id>-<subtask>-rendezvous`).
- Every read uses `peek:true`, a fresh reader `agent_id` per read (e.g. `<SESSION>-read-<n>`, never a dispatched agent's id), and `limit 200`. When a page returns 200 messages, read again with the last seen message id as the cursor until a page returns fewer than 200 (C5.3). A read without `peek` would consume posts the controller must see.
- Reads happen in the cron that runs while an invocation is live, on every tick (`tick.md`), after the controller task returns, and at resume step 5 (`resume.md`).
- Readers are the lead and the shepherd (peek-only, for `FREE-CANDIDATE`, AM-4 23). The conductor never reads a sub-task bus.

## The lead filter (C2)

Act only on a post that meets all of these:

1. The post is **bare JSON**. "`UNIT-VERDICT:`" is the prose name and never a text prefix.
2. It has exactly the four keys `{"unit","verdict","head","reason"}` (no extra key).
3. `unit` matches `^[ui][0-9]+$`, `head` matches `^[0-9a-f]{40}$`, and `verdict` and `reason` satisfy the matrix below.
4. Its `from_agent` is registered in **this invocation's** `dispatch/<invocation>.jsonl` with role `worker` or `gate`, and the record's `unit` equals that line's `unit` (C8 "C2 filter and readers": the `UNIT-VERDICT` filter accepts worker and gate records only).

Per unit the lead acts on the **latest** accepted record; the `PASS` head check below compares the worktree HEAD with that record's `head`, never with an older record's.

Anything else is logged and ignored: gate verdicts `{"agent_id","verdict","rationale"}` (they fail step 2), posts from earlier invocations, other roles, and unregistered senders. The controller's step 8 final result is also logged, and its arrival is noted as the end of the invocation.

### Verdict-reason matrix (C2)

| `verdict` | allowed `reason` |
|---|---|
| `PASS` | `none` only |
| `ROLLED` | `budget`, `lane-unavailable`, `env-bug`, `merge-conflict` |
| `ESCALATE` | every other non-`none` code: `gherkin-checkpoint`, `decision-gate`, `spec-gap`, `contract-gap`, `tier-exhausted`, `fix-loop-cap-exhausted`, `arch`, `source-bug`, `human-step` (C2 `verdict` row) |

A pair outside the matrix fails filter step 3.

## Lead action per verdict (C2 lead table)

### `PASS`

1. Run `git -C <worktree> rev-parse HEAD`, where `<worktree>` is the unit worktree `<worktree_base>/<run-id>-<subtask>-<unit>` for `u<N>`; it must equal `head`. For an Integrator record `i<N>` the worktree is the sub-task worktree, whose HEAD the Integrator advances with every merge, so a batch read sees earlier records behind it: `git -C <worktree> merge-base --is-ancestor <head> HEAD` must succeed, and step 2 runs at the current HEAD (proposed CV33; the strict equality stays for `u<N>`).
2. Re-run **one load-bearing command** (M15): the work_item's `done_condition` `command` from its wave file, in that worktree at `head`, after the profile `node.prefix_cmd`. It must exit 0, and its last stdout line must equal the `done_condition` `token` exactly (C1.2).
3. Only then:
   - rename the worker's slot row `.freed` (`ledger.md`);
   - for `i<N>`, append `u<N> <head>` to `substate.md` `integrated` (the `INTEGRATED:` entry, D1.1; one record per merged unit, A.3);
   - release the unit's lane lease if it was the lane's last work_item in the invocation;
   - below 3 live agents, run the drift and creep check (below).
4. **Head mismatch** (step 1 fails: `u<N>` HEAD differs, or an `i<N>` `head` is not an ancestor): the post is incomplete. It is never accepted, the row is not freed on it, and nothing is appended. The unit is re-gated under its fix loop. The controller's `step_complete` gate reads the record and the branch at `head` (R-2), and the lead takes no action of its own on the controller. **Two consecutive mismatches on one unit** are a stop row for that unit. The lead counts them from the topic itself (two mismatching records for the unit with no accepted record between them), so the count survives a resume. On the second one, pause the unit as for `ESCALATE`, reason `human-step` (C8 CV6, owner answer O8; escalation record holding both records and the observed head), keep its dependents unreleased, and run the rest of the sub-task on.
5. If step 2 fails while the head matches, handle it like a mismatch: the post is not accepted and the unit is re-gated.

### `ROLLED`

- The unit is a failed gate on the controller side: its dependents stay unreleased (C2 controller side, ADR 0054 A5).
- Wait until the live invocation returns (one live invocation per sub-task), then run a **fresh invocation** with `tier_override <unit>=<tier>` one tier up (C1.1). The controller resumes at the unpassed items from its checkpoint. Alternatively, mark the unit blocked and escalate. The lead decides: tier-up fits a capability cause (`budget`, `merge-conflict`); blocked plus an escalation fits a cause outside the agent (`lane-unavailable`, `env-bug`).
- "One tier up" is one above the highest tier recorded for the unit in `dispatch/*.jsonl`, so it survives a `TaskStop` or a resume (C8 CV7). A drained `fix-loop-cap-exhausted` escalation for a unit the lead tiers up (Integrator `merge-conflict` included) is closed resolved-by-lead (below, proposed CV34).
- **Never a third attempt at the top tier.** The lead counts a unit's earlier attempts per tier from the `dispatch/*.jsonl` lines of that unit with `role` `worker` only (C8 CV7, narrowed to `worker` lines by owner answer O8). If two top-tier attempts are already recorded, the unit is blocked and escalated with `tier-exhausted`.
- The fixer one-MODEL-step rule (ADR 0014 T1, D2.1 `tier` row) belongs to the review loops and does not change this handling (AM4-3).

### `ESCALATE`

- Pause the unit: it is not re-dispatched, and its dependents stay unreleased. Because every invocation re-dispatches each work_item its checkpoint has not passed, no new invocation starts while an escalation is open (`handoffs-and-modes.md` "Loop end", proposed CV21).
- Write `RUN_HOME/<subtask>/escalations/<unit>.md` holding the record and, when it exists, the `.decisions/<unit>.md` path. Run-level work, which has no sub-task, uses `RUN_HOME/escalations/<unit>.md` (AM-4 22).
- Free the row (the record is from the registered agent and has been handled).
- The conductor's next status post lists open escalations. The human's answer arrives as an inbox `ANSWER` line (`control-channel.md`). A `decision-gate` record follows the `.decisions` fork flow (`handoffs-and-modes.md`).

### Escalation closure (proposed CV34)

- **Open:** a unit escalation is a file `escalations/<unit>.md` (`<unit>` `[ui][0-9]+`) that has not been renamed. Only these block a new invocation (CV21). Other names (`register`, `lane-wait`, `desk-<id>`, `cleanup`, `wave-<N>`, C8 CV9 inbox items) never block step 10; each of them that stops the lead carries its own `stop_reason`.
- **Close on `ANSWER`:** on consuming `ANSWER <run-id> <subtask> <unit> <text>` the lead appends `Resolved: <utc> <first line of the ANSWER file>` to `escalations/<unit>.md` and renames it `<unit>.md.resolved-<yyyymmddThhmmssZ>`. `decision-gate` closes only once the `.decisions` fork flow has filled its Re-dispatch instruction (`handoffs-and-modes.md`). For every other reason (`spec-gap`, `contract-gap`, `source-bug`, `arch`, `human-step`, `gherkin-checkpoint`, `tier-exhausted`, `fix-loop-cap-exhausted`, head-mismatch pause) the lead appends the CV42 pointer line naming the resolved file to the unit's `.tasks` file, and the next invocation re-dispatches the unit with the answer carried that way.
- **Resolved by the lead:** a drained `fix-loop-cap-exhausted` for a unit the lead itself tiers up (`ROLLED`) gets `Resolved: <utc> lead tier-up <tier>` and the same rename at once, so it never blocks that tier-up.

### `{SESSION_ID}-escalation` drain

On the same bus, read the topic `<session_id>-escalation` with the same idiom. For each `{halt_reason: "fix-loop-cap-exhausted", wave, work_item, iterations}` not yet drained, write `escalations/<work_item>.md` as an `ESCALATE` with reason `fix-loop-cap-exhausted`. The work_item's dependents stay unreleased (ADR 0054 A5). A work_item that already has an escalation record is not written twice. A post with no `work_item` (a barrier-wave exhaustion, W' `SKILL.md:149-151`) names no unit: write `escalations/wave-<N>.md` (record `unit` `-`, reason `fix-loop-cap-exhausted`), write `stop_reason: human`, and start no further invocation (proposed CV43).

## Status-file fallback (C4)

- **Trigger:** the agent found the bus unreachable at posting time and wrote the exact record to `status/<agent-id>.verdict`.
- **On every tick**, for each `RUN_HOME/<subtask>/status/*.verdict`:
  1. The stem must appear as an `agent_id` in `dispatch/*.jsonl`. If it does not, log the file and ignore it.
  2. Handle the record as above, filter steps 1-3 and head verification included.
  3. Relay the record to the topic, posting under the recorded `agent_id` (the stem) as `from_agent`. If the bus is still down, leave the file for the next tick.
  4. Rename the file `<agent-id>.verdict.consumed`.
- **Precedence:** a bus post for the same unit and head wins. A `.verdict` whose record differs from the bus post is logged and ignored (and still renamed `.consumed`).
- `wave-execution` never reads `.verdict` files; the relay is how the controller sees them (ADR 0054 Q7).
- **No post:** a dispatch that returns with neither a bus post nor a `.verdict` is a gate failure. The fix loop's stalled-dispatch exception verifies ground truth and posts the completion. **The lead never posts for an agent**; its only post is the C4 relay of a record the agent wrote.

## `step_complete` gate reading (R-2; C1.2 verifier row)

Every wave of a delivery bundle runs `gate_type: step_complete`. The gate agent for a work_item:

- reads **that work_item's C2 record** (the bare JSON posted under its registered `from_agent`, or the relayed `.verdict`);
- reads **the unit branch at the record's `head`** (for `i<N>`, the sub-task branch at `head`);
- runs the work_item's `done_condition` `command` there;
- passes the work_item only when `command` exits 0, its last stdout line equals `token` exactly, and the wave `exit_criteria` hold;
- fails every work_item whose C2 record is not `PASS` (C2 controller side).

In the barrier wave `02-integrate.md` the gate passes only when every gate agent passes. Per W' `frontier-mode.md`, "which output and where the command runs" is the caller's brief. The lead adds nothing at run time: the wording above reaches the gate agent through the work_item instruction and the `gate-checker` brief.

## `NEXT:` and the drift and creep check below 3 live agents (C3, C7)

At 3 or more live agents the shepherd half runs these checks (`tick.md`). Below 3, the lead runs them on each accepted verdict, for `u<N>` units only. Integrator `i<N>` and `wave-controller` rows get none (AM-4 23).

- **Drift:** read `RUN_HOME/<subtask>/status/<agent-id>.md`. Its one line must match `^NEXT: (u[0-9]+)\.([0-9]+) .+$`, where `<unit>.<n>` is `next_step` (never `step_id`) and `<n>` is the step number in `.tasks/<unit>-<slug>.md` §9, or `0` before the first step. A line that does not match the plan is `DRIFT`: run a spec check first, then redirect.
- **Creep:** run `scope-check.sh <primary_repo>/.tasks/<unit>-<slug>.md <worktree> <base-sha>`, where `base-sha` = `git -C <worktree> merge-base HEAD <sub-task branch>`, computed and never stored. Exit 1 prints `CREEP <path>` lines. Creep is a named defect and never a fix; adjacent defects are ticketed.
- A flag line and its one nudge follow the `tick.md` rules.

## Red flags

| Thought | Reality |
|---|---|
| "It says PASS on the bus, count it." | Only after `git rev-parse` equals `head` and the load-bearing command passes (M15). |
| "The agent finished but never posted, I'll post for it." | No post is a gate failure; the lead never posts for an agent (C4). |
| "Read the topic normally." | `peek:true`, a fresh reader id and `limit 200` on every read. |
| "A text line `UNIT-VERDICT: PASS` is close enough." | Bare JSON with exactly four keys, from a registered `from_agent`. |
| "ROLLED again at the top tier, give it one more go." | Never a third top-tier attempt: block and escalate `tier-exhausted`. |
| "Stop the dependents of the failed unit." | Dependents are never released, so there is nothing to stop. `TaskStop` only live agents (C1.2, E15). |
