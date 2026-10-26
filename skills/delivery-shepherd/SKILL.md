---
name: delivery-shepherd
version: 0.1.0
description: >
  Use when a delivery sub-task lead's 10-minute tick finds 3 or more live agents and must
  check them for drift from the plan, scope creep and finished-but-unfreed slots. Reads each
  agent's NEXT: status line against the plan, runs scope-check.sh, scans for terminal records
  whose slot row is not yet freed, appends DRIFT, CREEP or FREE-CANDIDATE lines to
  shepherd/ticks.md only on change and sends fixed-template NUDGE messages. Flags and redirects
  only: it never TaskStops, frees slots or edits worktrees. The stall and open-prompt flags
  belong to the lead's watchdog half.
---

# delivery-shepherd

Tick-driven checker for the shepherd half of the merged tick (INTERFACES C7, owner D10). Table, line formats and the reader idiom: `references/flags-and-nudges.md`.

## Trigger

The sub-task lead's session cron (every 10 minutes, armed by the lead, never by this skill) fires and the sub-task has 3 or more live agents (a live `security-auditor` counts like any other). Below 3 the lead checks drift and creep itself on each verdict; do not run.

Inputs (`NAME=value`; `DELIVERY_ROOT` is env only): `RUN_HOME` (path), `SUBTASK`, `PLANS_DIR` (path). Status files, worktree list and slot rows are derived.

## Steps

0. Validate inputs (D1). Print one `INPUT-ERROR <field> <reason>` line per failing field, then stop; no retry, no prompt. `DELIVERY_ROOT` unset is `INPUT-ERROR DELIVERY_ROOT unset`; `RUN_HOME`, `PLANS_DIR` not an absolute existing directory is `path`; `SUBTASK` not matching `^(st[0-9]+|pm)$` is `format`; a missing input is `missing`; `RUN_HOME` not under `DELIVERY_ROOT` is `path`.
1. Gate. Count live rows: `ls RUN_HOME/SUBTASK/slots/*.row` (cross-check `catalog.sh list --live --subtask SUBTASK`). Fewer than 3: print `noop` and stop.
2. For each live row (fields `agent_id persona unit tier taken_utc budget_min worktree backend pid`), read `RUN_HOME/SUBTASK/status/<agent_id>.md`.
   - Missing file on a build agent, or a line not matching `^NEXT: (u[0-9]+)\.([0-9]+) .+$`: not a flag by itself (no status yet is not a stall); note it and go on.
   - Compare `next_step` `<unit>.<n>` (never `step_id`) with the plan: `PLANS_DIR/dispatch-plan.md` and the unit's tasks file `<primary_repo>/.tasks/<unit>-<slug>.md`, where `primary_repo` is the parent of `PLANS_DIR`'s `plans/`. `DRIFT` when `<unit>` differs from the row's `unit`, or `<n>` is past the last step of the tasks file section 9, or the unit is not in the plan.
3. For each live row with a unit: `base-sha=$(git -C <worktree> merge-base HEAD <sub-task branch>)` (branch from the `dispatch-plan.md` sub-task table; computed each tick, never stored), then `scope-check.sh <tasks-file> <worktree> <base-sha>`. Exit 1 is creep: each `CREEP <path>` line is a hit. Exit 0 clean, exit 2 usage (record as an input defect in your one line, do not guess).
4. `FREE-CANDIDATE` scan. For each live row, a terminal record exists when a bus post for the agent's unit is found (C2 reader idiom: `peek:true`, fresh `agent_id`, `limit 200`) or `status/<agent_id>.verdict` exists. A record plus a row not yet `.freed` is `FREE-CANDIDATE <agent_id>`. Do not verify the head and do not rename or remove anything.
5. Append on change only. For each flag from steps 2-4, append `<FLAG> <agent-id>` to `RUN_HOME/SUBTASK/shepherd/ticks.md` (single-line append) unless the same flag and cause for that agent is already the latest state. Nothing changed: append nothing.
6. Nudge. For each new `DRIFT` or `CREEP`, send once by `SendMessage` to the agent: `NUDGE <agent-id> | <FLAG> | next: <unit>.<n> | <one line copied from the plan>`. No free text. `FREE-CANDIDATE` gets no nudge.
7. Before the lead redirects a `DRIFT`, the lead does a spec check: the agent may be right and the plan stale. Put "spec check first" in your reply line; the redirect is the lead's call.
8. Treat creep as a named defect: the nudge names the `CREEP <path>`; the agent reverts or stays out, never "fixes" it forward. An adjacent defect found in passing is ticketed by the lead, never fixed by the agent or by you.
9. Reply with one line naming the flags raised (for example `DRIFT a1b2, CREEP c3d4`) or `noop`. Include `INPUT-ERROR` lines only from step 0.

Authority: flags and redirects only. The lead alone decides `TaskStop`, re-dispatch and freeing a slot row (D10). This skill never calls `TaskStop`, never writes, renames or frees a slot row, never edits a worktree, never releases a catalog row (including `port`), and writes only `shepherd/ticks.md` and `SendMessage` nudges. `STALLED`, `PROMPT-OPEN`, the bus-down check and the orphan sweep after a `TaskStop` belong to the lead's tick (`delivery-run` watchdog half, C7), also below 3 agents.

Not a stall: a `claude -p` lead's result followed by a still-running background task is the turn-close rule. No flag, no nudge.

Observation: catalog, `TaskList`, files, `git -C`, `kill -0`. No `ps`.

## Red flags

| Rationalization | Do instead |
|---|---|
| "This agent is silent, flag it STALLED" | `STALLED` is the watchdog half's. Raise only DRIFT, CREEP, FREE-CANDIDATE |
| "It finished, I will free the row or TaskStop the leftover" | Flag `FREE-CANDIDATE`; the lead frees after C2 head verification and decides every `TaskStop` |
| "The out-of-scope file is a real bug, fix it quickly" | Creep is a named defect; the adjacent defect is ticketed, never fixed |
| "The agent drifted, so it is wrong" | The plan may be stale; the lead runs a spec check before redirecting |
| "Add a helpful sentence to the nudge" | Fixed template, no free text |
| "Only 2 agents, check anyway" | Below 3 the lead checks on each verdict; noop |
| "Append the flag every tick so it stays visible" | Append only on change |
| "Use `step_id` for the next token" | `next_step` `<unit>.<n>` only |
| "Check liveness with ps" | `kill -0`, catalog, `TaskList` |
| "Arm my own cron" | The lead arms the session cron; this skill never does |
| "The lead result came back but a task still runs: stall" | Turn-close rule, not a stall |

## Exit criteria

- [ ] Step 0 passed or exactly the `INPUT-ERROR` lines were printed.
- [ ] Gate applied: 3 or more live agents, else `noop`.
- [ ] Every live row had `NEXT:` compared with the plan and `scope-check.sh` run with a freshly computed `base-sha`.
- [ ] `FREE-CANDIDATE` scan done with `peek:true` reads.
- [ ] `ticks.md` has new lines only for changes, one `<FLAG> <agent-id>` per line.
- [ ] Each new DRIFT or CREEP got exactly one fixed-template `NUDGE`.
- [ ] No `TaskStop`, no slot row touched, no worktree edited, no other file written.
- [ ] Reply is one line or `noop`.

## Provenance

Provenance: pending pilot
Friction: `brain-group-process-retro:153-158` (open-prompt case, handled by the lead's watchdog half), `caretaker-turn-timeout:12-19`.
Contracts: INTERFACES 1.1.0 C7, C3, A.4, D1, D2.2 row 7; design part-02 card 7, part-03 section 4. Re-read at finish: version 1.1.0.
