# panel-consultation — design record (ADR 0011)

One-line summary: a real 9-seat RACI panel — nine independent agent instances, blind dispatch,
no shared context — that reviews architecture decisions, contracts, task specs and designs
(`MODE=review`, default) or reconciles two independently-diverged versions of one artifact into a
merged result (`MODE=reconcile`) — Rung 2 on the review-escalation ladder
(`tools/review-ladder.md`).

## What This Is

**As of 2026-10-29 (commit `591630f`), this is a real 9-seat RACI panel, not a simulation.**
Nine independent Sonnet seat instances read the artifact blind, each Responsible for one of nine
finding topics and Consulted on two others; a fixed R/A/C matrix (`references/seats-raci.md`)
sends every topic with a finding to a fresh Accountable closer; a synthesizer compiles the
closed topics into a findings table; a fixer applies the fix; `fix-verifier` confirms it; the
loop repeats until a Full-tier round reads 0 Blocking / 0 Medium. One Opus sub-agent orchestrates
the whole run — no swarm bus, no live deliberation (independence comes from blind dispatch and
file-based records, not a shared channel). Distinct from `doc-reviewer` (Rung 1 — a fixed
checklist, one agent, against a *finished* artifact) and from `panel-review` (Rung 4 — 11 agents,
bus-quorum deliberation). As of the same commit the skill also supports a `reconcile` mode
(`MODE=reconcile`) that reconciles two independently-diverged versions of one artifact into a
merged best-of-both result, using the same nine seats to classify every delta instead of hunting
defects (`skills/panel-consultation/references/reconcile-brief.md`).

## Components

- `skills/panel-consultation/SKILL.md` — entrypoint: frontmatter (name/description carrying the
  L1 ladder hints), Trigger, Inputs (including `MODE`), Roles and model pins, the orchestrator's
  Steps runbook, Scaling, Reconcile mode, Loop, Independence and secrets, Red flags, Exit
  criteria, Defaults and open questions, Provenance.
- `references/seats-raci.md` — the nine seats (lens, lineage), the topic/RACI matrix and the
  A-close rule, perspective fitting, one-line check definitions per topic.
- `references/briefs.md` — the five dispatch brief templates (seat, A-close, synthesizer, fixer,
  fix-verifier, pre-round check, Low pass) and their common block.
- `references/scaling.md` — the Full/Focused tier mapping and the dispatch-count/concurrency math.
- `references/severity-and-records.md` — severities, record-naming scheme, line shapes, the
  hand-back form, the record-identity screening grep.
- `references/preround-check.md` — the Haiku pre-round mechanical checklist (C1-C8) run before
  every seat round and after every fix.
- `references/patterns.md` — learned failure patterns seats check a session against.
- `references/reconcile-brief.md` (new, 2026-10-29) — the reconcile-mode briefs, classification
  taxonomy (`IMPROVEMENT`/`REGRESSION`/`NEUTRAL`/`CONFLICT`/`MISSING-FROM-BOTH`), `DELTA` line
  shape, and the reconcile-mode record names.
- No `triggers.md` or `preflight.md` — both belonged to the retired simulated design (see
  Discrepancies found, below); not carried into the real-panel redesign.
