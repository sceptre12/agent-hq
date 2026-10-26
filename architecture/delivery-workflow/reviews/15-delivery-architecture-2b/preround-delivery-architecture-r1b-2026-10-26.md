# Pre-round check: delivery-architecture, round r1b (2026-10-26)
Artefact: skills/delivery-architecture (SKILL.md + references/, templates/ excluded). Pin 668af1c (artefact last touched there; HEAD 807a9fa, artefact unchanged vs HEAD). Snapshot: snap-r0. Fix list: fix-delivery-architecture-r0-2026-10-26.md (PR1-*).
C1 PASS SKILL.md:68 RLM:32, RLM:83, RLM:89, RLM:99, H/learnings wave 16-17, part-06:68, INTERFACES.md:3 and all section ranges open and match
C1 PASS references/architect-brief.md:13 dispatch-stop-conditions-02:307-320 heading at 307; COMMON block identical to part-03:6 (decomposer-brief.md:12 same)
C1 PASS references/review-handoff.md:31-32 part-02-skill-inventory.md:56 "never exceed 7 at 2b or 9 at Rung 2"; :47 RLM:99 is G46
C1 PASS references/security-sensitive.md:31 tasks/15-delivery-architecture.md:96 is RESOLVED Q2; :3 plan-check-w1-specs.md §5 OQ-1 is at :104-106
C2 FAIL references/architect-brief.md:3 "INTERFACES 1.1.0 part D2.1": no path:line pointer and stale (INTERFACES.md:3 is 1.3.0); same in decomposer-brief.md:3, contracts.md:3, review-handoff.md:3, security-sensitive.md:3 and :15 (PR1-C2 covered only SKILL.md:68)
C3 PASS 8 hunks vs snap-r0, all mapped: SKILL.md:33 PR1-C4; SKILL.md:31 PR1-C5a; SKILL.md:68 PR1-C1a/C2; architect-brief.md:13 and decomposer-brief.md:12 PR1-C1d; contracts.md:3 PR1-C1b; review-handoff.md:31-32 PR1-C5b; review-handoff.md:49 PR1-C1c; security-sensitive.md:31 PR1-C5c
C4 PASS SKILL.md:33 Spec map states 5a and 8 as sub-steps and write-then-mv at 13/14; accurate vs tasks/15-delivery-architecture.md:57 and §4 row 27 ("written last"); no sha pins on either side
C5 FAIL SKILL.md:39 publication rule ("ticket-clerk publishes through the desk only after H1.ok") has no token and no anchor; same substance as anchored SKILL.md:31
C5 PASS SKILL.md:31, references/review-handoff.md:31-32, references/security-sensitive.md:31 now anchored (PR1-C5a/b/c); security-sensitive.md:29 under the "plan-check default" heading
C6 PASS check-doc-length.sh W: 0 blocking, 0 over 500 lines; skills/delivery-architecture not listed; largest file tree-rules.md 70 lines
C7 PASS artefact head sha 668af1c equals the pin in the brief and this record; brief's "git -C W log -1 = 668af1c" is wrong (HEAD is 807a9fa)
preround: 2 fails
