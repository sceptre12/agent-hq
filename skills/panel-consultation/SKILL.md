---
name: panel-consultation
description: >
  Simulated multi-perspective architecture panel — one agent roleplaying a 9-member expert
  panel (platform, devops, full-stack, integration-architecture, agent-context-design,
  orchestration, planning, frontend, and documentation domains) to pressure-test
  architecture decisions, contracts, task specs, and designs before a finished artifact
  exists to grade. Use when multi-perspective expert input is wanted on technical work — a
  design review, architecture thinking, a "think this through," "consult the panel,"
  "pressure test," or "sanity check" request. This is Rung 2 on the review ladder
  (tools/review-ladder.md): perspective breadth on medium-stakes artifacts without bus
  overhead — perspectives are simulated in one shared context, so independence is not real.
  For a finished artifact needing a routine checklist review, use doc-reviewer instead
  (Rung 1). For a contested one-way-door decision where perspective independence actually
  matters, escalate to panel-review instead (Rung 4).
---

## Trigger

Use when multi-perspective expert input is wanted on technical work — a design decision, an
architecture question, a contract or task-spec draft, or an idea that needs pressure-testing
before there's a finished artifact to review. This is Rung 2 on the review ladder
(`tools/review-ladder.md`): reach for it for breadth of perspective on medium-stakes work
without bus overhead. It is not a substitute for doc-reviewer (Rung 1) when there's already
a finished document and the need is a routine checklist pass, and it is not a substitute for
panel-review (Rung 4) when the decision is a genuine one-way door and perspective
independence — not simulation — actually matters.

How this differs from doc-reviewer: doc-reviewer grades a finished artifact against a fixed
set of checks. This skill is for thinking through a problem *before* there's a finished
artifact to grade.

## The Panel

Each member has a distinct domain, a characteristic question, and a strongest catch. Adopt
each relevant member's perspective genuinely when running a session — surface real domain
concerns; don't rubber-stamp from 9 angles.

| Role | Domain | Characteristic question | Strongest on |
|---|---|---|---|
| **Platform Engineer** | Infrastructure interfaces, service topology, credential management, ENV var ownership, layer separation | "Which layer owns this? Where does this value come from?" | Misattributed ownership, connection-string correctness, infra assumptions that don't hold across runtimes |
| **DevOps Engineer** | Dockerfiles, build commands, image layers, package installation mechanics, CI/CD, runtime build quirks | "What's the exact command? Does this work the same way in every runtime?" | Translating abstract specs into concrete build commands, pseudocode agents will misinterpret, per-runtime packaging gotchas |
| **Staff Full Stack Engineer** | Module consumption patterns, import paths, API surfaces, cross-runtime symmetry | "How does application code actually use this? Is the pattern consistent across runtimes?" | Modules that work in isolation but don't match consumer expectations, missing import examples, asymmetric runtime support |
| **Integration Architect** | Cross-contract consistency, acceptance-criteria quality, verification completeness, cross-wave impact | "Does the verification actually prove compliance, or just functionality?" | Acceptance criteria that pass but miss the real requirement, values drifting between contracts, cascading cross-wave impacts |
| **Agent Context Designer** | Task-spec executability, context budgets, spec-to-agent translation quality | "If this were handed to an agent who wasn't in the room, what would they produce?" | Gap between authorial intent and literal text, accumulated context blindness, ambiguity authors fill in mentally but agents cannot |
| **Orchestration Architect** | Parallel execution, worktree isolation, file-scope overlap, context-package sizing, dispatch sequencing | "Can these run in parallel safely? Is the context budget manageable?" | Hidden shared state between parallel agents, context overload, dispatch ordering that creates unneeded dependencies |
| **Project Planner** | Wave decomposition, task dependency graphs, parallelization strategy, milestone sequencing | "What depends on what? Where are the hidden dependencies?" | Work that looks independent but shares state, sequencing mistakes, scope creep across wave boundaries |
| **Principal Frontend Engineer** | UI components, frontend dev servers, HMR/WebSocket routing through infrastructure, API consumption from the frontend | "Does the infrastructure support what the frontend needs at runtime?" | Frontend-infrastructure integration points, API response-shape mismatches. Dormant for infrastructure-only projects — activates when UI work is in scope. |
| **Documentation Organizer** | Documentation completeness, where learnings are captured, execution-log maintenance, cross-document consistency | "Where does this get recorded? Will it be findable later?" | Ensuring decisions land in the right durable record, catching documentation gaps that create institutional memory loss |

## Steps

1. **Understand what's on the table.** Get clear on: what's under discussion (a design
   decision, a contract draft, a task spec, a vague idea); what phase of work (brainstorming,
   contract authoring, spec writing, pre-dispatch review, post-execution retro); and what the
   concern is (a specific worry, or a general "poke holes in this"). If a document or link is
   provided, read it; if the problem is only described in conversation, work from that — the
   skill is self-contained and needs no external tool to run a useful session.

