# architecture/ — design records (ADR 0011)

One file per system/skill, `architecture/<slug>.md`: WHAT it is and WHY it's shaped that
way — components, interfaces, constraints, settled decisions, and source lineage (e.g.
an upstream design this was validated against, or a ported skill's origin).

## What belongs here

- Components and interfaces.
- Constraints the design operates under.
- Settled decisions about shape (not the *authority* to decide — see below).
- Source lineage: where design material was reused from and validated against.

## What doesn't

- **Execution/dispatch status** — goes in `plans/` (status tables, what's done, by whom).
- **How-to standards** — goes in `tools/` (mechanics of doing a thing).
- **Decision authority** — stays in `decisions/` (ADRs). Architecture docs are
  descriptive; on conflict, the ADR wins (precedence unchanged, see hq `CLAUDE.md`).

## Rule 5 flow

Architecture ratified here → dispatch plan derived from it in `plans/` → execution. No
substantive build without both, in that order.
