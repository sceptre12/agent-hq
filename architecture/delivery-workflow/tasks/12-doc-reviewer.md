# Task Spec: 12-doc-reviewer (EXTEND `doc-reviewer`: `references/delivery-doc-checks.md`)

- Work item: 12 (part-06 §7 row 9-13; card: part-02 §2.3 `doc-reviewer` row, "stage 2 checks"). Tier: `execute` (part-06 §7). The skill runs on the verify/design tiers per its callers (`review-tailor`, stage 2).
- Review rung: Rung 1 trio by the UNMODIFIED installed skills (M29), max 3 rounds then the owner (D7). Prose; no script.
- Branch: the separate EXTEND branch (M29), shared with items 10, 11, 13, own directory. RESOLVED (PC-1, plan-check): branch `ext/delivery-extends` in worktree `~/projects/agent-hq-worktrees/delivery-extends`, created by the integrator (Worker1) from `wt/delivery-w0` after the plan-check commit (so it holds the W0 item 8 ports); items 9-13 share it on directory-disjoint paths; the branch is reviewed separately and never used to review the family (M29).
- Dependencies: INTERFACES D2.3 (row `doc-reviewer`: no new inputs); part-04 §5.1 ticket template and §5.2 `architecture.md` section list (the checks quote them); none on items 10, 11, 13.
- Split: none.

## 1. Objective
Add `skills/doc-reviewer/references/delivery-doc-checks.md` and the pointers in `SKILL.md` so a stage 2 delivery doc is checked for required sections, `(fact)` commands, child coverage and ticket-template format.

**Done condition (one, machine-checkable):** with the fixture results saved by a non-author verifier (§9), the §9 block exits 0 and its last stdout line is `EXT-12-OK`.

## 2. Context Package
- Card: "`references/delivery-doc-checks.md`: required sections present, every "(fact)" names its command, child-coverage check, template-format check against the ticket template" | source "stage 2 checks" | no owner ask.
- INTERFACES D2.3 row `doc-reviewer`: "none (adds `references/delivery-doc-checks.md`)"; enumerated fields none. So this EXTEND adds NO named input and no `INPUT-ERROR` line; applicability must come from the document itself or the caller's request text.
- The four checks and their sources in the design (cite, do not invent beyond them):
  1. Required sections present: `architecture.md` 14 sections (part-04 §5.2: Summary 15 lines, Goals/non-goals, Components/interfaces/contracts, Locked decisions with ADR refs, Epic and sub-task tree with merge order, Scope, Dispatch-plan requirement, Testing plan pointer incl. e2e harness statement, Release sketch pointer with agent/human split, Risks and stop-the-line, Diagrams as text, Review record, Human acceptance block, Provenance). Other delivery docs: their own section lists in part-04 (§5.1 ticket body, §5.3 `dispatch-plan.md`, §5.3b unit task spec 11 sections, §5.4 `test-plan.md`, §5.5 `release-plan.md`).
  2. Every "(fact)" names its command: a claim tagged `(fact)` must carry the command (and date and where) that measured it, the design's own convention (part-05 §6.1 "Measured facts (command, date, where)").
  3. Child-coverage: every child ticket draft of the epic tree is reachable from the architecture doc and every architecture sub-task has at least one child draft; each child has acceptance criteria (ticket-decomposer stop rule "child without AC", part-03 §3.2).
  4. Template-format: epic and child drafts match §5.1 (header fields, body sections, Gherkin AC with happy, failure or edge and observability cases, Subtasks; epic additions; agent additions).
- Existing skill: `skills/doc-reviewer/SKILL.md` 144 lines (10-step 3-phase; checks table 1-14 in Steps; Check 14 Flow-Scope for bus docs); `references/checks.md` 717 lines is OVER the 500-line default and is not touched by this item (it is a skill reference, exempt from the doc-length rule; leave as is).
- Callers: stage 2 review loop (`delivery-architecture`, `review-tailor` Rung 1); `RUNG:` seat table D1.1.

