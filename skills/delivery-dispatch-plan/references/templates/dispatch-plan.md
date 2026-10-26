# Template: `dispatch-plan.md` (Part A) and unit task spec `.tasks/<unit>-<slug>.md` (Part B)

Purpose: fill-in skeletons for the stage 3 plan and for each unit's task spec. Grammars live in INTERFACES (anchors cited per block); this file never restates them. Values not measured stay `FILL_IN_BEFORE_DISPATCH`; never invent one.

**Writer / Reader:** writer `delivery-dispatch-plan` (plan to repo `plans/<epic>/dispatch-plan.md`, unit specs to repo `.tasks/<unit>-<slug>.md`, A.6; `<slug>` the unit's ticket slug, A.1). Readers: the conductor, the sub-task leads, `scope-check.sh` (Part B `## 3` only), the Plan-checker, the human at the stage 3 information post (no gate, Rule 11).

---

## Part A: `dispatch-plan.md`

### A.0 Header
```
# Dispatch plan: <epic title>
epic: <JIRA-KEY>            run_id: <run-id>
interfaces_version: <version>@<sha256>      # copied from state.md (A.6 additions)
repos: <primary_repo>, <linked repos or ->
repo_profile: <path>@<sha>                  # a link, never a copy (D22); sha = blob id (A.2)
security_sensitive: yes|no                  # read from architecture.md header (AM-1, A.2); never decided here
date: YYYY-MM-DD
```

### A.1 Sub-task table (one PR each, D5; `st0` is the plan PR, M22)
Columns beyond the design (A.6 additions): `ticket`, `branch`, `repo`.

| id | ticket | branch | repo | PR | merge order | lead session | backend | slot plan | depends-on |
|---|---|---|---|---|---|---|---|---|---|
| st0 | `<epic key>` | `<key>-<slug>` | `<clone root>` | `-` | 1 | `lead-st0-a1` | `agent-tool\|claude-p` | `<peak>/30` | `independent` |
| st<N> | `<JIRA-KEY from tickets.tsv>` | `<key>-<slug>` (B4 `branch` regex) | `primary_repo` or `linked_profiles[].clone` (A.2.2) | `-` | `<n>` | `<session>` | `<BACKEND>` | `<peak>/30` | `st<M>` or `independent` (M19) |

- Sub-task worktree: `<worktree_base>/<run-id>-<subtask>`; unit worktree `<worktree_base>/<run-id>-<subtask>-<unit>` (A.6).
- Version bump (B3), per sub-task: affected apps under `apps/` (excluding examples and e2e): `st<N>: <app>, <app>` or `none`. Checked by `pre-pr-gate`.
- Full-audit slots (AM-1): `security-auditor` agents draw on free slots, count in the ledger, and are not plan units. The `pre-pr-gate` row `C26` runs `node skills/security-audit/validate-findings.cjs <output-dir>/findings.json` under `full` only (A.5.3).

### A.2 Persona roster with tiers
| persona (D2.1) | tier (D2.1) | brief (`Brief:` line in the work_item instruction, C1.2) |
|---|---|---|
| `<persona>` | `design\|execute\|verify\|mechanical` | `skills/delivery-run/references/briefs/<persona>.md` |

### A.3 Repo table
| repo | role | profile link | `worktree_base` |
|---|---|---|---|
| `<abs path>` | primary\|linked | `<path>@<sha>` | `<from profile>` |

### A.4 Unit table (feeds `waves/01-build.md`, C1.2; one done condition per unit)
| id (`u<N>`) | ticket | scope globs | blocked-by | persona | lane | budget_min | done token | verifier command | review path | e2e |
|---|---|---|---|---|---|---|---|---|---|---|
| `u1` | `<JIRA-KEY>` | `<glob>`, `<glob>` | `-` or `u<M>` (same wave only, C1.3 rule 15) | `<persona>` | `<lane or ->` | `FILL_IN_BEFORE_DISPATCH` (from measured medians) | `<verbatim last stdout line>` | `<command; exit 0 and last line = token>` | `<rung per D2.1>` | `new\|updated\|none` |

Rules: scope globs are the dispatch-plan copy; the authority is Part B `## 3` (C1.2). A unit with no verifier, or overlapping scopes, rejects the plan (stop rows, A.11). `done_condition` is `{"token", "command"}` (C1.2). The Integrator work_item that merges `u<N>` is `i<N>` in `02-integrate.md`.

### A.5 Shared-file owner and serial-lane table (M16, D63)
| shared file or contract | owning unit (exactly one per sub-task) | owning document of the cross-unit contract | serial lane |
|---|---|---|---|
| `<root manifest, lockfile, MF shared config, contract file>` | `u<N>` | `contracts/<file>.md` | `<lane or ->` |

Overlap or an implicit touch of a shared file rejects the plan.

### A.6 DAG and wave sketch
Text diagram. One DAG wave `01-build.md` per sub-task, plus `00-constitution.md` only when the repo has no profile, then `02-integrate.md` (C1). Frontiers are inside `01-build.md`; no numbered lane-waves.

### A.7 Lane table with per-lane resource profile
| lane | HTTP port need | HMR / devtools ports | browser pre-staged (desk `INSTALL`) | device lane (human-run) | leased by |
|---|---|---|---|---|---|
| `lane/<name>` | `yes\|no` | `<count>` | `yes\|no` | `yes\|no` | lead, per invocation (C1.1) |

Every lane, dev-server and bus port is claimed at launch per A.5.2 (`port-check.sh --claim`, then `catalog.sh register port`), never auto-picked; a collision is C2 reason `lane-unavailable`.

### A.8 Port table (PC-4; A.5.2 candidate formula)
`candidate = <base> + 10*k`; `<base>` is the profile key `ports.bus_base` (bus, review-bus) or `ports.lane_base` (lanes); either absent means `FILL_IN_BEFORE_DISPATCH`, which fails the pre-dispatch checklist. Fixed app ports keep `k = 0`. Bus rule: `st<N>` bus `k = 2N`, review bus `k = 2N + 1`; lanes by lane index.

| subtask | role (`bus\|review-bus\|lane/<name>`) | base_key (`ports.bus_base\|ports.lane_base`) | k | candidate |
|---|---|---|---|---|
| `st1` | `bus` | `ports.bus_base` | `2` | `FILL_IN_BEFORE_DISPATCH` |
| `st1` | `review-bus` | `ports.bus_base` | `3` | `FILL_IN_BEFORE_DISPATCH` |
| `st1` | `lane/<name>` | `ports.lane_base` | `<lane index>` | `FILL_IN_BEFORE_DISPATCH` |

One row per bind per sub-task. The launcher claims each candidate at launch (A.5.2); a refusal (exit 1 or 2) is reported to the lead and the candidate is never moved by +10. A candidate is never promised free; the plan runs no `port-check.sh`. A bus starts with `PORT_RANGE_START=PORT_RANGE_END=<port>` and its `$DATA_DIR/port` must equal the claim.

### A.9 Capacity and parallelism
- Per sub-task: `dispatch_budget` (C1.1: frontier wave `work_items x (1 + (fix_loop_cap + 1) x g)`, barrier waves `work_items_count + (fix_loop_cap + 1) x gate_agents`) and peak concurrency (cap 30). Machine line: sum of peaks against 200 (D4); rule 8, at most 3 builds.
- Parallelism note (computed, not estimated): `<n units on the frontier, n sub-tasks, n lanes>`.
- Throughput formula: `sub-tasks x review minutes / parallel reviews`.

### A.10 Cadence and rules
Shepherd cadence: `<ticks>`. Branching and merge order: `<from architecture.md section 5>`. Pre-PR gate rule: link `pre-pr-gate`, `GATE-PASS` per A.7 (link, do not restate `HUSKY=0`). Cleanup rule: `delivery-cleanup`, D8 and D9. Review rung table: `<unit or sub-task -> rung -> review-tailor record>`.

### A.11 Pre-dispatch checklist and stop-the-line
| # | check | result |
|---|---|---|
| 1 | no `FILL_IN_BEFORE_DISPATCH` left (budgets, ports, profile keys) | `[ ]` |
| 2 | every unit has a verifier and a done token | `[ ]` |
| 3 | scopes disjoint; shared-file owners unique | `[ ]` |
| 4 | worst-case dispatch count within 30 and the machine ledger within 200 | `[ ]` |
| 5 | `PLAN-CHECK: clean` in `RUN_HOME/plan-check.md` (D55; stop after round 3, D7) | `[ ]` |
| 6 | every task spec passes the Part B pre-flight | `[ ]` |

| stop-the-line | action |
|---|---|
| unit without verifier | stop; add one |
| overlapping scopes | stop; re-cut |
| an unmeasured claim contradicted | re-measure first |

---

## Part B: unit task spec `.tasks/<unit>-<slug>.md` (11 sections; adapted from the context-docs task-spec template)

Heading `## 3` carries the scope globs: one `- <glob>` per line under "In scope" until the next `## `; `scope-check.sh` reads only this file (C1.2). Do not add or drop a section.

```
# Task Spec: <unit> <slug>: <Title>

> Branch: `<JIRA-KEY>-<slug>`   Worktree: `<worktree_base>/<run-id>-<subtask>-<unit>`
> Brief: skills/delivery-run/references/briefs/<persona>.md

## 1. Objective
<One sentence: what this unit produces.>

## 2. Context Package
- Relevant contracts: `contracts/<file>.md`
- Relevant architecture: `plans/<epic>/architecture.md` section <n>
- Dependencies: <what must exist first; blocked-by units>

## 3. Scope
**In scope:**
- <glob>
**Out of scope:**
- <explicit list>
**Do NOT create:**
- <convention files, config or modules the agent might assume are needed>

## 4. Contracts
| Contract | Field / Value | Authority |
|---|---|---|
| `contracts/<file>.md` | <field> | <file> |

## 5. Inherited Module API
<What the runtime or shared layer already provides: import paths, APIs. Use it; do not recreate it.>

## 6. What You Inherit
| Thing | Source | Notes |
|---|---|---|
| <package or env var> | <where> | use this, do not install your own |

## 7. Known Risky Values
| Value | Correct | Wrong | Source |
|---|---|---|---|
| <value> | <exact> | <drift> | <authority contract> |

## 8. Acceptance Criteria
- [ ] <criterion verifiable by a command in section 9>

## 9. Verification Commands
```bash
# criterion 1
<exact command>
```
Done token: `<verbatim>`; verifier: `<command>` (exit 0, last stdout line equals the token).

## 10. Branch and Worktree
`<JIRA-KEY>-<slug>` from `<base>` in the unit worktree above; never the main checkout. The branch exists only after the desk read back the key (3.0).

## 11. Decision Gate Reminder
On any of these, write `.decisions/<unit>.md` (template: `skills/delivery-run/references/templates/decisions-fork.md`) and stop; do not guess:
- a value that differs between two contracts
- a dependency that does not exist yet
- an unclear scope boundary
- criteria that cannot be verified with the commands given
- anything that needs a file outside section 3
```

### Pre-flight (six checks, run before the plan is final)
1. Section 6 (inherit) is present and non-empty.
2. Section 7 (risky values) is present.
3. Section 5 (module API) is present.
4. The "Do NOT create" list is present.
5. Every acceptance criterion is verifiable with the commands in section 9.
6. Every risky value is sourced from its authority contract.
