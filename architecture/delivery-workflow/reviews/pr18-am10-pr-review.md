CODE-GATE-REVIEW: FAIL head=1c1b0f2b3699b462b34b4a3e403533f7611ce70a blocking=0 medium=1
Reviewed-By: orchestrator xProfWorker1 PR18-r1

# PR #18 round 1 Phase B (AM-10, branch wt/am10-ci-run-id, head 1c1b0f2, base bf638b2)

## 1. Severity summary
0 Blocking, 1 Medium, 4 Advisory

## 2. Findings table
| # | Issue | Severity | Check | R | A | C Responses | Recommended Fix |
|---|-------|----------|-------|---|---|-------------|-----------------|
| M1 | ci_run_id is required (int, no null) on every checks[] item, but verbs.md:146-148 derives it only from an Actions link (.../actions/runs/<id>/job/<id>). A check without an Actions run (external status such as Sonar, empty link, pending) has no producible value, and there is no parse rule or refusal. Posted on pr-check-2, 4, 5, 6, 8 and reported once here. pr-check-6 was raised from Advisory to Medium by two challenges and closed Medium. | Medium | pr-check-2 (also 4, 5, 6, 8) | integration-architect (first poster) | platform-engineer | platform-engineer ✓, devops-engineer ✓ and ↩ (raised pr-check-6), security-engineer ↩ (raised pr-check-6), fullstack-engineer ✓, integration-architect ✓ | State the parse as /actions/runs/([0-9]+)/ in verbs.md and B6. Then either reject with action-failed when there is no match, make ci_run_id nullable with ci-fix-loop routing null to CI: HUMAN, or declare required checks Actions-only. This is an owner or lead decision. |
| A1 | Wording drift across the six places: B9 and the AM-10 row say a head's checks may come from several runs, the B6 row says one head's checks, verbs.md and ci-fix-loop step 1 omit "on head", and required-ness is stated only in B9. | Advisory | pr-check-8 | technical-writer | (per RACI) | none beyond closure | Reuse one sentence verbatim in B6, B9, verbs.md and SKILL step 1. |
| A2 | ci-fix-loop step 2 says job is the check name, but B4 and verbs.md never define it. Only ci-fix-loop defines it. | Advisory | pr-check-8 | technical-writer | (per RACI) | none beyond closure | Add "job = check name" to the B4 ci-logs row if intended. |
| A3 | gh field names (--json name,bucket,link) and the run id inside link are unverified live. devops-engineer judged the fields real, but the Actions link shape is unverified until the pilot. | Advisory | pr-check-4, 6 | devops-engineer, platform-engineer | (per RACI) | fullstack-engineer noted unverified | Confirm in the pilot. |
| A4 | The AM-10 row and freeze line are dated 2026-10-27, while sibling rows are 2026-10-26. This was challenged in pr-check-8 and held at Advisory. The date is likely the UTC commit date and a probable non-issue. | Advisory | pr-check-3, 8 | integration-architect, technical-writer | (per RACI) | held at Advisory at closure | Confirm the date, otherwise drop. |

Checks with no issues: pr-check-cold-read, pr-check-1, pr-check-7, pr-check-9 (no messages). pr-check-3 passed apart from the A4 note. The stamp sweep passed: 60 of 67 removed lines carry 1.9.0, all current-contract stamps, 10 sampled, and the residual 1.9.0 hits are history that was not rewritten. E54 continues E53. desk-req 558/0 and jq ok.

## 3. Deliberation trails (Blocking only)
None. There are no Blocking findings. For M1: the pr-check-6 Advisory by platform-engineer was challenged by devops-engineer and security-engineer ("required and strict, additionalProperties false, so the failure is hard") and merged into M1 as Medium.

## 4. Timed-out threads
None. gate1 [] and gate2 [] (all 7 seats signalled both phases).

## 5. Overall verdict
READY WITH CONDITIONS: resolve M1 (define the non-Actions check case) before merge. The Advisories do not block.

## 6. Confidence notes
- M1 was validated by 5 or more C members across topics, so it is high confidence. pr-check-5 closed "quorum partial" (fullstack-engineer's reply was not in yet), but fullstack-engineer validated on pr-check-4 and 8.
- A1 to A4 are solo findings from technical-writer (A3 is partly corroborated). A4 is probably a non-issue.
- No read returned 200 messages, so nothing was truncated. The gh link shape was not verified live.

## Orchestrator note (round 1 close-out)

Fix (Opus fixer, non-author; fix-verifier Sonnet) addresses M1: per-check ci_run_id becomes integer-or-null on the reply only (requests still require an int), verbs.md gets the exact /actions/runs/<id> parse rule and a no-guessing rule, part B6 defines job as the check name and the policy refusal for a check with no run, ci-fix-loop stops a null-id failing check as external-service with a no-ci-run line; A1 wording unified, A3 gh field names marked for P0 re-measure. Round 2 reviews 1c1b0f2...<head> next.
