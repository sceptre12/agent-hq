# 0003. Memory-ownership map: one owner per fact, no mirroring

- **Status:** accepted
- **Date:** 2026-07-01
- **Context of:** workspace-wide

## Context

With multiple memory mechanisms (CLAUDE.md, learnings/, decisions/, Serena notes,
agentmemory), the risk is duplication: the same fact in two places, diverging silently.
A single-owner rule prevents this. The automatic plane's physical home is governed
by ADR 0006.

## Decision

One owner per fact. No mirroring. Pointers only between planes.

| Artifact | Owner | Written by | Read by |
|---|---|---|---|
| CLAUDE.md files (root, hq, per-repo) | hq discipline | Human, Compound-only | Auto-loaded |
| decisions/ learnings/ STANDARDS projects/ retros/ | hq git | Human | On-demand grep→Read |
| references/x-context-docs/* | hq git (append-only) | Human appends | grep-only; never Serena-indexed |
| agentmemory stores (personal + work) | agentmemory | Its hooks, automatically | Its MCP tools only |
| Serena per-repo notes (.serena/) | That code repo | Human, sparingly | Serena tools in-repo |

**Promotion rules:**

1. **Automatic → curated is one-way and manual.** agentmemory recall is never pasted,
   exported, or mirrored into hq git. Only the Compound ritual (human writing) promotes
   insights from recall into hq markdown.
2. **Serena notes stay repo-local.** hq project records link to them; never copy.
3. **No TIL/ADR mirroring.** A fact in decisions/ or learnings/ is never also written
   into agentmemory or Serena notes.
4. **Work-namespace promotion into hq only in sanitized form.** Patterns, not payloads;
   anything work-confidential stays work-side or is not promoted at all. Every hq commit
   is under the personal account and must be employer-safe.
5. **OS snapshot/git snapshot — not the durability mechanism for the automatic plane.**
   Snapshot-exports of agentmemory into hq git are explicitly forbidden — they would
   create a machine-generated mirror of the automatic plane inside the curated plane,
   violating rules 1 and 3 above. Durability for automatic stores = backup + Compound
   (details in ADR 0006).
6. **The automatic plane's physical home is governed by ADR 0006.**

## Reasoning

Duplication always drifts. One-owner-per-fact is the only rule that prevents silent
divergence without requiring continuous reconciliation. The compliance sub-rule (rule 4)
follows from hq being committed under the personal account.

## Consequences

- Easier: no staleness from duplicated facts; clear answer to "where does X live?"
- Harder: discipline required at Compound time to rewrite rather than paste/export.
- Accepted: agentmemory loss (corruption, machine wipe) loses recall nuance, not
  decisions or learnings — those are in hq git, the sole durable truth.

## Alternatives considered

- Periodic export of agentmemory into hq markdown — violates rules 1 and 3; creates a
  machine-generated mirror that drifts and piles up churn commits.
- Serena indexing hq — ruled out; hq is grep-only; Serena is for code repos.

## As-built addendum (2026-07-02): LLM features off

agentmemory's LLM-powered consolidation/compression/graph extraction are deliberately disabled (no ANTHROPIC_API_KEY provided). Rationale: background LLM consolidation would create a second curator competing with the Compound ritual; hq git remains the sole owner of durable knowledge. AGENTMEMORY_INJECT_CONTEXT is also off — recall is pull-only, keeping the cache prefix clean. Accepted by user 2026-07-02.
