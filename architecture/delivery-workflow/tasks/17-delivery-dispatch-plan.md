# Task Spec: T17 `delivery-dispatch-plan` (W1 item 17, stage 3)

> Written 2026-10-26 (W0 item 2b) from design card 5 (`part-02-skill-inventory.md` §2.2), `part-06` §7 row 14-22, INTERFACES `1.1.0` (FROZEN, amendment AM-1 landed: port guard A.5.2, `security_audit` A.2/A.5.3), ADR 0054, ADR 0055, `tools/skill-authoring.md` §2-§5.
> Author: one execute-tier agent, about 1 h. Not split, so no integration step. Reviewer path: Rung 1 trio (`doc-reviewer`, separate fixer, `fix-verifier`), at most 3 rounds, then the owner (D7).

**Done condition (one, machine-checkable):** the command block in section 9 exits 0 and its last stdout line is `SKILL-17-OK`.
**Tier:** execute (design §7 row 14-22). **Rung:** 1 (SKILL.md prose; the plans the skill later writes use 2b above 10 units, else 1, card 5, §2.4).
**Depends on:** INTERFACES 1.1.0 (done); item 9 (`wave-execution` EXTEND, for `references/spec-format.md` field names); item 16 (`review-tailor`, called by name only); item 27 (template pack writes `references/templates/` of this skill); item 27b is NOT needed (briefs root is `skills/delivery-run/references/briefs/`, INTERFACES C1.2 `persona` row). No dependency on item 18 or 19.

## 1. Objective
Write the skill `delivery-dispatch-plan`: it turns an accepted `architecture.md` plus drafts and the repo profile into an executable dispatch plan (sub-tasks, units, DAG, lanes, shared-file owners, slot plan, verification), dispatches the Plan-checker and loops to `PLAN-CHECK: clean` or round 3.

## 2. Context package
- Card 5: Trigger "Use when an accepted architecture must become an executable dispatch plan: sub-tasks, units, DAG, lanes, shared-file owners, slot plan, verification." In: `architecture.md`, drafts, `repo-profile.md`. Out: `dispatch-plan.md`, `.tasks/<unit>-<slug>.md`, `substate.seed.md` per sub-task, `waves/` per sub-task, parallelism note (Rule 7, computed). Stop: unit without verifier; overlapping scopes.
- Template shapes: `part-04-templates.md` §5.3 (dispatch-plan), §5.3b (11-section unit task spec, six pre-flight checks), §5.8 (`FILL_IN_BEFORE_DISPATCH` sentinels).
- Parallelization rules: `part-03-personas-and-concurrency.md` §4 (rules 1-8d, shared-file owners M16, 30 per sub-task, 200 per machine, rule 8 at most 3 builds).
- Anatomy: `tools/skill-authoring.md` §2-§5. Owner deviation to record: no `disable-model-invocation` (D16). Frontmatter carries `version:` (A6).

## 3. Scope
**In (write only these paths under `skills/delivery-dispatch-plan/`):**
- `SKILL.md` (body under 5k tokens, under 500 lines): frontmatter (`name`, "Use when" `description` of 1024 characters or fewer, `version: 0.1.0`), `## Trigger`, `## Steps` (Step 0 first), `## Red flags`, `## Exit criteria`, `## Provenance`.
- `references/unit-and-waves.md` (unit table to `waves/` mapping by pointer to INTERFACES C1.2, wave file set, bundle fields, seed keys).
- `references/shared-files-and-parallelism.md` (shared-file owner and serial-lane table, Rule 7 note, slot and dispatch arithmetic).
- `references/predispatch-checklist.md` (sentinels, `ls`-verified paths, flags, six unit pre-flight checks).
- `references/plan-check-loop.md` (Plan-checker invocation, G48 pre-round check, round cap).

**Out:** `references/templates/**` (item 27 owns them; SPEC-QUESTION 2), `skills/delivery-run/**` (briefs, persona list), `tools/**`, INTERFACES, any other skill, any ADR.
**Do NOT create:** a script, a symlink, a second copy of any INTERFACES table, a persona brief, a `catalog.tsv` writer (only `catalog.sh` appends), cost or effort metrics (B-4), a `disable-model-invocation` field.

