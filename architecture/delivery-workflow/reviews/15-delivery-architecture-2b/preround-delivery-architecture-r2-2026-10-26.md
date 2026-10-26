# Pre-round check: delivery-architecture, round r2 (2026-10-26)
Artefact: skills/delivery-architecture (SKILL.md + references/, templates/ excluded). Pin 668af1c. Snapshot: arch15/snap-r1 (10 modified files + 1 new fixture). Fix list: reviews/15-delivery-architecture-2b/fix-delivery-architecture-r1-2026-10-26.md.
C1 PASS SKILL.md:68 all 58 file:line cites open at their resolved path and the text matches the claim (INTERFACES 1.4.0 parts, part-02/03/04/06, templates, RLM:32/83/89/99, H/learnings:16-17, dispatch-stop-conditions-02:307-320); INTERFACES.md:3 reads 1.4.0.
C2 FAIL SKILL.md:16 "Rule 5" named with no path:line or quote (also SKILL.md:46, fixtures/expected.md:10)
C2 FAIL references/review-handoff.md:55 "ADR 0014 T1" named with no path:line or quote
C3 PASS skills/delivery-architecture hunks map to R1-1..R1-18, PR2-C2, PR2-C5, AM4-a..e; no hunk without an id
C4 PASS step order and ids match tasks/15-delivery-architecture.md:57 (step 8 and 5a are mapped in SKILL.md spec map); no sha pins in either; drift outside C4 scope: spec :61 and :96 still call OQ-1 open or plan-check default
C5 FAIL references/decomposer-brief.md:8 "reply in at most 5 lines" is a cap with no default, question, proposed or anchor
C5 FAIL SKILL.md:24 "Re-sync drafts (always on the first pass)" is a mandatory rule with no default or proposed marker
C5 FAIL references/step0-inputs.md:46 "Delete the draft of every node the notes remove" is a deletion with no marker
C5 FAIL references/review-handoff.md:13 STAKES `one-way` definition (money flow, external publication) has no marker; the D2.1 cite does not carry it
C5 FAIL references/security-sensitive.md:32 "it never removes a control" is a policy with no marker or anchor (carried from r1)
C5 FAIL references/contracts.md:11 "never secret values" is a policy with no marker (unchanged since r1)
C6 PASS largest artefact file is 85 lines (references); check-doc-length.sh: 0 blocking, 0 over 500 lines
C7 PASS artefact last touched at 668af1c = pin in brief and record; HEAD is e519eac, and skills/delivery-architecture is identical at 668af1c and HEAD
preround: 8 fails
