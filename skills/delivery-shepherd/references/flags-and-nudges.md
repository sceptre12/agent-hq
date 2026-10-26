# Flags and nudges (delivery-shepherd reference)

Authority: INTERFACES 1.5.0 part C7 (flag table, nudge template, "Not a stall", "After every TaskStop", "Observation means", "Merged tick"), C2 (records, reader idiom), C3 (`NEXT:`), C4 (`.verdict`), A.4 (slot row), D4 (topic), D5 (`bus.endpoint`). This file copies the table by anchor; on any difference C7 wins. Lines marked "this skill's reading" interpret a contract; they add no INTERFACES grammar.

## Flag table (C7, with its "Raised by" column)

| Flag | Raised by | Condition | Lead action |
|---|---|---|---|
| `STALLED` | tick (watchdog half, `delivery-run`) and the shepherd (this skill; AM-3, OQ-3) | past `budget_min` with no result | `TaskStop`, re-dispatch one tier up or escalate; never one more budget |
| `PROMPT-OPEN` | tick (watchdog half, `delivery-run`) and the shepherd (this skill; AM-3, OQ-3) | a pending tool call with no result | answer it or stop the agent |
| `DRIFT` | shepherd half (this skill) | `NEXT:` does not match the plan | spec check first; redirect |
| `CREEP` | shepherd half (this skill) | `scope-check.sh` hit outside the unit's globs | a named defect, never a fix; adjacent defects ticketed |
| `FREE-CANDIDATE` | shepherd half (this skill) | a terminal record exists for the agent (bus post or `.verdict`) but its slot row is not yet `.freed` | the lead alone frees, after C2 verification |

This skill raises the three shepherd-half flags and also `STALLED` and `PROMPT-OPEN` on its own tick (INTERFACES 1.5.0 C7 authority line, AM-3, owner OQ-3), alongside the `delivery-run` watchdog half, which raises them on every tick including below 3 live agents; two flags for one agent collapse to one lead action, and the lead decides `TaskStop` (D10). The bus-down check and the orphan sweep after a `TaskStop` stay the watchdog half's. The shepherd half runs when the sub-task has 3 or more live agents (the `.row` count, A.4 `live_rows`); below that the lead checks drift and creep itself on each verdict.

A pending advisory port-hook `ask` (AM-1) can hold an agent; that is the `PROMPT-OPEN` case, flagged here and by the lead's watchdog half. The shepherd never releases a `port` catalog row (cleanup's, A.5.1).

## Which rows get which checks (C7 flag discipline, AM-4 23; A.4)

| Row `unit` (A.4 `^([ui][0-9]+\|-)$`) | `DRIFT`, `CREEP` | `STALLED`, `PROMPT-OPEN`, `FREE-CANDIDATE` | Nudge |
|---|---|---|---|
| `u<N>` | yes, when the tasks file resolves | yes | yes |
| `i<N>` (Integrator) | no (C7, AM-4 23) | yes | no: flag line only |
| `-` (gate runner, `security-auditor`, `wave-controller`) | no (C7, AM-4 23): no unit, no plan line | yes | no: flag line only |

## Plan, steps and DRIFT (this skill's reading of C3 and C7)

- `primary_repo` is the parent of `PLANS_DIR`'s `plans/`. The tasks file is the single match of `<primary_repo>/.tasks/<unit>-*.md` for the row's `unit` (`<slug>` per A.1). Zero or several matches, or K = 0 (no step in `## 9`): no `DRIFT` or `CREEP` check, reply item `unchecked <agent-id> tasks-file`.
- A step is one line of the tasks file `## 9` section (up to the next `## ` heading): each non-blank line inside a fenced code block that does not start with `#`, numbered 1 to K in order. `<n>` = 0 means before the first step (C3).
- The `DRIFT` read covers only `u<N>` rows whose tasks file resolved; an `i<N>` or `-` row's status file is not read. `DRIFT` when the `NEXT:` unit differs from the row's `unit`, or `<n>` > K, or the row's `unit` has no row in the `dispatch-plan.md` unit table.
- Not flagged: `<n>` = 0; `<n>` lower than on an earlier tick (re-running a step after a fix); the free text after `<unit>.<n>`; order between agents. A missing status file is not a flag and is not reported; a line failing the C3 regex is reply item `unchecked <agent-id> next-format`.

## Expected-step rule (the nudge's `next:` and plan line)

`<unit>` is always the row's `unit`, never the unit the agent wrote. `<n>` and the plan line:

| Case | `<n>` | Plan line copied verbatim |
|---|---|---|
| `NEXT:` unit equals the row's unit and 1 <= `<n>` <= K | the agent's `<n>` | step `<n>` of `## 9` |
| same unit, `<n>` > K | K | step K of `## 9` |
| same unit, `<n>` = 0; or `NEXT:` names another unit; or no valid `NEXT:` line (a `STALLED` or `PROMPT-OPEN` agent may have none); or K is unknown | 0 | the unit's row of the `dispatch-plan.md` unit table (the whole table line) |

