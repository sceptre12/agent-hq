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

## 3. Port table (RESOLVED: candidate formula, not a check)

One row per bind per sub-task.

| subtask | role | base_key | k | candidate |
|---|---|---|---|---|
| `st<N>` | `bus` | `ports.bus_base` | `2N` | `<ports.bus_base> + 10*k` |
| `st<N>` | `review-bus` | `ports.bus_base` | `2N + 1` | `<ports.bus_base> + 10*k` |
| `st<N>` | `lane/<name>` (one row per port the lane binds) | `ports.lane_base` | bind index | `<ports.lane_base> + 10*k` |

- Write the computed integer in `candidate` and the integer `k` in its own column. If the profile lacks the base key, write `FILL_IN_BEFORE_DISPATCH` in the row; the checklist fails until intake supplies it.
- Lane `k` is the bind's index in this table's lane rows, counted from 0 in table order across all lanes (one bind per lane means the lane index). Lane leases are run-wide, so a lane keeps one candidate across sub-tasks and the `pm` lead reuses it.
- A serial lane whose ports are fixed in the app config keeps those ports with `k = 0`, and the row says "fixed by app config".
- The candidate is a proposal fixed before any check. The launcher claims each one per A.5.2 (`port-check.sh --claim`, then `catalog.sh register port`, launch, `catalog.sh start`); the plan runs no `port-check.sh`.
- On a refusal the launcher makes exactly one retry at candidate + 10, itself claimed with `port-check.sh --claim` before any bind (the tool never auto-picks); a bus is then pinned to the retry port (`PORT_RANGE_START=PORT_RANGE_END=<port+10>`). A second refusal stops the line: a lane ends as C2 reason `lane-unavailable`; a bus is reported to the lead. Never a second +10 (INTERFACES 1.3.0 A.5.2, C1.1, AM-3, owner OQ-2). Distinctness (below) covers the plan candidates only; the retry port is checked by the claim.
- Distinctness is checked across the whole table (checklist row 8).

## 4. Slot plan and dispatch arithmetic

Per sub-task, with `g = 1` (one gate agent per work_item under `step_complete`) and `cap` = the wave `fix_loop_cap` (spec default 3):

| Term | Formula |
|---|---|
| `01-build.md` (frontier) | `n_units * (1 + (cap + 1) * g)` |
| `02-integrate.md` (barrier, `step_complete` so gate agents = work_items) | `n_i + (cap + 1) * n_i`, `n_i` = Integrator work_items |
| `constitution.md` (barrier, when present; bundle root, not a wave file, C1) | `1 + (cap + 1) * 1` |
| `dispatch_budget` | the sum of the terms above |

Illustration only: 12 units, `cap` 3, `g` 1 gives `12 * 5 = 60` for the build wave and `12 + 4 * 12 = 60` for integration, so `dispatch_budget` 120.

Checks and statements the plan carries for each sub-task:
- (a) `dispatch_budget` against the lead's spawn stop: the lead stops dispatching at `spawns` cap minus 5 (A.3). Record the session cap by `printenv CLAUDE_CODE_MAX_SUBAGENTS_PER_SESSION` in this session; if it is unset or differs from the lead's environment, write "cap unmeasured for the lead session, verify at move" and do not claim headroom. If `dispatch_budget` plus an allowance for non-wave spawns (reviews, fixers, shepherd ticks) would pass cap minus 5, split the sub-task at a wave boundary.
- (b) Peak concurrency: the widest frontier of `01-build.md` (units per topological level, one live work_item per lane), capped at `30 - sum(reserved)`. Reserved in build is shepherd 1, clerk 1, ci 1, so 27; each concurrent `pr-review` reserves 10 more. Peak is a count of agents live at once; a work_item has one live agent at a time (worker, then gate, then fixer).
- Machine line: list the sub-tasks planned to build concurrently (at most 3 and only with disjoint resource rows, rule 8), sum their peaks, and compare with 200. The ledger counts nested descendants whether or not the session cap does.
- Full-mode `security-auditor` agents draw on free slots at launch (A.4); 0 pre-allocated; they are counted in the slot ledger and the budget of the audit is the free slot count at launch. When `security_sensitive: yes`, each sub-task lists the `pre-pr-gate` row `C26`. The audit is not a unit and has no wave.
- A capacity shortfall is an ask to the owner, never a silent cut (rule 9).
- Build duration inputs come from `durations.*` in the profile (measured medians); write "unmeasured" where the profile has none.

## 5. The computed Rule 7 note

State numbers derived from the DAG and the owner table, with the command or table each came from:
- units, sub-tasks, `st0` included;
- widest frontier (peak) and critical-path length in units (longest `depends_on` chain);
- units serialized by shared-file owners or lanes, listed;
- unit pairs that run in parallel and whose expanded globs were intersected, with the count of empty intersections;
- throughput: `sub-tasks * review minutes / parallel reviews` using `durations.pr_review_min`.

A split is safe only with no shared mutable state (Rule 7). Any pair whose intersection is non-empty and has no owner contradicts the note and rejects the plan; recompute the note after every fix.
