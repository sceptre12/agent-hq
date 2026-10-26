---
name: delivery-shepherd
version: 0.1.0
description: >
  Use when a delivery sub-task lead's 10-minute tick finds 3 or more live agents and must
  check them for drift from the plan, scope creep, stalls, open prompts and finished-but-unfreed
  slots. Reads each agent's NEXT: status line against the plan, runs scope-check.sh, checks
  budget_min and pending tool calls, scans for terminal records whose slot row is not yet freed,
  appends DRIFT, CREEP, STALLED, PROMPT-OPEN or FREE-CANDIDATE lines to shepherd/ticks.md only
  on change and sends fixed-template NUDGE messages. Flags and redirects only: it never
  TaskStops, frees slots or edits worktrees; the lead decides TaskStop.
---

# delivery-shepherd

Tick-driven checker for the shepherd half of the merged tick (INTERFACES C7, owner D10). Table, line formats, the expected-step rule and the reader idiom: `references/flags-and-nudges.md`.

## Trigger

The sub-task lead's session cron (every 10 minutes, armed by the lead, never by this skill) fires and the sub-task has 3 or more live agents (a live `security-auditor` counts like any other). Below 3 the lead checks drift and creep itself on each verdict; do not run.

Inputs (`NAME=value`; `DELIVERY_ROOT` is env only): `RUN_HOME` (path), `SUBTASK`, `PLANS_DIR` (path). Status files, worktree list and slot rows are derived.

## Steps

