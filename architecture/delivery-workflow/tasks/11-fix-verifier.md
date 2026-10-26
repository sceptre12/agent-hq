# Task Spec: 11-fix-verifier (EXTEND `fix-verifier`: `FILE_SET` input, M24)

- Work item: 11 (part-06 §7 row 9-13; card: part-02 §2.3 `fix-verifier` row). Tier: `execute` (part-06 §7). The skill's own run tier stays `verify`, never the author (part-01 tiers row).
- Review rung: Rung 1 trio by the UNMODIFIED installed skills (M29), max 3 rounds then the owner (D7). The trio's `fix-verifier` run uses `FILE_SET` = this item's In-scope files. Prose skill, no script.
- Branch: the separate EXTEND branch (M29), same branch as items 10, 12, 13, own directory. SPEC-QUESTION Q11-1: branch name and base are not named in the design; the integrator names them.
- Dependencies: INTERFACES D2.3 (frozen row `fix-verifier`). None on items 10, 12, 13.
- Split: none.

## 1. Objective
Add a `FILE_SET` input to `skills/fix-verifier/` so that any change outside the failing file set is reported as `ISSUES_FOUND`.

**Done condition (one, machine-checkable):** the §9 block prints `OK-input OK-check OK-fixture OK-noregress`, prints no `MISSING` line, the sanitization grep and the out-of-scope `git diff --stat` print nothing, and `tools/check-doc-length.sh .` exits 0.

## 2. Context Package
- Card (part-02 §2.3): "Add `file_set` input: flag any change outside the failing file set as `ISSUES_FOUND` (M24). The v1 `class_sweep` proposal is dropped: D54 and D58 are advisory, not rules (D6)." Source M24, D6; no owner ask.
- INTERFACES D2.3: input `FILE_SET` (comma list of repo-relative paths); "a change outside `FILE_SET` is `ISSUES_FOUND`". Transport: UPPER_SNAKE `NAME=value` (D2.3 note, row R4-J22).
- Why (part-03 §4 rule 8c, M18): one fixer per worktree at a time, or one worktree per fixer with disjoint file sets computed from the findings; `fix-verifier` `file_set` is per fixer. The check stops a fixer from widening a fix beyond its findings.
- Existing skill (`skills/fix-verifier/SKILL.md`, 394 lines): input contract JSON (`changed_files` absolute, `diff`, `fix_description`, `related_files`, `session_context`); 5 checks; finding object `check` enum `"0".."5"`; verdict `CLEAN` only with zero Blocking/Medium; loop iteration rule (iteration 3 appends the check-0 Blocking finding); read-only security rules (never writes, never runs shell, never dispatches agents); path canonicalization and project-root resolution.
- Loop location: D7 (part-01) max 3 rounds; `verify-<seat-id>-<n>.md` records live under `RUN_HOME/review/<subtask>/` (A.6); that record's writer is the caller, not this skill.

## 3. Scope
**In scope (directory `skills/fix-verifier/` only):** `SKILL.md` (frontmatter `version:`, Input Contract row, one added check or a Check 3 extension, Output Contract finding enum, Red flags row, Exit criteria row, Provenance line). If body growth exceeds the 5k-token target, move the new text to `skills/fix-verifier/references/file-set-check.md` (NEW, allowed).
**Out of scope:** the `class_sweep` proposal (dropped; do not add it or any D54/D58 rule); changing the verdict rule, the iteration rule, the timeout rule or the five existing checks' behaviour when `FILE_SET` is absent; any other skill; `architecture/fix-verifier.md`; INTERFACES.
**Do NOT create:** a script, a test harness outside the §9 fixture, a new verdict value (only `CLEAN`/`ISSUES_FOUND`), a new input named differently from `FILE_SET`, or any file outside `skills/fix-verifier/` (the fixture lives under `$TMPDIR` at verification time).

