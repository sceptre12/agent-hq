# Task Spec 20: `pre-pr-gate` (NEW skill, stage 4b)

Spec of record for W1 item 20 (design part-06 §7 row "14-22"; card 10 in part-02 §2.2). Authority: `INTERFACES.md` 1.5.0 (FROZEN; amendment AM-1: port guard, `security-audit`; AM-3 OQ-2 one claimed retry; AM-4 20 loop decisions; AM-5 10-B2 review-bus path). Anchors below are `interfaces/part-X` sections.

## 1. Objective
Author `skills/pre-pr-gate/SKILL.md` (plus `references/*.md` depth) so that a lead holding a rebased sub-task branch runs card 10 end to end and ends with exactly one `PREPR:` token.

## 2. Context package
- Card 10 (part-02 §2.2 item 10) is the step list; the steps below only restate its numbering. Rules: part-03 §3 "Quality rules" (G48, D35, D55, D57, D59, D60, D62, ADR 0014 T1), part-04 §5.7 (checklist), §5.8 (profile keys), §5.8b rows "Version-bump rule", "PR merge pipeline".
- Grammars produced: `PREPR:` (part-d D1.1); `checklist-<subtask>.md`, `pr-body.md`, `fix-<agent-id>-<n>.md`, `verify-<seat-id>-<n>.md` (part-a A.6); `gate-runs/<sha>.md` `GATE-PASS` (part-a A.7).
- Grammars consumed: review record `record-<head>.md` lines 1-3 (`CODE-GATE-REVIEW`, `Reviewed-By`, `Verified-By`; part-a A.6); profile keys `gates.*`, `node.prefix_cmd`, `secrets.pattern_file`, `sensitive_paths[]`, `default_branch` ("main" means this key; AM-4 20 Q6) (part-a A.2.2), and `install.rebuild_allowlist`, `e2e.dist_scan_cmd` (part-04 §5.8 only, not in A.2.2; integrator note, `reviews/20-pre-pr-gate-rung1.md`); catalog `lane-lease` `gate-runner/<n>` (part-a A.5); `substate.md` field `prepr` (part-a A.3); `INSTALLED` rows (ADR 0055).
- Callers: `delivery-run` (lead, stage 4b and `plan-pr` mode for `st0`). The lead copies `prepr` to `substate.md`; `push` and `pr-create` require `PREPR: PASS` for the head (part-b B4).
- Existing skills reused unchanged by name: `pr-review` (extended, item 10 of the build table: `PR_REVIEW_MODE=local-diff`, `ROLES`, `RECORD_PATH`, `STACK_BASE/HEAD`), `fix-verifier` (extended: `FILE_SET`), `security-audit` (guidance mode), `review-tailor` for the seat set when the profile asks for it.

## 3. Scope
In (this item writes only):
- `skills/pre-pr-gate/SKILL.md` (body under 5k tokens; frontmatter `name`, `description` with "Use when", `version`; no `disable-model-invocation`, D16).
- `skills/pre-pr-gate/references/*.md` at the top level of `references/` (for example `steps-detail.md`, `g48-classes.md`, `security-seat.md`).

Out: `skills/pre-pr-gate/references/templates/` (item 27; the SKILL.md links it by the names item 27 owns); no `references/briefs/` exists here (RESOLVED Q1: one briefs root `skills/delivery-run/references/briefs/`, item 27b); `pr-review`, `fix-verifier`, `security-audit` edits; scripts; INTERFACES.
Do NOT create: a second record format, a weighted score, a new token, a new desk verb, `tools/` files, symlinks.

Directories written: `skills/pre-pr-gate/` only.

