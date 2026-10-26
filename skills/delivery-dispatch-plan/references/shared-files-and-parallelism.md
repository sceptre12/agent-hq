# Shared files, ports, slots and the Rule 7 note (steps 5, 8, 9)

Authority: `part-03` section 4 (rules 1-8d, 30 per sub-task, 200 per machine, rule 8 at most 3 concurrent builds), INTERFACES A.3, A.4, A.5.2, C1.1. Numbers below are the plan's arithmetic, not new rules.

## 1. Shared-file owner and serial-lane table (M16)

Find the candidates by measurement, not memory: `git -C <repo> ls-files` filtered for package manifests, lockfiles, barrel/index files, generated outputs, CI and pipeline config, plus every path two units' globs can both match (expand each unit's globs against `git ls-files` and intersect the sets pairwise; created-by-unit paths are compared by their glob text).

| Shared file or class | Owner unit | Serialized behind owner (units) | Why (measured) |
|---|---|---|---|
| `<path or glob>` | `u<N>` | `u<a>, u<b>` | `<cmd -> result>` |

Rules:
- One owner per file. A second unit that must change the file gets `depends_on` on the owner (same wave) or the touch is rejected from its scope.
- Same-file chains share one worktree and merge to the sub-task branch after each unit (rule: wave shape, `part-03`).
- A lockfile or manifest change is a dependency edit: the unit does not make it; the owner requests it from the desk (`INSTALL`) and the plan says so.
- Each cross-unit contract has exactly one owning document; units cite it by pin and never restate it (D63).
- Serial lanes are exclusive-writer with a catalog lease: list each lane's name, owner persona and the units that use it. Shared append-only files are replaced by per-unit map files.
- An overlap with no named owner, or a path a unit touches that its globs do not list, rejects the plan (stop row).

## 2. Lane table and resource profile

| Lane | Kind (serial, shared, device) | Ports it binds (role) | Browser | Units |
|---|---|---|---|---|
| `<name>` | serial | HTTP, HMR, devtools as needed | pre-staged by desk `INSTALL` | `u<N>...` |

Device lanes are human-run and listed as such. The table records port needs only; no value in it is promised free.

## 3. Port table (spec 17 Q4, INTERFACES A.5.2: candidate formula, not a check)

Candidates step by 20 (`<base> + 20*k`, INTERFACES 1.5.0 A.5.2 and C1.1, AM-4 W2-3), so the one +10 retry of any candidate lands on an odd ten that no candidate uses. Only `bus` and `review-bus` rows are per sub-task. Lane rows are written once per lane for the run: lane leases are run-wide, so lane rows are not repeated per sub-task.

| subtask | role | base_key | k | candidate |
|---|---|---|---|---|
| `st<N>` (build mode only) | `bus` | `ports.bus_base` | `2N` | `<ports.bus_base> + 20*k` |
| `st<N>` (every sub-task that runs `pre-pr-gate`, `st0` included) | `review-bus` | `ports.bus_base` | `2N + 1` | `<ports.bus_base> + 20*k` |
| `-` (run-wide) | `lane/<name>` (one row per port the lane binds) | `ports.lane_base` | next consecutive bind index | `<ports.lane_base> + 20*k` |

- Write the computed integer in `candidate` and the integer `k` in its own column. If the profile lacks the base key, write `FILL_IN_BEFORE_DISPATCH` in the row (A.2.2 `ports.*` row); the checklist fails until intake supplies it.
- Which sub-tasks get bus rows: a `bus` row only for a build-mode sub-task; `st0` (`plan-pr`) and `pm` (`post-merge`) run no bus (A.2 modes). `st0` gets a `review-bus` row (`k = 1`), because it opens the plan PR through `pre-pr-gate` (A.2), which passes the sub-task's `review-bus` candidate to `pr-review` as `BUS_PORT`, required when `RUN_HOME` is set (D2.3 `pr-review` row). `pm` is added by the conductor post-merge (A.2) and gets no row from this plan.
- Lane `k`: the per-bind index (INTERFACES 1.5.0 A.5.2 "lane binds by consecutive bind index"): each lane bind takes the next consecutive `k` in table order, from 0, across all lanes, so every bind keeps a distinct candidate. With one bind per lane, `k` equals the lane index. A post-merge re-entry appends new lanes' rows with `k` continuing from the last existing bind index (SKILL.md step 13). A lane keeps its candidates across sub-tasks and the `pm` lead reuses them.
- A serial lane whose ports are fixed in the app config writes the app port as `candidate`, `k` = `-`, with the note "fixed by app config" (fixed app ports keep their app port, W2-3); it takes no index and is outside the formula, but it and its + 10 are included in the distinctness check (checklist row 8), so a fixed port equal to a formula candidate or a retry slot is caught.
- The candidate is a proposal fixed before any check. The launcher claims each one per A.5.2 (`port-check.sh --claim`, then `catalog.sh register port`, launch, `catalog.sh start`); the plan runs no `port-check.sh`.
- On a refusal the launcher makes exactly one retry at candidate + 10, itself claimed with `port-check.sh --claim` before any bind (the tool never auto-picks); a bus is then pinned to the retry port (`PORT_RANGE_START=<port+10> PORT_RANGE_END=<port+10>`, INTERFACES 1.5.0 A.5.2, AM-4 18). A second refusal stops the line: a lane ends as C2 reason `lane-unavailable`; a bus is reported to the lead. Never a second +10 (INTERFACES 1.5.0 A.5.2, C1.1, AM-3, owner OQ-2). `port-check.sh` exit 3 (registry unusable) is stop-the-line with no retry (A.5.2).
- The plan checks that all candidates and all candidates + 10, across both bases and the fixed app ports, are pairwise distinct and at most 65535 (checklist row 8). A plan-time clash stops the skill and is reported; the plan never re-picks a port.

