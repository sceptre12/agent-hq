# Pre-round check: delivery-architecture, round r1 (2026-10-26)
Artefact: skills/delivery-architecture (SKILL.md + references/, templates/ excluded). Pin 668af1c. Snapshot n/a (round 1). Fix list n/a.
C1 FAIL skills/delivery-architecture/SKILL.md:66 cites RLM:32, RLM:83 and H/learnings/...:16-17; artefact does not define the RLM or H/ prefix
C1 FAIL skills/delivery-architecture/references/contracts.md:3 cites RLM:32, RLM:83, RLM:89; undefined prefix
C1 FAIL skills/delivery-architecture/references/review-handoff.md:47 cites RLM:99; undefined prefix
C1 FAIL skills/delivery-architecture/references/architect-brief.md:14 cites dispatch-stop-conditions-02:307-320; not openable in W (same in decomposer-brief.md:13)
C2 FAIL skills/delivery-architecture/SKILL.md:66 Provenance names INTERFACES 1.1.0 parts with no path:line-range pointer or verbatim quote
C3 PASS round 1, n/a
C4 FAIL skills/delivery-architecture/SKILL.md:15-31 vs architecture/delivery-workflow/tasks/15-delivery-architecture.md:57: SKILL has step 8 (re-sync drafts) and 5a, spec list has neither; SKILL moves review-architecture.md after h1-packet (steps 13-14), spec lists it before h1-packet
C5 FAIL skills/delivery-architecture/SKILL.md:31 "publish nothing" (external publication) has no default/question/proposed/owner-to-decide token or anchor
C5 FAIL skills/delivery-architecture/references/review-handoff.md:31 "at most 9" cap, no token or anchor
C5 FAIL skills/delivery-architecture/references/review-handoff.md:32 "at most 7 seats" cap, no token or anchor
C5 FAIL skills/delivery-architecture/references/security-sensitive.md:31 "it never removes a control" policy sentence, no token or anchor
C6 PASS largest file tree-rules.md 70 lines; check-doc-length.sh W: 0 blocking, 0 over 500 lines
C7 PASS artefact last touched at 668af1c = pin in brief and record (note: `git -C W log -1` returns HEAD 7aaea78, not 668af1c)
preround: 4 fails