2. **Identify which panel members have standing.** Not every member speaks on every topic.
   Read `references/triggers.md` to find which consultation triggers are active, then select
   the 3-5 most relevant members. If the problem crosses infrastructure + application
   boundaries, always include Platform Engineer and Staff Full Stack Engineer. If it involves
   specs that agents will execute, always include Agent Context Designer.

3. **Run the consultation.** For each relevant member, in sequence: state the perspective
   ("As the [Role]..."), apply their characteristic question to the specific problem, surface
   concrete concerns (not "this might cause issues" — the specific thing that could go wrong,
   with an example), check `references/patterns.md` for the 6 learned failure patterns (A-F)
   and call one out explicitly if the situation rhymes with it, and land on a concrete
   recommendation, not just a concern.

4. **Synthesize.** After all relevant members have spoken: identify agreements (the same
   concern raised from different angles is a strong signal), identify tensions and surface
   the tradeoff honestly rather than picking a side for the panel — weighing domain authority
   when members conflict (the member whose domain is closest to the concern carries more
   weight: Platform Engineer on infrastructure values, DevOps Engineer on build commands,
   Agent Context Designer on spec executability) — rank by impact, and propose one concrete
   path forward. This is a thinking tool, not a gate: if the panel raises several concerns
   but the decision is to proceed accepting some of the risk, that is a valid outcome.

5. **Run the pre-flight checks whenever the artifact under discussion is a task spec,
   contract, or document headed for dispatch or merge** — this is the final quality gate
   before work leaves the design phase, and it is not optional in that case. Read
   `~/.claude/skills/doc-reviewer/references/checks.md` and run Checks 1-8 at minimum —
   doc-reviewer is the canonical, maintained source for these checks; don't use or recreate a
   second copy. For a general thinking session with no artifact headed for dispatch or merge,
   this step doesn't apply.

## Modes

- **Think this through (default):** full panel session as above — design decisions,
  architecture questions, pre-dispatch review.
- **Quick sanity check:** only the 2-3 most relevant members weigh in, no formal synthesis —
  for small decisions that just need a second look for something obvious.
- **Devil's advocate:** each member actively tries to break the idea — more adversarial, for
  stress-testing something already fairly settled.
- **Retrospective lens:** the panel looks at something that already happened (a completed
  wave, a failed agent run, a merged branch) and extracts learnings — each member identifies
  what they would have caught and what should change next time.

## Documentation lookup

The skill runs with no external tool. When a durable record exists — this workspace's
`decisions/`, Hermes for learnings (ask through its API door; recipe in
`tools/brain/templates/member-CLAUDE.md`, Memory section), or another live doc workspace if the project has one — pull it
in before the panel re-debates a settled question, runs a retrospective from memory instead
of actual execution history, or discusses a contract value from memory instead of the actual
file. Use whatever MCP tools are available for that record; if none are available, ask for
the relevant context to be pasted in directly.

## Red flags

| Rationalization | What to do instead |
|---|---|
| "Small decision, but let's run the full 9-member panel to be safe." | That's the tank at the water-gun fight (`tools/review-ladder.md` §4) — use Quick Sanity Check mode, or drop to Rung 1 (doc-reviewer) if there's a finished artifact and no real contention. |
| "All 9 members should weigh in on everything." | Select the 3-5 with actual standing (Step 2) — a member with nothing domain-relevant to say is rubber-stamping, not adding perspective. |
| "The panel agrees on everything, ship it." | Genuine tension is the signal this skill exists to surface; if every member agrees instantly, check whether each is actually applying their distinct lens or just agreeing with whoever spoke first. |
| "This doesn't rhyme with any of the 6 known patterns, so it's fine." | Absence of a pattern match isn't a clean bill of health — it's an unproven claim, not a passed check. |
| "It's just a quick sanity check, skip the pre-flight checks." | If the artifact is headed for dispatch or merge, Step 5's pre-flight checks are not optional regardless of mode. |
| "This is a one-way-door decision — running more panel rounds myself will be sure enough." | Simulation shares one context; more rounds don't buy independence. Escalate to panel-review (Rung 4) instead. |

## Exit criteria

- [ ] At least 3 panel members with actual standing on the problem have spoken (Steps 2-3).
- [ ] Each member who spoke surfaced a concrete concern or recommendation, not a generic
      restatement.
- [ ] Agreements and tensions were both identified explicitly (Step 4) — not just a list of
      concerns.
- [ ] One concrete path forward was proposed.
- [ ] If the artifact is headed for dispatch or merge, the pre-flight checks (Step 5) ran and
      their results are stated.

## Provenance
Provenance: Hermes skill learnings/skill-sharing (imported from learnings/skill-sharing.md; the recorded port friction)
Lineage: X-context-docs skills/panel-consultation@0e9281e
