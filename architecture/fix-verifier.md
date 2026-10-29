# fix-verifier — post-fix gate design record (ADR 0011)

One-line summary: a single synchronous agent that runs 5 targeted checks against only the
files a fix agent just changed, and returns CLEAN or ISSUES_FOUND before the heavier
panel-review is dispatched — no swarm bus, no waves, no quorum.

## What This Is

A fast quality gate that sits between a fix agent finishing a correction and the next
review stage. It reads only `changed_files` (plus optionally `related_files`), runs 5
checks sequentially in one Agent-tool dispatch, and reports a verdict + finding list. It
never dispatches, writes, or halts anything itself — the orchestrator does all of that,
reading the verdict fix-verifier returns.

## Components

- **`skills/fix-verifier/SKILL.md`** — the entire skill; no `references/` subdirectory,
  no scripts. One file, both in source and as installed.
- **Two roles defined inline** (not elsewhere in hq): the **fix agent** — whatever agent
  applied the correction being verified (a named skill, a corrective skill, or a
  general-purpose agent instructed to make the change; a role, not a specific skill) —
  and the **corrective agent** — dispatched on `ISSUES_FOUND`, may be the same fix agent
  re-prompted or a dedicated corrective skill; the orchestrator picks.
- **The 5 checks**, run sequentially against `changed_files` only: Check 1 Internal
  Consistency (self-contradictions within one changed file), Check 2 Cross-Reference
  Symmetry (do files changed-files reference still contain the referenced thing), Check 3
  Fix Completeness (was a term/value change from the diff applied everywhere it occurs
  in `changed_files`), Check 4 No New Orphan References (do extracted links/paths/headings
  still resolve on disk), Check 5 Line Limit Compliance (no changed file exceeds 200
  lines).

## Interfaces

