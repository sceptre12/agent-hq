# hq — personal command-center workspace

`hq` is a single, lightweight git repo that holds the **architecture and context of
all my projects** in one place. It is a meta-workspace — a command center — **not a
code project**. No application code lives here; only context, standards, decisions,
lessons, and reference material.

## Why this exists

When work is spread across many repos, the *context* (why a project exists, how it's
built, what was decided, what was learned) gets lost. `hq` is the durable home for that
context so any project can be picked back up quickly, and so lessons compound over time.

## What lives here

| Dir           | Purpose (one line)                                                        |
|---------------|---------------------------------------------------------------------------|
| `agents/`     | Agent definitions (topology workers).                                     |
| `config/`     | Global Claude rules, settings and permission tiers.                       |
| `skills/`     | Skills installed into `~/.claude/skills` by symlink.                      |
| `tools/`      | Standards-as-tools: how-to setups (e.g. git identity auto-switch).        |

## How to use it (the 30-second version)

- **Learned something worth reusing?** Write it to Hermes through its API door
  (recipe: `tools/brain/templates/member-CLAUDE.md`, Memory section); existing `learnings/` files stay until the owner-gated removal.
- **End of any session?** Run the Compound reflection (see `STANDARDS.md` §8 and
  Hermes skill `learnings/learnings-methodology` (was learnings/METHODOLOGY.md)).
- **All conventions** (naming, doc format, commits, how projects are added) live in
  `STANDARDS.md`. Read it once.

## Relationship to actual code repos

Code repos live **alongside** `hq` under `~/projects/` (siblings), not inside it. `hq`
stays lightweight and never nests other git repos. Each `projects/<project>.md` links out
to the real repo path / remote.

## Conventions

See **`STANDARDS.md`** — the single source of truth for how this workspace is run.
