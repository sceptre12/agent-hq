CODE-GATE-REVIEW: PASS head=ac9df4c140be212bbac3bacb2c12e164eca2fbac blocking=0 medium=0
Reviewed-By: xProfWorker1 PR10-delivery-scripts-r2

# PR #10 delivery scripts — code-gate review round 2

- Date: 2026-10-26
- Head: ac9df4c (ac9df4c140be212bbac3bacb2c12e164eca2fbac)   Base: 42a5198
- Round-2 fix commits: 81f963a (M1-M4 plus desk-panel sender findings), 86cb14f (audit exit 4), ac9df4c (audit exit 5, supersedes 86cb14f)
- Mode: local-diff (repo_dir `~/projects/agent-hq-worktrees/delivery-scripts`, read-only)
- Bus session: swarm-pr-review-20261026-12c3aff9 (`pr-check-cold-read`, `pr-check-1`..`9`, all `-closed` topics, `rendezvous`, `phase2-rendezvous` read with peek)
- Gates: gate1 7/7, gate2 7/7; timed_out_checks = { gate1: [], gate2: [] }
- Panel: strategic-reviewer, integration-architect, platform-engineer, devops-engineer, security-engineer, fullstack-engineer, technical-writer, plus independent synthesizer

## 1. Severity summary

Blocking: 0, Medium: 0, Advisory: 5

6 raw FINDING messages on the bus merged into 5 rows (the stale `list --live` text was raised twice, in the cold read and in pr-check-3). Severity is the bus consensus from the CLOSED messages: no seat posted a CHALLENGE or ESCALATE, and no severity moved. Every finding is Advisory: four are outside the diff (W0 skill docs or INTERFACES amendments) or hardening with no argv sink, and the desk re-validates every request. All four round-1 Mediums (M1-M4) are verified fixed (section "M1-M4 round-1 closure").

The synthesizer did not re-run tests or repros; everything below is read from the bus.

## 2. Findings table

R = Responsible (raiser), A = Accountable (closer). C markers: ✓ VALIDATE, ⬆ ESCALATE, ↩ CHALLENGE, + ADD. No ↩ or ⬆ was posted. PASS-only topics: pr-check-1, 2, 4, 6, 8, 9. Advisory ids are prefixed R2- so they do not collide with the round-1 A1-A11 (still deferred, not re-raised).

| # | Issue | Severity | Check | R | A | C Responses | Recommended Fix |
|---|-------|----------|-------|---|---|-------------|-----------------|
| R2-A1 | Stale cross-file text after the fixes, all outside the diff: `skills/resource-catalog/SKILL.md:26` and step 7 and `skills/pre-pr-gate/references/steps-detail.md:53,66` (open point 8) still treat `list --live` as live-only or unknown, while INTERFACES 1.4.0 says planned or live; `skills/delivery-desk/references/schemas.json` package `$comment` says `desk-req-schema.sh` has no leading-dash guard (now false). | Advisory | pr-check-cold-read, 3 | strategic (cold-read), integration (3) | integration (cold-read), platform (3) | cold-read: platform ✓, integration +. pr-check-3: platform ✓, security ✓, strategic ✓ | W0 skills pass: align the three lines with INTERFACES 1.4.0 |
| R2-A2 | Consumers of `catalog.sh audit` do not name exit 5: `resource-catalog/SKILL.md` step 8 lists 0/2/3/4 only; `delivery-run` `references/resume.md` step 1 and `delivery-cleanup` `SKILL.md` Step 1 / `dry-run-table.md` ignore the rc, so a port row with no verdict silently drops out of the dry run. Benign today (resume step 2 re-verifies by lsof; cleanup acts only on catalog rows). Not a finding on exit 5 itself (AM-5). | Advisory | pr-check-3 | integration | platform | platform ✓, security ✓, strategic ✓ | After AM-5 lands: add exit 5 to resource-catalog step 8, treat it as report-to-lead in resume step 1 and cleanup Step 1 |
| R2-A3 | Code is stricter than the INTERFACES text it cites: A.5 handle grammar (`pm2-app\|container\|image\|workspace\|db`) and B4 `package` allow a leading `-`; `catalog.sh` and `desk-req-schema.sh` now refuse it. Stricter is the safe direction (no raw flag at pm2/docker argv), but INTERFACES 1.4.0 is not amended. | Advisory | pr-check-3 | integration | platform | platform ✓, security ✓, strategic ✓ | Queue an INTERFACES amendment row (with AM-5) stating the no-leading-dash rule; scripts need no change |
| R2-A4 | `desk-req-schema.sh:33` type `int` is not rx-routed (`type==number and .==floor and .>=0`): `pr` / `ci_run_id` accept `-0` and `1e400` (tojson prints `-0` and `1E+400`; jq 1.6 and 1.7 render differently). Spec B4 types them as plain int; no argv sink in this PR; desk re-validates. Security also noted `job` accepts a leading dash, matching the spec regex. | Advisory | pr-check-5 | security | platform | platform ✓, devops ✓, integration ✓ | Optional hardening: rx on tojson `^(0\|[1-9][0-9]*)$`, or require `. == floor` and tojson without `e` or `-` |
| R2-A5 | `desk-req-schema.sh` semver (line ~39): major/minor/patch forbid leading zeros but the prerelease id class `[0-9A-Za-z-]+` admits numeric ids with a leading zero; `publish` version `1.0.0-01` returns rc 0 (SemVer 2.0 item 9 forbids it). Sender-side only, desk re-validates; no injection impact (charset unchanged, no leading dash, no control chars). | Advisory | pr-check-7 | fullstack | integration | platform ✓, integration ✓, security ✓, technical-writer ✓ | Use `(0\|[1-9][0-9]*\|[0-9]*[A-Za-z-][0-9A-Za-z-]*)` per prerelease id; add a `1.0.0-01` reject test |