## 4. Contracts
| Contract | Value | Authority |
|---|---|---|
| Step 0 inputs | `RUN_HOME`, `SUBTASK`, `HEAD`, `WORKTREE`, `REPO_PROFILE`, `SECURITY_AUDIT` (`guidance\|full`, enum part-d D2.1); `DELIVERY_ROOT` env; print `INPUT-ERROR <field> <reason>`, one line per failing field, then stop | part-d D1, D2.2 row 10 (AM-1) |
| Output token | `PREPR: PASS` or `PREPR: STOP <rows>` as line 1 of `RUN_HOME/review/<subtask>/checklist-<subtask>.md`; rows = failed §5.7 row ids | part-d D1.1 |
| Review record | consumed as written by `pr-review`; the verifying seat appends line 3 and differs from the line-2 seat | part-a A.6, M16 |
| Fix and verify records | `fix-<agent-id>-<n>.md` with a non-empty `fix:` field; `verify-<seat-id>-<n>.md`; `<n>` = round 1..3 | part-a A.6, D7 |
| Gate record | `GATE-PASS` written by a separate gate-runner agent under a `gate-runner` lease; cold run with `--skip-nx-cache` is the first-push `GATE-PASS` | part-a A.7, A.5 |
| Version bump | every app under `apps/` (not `apps/examples/`, not `e2e`) affected since merge-base has a changed `package.json` `version`; none added for unaffected apps | part-04 §5.8b (B3) |
| `HUSKY=0` | not restated; link part-a A.7 only | part-a A.7 |
| Review loop cap | rounds 1-3, then STOP: the sub-task halts, open findings to the human, other sub-tasks continue | D7, card 10 step 9 |
| Port guard | the local `pr-review` bus port: `pre-pr-gate` passes `BUS_PORT` = the sub-task's `review-bus` candidate from the dispatch-plan port table to `pr-review`, whose Step 1 runs the four A.5.2 steps (claim, `catalog.sh register port`, launch pinned to that port, `catalog.sh start`); `pre-pr-gate` claims no port itself; on a refusal `pr-review` makes exactly one claimed retry at `BUS_PORT + 10`; after the second refusal the gate writes `PREPR: STOP C<port row>` and the lead writes `stop_reason: port-refused` (amended: AM-3 OQ-2, AM-4 20, D2.2 row 10; integrator note: "never re-picked" is overridden) | part-a A.5.2; spec 10 Q10-7 |
| Security seat, guidance | `SECURITY_AUDIT=guidance` (default): the security seat loads `skills/security-audit` diff-scoped, writes no file, launches no agent; passed to `pr-review` as its `SECURITY_AUDIT` input | part-d D2.1, D2.3 `pr-review` |
| Loop decisions (amended: AM-4 20) | a sensitive-path hit (A.2.2 `sensitive_paths[]`) passes only with a desk `INSTALLED` row or a `grant.<subtask>.<n>.<run-id>.ok` file (A.2.1; AM-5 26 run-id suffix); a plan-check runs before round 1 (D55); a failure outside the review loop is `PREPR: STOP <id>`, never handed to the fixer; `fix-verifier` also verifies the G48 pre-round fixes; Step 0 rejects a `REPO_PROFILE` `@<sha>` that does not match `git hash-object` with `INPUT-ERROR REPO_PROFILE sha` (D1 `sha` reason); a gate runner that dies holding its lease is released by the post-`TaskStop` orphan sweep | part-d D1, D2.2 row 10; part-a A.2.1, A.7 |
| Security audit, full | only on an explicit operator request or a `security_sensitive: yes` epic (set by the conductor, not decided here); `output-dir` `RUN_HOME/<subtask>/security-audit/run-<N>/`; agents persona `security-auditor`, a slot row each, no agent without a free slot; the gate row `node skills/security-audit/validate-findings.cjs <output-dir>/findings.json` non-zero exit fails checklist row `C26` (`PREPR: STOP C26`; RESOLVED Q3) | part-a A.4, A.5.3 |

## 5. Inherited module API
`catalog.sh` (register/start/release/fail, leases; item 5), `scope-check.sh` (item 6; preventive mode), `desk-req.sh` (not used here: `pre-pr-gate` sends no desk verb), `tools/port-check.sh` via the `port-claim` skill (part-a A.5.2). The skill names these by their INTERFACES script table entry and does not re-describe flags beyond what that table states.

