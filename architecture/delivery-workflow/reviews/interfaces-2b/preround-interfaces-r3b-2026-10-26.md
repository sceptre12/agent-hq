# Pre-round check r3b (review-7-panel preround-check.md C1-C7), fixes r2b and r2c only

Scope: the four changed lines (part-a-state.md:41, part-b-desk.md:22, part-d-enums-topics.md:101, INTERFACES.md:100). Files live under interfaces/ (part-*.md), not the brief's architecture/delivery-workflow/ root. Read-only except this record. Checker: fresh read-only Haiku run, not the fixer or author (Rule 4).

C1 PASS INTERFACES.md:100 cite owner-decisions.md:28 opens at architecture/delivery-workflow-sources/owner-decisions.md:28 (D21 text: PR creation/first push allowed, per-commit gate); part-c-waves-control.md:118 (cited by r2b) opens with the same register.consumed / register.refused wording.
C2 PASS the changed lines name no external source without a pointer; INTERFACES.md:100 carries owner-decisions.md:28; other cites are in-set section pointers.
C3 PASS (from fix records and line content; git show not run) part-a-state.md:41 -> PR7-C4; part-b-desk.md:22 -> PR7-C4; part-d-enums-topics.md:101 -> PR7-C5; INTERFACES.md:100 -> V-R2-1. No unmapped hunk among the four lines.
C4 PASS register states agree by exact string across part-a-state.md:41, part-b-desk.md:22, part-c-waves-control.md:118: register.consumed (after REGISTERED ... ok), register.refused (on refused). Sha pins are not on these lines; C7 n/a, not compared.
C5 PASS part-a-state.md:41 rename rule; the row's source cell carries DEFAULT (integrator) for the rename set.
C5 FAIL part-b-desk.md:22 sentence "A lead sends no DESK line until its outbox/register.consumed exists (...)" states a rule with no default/question/proposed/owner-to-decide word; the DEFAULT (integrator) tag sits on the later re-attach sentence. Same class as the r2d C5 item on part-b-desk.md:36. Fix: add the tag to that sentence.
C5 PASS part-d-enums-topics.md:101 sentence ends with (`DEFAULT (integrator)`).
C5 PASS INTERFACES.md:100 Kind column DEF; legend at INTERFACES.md:43 defines DEF = DEFAULT (integrator). Literal word "default" is absent from the cell.
C6 PASS INTERFACES.md 202; interfaces/part-a-state.md 283; interfaces/part-b-desk.md 162; interfaces/part-c-waves-control.md 175; interfaces/part-d-enums-topics.md 156 lines; all under 1000. The brief sets no loop cap.
C7 n/a pins not stated in the brief.
preround: 1 fail (C5 part-b-desk.md:22)
