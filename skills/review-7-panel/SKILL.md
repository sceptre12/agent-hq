---
name: review-7-panel
description: >
  Owner-adopted 7-agent review loop: seven independent Sonnet seats, each with one
  perspective fitted to the artifact, then a Sonnet synthesizer, a fixer, and a fix-verifier,
  repeated under one Opus orchestrator until 0 Blocking / 0 Medium or the D7 round cap. Use when
  asked for a "7-agent review", a "panel loop", a "design approval loop", or to "run the panel on
  this design" (or plan) before ratification or build. This is Rung 2b on the review ladder
  (tools/review-ladder.md): between panel-consultation (Rung 2, one simulated context) and
  pr-review (Rung 3, code diffs). For a single-context perspective sweep use
  panel-consultation; for a code diff or PR use pr-review; for a one-way-door needing 11-agent
  quorum use panel-review (Rung 4).
---

## Trigger

Use when a design or plan must clear the owner's approval standard, or when independence of
perspectives matters but there is no code diff. Rung 2b sits after panel-consultation (Rung 2,
simulated, anchoring is structural) and before pr-review (Rung 3, code diffs on the bus); the
"2b" placement (an inserted rung, existing rungs not renumbered) is the skill author's choice.

Owner approval standard (2026-10-24 04:17:03Z, Slack ts 1792815412.788869, verbatim): "As long
as the architectures have gone through the panel review skill phase ( I legit the blocker on
that skill so agents can run it for this project) and then another agent has fixed the issues
and then another agent runs the fix validator and that loops runs till there's no blocking or
medium issues then the plan is approved to go". Owner, chat 2026-10-24 18:16:28Z, answering
Q-REVIEW-RUNG (verbatim): "Yes that can be now its own skill name for that" - the router
reads this as the loop satisfying the panel phase, so a design that passes is build-eligible on
ratification (router reading of the owner's yes).

Owner-sourced shape (see Provenance): 7 problem-fitted agents, orchestration by a sub-agent,
Sonnet seats, loop to 0B/0M. Everything else below not tied to an owner quote is a router
default (Rule 9: a suggestion, not a rule).

Not for: typo-level or routine single-doc checks (Rung 0/1), code diffs (pr-review).

## Roles

| Role | Model | Job |
|---|---|---|
| Orchestrator | Opus | Owns the whole loop in its own context; dispatches everything below; writes the loop ledger; hands back <=10 lines. One orchestrator per artifact. |
| 7 seats | Sonnet | Each reads the artifact with ONE perspective; seats never see each other's output. Dispatched in one message. |
| Synthesizer | Sonnet | Reads the 7 seat records, de-duplicates, re-verifies every Blocking and Medium against its source, assigns final severity. First line of its record: `APPROVAL BAR MET|NOT MET <B>/<M>/<L>`. |
| Fixer | Opus; Fable once ADR 0014 T1 fires for the artifact | Applies the synthesizer's findings to the artifact only. T1 = a second Opus fix followed by new Mediums; log the fire (time + round). |
| Fix-verifier | Sonnet | Checks the fix against its findings (`skills/fix-verifier` form): CLEAN or ISSUES_FOUND with counts. Never the fixer. |
| Low pass + verifier | Sonnet, Sonnet | After the bar: apply Lows (skip with reason), then a verifier. |

Verifier is never the author of the fix (Rule 4).

## Steps

1. Fit seven perspectives to the artifact (see Seat-perspective fitting); write them in the ledger row before dispatch.
2. Run the pre-round check: `preround-check.md` (this directory) before round 1 and after every fixer commit, before seats re-read (trial, owner yes 2026-10-26).
3. Dispatch the 7 seats in ONE message.
4. Dispatch the synthesizer; read its first line for the bar.
5. If the bar is NOT MET: dispatch the fixer (narrow fix first if the verifier finds one issue), then the fix-verifier. ISSUES_FOUND goes back to a narrow fix and verifier before the next round; CLEAN starts the next 7-seat round.
6. If the bar is MET (0 Blocking / 0 Medium from a synthesizer round): run the Low pass + verifier; the loop ends there.
7. Write one ledger line per step, then hand back (see Hand-back form).

- Round cap: D7 caps review loops at 3 rounds, then the owner decides. The orchestrator
  follows D7 and the Hand-back form; it does not decide past the cap.
- Loop ledger: one file per artifact, one line per step:
  `<UTC ts> <step> <result counts> -> <record path>; <next dispatch>`. Router notes
  (owner instructions, corrections) are logged as lines too. The ledger location is set in the
  orchestrator's brief.
- Record naming: seats `panel7-<artifact>-r<N>-s<1..7>-<date>.md`; synth
  `panel7-<artifact>-r<N>-<date>.md`; fix `fix-<artifact>-r<N>[b|c]-<date>.md`; verifier
  `verify-fix-<artifact>-r<N>[b]-<date>.md`; Low pass `fix-<artifact>-lows-<date>.md`;
  pre-round `preround-<artifact>-r<N>-<date>.md`.
- Seat brief: artifact paths, history, sources, binding owner decisions, its one
  perspective and what to pressure-test, "verified findings only, cite line + source,
  classify B/M/L", output <=12 lines + record, 10 min wall budget (default; see Budgets),
  harness block = stop verbatim.
- Rounds of independent artifacts run in parallel (owner 2026-10-24 14:35:47Z, ts
  1792852547.901459: no panel lock); the measured harness cap (50 concurrent sub-agents) is
  the only ceiling, and hitting it is recorded as a fact.

## Seat-perspective fitting

Choose seven perspectives that match the problem, not a stock list; each must be able to
find something the others cannot.

- Design: one seat per risk surface, e.g. wire/protocol edge semantics, failure and
  recovery paths, test/acceptance gradability, packaging and metadata, ticket and owner
  alignment, consistency of the document with itself, measured-fact accuracy.
- Plan: sequencing and real dependencies, shared mutable state and concurrency (Rule 7),
  wake/deadline signals, done conditions and verifiability, owner-decision boundaries,
  limit exposure, document coherence and ticket alignment.
- Code diff: use pr-review instead. If a diff accompanies a design, add seats for
  correctness against the design and test coverage.
- Router default (no owner source): consider one seat that re-measures facts cited in the
  artifact and one that reads as the cold implementer.
- Rounds may re-fit seats to the residual finding class.

## Reading rules and frozen facts (router defaults)

- Default: a "(fact)" in the artifact names the command and the count that produced it, measured by
  the author or a separate measurer. Never a list copied from another agent's report.
- Default: a reading rule (a short statement in the seat brief of when a finding stands, e.g. "a
  Medium stands only if it names X or shows Y; otherwise refute by citing line N") may bind
  seats and the synthesizer for the rest of the loop.
- Default: a frozen fact contradicted by re-measurement pauses the loop; the orchestrator
  reports to the router, which may fire ADR 0014 T2 (falsified working hypothesis) and
  dispatch an assessor whose steering (<=10 lines) names the closure.
- Assessor advice seen once: put closure at the derivation point of an invariant, not at an
  enumeration of sites.

## Hand-back form

<=10 lines to the router: bar met or not; rounds; final B/M/L; record paths (ledger,
last synth, last verifier); T1 fires (time + round); T2 signals; sizes of the artifact;
"owner notes:" list of items that need owner notification or decision (named, not
decided). The orchestrator never decides an owner-only item.

## Budgets

Defaults (not owner-set): seats 10 min each (the brief's budget; 12 min is the per-round
wall allowance for the seat stage), synthesizer 10 min, fixer <=20 min, verifier <=10 min.
About 9 dispatches per round (7 + synth + fix + verify); wall time is similar to a Rung 2
review because seats run in parallel. Count the peak against the cap of 50 across parallel loops.

## Never-list (router defaults; sources named where they exist)

Every role except the orchestrator's ledger writes only the artifact under review (fixer)
or its own record:
- Router default: no clone, QUEUE.md or Slack writes.
- Router default: never ask the owner; never edit skills; never decide owner-only items
  (Rule 9, Rule 11: rules, money, external publication).
- Global Rule 10 / owner 2026-10-01: no --no-verify, no core.hooksPath override; no
  force-push is a router default.
- Router default: a fixer that refuses a finding says so with the reason, not silently.
- Global Rule 4 (classifier block = stop-the-line): a harness or classifier block is STOP
  verbatim; no rewording, rerouting or retry.
- Orchestrators write review records only; the router keeps QUEUE.md rows, eval-log lines,
  Slack and the owner summary.

## Red flags (router defaults)

| Rationalization | Do instead |
|---|---|
| "Two clean rounds, call it approved." | Owner 04:16:52Z: loop to no Blocking/Medium. The bar here is a synthesizer round at 0B/0M, then the Low pass + verifier (router default). |
| "Round 3 missed the bar, run round 4." | D7: loops stop after round 3 and the owner decides. Hand back. |
| "The verifier's count is good enough to freeze." | Re-measure; name the command and count. |
| "Small doc, run 7 seats to be safe." | Rung 1 covers it; pick the lowest rung. |

## Exit criteria

- [ ] A synthesizer round at 0B/0M, the Low pass and its verifier CLEAN; or the D7 cap reached and handed to the owner.
- [ ] Every fix was verified by an agent that did not write it.
- [ ] Ledger has one line per step; hand-back is <=10 lines with `owner notes:`.

## Provenance

Owner words: 04:17:03Z standard and 18:16:28Z skill direction (above); 13:53:57Z (ts
1792850037.024329): "Do panel consultation except there are 7 agents that take on the
perspectives that better rmatch the problem being solved"; 14:13:43Z (ts
1792851223.586009): "spawn a sub agent to be the orchestrator so that it handles all of
the context coming in"; 14:35:47Z lock removal; 04:16:52Z loop to 0B/0M; 06:27:40Z "The panel review can be orchestrated by opus but the work can be done by Sonnet". Lineage: panel-consultation, fix-verifier, doc-reviewer.
Ported into agent-hq 2026-10-26 for the delivery workflow (design §7 item 8).