PASS-only topics (no findings): pr-check-1 (platform PASS, devops ✓), pr-check-2 (integration PASS), pr-check-4 (devops PASS), pr-check-6 (platform PASS, devops ✓), pr-check-8 (technical-writer PASS), pr-check-9 (strategic PASS). Two PASS messages carry round-2 verification evidence: pr-check-7 (fullstack) and pr-check-cold-read (integration).

## M1-M4 round-1 closure

Fix commits: 81f963a carries M1-M4 (its message lists list --live planned, control-char rejection, jira-create parent/summary/issuetype, audit fail-closed without lsof). 86cb14f and ac9df4c only rework the M4 exit code (4, then 5). Verification evidence is the seats' own bus messages; the synthesizer re-ran nothing.

| id | Round-1 issue | Fix commit | Verified by | Status |
|----|---------------|------------|-------------|--------|
| M1 | `catalog.sh list --live` omitted planned rows (INTERFACES 1.4.0 says planned or live) | 81f963a | strategic (cold-read: planned or live ok, repro re-run); integration (pr-check-2: matches script table and AM-4 row 20); technical-writer (pr-check-8: header matches code line 225) | CLOSED. Residue is stale doc text outside the diff (R2-A1) |
| M2 | `rx()` accepted one trailing LF in every regex-typed field | 81f963a | fullstack (pr-check-7: LF, CR, TAB, DEL, NUL rejected in repo/ref/branch/sha/tag/step/key/parent/job); security (pr-check-5: CR, NUL, DEL, U+0085, TAB, trailing LF rejected in every rx field); strategic (cold-read: 187 positive controls rc 0, so reject tests fail for the right reason); integration (pr-check-2) | CLOSED. Note: `job` accepts U+2028 by design (free text); multi-line description/summary stay allowed (`isstr`, not rx) |
| M3 | `jira-create` allowed `fields.parent`, required neither `fields.summary` nor `fields.issuetype` | 81f963a | fullstack (pr-check-7: all repros rejected with the field name; valid Epic and non-Epic cases rc 0; `jira-update` stays partial); strategic (cold-read: Epic-no-parent, Task+parent, update partial behave); integration (pr-check-2: matches B4 and `schemas.json`) | CLOSED |
| M4 | `catalog-audit.sh` read any lsof failure as "not listening" (false GHOST) | 81f963a, then 86cb14f (exit 4), ac9df4c (exit 5) | platform (pr-check-1: fail-closed rc 5, `exit $?` plumbing, tests reproduced); devops (pr-check-1, 4: `audit_port` mirrors `port-check-lib` `lsof_run`, missing or odd rc gives 5, rc 1 with empty output is not listening); security (pr-check-5: no lsof gives 5, other rows still audited); integration (pr-check-2: repro via fake-lsof tests); technical-writer (pr-check-8: exit table 0/2/3/4/5 consistent; exit 4 is lock timeout only) | CLOSED. Exit 5 value is the lead decision queued as AM-5 (PR10-M4), not a finding |

