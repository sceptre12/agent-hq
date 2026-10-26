# Pre-round check r2: delivery-pipeline (W2 item 29), 2026-10-26
Pin: 2c10079 + uncommitted fix (HEAD 8f9d3e3; skill files unchanged in git since 2c10079). Fix record: fix-delivery-pipeline-r1-2026-10-26.md.
C1 PASS skills/delivery-pipeline (new external cites opened: owner-decisions :5 :6 :8 :11 :12 :25 :29 :58 :89, interfaces A.1 :7, A.2 :53, A.4 :204, B1 :7, C2 :60, C6 :152, D1 :6, D3 :105; post-merge-verify :27 :50; plan-check-loop :20) all resolve; internal cites not opened
C2 FAIL references/provenance.md:9 the scope-control retro (2026-08-26) is named with no path:line pointer or verbatim quote (its :42-44 cite was dropped)
C3 PASS all hunks map to r1 ids: SKILL.md:10 PR1-C2; :15 r1-06; :16 r1-09/r1-24; :17 r1-04; :18 r1-14; :19 r1-24/r1-02/PR1-C5; :21 r1-07; :25 r1-05/r1-23; :26 r1-08/r1-10; :27 r1-01/r1-02/r1-03/r1-22/r1-27; :28 r1-13; :31-37 r1-09/r1-06/r1-11 (rules); :39 PR1-C5; :40 PR1-C2; launcher.md r1-24/r1-26/r1-25/r1-08/r1-09/PR1-C5/PR1-C2; resume.md r1-06/r1-08/r1-09/r1-10/r1-12/r1-17/r1-23/r1-27; stages.md r1-02/r1-04/r1-05/r1-06/r1-14/r1-23/r1-25/r1-22; stops-and-posts.md r1-03/r1-13/r1-15/r1-19/r1-21/PR1-C5; tick-relay.md r1-06/r1-07/r1-11/r1-13/r1-20/r1-23/r1-27/r1-08; provenance.md PR1-C1/PR1-C2/29-13..29-24 rows
C4 FAIL (KNOWN only): spec tasks/29-delivery-pipeline.md unchanged since 2c10079; still cites INTERFACES 1.3.0 and older 29-x ids; KNOWN, outside fixer scope; no new FAIL
C5 FAIL SKILL.md:25 step 10 "no terminal pr-merge REJECTED or .req.noreply blocks this head (29-16)" has no default/proposed/question/owner-to-decide marker in the sentence
C5 FAIL SKILL.md:27 step 12 "repo = primary_repo, backend = the st0 backend, 29-19" has no marker in the sentence
C5 FAIL references/resume.md:48 "not relaunched a third time" bullet (relaunch-limit rule) has no marker
C5 FAIL references/tick-relay.md:101 "INVALIDATE goes only to successors already released or later" has no marker
C6 PASS largest file 130 lines; no file at or over 1000
C7 PASS (KNOWN) skill files unchanged since 2c10079; HEAD moved by other agents' commits; uncommitted owner-decisions.md +3 lines is outside this fix (its cites still match)
preround: 5 fails (C2 x1, C5 x4; C4 KNOWN only)
