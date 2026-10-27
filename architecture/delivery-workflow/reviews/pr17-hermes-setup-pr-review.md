CODE-GATE-REVIEW: FAIL head=8e417cf88b9b24910780d94b9f4c44a2998dca08 blocking=0 medium=3
Reviewed-By: orchestrator xProfWorker1 PR17-r1

# PR #17 round 1 - Phase B report (pr pr-review panel, local-diff mode, head 8e417cf, base 5184c0c)

## 1. Severity summary
0 Blocking, 3 Medium, 10 Advisory

## 2. Findings table
Agreed severities are taken from the CLOSED lines. C markers: ✓ validate, ↩ challenge, ⬆ escalate, + add.

| # | Issue | Severity | Check | R | A | C Responses | Recommended Fix |
|---|-------|----------|-------|---|---|-------------|-----------------|
| M1 | tools/hermes/setup/required-config.tsv line 22: `curator.enabled` is `unset-or-eq false`, but Hermes defaults to true, so a config with no curator block passes with the curator on (mutation reproduced) | Medium | pr-check-1 | platform-engineer | devops-engineer | devops ✓, security ✓, integration ✓ | Make the row `eq false`, matching config-edits.md and config.active.yaml |
| M2 | check-config runs the hook-file and hook-mode (555) checks only when `--home` is passed; with `HERMES_HOME` alone it prints SKIP, n drops 23 to 21, and the verdict can still be PASS | Medium | pr-check-4 | devops-engineer | platform-engineer | fullstack ✓, security ✓, platform ↩ (Advisory), integration ↩ (Advisory) | Gate the hook checks on the resolved home (flag or env), or fail on env-only; note it in INSTALL step 5 |
| M3 | INSTALL.md:215-217 copies and sed-writes onto bin/ files, then chmods them 555; section 8 says to re-run steps 2-5, and a second cp or redirect onto a 555 file fails (Permission denied, reproduced), so the update and re-pin path cannot be followed | Medium | pr-check-3 | integration-architect | platform-engineer | platform ✓, security ✓, strategic ✓ | `rm -f` the three targets (or `cp -f`) before the copy and sed in step 4; mention it in section 8 |
| A1 | INSTALL.md:168 says model.base_url was "left from an earlier setup"; no repo source supports it, and step 3 diverges from config.active.yaml on base_url | Advisory | pr-check-cold-read | integration-architect | integration-architect | platform ✓ | Drop the history claim or mark it UNVERIFIED; state the divergence |
| A2 | `model.provider` is owned only by the tsv, config.active.yaml and INSTALL step 3; config-edits.md has no line for it though the tsv header says they agree | Advisory | pr-check-1 | platform-engineer | devops-engineer | devops ✓, security ✓, integration ✓ | Add a model.provider line to config-edits.md |
| A3 | hermes-up enforces `platforms.api_server.extra.host == 127.0.0.1` (and the .env allowlist, hook matcher/timeout), which check-config does not, so INSTALL's full check can pass a config the gateway later refuses (fails closed at launch) | Advisory | pr-check-1, pr-check-2, pr-check-3 | platform-engineer, integration-architect | devops-engineer, platform-engineer | devops ✓, fullstack ✓, platform ✓, security ✓ | Add an `unset-or-eq 127.0.0.1` row, or note in the tsv header or INSTALL that hermes-up owns these |
| A4 | setup/README.md has only a pointer line: no Files rows for INSTALL.md, check-config or required-config.tsv, no "enforces" bullet; the Known gaps toolset-match bullet could be worded more precisely (it stays accurate for config-edits.md; Known gaps are owner-accepted) | Advisory (downgraded from Medium) | pr-check-2 | integration-architect | platform-engineer | devops ↩, platform ↩, fullstack ✓ (Medium) | Add the Files rows and one enforces bullet; refine the gap wording only with owner acceptance in mind |
| A5 | check-config echoes up to 80 chars of the live value on a FAIL line (`got <value>`), contradicting the header's "only TSV keys and expected values"; a mis-pasted token in a scalar key would be printed | Advisory (downgraded from Medium) | pr-check-5, pr-check-2 | security-engineer, integration-architect | platform-engineer | devops ↩, platform ↩, integration ✓ (Medium), fullstack ✓, security ✓ | Print a kind or length tag on mismatch, or document the echo in the header and INSTALL.md:276 |
| A6 | INSTALL.md curl-then-bash installer step names no risk and its only integrity check is `wc -l 1049` | Advisory | pr-check-5 | security-engineer | platform-engineer | devops ✓, platform ✓, integration ✓ | State the risk in one sentence; pin a sha256 if the owner can supply one |
| A7 | check-config `lookup()` returns ABSENT when a parent is a non-mapping, so `unset-or-eq` passes for `curator: true` and the `hooks_auto_accept` parent-scalar case; same-indent block lists give UNPARSEABLE exit 2 (fail-closed, false alarm only). The curator case is covered by M1 | Advisory | pr-check-7 | fullstack-engineer | integration-architect | writer ✓, integration ✓, platform ✓, security ✓ (asked Medium) | FAIL when a parent key exists but is not a mapping |
| A8 | config.active.yaml ships a literal `__HOME__` in the hook command, so the raw fixture FAILs the hook row; INSTALL.md:267-268 quotes `PASS n=23` which holds only with the step-4 hook installed and `--home` given (else n=21 with SKIP) | Advisory | pr-check-4, pr-check-8 | devops-engineer, technical-writer | platform-engineer | fullstack ✓, platform ✓, integration ✓, strategic ✓ | One INSTALL step 5 note; merge into the M2 edit |
| A9 | INSTALL.md step 2 runs `hermes config set updates.check false` before the UNVERIFIED caveat that appears only in step 3 | Advisory | pr-check-8 | technical-writer | fullstack-engineer | fullstack ✓, integration ✓, strategic ✓ | Move or reference the caveat in step 2 |
| A10 | INSTALL.md step 3 states that config set values are type-checked, and lists the config CLI verbs, as fact with no UNVERIFIED marker | Advisory | pr-check-8 | technical-writer | fullstack-engineer | fullstack ✓, integration ✓, strategic ✓ | Attribute to the docs digest or mark UNVERIFIED |

