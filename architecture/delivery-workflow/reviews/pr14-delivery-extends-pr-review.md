CODE-GATE-REVIEW: FAIL head=58ca36ceebdca69d91198a38dad86b1c973592c9 blocking=0 medium=2
Reviewed-By: orchestrator xProfWorker1 PR14-r1

# PR #14 round 1 - Phase B report (local-diff mode)

Session swarm-pr-review-20261026-83deb093. Repo ~/projects/agent-hq-worktrees/delivery-extends, base 8082257, head 58ca36c. All 7 seats signalled both phases; timed_out_checks gate1 [] and gate2 [].

## 1. Severity summary
0 Blocking, 2 Medium, 5 Advisory.

## 2. Findings table
Markers: ✓ VALIDATE, ⬆ ESCALATE, ↩ CHALLENGE, + ADD. R is the seat that posted the finding; A is the seat that posted the CLOSED line.

| # | Issue | Severity | Check | R | A | C Responses | Recommended Fix |
|---|-------|----------|-------|---|---|-------------|-----------------|
| M1 | skills/doc-reviewer/references/delivery-doc-checks.md DOC-1 requires 18 items (design template 5.3) as headings for dispatch-plan.md and grades a miss Medium. The template on main (skills/delivery-dispatch-plan/references/templates/dispatch-plan.md at 8082257) has 13 headings P0-P12; version bump, throughput, shepherd cadence, cleanup rule and the review rung table are lines inside P-sections. DOC-1 would raise false missing-section findings on every real plan and burn D7 rounds. | Medium | pr-check-2 | integration-architect | platform-engineer | platform ✓, fullstack ✓, security ✓, devops ✓ | Map the 18 items to the P0-P12 headings (or accept a named line inside the owning P-section) and cite the template file as the authority. |
| M2 | skills/pr-review/references/review-record.md (and SKILL.md line 232) writes the record as line 1, line 2, a blank line 3, then the report, and says the verifying seat "writes" line 3. Main skills/pre-pr-gate step 17 says the Verified-By seat appends line 3, so it lands after the report, leaves line 3 blank, and the delivery-desk check (checks.md:120, Verified-By regex on line 3) fails. The 1.0.0 wording said "inserts it as line 3"; the EXTEND dropped that verb. | Medium | pr-check-2 | integration-architect | platform-engineer | platform ✓, fullstack ✓, security ✓, devops ✓ | State in review-record.md that the verifier INSERTS Verified-By as line 3 (replacing the blank placeholder), or write no blank line 3; align pre-pr-gate step 17 if it stays "append". |
| A1 | tools/code-gate/test-map.tsv lines 1-4: header comment reordered (CODE_GATE_TIMEOUT line first, "hq code-gate test map" line third) and the blank line after the header dropped; not claimed by the PR. Looks like a whole-file LC_ALL=C sort swept the comments. Parser ignores # lines; the added wave-execution tests/run.sh row is correct, sorted, unique, file exists, reachable via include *.sh. Reported once each on pr-check-1, 4, 7 and 9 by four seats; deduplicated here. | Advisory (orchestrator ruling; closers split, see below) | pr-check-1, 4, 7, 9 | platform-engineer (c1), devops-engineer (c4), fullstack-engineer (c7), strategic-reviewer (c9) | devops-engineer (c1), platform-engineer (c4), integration-architect (c7, c9) | integration ✓ (c1, c4, c7, c9), security ✓ (Advisory on risk alone), technical-writer ✓ (c7, c9, Advisory), devops ↩ (c1, to Advisory), platform ↩ (c4, c7, to Advisory), fullstack ↩ (c4, to Advisory) | Restore main's header lines 1-4 and the blank line verbatim (8082257:tools/code-gate/test-map.tsv); keep only the one added run.sh row. Fixed anyway. |
| A2 | bus-start-standalone.md lines 17-19: the pre-bind lsof check is not a claim, so two concurrent default reviews can race for P+10. The doc already states the race and the port-file equality check stops the loser. In-run bus-start-run.md claims the port properly. | Advisory | pr-check-5 | security-engineer | platform-engineer | platform ✓, integration ✓, devops ✓ | None required. |
| A3 | skills/wave-execution/references/example-spec/README.md:67 and tests/run.sh:4 say run.sh checks rule 5. run.sh:51 codes bad(5,...), but no invalid-5 fixture exists (fixtures cover 9, 11, 13, 14, 15), so the coverage claim is overstated. | Advisory | pr-check-8 | technical-writer | fullstack-engineer | integration ✓, fullstack ✓, strategic ✓ | Add an invalid-5-* fixture or drop 5 from the checks wording. |
| A4 | skills/delivery-run/references/handoffs-and-modes.md:37 (main) cites wave-execution SKILL.md:190 for the checkpoint location; it is now at lines 193-194. | Advisory | pr-check-3 | integration-architect | platform-engineer | none | Update the line cite (consumer-side file, outside this diff). |
| A5 | No file on main (delivery-run, delivery-pipeline) passes UNIT_MODE=team to feature-change; the implementer brief is not a feature-change caller. The EXTEND declares an input with no current consumer. | Advisory | pr-check-7 | fullstack-engineer | integration-architect | none | None required now; note for the next delivery-run change. |