- **Trigger surface**: dispatched via the Agent tool only — `claude -p` (CLI subprocess)
  is explicitly not supported. Caller must wait for the fix agent to fully finish and
  write to disk first; concurrent dispatch is an explicit anti-pattern ("undefined
  results — changed files may be partially written").
- **Input contract**: `changed_files` (required, non-empty, absolute paths — empty input
  returns an error object, not a verdict), `fix_description` (required, context for Check
  3), `diff` (optional but strongly recommended — without it Check 3 degrades to
  prose-level analysis), `related_files` (optional — auto-discovered if omitted),
  `session_context.iteration` (optional — absence treated as iteration 1 plus an Advisory
  finding).
- **Output contract**: `{verdict: CLEAN|ISSUES_FOUND, findings[], files_checked,
  files_not_checked, session_context}`. `CLEAN` requires zero Blocking/Medium findings; a
  timeout always forces `ISSUES_FOUND` regardless of what finished. `session_context` is
  echoed verbatim — fix-verifier is stateless across calls, the orchestrator owns
  iteration count.
- **What it points at**:
  - `tools/review-ladder.md` — fix-verifier's own SKILL.md Red flags table cites this file
    to place a full first-pass review at "doc-reviewer (Rung 1) or above"; review-ladder.md
    itself never mentions fix-verifier, confirming fix-verifier is off-ladder.
  - `doc-reviewer` — the alternative for first-pass/whole-document review.
  - `review-validator` — the alternative for validating existing panel-review PR comments.
  - `panel-review` — the intended downstream consumer on a `CLEAN` verdict.
  - `tools/skill-authoring.md` §3 — referenced only to disclaim overlap: that standard's
    ≤5,000-token/≤500-line **L2 skill-body** budget governs skill files themselves, not
    the 200-line cap Check 5 applies to arbitrary changed files. Confirmed independently:
    `tools/skill-authoring.md` line 66 states the ≤5,000-token L2 target.

## Constraints

- **Read-only / non-dispatching by design**: "never writes files, never executes shell
  commands, never dispatches agents." This is stated three times across the skill
  (Steps, Agent Model, Security) — a deliberate, repeated invariant, not an incidental
  detail.
- **Runtime budget**: target under 60 seconds for 1–5 changed files (~10s/file);
  hard timeout 90 seconds (1.5× target). A timeout downgrades to a check-0 Advisory
  finding but still forces `ISSUES_FOUND` — the loop is never blocked on a hung verifier.
- **Loop cap**: iteration ≥ 3 appends a check-0 Blocking "max iterations reached" finding
  and forces `ISSUES_FOUND` regardless of other findings — the orchestrator halts, it does
  not keep re-running. Two prior `ISSUES_FOUND` results is what makes the third run
  iteration 3.
- **Security / path handling**: all `changed_files`/`related_files` paths must be
  canonicalized (realpath-equivalent) *before* the project root is computed — root
  computed from an uncanonicalized path is invalid by construction. Root-marker
  precedence: `.git` > `package.json` > `CLAUDE.md`, walking up from `changed_files[0]`;
  fallback is `dirname(changed_files[0])`. A root that resolves to `/` is rejected
  outright. `changed_files`/`related_files` paths outside the computed root are rejected —
  either the benign "outside project root" case or, if only outside root after
  canonicalization, the "path traversal attempt" case; both are recorded in
  `files_not_checked`. Exception: auto-discovered cross-references (parsed from file
  content, not caller-supplied) resolving outside root are skipped silently by design.
- **Check 5's 200-line cap is fix-verifier's own house rule** on changed files — separate
  from, and not superseded by, the hq skill-body budget above (installed artifact states
  this explicitly; source does not).
- **Known cap gap (Wave-1 live-test follow-up, unresolved, advisory-only)**: Check 5's
  flat 200-line cap fires even on files that were already over 200 lines before the fix
  (no pre-existing-length exemption). Also open: Checks 2/4 don't state whether the
  reference-crawl scope is whole-file or diff-only, and the Output Contract doesn't state
  whether `files_checked` includes auto-discovered files. None of these block a verdict
  today; they're recorded, not fixed, per `plans/dev-workspace-base-skills.md`.

## Settled decisions (port-time rulings, wave 1)

- **PORT, not ADAPT/RULING-NEEDED**, at Gate 0 intake — its own description already
  states "no swarm bus, no waves, no quorum," so it carried no work-coupled dependency to
  strip (`plans/dev-workspace-base-skills.md` P-row for fix-verifier).
- **Originating precedent for "no nested CLI subprocess" dispatch**: this skill's Agent
  Model section ("Invoked via the Agent tool ... not CLI subprocess") is the ruling later
  ported skills point back to rather than re-litigate — `architecture/review-validator.md`
  cites it by name as the settled source of its own no-nested-CLI convention.
- **`files_not_checked` reasons split from 3 to 4**, each mapped to exactly one condition,
  no overloading — see Discrepancies below; this is the one behavioral (not just prose)
  change made at port time.
- **Frontmatter trimmed to hq's two-field convention** (`name` + `description` only) —
  matches every other installed skill; no skill in `~/projects/agent-hq/skills/*/SKILL.md`
  carries a `status:` key.
- **Refit into the Trigger → Steps runbook shape** used by every other ported skill
  (`tools/skill-porting.md` Gate 2), adding a **Red flags** table and an **Exit criteria**
  checklist not present in the source's flatter section layout.
- **Verdict/routing ownership stays with the orchestrator**: fix-verifier reports only —
  restated at three separate points (Steps step 5, Workflow Position, How to Invoke) so no
  future refit can quietly hand it dispatch authority.

## Discrepancies found — mined docs vs. installed artifact (artifact wins)

1. **Structure**: source is a flat set of `##` sections (When to Use, Workflow Position,
   Input Contract, Agent Model, ...). Installed artifact nests almost all of that under a
   numbered `## Steps` runbook and adds **Red flags** + **Exit criteria** + **Provenance**
   sections the source doesn't have — the Gate 2 refit shape, not a source feature.
2. **`files_not_checked` reasons**: source lists 3 (`out of scope`, `access error`,
   `access denied — outside project root`) and calls the first two "SKILL.md-level
   additions to the architecture-specified third reason" — implying an upstream spec the
   source itself doesn't show. Installed artifact has 4, splitting the third into a
   benign "outside project root" case and a distinct "path traversal attempt" case tied to
   the Security canonicalization rule. Real behavioral clarification, not just prose.
3. **Check 5 rationale**: source cites "the CLAUDE.md global rule" as the 200-line cap's
   justification but never names which rule/file/section, and no such 200-line global rule
   exists in this workspace's own CLAUDE.md/STANDARDS.md (STANDARDS.md's one 200-line
   mention is scoped to a different artifact type). Installed artifact's disclaimer — this
   is fix-verifier's own house rule, not the same as, and not superseded by, the hq
   skill-body budget (`tools/skill-authoring.md` §3) — is the correct resolution; the
   source's cross-reference was vague/unverifiable, not absent.
4. **Cross-reference honesty**: source states the `loop-controller`/`panel-review`
   relationships as flat fact. Installed artifact adds the caveat that neither
   relationship is reciprocated yet in the other skill's own file — "treat as an intended
   integration, not a confirmed one." Carried into the Interfaces section above.
5. **Role definitions**: installed artifact adds an explicit inline definition block for
   "fix agent" / "corrective agent" in its Trigger section; source uses both terms without
   ever defining them as a distinct block.
6. **Frontmatter**: source has `status: experimental`; installed has no `status:` field —
   consistent with hq's two-field convention (see Settled decisions), so this is an
   intentional drop, not a loss.
7. **Provenance footer**: installed artifact carries a `Provenance:` line pointing to
   Hermes skill `learnings/skill-sharing` (was learnings/skill-sharing.md) plus a `Lineage:` line; source has neither (it is the
   origin, so this is expected, not a gap).

## Source lineage

Lineage: X-context-docs skills/fix-verifier@0e9281e. Provenance: Hermes skill `learnings/skill-sharing` (was learnings/skill-sharing.md)
(recorded port friction — no standardized skill-export path existed at port time). Port
evidence: `plans/dev-workspace-base-skills.md` P11 (done, live-tested against a real fix).
Line-count and check-behavior gaps: `plans/dev-workspace-base-skills.md` Wave-1 live-test
follow-ups section.
