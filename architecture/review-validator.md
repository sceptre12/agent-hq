# review-validator — design record (ADR 0011)

One-line summary: single-file native skill that triages an existing automated PR review's
comments into Valid / Needs-Verification / Invalid, and posts the triage only after
explicit human confirmation.

## What This Is

A downstream **companion** to the review-escalation ladder (`tools/review-ladder.md`), not
a rung on it: it validates an existing automated review's findings rather than generating
a review itself. Manual-only (`disable-model-invocation: true`) — an engineer invokes it
deliberately when a PR already carries comments matching its detection markers.

## Components

- `skills/review-validator/SKILL.md` — the **only** file (verified: no `references/`, no
  scripts, no supporting assets). Symlink-installed at
  `~/.claude/skills/review-validator` → `~/projects/agent-hq/skills/review-validator`
  (ADR 0009 convention, confirmed live).
- Sections inside the single file: frontmatter (name/description/
  `disable-model-invocation`), Trigger, Execution Model, 6 Steps, Output Format, Common
  False Positive Patterns table, Network Unavailable, Red flags, Exit criteria,
  Provenance/Lineage.

## Interfaces

- **Trigger surface:** manual-only — no auto-invoke. Fires when a PR carries one or more
  review comments containing "🤖 Automated panel review", "## Combined Review",
  "## Panel Review", or "## Code Review Panel" (detection markers, see caveat below).
- **Inputs:** PR number + `owner/repo`, fetched via `gh pr diff`, `gh api .../comments`,
  `gh api .../reviews` (Step 1).
- **Outputs:** a Valid / Needs-Verification / Invalid markdown report, rendered in chat
  first (Step 5) and posted via `gh pr comment` only after explicit engineer confirmation
  (Step 6) — never chained automatically. "Net actionable items" tally counts
  Blocking/Medium only; Advisory-valid findings appear in the table but are excluded from
  the tally.
- **What it points at:**
  - `tools/review-ladder.md` — Rung 1 (`doc-reviewer`) for a fresh routine review with no
    existing comment to triage; Rung 4 (`panel-review`) for a fresh fuller review.
  - `tools/model-routing.md` Rule 3/4 — governs delegation of the mechanical steps.
  - `skills/fix-verifier`'s "Agent Model" section — settled the no-nested-CLI ruling this
    skill also follows (verified present in the installed fix-verifier artifact).
  - Not-yet-ported `network-check` skill — soft dependency, RULING-NEEDED
    (`plans/dev-workspace-base-skills.md`). The source's script path is work-corpus
    layout and does not exist on this machine; a real path lands only if/when
    network-check is ported.

## Constraints

- **Mixed-model execution:** Steps 1, 2, 5, 6 (fetch/parse/format/post) are Haiku-eligible
  and delegated via the Agent tool with an explicit model pin, never a `claude -p` CLI
  subprocess — hq's dispatch convention doesn't support that path. Steps 3–4
  (diff-reading + classification judgment) require Sonnet and are never delegated.
- **Side-effecting, but gated:** Step 6 (`gh pr comment`) is the only side-effecting
  action and fires only after the engineer explicitly confirms the Step 5 chat report —
  no automatic Step-5-to-Step-6 chaining.
- **Network dependency:** up to 4 outbound `gh` calls (diff, 2x api read, comment post).
  No confirmed local pre-check exists yet — the primary path is interactive graceful
  decline; the script/launchd exit-0-skip branch is retained for parity with other
  outbound-call skills but is **not** a confirmed active integration (review-validator is
  absent from network-check's own "launchd apps" list, present only under "skills with
  outbound calls").
- **Line budget:** no cap stated inside the skill itself; this architecture doc is bound
  by the workspace-wide fix-verifier Check 5 flat 200-line cap (dev-workspace-base-skills.md
  Wave-1 follow-up).

## Settled decisions (port-time rulings, wave 1)

- **Ladder relationship hardened at port:** explicit "downstream companion, not a rung"
  framing, with Rung 1/4 cross-references, added during Gate 2 refit.
- **Step 6 confirmation gate hardened at port:** source's Step 5 only said render the
  report "so the engineer can review it first"; the installed version adds an explicit
  Red-flag entry and an Exit-criteria checklist item forbidding auto-chaining to Step 6.
- **Dispatch mechanism:** Agent tool + explicit model pin only, no nested `claude -p`
  subprocess — this exact question was settled once, by fix-verifier's port, and
  review-validator's port reused that ruling rather than re-litigating it.
- **Detection-marker caveat carried forward, deliberately unresolved:** none of the four
  marker strings appear anywhere else in the accessible corpus — not even in
  panel-review's or pr-review's own synthesizer-brief report-format specs. The port did
  not invent a resolution; it recorded the caveat as an explicit trigger for a human
  ruling if a triage run ever turns up nothing.
- **Wave-1 live-test follow-ups (advisory, not yet actioned):** Step 2 doesn't state
  whether one matching marker suffices to begin parsing; the marker-provenance caveat
  remains open; Steps 1/6 example commands assume a live PR context.
- **Provenance retained from source's own recorded friction:** Hermes skill `learnings/skill-sharing` (was learnings/skill-sharing.md).

## Discrepancies found — mined docs vs. installed artifact (artifact wins)

- Source `SKILL.md` (X-context-docs) carries no `disable-model-invocation` flag and a
  two-line description; the installed artifact adds `disable-model-invocation: true` and
  a longer, ladder-cross-referencing description — a Gate 2 refit addition, not an
  upstream behavior.
- Source's Network Unavailable section treats the launchd/exit-0 script branch as
  straightforwardly applicable; the installed artifact demotes it to "forward-compatible,
  not a confirmed unattended path today" after cross-checking network-check's own
  integration list.
- Source has no "Red flags" or "Exit criteria" sections; both are Gate 2 refit additions
  per hq's skill-authoring convention, absent upstream.
- Source's Step 6 has no explicit confirmation-gate language beyond Step 5's framing; the
  installed artifact adds the explicit no-auto-chain rule (see Settled decisions).

## Source lineage

Lineage: X-context-docs `skills/review-validator@0e9281e`, ported via the seven-gate
pipeline (`tools/skill-porting.md`), wave 1, plan row P12
(`plans/dev-workspace-base-skills.md`; evidence: commit `a23a2bf` + live test).
Provenance: Hermes skill `learnings/skill-sharing` (was learnings/skill-sharing.md) (recorded port friction).
