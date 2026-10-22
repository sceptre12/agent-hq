# doc-reviewer — design record (ADR 0011)

One-line summary: single-agent, 10-step / 3-phase (Discovery → Decision → Resolution)
checklist-review skill for architecture docs, addendums, task specs, and standards —
Rung 1 on the review-escalation ladder; finds and presents issues, never auto-applies a fix.

## What This Is

Catches errors iterative editing introduces: contradictions across edit rounds, claims
that drift from source code, and cross-cutting contract conflicts that only surface when
every reference is actually checked. Positioned deliberately in the middle of the ladder —
cheaper than a simulated or real multi-agent panel, stronger than an unstructured read.
First skill through `tools/skill-porting.md`'s seven-gate pipeline (Gates 0–6), used as the
pipeline shakeout before any other skill or the bus port.

## Components (files + roles)

- **`skills/doc-reviewer/SKILL.md`** (139 lines, verified) — entrypoint: frontmatter
  `description` (ladder-rung hint + trigger phrases, always-loaded L1), `## Trigger`
  (restates when to use + the 4 inputs to gather), `## Steps` (the 14-row check table +
  numbered Phase A/B/C steps 1–10), `## Red flags` (8-row rationalization table), `##
  Exit criteria` (5-item checklist), `## Provenance` (lineage line).
- **`skills/doc-reviewer/references/checks.md`** (717 lines, verified) — full spec for all
  14 checks (purpose, what-to-check, verdict scale, worked failure/pass examples), plus
  Severity Classification, Panel Composition, the Multi-Wave Spec Protocol, and the Key
  Learnings list (14 entries) — all four of these sections live only here, not in
  `SKILL.md` (see Constraints). `SKILL.md`'s check table is declared the authoritative row
  count; `checks.md` is declared stale if the two diverge.

## Interfaces

- **Trigger surface:** frontmatter `description` (L1, always in context) states the
  10-step/3-phase shape and fires on "review this doc," "run the checks," "cold read
  this," "check for conflicts," "is this ready to ship," or a document that has been
  through 2+ editing rounds and needs a quality gate before dispatch.
- **Inputs (gathered before Step 1):** the document (file, pasted text, or a wiki/doc
  link); the project's contracts/interfaces directory *if one exists* (Step 4's matrix is
  skipped when it doesn't); source code access (for Check 8, only if the doc modifies
  existing files); context on what the doc changes (net-new vs. edit vs. new standard).
- **Outputs:** a compiled findings table (`# | Issue | Severity | Check | Recommended
  Fix`) with severity totals, the cross-cutting matrix (conditional), the architectural
  impact verdict, and an overall READY / NOT READY / READY WITH CONDITIONS call — all
  presented for a human decision before Phase C touches anything.
