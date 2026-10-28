CODE-GATE-REVIEW: PASS head=9825a8655b2aa5a039b5073636f6949d274744f6 blocking=0 medium=0
Reviewed-By: orchestrator xProfWorker1 PR16-r2

# PR #16 round 2, Phase B report (sceptre12/agent-hq, branch wt/cprof-bedrock-onboarding)

Reviewed head 9825a86 against round-1 head 8956ad9 (fix commit 1e9a233 plus 9825a86, which adds only the round-1 record). Session swarm-pr-review-20261026-264aea3a-r2.

## 1. Severity summary
0 Blocking, 0 Medium, 2 Advisory

## Round-1 items
- B1 (CPROF_SSO_REGION unvalidated, executor render left with empty deny and no sandbox at exit 0): FIXED. Seats reproduced in fresh extracts of 9825a86. Values a/b&c, *, a|b and trailing-newline forms exit 1 with no profile dir (8956ad9 exited 0 with a sed error). An executor overlay setting sandbox.enabled false is refused ("invalid or weakened settings object; nothing written"). Desk plus bedrock still renders (sandbox absent by design). The oauth executor settings.json is byte-identical to 8956ad9 (cmp). The guard (cprof-tiers.zsh:53) runs after the KEEP merge and before the write, covers new, sync --force (:111) and launch re-render (:135), and pipefail is scoped locally. All four suites exit 0 (test_cprof 59, test_cprof-auth 26 including a6f/a6g/a6h, test_cprof-checks 9, test_cprof-link 23). cprof-tiers.zsh is 239 lines.
- M1 (onboarding.md used "overlay" without defining it): FIXED. onboarding.md:208-218 gives the path config/tiers/overlays/<project>.json, the add-only rule, the --overlay command and a JSON example; it matches overlays/README.md and cprof.zsh:62, and the example rendered with RC=0.
- A1 (profile.env sourced after the auth apply in use): FIXED as documentation (README and onboarding.md:170), agreeing with cprof.zsh:139 and cprof-tiers.zsh:175-176.
- A2 (cprof.zsh:5 header comment): FIXED, matches the auth file and no token for bedrock.

## 2. Findings table
| # | Issue | Severity | Check | R | A | C Responses | Recommended Fix |
|---|-------|----------|-------|---|---|-------------|-----------------|
| A1 | Design Extension (architecture/claude-profile-02.md lines 21-26) does not describe that CPROF_SSO_REGION must be a region id (exit 1 otherwise) nor that executor renders fail closed. Posted Medium, challenged to Advisory; agreed Advisory. | Advisory | pr-check-3 | integration-architect | platform-engineer | platform-engineer ↩ (to Advisory), security-engineer ✓, strategic-reviewer ✓ | Add two sentences to the Extension: validated like AWS_REGION; executor render fails closed with nothing written. Doc-only follow-up. |
| A2 | Fail-closed guard does not check allowUnsandboxedCommands or wildcard allowedDomains from an overlay (overlays are owner-authored; README forbids weakening; not a bypass of the B1 env-injection threat). | Advisory | pr-check-2 | integration-architect | platform-engineer | security-engineer + (low follow-up) | Extend the jq -e guard with allowUnsandboxedCommands != true and no wildcard host. Not merge-blocking. |

All other checks (cold-read, 1, 4, 5, 6, 7, 8, 9): PASS, no issues, agreed severity none.

## 3. Deliberation trails (Blocking only)
None: no Blocking findings.

## 4. Timed-out threads
None (gate1 [], gate2 []). Four Phase 1 seats stalled and were redone; the redo seats posted and their posts are the ones used here.

## 5. Overall verdict
READY (both Advisories are follow-ups, not merge conditions).

## 6. Confidence notes
- Validated by 3+ seats: B1 fixed (platform-engineer, integration-architect, devops-engineer, fullstack-engineer, technical-writer, strategic-reviewer, security-engineer, all with the 26-case suite or reproductions). A1 is 3 votes for Advisory.
- Solo: A2 (integration-architect, with security-engineer's low-severity ADD). One gap: fullstack-engineer did not separately run the oauth byte-compare, but platform-engineer and integration-architect did.
- No read hit the 200-message limit.

## Orchestrator note (round 2 close-out)

Reviewed head 9825a86 = round-1 head 8956ad9 + fix 1e9a233 + the round-1 record. Advisories left for a follow-up: the design Extension should state the CPROF_SSO_REGION validation and the fail-closed executor render (two sentences); the render guard could also refuse allowUnsandboxedCommands and wildcard allowedDomains from an overlay. main moved to 605bb7f (PR #17) after this branch forked: README.md conflicts (both PRs add one bullet to "How to use it"); the desk resolves it in the merge commit keeping both bullets, so the reviewed head stays the PR head. This record is committed after the reviewed head; the desk merges the reviewed head, as for PRs #13-#15 and #17.