## 4. Slot plan and dispatch arithmetic

Per build-mode sub-task, with `g = 1` (one gate agent per work_item under `step_complete`) and `fix_loop_cap` = the wave value (spec default 3):

| Term | Formula |
|---|---|
| `01-build.md` (frontier) | `n_units * (1 + (fix_loop_cap + 1) * g)` |
| `02-integrate.md` (barrier, `step_complete` so gate agents = work_items) | `n_i + (fix_loop_cap + 1) * n_i`, `n_i` = Integrator work_items |
| `constitution.md` (barrier, when present; bundle root, not a wave file, C1) | `1 + (fix_loop_cap + 1) * 1` |
| `dispatch_budget` | the sum of the terms above |

Illustration only: 12 units, `fix_loop_cap` 3, `g` 1 gives `12 * 5 = 60` for the build wave and `12 + 4 * 12 = 60` for integration, so `dispatch_budget` 120.

Checks and statements the plan carries for each sub-task:
- (a) `dispatch_budget` against the lead's spawn stop: the lead stops dispatching at `spawn_cap - 5`, `spawn_cap` being the `spawns` cap of A.3. Record `spawn_cap` by `printenv CLAUDE_CODE_MAX_SUBAGENTS_PER_SESSION` in this session; if it is unset or differs from the lead's environment, write "spawn_cap unmeasured for the lead session, verify at move" and do not claim headroom. If `dispatch_budget` plus an allowance for non-wave spawns (reviews, fixers, shepherd ticks) would pass `spawn_cap - 5`, the remedy is the spec format's: split the bundle at a wave boundary (`skills/wave-execution/references/spec-format.md` rule 11). The sub-task cut stays one PR each (D5); a shortfall the bundle split does not cure is an ask to the owner (rule 9).
- (b) Peak concurrency: the widest frontier of `01-build.md` (units per topological level, one live work_item per lane), at most `30 - sum(reserved)` (spec 17 Q3; A.4 free-slot formula with `live_rows` 0). `reserved` is the seed value (A.3 `{shepherd: 1, ci: 1, review: 10}`, sum 12, no clerk seat, INTERFACES 1.8.0 AM-8 V8), so at most 18; A.3 counts `review: 10` per concurrent `pr-review`. Peak is a count of agents live at once; a work_item has one live agent at a time (worker, then gate, then fixer).
- Machine line: list the sub-tasks planned to build concurrently (at most 3 and only with disjoint resource rows, rule 8). The ledger counts every live agent, nested descendants included, whether or not the session cap does, so each concurrently building sub-task contributes its peak plus `sum(reserved)` (A.3 seed `reserved`, A.4); sum those contributions and compare with 200.
- Full-mode `security-auditor` agents draw on free slots at launch (A.4); 0 pre-allocated; they are counted in the slot ledger and the budget of the audit is the free slot count at launch. When `security_sensitive: yes`, each sub-task lists the `pre-pr-gate` row `C26`. The audit is not a unit and has no wave.
- A capacity shortfall is an ask to the owner, never a silent cut (rule 9).
- Build duration inputs come from `durations.*` in the profile (measured medians, A.2.2); an absent `durations.*` key is `INPUT-ERROR <key> missing` at Step 0 (A.2.2), never a guessed or "unmeasured" value.

## 5. The computed Rule 7 note

State numbers derived from the DAG and the owner table, with the command or table each came from:
- units, sub-tasks, `st0` included;
- widest frontier (peak) and critical-path length in units (longest `depends_on` chain);
- units serialized by shared-file owners or lanes, listed;
- unit pairs that run in parallel and whose expanded globs were intersected, with the count of empty intersections;
- throughput: `sub-tasks * review minutes / parallel reviews` using `durations.pr_review_min`.

A split is safe only with no shared mutable state (Rule 7). Any pair whose intersection is non-empty and has no owner contradicts the note and rejects the plan; recompute the note after every fix.
