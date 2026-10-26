Pre-round check r3, INTERFACES 2b, after fixer r2 (2026-10-26). Read-only checker (Haiku). Set: INTERFACES.md, interfaces/part-a-state.md, part-b-desk.md, part-c-waves-control.md, part-d-enums-topics.md. Diff: scratchpad diff-r2.patch.
C1 PASS owner-decisions.md:28, :37, :58, :59, :60 open at the cited content; Q1 and Q2 quotes string-match :58 and :59 (grep count 1 each). ADR cites 0054:55-61, :135-137, :150-162, :159-162, :194-197 and 0055:81-83, :89-92, :159-162, :164-166, :185-191, :219-223 open at the cited content.
C2 PASS every new external-source sentence carries a path:line pointer or a verbatim quote.
C3 PASS every hunk maps to an id: G1 G2 G3 G4 G5 G6 G7 G8 G9 G10 G11 G12 G13 G14 G15 G16 G17 G18 G19 G20 G21 G22 G23 G24 G25 G26 G27 G28 G29 G30 G31 G32 G33 G34 G35, PR6-1 (rename set), PR6-2 (DEFAULT tags).
C4 FAIL interfaces/part-a-state.md:41 `outbox/register` row lists no rename states, but interfaces/part-c-waves-control.md:118 and part-b-desk.md:22 use register.consumed and register.refused. Other tokens match: .sending-<id>/.sent-<id>/.refused (INTERFACES.md:115, part-a:41, part-c:110, :118), ticket-events.cursor, pm/new-units.md, REBIND, MERGED, unit regex, done_condition shape.
C5 FAIL interfaces/part-d-enums-topics.md:101 added rule sentence "A unit maps to its ticket through the dispatch-plan unit table ... else its draft slug" carries none of DEFAULT, DEF, FROZEN, owner cite or owner to decide.
C6 PASS largest file part-a-state.md 283 lines (under 500 and under 1000).
C7 PASS sha256 12-char prefixes match all five pins: INTERFACES f2c33491f38b, part-a 8e7eb257955b, part-b e54289687c73, part-c a7d9914e1bb1, part-d 4bd7e469f166.
Not counted: N10 (INTERFACES.md:10) states an open owner question without the literal words; left to the owner per the fixer's note.
preround: 2 fails