## 4. Contracts (cite the anchor, never restate the table)
| Contract | Field / value the skill must honour | Authority |
|---|---|---|
| Step 0 inputs | `RUN_HOME`, `PLANS_DIR`, `REPO_PROFILE` (@sha), optional `NEW_UNITS`; reads `RUN_HOME/tickets.tsv`; `INPUT-ERROR <NAME> <reason>`, one line per field, then stop; `DELIVERY_ROOT` unset is `INPUT-ERROR DELIVERY_ROOT unset` | `part-d-enums-topics.md` D1, D2.2 row 5; `part-a-state.md` A.1 |
| Output token | `PLAN-CHECK: clean` or `PLAN-CHECK: <n> findings`, line 1 of `RUN_HOME/plan-check.md`, written by the Plan-checker | D1.1; C1.3 |
| Artifact paths | `dispatch-plan.md`, `subtasks/<subtask>/substate.seed.md`, `subtasks/<subtask>/waves/` under `PLANS_DIR`; `.tasks/<unit>-<slug>.md` at the primary repo root; empty `RUN_HOME/catalog.tsv`; `plan-check.md` in RUN | A.6, D6 |
| Dispatch-plan header | `interfaces_version: <version>@<sha256>` copied from `state.md`; sub-task table columns `ticket`, `branch` (`<key>-<slug>`), `repo`; unit table `ticket` filled from `tickets.tsv` (latest `key`, else draft slug); the conductor never edits the unit table | A.6 additions (R4-J17, R4-J23); D3 |
| Seed | one YAML document, exactly keys `subtask_id session_id reserved frontier interfaces_version phase: seeded` | A.3 |
| Waves | one DAG wave `01-build.md` per sub-task (plus `00-constitution.md` only when the repo has no profile, plus `02-integrate.md`); `depends_on` edges same-wave only; per work_item `persona`, `lane`, `done_condition` `{token, command}`, `Brief:` line naming `skills/delivery-run/references/briefs/<persona>.md`; bundle `session_id`, `output_topic`, `bus_endpoint`, `dispatch_budget` (rule 11); `max_concurrent` is NOT a spec field | C1, C1.1, C1.2; ADR 0054 A0-A8 |
| Preflight | rules 13-15; rule 9 requires `done_condition` on every `step_complete` work_item | C1.3 |
| Plan-checker | dispatched by this skill after `waves/` is written, persona `plan-checker`, inputs `PLANS_DIR`, `RUN_HOME`; fresh checker per round; stop at `clean` or round 3 (D7) | C1.3 (R3 H24) |
| Scope globs | live in `.tasks/<unit>-<slug>.md` heading `## 3`, one `- <glob>` per line, git `:(glob)` dialect | C1.2 scope row |
| Port guard | every port a lane or dev server binds is claimed per A.5.2 before launch, never auto-picked; a lane that cannot claim maps to C2 reason `lane-unavailable`; the plan's lane table therefore records port needs, not promises | A.5.2; C1.1 lane lease row; D4 namespacing |
| Security audit | `architecture.md` header line `security_sensitive: yes` makes the conductor set `security_audit: full`; full-mode `security-auditor` agents take free slots under the 30 cap and are counted in the slot ledger (budget = free slots at launch); the audit runs in `pre-pr-gate`, output `RUN_HOME/<subtask>/security-audit/run-<N>/`, `validate-findings.cjs` is a `pre-pr-gate` gate row; it is not a unit of this plan | A.2 `security_audit`; A.4 security-audit agents; A.5.3; D2.1 |
| Token shapes | sha 40-hex; unit `^u[0-9]+$`; sub-task `^(st[0-9]+\|pm)$`; `st0` is the plan PR; persona from the closed set | A.1; D2.1 |

