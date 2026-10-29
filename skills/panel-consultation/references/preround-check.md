# Pre-round check (panel-consultation; copied from review-7-panel with the changes listed at the end)

Router default adopted on the owner's yes. Owner, chat 2026-10-26 (verbatim): "Do you want that
added to the review skills? yes" - approving the proposal to add a cheap pre-round check to the
review loop, run by a Haiku agent before round one and after every fix, against the recurring
finding classes; findings are fixed before any seat reads the document; "we measure it on the
next two loops before keeping it". Pattern: four loops on 2026-10-25/26 (cs-01 c2, cprof-registry,
contract-measures, brain-workflow) each needed five rounds; their Mediums were mostly class A/B
per the assessors.

## When
- Before round 1, on the whole artefact set (architecture doc, plan, ticket together).
- After every fixer commit, before the fix-verifier or any seat re-reads.

## Who
One fresh Haiku sub-agent per run, read-only, never the author or the fixer (Rule 4). Writes one
record `preround-<artifact>-r<N>-<date>.md`; edits nothing.

## Checklist (each item mechanical; FAIL condition stated; evidence source in brackets)
- C1 Every file:line cite resolves: open the file at the pinned sha, compare the quoted text; a
  cite that does not open or whose text differs = FAIL. [assessor-contract-measures-t2 :4]
- C2 Every sentence naming an external source (an AUTHORING.md, an ADR, an owner message) carries
  a path:line-range pointer or a verbatim quote that string-matches the source; neither = FAIL.
  [assessor-contract-measures-t2 :8: three paraphrases of T:522-538 all drifted]
- C3 Every hunk of the fix commit (`git show <fix sha>`) maps to a finding id of that round; the
  accepted id classes are seat ids `<seat-id>-<n>`, A-close additions `<topic>-A<n>`, synthesizer
  `r<N>-B<n>` / `r<N>-M<n>` / `r<N>-A<n>`, pre-round `C<n>` (`-<k>` for its k-th hit), fix-verifier
  `V<n>` and Low pass `L<n>`; list each hunk with its id; a hunk without an id = FAIL. Round 1: n/a.
  [assessor-contract-measures-t2 :5, :9; assessor-brain-workflow-t2 :4, :6]
- C4 Across the companion files (architecture doc, plan, ticket): list the ids, the step order and
  every sha pin in each, compare by exact string; any difference = FAIL.
  [assessor-brain-workflow-t2 :5, :8; assessor-cprof-registry-t2 :10; Hermes G42]
- C5 Every sentence that states a rule, policy, cap, standard, cost/money, external publication or
  deletion and is not a verbatim owner quote carries one of the words "default", "question",
  "proposed" or "owner to decide"; none = FAIL (Rule 9). [assessor-brain-workflow-t2 :11]
- C6 Line caps (owner-sourced): no file at or over 1000 lines (owner 2026-10-24 06:41:40Z,
  `hq:tools/brain/templates/member-CLAUDE.md:36@c68740da`); Notion pages at most 200
  (`hq:config/CLAUDE.md:59@c68740da`; a 180
  target has no repo source, default); the loop brief's own cap (for example the 140-line doc cap in
  assessor-contract-measures-t2 :6). A 180-line cap for skill/Hermes files is a design default
  only, no owner source (`hq:architecture/brain-workflow-02.md:68@1dab0058`).
- C7 The artefact's head sha matches the sha in the record and the brief. [assessor-brain-workflow-t2
  :9 "mutual pin" churn; assessor-cs01-c2-t2 header (design read at 954e1469)]
- C8 any test step that passes or fails by elapsed time (a fixed hold, a sleep, a stop/continue
  window) fails review unless it names the logged event it waits on and cites the competing timers;
  and reviewers' fix instructions must state the property to achieve, never prescribe a timing
  mechanism. FAIL = a timed test step without its named event and competing timers, or a fix
  instruction that prescribes a timing mechanism. Owner, 2026-10-26, question Q-PREROUND-C8 ("adopt
  one more pre-round check for every design review loop?"), answer (verbatim): "Yes".

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
C1-C8. It never replaces the synthesizer or the fix-verifier; it only removes mechanical Mediums
before they cost a seat round.

## Use in panel-consultation (changes from the review-7-panel copy)
Changes from the source: this title; C3's id clause (accepted id classes above, from the id
assignment in `references/severity-and-records.md`); C8 added; the `hq:` form of one cite; C6's two line cites (`hq:` form with sha: the line numbers differ in
the public copy); C1-C8
in the closing paragraph; this section. The source file stays as it was. Source:
`skills/review-7-panel/preround-check.md:1-56@ba317780`.
- Record name here: `pc-preround-<slug>-r<N>-<step>-<date>.md` (steps and placeholders:
  `references/severity-and-records.md`); the `preround-<artifact>-r<N>-<date>.md` name above is the
  source's.
- Timing (default): before every seat round and after every fix commit (main, narrow,
  pre-round-FAIL and Low) - always before any verifier or seat reads.
- FAIL sub-procedure (default; the trial defaults above): the FAIL list goes to a fresh fixer
  instance (the Fixer role's model) whose brief is the FAIL lines and "fix only the listed items".
  C3 maps that commit's hunks to the FAIL ids `C<n>`. The check re-runs once after that fix; FAILs
  still open after the re-run go to the synthesizer as data (never to seats) and the round
  proceeds. After a Low-cycle commit there is no synthesizer: the Low cycle's own rule applies
  (`SKILL.md`, Loop). A pre-round FAIL fix does not count as an Opus fix toward ADR 0014 T1, which
  counts fixes of synthesizer findings.
- Open question (Q10, `SKILL.md`): script this check as Rule 10 code with tests, or keep it a
  prose checklist a Haiku agent runs (default).
