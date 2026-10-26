# Template: retrospective and execution-log row (design 5.9; INTERFACES A.6, D6)

Fill-in skeletons for the stage 8 retrospective and the per-run execution-log rows. Adapted from the context-store wave retrospective and execution-log templates: five questions with counts, failure classification, new patterns, framework updates; a log row of task, wave, date, outcome, L2 gate, failure class, notes.

- **Writer / Reader:** writer the conductor (`delivery-pipeline`, stage 8). Readers: the human; the capture agent (queue under `RUN_HOME/capture/` until the Hermes port is on); future plan authors who read the "What You Inherit" and risky-value actions.
- **Plane:** RUN only. `retro.md` is `RUN_HOME/retro.md`; `execution-log.md` is `RUN_HOME/execution-log.md`. Committing either to `plans/<epic>/` is a human step after CYCLE DONE and is listed in the conductor's final status post (INTERFACES A.6, row R4-J19; errata E17). Do not write them to the repo.
- **Dates:** `YYYY-MM-DD`. Inside generated file bodies a timestamp is ISO UTC `YYYY-MM-DDTHH:MM:SSZ` (A.1).
- **Run Health targets:** the first four rows and their targets are the context-store template's Wave Health Score (`XC/_templates/retrospective.md`, design 5.9); the two stop rows are template-local.
- **Size:** a retro stays about 150 lines; link evidence instead of pasting it.
- **Read-back (INTERFACES C8, 29-24):** a different agent reads both files back and writes `RUN_HOME/capture/read-back.md`, line 1 `READ-BACK: <ok|mismatch> <path>` (D1.1, INTERFACES 1.8.0 AM-8 V16); on `mismatch` the conductor fixes `retro.md` and `execution-log.md` once and runs a fresh read-back; a second failure goes to the owner.
- **Sentinel:** a value you did not measure is written `UNMEASURED`, never estimated. `UNMEASURED` is retro-local (this file only); it is not the `FILL_IN_BEFORE_DISPATCH` pre-dispatch sentinel and no reader greps for it.

## Part A. `retro.md`

One retro per run (one wave of the delivery workflow = the run). Lists use the run's own ids: units `u<N>`, sub-tasks `st<N>`, SHAs 40-hex.

```markdown
# Retrospective: <run-id>

- **Date:** <YYYY-MM-DD>
- **Run:** <run-id> (epic <epic>)
- **Sub-tasks:** <st0, st1, ...>
- **Units:** <u01, u02, ... or count>
- **Agents dispatched:** <count from the slot-row history; UNMEASURED if not recoverable>
- **Facilitators present:** <roles>
- **Evidence:** <paths under RUN_HOME: state.md, execution-log.md, plan-check.md, review/<subtask>/>

---

## The Five Questions

### 1. How many failures were spec gaps vs. agent errors?

| Category | Count | Unit ids |
|---|---|---|
| Spec gap | | |
| Contract gap | | |
| Agent error | | |
| Scope violation | | |

**Takeaway:** <what this ratio says>

### 2. Which values drifted between documents?

| Value | Found in | Conflict | Designated authority |
|---|---|---|---|
| | | | |

**Action:** add each drifted value to `contracts/<relevant>.md` and to the risky-values list of future task specs.

### 3. What did agents recreate that already existed?

| Thing recreated | Where it already existed | Spec section to update |
|---|---|---|
| | | "What You Inherit" |

**Action:** update "What You Inherit" in future specs for this repo.

### 4. Where did agents guess instead of writing to `.decisions/`?

| Unit | What the agent guessed | Was it correct? | New Decision Gate trigger |
|---|---|---|---|
| | | | |

**Action:** add each trigger to the repo `CLAUDE.md` decision-gate rule as a human proposal (this family never writes `CLAUDE.md`).

### 5. Which consultation would have prevented each failure?

| Failure | Missed consultation | New phase-table row |
|---|---|---|
| | | |

**Action:** propose each row for the panel protocol of the repo's context store.

---

## Failure Classification Summary

| Unit | Failure | Class | Fix applied | Fix scope |
|---|---|---|---|---|
| | | Cosmetic\|Structural\|Systemic | | branch\|spec\|contract |

## New Patterns Catalogued

| Pattern id | Name | Summary |
|---|---|---|
| | | |

Cross-repo patterns go to the capture queue (`RUN_HOME/capture/`); repo-specific ones go to the repo's shared notes.

## Framework Updates Triggered

| Document | Change | Reason |
|---|---|---|
| repo `CLAUDE.md` (human edit) | | |
| `contracts/<x>.md` | | |
| `repo-profile.md` (via `delivery-intake`) | | |
| skill or template of this family | | |

## Run Health

| Metric | Target | Actual |
|---|---|---|
| First-pass gate success rate | above 80% | |
| Context sufficiency rate | above 90% | |
| Scope violation rate | below 5% | |
| New patterns catalogued | stabilizing | |
| D7 stops (review loop reached round 3) | 0 | |
| Stop-the-line rows hit | 0 | |

**Ready to increase parallelism?** yes / no, with the reason.

## Open human steps after CYCLE DONE

- [ ] commit `release-plan.md` v1, `retro.md` and `execution-log.md` to `plans/<epic>/` (human step; A.6)
- [ ] <each `kept` catalog row with its `keep_reason`>
```

