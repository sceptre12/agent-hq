# Seats, topics, RACI and the close rule

Nine seats, nine finding topics, one fixed matrix. The matrix is the same on every run (default:
RACI needs stable closers); each seat's brief is fitted per run (section 3). The shape follows
`skills/pr-review/references/agent-roles.md` and `skills/panel-review/references/agent-roles.md`.
Labels: owner = the owner's quoted words; fact = measured; default = this skill's choice, the
owner may change it; question = open owner item (`SKILL.md`, Defaults and open questions).

## 1. Seats (agent-id in backticks)

| # | Seat | Lens (characteristic question) | Lineage |
|---|---|---|---|
| 1 | Cold Reader `cold-reader` | "Handed to an agent who wasn't in the room, what gets produced?" Executability, ambiguity, contradictions, placeholders, scope confusion. | v1 Agent Context Designer and its Phase 0 cold read; doc-reviewer Check 7 (`skills/doc-reviewer/SKILL.md:58@c057d0cf`); pr-review `strategic-reviewer` cold read (`skills/pr-review/references/agent-roles.md:64-69`) |
| 2 | Integration Architect `integration-architect` | "Is this value or rule defined in two places that now disagree? What else had to change?" Cross-document and cross-contract consistency, flow-scope (producer and consumer of every topic, path, id), cascading impact. | `skills/pr-review/references/agent-roles.md:27-48`, `skills/panel-review/references/agent-roles.md:35-54`, v1 Integration Architect; doc-reviewer Checks 4, 12, 14 |
| 3 | Fact Checker `fact-checker` | "Does the cited line say that? Does the command produce that count?" Re-measures every file:line cite, sha, count, command claim and owner quote. | review-7-panel router default "one seat that re-measures facts" (`skills/review-7-panel/SKILL.md:96-97@c057d0cf`); `references/patterns.md` Pattern F; pre-round C1, C2, C7; citations are wrong even when findings are right |
| 4 | Scope and Boundary Reviewer `scope-reviewer` | "Does the artifact do what it claims, no more? Which sentences make rules without an owner quote?" Intent vs text (PR title and commits vs diff; plan vs architecture vs ticket), scope creep and gaps, Rule 9 tagging, owner-only items named not decided. | pr-review `strategic-reviewer` (`skills/pr-review/references/agent-roles.md:64-69`); pre-round C5; review-7-panel never-list (`skills/review-7-panel/SKILL.md:136-149@c057d0cf`) |
| 5 | Orchestration Architect `orchestration-architect` | "Can these run in parallel safely? Is every dispatch pinned, bounded and verifiable?" Rule 7 shared state, worktree isolation, sequencing and real dependencies, model pins (Rules 3 and 4), done conditions, stop clauses, wake signals, budgets. | v1 Orchestration Architect and Project Planner; panel-review `orchestration-architect` and `project-planner` roles |
| 6 | Platform and Runtime Engineer `platform-engineer` | "Which layer owns this value? Is the command exact and does it behave the same in every runtime?" Env and config authority, exact commands (no pseudocode), runtime parity, build and deploy quirks, acceptance-criteria runability. | v1 Platform and DevOps; pr-review `platform-engineer` and `devops-engineer`; `references/patterns.md` Patterns A, C, D; doc-reviewer Checks 3, 6, 13 |
| 7 | Security and Blast-Radius Engineer `security-engineer` | "What is exposed? What is the blast radius if this runs with compromised inputs, or deletes the wrong thing?" Credentials and tokens in records, injection, deletion and data-loss paths, permission scope, never-read files. | `skills/pr-review/references/agent-roles.md:50-55`, `skills/panel-review/references/agent-roles.md:93-98` |
| 8 | Consumer Engineer `consumer-engineer` | "How does the downstream code, agent or dispatcher actually use this? Does the shape match?" Interfaces as consumed: API and contract shapes, import and usage examples, a skill's dispatch brief as its caller sees it; UI and API consumption when a frontend is in scope. | v1 Staff Full Stack and Principal Frontend; pr-review `fullstack-engineer` |
| 9 | Documentation and Record Architect `doc-architect` | "Where does this get recorded, and will it be found and still be true later?" Decision placement, provenance, duplicate definitions (one rule, one place), line caps, ladder and description consistency, docs vs implementation drift. | v1 Documentation Organizer; pr-review `technical-writer`; panel-review `doc-architect`; pre-round C4 and C6; a rule stated in two places counts as not replaced (Hermes D65) |

