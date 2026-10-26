# Pre-round check, INTERFACES 2b, after fixers r1b and r1c (2026-10-26)

Scope: combined diff of r1b and r1c (`diff-r1bc.patch`, 592 lines, no git commit). Read-only check; one record written. Checker: fresh Haiku, not the fixer or author (Rule 4).

C1 FAIL INTERFACES.md:126-135 O-Q2..O-Q11 cite ADR 0054 `:273-274` through `:284`; the owner answers sit one line earlier (Q2 `:272-273`, Q3 `:274`, ... Q11 `:283`).
C1 FAIL INTERFACES.md:171 E14 cites decisions/0055-desk-verb-permission-tiers-02.md `:244-245` for OP10 `action-failed`; that range is the ADR 0053 item 6 / OP8 text. The tenth code is at decisions/0055 `:58-59` and `:138-143`.
C2 FAIL interfaces/part-b-desk.md:14 Credentials row names "ADR 0053 item 6" with no path:line; the only pointer is owner-decisions.md:70 (OP8).
C3 FAIL interfaces/part-b-desk.md:4 Sources row (new ADR 0054/0055 pointers and OP1-OP10 answer text): no finding id in either fix record.
C3 FAIL interfaces/part-b-desk.md:20 Grammar authority row (ADR 0055 accepted 2026-10-26): no finding id in either fix record.
C4 PASS ids (Q1-Q3, O-OP1..10, O-Q2..11, FRZ-a..i, E1-E15), 10 reason codes with the terminal/curable split, and GATE/ANSWER/REGISTER-SENDER/REGISTERED shapes agree across all five files.
C5 PASS new rule sentences carry DEFAULT, DEF, FROZEN or an owner cite (spot-checked on every changed row).
C6 PASS largest file part-a-state.md 278 lines (cap 1000; 500 standard also holds).
C7 PASS content sha256 prefixes match pins: INTERFACES 90cf4f6f82c5, part-a b0b8e0b56214, part-b c4bd2ee7b644, part-c c590d6e9c02b, part-d 44a1c6051ee3.
Owner quotes owner-decisions.md:58-60 string-match; owner-decisions.md:62-76 and the other cited ADR, design and permission-tiers ranges open and match.
preround: 5 fails (C1 x2, C2 x1, C3 x2)