No Blocking or Medium finding from pr-check-6, pr-check-cold-read (PASS only). The 18/18 run.sh result, 0 blocking from check-doc-length, hygiene (no /Users, no personal-project names, no secrets) and the producer/consumer contract match against INTERFACES 1.9.0 were confirmed independently by several seats.

## 3. Deliberation trails (Blocking findings only)
No Blocking findings, so no trail is required. The one split worth recording:

> **test-map.tsv header (A1) severity split:**
> Raised Medium by platform-engineer (c1), devops-engineer (c4), fullstack-engineer (c7), strategic-reviewer (c9).
> Challenged to Advisory: devops-engineer (c1), platform-engineer (c4, c7), fullstack-engineer (c4); technical-writer and security-engineer (on risk alone) lean Advisory; integration-architect holds Medium.
> Closers disagree: pr-check-1 closed Medium by majority (devops-engineer), pr-check-4 closed Advisory (platform-engineer), pr-check-7 closed Medium-or-Advisory split with "orchestrator to rule" (integration-architect), pr-check-9 closed Medium (integration-architect).
> Orchestrator ruling: a comment-only reorder with the parser unaffected is Advisory, fixed anyway.

## 4. Timed-out threads
None.

## 5. Overall verdict
READY WITH CONDITIONS. Conditions: fix M1 and M2 (both are contract mismatches with main consumers that would fail or mis-grade in the delivery path), and apply the A1 header restore in the same pass. A2-A5 do not block.

## 6. Confidence notes
- Validated by 3 or more C members: M1 (4 seats), M2 (4 seats), A2 (3 seats), A3 (3 seats), A1 (content confirmed by 6 seats across the four topics; only its severity is contested).
- Solo findings (no C response): A4 (integration-architect, folded into a PASS) and A5 (fullstack-engineer, folded into a PASS). Both are Advisory with no runtime effect.
- M1 and M2 were each posted by one seat and validated by all four other responders; M2 has two valid fix sides (review-record.md or pre-pr-gate step 17), so the fixer should pick one and keep the other consistent.

Presented only; no fixes applied.

## Orchestrator note (round 1 close-out)

Fix commit f136a03 (fixer Opus, non-author; fix-verifier Sonnet: CLEAN) addresses M1, M2 and A1: DOC-1 dispatch-plan list = the 13 template sections P0-P12; pr-review record line 3 is an explicit empty placeholder the verifying seat replaces in place; test-map header restored to main's. Follow-up outside this PR (main): pre-pr-gate step 17 says the verifying seat "appends line 3"; it must replace line 3 in place (INTERFACES A.6 regex, desk checks.md:120). A2-A5 are advisory and left as is. Round 2 reviews 58ca36c...<head> next.