Dropped, with the reason: v1 "Principal Frontend Engineer" as its own seat (dormant for non-UI
work; folded into seat 8); panel-review "Foundations Technical Planner" (roadmap alignment is the
caller's, not a finding type); pr-review DevOps as a seat (merged into seat 6).

## 2. Topics, RACI and the close rule

Topics are prefixed `pc-` (the disambiguation convention of `skills/pr-review/references/bus-schema.md:5-15@c057d0cf`).
**Phase 1** = the nine seat dispatches of a round: R writes FINDING or PASS lines on its topic;
each C seat writes one C-NOTE on each of its C topics, blind (without reading R): `risk-seen |
<evidence>` when, reading the artifact alone, it sees a defect in that topic's area, else
`none-seen`. **Phase 2** = the A-close dispatches, started after every Phase 1 record exists.
I = every other seat, informed through the synthesizer's report. A seat that sees something on a
topic where it is neither R nor C writes it as a C-NOTE on that topic, handled like any other.

**Close rule** (default; stated once here; line shapes and ids in `references/severity-and-records.md`):
every in-scope topic (all nine in a Full round; a Focused round's in-scope topics,
`references/scaling.md`) ends the round with exactly one `CLOSED` line (an UNRESOLVED topic: none). After Phase 1 the
orchestrator extracts, per in-scope topic, the R seat's FINDING/PASS lines and every C-NOTE on that
topic into one topic file (`pc-<slug>-r<N>-topic-<topic>-<date>.md`). A topic gets an A-close
dispatch when its file holds at least one FINDING from R or at least one C-NOTE `risk-seen`; the
fresh A instance receives that topic file, the artifact, the sources and its own section-1 row,
never a whole seat record (the one exception to "a seat reads no other seat's record"). It
re-measures each item from source and appends to that topic file one `VERDICT` line per existing
finding id, any finding it adds (id `<topic>-A<n>`; an upheld C-NOTE becomes one), and the CLOSED
line with a final severity per id (an UNRESOLVED topic: VERDICT lines only). Otherwise (R posted PASS, every C-NOTE `none-seen`) the
orchestrator appends the CLOSED line itself (an UNRESOLVED topic gets no CLOSED line; its
C-NOTEs, if any `risk-seen`, go to an A-close on the C-NOTEs alone):
`CLOSED | <topic> | orchestrator | PASS | validated: none; challenged: none`.
Seats write C-NOTEs only on in-scope topics. The synthesizer takes the A-close severity as final
unless it re-verifies and changes it (`SYNTH-OVERRIDE`). It receives every topic file, the round's
ledger lines (NOT-REVIEWED, UNRESOLVED), the pre-round record and HISTORY (prior synthesizer
tables, for its repeat-class column).

A differs from R on every topic (default: no seat closes what it found). Source note:
`skills/pr-review/references/agent-roles.md:30,34` does not hold it; `skills/panel-review/references/agent-roles.md:83`
avoids self-close once.

| Topic | What it covers | R | A (closes) | C |
|---|---|---|---|---|
| `pc-cold-read` | executability, ambiguity, contradiction, placeholders, scope confusion | cold-reader | doc-architect | scope-reviewer, consumer-engineer |
| `pc-cross-ref` | cross-document / cross-contract consistency, flow-scope of every id, path, topic | integration-architect | consumer-engineer | cold-reader, doc-architect |
| `pc-citations` | every cite, sha, count, command claim, owner quote re-measured | fact-checker | integration-architect | scope-reviewer, orchestration-architect |
| `pc-scope` | intent vs text, scope creep/gaps, Rule 9 tagging, owner items named not decided | scope-reviewer | cold-reader | fact-checker, doc-architect |
| `pc-dispatch` | Rule 7 shared state, pins, done conditions, stop clauses, wake signals, budgets | orchestration-architect | security-engineer | platform-engineer, consumer-engineer |
| `pc-runtime` | value authority, exact commands, runtime parity, AC runability | platform-engineer | orchestration-architect | security-engineer, fact-checker |
| `pc-security` | secrets in records, injection, deletion/data-loss paths, permission scope | security-engineer | scope-reviewer | orchestration-architect, platform-engineer |
| `pc-consumption` | interface as consumed: shapes, usage examples, dispatcher's view of a skill | consumer-engineer | platform-engineer | cold-reader, integration-architect |
| `pc-record` | decision placement, provenance, duplicate definitions, line caps, ladder text | doc-architect | fact-checker | integration-architect, security-engineer |

Counted from the table: each seat is R for exactly one topic, A for exactly one, C for exactly
two (9 R, 9 A, 18 C cells); no seat is both A and C, or R and C, on one topic. The A column forms
one 9-cycle, so no two seats close each other's topics (default). Check definitions live in this
one file (section 4), closing pr-review's recorded defect that its `pr-check-1..9` were never
defined.

## 3. Perspective fitting (S3 carried)

The orchestrator writes, in each seat's brief, the artifact-specific risk surface that seat must
pressure-test (two to four lines: for a plan, seat 5 gets "the parallel set and the shared
test-map file"; for a skill, seat 8 gets "the dispatch brief a caller must write from the Steps
section"). It is written in the loop ledger before dispatch (carried from
`skills/review-7-panel/SKILL.md:83-99@c057d0cf`). `KIND` selects the examples; it changes no seat, matrix
row, tier rule or bar. Rounds may re-fit the surface to the residual finding class; the seat and
its RACI row do not change. Owner S3 (2026-10-24, 13:53:57Z): "Do panel consultation except there
are 7 agents that take on the perspectives that better rmatch the problem being solved"; the
fitting rule is kept inside each seat, the seat count is nine (question Q13).

## 4. One-line check definitions per topic

Each R seat runs its topic's check; each C seat writes one C-NOTE per C topic.

| Topic | The check (one line) |
|---|---|
| `pc-cold-read` | Read the artifact as an agent with zero context: list what you would produce, and every place you would have to guess, contradict yourself, or fill a placeholder. |
| `pc-cross-ref` | For every id, path, value, rule and topic the artifact defines or uses: find its producer and each consumer, compare exact strings, and name what else had to change. |
| `pc-citations` | Re-open every cited file at the cited sha and line, re-run every command claim, string-match every owner quote; a cite that does not open, or whose text differs, is a finding. |
| `pc-scope` | Compare what the artifact says it does (title, summary, PR text, commits, ticket) with what its text does; list each sentence that makes a rule, cap, cost, publication or deletion without an owner quote or a default/question tag. |
| `pc-dispatch` | For every dispatch or parallel set: shared mutable state, model pin and rationale, done condition, stop clause, wake signal, budget; real vs assumed dependencies. |
| `pc-runtime` | For every command, path and config value: is it exact, runnable as written, owned by one layer, and the same in every runtime; can each acceptance criterion be run. |
| `pc-security` | Secrets or tokens in text or records, injection through briefs and commands, deletion or data-loss paths (rm with literal paths only), permission scope, never-read files. |
| `pc-consumption` | Build the caller's or consumer's side from the text alone: does the shape, example, input list or brief match what the consumer needs. |
| `pc-record` | For every decision and definition: is it recorded once, in the right place, with provenance; duplicate definitions, line caps (every file under 1000 lines), ladder and description text consistent with the files that name it. |

## 5. Source notes

The matrix's R/A/C cells are this skill's own defaults: pr-review's matrix is the shape source,
the A-not-R rule and the nine-cycle are new. Severity authority sits in the A column (v1's
Phase 2.5 severity step), not in a separate seat.

## Lineage

Lineage: panel-consultation v1 (X-context-docs skills/panel-consultation@0e9281e), review-7-panel
(`skills/review-7-panel/SKILL.md`, `skills/review-7-panel/preround-check.md`), pr-review
(`skills/pr-review/references/agent-roles.md`, `skills/pr-review/references/agent-briefs.md`,
`skills/pr-review/references/synthesizer-brief.md`), panel-review
(`skills/panel-review/references/agent-roles.md`), `skills/fix-verifier/SKILL.md`, `skills/doc-reviewer/SKILL.md`, and
`tools/skill-authoring.md` section 4 (the checklist this skill follows).
