CODE-GATE-REVIEW: PASS head=50aa05c1a18390aceabe0bee9b44f67abaa04e0f blocking=0 medium=0
Reviewed-By: xProfWorker1 PR12-gate-scope-r1

# PR #12 Phase B report (session swarm-pr-review-20261026-ddccc76c)

Local-diff: `~/projects/agent-hq-worktrees/gate-scope-vendored`, 4ee64a0..50aa05c. Change: `tools/code-gate/scope.conf` +4 lines (3-line comment + `exclude skills/security-audit/*.test.cjs`).

## 1. Severity summary (final, per Accountable CLOSED lines)
**0 Blocking, 0 Medium, 9 Advisory.** Four findings were raised as Medium and downgraded to Advisory after 3 challenges each (pr-check-3, -5, -6, -9).

## 2. Findings table
Markers: ✓ VALIDATE, ⬆ ESCALATE, ↩ CHALLENGE, + ADD. A = the seat that posted CLOSED.

| # | Issue | Orig | Final | Check | R | A | C responses | Recommended fix |
|---|-------|------|-------|-------|---|---|-------------|-----------------|
| A1 | Glob `skills/security-audit/*.test.cjs` is broader than the two vendored files: `*` crosses `/` (case match, lib.sh), so any future/nested `.test.cjs` there is invisible. Layer (scope.conf) is right. | Advisory | Advisory | pr-check-1 | platform-engineer | devops-engineer | devops ✓, integration ✓, security ✓ | List the two exact paths, or state in the comment that new `*.test.cjs` are intentionally invisible |
| A2 | The exclude is the only thing keeping the wrappers meaningful; nothing enforces "vendored unmodified" for the tests. Suggested test-map rows would be dead: run-mapped-tests.sh:113 filters via cg_scoped before cg_tests_for | Advisory | Advisory | pr-check-2 | integration-architect | platform-engineer | platform ✓, devops ✓, fullstack ✓, security ✓ | Do not add test-map rows on the excluded sources (ineffective); rely on PROVENANCE, or narrow the exclude |
| A3 | Flow trace: one cg_scoped path, uniform effect. Excluded files get no review requirement, no direct/mapped test run, and a test-only push gives PASS n_run=0. test_scope.sh has no row for the new exclude. | Medium | Advisory | pr-check-3 | integration-architect | platform-engineer | platform ↩, security ↩, strategic ↩ | Optional: test_scope.sh rows (tests out, validators in); optionally narrow glob to the two exact paths |
| A4 | Wrappers need `node` on the gate's PATH; absent node fails closed ("FAIL: node not found on PATH"), blocking rather than skipping | Advisory | Advisory | pr-check-4 | devops-engineer | platform-engineer | platform ✓, fullstack ✓, integration ✓, security ✓ | None required; optionally note the node prerequisite in PROVENANCE or gate docs |
| A5 | Unreviewed edit to an excluded `.test.cjs` can weaken tests that guard the validators (gate-executed code, slightly broader than the swarm-bus precedent). Needs push-to-main privilege already held. | Medium | Advisory | pr-check-5 | security-engineer | platform-engineer | platform ↩, devops ↩, integration ↩ | Optional: narrow glob to exact paths; sha256 pinning judged out of scope |
| A6 | Ordering: scope is read from BASE (cg_scope_from), so the exclusion applies only after PR #12 is on main. If delivery-w0 (258f8e3) is gated first, the `.test.cjs` files hit TEST-NOT-RUNNABLE (loud block). | Medium | Advisory | pr-check-6 | platform-engineer | devops-engineer | devops ↩, integration ↩, security ↩ | Merge PR #12 first, then rebase/merge main into wt/delivery-w0; record the order in the PR description |
| A7 | Glob semantics: matches exactly the two vendored files today; also any future `.test.cjs` at any depth under `skills/security-audit/`; not `security-auditor/`, `.bak`, or `x.test.cjs.sh`. | Advisory | Advisory | pr-check-7 | fullstack-engineer | integration-architect | platform ✓, integration ✓, security ✓, technical-writer ✓ | Optional: exact filenames instead of the wildcard |
| A8 | Comment says "same mechanism as the swarm-bus exclusion", but the swarm-bus rationale is a stable vendored tree dropped wholesale, while this drops only tests and keeps validators in scope | Advisory | Advisory | pr-check-8 | technical-writer | fullstack-engineer | fullstack ✓, integration ✓, strategic ✓ | Reword: "same vendored-code rationale as the swarm-bus exclusion above, but narrower: tests only" |
| A9 | Exclude is the narrowest config-layer change, but test_scope.sh (lines 46-52) has no row for it or for a validator staying in scope, and hq-code-gate.md Scope bullet (25-27) omits it | Medium | Advisory | pr-check-9 | strategic-reviewer | integration-architect | integration ↩, security ↩, technical-writer ↩ | Add test_scope.sh rows (test out, validator in, 100755 variant); add the exclusion to the Scope bullet |
| - | pr-check-cold-read: No issues (integration-architect PASS, strategic-reviewer PASS) | - | - | pr-check-cold-read | integration-architect | integration-architect | - | - |

