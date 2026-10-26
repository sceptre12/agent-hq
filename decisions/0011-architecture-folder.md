# 0011. Architecture folder — design record precedes build work

- **Status:** accepted (2026-07-04) — ratified per user decision, verbal
- **Date:** 2026-07-04
- **Context of:** workspace-wide (new top-level folder; backfill tracked in
  `plans/dev-workspace-base-skills.md`)

## Context

hq has `plans/` (execution and dispatch tracking — status tables, what's done and by
whom) and `tools/` (how-to standards — the mechanics of doing a thing). Neither holds a
system's **design** — its components, interfaces, constraints, and the decisions already
settled about its shape. Design narrative currently either doesn't exist in writing or
leaks into plan files, where it churns alongside execution status and gets buried.

The user has adopted a new global Rule 5: **architecture first, dispatch plan second,
action last** — no substantive build without a ratified design record and a dispatch plan
derived from it. hq needs a folder that is the record Rule 5 points to, distinct from
`decisions/` (why we chose this, decision authority) and `plans/` (what's done, execution
state).

Several skills are already shipped without such a record: `doc-reviewer`,
`panel-consultation`, `fix-verifier`, `review-validator`, `skill-export`. Upstream design
material for some systems already exists outside hq — e.g. X-context-docs project spaces
(the source for the ported skill corpus, ADR 0010) — but it was authored for a different
context and hasn't been checked against what's actually running here.

## Decision

hq gains a top-level `architecture/` folder holding **one design record per
system/skill** — WHAT it is and WHY it's shaped that way (components, interfaces,
constraints, settled decisions) — distinct from `plans/` (execution/dispatch tracking)
and `tools/` (how-to standards).

- **One file per system:** `architecture/<slug>.md`.
- **Reuse upstream design material where it exists** (e.g. X-context-docs project
  spaces) — validated against ground truth and updated, never blind-copied.
- **Cite sources:** architecture docs record lineage (e.g. a ported skill's upstream
  origin) where applicable.
- **Precedence unchanged:** ADRs still rank above everything (see hq `CLAUDE.md`).
  Architecture docs are descriptive design records, not decision authority — a
  conflict between an architecture doc and an ADR resolves in the ADR's favor.
- **Existing shipped skills get architecture records BACKFILLED**, tracked as plan items
  in `plans/`, rather than being re-ported through the intake pipeline again.

## Reasoning

- Design and execution state have different volatility: execution churns every session,
  design should only change when the system's shape actually changes. Mixing them in
  `plans/` means design gets overwritten or buried by status noise.
- A dedicated WHAT/WHY layer gives Rule 5 a concrete artifact to gate on — "is there a
  ratified design record" is checkable only if design records live somewhere consistent.
- Backfilling existing skills (rather than re-running them through the port pipeline)
  is the cheaper path: the skills are already shipped and working; what's missing is the
  written record, not the artifact.

## Consequences

- Easier: Rule 5's gate ("architecture ratified → dispatch plan → execution") has a
  concrete home to point at; future systems get a WHAT/WHY record that outlives any one
  plan's churn; upstream design material (X-context-docs project spaces) has a validated
  landing spot instead of being blind-copied or ignored.
- Harder / accepted trade-off: one more folder to keep in sync — an architecture doc that
  drifts from the running system is worse than none; backfilling five existing skills is
  added, tracked work before new build work under Rule 5 can claim a clean slate.
- Revisit if: architecture docs start duplicating `plans/` execution detail (sign the
  boundary isn't holding) or duplicating ADR decision authority (sign precedence needs
  restating).

## Alternatives considered

- **Design sections inside each plan file** — rejected: plans are execution state:
  status-table churn would bury design, and design would need to be reconstructed from
  scattered updates rather than read as one settled record.
- **Design inside each skill's `SKILL.md`** — rejected: `SKILL.md` is L2 token budget
  loaded at runtime; skills are runbooks, not rationale, and design prose would bloat the
  budget every skill invocation pays.