## 5. Inherited module API
- `review-tailor` (item 16): called with `RUN_HOME`, `SLUG`, `ARTIFACTS`, `KIND=plan`, `STAKES`, `CONTENTION`, `NOVELTY`; returns `RUNG:` and a seat table (D2.2 row 4). Do not restate its rules.
- `writing-plans` (REUSE): per-unit task files; the skill points to it, adds the 11-section layout by reference to `part-04` §5.3b.
- `pr-review`/`doc-reviewer`/`review-7-panel`: Rung 2b above 10 units, else 1 (card 5). Name the rung, never inline the mechanism.
- Persona and Plan-checker brief: `skills/delivery-run/references/briefs/plan-checker.md` (written by item 27b; cite by path only).

## 6. What you inherit
| Thing | Source | Note |
|---|---|---|
| Worktree | `~/projects/agent-hq-worktrees/delivery-w0`, branch `wt/delivery-w0` | write only your paths; others write beside you (Rule 7) |
| Standards | `STANDARDS.md`, `tools/skill-authoring.md`, `tools/skill-porting.md`, `tools/check-doc-length.sh` | |
| SUB rules | `/Users/xavier` to `$HOME`; "Xavier" to "the owner"; no personal-project text; Notion removed | build-common |
| HUSKY statement | single home is `part-a-state.md` A.7 | link it, never restate |

## 7. Known risky values
| Value | Correct | Wrong | Source |
|---|---|---|---|
| Task file name | `.tasks/<unit>-<slug>.md` | `.tasks/NN-slug.md` (card 5 shorthand) | A.6, R3 H10 |
| Waves layout | one DAG wave `01-build.md` | numbered "lane-waves 1..N" files | C1, E12 |
| `max_concurrent` | caller argument of `delivery-run` | a field in the spec | C1.1, E12 |
| `depends_on` scope | same wave only | cross-wave edges | C1.3 rule 15, E13 |
| Done condition field | `done_condition` `{token, command}` | `done_token`, free text | C1.2 |
| Briefs root | `skills/delivery-run/references/briefs/` | a briefs dir inside this skill | C1.2 persona row |
| Stage 3 gate | none (Rule 11), human informed | an H gate | `part-01` §1 stage 3 |
| Counts | 30 per sub-task, 200 per machine, rule 8 at most 3 builds | other numbers | `part-03` §4 |

## 8. Acceptance criteria
- [ ] SKILL.md has the five required sections, Step 0 with the four named inputs and `INPUT-ERROR`, and every card-5 step: cut sub-tasks (one PR each, D5, merge order from `architecture.md`; `st0` = plan PR), units with one done condition each, scope globs, shared-file owner and serial-lane table (overlap or implicit touch rejects the plan, M16), blockers, personas and tiers, e2e units per user-visible story, per-lane resource profile, worst-case dispatch count against 30 and the machine ledger against 200 (D4), computed Rule 7 note, Plan-checker before round 1 (D55), pre-dispatch checklist, `review-tailor`, loop (D7 cap).
- [ ] Post-merge re-entry path: `NEW_UNITS` adds units for `st<N>` and produces the stage-3 outputs for it only (A.2 post-merge re-entry).
- [ ] AM-1 is reflected where this skill touches it: (a) port guard: the lane resource profile records port needs, states that each port is claimed per A.5.2 before launch (never auto-picked, collision = `lane-unavailable`) and that no plan value is promised free; (b) `security-audit`: the plan reads `security_sensitive:` from `architecture.md`, notes in the slot plan that full-mode `security-auditor` agents draw on free slots and count in the ledger, and names the `pre-pr-gate` `validate-findings.cjs` gate row; the audit is not a plan unit. Wording stays at what AM-1 fixes.
- [ ] Stop rows stated: unit without verifier; overlapping scopes; unmeasured claim contradicted (re-measure first).
- [ ] No cost or effort metric; no personal-project or `/Users/xavier` text.
- [ ] Provenance line cites card 5 friction (efficiency-study PLAN row, Rule 7 overcount retro, D55 plan-check, P6 and `brain-run3` retro paths that did not exist) as listed in `part-06` §7b stage 3.

