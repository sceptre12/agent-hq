# Task Spec 20: `pre-pr-gate` (NEW skill, stage 4b)

Spec of record for W1 item 20 (design part-06 §7 row "14-22"; card 10 in part-02 §2.2). Authority: `INTERFACES.md` 1.1.0 (FROZEN; amendment AM-1: port guard, `security-audit`). Anchors below are `interfaces/part-X` sections.

## 1. Objective
Author `skills/pre-pr-gate/SKILL.md` (plus `references/*.md` depth) so that a lead holding a rebased sub-task branch runs card 10 end to end and ends with exactly one `PREPR:` token.

## 2. Context package
- Card 10 (part-02 §2.2 item 10) is the step list; the steps below only restate its numbering. Rules: part-03 §3 "Quality rules" (G48, D35, D55, D57, D59, D60, D62, ADR 0014 T1), part-04 §5.7 (checklist), §5.8 (profile keys), §5.8b rows "Version-bump rule", "PR merge pipeline".
- Grammars produced: `PREPR:` (part-d D1.1); `checklist-<subtask>.md`, `pr-body.md`, `fix-<agent-id>-<n>.md`, `verify-<seat-id>-<n>.md` (part-a A.6); `gate-runs/<sha>.md` `GATE-PASS` (part-a A.7).
- Grammars consumed: review record `record-<head>.md` lines 1-3 (`CODE-GATE-REVIEW`, `Reviewed-By`, `Verified-By`; part-a A.6); profile keys `gates.*`, `node.prefix_cmd`, `secrets.pattern_file`, `install.rebuild_allowlist`, `e2e.dist_scan_cmd`, sensitive-path list (part-a A.2.2, part-04 §5.8); catalog `lane-lease` `gate-runner/<n>` (part-a A.5); `substate.md` field `prepr` (part-a A.3); `INSTALLED` rows (ADR 0055).
- Callers: `delivery-run` (lead, stage 4b and `plan-pr` mode for `st0`). The lead copies `prepr` to `substate.md`; `push` and `pr-create` require `PREPR: PASS` for the head (part-b B4).
- Existing skills reused unchanged by name: `pr-review` (extended, item 10 of the build table: `PR_REVIEW_MODE=local-diff`, `ROLES`, `RECORD_PATH`, `STACK_BASE/HEAD`), `fix-verifier` (extended: `FILE_SET`), `security-audit` (guidance mode), `review-tailor` for the seat set when the profile asks for it.

## 3. Scope
In (this item writes only):
- `skills/pre-pr-gate/SKILL.md` (body under 5k tokens; frontmatter `name`, `description` with "Use when", `version`; no `disable-model-invocation`, D16).
- `skills/pre-pr-gate/references/*.md` at the top level of `references/` (for example `steps-detail.md`, `g48-classes.md`, `security-seat.md`).

Out: `skills/pre-pr-gate/references/templates/` and `references/briefs/` (written by items 27 and 27b; the SKILL.md links them by the names those items own, and `SPEC-QUESTION 1` records the open overlap); `pr-review`, `fix-verifier`, `security-audit` edits; scripts; INTERFACES.
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
| Port guard | the local `pr-review` bus port: (1) `tools/port-check.sh --claim <port> <bind> <container_port> <service> <project> claimed <source> <note>` via the `port-claim` skill, `project`=`<run-id>`, `source`=`<run-id>-<subtask>`; (2) `catalog.sh register port`; (3) launch; (4) `catalog.sh start`. Exit 1 or 2 refuses the launch, never auto-pick, report to the lead; exit 3 is stop-the-line. Release is cleanup's | part-a A.5.2 |
| Security seat, guidance | `SECURITY_AUDIT=guidance` (default): the security seat loads `skills/security-audit` diff-scoped, writes no file, launches no agent; passed to `pr-review` as its `SECURITY_AUDIT` input | part-d D2.1, D2.3 `pr-review` |
| Security audit, full | only on an explicit operator request or a `security_sensitive: yes` epic (set by the conductor, not decided here); `output-dir` `RUN_HOME/<subtask>/security-audit/run-<N>/`; agents persona `security-auditor`, a slot row each, no agent without a free slot; the gate row `node skills/security-audit/validate-findings.cjs <output-dir>/findings.json` non-zero exit fails the gate (SPEC-QUESTION 3) | part-a A.4, A.5.3 |

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
- [ ] The per-push affected gate is stated once, by link to part-a A.7, with the rule that a changed head needs a `GATE-PASS` for the final head before `push` (see SPEC-QUESTION 4).
- [ ] The security-audit guidance seat is a named step; the full-mode condition and the `validate-findings.cjs` gate row are quoted from part-a A.5.3 and part-d D2.1, not paraphrased; full-mode agents are bound to slot rows (A.4).
- [ ] The `pr-review` bus port follows the four-step order of part-a A.5.2.
- [ ] Head-moved stop: rebase then non-author delta verify of reviewed-head..new-head (part-03 "Rebase-before-verify", M16).
- [ ] Every redirect to the human names the file path (record, checklist), never prose only.
- [ ] No cost metric, no personal-project term, no Notion, no `/Users/xavier` path.

