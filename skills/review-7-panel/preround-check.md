# Pre-round check (review-7-panel)

Router default adopted on the owner's yes. Owner, chat 2026-10-26 (verbatim): "Do you want that
added to the review skills? yes" - approving the proposal to add a cheap pre-round check to the
review loop, run by a Haiku agent before round one and after every fix, against the recurring
finding classes; findings are fixed before any seat reads the document; "we measure it on the
next two loops before keeping it". Pattern: four loops on 2026-10-25/26 each needed five rounds;
their Mediums were mostly class A/B per the assessors.

## When
- Before round 1, on the whole artefact set (architecture doc, plan, ticket together).
- After every fixer commit, before the fix-verifier or any seat re-reads.

## Who
One fresh Haiku sub-agent per run, read-only, never the author or the fixer (Rule 4). Writes one
record `preround-<artifact>-r<N>-<date>.md`; edits nothing.

## Checklist (each item mechanical; FAIL condition stated)
- C1 Every file:line cite resolves: open the file at the pinned sha, compare the quoted text; a
  cite that does not open or whose text differs = FAIL.
- C2 Every sentence naming an external source (an AUTHORING.md, an ADR, an owner message) carries
  a path:line-range pointer or a verbatim quote that string-matches the source; neither = FAIL.
  (Seen: three paraphrases of one source range all drifted.)
- C3 Every hunk of the fix commit (`git show <fix sha>`) maps to a finding id in that round's
  findings table; list each hunk with its id; a hunk without an id = FAIL. Round 1: n/a.
- C4 Across the companion files (architecture doc, plan, ticket): list the ids, the step order and
  every sha pin in each, compare by exact string; any difference = FAIL.
- C5 Every sentence that states a rule, policy, cap, standard, cost/money, external publication or
  deletion and is not a verbatim owner quote carries one of the words "default", "question",
  "proposed" or "owner to decide"; none = FAIL (Rule 9).
- C6 Line caps: no file at or over 1000 lines (owner 2026-10-24 06:41:40Z); the loop brief's own
  cap if it sets one. A 180-line cap for skill files is a design default only, no owner source.
- C7 The artefact's head sha matches the sha in the record and the brief ("mutual pin" churn).

## Output (at most 20 lines)
`C<n> PASS|FAIL <file:line> <one clause>`, one line per item, then `preround: pass|<n> fails`. A FAIL
list goes to the fixer BEFORE seats read. Trial defaults (router), owner keeps/retires after two
loops: the fixer fixes only the listed items; the check re-runs once; the orchestrator records
`preround: <pass|n fails fixed>` in the loop ledger line for that round.

## Measurement (next two loops, then the owner decides)
Per loop record: Mediums at round 1 (synthesizer count) and rounds to converge. Baseline: five
rounds in each of the four loops above. After two loops the router sends the owner both numbers
and the keep or retire question; until then this file is a trial, not a standing rule.

## What it is not
Not a seat: no severity judgement (no B/M/L), no scope or design opinion, no new findings beyond
C1-C7. It never replaces the synthesizer or the fix-verifier; it only removes mechanical Mediums
before they cost a seat round.