## 4. Contracts
| Contract | Field / value | Authority |
|---|---|---|
| D2.3 `fix-verifier` row | input `FILE_SET`, comma list of repo-relative paths; outside = `ISSUES_FOUND` | `interfaces/part-d-enums-topics.md` D2.3 (line 100) |
| D1 Step 0 | a malformed `FILE_SET` prints `INPUT-ERROR FILE_SET <reason>` (`missing\|enum\|path\|unset\|format`), one line per failing field, then stops with no retry and no prompt; absent `FILE_SET` is valid (today's behaviour) | part-d D1 |
| Existing output contract | `verdict`, `findings[]` with `check`, `severity`, `description`, `file`, `recommended_fix`; `CLEAN` only with zero Blocking/Medium | `skills/fix-verifier/SKILL.md` "Output Contract" |
| A.6 | caller writes `verify-<seat-id>-<n>.md` for round `n` (1..3) | `interfaces/part-a-state.md` A.6 |
| M18 / part-03 rule 8c | `file_set` is per fixer | `part-03-personas-and-concurrency.md` Parallelization rules |

## 5. Inherited Module API
Existing input contract and path-canonicalization rules apply unchanged: `FILE_SET` entries are repo-relative; the verifier resolves each against the computed project root (`.git` > `package.json` > `CLAUDE.md` marker) after the same canonicalization step, then compares with the canonicalized `changed_files`. An entry that escapes the root is rejected as `INPUT-ERROR FILE_SET path`, not silently dropped.

## 6. What You Inherit
| Thing | Source | Notes |
|---|---|---|
| Read-only, no-shell, no-dispatch rule | SKILL.md "Security" | the new check is a set comparison on `changed_files` and `diff` headers; it adds no shell call |
| Finding severities | SKILL.md "Severity Reference" | `ISSUES_FOUND` needs Blocking or Medium; Advisory alone yields `CLEAN` |
| Timeout rule | SKILL.md Output Contract exception | unchanged |

## 7. Known Risky Values
| Value | Correct | Wrong | Source |
|---|---|---|---|
| Severity of an out-of-set change | Blocking or Medium (SPEC-QUESTION Q11-2: card says only "`ISSUES_FOUND`"; Advisory cannot produce it under the verdict rule, so the integrator picks Blocking or Medium and records why) | Advisory | SKILL.md verdict rule |
| `check` id for the new finding | SPEC-QUESTION Q11-3: the enum is `"0".."5"`; either extend Check 3 (Fix Completeness) or add `"6"` and widen the enum; the card does not say | inventing an id silently | SKILL.md finding object |
| Path form | `FILE_SET` repo-relative; `changed_files` absolute | comparing mixed forms | D2.3 vs Input Contract |
| Absent `FILE_SET` | no new finding; behaviour identical to today | treating absence as an empty set (would flag every change) | D2.3 |
| Empty `FILE_SET=` (set, no entries) | `INPUT-ERROR FILE_SET format` | silently the same as absent | D1 |
| Files in `related_files` | not changes; never counted as outside the set | flagged | Input Contract |

## 8. Acceptance Criteria
- [ ] Input Contract documents `FILE_SET` (name, type, optional, repo-relative, per fixer), and Step 0 validates it per D1.
- [ ] With `FILE_SET` set, every `changed_files` entry whose canonical repo-relative path is not in the set yields one finding naming that file, severity per Q11-2, and the verdict is `ISSUES_FOUND`.
- [ ] With every changed file inside the set, the new check adds no finding.
- [ ] With `FILE_SET` absent, output is identical to the unmodified skill for the same input (no regression).
- [ ] A path-traversal entry or an empty list is `INPUT-ERROR`, not a verdict.
- [ ] Red flags row: "the extra file edit was needed for the fix, treat it as inside the set" maps to "report it; the lead widens `FILE_SET` or the fixer reverts"; Exit criteria row added; Provenance line cites M24 and D6 and states `class_sweep` is dropped.
- [ ] `version:` in frontmatter (Q11-4: baseline value and bump rule are not specified; the integrator sets them). Five anatomy sections still present; `SKILL.md` under 500 lines or the overflow moved to `references/`.

## 9. Verification Commands
```bash
cd ~/projects/agent-hq-worktrees/delivery-w0   # on the EXTEND branch
S=skills/fix-verifier
grep -q 'FILE_SET' $S/SKILL.md && grep -q 'INPUT-ERROR FILE_SET' $S/SKILL.md && echo OK-input
grep -n -i 'outside.*FILE_SET\|FILE_SET.*outside' $S/SKILL.md | grep -q . && echo OK-check
grep -q 'class_sweep' $S/SKILL.md && grep -n 'class_sweep' $S/SKILL.md   # allowed only in the Provenance "dropped" sentence
# fixture (verifier builds it under $TMPDIR; dispatch one fix-verifier on each case and compare):
#   case A FILE_SET=a.md, changed_files={a.md,b.md}  -> ISSUES_FOUND naming b.md
#   case B FILE_SET=a.md,b.md, same changes          -> no finding from the new check
#   case C FILE_SET unset                             -> output identical to the installed skill on the same input
#   case D FILE_SET=../x                              -> INPUT-ERROR FILE_SET path, no verdict
echo OK-fixture    # printed by the verifier only after A-D match
git diff -- $S | grep -E '^-[^-]' | grep -v -E 'version|description' | wc -l   # removed lines other than frontmatter: expected 0 or only reworded Input Contract rows; list and justify
echo OK-noregress  # printed by the verifier only after case C matches and no existing check text was removed
for h in '## Trigger' '## Steps' '## Red flags' '## Exit criteria' '## Provenance'; do grep -q "^$h" $S/SKILL.md || echo MISSING $h; done
head -12 $S/SKILL.md | grep -E '^version:'
grep -rn -E '/Users/xavier|brainAlpha|brainBeta|brainGamma|hermesAuth|Xavier|touri|ofw|runfrist|jetblue|Notion' $S   # nothing
bash tools/check-doc-length.sh . ; git diff --stat -- . ':!skills/fix-verifier'   # second: empty
```
The two `echo OK-*` lines are gates the verifier prints only after it ran the fixture and diff review by hand; they are not self-satisfying (the verifier is never the author, M-rules).

## 10. Branch and worktree
Separate EXTEND branch (Q11-1); no add, commit, rebase or push by the author (build-common).

## 11. Decision Gate Reminder
Write `.decisions/11-fix-verifier.md` and stop if: the severity (Q11-2) or the check id (Q11-3) cannot be chosen from the existing enums without widening one; `class_sweep` or a D54/D58 rule seems needed; the verifier would have to run a shell command; the unmodified behaviour changes with `FILE_SET` absent.