## 9. Verification commands (the verifier re-runs these from the worktree W)
```bash
S=skills/pre-pr-gate/SKILL.md
test -f "$S" && head -1 "$S" | grep -qx -- '---'
grep -E '^name: pre-pr-gate$' "$S"; grep -E '^version: ' "$S"
awk '/^description:/{ if (length($0) > 1036) print "DESC-TOO-LONG" }' "$S"   # 1024 + key
grep -E '^description:.*Use when' "$S"
! grep -E '^disable-model-invocation: *true' "$S"
for s in Trigger Steps 'Red flags' 'Exit criteria' Provenance; do grep -qx "## $s" "$S" || echo MISSING "$s"; done
test "$(wc -w < "$S")" -le 3500                          # about 5k tokens
for t in 'INPUT-ERROR' 'PREPR:' 'GATE-PASS' 'CODE-GATE-REVIEW' 'Verified-By' 'skip-nx-cache' 'pr-check-N-closed' 'peek' 'FILE_SET' 'security-audit' 'port-check' 'gate-runner' 'G48' 'A.7' 'SECURITY_AUDIT' 'validate-findings'; do grep -q -- "$t" "$S" skills/pre-pr-gate/references/*.md || echo ABSENT "$t"; done  # also: SECURITY_AUDIT validate-findings
! grep -riE '/Users/xavier|brainAlpha|brainBeta|brainGamma|hermesAuth|Xavier|touri|ofw|runfrist|jetblue|notion' skills/pre-pr-gate
! grep -riE 'token cost|dollar|\$[0-9]|cost metric' skills/pre-pr-gate
bash tools/check-doc-length.sh skills/pre-pr-gate
```
Every `ABSENT` or `MISSING` line is a fail. The done condition is: all commands above print nothing except the matches of the `name`, `version` and `Use when` greps, and the review trio returns CLEAN.

## 10. Branch
No branch for the author (Rule 7: Worker1 integrates on `wt/delivery-w0`; the author writes only the files in section 3 and does not commit).

## 11. Decision Gate reminder
Stop and write `.decisions/20.md` if: AM-1 contradicts card 10; a step needs a desk verb that part-b B4 does not list; a `PREPR` row id is needed that §5.7 does not name; a choice in SPEC-QUESTIONS below blocks the step order. Do not guess.

## Metadata
- Tier: execute (design §7 row "14-22"); the gate-runner, G48 checker and catalog check named in the skill are mechanical; fixer is execute and escalates per ADR 0014 T1; validator and Verified-By seat are verify.
- Review rung: Rung 1 trio (`doc-reviewer`, fix agent, `fix-verifier`), up to 3 rounds then the owner (D7); not one of the four heavy items.
- Dependencies: INTERFACES 1.1.0 (landed; hard); items 9-11 (`pr-review`, `fix-verifier` EXTENDs) and 5-7 (scripts) for the names it cites, soft (names fixed by INTERFACES); item 16 `resource-catalog` for lease wording, soft. Consumed by item 28 `delivery-run`.
- Not a split item; no integration step.

## SPEC-QUESTIONs
1. Templates (`checklist`, `pr-body`) and briefs (fixer, validator, gate-runner, G48 checker) live in `references/templates/` and `references/briefs/` of this skill but are written by items 27 and 27b. Plan-checker: confirm the subdirectory split keeps scopes disjoint.
2. The `pr-review` bus port: A.5.2 names the claim form, but not whether `pre-pr-gate` or `pr-review` itself runs the four steps for its per-review bus (the D2.3 `pr-review` row lists no port input). Default: `pre-pr-gate` does, before it launches `pr-review`.
3. A.5.3 says a non-zero `validate-findings.cjs` exit is `PREPR: FAIL`, but the D1.1 token is `PREPR: (PASS|STOP...)` and has no `FAIL`. Default: map it to `STOP` with a new row id; the row id is not in §5.7 and needs an INTERFACES decision. Also open: does `SECURITY_AUDIT=full` run before or inside the 7-seat round.
4. Ordering: card 10 runs the cold gate at step 2 (before review and fixes), A.7 says that run is the first-push `GATE-PASS` with no second run, but fix commits change the head and the desk requires `gate-runs/<expect_head>.md` for the final head. Does a fix round trigger a gate-runner pass on the final head, or does the cold run repeat? Needs an INTERFACES decision.