Tests reported by seats at ac9df4c under `/bin/bash` 3.2 in a fresh archive: `test_catalog.sh` 157, `test_desk-req.sh` 558, `test_scope-check.sh` 23, all pass (platform, devops, fullstack, strategic, integration).

## 3. Deliberation trails

No Blocking findings, and no CHALLENGE or ESCALATE was posted anywhere. Nothing to trail. Severity moves: none. Closer confirmations of the final severity: pr-check-cold-read-closed (integration: "Advisory, 0 Medium, 0 Blocking"), pr-check-3-closed (platform: 3 findings, all Advisory), pr-check-5-closed (platform: Advisory), pr-check-7-closed (integration: Advisory, 0 Medium, 0 Blocking). pr-check-1, 2, 4, 6, 8, 9 closed with no findings.

## 4. What was verified clean

- Round-1 fixes M1-M4 hold, including every control character class and the `jira-create` / `jira-update` split (see closure table).
- Semver accepts `0.0.1`, `10.20.30`, `1.0.0-rc.1+sha-5`, `-alpha-1`, `-0`, `-x.7.z.92`, `+001`; rejects `01.0.0`, `1.0`, `1.0.0-`, `-rc..1`. Packages `foo`, `@scope/foo`, `_foo`, `foo.bar` pass; `-foo` and `@a/-b` are rejected (fullstack).
- Audit exit-code plumbing: here-string loop (no subshell), `cmd_audit` propagates `exit $?`, other rows still audited after a rc 5 row (platform, devops, security).
- Handle and field guards (leading dash, semver, control-char rx) are bash 3.2 and BSD safe; no env or connection regression (platform, devops).
- Header comments in `catalog.sh`, `catalog-audit.sh`, `desk-req-schema.sh` match behaviour; `test-map.tsv` rows 32-36 still map the scripts to their tests; no new files (technical-writer, integration).
- Scope (pr-check-9): PASS, no findings (strategic, closed by integration).
- Commit 86cb14f's message says exit 4; superseded by ac9df4c (history only, technical-writer).

## 5. Timed-out threads

None. gate1 and gate2 are empty. All 10 Accountable closing topics carry a CLOSED: `pr-check-cold-read-closed` (integration), `pr-check-1-closed` (devops), `pr-check-2-closed`, `3`, `4`, `5` (platform), `pr-check-6-closed` (devops), `pr-check-7-closed` (integration), `pr-check-8-closed` (fullstack), `pr-check-9-closed` (integration). `rendezvous` and `phase2-rendezvous` each hold 7 of 7 signals.

## 6. Overall verdict

READY. Blocking: 0, Medium: 0, Advisory: 5. All four round-1 Mediums are CLOSED with multi-seat evidence, tests are green at ac9df4c (157/558/23), and the five Advisories are W0 doc or INTERFACES follow-ups or optional sender-side hardening (the desk re-validates). Two items are queued outside this review and are not findings: the audit exit-5 value (lead decision, INTERFACES amendment AM-5, row PR10-M4) and spec 05 line 64 live-only wording (queued errata). The owner may take R2-A4 and R2-A5 as a small `desk-req-schema.sh` pass or defer them with R2-A1 to R2-A3. Under D7 this is round 2 of at most 3.

## 7. Confidence notes

- Validated by 3+ C members: R2-A1 (platform, security, strategic, integration), R2-A2 (platform, security, strategic), R2-A3 (platform, security, strategic), R2-A4 (platform, devops, integration: exactly 3), R2-A5 (platform, integration, security, technical-writer). M1-M4 closure rests on 3 to 5 seats each.
- Solo findings: none. Every FINDING had at least 3 distinct validating seats on the bus.
- Silent seats: no Consulted seat objected anywhere; devops, fullstack and technical-writer posted no C on pr-check-3, and strategic, fullstack and technical-writer none on pr-check-5.
- Repro provenance: R2-A4 reproduced by its raiser (security) and devops on jq 1.7.1; R2-A5 by code read (platform, technical-writer) and the raiser's repro. R2-A1 to R2-A3 are doc and spec comparisons by read.
- Synthesizer did not re-run tests, repros or any script; it read the bus (all topics, peek) and `git log` / `git show --stat` of the three fix commits for the commit-to-finding mapping only.

CODE-GATE-REVIEW: PASS head=ac9df4c140be212bbac3bacb2c12e164eca2fbac blocking=0 medium=0