- **What it points at:**
  - `tools/review-ladder.md` — self-identifies as **Rung 1**; escalate to
    `panel-consultation` (Rung 2) for contested/multi-system reviews; drop to Rung 0
    (direct review, no skill) for typo-level checks. The `description` states this
    inline per review-ladder.md §5's prompt-hint mechanism, and one `## Red flags` row is
    the ladder row §5 requires.
  - `tools/skill-authoring.md` — the anatomy this skill was refit to (Trigger / Steps /
    Red flags / Exit criteria / Provenance), and the §3 token-budget rule that shaped the
    SKILL.md/checks.md split below.
  - `superpowers:writing-plans` — inferred, not cited: Check 1's "Writing-plans
    standards" and Check 7's "Writing-plans pre-check" section headers name no skill in
    `checks.md`; the phrase matches this skill by name, not `writing-skills` below.
  - `superpowers:writing-skills` — Key Learning 13's rule that new checks must be
    validated against a real failing case before shipping, explicitly cited in
    `checks.md` ("Per `superpowers:writing-skills`: ...").
  - `superpowers:verification-before-completion` — Check 13 (AC Runability) is derived
    directly from its Iron Law ("no completion claims without fresh verification
    evidence"), applied to acceptance criteria instead of task completion.
  - **Consumed by:** `panel-consultation` (Rung 2) points at this skill's `checks.md`
    vocabulary from its own Step 5 — established as the corpus's canonical check spec
    (see Settled decisions).

## Constraints

- **Token budget:** hq's per-skill rule is `SKILL.md` body ≤5,000 tokens (L2), overflow
  moved to `references/` (`tools/skill-authoring.md` §3). Verified: `SKILL.md` is 139
  lines; the four sections that would have pushed it over (Severity Classification, Panel
  Composition, Multi-Wave Spec Protocol, 14-entry Key Learnings) live only in the 717-line
  `checks.md` instead.
- **Read-only vs. side-effecting:** Phases A and B (Steps 1–8, Discovery + Decision) never
  edit anything — they only produce findings and wait for a decision. Phase C (Steps 9–10)
  is the sole side-effecting stage, and it is gated: Step 8 requires an explicit, scoped
  confirmation ("apply these, defer those") before any edit lands, and Step 10 re-verifies
  coherence after. Core principle, stated verbatim in `SKILL.md`: "every finding is
  presented for a decision before any edit is applied. Never auto-apply fixes." The
  skill's report is a decision request, not an execution request.
- **Invocation flags:** none. One entry path, no modes/flags — branching is internal
  (which of the 14 checks apply, per the table's "Applies to" column; Check 8 skipped for
  net-new specs; Checks 9–14 conditional on spec shape).
- **Bus dependency:** none live. `checks.md` Check 14 (Flow-Scope Check) mentions
  `bus-schema.md`/`agent-roles.md` as things to check *when reviewing a bus-dependent
  artifact* — that is doc-reviewer inspecting another skill's bus usage, not doc-reviewer
  itself calling `send_message`/`read_messages`/`broadcast`. Settled as a false positive
  (see Settled decisions) — this is why doc-reviewer could port and install with no Gate 3
  parking, first in the ratified order, ahead of the bus.

## Settled decisions (port-time rulings — record, do not reopen)

- **De-work-ified framing.** The source skill was scoped to one company's wiki-hosted
  doc set with a hardcoded contracts-directory path and personal-name framing throughout.
  Gate 2 generalized the contracts directory to "the project's contracts/interfaces
  directory, if one exists" (Step 4's matrix becomes N/A when absent) and stripped all
  company/product/personal-name references from `description` and body text.
  **Discrepancy vs. mined planning doc:** `plans/architecture-backfill.md`'s B2 dispatch
  row says to mine "X-context-docs custom-projects/doc-reviewer/" — that path does not
  exist. The read-only source actually lives at `X-context-docs skills/doc-reviewer/`,
  confirmed by directory listing and by the installed artifact's own `Provenance` line
  (`Lineage: X-context-docs skills/doc-reviewer@0e9281e`, commit verified in
  X-context-docs history). Artifact wins; the plan row's path is stale.
- **Structural refit.** Source had no `## Trigger`, `## Red flags`, `## Exit criteria`, or
  `## Provenance` sections — these were added wholesale to satisfy
  `tools/skill-authoring.md`'s anatomy, not migrated from anything in the source.
- **Ladder-hint embedding.** Per `tools/review-ladder.md` §5, the refit `description` now
  states its rung and points one rung each way; one `## Red flags` row is the required
  ladder row (escalate to panel-consultation when a review is genuinely contested).
- **checks.md established as the corpus's canonical check spec.** Wave-1 porting of
  `panel-consultation` found its source carried its own divergent `preflight.md` sharing
  lineage with, but textually diverged from, doc-reviewer's checks. The refit retired that
  file and repointed `panel-consultation` at this skill's `checks.md`
  (Hermes skill `learnings/skill-porting` (was learnings/skill-porting.md), "Wave porting" entry).
- **Gate 4 caught an undeclared content drop** during refit — a "gather" item silently
  lost in refit despite disciplined, declared de-work-ification — fixed before Gate 5/6
  closed (Hermes skill `learnings/skill-porting` (was learnings/skill-porting.md), "First port shakeout" entry; commit `9855df8`).
- **Gate 5 live test** (a fresh instance running the installed skill against
  `tools/review-ladder.md`) caught a cross-standard gap — review-ladder.md §5's Gate-2
  requirement wasn't cross-referenced in `skill-porting.md`'s own Gate 2 — plus two minor
  port defects invisible to document-only review; fixed in commit `9e3d268`.
- **Bus-dependency false positive, ratified.** `plans/dev-workspace-base-skills.md`
  footnote 1: the Gate-0 grep hit on `bus-schema.md` in `checks.md` is doc-reviewer
  *reviewing other artifacts' bus schemas*, not a functional bus call — judged a false
  positive so doc-reviewer keeps its "no deps" position first in the ratified port order.

## Source lineage

Provenance: Hermes skill `learnings/skill-sharing` (was learnings/skill-sharing.md) (the recorded port friction this whole pipeline
traces to).
Lineage: X-context-docs `skills/doc-reviewer@0e9281e`.
Port pipeline: `tools/skill-porting.md` Gates 0–6, commits `9855df8` (initial port, Gates
0–4) and `9e3d268` (Gate 5 live-test fixes); tracked as
`plans/dev-workspace-base-skills.md` row P2 (done).
