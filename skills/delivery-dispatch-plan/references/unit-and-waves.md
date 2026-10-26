# Units to `waves/`: what step 10 writes

Authority is INTERFACES `1.7.0` part C1 (`spec_root` = bundle root, AM-7 touch-up 6), C1.1 (lane release, AM-6 C-4), C1.2, C8 and part A.3, A.6 (AM-6 B-9b, B-9c), A.8. This file points at them and records only how this skill applies them; it does not restate their tables. Field names for the spec come from `skills/wave-execution/references/spec-format.md` (item 9 extends it); read that file before writing, and follow it where it is more exact than this page.

## Output paths (A.6)

| File | Where | Notes |
|---|---|---|
| `dispatch-plan.md` | `PLANS_DIR/` | template: `references/templates/dispatch-plan.md` (this skill does not write into `references/templates/`) |
| `.tasks/<unit>-<slug>.md` | primary repo root | `<slug>` is the unit's ticket slug (A.1), never `NN-slug` |
| `subtasks/<subtask>/substate.seed.md` | `PLANS_DIR/` | build-mode sub-tasks only; exactly the seed keys below |
| `subtasks/<subtask>/bundle.md` | `PLANS_DIR/` | the bundle header (bundle fields below), at the bundle root next to `waves/` (C1, AM-3 errata (c)) |
| `subtasks/<subtask>/waves/` | `PLANS_DIR/` | Option B layout of the spec format; waves numbered from 1; the `spec_root` `delivery-run` passes is the bundle root `subtasks/<subtask>/`, not `waves/` (C1, INTERFACES 1.7.0 AM-7 touch-up 6, E46) |
| `subtasks/<subtask>/constitution.md` | `PLANS_DIR/` | only when the repo has no profile yet (C1; definition below); not a wave file (C1, AM-3 errata (d)); written here at plan time, never at run time (A.8 A.6, C8, owner S4b) |
| `catalog.tsv`, `plan-check.md` | `RUN_HOME/` | the first created empty by this skill; the second written by the Plan-checker |

## Wave files per build-mode sub-task (C1)

- `01-build.md`: one DAG wave holding every unit of the sub-task, with `depends_on` edges. Successive frontiers live inside this file. Do not write numbered "lane-wave" files.
- `02-integrate.md`: the Integrator work_items `i<N>` (one per unit `u<N>`, merging serially into the sub-task branch) and the `pre-pr-gate` hand-off.
- `constitution.md` (bundle root, next to `waves/`; not a wave file, since spec-format rule 4 numbers waves from 1): only when the repo has no profile yet: `repo-profile.md` absent, or `FILL_IN_BEFORE_DISPATCH` in a required A.2.2 key (INTERFACES A.8, AM-5 17; the absent case already stops at Step 0, so in practice this is the sentinel case), the serial constitution-and-contracts agent, which the lead runs before `01-build.md` and verifies as a C2 `PASS` (C8, 28-CV19). Otherwise absent. Never `00-constitution.md`.
- Wave 0 setup (worktrees, baseline gates, lane leases) is not a wave file; `delivery-run` performs it. Do not add it.
- `st0` (`plan-pr`) and `pm` (`post-merge`) have no seed, no `waves/` and no sub-task bus (A.2 modes; `st0`'s `pre-pr-gate` review still claims a `review-bus` port, port table in `references/shared-files-and-parallelism.md` section 3); their leads initialize `substate.md` from `subtask_id`, `session_id` and `phase: seeded` only. `pm` is added by the conductor post-merge, not by this plan.

## Bundle fields (written once per build-mode sub-task, in `bundle.md` at the bundle root, the bundle header the spec format defines)

| Field | Value this skill writes |
|---|---|
| `session_id` | `<run-id>-<subtask>`, matches `^[a-z0-9-]+$` (rule 13) |
| `output_topic` | `<run-id>-<subtask>-rendezvous`, a literal, never a placeholder (rule 14) |
| `bus_endpoint` | `<run-id>/<subtask>/bus.endpoint`, `$DELIVERY_ROOT`-relative, never absolute |
| `dispatch_budget` | the rule 11 sum of the bundle (arithmetic in `references/shared-files-and-parallelism.md`) |

`max_concurrent` is not a spec field; it is a caller argument of `delivery-run` set to the free slot count at each invocation. Never write `budget`, `budget_min` or `spawns` into the spec (lead-side values, A.3, A.4).

## Unit-table column to field (C1.2 is the table; these are the application notes)

- Each unit is one `work_item` with id `u<N>`; its instruction names `.tasks/<unit>-<slug>.md`, the ticket, the budget in minutes, the review path and e2e state as brief text.
- `persona` is a token of INTERFACES D2.1. The instruction carries a line `Brief: skills/delivery-run/references/briefs/<persona>.md` (the one briefs root; this skill creates no briefs directory and copies no brief).
- `lane` is a lane name from the lane table; one live work_item per lane is the controller's rule.
- `depends_on` lists `u<M>` ids of the same wave. A unit blocked by another sub-task is not an edge: it is the sub-task ordering of the dispatch plan.
- `done_condition` is `{"token": "<last stdout line on success>", "command": "<verifier command>"}`, two non-empty one-line strings, no other key. Every work_item of a `step_complete` wave carries it (rule 9). Do not write `done_token`.
- Wave `agents` names a tier, never a model. Wave `gate_type: step_complete`. `fix_loop_cap` stays at the spec default.
- The tests the unit runs belong in the `.tasks` file section 9 and in `command`, not in free text.

## Seed keys (A.3)

One YAML document with exactly: `subtask_id`, `session_id`, `reserved`, `frontier`, `interfaces_version`, `phase: seeded`.

- `reserved: {shepherd: 1, clerk: 1, ci: 1, review: 10}`.
- `frontier`: the unit ids with no `depends_on` and a free lane.
- `interfaces_version`: copied from `state.md`, same value as the plan header.
- The lead copies the seed verbatim and never edits the copy.

## Sub-task table in the plan (A.6 additions)

Columns beyond the template's: `ticket` (the sub-task's `JIRA-KEY` from `tickets.tsv`, the epic key for `st0`), `branch` (`<key>-<slug>`), `repo` (the clone root: `primary_repo` or a `linked_profiles[].clone`). The unit-table `ticket` column is the latest `key` of the unit's slug in `tickets.tsv`, else the draft slug. The conductor never edits the unit table.

## Worked sketch (shape only; values are placeholders)

```
# bundle.md
session_id: <run-id>-st1
output_topic: <run-id>-st1-rendezvous
bus_endpoint: <run-id>/st1/bus.endpoint
dispatch_budget: <n>

# waves/01-build.md, work_item u03
## u03
persona: implementer
lane: -
depends_on: [u01]
done_condition: {"token": "U03-OK", "command": "bash scripts/verify-u03.sh"}
Brief: skills/delivery-run/references/briefs/implementer.md
instruction: Implement .tasks/u03-<slug>.md ...
```

Write real values; a sentinel in a wave file fails spec-format rule 7 and the checklist.
