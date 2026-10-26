# 0014. Model-tier operating policy: Opus main seat, mechanical Fable escalation, post-incident assessor

- **Status:** accepted (ratified by the owner 2026-07-05)
- **Date:** 2026-07-05
- **Context of:** workspace-wide

## Context

The multi-day workspace buildout ran with Fable (top tier) as the main-chat orchestrator.
It worked, but main-seat cost multiplies with session length: the orchestrator re-processes
the whole conversation every turn, while a dispatched agent is a one-shot 50–115k-token cost
with curated context. Validated observations from the buildout:

- ~60–70% of main-seat turns were codified protocol execution (dispatch composition,
  done-condition checks, commits, memory pins) — no top-tier judgment needed.
- Where the top tier earned its cost: cross-context inference (correlating a mystery pid
  with a `/compact` the user ran — a fact that existed ONLY in conversation), catching a
  publish gate reading pre-fix verdicts, recognizing a subagent's hollow-progress stop,
  reframing an SSL error as MCP-server contamination. Cheap in tokens, decisive in judgment.
- Independent verification caught undeclared content drops in 8/8 skill ports. Credit
  belongs to **independence and heterogeneity**, not tier — consistent with Osmani's
  146-PR finding (93.4% of issues caught by exactly one reviewer tool).
- Reference canon (Osmani) says "harness > model" and "don't escalate model; escalate spec
  quality and verification rigour" — but contains **zero** content on model tiering, and
  never addresses (a) genuinely-frontier reasoning tasks or (b) triage blindness: the model
  in the seat cannot reliably grade its own difficulty (his own Maker/Checker argument,
  extended: the model deciding whether to escalate is too biased to grade the need).

Adjudication: Osmani is right about the **median** failure (spec/verification, fixable at
cheap tiers) and silent — not wrong, silent — about the **tail** (frontier inference,
triage blindness). Policy: the harness handles the median; **mechanical** triggers handle
the tail, because a judgment-based escalation rule fails exactly when judgment is the
thing that's impaired.

## Decision

We will run the following operating model:

1. **Main seat = Opus, always.** Fable never holds the main seat, including design phases.
   Design sessions run as dispatched Fable with external state (spec + progress log + git —
   Ralph-Loop pattern) so context lives in artifacts, not the seat.
2. **Dispatch ladder unchanged** (Rule 4: Haiku mechanical / Sonnet standard / Opus complex),
   plus **Fable as dispatch-only apex** for exactly three roles: design ratification,
   trigger-fired escalation, post-incident assessment.
3. **Escalation to Fable is trigger-based and mandatory** — when a trigger fires, the
   orchestrator has no discretion to skip it. Discretionary escalation is allowed in
   addition, never instead. Every fire is logged (see Evaluation).
4. **A post-incident assessor** (dispatched Fable) reviews qualifying incident arcs and
   returns a short steering message with stop-the-line authority.

### Escalation trigger list (mechanical — defeats triage blindness)

| ID | Trigger | Fires when |
|----|---------|-----------|
| T1 | Two Opus failures | The ladder has reached Opus and the problem failed twice there. Between failures 1 and 2, exactly one retry with upgraded spec + verification rigour (the Osmani move). Second failure → Fable, no third Opus attempt. **N = 2.** |
| T2 | Falsified hypothesis | The orchestrator's stated working hypothesis is contradicted by ground-truth evidence — a mechanical signal that it is out of frame. |
| T3 | Unresolved safety-stop / bypass pressure | An agent safety-stop or blocked gate whose cause is not evidence-identified after one investigation pass, OR any suggestion/temptation to bypass a gate appears. (Routine gate FAILs with an evidence-backed mechanical fix do not fire.) |
| T4 | Cross-system failure | Symptoms span ≥2 subsystems with no single-system explanation. |
| T5 | Extreme-caution scope | Proposed change touches an extreme-caution file (global CLAUDE.md, settings/permissions, credentials, INVARIANTS.md): Fable ratifies the design before any change. |
| T6 | Architecture ratification | Any new Rule-5 architecture record for a system/initiative is ratified at Fable (revisions of an existing record stay Opus unless another trigger fires). |
| T7 | User signal | User says "hard", "stuck", "escalate", or questions the current approach. |