## 3. Deliberation trails
No Blocking findings. Trails for the four severity changes:

> **pr-check-3 deliberation:** integration-architect (R): Medium. The effect is uniform across run-mapped-tests, check-review, gate-invariants. The gate goes silent on edits to the two tests, with no test_scope regression row. platform-engineer (C): CHALLENGE, invisibility is the deliberate purpose (they previously blocked as TEST-NOT-RUNNABLE), scope.conf and tools/code-gate/* stay in scope, and weakening a test needs push rights already held. security-engineer (C): CHALLENGE, Advisory, blast radius is two 644 files. strategic-reviewer (C): CHALLENGE, Advisory, and the missing row is real but optional. platform-engineer (A) CLOSED: downgraded to Advisory.

> **pr-check-5 deliberation:** security-engineer (R): Medium, an unreviewed edit could weaken the validator tests, and the files are gate-executed by node. platform-engineer (C): CHALLENGE, privilege needed equals push-to-main, the precedent has the same shape, and sha256 pinning is beyond this PR. devops-engineer (C): CHALLENGE, no new privilege or secret exposure. integration-architect (C): CHALLENGE, Advisory. platform-engineer (A) CLOSED: Advisory.

> **pr-check-6 deliberation:** platform-engineer (R): Medium, scope is read from base, so delivery-w0 gated before PR #12 merges gets TEST-NOT-RUNNABLE. devops-engineer, integration-architect, security-engineer (C): CHALLENGE, a loud block rather than a silent bypass, an integrator ordering note and not a diff defect. devops-engineer (A) CLOSED: Advisory, merge PR #12 first.

> **pr-check-9 deliberation:** strategic-reviewer (R): Medium, missing test_scope.sh rows and a docs omission. integration-architect, security-engineer, technical-writer (C): CHALLENGE, test/doc completeness with no exploitable effect, the narrowest-change conclusion holds. integration-architect (A) CLOSED: Advisory.

## 4. Timed-out threads
None (`gate1: []`, `gate2: []`).

## 5. Overall verdict
**READY WITH CONDITIONS.** No Blocking or Medium findings. The single condition is ordering: merge PR #12 before gating or pushing wt/delivery-w0, and record that in the PR description (A6). Everything else is optional: narrow the glob to the two exact paths (A1, A3, A5, A7), add test_scope.sh rows and the doc bullet (A3, A9), and reword the comment (A8).

## 6. Confidence notes
- Validated by 3+ C members: A1 (3), A2 (4), A4 (4), A7 (4), A8 (3). Severity downgrades A3, A5, A6, A9 were each backed by 3 independent challenges and no dissent.
- Solo-originated but verified by challengers: the exact-path narrowing (raised by several seats) and the dead-test-map-row caveat (A2; confirmed by 3 seats at run-mapped-tests.sh:113).
- Wrapper execution was confirmed by two seats (devops, fullstack) in a fresh extract of 258f8e3 (34/34 and 31/31).

## Answers to the review questions
**(a) Narrowest correct change?** Layer is right: scope.conf is the single owner of gate visibility and the swarm-bus exclusion is the precedent. A runner change would touch gate code for a one-off, and chmod+shebang would modify vendored upstream (pr-check-1, -9). The glob is not the narrowest form: two exact-path excludes are strictly narrower and cheap (pr-check-1, -3, -5, -7). That is optional (Advisory).

**(b) Glob match set.** Today: exactly `validate-findings.test.cjs` and `validate-coverage-ledger.test.cjs` at 258f8e3. Later: any `.test.cjs` at any depth under `skills/security-audit/` (e.g. `tests/x.test.cjs`, `sub/x.test.cjs`), because `case` `*` crosses `/`. It does not match `security-auditor/`, `.bak`, or `x.test.cjs.sh` (pr-check-7, verified with a case loop).

**(c) Do the wrappers execute the upstream tests?** Yes. Both wrappers are 100755 with a bash shebang and `exec node` on their `validate-*.test.cjs` from the repo root. In a fresh extract, test_validate-findings.sh passed 34/34 and test_validate-coverage-ledger.sh passed 31/31 (rc=0). They fail closed without node on PATH, and run in under 1s against the 120s timeout in the gate's temp worktree (pr-check-4, -7).

**(d) What becomes invisible to the gate.** For paths matching the glob, the same cg_scoped path feeds every consumer (pr-check-3). (1) No reviewed-PR-merge requirement (check-review, gate-invariants audit). (2) No direct or mapped test run: before, cg_is_test would run them directly and block as TEST-NOT-RUNNABLE. (3) A push changing only those files gets PASS n_run=0, and the wrappers run only when a validator changes. (4) `--inventory` is unchanged because cg_is_test already skipped them. Test-map rows sourced from the excluded files would never fire (pr-check-2). Validators, wrappers, scope.conf and tools/code-gate/* stay in scope, so the exclusion itself required a reviewed merge. Residual risk is an unreviewed edit to the vendored tests, which needs push-to-main privilege already held.

CODE-GATE-REVIEW: PASS head=50aa05c1a18390aceabe0bee9b44f67abaa04e0f blocking=0 medium=0
