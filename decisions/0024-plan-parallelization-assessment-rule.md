# 0024. Plan-authoring parallelization assessment rule (new global Rule 7)

- **Status:** accepted (2026-07-22) — Fable-ratified with suggested changes, applied; ratified per user decision
- **Date:** 2026-07-22
- **Context of:** workspace-wide (amends `~/.claude/CLAUDE.md`, not scoped to hq)

## Context

The owner wants a new global rule so agents assess, at plan-authoring time, how much of a
piece of work has genuine *safe* parallelism — imagining up to ~30 concurrent agents as a
stress-test ceiling — before deciding a plan's structure (parallel vs serial). Research
conducted for this decision found **nothing currently does this at planning time**:

- `wave-execution`'s `dispatch_budget` (ADR 0023, D4) and its deferred, unbuilt
  `max_concurrent` (ADR 0023, D5) are **runtime backstops** — they refuse or cap an
  over-large dispatch *after* a plan has already proposed it. Neither reasons about
  whether the split was safe or economical to propose in the first place.
- The `dispatching-parallel-agents` skill has a binary safety criterion (shared state →
  don't parallelize) but no cost framing, and is scoped to investigation work, not plan
  authoring.
- The `subagent-driven-development` skill has a cost-vs-difficulty model-tier framework
  (analogous to global CLAUDE.md Rule 4) but explicitly bans parallel dispatch for
  implementation and doesn't address parallelism-*shape* decisions at all.
- A separate, deliberately **unrelated** hq inbox item exists:
  `~/projects/agent-hq/inbox/writing-plans-wave-execution-option.md`, which proposes teaching
  the `writing-plans` skill specifically to detect parallelizable plans and offer
  `wave-execution` as a third handoff option. The owner explicitly decided to **keep this
  separate** from the new rule below — the two are related-but-distinct efforts, and this
  ADR does not resolve or supersede that inbox item.

No existing mechanism, in other words, sits at the moment a plan is *written* and asks
"how much of this is safely parallel, and is splitting it worth the coordination cost?"
That gap is what this ADR closes.

## Decision (accepted — Fable-ratified with suggested changes, applied; ratified per user decision on 2026-07-22)

Add a new global rule, **Rule 7**, to `~/.claude/CLAUDE.md`, immediately after the
existing Rule 6 ("Repo Work Happens in Worktrees; the Default Branch Is for Integration
Only"). The rule text below is the verbatim content to insert:

> ## Rule 7 — Assess Parallelization at Plan-Authoring Time
>
> - **Trigger/scope:** This fires any time ANY plan or spec is authored, anywhere — not
>   limited to hq's Rule 5 dispatch-plan step. It covers Rule 5 dispatch plans,
>   `writing-plans` specs, `wave-execution` spec_roots, and any other multi-step
>   implementation plan, in any repo or project.
> - **Stress-test framing:** The author imagines up to ~30 agents being available for the
>   work as a thought-experiment ceiling, NOT a literal fleet-size target. Its purpose is
>   to force genuinely checking which pieces could run concurrently, instead of defaulting
>   to serial structure or reflexively over-splitting. The actual agent count used is
>   whatever the safety and cost bars below allow — usually far below 30.
> - **Safety bar:** A split counts as "safe" ONLY if the parallel pieces share no mutable
>   state. That covers, at minimum: no same-file edits; no shared git-checkout/branch state
>   (per Rule 6, concurrent pieces need their own worktree even when they don't overlap on
>   files — this is why `subagent-driven-development` bans parallel implementation dispatch
>   even absent file overlap); no shared external resources (ports, dev servers, databases,
>   rate limits, lockfiles); and no output-to-input dependency between them. These examples
>   are illustrative of the shared-mutable-state principle, not an exhaustive list — anything
>   with cross-task dependencies stays serial, or becomes a later phase/wave once the
>   dependency resolves.
> - **Cost bar:** The primary cost to weigh is coordination/verification overhead, not raw
>   token or wall-clock spend — every parallel split adds its own rendezvous point and its
>   own independent verification step (cross-reference Rule 4's "verify independently"
>   principle). Don't split finer than the point where the added verification/coordination
>   overhead would exceed what parallel execution actually saves.
> - **Documentation requirement:** The plan must carry a brief explicit note recording the
>   assessment, e.g. "N of M tasks are safely parallel (no shared state); assessed against
>   a ~30-agent ceiling; kept serial because X." This makes the reasoning auditable rather
>   than assumed.
> - **Exemption:** Extends Rule 5's exemption pattern — sub-threshold mechanical work
>   (single-file edits, lookups, status flips, memory updates) skips this assessment entirely, plus one addition specific to this rule: plans with only 1-2 tasks are also exempt. (Rule 5 itself has no task-count criterion — this threshold is new here, not inherited from Rule 5.)
> - **Relationship to existing tooling:** This rule is self-contained and portable across
>   all projects — it is not a thin pointer that only works inside hq. It is the
>   **planning-time counterpart** to `wave-execution`'s `dispatch_budget` (ADR 0023) and
>   its deferred `max_concurrent` cap: those are *runtime* preflight backstops that refuse or limit an over-large dispatch once a plan already proposes one — before any agent is actually spawned (ADR 0023's rule 11 halts at validation time, not mid-execution); Rule 7 is what should keep a plan from
>   proposing an unsafe or uneconomical split in the first place. The two are
>   cross-referenced, not redundant, not duplicative.

## Reasoning

- **Why a stress-test ceiling of ~30, not a literal target:** the point of imagining a
  large agent count is to break the reflex of defaulting to serial (or, conversely,
  over-splitting for its own sake). Anchoring the thought-experiment high forces the
  safety and cost bars to do the real work of narrowing back down to whatever count is
  actually justified — the ceiling is a prompt for honest analysis, not a budget to spend.
- **Why the safety bar is binary (shared-state / no shared-state) rather than graded:**
  this mirrors the existing binary criterion already proven in
  `dispatching-parallel-agents` — cross-task dependencies are not a matter of degree; a
  same-file edit or an output-to-input dependency makes concurrent execution unsafe, full
  stop. Grading it would invite unsafe judgment calls where a hard line is cheaper and
  more auditable.
- **Why the cost bar is coordination/verification overhead, not token/wall-clock spend:**
  Rule 4 already established that verification must be independent per unit of work; each
  additional parallel split multiplies the number of independent verification passes and
  rendezvous points required. That overhead, not raw compute cost, is what actually erodes
  the benefit of parallelizing, so it's the bar this rule weighs against.
- **Why a documentation requirement instead of a silent mental check:** an unrecorded
  assessment is indistinguishable from no assessment at all. A one-line note per plan
  keeps the reasoning auditable — consistent with how ADR 0023's `dispatch_budget`
  preflight makes an equivalent runtime judgment mechanical and visible rather than
  assumed.
- **Why this rule is self-contained rather than a pointer into hq:** Rule 7 must fire in
  any project, not only hq-governed ones (see Alternatives B below). A rule that only
  resolves inside hq would silently do nothing everywhere else.
- **Why cross-reference `wave-execution` anyway, given the rule is self-contained:**
  without an explicit bridge, the planning-time rule and the runtime `dispatch_budget`
  mechanism could drift apart over time — e.g. Rule 7's safety/cost bars evolving without
  `dispatch_budget`'s worst-case-dispatch formula (ADR 0023, D4) being revisited, or vice
  versa. The cross-reference is a deliberate anti-drift link, not a dependency.

## Consequences

- **Easier:** plans across all projects should start explicitly reasoning about safe
  parallel structure instead of defaulting to serial by habit. hq's `wave-execution`-
  authored plans should already tend to comply with the `dispatch_budget` mechanism (ADR
  0023, D4), since Rule 7 is meant to keep proposals within safe and economical bounds
  upstream of that runtime check — fewer dispatch-budget refusals should be needed as a
  result, though the runtime check remains the backstop of record.
- **Harder / accepted trade-off:** every plan or spec now carries a small amount of added
  authoring overhead — one explicit documentation note per plan recording the
  parallelization assessment. This is accepted in exchange for auditability: the reasoning
  becomes checkable rather than assumed.
- **Revisit if:** the ~30-agent stress-test ceiling proves to anchor authors toward
  over-splitting in practice rather than away from reflexive serial defaults (tune the
  framing, not the underlying safety/cost bars); or the exemption threshold ("1-2 tasks")
  proves too permissive or too strict once observed across real plans; or `wave-execution`'s
  `dispatch_budget` formula changes in a way that no longer matches the cost bar this rule
  describes (amend both together, per the anti-drift intent above); or the required
  documentation note becomes rote or starts going missing across observed plans — this
  workspace has direct precedent that prose-only discipline erodes
  and needs a planned mechanization path, and the parked inbox item
  `~/projects/agent-hq/inbox/writing-plans-wave-execution-option.md` would be a natural home for
  that mechanization if/when needed.

## Alternatives considered

- **A — fully self-contained, no hq reference.** Same inline principle (stress-test
  ceiling, safety bar, cost bar, documentation requirement), but zero mention of any
  hq-specific mechanism. Rejected: the rule and hq's `dispatch_budget` tooling could drift
  apart over time with no link between them — a future change to one would have no
  prompt to check the other.
- **B — thin pointer to an hq architecture doc.** Rule 7 becomes 1-2 lines pointing at an
  hq architecture doc for the actual method. Rejected: this breaks down in non-hq
  contexts, since there is nothing to point to outside hq, and the owner wants Rule 7 to be a
  genuinely global, portable rule that works the same way in every project.
- **C — chosen.** Self-contained principle inline (portable everywhere: stress-test
  ceiling, binary safety bar, coordination-cost bar, documentation requirement, Rule-5-style
  exemption) plus an explicit bridging cross-reference to `wave-execution`'s
  `dispatch_budget` / `max_concurrent` (ADR 0023), so hq's tooling and this rule are linked
  without either depending on the other to function. This is what is documented in the
  Decision section above.

## Governance note

This ADR amends `~/.claude/CLAUDE.md` — an extreme-caution file per the user's trigger
taxonomy (T5 — extreme-caution-file scope; T6 — architecture ratification). Per precedent
— ADR 0017 ("pure-worktree-no-exemptions") is the ADR that actually amended global `~/.claude/CLAUDE.md` (Rule 6); ADR 0016 ("source-file-length-limit") amended only STANDARDS.md and the file-length convention, and never touched CLAUDE.md, so it is not cited here as CLAUDE.md-amendment precedent. Both ADRs' own Status lines record "ratified per user decision," not an explicit Fable-ratification line — but per this workspace's own session history, extreme-caution-file changes like ADR 0017 were designed via Fable consultation (mandatory under the user's Rule 4 / ADR-0014-style T5/T6 triggers) as part of reaching that user sign-off. Per those same T5 (extreme-caution-file scope) and T6 (architecture ratification) triggers, this design requires Fable consultation before the Rule 7 text above is inserted into `~/.claude/CLAUDE.md`, and before this ADR's status moves from `proposed` to `accepted` by the user. **Fable consultation is complete (see "Fable ratification" section below); the owner gave final ratification on 2026-07-22, and this ADR's status is now `accepted`.**

## Fable ratification

Fable reviewed this design on 2026-07-22, independently verifying it against the live
`~/.claude/CLAUDE.md`, ADR 0017, and ADR 0023 — confirming that `dispatch_budget` / rule 11
is live in hq's commit history, not merely designed, and that the governance-note precedent
fix identified in the earlier independent review holds up against ground truth. **Verdict:
RATIFY WITH SUGGESTED CHANGES — no blocking concerns found.** Two suggested edits (the
safety-bar broadening and the documentation-erosion revisit trigger, both incorporated
above) were applied in this revision at the owner's direction. The owner gave final explicit sign-off on 2026-07-22; this ADR's status is now `accepted`.

**Links:** ADR 0023 (`dispatch_budget` / deferred `max_concurrent` — the runtime
counterpart this rule bridges to), ADR 0014 (model-tier operating policy — source of the
"verify independently" principle this rule's cost bar cross-references), ADR 0016 and ADR
0017 (precedent for hq-authored ADRs amending global `~/.claude/CLAUDE.md`, and for the
Fable-ratification gate on doing so), `~/projects/agent-hq/inbox/writing-plans-wave-execution-option.md`
(related-but-deliberately-separate effort teaching `writing-plans` to detect
parallelizable plans and offer `wave-execution` as a handoff option — not resolved or
superseded by this ADR).