## 6. What you inherit
Frontmatter and anatomy per `tools/skill-authoring.md` §2-§5 (Trigger, Steps, Red flags, Exit criteria, Provenance). Provenance line: card 10 friction entries (`enforcement-gates:10`, `:141`; PR #18/#19 second verify; `pr-review-local-diff-bus-facts`; `pr-review-orch-reads-closed`; `brain-workflow-shift:26`).

## 7. Known risky values
| Value | Correct | Wrong | Source |
|---|---|---|---|
| install | `--frozen-lockfile --ignore-scripts` plus `pnpm rebuild` of `install.rebuild_allowlist` | plain install | card 10 step 2 |
| nx cache | `--skip-nx-cache` on the cold gate run | cached run | `enforcement-gates:141` |
| topics | `pr-check-N-closed`, read with `peek:true`, fresh `agent_id` per reader, `limit 200` | shared agent id, no peek | A4 |
| validator verdict | fail on any single failing Blocking row | weighted score | `brain-workflow-shift:26` |
| fixer escalation | a second fix round that adds Mediums escalates the fixer one tier; never a third top-tier attempt | retry at the same tier | ADR 0014 T1 |
| G48 | mechanical-tier agent, before round 1 and after every fix; fixes land before any seat reads | seats read first | part-03 quality rules |
| advisory only | D44, D54 (hint line in fixer brief), D58, D61, D65, D66 | written as rules | D6 |
| round cap | 3 | 5 or open-ended | D7 |

## 8. Acceptance criteria
- [ ] SKILL.md has the five sections and a Step 0 using the exact input names of section 4.
- [ ] Steps cover, in card order: rebase then review landing head; node check; `GATES` and CI-parity cold run by the gate runner; version-bump check; dist scan; standardization pre-check; redaction gate; preventive scope-check; G48 pre-round; 7-seat `pr-review`; separate fixer; `fix-verifier` with `FILE_SET`; rounds 1-3 and STOP; completeness validator over §5.7; Verified-By; catalog check; `pr-body.md`.
- [ ] The per-push affected gate is stated once, by link to part-a A.7, with the rule that a changed head needs a `GATE-PASS` for the final head before `push` (RESOLVED Q4).
- [ ] The security-audit guidance seat is a named step; the full-mode condition and the `validate-findings.cjs` gate row are quoted from part-a A.5.3 and part-d D2.1, not paraphrased; full-mode agents are bound to slot rows (A.4).
- [ ] The `pr-review` bus port: `BUS_PORT` passed from the dispatch-plan port table; `pr-review` Step 1 runs the A.5.2 order with its one claimed retry at `BUS_PORT + 10`; the in-run review bus lives under `RUN_HOME/review/<subtask>/<review-id>/bus/` (RESOLVED Q2; amended: AM-3 OQ-2, AM-5 10-B2).
- [ ] `PREPR:` values (RESOLVED, PC-8): `PREPR: PASS`, or `PREPR: STOP <ids>` with the comma-separated failed checklist row ids `C1`-`C26` of the item 27 checklist template; the `SLUG` for `review-tailor` is `<subtask>-diff-<n>` minted here (spec 15 Q4).
- [ ] Head-moved stop: rebase then non-author delta verify of reviewed-head..new-head (part-03 "Rebase-before-verify", M16).
- [ ] Every redirect to the human names the file path (record, checklist), never prose only.
- [ ] No cost metric, no personal-project term, no Notion, no `/Users/<name>` path.

## 9. Verification commands
```bash
set -eu; W=~/projects/agent-hq-worktrees/delivery-w0; cd "$W"; D=skills/pre-pr-gate; S=$D/SKILL.md
test -f "$S"; head -1 "$S" | grep -qx -- '---'
grep -qE '^name: pre-pr-gate$' "$S"; grep -qE '^version: 0\.1\.0$' "$S"
d=$(grep -E '^description:' "$S"); [ "${#d}" -le 1036 ]; printf '%s' "$d" | grep -q 'Use when'
if grep -qE '^disable-model-invocation' "$S"; then echo "FAIL: disable-model-invocation"; exit 1; fi
for s in Trigger Steps 'Red flags' 'Exit criteria' Provenance; do grep -qx "## $s" "$S" || { echo "MISSING $s"; exit 1; }; done
test "$(wc -w < "$S")" -le 3500
for t in 'INPUT-ERROR' 'PREPR: PASS' 'PREPR: STOP' 'C26' 'GATE-PASS' 'CODE-GATE-REVIEW' 'Verified-By' 'skip-nx-cache' 'pr-check-N-closed' 'peek' 'FILE_SET' 'security-audit' 'BUS_PORT' 'gate-runner' 'G48' 'A.7' 'SECURITY_AUDIT' 'validate-findings' 'diff-'; do grep -rq --exclude-dir=templates -- "$t" "$D" || { echo "ABSENT $t"; exit 1; }; done
if grep -riE --exclude-dir=templates '/Users/[a-z]+|brainAlpha|brainBeta|brainGamma|hermesAuth|Xavier|touri|ofw|runfrist|jetblue|notion' "$D"; then echo "FAIL: forbidden match"; exit 1; fi
if grep -riE --exclude-dir=templates 'token cost|dollar|\$[0-9]|cost metric' "$D"; then echo "FAIL: cost text"; exit 1; fi
if find "$D" -type l | grep -q .; then echo symlink; exit 1; fi
bash tools/check-doc-length.sh "$D" >/dev/null
echo SKILL-20-OK
```
**Done condition:** the block exits 0 and its last stdout line is `SKILL-20-OK`, and the review trio returns CLEAN.

## 10. Branch
No branch for the author (Rule 7: Worker1 integrates on `wt/delivery-w0`; the author writes only the files in section 3 and does not commit).

## 11. Decision Gate reminder
Stop and write `.decisions/20.md` if: AM-1 contradicts card 10; a step needs a desk verb that part-b B4 does not list; a `PREPR` row id is needed outside the checklist ids `C1`-`C26` (PC-8); a resolution below cannot be applied without changing the step order. Do not guess.

## Metadata
- Tier: execute (design §7 row "14-22"); the gate-runner, G48 checker and catalog check named in the skill are mechanical; fixer is execute and escalates per ADR 0014 T1; validator and Verified-By seat are verify.
- Review rung: Rung 1 trio (`doc-reviewer`, fix agent, `fix-verifier`), up to 3 rounds then the owner (D7); not one of the four heavy items.
- Dependencies: INTERFACES 1.5.0 (landed; hard); items 10-11 (`pr-review`, `fix-verifier` EXTENDs) and 5-7 (scripts) for the names it cites, soft (names fixed by INTERFACES); item 18 `resource-catalog` for lease wording, soft. Consumed by item 28 `delivery-run`.
- Not a split item; no integration step.

## Plan-check resolutions (2026-10-26; report `reviews/plan-check-w1-specs.md`)
1. RESOLVED (INTERFACES C1.2 `persona` row, D2.1, row R4-J14: one briefs root `skills/delivery-run/references/briefs/`; spec 27 §3 piece T-D; PC-3): no `references/briefs/` in this skill; item 27 writes only `references/templates/step-completeness-checklist.md` here; this item writes `SKILL.md` and top-level `references/*.md`; disjoint at the subdirectory.
2. RESOLVED (PC-4; A.5.2 "the launcher never auto-picks"; AM-2 row 7): `pr-review` is the launcher of its bus, so its Step 1 runs the four steps (and the one claimed retry at `BUS_PORT + 10`, AM-3 OQ-2); `pre-pr-gate` passes `BUS_PORT` (the `review-bus` candidate of this sub-task's dispatch-plan port table) and claims nothing itself.
3. RESOLVED (INTERFACES D1.1 `PREPR:` regex has no `FAIL`; A.5.3 "is `PREPR: FAIL`" is an INTERFACES wording slip, AM-2 row 8; PC-8): a non-zero `validate-findings.cjs` exit fails checklist row `C26`, token `PREPR: STOP C26`. Under `full` the audit runs after the G48 pre-round check and before round 1 of the 7-seat `pr-review`, because the security seat reads the latest `findings.json` (D2.3 `pr-review` row); it is not re-run per round unless the head changes.
4. RESOLVED (INTERFACES A.7 cadence "once per push or batch, at unit end and before each push" and "`pre-pr-gate` cold run ... is the `GATE-PASS` for the PR's first push (same command, same runner)"; B5 gate-run marker `gate-runs/<expect_head>.md`): when fix rounds move the head, the gate runner re-runs the same cold CI-parity command on the final head under a `gate-runner` lease and writes `gate-runs/<final head>.md`; the step-2 run is the first-push `GATE-PASS` only while the head is unchanged. Checklist row `C9` checks it. No INTERFACES change.
