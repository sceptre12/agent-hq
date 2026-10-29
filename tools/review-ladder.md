# Review-escalation ladder

One-line summary: which review mechanism to use for a given artifact, so the strongest
tool is reserved for problems that need it — "bringing a tank to a water-gun fight" (the
user's own phrase) is the recorded failure mode this standard exists to prevent.

- **Status:** active
- **Applies to:** choosing a review mechanism for any hq artifact (doc, plan, ADR, code
  diff) before invoking a review skill.
- **Builds on:** `tools/skill-authoring.md` (skill anatomy, `description`/`## Red flags`
  fields this standard's prompt-hints attach to), `tools/skill-porting.md` (Gate 2 refit,
  where the hints get written into each ported review skill).

## 1. The ladder

| Rung | Mechanism | What it is | Cost | Use for | Not for |
|---|---|---|---|---|---|
| 0 | direct review | single reviewer instance, no skill | ~1 agent | trivial/mechanical changes, typo-level docs | anything with a design fork |
| 1 | doc-reviewer skill | single-agent checklist review (10-step, 3-phase) | 1 agent | routine single-artifact review, consistency + auditability | multi-doc systems, contested decisions |
| 2 | panel-consultation skill | real 9-seat RACI panel — nine independent agent instances read blind, RACI-closed, synthesized, fixed and fix-verified; no swarm bus | ~13-23 agents (one Opus orchestrator sub-agent) | breadth of perspective on medium-stakes/medium-size artifacts without bus overhead; also reconciles two diverged versions of one artifact (`MODE=reconcile`) | decisions needing bus-quorum deliberation or 11-agent scale (Rung 4) |
| 3 | pr-review skill | 7 independent agents + bus deliberation | ~8 agents + live bus | substantial code diffs/PRs | prose/architecture docs |
| 4 | panel-review skill | 11 independent agents, bus quorum deliberation | 26+ agents + bus + PM2 | large architecture docs, one-way-door decisions, high blast radius | anything a lower rung covers |

Rungs 3–4 require the swarm bus, which went live 2026-07-04 (Gate 3,
`tools/skill-porting.md`); all four rungs are now available.

## 2. Selection rubric

Pick the **lowest** rung that covers the risk; escalate on triggers (§4), never start high
"to be safe." Weigh:

- **Artifact size** — does it fit one context comfortably?
- **Stakes** — reversible, or a one-way door? What's the blast radius?
- **Contention** — is there a genuine design fork or disagreement, or is this routine?
- **Novelty** — well-trodden pattern, or new territory?

## 3. Executor-tier modifier

When the executing/orchestrating models are mid-tier only (Sonnet/Haiku environments,
e.g. the user's work setup), shift **+1 rung** for the same artifact: structural rigor and
independent instances substitute for top-tier judgment. When a top-tier orchestrator is
present, the ladder applies as written.

Why: weaker single contexts are more prone to unnoticed anchoring and coverage gaps, so
independence and checklists carry more of the quality burden.

## 4. Escalation and de-escalation triggers

Escalate one rung **mid-review** when:
- Contradictory cross-cutting findings emerge.
- Simulated perspectives genuinely deadlock (Rung 2).
- A one-way-door decision is discovered inside the artifact.
- The artifact exceeds what one context can review coherently.

De-escalation red flags — rationalization → do instead:

| Rationalization | Do instead |
|---|---|
| "High stakes" claimed without a nameable risk | Name the risk, or drop a rung. |
| "We used panel-review last time" | Rungs attach to artifacts, not habits. |
| "Small doc, but panel-review to be safe" | That's the tank at the water-gun fight — Rung 1 covers it. |
| "I can simulate the panel myself, skip the real one" (on a one-way door) | Simulation shares one context; independence is the point at Rung 4. |

## 5. Prompt-hint mechanism (how agents discover the ladder)

A skill's frontmatter `description` is always-loaded L1 metadata, so the hints live
there: at Gate 2 refit (`tools/skill-porting.md`), each ported review skill's
`description` **must** state its rung and point one rung up and down ("Use when …; for
<bigger case> use <skill>; for <smaller case> use <skill>"), and its `## Red flags`
**must** include one ladder row (wrong-rung rationalization → correct rung). Every agent
then sees the ladder from metadata alone, without loading any skill body.

Cross-reference: `tools/skill-porting.md` Gate 2; `tools/skill-authoring.md` §2.
