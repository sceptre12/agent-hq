C1 FAIL interfaces/part-b-desk.md:118 cites `skills/delivery-desk/references/schemas.json`, which does not exist on disk (same path at INTERFACES.md:66); a W1 target, so mark it as a target or fix the cite
C2 FAIL INTERFACES.md:5 names the owner-decisions and design sources by path only, with no path:line-range or verbatim quote
C2 FAIL interfaces/part-a-state.md:4 names the design source by path only, with no path:line-range or verbatim quote
C2 FAIL interfaces/part-b-desk.md:4 names the design and owner-ruling sources by section and ID only, with no path:line-range or verbatim quote
C2 FAIL interfaces/part-c-waves-control.md:3 names the ADR 0054 source by path only, with no path:line-range or verbatim quote
C2 fact (not a FAIL): owner-decisions.md tail records Q1 YES, Q2 YES, Q3 YES (2026-10-26), but INTERFACES.md "Owner questions" table still lists Q1-Q3 as open; parts B1, C1.1, B4, B5 still say "DEF pending Q1/Q2" or "Q3". Errata quotes E1 "per commit", E6 "per-request account lock", E7 "conductor topic" string-match changelog.md.
C3 n/a (round 1)
C4 PASS ids Q1-Q3, E1-E11, part sections A.1-A.7 (A.2.1, A.5.1), B1-B8 (B2.1), C1-C7 (C1.1-C1.3, C5.2), D1-D7, and version 0.1.0-draft agree across INTERFACES.md, interfaces/*.md and the decision log (spot-check, not exhaustive)
C5 FAIL interfaces/part-a-state.md:192 worktree-remove deletion rule carries no DEFAULT/DEF/default/question/proposed/owner-to-decide marker in the sentence (marked only in the INTERFACES.md A.5.1 row)
C5 FAIL interfaces/part-a-state.md:194 process kill rule carries no marker in the sentence (same as above)
C5 FAIL interfaces/part-a-state.md:198 tmpdir/file/clone rm rule carries no marker in the sentence (same as above)
C5 FAIL interfaces/part-c-waves-control.md:150 STALLED rule "never one more budget" carries no marker in the sentence (INTERFACES.md C7 row marks it DEF)
C6 PASS largest file interfaces/part-a-state.md at 245 lines; 778 lines total; INTERFACES.md states every part is at or under 500 lines; the brief sets no cap
C7 PASS shasum -a 256 matches all five pins (INTERFACES c74d3d7a782d, part-a c5c1de75ff2f, part-b 51f4c4b1ef72, part-c f0071d64593e, part-d de8c519dbd26); the artefact states no conflicting pin (only @<sha> placeholders)
preround: 9 fails
