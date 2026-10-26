# Pre-round check r4 (post-final-fix), delivery-pipeline (W2 item 29), 2b review-7-panel, 2026-10-26

Artefact set: skills/delivery-pipeline/SKILL.md and references/{stages,tick-relay,launcher,resume,stops-and-posts,provenance}.md (W = agent-hq worktree delivery-w0). Scope: text changed or added by fix-delivery-pipeline-r3-2026-10-26.md. Checks run: C1, C2, C5, C6. C3, C4, C7 n/a (KNOWN / covered by verifier). Read-only except this record. No sub-agents.

C1 FAIL references/stages.md:87 (fix row s4-2 cites :87) the pr-open / merge_sha-empty precondition text is at :88; :87 is blank
C1 FAIL references/stages.md:91 (fix row s3-1 cites :91) the REJECTED posting text is at :92 (5. On REJECTED); :91 is the DONE step
C1 FAIL references/stages.md:103 (fix rows s4-1, s5-1 cite :103) the FAIL re-entry and the st<N> ticket-key text is at :104; :103 is the POSTMERGE: STOP bullet
C1 FAIL references/stages.md:104 (fix row s1-1 cites :104) the CLEANUP DONE pm text is at :105; :104 is the POSTMERGE: FAIL bullet
C1 FAIL references/stops-and-posts.md:64 (fix row s3-1 cites :64) the REJECTED-posting clause is at :66 (Human steps) and :53; :64 is the Stops-per-sub-task item
C1 PASS other fix-row cites checked: SKILL.md:18,19,24-27; stages.md:56,64,65; tick-relay.md:56,62,68,70,73,74,80,86,106; resume.md:20,33,51; stops-and-posts.md:27; provenance.md:55,66,67,70-73; launcher.md:26,46,47,52-68
C2 FAIL references/stages.md:56 "RESOLVED Q1" names an owner ruling and carries no path:line-range pointer or verbatim quote (fix row PR3-C5 edited this line)
C2 FAIL references/stages.md:88 "(spec 29 §7, AM-4 W2-7)" names a spec and an amendment with no path:line-range pointer or verbatim quote (line edited by 29-37)
C2 PASS spot-checked external cites resolve to matching text: owner-decisions.md:6 (D5), :58 (Q1), :89 (OQ-1); skills/delivery-dispatch-plan/references/plan-check-loop.md:20 (round cap 3, owner D7)
C3 n/a (KNOWN / covered by verifier)
C4 n/a (KNOWN / covered by verifier)
C5 FAIL references/stops-and-posts.md:51 curable-row rule (resend with a fresh id once per cause on its trigger; marker/order triggers) has no "default", "question", "proposed" or "owner to decide" tag in the row; the tag sits only in the paragraph at :53
C5 PASS other fix-added rules in SKILL.md, stages.md, tick-relay.md, resume.md, launcher.md, provenance.md carry a proposed/default/owner-to-decide tag
C6 PASS largest file 115 lines (stages.md); the loop brief sets no line cap
C7 n/a (KNOWN / covered by verifier)
preround: 7 fails
