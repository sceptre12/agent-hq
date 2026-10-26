CODE-GATE-REVIEW: FAIL head=941ac563290e0333495a5f527c82d999dd804785 blocking=0 medium=2
Reviewed-By: xProfWorker1 pr13-code-gate-r1

# PR #13 Phase B report (agent-hq, local-diff 1bd844e...941ac56)

session_id: swarm-pr-review-20261026-b4a16df5 | head_sha: 941ac563290e0333495a5f527c82d999dd804785 | 7 seats, both gates signalled (timed_out_checks: gate1 [], gate2 [])

## 1. Severity summary

0 Blocking, 2 Medium, 12 Advisory.

## 2. Findings table

C markers: ✓ VALIDATE, ⬆ ESCALATE, ↩ CHALLENGE, + ADD. Severity is the RESOLVED value from the Accountable CLOSED message.

| # | Issue | Severity | Check | R | A | C Responses | Recommended Fix |
|---|-------|----------|-------|---|---|-------------|-----------------|
| M1 | READY-TO-MOVE.md is stale against the diff and would mislead the merge decision: sections 1 and 11 (lines 5 and 137) pin INTERFACES 1.7.0 while INTERFACES.md in this PR is 1.9.0 (the packet itself says 1.9.0 in section 5); header says item 33 edits are uncommitted and nothing pushed; section 1 lists EXTENDs wave-execution, pr-review, fix-verifier, doc-reviewer as shipped but none is in this PR (only feature-change; the rest sit on ext/delivery-extends); section 12 step 1 says test-map keeps the main seven rows and code-gate scope is release-track scripts only, but the PR adds 4 test-map rows incl. 2 for the vendored security-audit validators. Integration-architect's sampling also found the same version drift in skills/delivery-run/SKILL.md (line 15 says INTERFACES 1.7.0, line 327 says 1.5.0 while the skill cites AM-8/AM-9 content; content is current). | Medium | pr-check-cold-read | strategic-reviewer, integration-architect | integration-architect | platform ✓, integration ✓ | Add a short 'state at PR #13 head 941ac56' preamble (contents of this PR vs ext/delivery-extends, INTERFACES 1.9.0, code-gate scope incl. security-audit) or correct sections 1, 11, 12; refresh the delivery-run version stamps. |
| M2 | Producer/consumer mismatch on the zephyr profile format: skills/delivery-intake/references/templates/repo-profile.md:68 emits the profile as a one-line flow map (zephyr: {read_ops: [..], execute_tool: ..}) but skills/release-track/scripts/zephyr-guard.sh (read_ops_list awk, line 88) only recognises a bare zephyr: line with indented children. Reproduced from a git archive of head: template form gives rc 2 'zephyr.read_ops missing or empty' for a valid GET getRun call; block form gives rc 0. Fails closed (safe), but the first real profile would block every Zephyr read; test_zephyr-guard.sh has no flow-form case. | Medium | pr-check-3 | integration-architect | platform-engineer | platform ✓ (reproduced), security ✓, strategic ✓ | Make read_ops_list accept the one-line flow-map form, or change the template and profile-keys.md to the block form (and say so in hook-wiring.md); add a test case. |
| A1 | Assumption-until-P0 for Zephyr is well flagged in zephyr-guard.sh header, but READY-TO-MOVE (section 8 or 1) never says the guard is not wired/usable until P0 measures the real input shape, so a cold reader may read the hook as production-ready. | Advisory | pr-check-cold-read | strategic-reviewer | integration-architect | platform ✓, integration ✓ | One sentence in the packet: zephyr-guard ships as a fail-closed scaffold, input key set replaced at P0. |
| A2 | Changing vendored skills/security-audit/*.test.cjs selects no test (PASS n_run=0, excluded in scope.conf by design); report-schema.json (consumed by validate-findings.cjs) is out of scope, so schema drift is also ungated. | Advisory | pr-check-4 | devops-engineer | platform-engineer | platform ✓, fullstack ✓, integration ✓, security ✓ | Optional: add report-schema.json as an extra map row to both wrappers, or accept as documented. |
| A3 | test_zephyr-guard.sh has no case for python3 missing from PATH although the guard needs it for all JSON parsing; fail-closed (exit 2) verified manually, path untested. | Advisory | pr-check-4 | devops-engineer | platform-engineer | platform ✓, fullstack ✓, integration ✓, security ✓ | Optional: add a test running the guard with PATH lacking python3, expecting exit 2. |
| A4 | skills/security-audit/PROVENANCE.md:7 says Modifications none / this note is the only added file, but the PR also adds tests/test_validate-findings.sh and tests/test_validate-coverage-ledger.sh. 21 upstream files verified byte-identical (sha256) to the desk install (581355f); upstream c1c8a8c itself not comparable (no network). | Advisory | pr-check-5 | security-engineer | platform-engineer | platform ✓, devops ✓, integration ✓ | Reword: the only added files are PROVENANCE.md and the two gate wrappers under tests/. |
| A5 | 3 real absolute home scratch paths remain in review records under architecture/delivery-workflow/reviews (fix-delivery-architecture-r1b, r2, 27b-persona-briefs-rung1), plus xProfWorker1 profile name in Reviewed-By lines. No leak in skills or scripts; 20 new SKILL.md frontmatter, doc-length and file-length checks clean. | Advisory | pr-check-6 | platform-engineer | devops-engineer | devops ✓, integration ✓, security ✓ | Optional: replace the 3 paths with $HOME. |
| A6 | skills/release-track/scripts/zephyr-guard.sh keyword scan is literal on tool_input; path and params are free text, so operation=get_versions method=GET path=/api/dep%6Coy/prod exits 0 (as does params a='roll back'). Original severity Medium. | Advisory (was Medium) | pr-check-7 f1 | fullstack-engineer | integration-architect | platform ↩, integration ↩, security ↩, technical-writer ↩ | At P0 pin path to an allowlist or drop path/params from the accepted key set; at minimum percent-decode and strip separators before the keyword scan. |
| A7 | read_ops_list splits inline lists on every comma including inside quotes: read_ops: ["a,b", c] allows operation a, rc 0 (fail-open direction, needs a hand-written odd profile). | Advisory | pr-check-7 f2 | fullstack-engineer | integration-architect | platform ✓, integration ✓, security ✓, technical-writer ✓ | Refuse inline entries containing a quote char, or document that entries may not contain commas. |
| A8 | check-zephyr-disallowed.sh: a frontmatter with the disallowedTools key twice (first lists the tool, second does not) falsely passes (hit latches on first key; YAML last-wins would drop it). CRLF frontmatter fails closed (false MISSING). | Advisory | pr-check-7 f3 | fullstack-engineer | integration-architect | platform ✓, integration ✓, security ✓, technical-writer ✓ | Exit 1 on a second disallowedTools key; strip CR. |
| A9 | Untested fail-closed paths in test_zephyr-guard.sh (63/63 pass): python3 missing, set -u/EXIT-trap abort, CR/LF inside operation/method, CRLF profile, quoted-comma inline entry, percent-encoded path. | Advisory | pr-check-7 f4 | fullstack-engineer | integration-architect | platform ✓, integration ✓, security ✓, technical-writer ✓ | Add 3-4 cases; no behaviour change; optionally note them in the test header. |
| A10 | skills/security-audit/tests/test_validate-coverage-ledger.sh and test_validate-findings.sh line 3 say 'Runs it with node from the repo root' but the wrapper never cd's (cwd-independent via __dirname; verified from /). | Advisory | pr-check-8 | technical-writer | fullstack-engineer | fullstack ✓, integration ✓, strategic ✓ | Reword to 'Runs it with node (cwd-independent, the test locates its validator via __dirname)'. |
| A11 | Out-of-stated-scope files: decisions/0054 and 0055 ADRs (prose) are in the packet but not in the PR scope line. Counts otherwise verified (474 files, +28553, 0 deletions, 68 commits; only pre-existing file touched is tools/code-gate/test-map.tsv +4 rows; config untouched). | Advisory | pr-check-9 | strategic-reviewer | integration-architect | integration ✓, security ✓, technical-writer ✓ | Add the two ADRs to the PR description scope line. |
| A12 | Verbatim ports review-7-panel, port-claim, sim-lease have no per-skill review record by name (only pr9-port-guard records for the guard script); every other new delivery skill has a Rung 1 or 2b record. | Advisory | pr-check-9 | strategic-reviewer | integration-architect | integration ✓, security ✓, technical-writer ✓ | Confirm the item 8 ports were reviewed elsewhere or note in the PR body that they are unreviewed verbatim ports. |

## 3. Deliberation trails

No Blocking findings. Trails for severity-changed and challenged findings, plus Medium findings.

> **pr-check-7 f1 deliberation (A6, Medium -> Advisory):**
> fullstack-engineer (R): FINDING Medium. Percent-encoded path (/api/dep%6Coy/prod) and params 'roll back' pass the literal keyword scan, rc 0 under /bin/bash 3.2.
> platform-engineer (C): CHALLENGE. Reproduced rc 0, but zephyr-guard.sh header lines 11-14 scope the input shape and key set as ASSUMPTION UNTIL P0; the real control is the operation allowlist; hook is unwired scaffold. Medium -> Advisory, P0 follow-up.
> integration-architect (C): CHALLENGE. Agrees; guard fails closed on unknown keys; Medium -> Advisory.
> security-engineer (C): CHALLENGE. Primary control is the exact-match read_ops allowlist plus GET-only (line 129); the scan at line 130 is secondary. Bypass needs an allowlisted op, GET, and an MCP that decodes path into a mutating target; none measured (lines 11, 41-48). Medium -> Advisory.
> technical-writer (C): CHALLENGE. The gap is disclosed in the header, so documentation does not mislead the merge decision. Medium -> Advisory.
> integration-architect (A): CLOSED, f1 Medium->Advisory per 4 challenges.

> **pr-check-3 f1 deliberation (M2, Medium kept):**
> integration-architect (R): FINDING Medium, repo-profile.md:68 flow map vs guard block-map parser, rc 2 vs rc 0 reproduced.
> platform-engineer (C): VALIDATE, independently reproduced with stdin tool_name mcp__z__x, operation getRun, method GET.
> security-engineer (C): VALIDATE, Medium on defect grounds only (fail-closed, no exposure).
> strategic-reviewer (C): VALIDATE, source read: guard line 88 sets inz only for a bare zephyr: key.
> platform-engineer (A): CLOSED, stays Medium.

> **pr-check-cold-read f1 deliberation (M1, Medium kept):**
> strategic-reviewer (R): FINDING Medium, stale READY-TO-MOVE.md.
> platform-engineer (C): VALIDATE, lines 5 and 137 pin 1.7.0, mechanical fix.
> integration-architect (C, also A): VALIDATE, consistent with own sampling of 1.7.0 vs 1.9.0 drift.
> integration-architect (A): CLOSED, Medium kept; f2 Advisory.

## 4. Timed-out threads

None. timed_out_checks gate1 [] and gate2 [] (all 7 seats posted PHASE1_DONE and PHASE2_DONE).

## 5. Overall verdict

READY WITH CONDITIONS. No Blocking findings. Conditions before merge: fix M1 (correct or preamble the stale READY-TO-MOVE.md and delivery-run version stamps) and M2 (zephyr profile template/guard format mismatch plus a test). All 12 Advisories are non-blocking. Both Mediums fail safe (stale doc; fail-closed guard), so the owner may instead accept them with a follow-up.

## 6. Confidence notes

- High confidence (3+ C members): A2, A3 (4 each), A6 (4 challenges), A7, A8, A9 (4 each), A4, A5, A10, A11, A12 (3 each), and M2 (3 C, independently reproduced by platform-engineer).
- 2 C members: M1, A1.
- Solo / thinly corroborated: none beyond 2; the version-stamp drift in delivery-run SKILL came only from integration-architect's PASS text and is folded into M1 rather than counted separately.
- Quorum reached on every topic; M1's Accountable is also a Responsible seat and a validator on the same thread.
- Scope caveats: seats were told not to re-review prose that passed Rung 1; upstream vendored c1c8a8c could not be compared (no network); Zephyr input shape is ASSUMPTION UNTIL P0.
- A stray 'x' post and its NOTE on pr-check-8 were ignored as instructed.

## Checks with PASS

- pr-check-1 (layer/config ownership, symlinks, home writes): PASS only, validated by security-engineer.
- pr-check-2 (test-map rows, wrappers): PASS only, validated by platform, fullstack, security.

## Run notes (orchestrator)

- Skill: `pr-review` (~/projects/agent-hq/skills/pr-review/SKILL.md), local-diff mode, round 1, 2026-10-26. repo_dir `~/projects/agent-hq-worktrees/delivery-w0` (read-only; seats read via `git show 941ac56:<path>` and ran tests in their own `git archive` exports under TMPDIR), base `1bd844e`, head `941ac56`.
- Bus: own pm2 app from `~/projects/swarm-communication-layer`, DATA_DIR under /tmp, port 7877 (free-checked, no retry needed), loopback bind and /health identity verified; `session_id` on every call, `peek:true` one topic per read, `from_agent` on broadcasts. Cleanup: `end_session`, `pm2 delete`, DATA_DIR removed.
- Seats: 7 Sonnet seats x 2 phases + 1 Sonnet synthesizer. Gate 1 and Gate 2: 7/7 each, no timeouts. Mechanical steps (bus start, diff, gates, cleanup) ran in the orchestrator thread instead of Haiku dispatches.
- Inputs fed: `git diff --stat 1bd844e...941ac56`, changed-file tree, the full code-gate-scope diff (zephyr scripts, security-audit wrappers, test-map rows, port-claim, sim-lease) and the vendored-file diff, plus the whole-PR diff for grep.
- Seat focus: (1) code review of the code-gate scope (fullstack, devops); (2) vendored security-audit identity + reachability (security); (3) repo-level safety (platform, security); (4) sampled INTERFACES 1.9.0 consistency vs sim-lease, delivery-run, ticket-clerk (integration); scope/cold read (strategic); comments vs code (technical-writer).
- Measured by seats: `test_zephyr-guard.sh` 63/63 under /bin/bash 3.2; security-audit wrappers 31/31 and 34/34; `test_run-mapped-tests.sh` 142/142; check-doc-length 0 blocking, check-file-length 0 over limit; no symlinks, config untouched, 0 deletions; 21 vendored files sha256-identical to the desk install (delivery-extends 581355f); no secrets in added lines; no `disable-model-invocation` in any frontmatter.
- Orchestrator spot-check of both Mediums at head: `skills/delivery-intake/references/templates/repo-profile.md:68` is the one-line flow map; `architecture/delivery-workflow/READY-TO-MOVE.md:5` and `:137` pin INTERFACES 1.7.0, `:6` says item 33 edits are uncommitted.
- Record location: written inside the reviewed worktree by the caller's instruction (the skill's default is outside REPO_DIR); this file is not part of head 941ac56.

CODE-GATE-REVIEW: FAIL head=941ac563290e0333495a5f527c82d999dd804785 blocking=0 medium=2