`<unit>.<n>` is `next_step` (C3), never `step_id`.

## ticks.md line format and on-change scheme

File: `RUN_HOME/<subtask>/shepherd/ticks.md`. Single-line appends only (both halves append; AM-2 row 11): `printf '%s\n' "<FLAG> <agent-id>" >> ticks.md`.

- One line per flag: `<FLAG> <agent-id>`, `<FLAG>` in `DRIFT|CREEP|STALLED|PROMPT-OPEN|FREE-CANDIDATE`, `<agent-id>` matching `^[a-z0-9-]+$`.
- On change (this skill's reading of C7 "only when something changed"): append only when the exact line is not already in the file, from either half: `command grep -qxF "<FLAG> <agent-id>" ticks.md || printf ...`. The line carries no cause, so a change of cause is not tracked.
- A flag that clears and later recurs for the same agent is not appended or nudged again (C7 flag discipline: a cleared flag that returns is not re-flagged, AM-4 23). Agent ids are minted per dispatch, so a re-dispatched agent starts with no lines.
- A `STALLED` or `PROMPT-OPEN` line the watchdog half already wrote is not appended again here, and this skill sends no nudge for it. Exactly one nudge per flag, sent by whichever side writes the flag line (C7 flag discipline, AM-4 23).
- Never rewrite, truncate or delete lines. No timestamps or free text in the line.

## Nudge template

```
NUDGE <agent-id> | <FLAG> | next: <unit>.<n> | <one line copied from the plan>
```

- Sent by `SendMessage` to `<agent-id>`, `u<N>` rows only; no free text, no extra fields. Every flag (`DRIFT`, `CREEP`, `STALLED`, `PROMPT-OPEN`) is nudged exactly once, on the tick this skill appends its line; a line already present (written by either half) gets no nudge from this skill. Exactly one nudge per flag, sent by whichever side writes the flag line (C7 flag discipline, AM-4 23).
- `CREEP`: the template has no path slot. The `CREEP <path>` lines stay in `scope-check.sh` output; this skill stores none, and the lead re-runs the same command (same tasks file, worktree and fresh `base-sha`) to name them.
- `FREE-CANDIDATE` is a flag line for the lead, not a nudge: the agent is finished. A `STALLED` or `PROMPT-OPEN` nudge does not replace the lead action (C7 table).

## NEXT: line (C3)

`RUN_HOME/<subtask>/status/<agent-id>.md`, one current line `^NEXT: (u[0-9]+)\.([0-9]+) .+$`; `<n>` is the step number in the unit's section 9 commands, or `0` before the first step.

## Not a stall (C7)

A `claude -p` lead's result followed by a still-running background task is the turn-close rule, not a stall and not a flag. Do not nudge it.

## Observation means (C7)

Catalog (`catalog.sh list --live [--subtask <st>]`), `TaskList`, files, `git -C`, `kill -0`. No `ps`, no `pgrep`.

## FREE-CANDIDATE reader idiom (C2, C4, D4, D5)

C2 and D4 name the lead as the reader that acts on rendezvous records; C7 has the shepherd read the same evidence with the C2 idiom. This skill only peeks and acts on nothing.

- Files: `RUN_HOME/<subtask>/status/<agent-id>.verdict` for a live row's `agent_id` (C4). A `.verdict` whose stem matches no live row (or is absent from `dispatch/*.jsonl`) is the lead's to log and is ignored here.
- Bus: `RUN_HOME/<subtask>/bus.endpoint` (D5; keys `port=`, `data_dir=`, `pm2_app=`, `pid=`, `session_id=`, `topic=`). Take `session_id` and `topic` from the file, never composed (the topic is the D4 `-rendezvous` topic, a broadcast topic). Call per `skills/swarm-communication/references/tools.md` `read_messages`: `{agent_id: <fresh per call>, session_id: <session_id>, topics: [<topic>], peek: true, limit: 200}`. Paging: when a page returns 200 messages, call again with `since` = the `timestamp` of that page's last message; stop at a page of fewer than 200. `since` is exclusive, so a post sharing the boundary timestamp can be missed; that only delays an advisory `FREE-CANDIDATE` to the next tick (each tick re-reads from the start).
- Match (this skill's reading of "for the agent"): a post whose `from_agent` equals the row's `agent_id` and that is a C2 unit record (exactly `unit`, `verdict`, `head`, `reason`) or a gate verdict (`agent_id`, `verdict`, `rationale`). A record for the same `unit` from another agent does not count: worker, gate and fix agents can share a unit.
- Bus unreachable (no `bus.endpoint`, its `pid` failing `kill -0`, or a failed read): `.verdict` files only this tick; no flag and no reply item for the bus (the watchdog half's bus-down check covers it).
- The flag is advisory: the shepherd does not verify the head; the lead verifies per agent (C2) before renaming the row `.freed`.
