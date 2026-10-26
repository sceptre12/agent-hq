# 0009. Skills authored in hq, symlink-installed

- **Status:** accepted (2026-07-03) — ratified per user ruling on P4 open-question A
- **Date:** 2026-07-03
- **Context of:** workspace-wide (skills series; standard in `tools/skill-authoring.md`)

## Context

The skills series needed a home before the first skill is written. The Q4 ruling
(addy-alignment-plan.md §6, 2026-07-02) settled the *format* — native Claude Code
skills — but not *where the source lives*. Claude Code discovers native skills under
`~/.claude/skills/`, which sits outside hq: outside git, outside review, and outside
the push-is-backup durability mechanism (ADR 0006). hq's provenance discipline
(every skill traces to recorded friction — `tools/skill-authoring.md`) is only
enforceable where skills pass through review. The user ruled on 2026-07-03
(P4 open-question A); this builds on the Q4 ruling (native format) and plan item
P4.2 (first skills, pending).

## Decision

hq skills are **authored in hq** at `skills/<name>/SKILL.md`, per the standard in
`tools/skill-authoring.md`. Each skill is **installed by symlinking the skill
directory** into `~/.claude/skills/<name>`. Claude Code's native format follows
symlinks (verified in `tools/skill-authoring.md` §1), so an installed skill behaves
identically to a physical copy while the bytes live in exactly one place.

## Reasoning

- **hq stays the single owner** (ADR 0003 one-owner discipline): the skill source is
  git-versioned, reviewable, and covered by push-is-backup (ADR 0006). The symlink
  adds no second copy that could drift.
- **Provenance is enforceable at review:** skills must trace to recorded friction;
  that check happens where the skill is committed — in hq, not in an unversioned
  dot-directory.

## Consequences

- Easier: skills get git history, diff review, and backup for free; a skill edit is
  an ordinary hq commit; uninstalling is deleting a symlink.
- Harder / accepted trade-off: one symlink-install step per skill (and again after a
  fresh clone), same class of one-time setup as `core.hooksPath` (ADR 0007).
- The `skills/` directory does not exist yet — it is created by the first skill
  (plan item P4.2), not by this ADR.

## Alternatives considered

- **Author directly in `~/.claude/skills/` with hq holding pointers** — rejected:
  skills would live outside git/backup and weaken the one-owner/provenance
  discipline this workspace is built on.
