# 0056. context-docs retired as the skills backing-store

- **Status:** accepted (2026-10-29) — ratified per user decision
- **Date:** 2026-10-29
- **Context of:** workspace-wide (skills series; builds on ADR 0009, ADR 0010)

## Context

Of the user's 50 installed `~/.claude/skills/*` symlinks, all but one
(`hermes-memory`) pointed into `~/projects/context-docs/skills/` rather than hq.
context-docs serves two distinct roles: a skills backing-store, and a project-records/
knowledge store (status dashboards, per-initiative decisions and learnings under
`projects/`). Only the first role is in scope here — the second was already deliberately
excluded from hq's sanitized carve-out and stays untouched.

15 skill names existed in both repos, each diverged since any earlier porting. Most
diffs were cosmetic or a confirmed hq superset. Two needed real reconciliation work:
`panel-consultation` was resolved by user decision (keep hq's redesigned 9-seat version
as-is, no reconciliation run on context-docs' superseded copy); `pr-review` had genuine
two-way divergence and was reconciled via a new `panel-consultation` `MODE=reconcile`
capability built for this project, with the one residual default-mode question
(`PR_REVIEW_MODE`) resolved by the user's explicit call to keep it as merged.

35 skill names existed only in context-docs. `my-skill` was empty `.gitkeep` scaffolding
and excluded outright. The other 34 were ported via `tools/skill-porting.md`'s existing
seven-gate pipeline, pinned to source snapshot `context-docs@9d7143e`, with one further
exception below.

## Decision

`~/.claude/skills/*` now resolves against hq for every skill except two, both deliberate:

- **`my-skill`** — stays pointed at context-docs' empty scaffold; there is nothing to
  port.
- **`package-release`** — stays pointed at context-docs. Its content documents a manual
  release process superseded months ago by `dft-release-plugin`; porting it as-is would
  install wrong guidance. Rewriting it is separate, undesigned work, not this project's
  scope — per explicit user ruling.

context-docs' skills directory is no longer the backing-store for any installed skill
except these two named exceptions. context-docs itself is **not deleted** and its
project-records role is **unchanged and out of scope** — this ADR governs the skills
role only.

## Reasoning

- **Single source of truth.** hq already owns the skill-authoring standard
  (`tools/skill-authoring.md`) and the porting pipeline (ADR 0010); consolidating the
  backing-store onto hq removes the two-repo drift that caused this project in the first
  place.
- **Trim, don't accumulate.** Every port in this pass actively dropped stale
  cross-references, leaked work-machine paths, and redundant restated content found
  along the way, rather than carrying context-docs' accumulated bloat forward verbatim.
- **Reconciliation is now a repeatable capability, not a one-off.** `panel-consultation`
  `MODE=reconcile` and the new Gate-0 `RECONCILE` triage class in
  `tools/skill-porting.md` mean the next partial-overlap case doesn't require
  re-deriving this plan.
- **Named exceptions over silent gaps.** Both `my-skill` and `package-release` are
  recorded here explicitly so a future skill-porting pass doesn't mistake either for an
  oversight.

## Non-goals

- Deleting context-docs, or any of its project-records content.
- Rewriting `package-release` to document the current `dft-release-plugin` flow — a
  real but separate task.
- Backporting hq-specific capability (e.g. `pr-review`'s `RUN_HOME` in-run dispatch
  mode) into context-docs.
