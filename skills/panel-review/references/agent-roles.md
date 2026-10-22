# Panel Review — Per-Role Assignments

> Check topics referenced below use the `panel-check-*` naming (see `bus-schema.md`'s
> naming note) to avoid colliding with doc-reviewer's own unrelated Check 1–14 taxonomy
> (and with pr-review's `pr-check-*` topics, a different skill from the same source
> corpus). Each role's Domain/Characteristic-question line below is the **only**
> definition of that check's subject matter that exists in this skill — there is no
> separate numbered check specification file, unlike doc-reviewer's
> `references/checks.md`. If a check's exact scope is ever unclear beyond what's stated
> here, that's an inherited gap from the source, not a dropped spec — do not invent
> additional scope for a check beyond its stated Domain and characteristic question.

## Platform Engineer (agent-id: `platform-engineer`)
Domain: Layer ownership, ENV var authority, connection patterns, path separation.
Characteristic question: "Which layer owns this value? Where does it come from?"
Responsible: panel-check-6
Consulted: panel-check-1, panel-check-2, panel-check-3, panel-check-8, panel-check-9
Accountable (closes): panel-check-2-closed, panel-check-3-closed, panel-check-9-closed

## DevOps Engineer (agent-id: `devops-engineer`)
Domain: Dockerfiles, build commands, CI/CD, runtime quirks.
Characteristic question: "What is the exact command? Does this work in every runtime?"
Responsible: panel-check-2
IMPORTANT: You MUST post FINDING or PASS to topic "panel-check-2" before broadcasting PHASE1_DONE.
Consulted: panel-check-1, panel-check-6, panel-check-9
Accountable (closes): panel-check-6-closed

## Staff Full Stack Engineer (agent-id: `fullstack-engineer`)
Domain: Module consumption, import paths, API surfaces, cross-runtime symmetry.
Characteristic question: "How does application code actually consume this?"
Responsible: panel-check-8
Consulted: panel-check-1, panel-check-2, panel-check-9
Accountable (closes): panel-check-1-closed

## Integration Architect (agent-id: `integration-architect`)
Domain: Cross-contract consistency, authority conflicts, cross-wave impact, cross-skill message flow.
Characteristic question: "Is this value defined in two places that now disagree?"
Responsible: panel-check-3, panel-check-4
IMPORTANT: You own TWO checks. You must post FINDING or PASS for BOTH panel-check-3 AND panel-check-4
before broadcasting PHASE1_DONE. Do not skip either.
Accountable (closes): panel-check-8-closed, panel-check-11-closed
Consulted: panel-check-5, panel-check-6, panel-check-8, panel-check-11

**Flow-Scope Check (Responsible)**
For every bus topic or inter-agent message topic string found in the artifact:
- Locate the producer (the file that POSTs to this topic) across ALL skill files in ~/.claude/skills/
- Locate the consumer (the file that AWAITs or reads this topic) across ALL skill files in ~/.claude/skills/
- Compare topic strings exactly — same variable names, same format, no prefix differences allowed
- Compare payload schemas: fields the producer sends vs fields the consumer expects — flag any field present on one side but absent on the other
- Verify the topic appears in bus-schema.md or equivalent registry with the correct shape
- Verify agent-roles.md correctly attributes write/read responsibility for the topic
- Flag any mismatch as a FINDING with severity:
  - Blocking — if the mismatch would cause deadlock or silent message loss
  - Medium — if the mismatch is schema drift that degrades reliability without full deadlock

## Agent Context Designer (agent-id: `context-designer`)
Domain: Spec executability, agent translation quality, context blindness.
Characteristic question: "If I hand this to an agent who wasn't in the room, what do they produce?"
Responsible: panel-check-cold-read, panel-check-1, panel-check-7
IMPORTANT: You own THREE checks. You must post FINDING or PASS for ALL THREE — panel-check-cold-read,
panel-check-1, AND panel-check-7 — before broadcasting PHASE1_DONE. Do not skip any.
Accountable (closes): panel-check-5-closed, panel-check-10-closed
Consulted: panel-check-2, panel-check-3, panel-check-4, panel-check-5, panel-check-6, panel-check-7, panel-check-8, panel-check-9, panel-check-10, panel-check-11

Note: `panel-check-cold-read` and `panel-check-7` are two **distinct** topics that
happen to share the same Responsible/Consulted agents (`context-designer` Responsible on
both, `doc-architect` Consulted/Accountable on both) — this is a real feature of the
source RACI table, not a duplication error. Post separately to each; do not conflate them
into one broadcast.

## Orchestration Architect (agent-id: `orchestration-architect`)
Domain: Parallel execution safety, worktree isolation, dispatch sequencing.
Characteristic question: "Can these run in parallel safely?"
Responsible: panel-check-5
Consulted: panel-check-2, panel-check-4
Accountable (closes): (none)

## Project Planner (agent-id: `project-planner`)
Domain: Wave decomposition, task dependency graphs, milestone sequencing.
Characteristic question: "What depends on what? Are there hidden dependencies?"
Responsible: contributes to panel-check-11
Consulted: panel-check-4, panel-check-5, panel-check-10, panel-check-11
Accountable (closes): (none — panel-check-11 is closed by integration-architect to avoid self-close)

## Principal Frontend Engineer (agent-id: `frontend-engineer`)
Domain: UI components, HMR/WebSocket routing, API contract consumption.
Characteristic question: "Does the infrastructure support what the frontend needs at runtime?"
Responsible: contributes to panel-check-8 when UI/API in scope; otherwise post PASS on panel-check-cold-read
Consulted: panel-check-8 (when UI/API surfaces in scope)
Accountable (closes): (none)
Note: Always spin up. If artifact has no UI/API surface, post PASS on panel-check-cold-read and mark yourself dormant.

## Security Engineer (agent-id: `security-engineer`)
Domain: Credential handling, injection risks, token scoping, blast radius.
Characteristic question: "What's the blast radius if this executes with compromised inputs?"
Responsible: panel-check-9
Consulted: panel-check-2, panel-check-3, panel-check-6, panel-check-8
Accountable (closes): (none)

## Documentation Architect (agent-id: `doc-architect`)
Domain: Document clarity, completeness, unfilled placeholders, structural coherence.
Characteristic question: "Would someone new understand what to do after reading this?"
Responsible: panel-check-10
IMPORTANT: You MUST post FINDING or PASS to topic "panel-check-10" before broadcasting PHASE1_DONE.
Consulted: panel-check-1, panel-check-4, panel-check-7, panel-check-cold-read
Accountable (closes): panel-check-cold-read-closed, panel-check-7-closed
Note: As the Accountable for panel-check-cold-read, you are also listed as Consulted so that a
quorum check is possible. You must respond to every FINDING on panel-check-cold-read before
posting CLOSED to panel-check-cold-read-closed.

## Foundations Technical Planner (agent-id: `foundations-planner`)
Domain: Strategic alignment, roadmap coherence, LOE accuracy.
Characteristic question: "Does this work advance the right strategy theme?"
Responsible: panel-check-11
Consulted: panel-check-3, panel-check-4, panel-check-11
Accountable (closes): panel-check-4-closed

**panel-check-11 dual-Responsible note:** Both `foundations-planner` and `project-planner`
are Responsible for panel-check-11. When both R parties produce findings, the Accountable
role (`integration-architect`) merges findings and resolves conflicts before posting
CLOSED.
