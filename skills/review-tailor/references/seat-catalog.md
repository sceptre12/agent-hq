# Seat catalog (derived from part-03 §3.4-3.5, pr-review Step 4, panel-consultation, panel-review)

No new seats. Tier column: review seats are `verify` (part-03 §3.1); the review orchestrator,
fixer and the one-way-door judgment are `design`. "Finds what the others cannot" is the reason
text that goes in the record row.

## A. Lens seats for Rung 2b (doc, plan), from part-03 §3.4-3.5
Default set (considered every time; omit only with a stated reason): `correctness-design`,
`test-adequacy`, `cold-implementer`, `fact-remeasurer`, `docs-accuracy`, `operability`, `security`.

| seat-id | Lens | Finds what the others cannot | Tier | Added by risk surface |
|---|---|---|---|---|
| `correctness-design` | correctness vs design | a claim that contradicts the design or another section | verify | default |
| `test-adequacy` | test adequacy | an acceptance criterion with no test that can fail | verify | default |
| `cold-implementer` | cold implementer | a step an agent not in the room cannot execute | verify | default |
| `fact-remeasurer` | fact re-measurer | a cited fact that no longer measures the same | verify | default |
| `docs-accuracy` | docs accuracy | wording that drifts from source or from a sibling doc | verify | default |
| `operability` | operability | a failure with no signal, owner or recovery path | verify | default |
| `security` | security | a trust boundary, secret or injection path | verify | default; always when security surface present |
| `concurrency-shared-state` | concurrency and shared state | a race, lock or ordering hazard | verify | shared state, parallel writers |
| `api-contract` | API/contract | a breaking change for a consumer | verify | public interface or schema |
| `data-migration` | data and migration | an irreversible or unordered data change | verify | schema, backfill |
| `performance` | performance | an unbounded loop, query or payload | verify | hot path, large data |
| `ux-accessibility` | UX and accessibility (UI only) | a flow or a11y gap a user hits | verify | UI surface only |
| `release-rollback` | release and rollback | no path back after a bad release | verify | deploy, version bump |
| `contract-interface` | contract/interface | a consumer-visible term defined twice | verify | contracts directory touched |
| `generator-migration` | generator/migration | a missing companion test PR (Blocking) | verify | generator output |
| `iac` | IaC | drift between declared and live infra | verify | infrastructure code |
| `pipeline-supply-chain` | pipeline/supply-chain | an unpinned install or lockfile gap | verify | CI, packaging, vendored deps |
| `release-engineering` | release engineering | a merge that deploys more than intended | verify | `merge_reach` or versioning |
| `accessibility` | accessibility | keyboard or screen-reader failure | verify | UI surface |
| `consumer-simulation` | consumer simulation (one per consumer repo, own worktree) | breakage seen only from a consumer's checkout | verify | consumer repos listed |
| `context-organizer` | context organizer (session dump, never curated files) | context that was lost between sessions | verify | long multi-session work |
| `severity-classifier` | integration-architect lens (not the `pr-review` agent id) | a finding rated at the wrong severity | verify | contested severities |

Reviewers never hunt lint or typecheck. Non-seat roles (never rows in the table): review
orchestrator (design, one per loop, D35), synthesizer (verify), fixer (design, never the
author), fix-verifier (verify, never the fixer), G48 pre-round checker (mechanical).

## B. Rung 3, code diff: the seven `pr-review` ids (fixed, D12 off)
| seat-id | Role | Finds what the others cannot | Tier |
|---|---|---|---|
| `platform-engineer` | Platform/Infra Engineer | layer ownership and credential flow errors | verify |
| `devops-engineer` | DevOps Engineer | build, CI and runtime command mechanics | verify |
| `fullstack-engineer` | Full Stack Engineer | inconsistent module use across runtimes | verify |
| `integration-architect` | Integration Architect | cross-contract and verification gaps | verify |
| `security-engineer` | Security Engineer | trust-boundary and secret exposure (mode line, see SKILL Step 7) | verify |
| `technical-writer` | Technical Writer | doc and message drift from the code | verify |
| `strategic-reviewer` | Strategic Reviewer | primary owner of the cold read; fit to intent | verify |

## C. Rung 2, simulated members (at most 9; members with standing only)
`platform-engineer`, `devops-engineer`, `fullstack-engineer`, `integration-architect`,
`context-designer`, `orchestration-architect`, `project-planner`, `frontend-engineer`,
`doc-organizer`. Reason text: each member's strongest catch from `panel-consultation`.

## D. Rung 4, `panel-review` roster (11, fixed)
`platform-engineer`, `devops-engineer`, `fullstack-engineer`, `integration-architect`,
`context-designer`, `orchestration-architect`, `project-planner`, `frontend-engineer`,
`security-engineer`, `doc-architect`, `foundations-planner`. Tier `design` on one-way doors
(part-03 line 36 persona note); role column repeats the `panel-review` role name.

## E. Rung 1 and Rung 0
Rung 1: one row, `doc-reviewer`, role `reviewer`, reason "single-artifact checklist review".
Rung 0: no rows; line 2 of the record is the blank line.