### Post-incident assessor

**Role separation:** the assessor is NOT the Maker/Checker verifier. Independent verification
of every substantive change stays at difficulty-appropriate cheap tiers (that is what caught
8/8 drops). The assessor is a rarer, blast-radius-tiered judgment review of the whole
incident arc; verification evidence is one of its inputs. It does double as a heterogeneous
second reviewer (different model, different vantage) for the incidents it covers. If Fable
authored the fix (via T1–T7), the assessor role passes to an independent Opus instance —
never assess your own work.

**When it fires** — after symptom → hypotheses → fix → verification, if the incident meets ANY:
- fix touched >1 system, or any extreme-caution file;
- data loss, credential exposure, or gate-bypass pressure was involved;
- the confirmed root cause differed from the first diagnosis;
- second occurrence of the same symptom (recurrence = missed root cause).

Single-file, hypothesis-confirmed, first-occurrence incidents: no assessor; ordinary
independent verification suffices.

**Input contract** — a curated packet (≤ ~150 lines); the assessor has no conversation
context, and the known failure mode is that the decisive fact may exist ONLY in
conversation (the pid ↔ `/compact` case). Required fields:

1. Symptom — verbatim first observation (command output / error text).
2. Timeline — ordered events **including user-side conversation events** (compactions,
   restarts, manual commands). Before dispatch the orchestrator must sweep the session for
   such events and attest: "no known conversation-only fact omitted."
