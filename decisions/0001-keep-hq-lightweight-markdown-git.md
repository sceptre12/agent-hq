# 0001. Keep hq lightweight: plain Markdown + plain git

- **Status:** accepted
- **Date:** 2026-07-01
- **Context of:** workspace-wide

## Context

`hq` is a meta-workspace for project context, standards, decisions, and learnings across
many repos. The risk with such a hub is over-engineering it into its own maintenance
burden (databases, generators, heavy tooling), which defeats the purpose.

## Decision

We will keep `hq` as plain Markdown in a single git repo, with a small fixed folder set
(`inbox/`, `projects/`, `decisions/`, `learnings/`, `retros/`, `references/`, `tools/`).
No build step, no required tooling to read or edit. Code repos live as siblings, never
nested.

## Consequences

- Easier: anyone can read/edit with a text editor; portable; diff-friendly history.
- Harder: no automated indexes/queries — indexes (e.g. the ADR table) are maintained by
  hand or regenerated later if it ever hurts.
- Revisit if the manual overhead grows; only then consider light tooling.

## Alternatives considered

- Wiki / Notion / database — richer, but tool lock-in and not git-native.
- Per-project nested repos or submodules — heavier, and couples hq to code lifecycles.