## 9. Verification commands (the verifier re-runs exactly these)
```bash
set -eu; W=~/projects/agent-hq-worktrees/delivery-w0; S=$W/skills/delivery-dispatch-plan; F=$S/SKILL.md
test -f "$F"; head -1 "$F" | grep -qx -- '---'
grep -qE '^name: delivery-dispatch-plan$' "$F"; grep -qE '^version: ' "$F"
d=$(grep -E '^description:' "$F"); [ "${#d}" -le 1040 ]; printf '%s' "$d" | grep -q 'Use when'
if grep -q 'disable-model-invocation' "$F"; then echo "FAIL: forbidden match"; exit 1; fi
for h in Trigger Steps 'Red flags' 'Exit criteria' Provenance; do grep -qE "^## $h" "$F"; done
[ "$(wc -c < "$F")" -le 20000 ]; [ "$(wc -l < "$F")" -le 500 ]
for t in RUN_HOME PLANS_DIR REPO_PROFILE NEW_UNITS INPUT-ERROR 'PLAN-CHECK:' interfaces_version FILL_IN_BEFORE_DISPATCH \
  01-build.md 02-integrate.md done_condition depends_on 'Brief:' tickets.tsv plan-check.md review-tailor security_sensitive 'A.5.2' lane-unavailable security-auditor; do
  grep -rqF -- "$t" "$S" || { echo "missing: $t"; exit 1; }; done
! grep -rn 'max_concurrent' "$S" | grep -viE 'not a (spec )?field|caller|argument' || { echo "max_concurrent misuse"; exit 1; }
if grep -rniE 'notion|touri|ofw|runfrist|jetblue|/Users/xavier|brain(Alpha|Beta|Gamma)|hermesAuth|cost|tokens? budget' "$S"; then echo "FAIL: forbidden match"; exit 1; fi
find "$S" -type l | grep -q . && { echo symlink; exit 1; }
for f in $(find "$S" -name '*.md'); do [ "$(wc -l < "$f")" -le 500 ] || { echo "over 500: $f"; exit 1; }; done
bash "$W/tools/check-doc-length.sh" "$W" >/dev/null
echo SKILL-17-OK
```
Also by the reviewer (not scripted): every INTERFACES anchor cited in the skill resolves (item 33 resolver re-runs it).

## 10. Branch and worktree
Write in `~/projects/agent-hq-worktrees/delivery-w0` (branch `wt/delivery-w0`). No `git add`, commit, branch or push; the integrator (Worker1) commits. No symlinks, no installs, no web.

## 11. Decision Gate reminder
Stop and write `.decisions/T17.md` (or report `STUCK`) if: INTERFACES and the card disagree on a name or path and the Known-risky-values table does not settle it; a step would need an owner decision (never invent wording for one); the 1.1.0 amendment contradicts section 4; a criterion cannot be checked with the section 9 commands; you must edit outside section 3.

## SPEC-QUESTIONs (for the plan-checker)
1. SPEC-QUESTION: AM-1 lists the `dispatch-plan.md` template as a consumer but fixes no dispatch-plan field for `security_sensitive` or the audit slot note (only the `architecture.md` header line and `state.md` `security_audit`). Where does the plan record it (header line, slot-plan row), and what slot count does it state for the audit agents (A.4 sets the budget at launch from free slots, so possibly none)?
2. SPEC-QUESTION: card 27 says templates live in `references/templates/` of the owning skill, so item 27 writes into this skill's directory. Confirm the two items stay disjoint (this spec excludes `references/templates/`).
3. SPEC-QUESTION: "worst-case dispatch count per sub-task against 30 and the machine ledger against 200" mixes concurrent slots with total spawns (A.3 `spawns` cap is unmeasured). Which quantity does the plan state: `dispatch_budget` (C1.1 rule 11 sum), peak concurrency, or both?
4. SPEC-QUESTION: card 5 lists per-lane port resources (HTTP, HMR, devtools) and A.5.2 claims a specific number. Who chooses the number: the plan (as a proposal the claim may refuse), the profile's lane resource profile, or the lane launcher? This spec records needs only.
