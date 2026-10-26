# Flags and nudges (delivery-shepherd reference)

Authority: INTERFACES 1.3.0 part C7 (flag table, nudge template, "Not a stall", "After every TaskStop", "Observation means", "Merged tick"), C3 (`NEXT:`), A.4 (slot row). This file copies the table by anchor; on any difference C7 wins.

## Flag table (C7, with its "Raised by" column)

| Flag | Raised by | Condition | Lead action |
|---|---|---|---|
| `STALLED` | tick (watchdog half, `delivery-run`) and the shepherd (this skill; AM-3, OQ-3) | past `budget_min` with no result | `TaskStop`, re-dispatch one tier up or escalate; never one more budget |
| `PROMPT-OPEN` | tick (watchdog half, `delivery-run`) and the shepherd (this skill; AM-3, OQ-3) | a pending tool call with no result | answer it or stop the agent |
| `DRIFT` | shepherd half (this skill) | `NEXT:` does not match the plan | spec check first; redirect |
| `CREEP` | shepherd half (this skill) | `scope-check.sh` hit outside the unit's globs | a named defect, never a fix; adjacent defects ticketed |
| `FREE-CANDIDATE` | shepherd half (this skill) | a terminal record exists for the agent (bus post or `.verdict`) but its slot row is not yet `.freed` | the lead alone frees, after C2 verification |

This skill raises the three shepherd-half flags and also `STALLED` and `PROMPT-OPEN` on its own tick (INTERFACES 1.3.0 C7 authority line, AM-3, owner OQ-3), alongside the `delivery-run` watchdog half, which raises them on every tick including below 3 live agents; two flags for one agent collapse to one lead action, and the lead decides `TaskStop` (D10). The bus-down check and the orphan sweep after a `TaskStop` stay the watchdog half's. The shepherd half runs when the sub-task has 3 or more live agents; below that the lead checks drift and creep itself on each verdict.

A pending advisory port-hook `ask` (AM-1) can hold an agent; that is the `PROMPT-OPEN` case, flagged here and by the lead's watchdog half. The shepherd never releases a `port` catalog row (cleanup's, A.5.1).

## ticks.md line format

File: `RUN_HOME/<subtask>/shepherd/ticks.md`. Single-line appends only (both halves append; AM-2 row 11): `printf '%s\n' "<FLAG> <agent-id>" >> ticks.md`.

- One line per flag: `<FLAG> <agent-id>`, `<FLAG>` in `DRIFT|CREEP|STALLED|PROMPT-OPEN|FREE-CANDIDATE`, `<agent-id>` matching `^[a-z0-9-]+$`.
- Append only when the (flag, agent) pair is not already the latest state: before appending, `command grep -qxF "<FLAG> <agent-id>" ticks.md` and skip when found and the cause is unchanged. For `DRIFT` and `CREEP`, a changed cause (different `next_step`, different `CREEP <path>` set) counts as a change and is appended again.
- Never rewrite, truncate or delete lines. No timestamps or free text in the line.

## Nudge template

```
NUDGE <agent-id> | <FLAG> | next: <unit>.<n> | <one line copied from the plan>
```

- Sent by `SendMessage` to `<agent-id>`; one message per flag; no free text, no extra fields.
- `<unit>.<n>` is `next_step` (C3, `^(u[0-9]+)\.([0-9]+)$` part of the `NEXT:` regex), the step the plan expects next, never `step_id`.
- The last field is one line copied verbatim from the plan: the unit's step line in `<primary_repo>/.tasks/<unit>-<slug>.md` section 9, else the unit's row in `dispatch-plan.md`.
- Nudges go for `DRIFT`, `CREEP`, `STALLED` and `PROMPT-OPEN`. `FREE-CANDIDATE` is a flag line for the lead, not a nudge: the agent is finished. A `STALLED` or `PROMPT-OPEN` nudge does not replace the lead action (C7 table).

## NEXT: line (C3)

`RUN_HOME/<subtask>/status/<agent-id>.md`, one current line `^NEXT: (u[0-9]+)\.([0-9]+) .+$`; `<n>` is the step number in the unit's section 9 commands, or `0` before the first step.

## Not a stall (C7)

A `claude -p` lead's result followed by a still-running background task is the turn-close rule, not a stall and not a flag. Do not nudge it.

## Observation means (C7)

Catalog (`catalog.sh list --live [--subtask <st>]`), `TaskList`, files, `git -C`, `kill -0`. No `ps`, no `pgrep`.

## FREE-CANDIDATE reader idiom (C2, C4)

Bus: `peek:true`, a fresh `agent_id` per read, `limit 200`; past 200 repeat with the last seen message id as cursor until a page returns fewer than 200. Files: `RUN_HOME/<subtask>/status/<agent-id>.verdict` (C4). A `.verdict` whose stem is absent from `dispatch/*.jsonl` is logged by the lead and ignored. A terminal record is any unit record for the agent's unit on the rendezvous topic or a `.verdict` file; the shepherd does not verify the head (the lead does, C2).
