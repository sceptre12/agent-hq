# Pre-round check r3, item 15 delivery-architecture (2026-10-26)
C1 FAIL skills/delivery-architecture/SKILL.md:23 cite `interfaces/part-a-state.md:100` lands on the H-pr row; the H-prod gate row is part-a-state.md:101. Other cites resolve under architecture/delivery-workflow/ (base not stated in the cite); H/ and dispatch-stop-conditions-02 cites are external with prefix defined in the artefact (PASS-UNVERIFIABLE)
C2 PASS skills/delivery-architecture/SKILL.md:21 OQ-1 and AM-3 cites string-match owner-decisions.md:88-89 and INTERFACES.md:25 (sampled, not exhaustive)
C3 PASS SKILL.md:13-33 (R2-6 step 1, R2-2 steps 10/12, R2-1 step 5 A3, PR4-C2 step 5a, R2-3 step 7, R2-4 step 13, R2-5 step 14); review-handoff.md:24-32 R2-2 §2a, :42-48 R2-4 §3, :67-70 R2-2 §8; h1-packet.md:8-15 R2-5, :43-55 R2-5/R2-2; tree-rules.md:14-20 R2-6, :68-75 R2-3 K12 and R2-1 K13 (every hunk maps to a finding id)
C4 FAIL skills/delivery-architecture/SKILL.md:24 step 8 (re-sync drafts) has no counterpart in spec 15 §8 item 3 (architecture/delivery-workflow/tasks/15-delivery-architecture.md:57); other step order matches; no sha pins in either
C5 FAIL skills/delivery-architecture/references/h1-packet.md:12 skill-authored answer rule ("ok means every recommended option...") carries no default/question/proposed/owner-to-decide marker and no anchor
C6 PASS largest file skills/delivery-architecture/SKILL.md 69 lines; check-doc-length.sh: 0 blocking files over 500 lines for this directory
C7 FAIL skills/delivery-architecture/ pin 668af1c (brief, last commit touching the directory) vs worktree HEAD 5fee2b3 (descends from 668af1c, does not touch the directory); brief's pin command now returns 5fee2b3
preround: 4 fails
