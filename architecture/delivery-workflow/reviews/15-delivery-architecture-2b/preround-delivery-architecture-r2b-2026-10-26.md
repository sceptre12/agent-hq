# Pre-round check: delivery-architecture, round r2b (2026-10-26)
Artefact: skills/delivery-architecture (SKILL.md + references/, templates/ excluded). Pin 668af1c. Snapshot: arch15/snap-r2. Fix list: reviews/15-delivery-architecture-2b/fix-delivery-architecture-r1b-2026-10-26.md (PR3-*).
C1 FAIL references/review-handoff.md:55 cite decisions/0014-model-tier-operating-policy.md:55 opens, but line 55 is the table header "| ID | Trigger | Fires when |"; the T1 row is line 57 (PR3-C2b points two lines short)
C1 PASS SKILL.md:16, SKILL.md:46, fixtures/expected.md:10 config/CLAUDE.md:32 resolves to $HOME/projects/hq/config/CLAUDE.md:32 "## Rule 5 — Architecture First..." (prefix not in Provenance; not W-relative)
C1 PASS all other file:line cites open; quoted text checked at the r1b-touched cites and spot checks; H/ and RLM: ids (D63, D67, G46) match at the cited lines
C2 FAIL SKILL.md:21 "(owner ruling OQ-1, INTERFACES AM-3)" names an owner ruling and an INTERFACES anchor with no path:line or quote in the sentence (carried from r2, not flagged then)
C2 PASS SKILL.md:16, SKILL.md:46, fixtures/expected.md:10, review-handoff.md:55 now carry pointers
C3 PASS working tree vs snap-r2 (fixer does not commit): 10 hunks, all mapped; SKILL.md:16, :46, fixtures/expected.md:10 = PR3-C2a; review-handoff.md:55 = PR3-C2b; SKILL.md:24 = PR3-C5b; decomposer-brief.md:8 = PR3-C5a; step0-inputs.md:46 = PR3-C5c; review-handoff.md:13 = PR3-C5d; security-sensitive.md:32 = PR3-C5e; contracts.md:11 = PR3-C5f; no hunk without an id
C4 PASS step order matches spec tasks/15-delivery-architecture.md:57; SKILL.md:33 spec map covers sub-steps 5a and 8; no sha pins in either
C5 PASS the six PR3-C5 lines carry "a default of this skill" or an anchor (SKILL.md:24 K14; security-sensitive.md:32 spec 15 RESOLVED Q2 at tasks/15:96); grep scan found no further unmarked cap or policy (not exhaustive)
C6 PASS largest artefact file 85 lines (references/tree-rules.md); check-doc-length.sh: 0 blocking files over 500 lines, 0 allowlisted, no file at or over 1000 lines
C7 PASS skills/delivery-architecture identical at 668af1c and HEAD (git diff empty). HEAD is now 2c10079 (was e519eac at r2); `git log -1` gives 2c10079, not the 668af1c pin in the brief
preround: 2 fails
