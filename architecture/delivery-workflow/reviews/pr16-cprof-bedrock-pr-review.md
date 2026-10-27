CODE-GATE-REVIEW: FAIL head=8956ad93da5e766cacdb2d42963e07ca607324ec blocking=1 medium=1
Reviewed-By: orchestrator xProfWorker1 PR16-r1

# PR #16 round 1: Phase B report (head 8956ad9, base 5184c0c)

## 1. Severity summary
1 Blocking, 1 Medium, 3 Advisory

## 2. Findings table

| # | Issue | Severity | Check | R | A | C Responses | Recommended Fix |
|---|-------|----------|-------|---|---|-------------|-----------------|
| B1 | CPROF_SSO_REGION is the one render input not validated (AWS_REGION is). It goes unchecked into sed (cprof-auth.zsh:27-28) and the output is piped into jq -s with no pipefail (cprof-tiers.zsh:47). Facets: (a) fail-open (pr-check-2, Blocking): a value such as a/b&c makes sed fail, jq -s of empty input still succeeds, and cprof new exits 0 with permissions.deny empty, no sandbox and no skipDangerousModePermissionPrompt; an executor with no deny list and no sandbox is then launchable, and it is new in this PR (before it the merge ran jq -s on files). (b) host injection (pr-check-5 and pr-check-6, Medium): a quote or comma in the value injects arbitrary hosts into the sandbox allowlist; the value * renders sso.*, oidc.* and portal.sso.* wildcards. | Blocking | pr-check-2 (also pr-check-5, pr-check-6) | integration-architect (pr-check-2); security-engineer (pr-check-5); platform-engineer (pr-check-6) | platform-engineer (pr-check-2, pr-check-5); devops-engineer (pr-check-6) | pr-check-2: security ✓, fullstack ✓, devops ✓, platform ✓. pr-check-5: integration ✓, devops ✓ (subsumed by the pr-check-2 fix), platform ✓. pr-check-6: integration ✓, security ✓, devops ✓ | Validate the SSO region with _cprof_region_valid in _cprof_render_ins and _cprof_tier_stale (fail closed, same message style); make render fail closed on a pipe failure (setopt localoptions pipefail in _cprof_render, or substitute with jq --arg instead of sed); add a test case for a malformed CPROF_SSO_REGION expecting rc 1 and no profile dir. |
| M1 | tools/onboarding.md:206 tells the reader to add a gateway host with an overlay but never says where the overlay lives (config/tiers/overlays/<project>.json, see config/tiers/overlays/README.md) or how to apply it (cprof new --overlay <project>, new profiles only); two sentences are also run together on one line. | Medium | pr-check-8 | technical-writer | fullstack-engineer | strategic-reviewer ✓, integration ✓ (accepts Medium, would not go below Low), fullstack ↩ (argued Advisory: gateway-only edge case, main flow unaffected) | Add one sentence naming the overlay file path and the --overlay flag with a pointer to config/tiers/overlays/README.md; split the line. |
| A1 | cprof use sources profile.env after _cprof_auth_apply (cprof.zsh:135-141), so a bedrock profile.env ANTHROPIC_API_KEY stays set after use. cprof launch strips it (cprof-tiers.zsh:171) and doctor WARNs; the tools/onboarding.md "What changes" bullet (line 186) and the tools/claude-profile/README.md bedrock bullet describe only the launch strip. Posted on pr-check-3 and pr-check-7 (one finding). | Advisory | pr-check-3, pr-check-7 | integration-architect (pr-check-3); fullstack-engineer (pr-check-7) | integration-architect | pr-check-3: strategic ✓, security ✓, platform ✓. pr-check-7: technical-writer ✓, integration ✓, security ✓, platform ✓ | Document the asymmetry in both places (profile.env is read after the unset in cprof use; only cprof launch strips Anthropic vars set there), or re-run the unset of _CPROF_BEDROCK_UNSET after profile.env in use. |
| A2 | tools/claude-profile/cprof.zsh:5 header comment layout lists <root>/<name>/{config,workspace,token,profile.env}: it omits the auth file and shows token as always present (bedrock has none). | Advisory | pr-check-8 | technical-writer | fullstack-engineer | strategic ✓, integration ✓, fullstack ✓ | Add auth to the list and note that token is oauth only. |
| A3 | config/README.md rewrites the machine-path warning (drops the ADR 0027 .nvm pointer) to say settings.json holds no absolute machine paths today. The claim is true (grep of config/settings.json for /Users, .nvm, /home is empty) but it is unrelated to Bedrock and is not named in either commit message. Also, owner-decisions.md has no Bedrock ruling text (cited only in the 46a69c5 message), so the ruling wording could not be verified. | Advisory | pr-check-9 | strategic-reviewer | integration-architect | technical-writer ✓, integration ✓, security ✓ | Name the change in the PR body, or split it out. |

