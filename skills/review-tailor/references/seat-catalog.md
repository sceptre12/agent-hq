# Seat catalog (derived from part-03 §3.4-3.5, pr-review Step 4, panel-consultation, panel-review)

No new seats. Tier column: review seats are `verify` (part-03 §3.1); the review orchestrator,
fixer and the one-way-door judgment are `design`. "Finds what the others cannot" is the reason
text that goes in the record row.

## A. Lens seats for Rung 2b (doc, plan), from part-03 §3.4-3.5
Default set (considered every time; omit only with a stated reason): `correctness-design`,
`test-adequacy`, `cold-implementer`, `fact-remeasurer`, `docs-accuracy`, `operability`, `security`.
This grouping is this skill's selection from the part-03 §3.4 pool (part-03 line 48), not a
part-03 term: the seven §3.4 lenses that apply to any doc or plan; the rest of §3.4 and all of
§3.5 are added by surface.

Selection rule (task spec 16 §6: seats by risk surface present, justify each omitted default,
never exceed 7 at 2b). A default seat's surface is what its "finds what the others cannot"
cell names. Test for presence: a default is present unless the artifact contains no item of
its kind (`correctness-design` a design claim, `test-adequacy` an acceptance criterion,
`cold-implementer` a step to execute, `fact-remeasurer` a cited fact, `docs-accuracy` a
restatement of a source or sibling doc, `operability` a failure mode, `security` a trust
boundary, secret or injection path); when it has none, the seat is omitted with that reason.
1. Profile-mandatory seats (`rung-rules.md` §5).
2. Defaults whose surface is present (`security` always when the security surface is present).
3. Surface seats whose surface is present, in table order.
When steps 1 and 2 alone pass the cap (mandatory seats first, task spec 16 §6 "never exceed
7"), defaults are dropped in the step 4 displacement order below and each is listed after
`omitted:` as `id=displaced by <mandatory seat>`; no surface seat is then added.
4. When step 3 would pass the cap, each further surface seat displaces one default from step 2,
   taking them in this order: `operability`, `docs-accuracy`, `fact-remeasurer`,
   `cold-implementer`, `test-adequacy`; `correctness-design`, and `security` when its surface
   is present, are never displaced. The displaced default is listed after `omitted:` as
   `id=displaced by <seat>`. When no default is left to displace, the remaining surface seats
   are not added and are named after `omitted:` with the cap as the reason.

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

Overlapping lenses (part-03 lines 48, 50): `accessibility` (§3.5) overlaps `ux-accessibility`
(§3.4), and `release-engineering` overlaps `release-rollback`; for one surface add the §3.4
seat only, unless the other's own "finds what" item is named.
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

## C. Rung 2, simulated members (3 to 9; members with standing only)
`panel-consultation` names its nine members by display name only (its member table). Ids here:
the first eight reuse the `panel-review` roster id for the same display name (`panel-review`
"The 11 roles to dispatch"); `doc-organizer` is this skill's kebab-case id for Documentation
Organizer, which has no `panel-review` id.
Platform Engineer `platform-engineer`, DevOps Engineer `devops-engineer`, Staff Full Stack
Engineer `fullstack-engineer`, Integration Architect `integration-architect`, Agent Context
Designer `context-designer`, Orchestration Architect `orchestration-architect`, Project Planner
`project-planner`, Principal Frontend Engineer `frontend-engineer`, Documentation Organizer
`doc-organizer`. Reason text: each member's "Strongest on" cell from `panel-consultation`.

Selection rule (task spec 16 §6 seats by risk surface; `panel-consultation` Step 2 "members
with standing", member table lines 41-49):
1. Profile-mandatory seats (`rung-rules.md` §5), counted against the cap.
2. Each member whose "Strongest on" or Domain cell names a risk surface the artifact has, in
   the member table order above. Surface to member, read from those cells: IaC and credentials
   `platform-engineer`; build, CI, packaging, release `devops-engineer`; API/contract
   `fullstack-engineer` and `integration-architect`; acceptance criteria and cross-contract
   values `integration-architect`; specs that agents execute `context-designer`; parallel
   work, shared state, concurrency `orchestration-architect` and `project-planner`; UI
   `frontend-engineer`; docs and durable records `doc-organizer`. `panel-consultation` Step 2
   also makes `platform-engineer` and `fullstack-engineer` required when the artifact crosses
   infrastructure and application boundaries, and `context-designer` when it holds specs
   agents will execute.
3. `panel-consultation` Step 2 guides "the 3-5 most relevant members"; this skill selects
   every member with standing, so the record can hold more than 5 up to the cap below.
   Minimum 3 (`panel-consultation` Exit criteria "at least 3 panel members with actual
   standing"): when steps 1-2 give fewer, add members in table order until there are 3. Maximum
   9 (task spec 16 §6, RESOLVED Q1); the member table has nine, so the cap cannot be passed.
4. Every member not selected is listed after `omitted:` as `id=no standing` (`rung-rules.md`
   §6).

## D. Rung 4, `panel-review` roster (11, fixed)
Rows in this order; role from `panel-review` "The 11 roles to dispatch", reason from the
`Domain:` line of `skills/panel-review/references/agent-roles.md`. Tier `verify` (part-03
§3.1; part-03 line 36 is the tailor's own tier, not a seat tier).

| seat-id | Role | Reason (finds what the others cannot) |
|---|---|---|
| `platform-engineer` | Platform Engineer | layer ownership, ENV var authority, connection patterns, path separation |
| `devops-engineer` | DevOps Engineer | Dockerfiles, build commands, CI/CD, runtime quirks |
| `fullstack-engineer` | Staff Full Stack Engineer | module consumption, import paths, API surfaces, cross-runtime symmetry |
| `integration-architect` | Integration Architect | cross-contract consistency, authority conflicts, cross-wave impact, cross-skill message flow |
| `context-designer` | Agent Context Designer | spec executability, agent translation quality, context blindness |
| `orchestration-architect` | Orchestration Architect | parallel execution safety, worktree isolation, dispatch sequencing |
| `project-planner` | Project Planner | wave decomposition, task dependency graphs, milestone sequencing |
| `frontend-engineer` | Principal Frontend Engineer | UI components, HMR/WebSocket routing, API contract consumption |
| `security-engineer` | Security Engineer | credential handling, injection risks, token scoping, blast radius; ends `mode=<SECURITY_AUDIT value>` (SKILL Step 7) |
| `doc-architect` | Documentation Architect | document clarity, completeness, unfilled placeholders, structural coherence |
| `foundations-planner` | Foundations Technical Planner | strategic alignment, roadmap coherence, LOE accuracy |

## E. Rung 1 and Rung 0
Rung 1: one row, `doc-reviewer`, role `reviewer`, reason "single-artifact checklist review".
Rung 0: no rows; line 2 of the record is the blank line.
