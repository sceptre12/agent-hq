# agent-hq — AI memory layer

This file is auto-loaded by Claude Code inside `~/projects/agent-hq` — minimal context to
navigate and extend this workspace correctly.

**Precedence on conflict: decisions/ (ADRs) > STANDARDS.md > CLAUDE.md > task instructions > agent judgment.**


## What hq is

A **meta-workspace**, not a code project. Holds context, standards, decisions, and learnings
for all projects under `~/projects/`; code repos are siblings at `~/projects/<repo>/`, never nested inside hq.

## Folder map

```
hq/
├── agents/         agent definitions (topology workers)
├── architecture/   one design record per system/skill — the WHAT/WHY layer (ADR 0011)
├── config/         global Claude rules, settings and permission tiers
├── skills/         skills installed into ~/.claude/skills by symlink
└── tools/          how-to setups and machine-level standards
```

## Core standards (brief)

- **Commits:** `add | update | decision | learning | retro | chore: <summary>`
- **Learnings:** live in Hermes via its API door (recipe: `tools/brain/templates/member-CLAUDE.md`, Memory section).

## Memory ownership (brief)

- Durable knowledge: learnings live in Hermes (config/CLAUDE.md Rule 13); hq git markdown keeps tools, standards and decisions.
- Code orientation = Serena notes inside each code repo; hq points to them, never copies.


## Concurrent writes (ADR 0017, amends 0013)

Every work unit — even one commit — runs in a worktree under `~/projects/agent-hq-worktrees/`,
merged + pushed to main when done; never author on main. Main moved ahead (others pushed)
= normal. Anomalies, fix-or-surface first: dirty / unpushed-local / failing invariants / dangling worktree.

## Keep this file under ~60 lines

Prune anything stale. Depth belongs in per-folder READMEs and STANDARDS.md.