0. Validate inputs (D1). Print one `INPUT-ERROR <field> <reason>` line per failing field, then stop; no retry, no prompt. `DELIVERY_ROOT` unset is `INPUT-ERROR DELIVERY_ROOT unset`; `RUN_HOME`, `PLANS_DIR` not an absolute existing directory is `path`; `SUBTASK` not matching `^(st[0-9]+|pm)$` is `format`; a missing input is `missing`; `RUN_HOME` not under `DELIVERY_ROOT` is `path`.
1. Gate. Count live rows: the `.row` files in `RUN_HOME/SUBTASK/slots/` (A.4 `live_rows`; the `.row` count governs, the catalog is not a tie-break). Fewer than 3: reply `noop` and stop.
2. Resolve the plan per live row (fields `agent_id persona unit tier taken_utc budget_min worktree backend pid`, A.4). `primary_repo` is the parent of `PLANS_DIR`'s `plans/`.
   - Row `unit` is `-` (gate runner, `security-auditor`, `wave-controller`) or `i<N>` (Integrator): no `DRIFT` and no `CREEP` check (C7 flag discipline, AM-4 23). Steps 5 and 6 still apply.
   - Row `unit` is `u<N>`: the tasks file is the single match of `<primary_repo>/.tasks/<unit>-*.md` (A.1 slug). Zero or several matches, or a `## 9` section with no step (K = 0): skip steps 3 and 4 for that agent and report `unchecked <agent_id> tasks-file`.
   - Steps of the unit (this skill's reading of C3 "step number in §9 verification commands"): inside the tasks file section from the heading `## 9` to the next `## `, each non-blank line of a fenced code block that does not start with `#` is one step, numbered 1 to K in order.
3. `DRIFT` check, only for each `u<N>` row whose tasks file resolved in step 2 (this skill's reading of C7 "`NEXT:` does not match the plan"). Read `RUN_HOME/SUBTASK/status/<agent_id>.md`.
   - Missing file: no flag (no status yet is not a stall), nothing reported. A file whose line fails `^NEXT: (u[0-9]+)\.([0-9]+) .+$`: no flag, report `unchecked <agent_id> next-format`.
   - `DRIFT <agent_id>` when the `NEXT:` unit differs from the row's `unit`, or its `<n>` is greater than K, or the row's `unit` has no row in the `dispatch-plan.md` unit table.
   - Not `DRIFT`: `<n>` = 0 (before the first step), `<n>` lower than on an earlier tick (re-running a step after a fix is normal), the free text after `<unit>.<n>`, and order between agents.
   - Compare `next_step` `<unit>.<n>` only, never `step_id`.
4. `CREEP` check, for each `u<N>` row with a resolved tasks file: `base-sha=$(git -C <worktree> merge-base HEAD <sub-task branch>)` (`<sub-task branch>` is the `branch` cell of the `dispatch-plan.md` sub-task table row for `SUBTASK`, A.6 dispatch-plan additions; computed each tick, never stored), then `scope-check.sh <tasks-file> <worktree> <base-sha>`. Exit 1: `CREEP <agent_id>` (the `CREEP <path>` lines are the evidence; this skill does not store them, the lead re-runs the same command to name them). Exit 0: clean. Exit 2 (usage): no flag, do not guess, report `unchecked <agent_id> scope-check-usage`.
5. Stall scan (INTERFACES 1.5.0 C7, AM-3, owner OQ-3; alongside the lead's watchdog half). For each live row with no terminal record (step 6's test): `STALLED <agent_id>` when now minus `taken_utc` is past `budget_min` with no result; `PROMPT-OPEN <agent_id>` when the agent has a pending tool call with no result: its `TaskList` output file ends in a tool call with no result and is unchanged since the previous tick (C8 CV17; a pending advisory port-hook `ask` is this case). Apply "Not a stall" below first.
6. `FREE-CANDIDATE` scan (C7: the shepherd reads this evidence from the files and the bus with the C2 reader idiom; C2 and D4 name the lead as the reader that acts on records, this skill only peeks and acts on nothing). A terminal record exists for a live row when either:
   - `RUN_HOME/SUBTASK/status/<agent_id>.verdict` exists (C4; the stem is the row's `agent_id`; any other `.verdict` stem is the lead's to log and is ignored here); or
   - the bus holds one: read `RUN_HOME/SUBTASK/bus.endpoint` (D5) and take `session_id=` and `topic=` from it, never composed (the topic is the D4 rendezvous topic); call `read_messages` (skill `swarm-communication`, `references/tools.md`) with `session_id`, `topics: [<topic>]`, `peek: true`, a fresh `agent_id` per call and `limit: 200`, paging with `since` as the reference says; a post counts when its `from_agent` equals the row's `agent_id` and it is a C2 unit record or a gate verdict (C2 records (a), (b); this skill's reading of "for the agent").
   - Bus endpoint missing, its `pid` failing `kill -0`, or the read failing: use the `.verdict` files only this tick; the bus-down check is the lead's (C7).
   - A record plus a live `.row` is `FREE-CANDIDATE <agent_id>`. The flag is advisory: the lead verifies per agent under C2 (head check) before freeing. Do not verify the head and do not rename or remove anything.
7. Append on change only (scheme in the reference). For each flag from steps 3-6, append `<FLAG> <agent_id>` to `RUN_HOME/SUBTASK/shepherd/ticks.md` (single-line append) unless that exact line is already in the file, from either half. Nothing new: append nothing. A flag that clears and later recurs for the same agent is not appended or nudged again (C7 flag discipline, AM-4 23; detail in the reference).
8. Nudge, `u<N>` rows only, by `SendMessage` to the agent: every flag (`DRIFT`, `CREEP`, `STALLED`, `PROMPT-OPEN`) is nudged exactly once, on the tick step 7 appends its line. A line already in `ticks.md` (written by either half) means no nudge from this skill. Exactly one nudge per flag, sent by whichever side writes the flag line (C7 flag discipline, AM-4 23). Template: `NUDGE <agent-id> | <FLAG> | next: <unit>.<n> | <one line copied from the plan>`, with `<unit>.<n>` and the plan line from the reference's expected-step rule. No free text, no extra field. `FREE-CANDIDATE` gets no nudge; a `-` or `i<N>` row gets the flag line only (the template needs a `u` unit). Constraints the nudge carries no text for:
   - `DRIFT`: the nudge is a redirect hint. The agent may be right and the plan stale, so before any redirect the lead runs a spec check (C7 lead action); the redirect is the lead's call.
   - `CREEP`: a named defect. The agent reverts the out-of-scope change or stays out, never "fixes" it forward. An adjacent defect found in passing is ticketed by the lead, never fixed by the agent or by this skill.
   - `STALLED`, `PROMPT-OPEN`: the nudge is not the lead action. For `STALLED` the lead decides `TaskStop` (for an engine-dispatched agent its target is the controller task, C8 CV13) and re-dispatch one tier up or escalation (never one more budget); for `PROMPT-OPEN` the lead answers it or stops the agent.
9. Reply with one line; it is this skill's channel to the lead (D10 "escalate to the sub-task lead"; ticks.md is the record). Format (skill-local, not an INTERFACES token): the flags appended this tick as `<FLAG> <agent-id>` joined by `, `, then any `unchecked <agent-id> <reason>` items (reasons `tasks-file`, `next-format`, `scope-check-usage`) joined the same way; nothing to report is `noop`. `INPUT-ERROR` lines come only from step 0.

Authority: flags and redirects only. The lead alone decides `TaskStop`, re-dispatch and freeing a slot row (D10). This skill never calls `TaskStop`, never writes, renames or frees a slot row, never edits a worktree, never releases a catalog row (including `port`), and writes only `shepherd/ticks.md` and `SendMessage` nudges. `STALLED` and `PROMPT-OPEN` are raised both here and by the lead's tick (`delivery-run` watchdog half, which also runs below 3 agents); two flags for one agent collapse to one lead action. The bus-down check and the orphan sweep after a `TaskStop` belong to the lead's tick (C7).

Not a stall: a `claude -p` lead's result followed by a still-running background task is the turn-close rule. No flag, no nudge.

Observation: catalog, `TaskList`, files, `git -C`, `kill -0`. No `ps`.

## Red flags

| Rationalization | Do instead |
|---|---|
| "This agent is stalled, TaskStop it" | Flag `STALLED` and nudge; the lead decides `TaskStop` and re-dispatch |
| "No status line yet, flag it STALLED" | `STALLED` needs past `budget_min` with no result; a missing status alone is not a stall |
| "It finished, I will free the row or TaskStop the leftover" | Flag `FREE-CANDIDATE`; the lead frees after C2 head verification and decides every `TaskStop` |
| "A unit record exists, so every agent on that unit is done" | Match the post's `from_agent` or the `.verdict` stem to the row's `agent_id` |
| "The out-of-scope file is a real bug, fix it quickly" | Creep is a named defect; the adjacent defect is ticketed, never fixed |
| "The agent drifted, so it is wrong" | The plan may be stale; the lead runs a spec check before redirecting |
| "Point the nudge at the agent's own unit" | `next:` uses the row's unit (expected-step rule) |
| "Add the CREEP path or a helpful sentence to the nudge" | Fixed template, no free text, no extra field |
| "Only 2 agents, check anyway" | Below 3 the lead checks on each verdict; noop |
| "Append the flag every tick so it stays visible" | Append only when the exact line is new |
| "Nudge every tick until the agent moves" | One nudge per flag, on the tick this skill appends the line; a line already present gets none |
| "Use `step_id` for the next token" | `next_step` `<unit>.<n>` only |
| "Check liveness with ps" | `kill -0`, catalog, `TaskList` |
| "Arm my own cron" | The lead arms the session cron; this skill never does |
| "The lead result came back but a task still runs: stall" | Turn-close rule, not a stall |

## Exit criteria

- [ ] Step 0 passed or exactly the `INPUT-ERROR` lines were printed.
- [ ] Gate applied on the `.row` count: 3 or more live agents, else `noop`.
- [ ] Every `u<N>` row had its tasks file resolved or reported `unchecked`, `NEXT:` compared with the plan, and `scope-check.sh` run with a freshly computed `base-sha`.
- [ ] Stall scan done: `STALLED` and `PROMPT-OPEN` raised per their C7 definitions.
- [ ] `FREE-CANDIDATE` scan done with `peek:true` reads matched by `agent_id`, or `.verdict` files only when the bus was unreachable.
- [ ] `ticks.md` got only lines not already in it, one `<FLAG> <agent-id>` per line.
- [ ] On `u<N>` rows: each `DRIFT`, `CREEP`, `STALLED` or `PROMPT-OPEN` line this skill appended this tick got exactly one fixed-template `NUDGE`; no nudge for a line already present.
- [ ] No `TaskStop`, no slot row touched, no worktree edited, no other file written.
- [ ] Reply is one line or `noop`.

## Provenance

Friction: `brain-group-process-retro:153-158` (open-prompt case, flagged here and by the lead's watchdog half), `caretaker-turn-timeout:12-19`.
Contracts: INTERFACES 1.5.0 C2, C3, C4, C7, C8 (CV13, CV17), A.1, A.4, A.6 (dispatch-plan additions), D1, D2.2 row 7, D4, D5 (AM-3, owner OQ-3: the shepherd also flags `STALLED`, `PROMPT-OPEN`; AM-4 23: peek-only reader, no `DRIFT`/`CREEP` on `i<N>` and `wave-controller` rows, one nudge per flag); design part-02 card 7, part-03 section 4; `skills/swarm-communication/references/tools.md` (`read_messages`). Re-read at finish: version 1.5.0.
Provenance: pending pilot
