# Difficulty scaling (defaults; measured inputs; never below what the risk needs)

Every statement here is a default the owner may change (question Q6: adopt these tiers and the
Full-tier bar round as a standing rule, or keep them as logged defaults until measured on two
loops, as the pre-round check was). The ledger records the inputs beside the tier chosen.

## 1. What is recorded (facts)

Hermes `brain/review-loop-mechanics` records these:

- hq scales by rung, not seat count; nothing measured varies seat count by size or difficulty.
- Changed-lines re-reads did not satisfy the owner's approval standard (G39: "No panel has read
  the design with any owner decision encoded").
- Touched-seat re-runs are unmeasured against a full round (cs-01 r8 and r9).
- Fix-introduced findings were 7 of 16 in one loop (G11) and about 12 percent across six (G25).
- The pre-round check took a PR to 0 Blocking / 0 Medium in one round (G51).

So the scheme scales the intermediate rounds only, never the first round and never the bar round.

## 2. Ledger inputs

The orchestrator measures and writes these before each round:

- artifact size: `wc -l` and `wc -c` per file; companion count; `KIND`; round number;
- the previous round's tier and the synthesizer counts per topic;
- the previous round's last fix-verifier verdict;
- the fix diff's touched lines: `git diff --numstat <previous round's HEAD_SHA>..HEAD_SHA --
  <artifact paths>`, added plus deleted summed, against the artifact's total `wc -l`;
- the new-surface counts (section 4);
- the `OWNER_DECISIONS` entry count.

## 3. Tier mapping

Every round maps to exactly one tier from those inputs alone.

**Focused** when ALL hold:

- (F1) round number is 2 or more;
- (F2) the previous round's synthesizer read 0 Blocking and at least one Medium, all within 1 to
  3 topics;
- (F3) the previous round's last fix-verifier was CLEAN;
- (F4) the fix adds no new surface (section 4);
- (F5) the fix touched at most one third of the artifact's lines;
- (F6) the `OWNER_DECISIONS` entry count is unchanged since the last Full round.

In-scope topics (the one definition): the topics with at least one Blocking or Medium in the
previous round's synthesizer table (column Topic), plus every topic UNRESOLVED in the previous
round. Seats: the core trio (cold-reader, fact-checker, integration-architect) plus the R and A
seats of every in-scope topic, 3 to 9 seats from the matrix in `references/seats-raci.md`.

**Full** (9 seats) in every other case: round 1, and the round after any Focused round that read
0 Blocking / 0 Medium.

In a Focused round:

- before dispatch the orchestrator writes one ledger line per topic outside the in-scope set,
  `NOT-REVIEWED | <topic> | r<N> | focused`;
- a dispatched seat whose own R topic is outside the set writes `SKIPPED | <topic> | r<N> |
  focused` as its R line (valid, not malformed) and C-NOTEs only on in-scope topics;
- the close rule applies to in-scope topics only;
- the synthesizer's line 1 is `FOCUSED r<N> <B>/<M>/<A> — bar not evaluable`;
- only a Full round that reads 0 Blocking / 0 Medium meets the bar and ends the loop.

## 4. New-surface test

On `git diff -U0 <previous round's HEAD_SHA>..HEAD_SHA -- <artifact paths>`, count added lines
matching

```
grep -cE '^[+][[:space:]]*(#{1,6} |[|]|[0-9]+\. |[-*] )'
```

(headings, table rows, numbered steps, list items; the `+++` header does not match) and removed
lines matching the same pattern with `^[-]`. The fix adds new surface when added is greater than
removed. A reworded row (+1 and -1) is not new surface; a new clause inside an existing line is
caught by F5 and by the next Full round, not by this test.

## 5. Floor and escalation

- Smaller than Focused does not exist in this skill: a small doc is doc-reviewer's (Rung 1).
- A one-way door found inside the artifact escalates to panel-review (Rung 4) mid-loop
  (`tools/review-ladder.md` section 4).
- A code diff found inside the artifact is routed to pr-review (one rung per artifact, ADR 0022
  item 4: `hq:decisions/0022-operating-model-cost-efficiency-audit.md:172-174@c057d0cf`).
- The tiers are defaults until the owner rules (Q6).

## 6. Ledger line

One line per step: `<UTC ts> <step> <tier> <counts> -> <record>; <next>`. Per round the
orchestrator also writes the section 2 inputs and the tier chosen, plus any NOT-REVIEWED and
UNRESOLVED lines, in `pc-loop-<slug>-<date>.md`.

## 7. Dispatch count and concurrency (default basis)

A Full fix round is 9 seats plus 0 to 9 A-close plus synthesizer plus fixer plus fix-verifier plus
1 to 2 pre-round checks, which is 13 to 23 dispatches; the bar round is 10 to 20 (no fix, verifier
or post-fix check). Not counted: the orchestrator, FAIL fixes, narrow fixes and re-verifies, the
Low cycle. Peak concurrency is 10 live instances at one time, the orchestrator included, its
caller not. The measured harness cap is 50 concurrent sub-agents (Hermes G17); a loop that hits
it records the fact.
