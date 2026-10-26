# 0010. Direct port of the work-authored skill corpus

- **Status:** accepted (2026-07-04) — ratified per user attestation of personal authorship
- **Date:** 2026-07-04
- **Context of:** workspace-wide (skills series; feeds `plans/dev-workspace-base-skills.md`)

## Context

X-context-docs (a separate, read-only source repo; snapshot commit `0e9281e`) holds a
27-skill corpus under `skills/` and a spec-only project record at
`custom-projects/swarm-communication-layer/` — a pub/sub message-bus MCP server design
(Turso/libSQL-backed). The transfer contains no bus source code: `package.json`'s `main`
points at `src/index.js`, which does not exist anywhere in the transfer. The user wants
this corpus available on this machine to seed the dev-workspace initiative rather than
reinventing it.

**Attestation:** the user attests personal authorship of the skills and the bus ("I built
all of those personally"). This is recorded as a **user attestation, not independently
verifiable from files on this machine** — X-context-docs carries no commit-author
metadata this workspace can check. The port proceeds on the attestation as given; if that
basis changes, this ADR's status should be revisited.

## Decision

Port the work-authored skill corpus and the swarm-communication-layer bus **directly**
(adapt, don't rebuild) through the intake pipeline defined in `tools/skill-porting.md`.

- **Source snapshot:** X-context-docs commit `0e9281e` — `skills/` (27 skill directories)
  + `custom-projects/swarm-communication-layer/` (spec docs only). X-context-docs is a
  **read-only source** for the pipeline; ports never edit it — every fix lands in hq.
- **Targets:**
  - Skills → `hq skills/<name>/`, authored per `tools/skill-authoring.md`, installed via
    the ADR 0009 symlink mechanism.
  - Bus → a sibling code repo, `~/projects/swarm-communication-layer` — code repos never
    live inside hq (hq `CLAUDE.md`, "Folder map").
- **Constraint:** bus MCP registration is **project-scoped only** (registered against the
  bus's own repo / the projects that need it). The frozen user-scope MCP list (ADR 0004)
  stays untouched, avoiding a full cache re-verification for an unrelated addition.

## Reasoning

- Direct-port over rebuild-from-scratch: the corpus is attested as already personally
  authored and working; adapting it through a gated pipeline (triage → provenance → refit
  → dependency check → independent verify → install) is cheaper and lower-risk than
  redesigning 27 skills and a bus from spec docs alone.
- Project-scoped MCP registration keeps ADR 0004's frozen user-scope list intact — the
  smallest-blast-radius way to make the bus reachable to the skills that need it.

## Consequences

- Easier: the dev-workspace initiative starts from a working corpus instead of a blank
  page; `tools/skill-porting.md` gives every future work-sourced skill the same gated path.
- Harder / accepted trade-off: authorship is attested, not verified — a known, recorded
  gap, not a blocker.
- **Known gap at acceptance:** the bus's **source code was not included in the transfer**
  (spec docs only — see Context). Remainder of Step 0: the user pushes the actual code
  repo to `~/projects/swarm-communication-layer`. If that turns out to be impossible,
  rebuilding the bus from spec reopens as a **new** decision — this ADR does not
  authorize a rebuild.
- Revisit if: the authorship attestation is later contradicted, or the bus code never
  arrives and a rebuild-from-spec path is chosen instead.

## Alternatives considered

- **Rebuild the bus and skills from scratch on this machine** — rejected for now: the
  corpus is attested as already working; rebuilding 27 skills + a bus from spec-only docs
  is strictly more expensive than adapting attested-working originals, with no evidence a
  rebuild is necessary.
- **Register the bus MCP server at user scope** — rejected: would touch the ADR 0004
  frozen list and force a full cache re-verification for a dependency only a few skills
  need; project scope is the smaller, reversible change.
