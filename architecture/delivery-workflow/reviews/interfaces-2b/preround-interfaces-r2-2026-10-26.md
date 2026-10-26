# Pre-round check, INTERFACES 2b, round 2 (2026-10-26)

Checker: fresh read-only Haiku pre-round agent (not the author or fixer, Rule 4). Input: round-1 fix as `diff-r1.patch` (38 hunks, 5 files), fix record `reviews/interfaces-2b/fix-interfaces-r1-2026-10-26.md`. No file edited other than this record.

Pins (C7): INTERFACES.md 3cb1f42f9c3f, part-a c2f9a7b94fce, part-b 6f2e0f19a30d, part-c cb71b1ee1383, part-d a29eca310cd0 (sha256 prefixes recomputed, all match).

C1 FAIL architecture/delivery-workflow/part-b-desk.md (B1 row, "Allowed requesters"): cite `part-05:36-44` has no path; the file is `architecture/delivery-workflow/part-05-execution-constraints.md`; lines not opened by this check.
C2 FAIL interfaces/part-a-state.md:133 (A.4 row, "ADR 0054 A1"): quoted "reservations must cover gate and fix agents" is not in ADR 0054; text at decisions/0054-adr-0023-amendment-delivery-workflow.md:55 reads "reservations must also cover the gate and fix agents".
C2 FAIL interfaces/part-c-waves-control.md:113 (wave-files paragraph): quoted "frontiers inside one wave; waves stay barriers" is not verbatim; ADR 0054 :86 and :116 read differently.
C2 FAIL interfaces/part-c-waves-control.md:175 (done-condition row): cite ":255-260" for "Meanwhile"; the Q2 Meanwhile text is at ADR 0054 :262, outside the range.
C2 FAIL INTERFACES.md:11 and :15 and the Owner notes rows N1-N9 (:17-27): ADR 0054/0055 named (e.g. "ADR 0055 §1", "ADR 0054 Q3") with no path:line or quote.
C4 FAIL interfaces/part-c-waves-control.md:113 (inbox first line) and INTERFACES.md:90 (B8 decisions-log row, old wording) vs interfaces/part-b-desk.md:138 (`ANSWER <run-id> <subtask> <unit> <text>`) and INTERFACES.md:121 (new B8 row): ANSWER and GATE shapes differ across files.
C5 FAIL interfaces/part-a-state.md A.2.1 paragraph (after the gate table): sentences on `by=`, `ref=`, "Agents never write under gates/" carry no DEFAULT/owner-to-decide marker.
C5 FAIL interfaces/part-a-state.md "bus.endpoint" paragraph (A.3): "session_id= must equal ...; a mismatch is a stop row" has no marker.
C5 FAIL interfaces/part-a-state.md A.7 blockquote: new sentence "On a commit it is allowed inside a unit or batch..." has no marker.
C5 FAIL interfaces/part-b-desk.md "Allowed requesters" row: "Conductor-only verbs ... are valid only with <subtask> = run ... any other <subtask> is REJECTED sender" has no marker in those sentences.
C5 FAIL interfaces/part-b-desk.md B5 paragraph: "content-merged for branch-delete ... failure is REJECTED marker" has no marker.
C5 FAIL interfaces/part-b-desk.md B8 gate matrix paragraph: "any other pair is refused in the desk session, nothing written" has no marker.
C5 FAIL interfaces/part-c-waves-control.md C1.1 bus_endpoint row (after the owner quote): "delivery-run starts the pm2 app ... is the only restarter" has no marker.
C5 FAIL interfaces/part-c-waves-control.md C1.2 blocked-by row: "the lead TaskStops only already-live agents" has no marker.
C5 FAIL interfaces/part-c-waves-control.md C2 escalation row: "dependents stay unreleased" has no marker.
C5 FAIL interfaces/part-c-waves-control.md "Merged tick" bullet: "armed by the lead in its own session" has no marker in that sentence.
C5 FAIL interfaces/part-d-enums-topics.md D5 "Writer" bullet: "delivery-run is also the only restarter" has no marker.

C1 PASS (checked): owner-decisions.md:58, :59, :60 exist; ADR 0054 :37, :168-181 (A9) exist; ADR 0055 OP 1-9 numbering matches the N-table.
C2 PASS (checked): owner quotes Q1, Q2, Q3 match owner-decisions.md:58-60 verbatim.
C3 PASS: all 38 hunks map to a fix-record id by content (INTERFACES 1-5 to PR2-C2, F41, F21, F40, F27, F7, F12, F1; part-a 6-17 to F1, F3, F5, F7, F8, F11, F19-F20, F21, F22, F24, F26, F27, F30-F32, F34, F36, F42; part-b 18-21 to F2, F5, F6, F13, F15-F18, F23, F26, F28, F30, F37, F39; part-c 22-32 to PR2-C1, F1, F9, F10, F11, F12, F18-F21, F29, F33, F35, F36, F38, F40, F43; part-d 33-38 to F1, F3, F4, F5, F8, F11, F12, F21, F22, F24-F26, F34, F36, F44). Mapping is by content, not by a hunk-id table in the fix record.
C4 PASS: id sets (A.1-A.7, B1-B8, C1-C7, D1-D7, I, N1-N9, E12-E13), pins and version string "0.1.0-draft" agree across the five files apart from the ANSWER/GATE item above.
C6 PASS: INTERFACES 152, part-a 280, part-b 151, part-c 171, part-d 154 lines (all under 1000; check-doc-length 500 is a separate gate).
C7 PASS: pins above match the artefact content.

preround: fail 17
