# Template: `dispatch-plan.md` (Part A) and unit task spec `.tasks/<unit>-<slug>.md` (Part B)

Local section headings of Part A are `P0`-`P12` (this template's own); every `A.x` citation is INTERFACES part A.

Purpose: fill-in skeletons for the stage 3 plan and for each unit's task spec. Grammars live in INTERFACES (anchors cited per block); this file never restates them. Values not measured stay `FILL_IN_BEFORE_DISPATCH`; never invent one.

**Writer / Reader:** writer `delivery-dispatch-plan` (plan to repo `plans/<epic>/dispatch-plan.md`, unit specs to repo `.tasks/<unit>-<slug>.md`, INTERFACES A.6; `<slug>` the unit's ticket slug, INTERFACES A.1). Readers: the conductor, the sub-task leads, `scope-check.sh` (Part B `## 3` only), the Plan-checker, the human at the stage 3 information post (no gate, Rule 11).

---

## Part A: `dispatch-plan.md`

### P0 Header
```
# Dispatch plan: <epic title>
epic: <JIRA-KEY>            run_id: <run-id>
interfaces_version: <version>@<sha256>      # copied from state.md (INTERFACES A.6 additions)
repos: <primary_repo>, <linked repos or ->
repo_profile: <path>@<sha>                  # a link, never a copy (D22); sha = blob id (INTERFACES A.2)
security_sensitive: yes|no                  # read from architecture.md header (AM-1, INTERFACES A.2); never decided here
date: YYYY-MM-DD
```

### P1 Sub-task table (one PR each, D5; `st0` is the plan PR, M22)
Columns beyond the design (INTERFACES A.6 additions): `ticket`, `branch`, `repo`. `merge order` is binding: merge predecessors are every sub-task with a lower value (`st0` first); `RELEASE` follows `depends-on` (INTERFACES A.8, 29-18).

| id | ticket | branch | repo | PR | merge order | lead session | backend | slot plan | depends-on |
|---|---|---|---|---|---|---|---|---|---|
| st0 | `<epic key>` | `<key>-<slug>` | `<clone root>` | `-` | 1 | `-` (minted by the conductor at launch, `<run-id>-<subtask>-l<n>`, INTERFACES A.8) | `agent-tool\|claude-p` | `<peak>/30` | `independent` |
| st<N> | `<JIRA-KEY from tickets.tsv>` | `<key>-<slug>` (B4 `branch` regex) | `primary_repo` or `linked_profiles[].clone` (INTERFACES A.2.2) | `-` | `<n>` | `<session>` | `<BACKEND>` | `<peak>/30` | `st<M>` or `independent` (M19) |

- Sub-task worktree: `<worktree_base>/<run-id>-<subtask>`; unit worktree `<worktree_base>/<run-id>-<subtask>-<unit>` (INTERFACES A.6).
- Version bump (B3), per sub-task: affected apps under `apps/` (excluding examples and e2e): `st<N>: <app>, <app>` or `none`. Checked by `pre-pr-gate`.
- Full-audit slots (AM-1): `security-auditor` agents draw on free slots, count in the ledger, and are not plan units. The `pre-pr-gate` row `C26` runs `node skills/security-audit/validate-findings.cjs <output-dir>/findings.json` under `full` only (INTERFACES A.5.3).

### P2 Persona roster with tiers
| persona (D2.1) | tier (D2.1) | brief (`Brief:` line in the work_item instruction, C1.2) |
|---|---|---|
| `<persona>` | `design\|execute\|verify\|mechanical` | `skills/delivery-run/references/briefs/<persona>.md` |

### P3 Repo table
| repo | role | profile link | `worktree_base` |
|---|---|---|---|
| `<abs path>` | primary\|linked | `<path>@<sha>` | `<from profile>` |

### P4 Unit table (feeds `waves/01-build.md`, C1.2; one done condition per unit)
| id (`u<N>`) | ticket | scope globs | blocked-by | persona | lane | budget_min | done token | verifier command | review path | e2e |
|---|---|---|---|---|---|---|---|---|---|---|
| `u1` | `<JIRA-KEY>` | `<glob>`, `<glob>` | `-` or `u<M>` (same wave only, C1.3 rule 15) | `<persona>` | `<lane or ->` | `FILL_IN_BEFORE_DISPATCH` (from measured medians) | `<verbatim last stdout line>` | `<command; exit 0 and last line = token>` | `<rung per D2.1>` | `new\|updated\|none` |

Rules: scope globs are the dispatch-plan copy; the authority is Part B `## 3` (C1.2). A unit with no verifier, or overlapping scopes, rejects the plan (stop rows, P11). `done_condition` is `{"token", "command"}` (C1.2). The Integrator work_item that merges `u<N>` is `i<N>` in `02-integrate.md`.

### P5 Shared-file owner and serial-lane table (M16; D63, design `part-06-build-plan-and-sources.md` stage 2 row)
| shared file or contract | owning unit (exactly one per sub-task) | owning document of the cross-unit contract | serial lane |
|---|---|---|---|
| `<root manifest, lockfile, MF shared config, contract file>` | `u<N>` | `contracts/<file>.md` | `<lane or ->` |

Overlap or an implicit touch of a shared file rejects the plan.

### P6 DAG and wave sketch
Text diagram. One DAG wave `01-build.md` per sub-task, then `02-integrate.md` (C1; waves numbered from 1); `constitution.md` at the bundle root, not a wave file, only when the repo has no profile, run by the lead before `01-build.md`; the bundle header is `bundle.md` at the bundle root (C1, AM-3 errata (c), (d)). Frontiers are inside `01-build.md`; no numbered lane-waves.

### P7 Lane table with per-lane resource profile
| lane | HTTP port need | HMR / devtools ports | browser pre-staged (desk `INSTALL`) | device lane (human-run) | leased by |
|---|---|---|---|---|---|
| `lane/<name>` | `yes\|no` | `<count>` | `yes\|no` | `yes\|no` | lead, per invocation (C1.1) |

Every lane, dev-server and bus port is claimed at launch per INTERFACES A.5.2 (`port-check.sh --claim`, then `catalog.sh register port`), never auto-picked; on a refusal exactly one retry at candidate + 10, claimed before bind; a second refusal stops the line and is reported to the lead; for a lane it maps to C2 reason `lane-unavailable` (INTERFACES A.5.2, AM-3, owner OQ-2).

### P8 Port table (INTERFACES A.5.2 candidate formula; one +10 retry, AM-3 OQ-2)
`candidate = <base> + 20·k` (INTERFACES 1.5.0 A.5.2, AM-4 W2-3; the one +10 retry lands on an odd ten no candidate uses); `<base>` is the profile key `ports.bus_base` (bus, review-bus) or `ports.lane_base` (lanes); either absent means `FILL_IN_BEFORE_DISPATCH`, which fails the pre-dispatch checklist. Fixed app ports keep their app port, `k` = `-`, outside the formula (W2-3). Bus rule: `st<N>` bus `k = 2N`, review bus `k = 2N + 1`; lane binds by the per-bind index, consecutive in table order from 0 across all lanes (A.5.2).

| subtask | role (`bus\|review-bus\|lane/<name>`) | base_key (`ports.bus_base\|ports.lane_base`) | k | candidate |
|---|---|---|---|---|
| `st1` | `bus` | `ports.bus_base` | `2` | `FILL_IN_BEFORE_DISPATCH` |
| `st1` | `review-bus` | `ports.bus_base` | `3` | `FILL_IN_BEFORE_DISPATCH` |
| `-` (run-wide) | `lane/<name>` | `ports.lane_base` | `<per-bind index>` | `FILL_IN_BEFORE_DISPATCH` |

One row per bind per sub-task. The launcher claims each candidate at launch (INTERFACES A.5.2); on a refusal (exit 1 or 2) the launcher makes exactly one retry at candidate + 10, claimed before bind; a second refusal stops the line and is reported to the lead (INTERFACES A.5.2, AM-3, owner OQ-2). A candidate is never promised free; the plan runs no `port-check.sh`. A bus starts with `PORT_RANGE_START=PORT_RANGE_END=<port>` (the retry port when retried, C1.1) and its `$DATA_DIR/port` must equal the claim.

### P9 Capacity and parallelism
- Per sub-task: `dispatch_budget` (C1.1: frontier wave `work_items x (1 + (fix_loop_cap + 1) x g)`, barrier waves `work_items_count + (fix_loop_cap + 1) x gate_agents`) and peak concurrency (cap 30). Machine line: sum of peaks against 200 per machine (INTERFACES A.4 machine ledger row); rule 8, at most 3 builds.
- Parallelism note (computed, not estimated): `<n units on the frontier, n sub-tasks, n lanes>`.
- Throughput formula: `sub-tasks x review minutes / parallel reviews`.

### P10 Cadence and rules
Shepherd cadence: `<ticks>`. Branching and merge order: `<from architecture.md section 5>`. Pre-PR gate rule: link `pre-pr-gate`, `GATE-PASS` per INTERFACES A.7 (link, do not restate `HUSKY=0`). Cleanup rule: `delivery-cleanup`, D8 and D9. Review rung table: `<unit or sub-task -> rung -> review-tailor record>`.

### P11 Pre-dispatch checklist and stop-the-line
The plan's checklist section: the 13 "Whole plan" rows of `skills/delivery-dispatch-plan/references/predispatch-checklist.md` (checks and how-to there, not restated) plus its per-unit pre-flight. Each result is `PASS <evidence>` or `FAIL <what>`; any `FAIL` blocks step 12.

| # | check (predispatch-checklist.md row) | result |
|---|---|---|
| 1 | No sentinel left | `[ ]` |
| 2 | Every path named in the plan exists | `[ ]` |
| 3 | Flags present | `[ ]` |
| 4 | Header complete | `[ ]` |
| 5 | Ids and tokens | `[ ]` |
| 6 | Tickets | `[ ]` |
| 7 | Scopes disjoint | `[ ]` |
| 8 | Port candidates distinct | `[ ]` |
| 9 | Budgets | `[ ]` |
| 10 | Waves valid | `[ ]` |
| 11 | Briefs exist | `[ ]` |
| 12 | Catalog | `[ ]` |
| 13 | Stop rows stated | `[ ]` |
| per unit | the six pre-flight checks and the `## 3` glob check, per `.tasks` file | `[ ]` |

| stop-the-line | action |
|---|---|
| unit without verifier | stop; add one |
| overlapping scopes | stop; re-cut |
| an unmeasured claim contradicted | re-measure first |

### P12 Plan review
The plan's review section, written by `delivery-dispatch-plan` step 12 (`references/plan-check-loop.md`) and read by the conductor before the first launch (`skills/delivery-pipeline/references/stages.md` "Review round 3").
- Plan-check: `RUN_HOME/plan-check.md` line 1 at exit (`PLAN-CHECK:`, D1.1; D55).
- Review rounds: `<round> | <rung> | <record path> | <open B/M findings>` per round (stop after round 3, owner D7).
- Open findings at stop: `<finding id, severity, one line>` or `-`.
- Stop line, only on a round-3 stop with open B/M findings: `PLAN-REVIEW: STOP round-3` (D1.1, INTERFACES 1.6.0 AM-6 (g)); absent otherwise.

---

## Part B: unit task spec `.tasks/<unit>-<slug>.md` (11 sections; adapted from the context-docs task-spec template)

Heading `## 3` carries the scope globs: one `- <glob>` per line under "In scope"; `scope-check.sh` reads only this file and takes every `- ` line from `## 3` until the next `## ` as an allowed glob (C1.2). So "Out of scope" and "Do NOT create" are numbered lines (`1. `), never `- ` lines: a `- ` line there would be read as an allowed glob. Do not add or drop a section.

```
# Task Spec: <unit> <slug>: <Title>

> Branch: `<JIRA-KEY>-<slug>`   Worktree: `<worktree_base>/<run-id>-<subtask>-<unit>`
> Brief (informational copy; the binding `Brief:` line is the one in the work_item instruction, C1.2): skills/delivery-run/references/briefs/<persona>.md

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
1. <explicit list, numbered, never a `- ` line>
**Do NOT create:**
1. <convention files, config or modules the agent might assume are needed; numbered, never a `- ` line>

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