No-issue rows: pr-check-6 PASS (layer ownership verified, 0 findings). pr-check-9 PASS (8 files map to 3 commits, no scope creep). pr-check-3 also carried an Advisory contract-verification line (all contract values identical across tsv, config-edits.md, config.active.yaml, hermes-up and INSTALL.md; token rule holds), with no action and not counted. The malformed PASS-WITH-FINDINGS placeholder on pr-check-3 was ignored.

## 3. Deliberation trails (Blocking only)
None; there are no Blocking findings.

## 4. Timed-out threads
None. timed_out_checks: gate1 [], gate2 [] (all 7 seats signalled both phases).

## 5. Overall verdict
READY WITH CONDITIONS: fix M1, M2 and M3 before merge; the Advisories may be folded into the same edit or deferred.

## 6. Confidence notes
- Validated by 3 or more C members: M1 (3), A2 (3), A3 (4), A5 (4 after downgrade), A6 (3), A7 (4).
- Contested: M2 (2 validates, 2 challenges to Advisory; Medium retained on the CLOSED line). A4 and A5 were downgraded from Medium by two challenges each.
- Fewer than 3 C members: M3 (3 validates, so well supported), A1, A8, A9, A10 (documentation-only, all validated and unchallenged).
- Solo finding: A1 was first raised by one seat and validated by one other.
- No bus read returned 200 messages, so nothing was truncated. Fresh-extract test run by several seats: 62 passed, 0 failed; a toolset-drop mutation FAILs as expected.

## Orchestrator note (round 1 close-out)

Fixes (Opus fixer, non-author; fix-verifier Sonnet) address M1 (curator.enabled eq false), M2 (hook checks run with HERMES_HOME alone), M3 (install -m 555; re-run seed-hook-allowlist after a hook change) and the advisories that a one-line change closes: value echo on FAIL replaced by shapes (A5), non-mapping parent fails (A3), README Files rows, UNVERIFIED placement, curl|bash risk sentence, base_url wording, fixture __HOME__ note. check-config tests 62 -> 84. Round 2 reviews 8e417cf...<head> next.