3. Hypotheses considered — each with the evidence that supported or killed it.
4. Fix applied — diff or commit hash + the claim of what it does.
5. Verification evidence — post-fix ground truth (never the author's self-report).
6. Environment deltas — anything else that changed in the window.

**Output contract** — steering message, ≤10 lines, fixed shape:

```
VERDICT: fix correct | fix plausible-unverified | fix wrong | fix masks deeper cause
ROOT CAUSE: confirmed at depth | shallow — real cause likely <X>
MISSED EVIDENCE: <under-weighted fact in the packet, or "none">
PATTERN: codify? yes → <one-line learning + learnings/<topic>/ path> | no
NEXT RISK: <single most likely follow-on failure>
STEER: <one imperative sentence for the orchestrator's next move>
```

**Where outputs land:** verbatim into the incident's plan/project record follow-ups.
If PATTERN = yes, a Haiku dispatch files `learnings/<topic>/YYYY-MM-DD-<kebab>.md`.
A verdict of "fix wrong" or "fix masks deeper cause" is **stop-the-line**, treated
exactly like a blocked gate.

## Reasoning

- **Cost asymmetry.** A multi-day main seat re-processes an ~80k+ average context over
  hundreds of turns — order 10⁷ tokens through the main-seat model. A Fable dispatch is a
  bounded ~50–115k one-shot. Even a dozen Fable dispatches a week (~1M tokens) is a small
  fraction of one day of Fable in the main seat; caching shifts exact numbers, so the
  2-week evaluation counts real spend rather than trusting this estimate.
- **Bounded and rare by construction.** Design ratifications ≈ 1–2 per initiative; assessor
  runs a few per week at most; T1–T4 fire only after cheaper remedies failed.
- **Mechanical beats judgment for escalation** because the failure being defended against
  is the judge's own blind spot. Same logic as Maker/Checker.
- **Accepted loss, mitigated:** an Opus main seat will miss some conversation-only
  inferences a Fable seat would have made. The timeline-sweep duty in the assessor input
  contract and external-state design sessions recover most of this; the residual is the
  price of the economics, and the evaluation watches for it (under-escalation audit).

## Consequences

- Easier: predictable Fable spend; escalation no longer depends on the orchestrator
  "wanting" to escalate; incident arcs get a durable, short, actionable review artifact.
- Harder: orchestrator carries new bookkeeping (trigger log, assessor packets); some Fable
  dispatches will return "you were fine, proceed" (tolerated up to ~60% of fires — above
  that, loosen triggers at the retro).
- On ratification: update `tools/model-routing.md` standing-assignments table to match
  (Fable rows become dispatch-only roles); apply the Rule 4 amendment below (the owner applies
  it himself — global CLAUDE.md is extreme-caution and was not touched by this ADR).
- Revisit at the 2-week evaluation (below).

## Alternatives considered

- **Fable stays in the main seat for design phases** — rejected: main-seat cost scales with
  session length regardless of phase; dispatched-Fable-with-external-state (spec + progress
  log + git) captures the design value at one-shot cost.
- **Judgment-based escalation ("Opus escalates when it deems necessary")** — rejected: the
  precise worry is that a genuinely-capable model under-detects its own frontier; the rule
  must not route through the impaired faculty.
- **Assessor on every incident** — rejected: cost and noise; blast-radius tiering (Osmani's
  review-tiered-by-blast-radius) keeps it where a wrong fix is expensive.
- **Merge assessor into the Maker/Checker verifier** — rejected: verification runs on every
  substantive change and must stay cheap; merging either prices all verification at Fable
  or dilutes the assessor. Kept separate; assessor consumes verification evidence.
- **N = 1 (first Opus failure → Fable)** — rejected: contradicts the validated Osmani move
  (one spec/rigour upgrade retry fixes the median failure cheaply). **N = 3+** — rejected:
  third same-tier attempts were exactly the hollow-progress pattern the buildout logged.
- **Keep everything as-is (Fable main seat)** — rejected: 60–70% of turns demonstrably
  needed no top-tier judgment; the economics are the whole point.

## Appendix A — DRAFT amendment to global CLAUDE.md Rule 4 (the owner applies manually)

> Add to Rule 4 after the existing heuristic bullet:
>
> - Main seat: Opus for all orchestration. Fable never holds the main seat; it is
>   dispatch-only (design ratification, trigger-fired escalation, post-incident
>   assessment) — bounded one-shot dispatches with curated context.
> - Ladder top: first Opus failure → retry once with upgraded spec + verification rigour;
>   second Opus failure → mandatory Fable dispatch. Never a third Opus attempt.
> - Fable escalation is MANDATORY when any ADR 0014 trigger fires (T1 two Opus failures;
>   T2 falsified working hypothesis; T3 unresolved safety-stop or gate-bypass pressure;
>   T4 cross-system failure; T5 extreme-caution-file scope; T6 architecture ratification;
>   T7 user says hard/stuck/escalate). No discretion to skip a fired trigger;
>   discretionary escalation is allowed in addition, never instead.
> - Qualifying incidents get a post-incident assessor per ADR 0014 (curated input packet,
>   ≤10-line steering output); a "fix wrong / masks deeper cause" verdict is stop-the-line.
> - Log every trigger fire and assessor verdict as one line in the current eval log.

## Appendix B — 2-week evaluation (from ratification date)

Log: one line per event, appended to `retros/<YYYY-MM>-model-tier-policy-eval.md`
(created at ratification): `T<n> | <date> | <problem> | fable-changed-course: y/n` and
`ASSESSOR | <date> | <incident> | <verdict>`.

Count at the retro:
1. Escalations fired per trigger ID; for each, did Fable's output change course vs the
   pre-dispatch plan (y/n, judged in retro)?
2. Assessor runs: verdict distribution; every verdict ≠ "fix correct" is a caught miss;
   patterns codified into learnings/.
3. Fable token spend (ccusage) vs the buildout main-seat baseline
   (`tools/ccusage-baseline-pre-stack.txt` lineage).
4. Under-escalation audit: incidents in the window that in hindsight should have fired a
   trigger but didn't → trigger-list gap; tighten.
5. False-positive burden: share of Fable dispatches returning "proceed as planned" —
   above ~60%, loosen the offending trigger.

Retro decision: ratify/adjust N, the trigger set, and the assessor threshold; supersede or
amend this ADR accordingly.