## 3. Scope
**In scope (directory `skills/doc-reviewer/` only):** `references/delivery-doc-checks.md` (NEW, 500 lines or fewer); `SKILL.md` edits: `version:` frontmatter, one new row in the Steps checks table naming the delivery checks as "Delivery docs (stage 2)", one sentence in Phase A step 2 pointing to the file, a Red flags row, an Exit criteria line, a Provenance line.
**Out of scope:** `references/checks.md` content, the existing 14 checks, the severity scale, `panel-consultation`, `review-7-panel`, `delivery-architecture` itself (item 15), `ticket-clerk`, ticket templates other than the part-04 §5.1 summary, any Jira call.
**Do NOT create:** a named input or a mode flag, a new severity, a new verdict word, a numbering that collides with Checks 1-14 (use `DOC-1`..`DOC-4` labels, RESOLVED Q12-2 (PLAN-CHECK DEFAULT): `DOC-1`..`DOC-4`, since plain `D1`-`D4` would collide with design decision ids), a copy of the Jira template text from the work-context store (read-only; paraphrase from part-04 §5.1 only), or a file outside `skills/doc-reviewer/`.

## 4. Contracts
| Contract | Field / value | Authority |
|---|---|---|
| D2.3 `doc-reviewer` row | no new inputs; adds `references/delivery-doc-checks.md` | `interfaces/part-d-enums-topics.md` D2.3 (line 101) |
| Severity | Blocking / Medium / Advisory as in `references/checks.md` "Severity Classification" | existing skill |
| Verdict words | READY / NOT READY / READY WITH CONDITIONS | `SKILL.md` Phase B step 6 |
| D1.1 tokens | `ARCH: ready` and `DRAFTS: n drafts` are produced by `delivery-architecture`, not here; this skill only reports | part-d D1.1 |
| Template source | §5.1 and §5.2 of `part-04-templates.md` | design |

## 5. Inherited Module API
The review output format of `SKILL.md` Phase B (findings table `# | Issue | Severity | Check | Recommended Fix`) is reused unchanged; each new check reports in that table with its `DOC-<n>` label in the Check column.

## 6. What You Inherit
| Thing | Source | Notes |
|---|---|---|
| Cold read, Check 4 cross-reference walk | existing checks | DOC-3 child coverage builds on Check 4's method; cite, do not restate |
| Check 8 source verification | existing | DOC-2 `(fact)` command check is complementary: DOC-2 checks that a command is NAMED; Check 8 verifies against source |
| Phase B "wait for decision" | `SKILL.md` steps 7-8 | unchanged; an unattended caller supplies the decision (D7 loop owner) |

## 7. Known Risky Values
| Value | Correct | Wrong | Source |
|---|---|---|---|
| `architecture.md` section count | 14 | 13 or the older 11 | part-04 §5.2 |
| Unit task spec section count | 11 | 12 | part-04 §5.3b |
| Fact convention | "(fact)" followed by command, date, where | an uncommanded "(fact)" | part-05 §6.1 header |
| Review-record length cap | Summary 15 lines | no cap | part-04 §5.2 |
| Gherkin AC cases | happy, failure or edge, observability | happy only | part-04 §5.1 |
| New-check ids | `DOC-1`..`DOC-4` (Q12-2) | `15`..`18` (collides with `checks.md` numbering and the 14-row table) | `SKILL.md` Steps |