No-issue checks: pr-check-cold-read (PASS, 13 files match the commit messages), pr-check-1 (PASS, layer ownership, merge order, _auth drop, tier.src region line and staleness correct), pr-check-4 (PASS, the four cprof suites exit 0 in five environments, every cprof*.zsh under 300 lines, max 271).

## 3. Deliberation trails (Blocking only)

> **pr-check-2-f1 deliberation (B1):**
> integration-architect (R): FINDING Blocking. Reproduced in a fresh extract of 8956ad9: CPROF_SSO_REGION='a/b&c' cprof new inj2 --auth bedrock --tier executor prints a sed error, exits 0, and writes settings.json with an empty deny list and no sandbox. Separately, CPROF_SSO_REGION='*' is accepted and renders wildcard hosts (Medium on its own).
> security-engineer (C): VALIDATE. Reproduced; narrow trigger (an owner-set env var containing / & or newline), but the failure is fail-open on the security boundary at exit 0 and any sed failure does the same. Blocking right for the fail-open; the wildcard case alone is Medium.
> fullstack-engineer (C): VALIDATE. Reproduced; Blocking because it fails open on the deny list and sandbox.
> devops-engineer (C): VALIDATE. A silently rendered executor with no deny list or sandbox is a fail-open of the tier control; the host-injection part (pr-check-5/6) is the same root cause, one fix closes both.
> platform-engineer (C, A): VALIDATE and CLOSED. Agreed severity Blocking for the fail-open; the wildcard/host-injection facet alone is Medium.
> pr-check-5 and pr-check-6 were closed at Medium as filed, each noted as the same root cause and fixed by the same change; they are reported here as facets of B1, not as separate findings.

## 4. Timed-out threads
None. timed_out_checks: gate1 [], gate2 [].
Quorum note: pr-check-9 was closed as a quorum partial (integration-architect's close names platform-engineer as missing); it has 3 validations (technical-writer, integration-architect, security-engineer) and only Advisory content, so the verdict is unaffected.

## 5. Overall verdict
NOT READY. B1 is a fail-open on the executor tier deny list and sandbox, introduced by this PR, with a small fix (validate the SSO region, fail closed on pipe failure, add a test). M1 should be fixed in the same round; A1 to A3 do not block merge.

## 6. Confidence notes
- B1: validated by 4 C members on pr-check-2 and independently re-found by two other seats (pr-check-5, pr-check-6), reproduced in fresh extracts by three seats. High confidence.
- M1: validated by 2, challenged once (to Advisory); the Accountable close kept Medium by majority.
- A1: found on two topics, validated by 7 responses in total. A2: 3 validations. A3: 3 validations; the owner-decisions.md point is not verifiable from the diff.
- Open points not raised as findings: portal.sso stays unconfirmed in research-30.md; the sandbox host list otherwise matches it.
- No read returned 200 messages, so no truncation.

## Orchestrator note (round 1 close-out)

Fixes (Opus fixer, non-author; fix-verifier Sonnet) address B1 (CPROF_SSO_REGION validated; render pipeline fail-closed: pipefail, JSON-object check, executor must keep a non-empty deny list and sandbox.enabled true; tests a6f-a6h), M1 (overlay defined in tools/onboarding.md), A1 (profile.env-after-use documented; code unchanged, matches oauth behaviour and test t16h), A2 (cprof.zsh header). A3 (config/README) left as is: the correction is true and small. Round 2 reviews 8956ad9...<head> next.
