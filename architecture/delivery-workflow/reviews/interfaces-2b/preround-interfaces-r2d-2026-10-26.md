# Pre-round check r2d (review-7-panel preround-check.md C1-C7), fix r1f only

Scope: fix r1f (diff-r1f.patch, six hunks; record reviews/interfaces-2b/fix-interfaces-r1f-2026-10-26.md, ids N1, N2, N3, PR5-C4). Read-only except this record. Checker: fresh read-only Haiku run, not the fixer or author (Rule 4).

Pins (C7, shasum -a 256, first 12 hex): INTERFACES.md 21745488f112; interfaces/part-a-state.md f9191172abbe; part-b-desk.md c8b4b1fc99da; part-c-waves-control.md 69327ba92a2d; part-d-enums-topics.md a20e24b7bdc8. All match the brief.

Output:
C1 PASS INTERFACES.md:111,33; part-b-desk.md:36,62; part-a-state.md:40,210; part-d-enums-topics.md:81 open; quoted text matches the r1f diff.
C2 PASS no changed sentence names an external source (ADR, owner message) without a pointer; "part C5.1" and "part INTERFACES.md script table" are in-set section pointers, as in r2c.
C3 PASS 6 hunks mapped: INTERFACES @-108 N1 (row 111); part-a @-37 N2 (:40); part-a @-207 PR5-C4 (:210); part-b @-33 N1 (:36); part-b @-59 N1 (:62); part-d @-78 N3 (:81).
C4 FAIL part-a-state.md:40 names the conductor rename as `.sent-<id>` or `.refused`; part-c-waves-control.md:110 and INTERFACES.md:113 name only `.sent-<id>`. Fixer: align the rename set in part-c:110 and INTERFACES.md:113 (either add `.refused` or drop it from part-a:40). Note that editing part-c changes its pin 69327ba92a2d, so the pin must move with it. Other C4 items PASS: ids N1, N2, N3, PR5-C4 agree; the `.inflight/target` text agrees across INTERFACES.md:111 and part-b:36,62; the catalog.sh register argument list agrees across INTERFACES.md:33 and part-a:210 (7 args, kind=lane-lease).
C5 FAIL part-b-desk.md:36 ("Before acting ... writes the file ... holding one line" states a step rule with no default/question/proposed/owner-to-decide word; the DEFAULT tag sits on the next sentence); part-a-state.md:40 (conductor rename rule, no marker); part-a-state.md:210 (lease acquire rule, no marker in that sentence). Judgement: the three are mechanisms, but they state rules; fixer adds the tag to these sentences only.
C6 PASS INTERFACES.md 182, part-a-state.md 278, part-b-desk.md 158, part-c-waves-control.md 174, part-d-enums-topics.md 155 lines; all under 1000. The brief sets no loop line cap.
C7 PASS pins above match the artefact heads and the brief.
preround: 2 fails (C4, C5)

What it is not: no seat judgement, no severity, no scope opinion. The fixer fixes only the listed items; the check re-runs once.