## 8. Acceptance Criteria
- [ ] `delivery-doc-checks.md` exists, 500 lines or fewer, with exactly four checks `DOC-1` required sections, `DOC-2` fact commands, `DOC-3` child coverage, `DOC-4` template format, each with: what it reads, the pass rule, the finding text, severity (Blocking for a missing `architecture.md` section or a child without AC; Medium for an uncommanded `(fact)` and a template-format miss; Advisory for wording; RESOLVED Q12-3 (PLAN-CHECK DEFAULT): these severities, each marked "plan-check default" in the file), and one worked example.
- [ ] `SKILL.md` links the file from the checks table and from Phase A step 2; states when the delivery checks apply (RESOLVED Q12-4, INTERFACES D2.3 `doc-reviewer` row "none": no input, so the trigger is "the document under review is a delivery stage 2 artifact: `architecture.md`, `dispatch-plan.md`, a task spec or an epic/child ticket draft").
- [ ] No named input added; `SKILL.md` Step 0 behaviour unchanged.
- [ ] Existing 14 checks and `references/checks.md` byte-identical (`git diff` empty for that file).
- [ ] Red flags and Exit criteria rows added; Provenance line cites the card and stage 2; `version: 1.1.0` (RESOLVED, PC-1: the unversioned base at `c1ba30e` or the item 8 port counts as 1.0.0; an EXTEND is a minor bump) (RESOLVED Q12-5).

## 9. Verification Commands
```bash
set -eu; W=~/projects/agent-hq-worktrees/delivery-extends; cd "$W"; B=$(git merge-base HEAD wt/delivery-w0); S=skills/doc-reviewer; F=$S/references/delivery-doc-checks.md; R=${FIXTURE_DIR:?the non-author verifier sets FIXTURE_DIR to its fixture result directory}
test -f $F; [ "$(wc -l < $F)" -le 500 ]
for c in DOC-1 DOC-2 DOC-3 DOC-4; do grep -q "^##* $c" $F || { echo "MISSING $c"; exit 1; }; done
grep -q 'delivery-doc-checks.md' $S/SKILL.md
git diff --quiet $B -- $S/references/checks.md
if git diff $B -- $S/SKILL.md | grep -E '^\+.*(INPUT-ERROR|named input)'; then echo "FAIL: input added"; exit 1; fi
# fixture: the verifier builds in $TMPDIR a 13-section architecture.md (Provenance removed), one "(fact)" without a command,
# one child draft without AC, one child missing the observability case, and a clean control doc; it runs doc-reviewer on
# each and saves the raw reports as $R/fixture.out and $R/control.out
for c in DOC-1 DOC-2 DOC-3 DOC-4; do grep -q "$c" $R/fixture.out || { echo "FIXTURE-MISSING $c"; exit 1; }; done
if grep -qE 'DOC-[1-4]' $R/control.out; then echo "FAIL: control flagged"; exit 1; fi
for h in '## Trigger' '## Steps' '## Red flags' '## Exit criteria' '## Provenance'; do grep -q "^$h" $S/SKILL.md || { echo "MISSING $h"; exit 1; }; done
head -12 $S/SKILL.md | grep -qE '^version: 1\.1\.0$'
bash tools/check-doc-length.sh . >/dev/null
if grep -rnE '/Users/[a-z]+|brainAlpha|brainBeta|brainGamma|hermesAuth|Xavier|touri|ofw|runfrist|jetblue|Notion' $S; then echo "FAIL: forbidden match"; exit 1; fi
if git status --porcelain | grep -vE '^.. (skills/(wave-execution|pr-review|fix-verifier|doc-reviewer|feature-change)/|architecture/wave-execution\.md)'; then echo "FAIL: change outside the EXTEND scopes"; exit 1; fi
echo EXT-12-OK
```
Review-time check: the fixture report gives `DOC-1` and `DOC-3` Blocking, `DOC-2` and `DOC-4` Medium (Q12-3).

## 10. Branch and worktree
Branch `ext/delivery-extends` (PC-1); no add, commit, rebase or push by the author.

## 11. Decision Gate Reminder
Write `.decisions/12-doc-reviewer.md` and stop if: a check needs a new input; the part-04 section lists conflict with INTERFACES; severities (Q12-3) are demanded as owner rules rather than proposals; the file would pass 500 lines (split into a second `references/` file instead, never compress).