### A.1 Field sources

| Retro element | Source of the count |
|---|---|
| failure class | closed set `Cosmetic`, `Structural`, `Systemic` (INTERFACES D2.1) |
| spec gap, contract gap | `UNIT-VERDICT` `reason` values `spec-gap`, `contract-gap` (part C2) |
| decision-gate guesses | `.decisions/<unit>.md` files and `escalations/<unit>.md` against units that finished without one |
| D7 stops | `substate.md` `stop_reason: d7-round3` history in `subtasks[].state: stopped` |
| stop-the-line rows | `S1`-`S8`, `G1`, `G3`-`G5`, `D23` (A.3) |
| `kept` resources | `catalog.tsv` rows with `state=kept` and `keep_reason` (A.5) |

## Part B. `execution-log.md`

Per-run history, raw data for retros. Rows are appended by the conductor at stage 8, one row per unit. A cross-run view, if the repo keeps one, is a human-maintained copy; this file never writes outside `RUN_HOME`.

```markdown
# Execution Log: <run-id>

Per-run agent history. Raw data for the retrospective.

| Unit | Sub-task | Date | Outcome | L2 gate | Failure class | Notes |
|---|---|---|---|---|---|---|
| <u-id> | <st-id> | <YYYY-MM-DD> | <PASS\|ROLLED\|ESCALATE> | <PASS\|FAIL\|-> | <Cosmetic\|Structural\|Systemic\|-> | <one line> |
```

| Column | Value |
|---|---|
| `Unit` | `^u[0-9]+$` (Integrator work_items `i<N>` are not logged as units; note them against `u<N>`) |
| `Sub-task` | `<subtask>` per A.1 |
| `Date` | `YYYY-MM-DD` of the accepted verdict |
| `Outcome` | the `UNIT-VERDICT` `verdict`: `PASS`, `ROLLED`, `ESCALATE` (part C2), final value after any re-dispatch; the earlier attempts go in `Notes` |
| `L2 gate` | the unit's gate result (`GATE-PASS` record present for the final head = `PASS`); `-` when no gate ran |
| `Failure class` | `Cosmetic`, `Structural`, `Systemic` or `-` |
| `Notes` | reason code (C2 `reason`), head sha (40-hex) of the accepted result, link to `.decisions/<unit>.md` when one exists |

Example row (shapes only):

```
| u07 | st1 | 2026-11-02 | PASS | PASS | - | head <40-hex sha>; one re-dispatch, tier-exhausted not hit |
```