- Symlink-installed at `~/.claude/skills/panel-consultation` → **should** point at
  `~/projects/agent-hq/skills/panel-consultation` per ADR 0009 convention; verified live
  2026-10-29 via `readlink` and found instead pointing at
  `~/projects/context-docs/skills/panel-consultation` (the retired, pre-591630f simulated
  design) — a stale installation this record surfaces but does not fix (out of this pass's
  scope; the correct source of truth is this repo's checked-in `skills/panel-consultation/`).

Scope note (2026-10-29): the Interfaces/Constraints/Settled decisions/Known gaps sections below
predate the 591630f real-panel redesign and still describe the retired single-context simulated
design (4 named modes, Step 4/Step 5 pre-flight, "no file/artifact produced by default") —
superseded in substance by "What This Is" and "Components" above; left as-is pending a fuller
refresh of their own (out of this pass's stated scope).

## Interfaces

- **Trigger surface:** auto-invoke eligible — no `disable-model-invocation` flag (contrast
  with sibling port `review-validator`, which is manual-only). Fires on a design decision,
  architecture question, contract/task-spec draft, or an idea needing pressure-testing
  before a finished artifact exists.
- **Inputs:** a document/link (read it) or a problem described in conversation — the
  skill is self-contained and needs no external tool to run a session.
- **Outputs:** no file/artifact produced by default — a synthesis (agreements, tensions,
  one ranked concrete recommendation). When Step 5 applies, its result (doc-reviewer
  Checks 1–8 pass/fail) is stated as part of that synthesis.
- **What it points at:**
  - `tools/review-ladder.md` — this skill's own rung (2); the frontmatter description and
    a Red-flags row both encode the up/down pointers (Rung 1 `doc-reviewer`, Rung 4
    `panel-review`), satisfying `review-ladder.md` §5's prompt-hint mechanism.
  - `~/.claude/skills/doc-reviewer/references/checks.md` — Step 5 reuses doc-reviewer's
    canonical Checks 1–8 verbatim rather than carrying a second copy (see Settled
    decisions).
  - `decisions/` and `learnings/` (this workspace) or another live doc workspace —
    Documentation-lookup step, pulled via whatever MCP tools are available, else pasted
    context on request.

## Constraints

- **Token budget:** `SKILL.md` is L2, loaded at runtime — kept as a runbook (steps, table,
  red flags), not design rationale; ADR 0011 rejected putting design prose in `SKILL.md`
  for exactly this reason (its own "Alternatives considered").
- **Read-only, non-side-effecting:** no bus call, no MCP write tool of its own; the entire
  session is simulated in one context. The only external read is the optional
  Documentation-lookup step (existing durable records) and, when it applies, Step 5's read
  of doc-reviewer's `checks.md`.
- **Not a gate by default:** Step 4 states explicitly this is a thinking tool — if the
  panel raises concerns but the decision is to proceed accepting some risk, that is a
  valid outcome.
- **One non-optional path:** Step 5 (pre-flight) is mandatory whenever the artifact under
  discussion is a task spec, contract, or document headed for dispatch or merge — "not
  optional in that case," per both Step 5's own text and a dedicated Red-flags row against
  skipping it.
- **Executor-tier modifier applies** (`tools/review-ladder.md` §3): in a mid-tier-only
  (Sonnet/Haiku) executing environment, an artifact that would otherwise sit at Rung 1
  shifts up to this skill.
- **Mode selection is manual, not inferred:** 4 named modes (Think this through / Quick
  sanity check / Devil's advocate / Retrospective lens) — the agent picks one from context
  cues; there is no fifth "compressed" mode (see Known gaps).

## Settled decisions (port-time rulings, wave 1)

- **`references/preflight.md` retired.** Source carried its own 8-check pre-flight file
  sharing lineage with, but textually diverged from, the already-ported `doc-reviewer`
  checks — a live instance of the corpus's own Pattern B ("cross-contract value drift"),
  this time instantiated between two hq-bound files rather than two contracts. The refit
  deleted the duplicate and repointed Step 5 at doc-reviewer's canonical `checks.md`
  (Hermes skill `learnings/skill-porting` (was learnings/skill-porting.md), "Wave porting: intake review by an already-ported skill
  catches cross-corpus drift").
- **Ladder position fixed as Rung 2**, authored in the same wave as
  `tools/review-ladder.md` itself (plan row P9, immediately before this port, P10).
  `plans/dev-workspace-base-skills.md`'s P10 row attributes this to "resolves doc-reviewer
  self-review M1 (Rung-2 escalation dead-end)" — that finding ID has no independently
  retrievable source: it is not in `doc-reviewer.md`'s own Settled decisions, and it does
  not appear in the Gate-5 live-test fix commit `9e3d268`'s diff. Per doc-reviewer's own
  Check 8 convention (record "unverifiable — source inaccessible" rather than state it as
  settled), this claim is recorded here as unverifiable, attributed only to the P10 note,
  not restated as settled fact.
- **Panel-member renaming (Gate 2 refit):** source's "Notion Organizer" (documentation
  completeness, tied specifically to Notion) ported as "Documentation Organizer" — domain
  retained, concrete tool dependency dropped. This is the one genuine rename: source used
  "Notion Organizer" in both its frontmatter description and its body section header.
  Source's "Context Designer," "Full Stack Engineer," and "Frontend Engineer" were *not*
  renamed at port time — the source's frontmatter description already used those short
  forms while its own body section headers already read "Agent Context Designer," "Staff
  Full Stack Engineer," and "Principal Frontend Engineer" verbatim (source
  `skills/panel-consultation/SKILL.md@0e9281e`). The refit reconciled that pre-existing
  frontmatter-vs-body naming drift by keeping the already-existing fuller body names, not
  by inventing new ones. Panel size held at 9 — not reduced or expanded.
- **Personalization removed:** source addressed a specific named individual throughout
  (first-name references, "reach for Notion"); the installed artifact is written in the
  third-person impersonal, and the source's Notion-specific "When to Reach for Notion"
  section became the generic "Documentation lookup" section above.
- **Exit criteria and Red flags sections added** — absent upstream, added per
  `tools/skill-authoring.md` convention at Gate 2 refit (same convention applied to
  sibling port `review-validator`).

## Known gaps (wave-1 live-test follow-ups, advisory — not blocking)

- No named "compressed" mode — live testers had to improvise one.
- `references/triggers.md`'s phase organization (Cold Read → Contract Authoring → …) is
  infra/Docker-flavored and reads awkwardly when the artifact under discussion isn't
  infra work.
- Step 5's applicability trigger ("headed for dispatch or merge") is ambiguous for
  already-merged standing docs.
- doc-reviewer's `checks.md` vocabulary is infra-heavy when reached from this skill's
  Step 5 — same shared-corpus root cause as the `triggers.md` note above.

(`plans/dev-workspace-base-skills.md`, "Wave-1 live-test follow-ups (advisory)".)

## Discrepancies found — mined docs vs. installed artifact (artifact wins)

- Source `SKILL.md` names 9 members without stating a ladder rung or up/down pointers
  (`tools/review-ladder.md` postdates the source). The installed artifact adds the Rung-2
  framing throughout (frontmatter, Trigger, a Red-flags row) — a port-time addition, not
  an upstream behavior; this record follows the installed artifact.
- Source's Step 5 points at its own `references/preflight.md`; the installed artifact has
  no such file and points at doc-reviewer's `checks.md` instead (see Settled decisions) —
  where the two disagree on which checks are canonical, the installed artifact's pointer
  is what this record describes.
- Source has no "Red flags" or "Exit criteria" sections; both are Gate 2 refit additions,
  absent upstream.

## Source lineage

Lineage: X-context-docs `skills/panel-consultation@0e9281e` (commit verified against the
X-context-docs repo), ported via the seven-gate pipeline (`tools/skill-porting.md`),
wave 1, plan row P10 (`plans/dev-workspace-base-skills.md`; evidence: commit `1c33b72` +
live test). Provenance footer as shipped in the installed artifact:
Hermes skill `learnings/skill-sharing` (was learnings/skill-sharing.md) (recorded port friction motivating the porting initiative);
the panel-consultation-specific port finding (preflight retirement) is recorded separately
in Hermes skill `learnings/skill-porting` (was learnings/skill-porting.md), cited above under Settled decisions.
