# Task 16: `review-tailor` (NEW skill, stages 2, 3, 4b)

- **Header:** item 16 (part-06 §7); wave W1; authoring tier `execute` (§7 row 14-22); runtime tier `verify`, `design` on one-way doors (card 4; persona Review tailor, part-03 line 36); review rung: Rung 1 trio (reviewer, fixer, fix-verifier; item 30); not heavy. Interfaces: `INTERFACES.md` + `interfaces/part-a..d` (FROZEN, INTERFACES 1.5.0) and amendment AM-1 (INTERFACES 1.1.0: `SECURITY_AUDIT` input, D2.2 row 4); AM-3 errata (g) `ORCHESTRATOR_TIER`; AM-4 16 (RT-Q1, RT-Q2 in D1.1 `RUNG:`).
- **Dependencies:** INTERFACES frozen; reads `tools/review-ladder.md`; seat pool from part-03 §3.4-3.5; consumers (called by name, no file dependency): `delivery-architecture` (task 15), `delivery-dispatch-plan` (item 17), `pre-pr-gate` (item 20) and the `pr-review` EXTEND (`ROLES`, part D2.3). `security-audit` (`skills/security-audit`) is referenced, not edited.
- **Split:** none (1 agent).

## 1. Objective
Write `skills/review-tailor/SKILL.md` (card 4, part-02 §2.2): given artifacts, kind, stakes, contention and novelty, choose the lowest rung that covers the risk and the seats, and write one record file. **Done condition (single, machine-checkable):** with the fixture records saved by a non-author reader (section 9), the section 9 block exits 0 and its last stdout line is `SKILL-16-OK`. Smaller seat sets for code stay off until the D12 conditions are met (section 7, item 1).

## 2. Context package
- Card 4 (part-02 line 56); persona row (part-03 line 36); seat pool §3.4 and domain lenses §3.5 (part-03); review table (part-02 §2.4); G48 and the quality rules (part-03 line 94); D12 in `owner-decisions.md` (line 9: smaller seat sets allowed only after (a) a RACI remap moving every dropped role's checks to a kept role and (b) a 3-seat probe showing no lost checks; until then full 7).
- `tools/review-ladder.md` §1 (rungs 0-4), §2 (rubric: size, stakes, contention, novelty), §3 (+1 rung when no design-tier orchestrator exists), §4 (escalation triggers and the "tank at a water-gun fight" red flags).
- `skills/review-7-panel/SKILL.md` (seat counts, record naming, pre-round check) and the seven `pr-review` agent ids (`skills/pr-review/SKILL.md`, Step 4).
- Anatomy and sizing: `tools/skill-authoring.md` §2-§5; deviations as in task 14 (D16 model-invocable, `version:`, Step 0). Friction for Provenance: ladder failure mode "tank at a water-gun fight"; G14 under-selection on contested designs (card 4).

## 3. Scope
- **In (directory `W/skills/review-tailor/`, nothing else):** `SKILL.md`; `references/step0-inputs.md`; `references/seat-catalog.md` (every seat from §3.4-3.5: id, lens, "finds what the others cannot", tier, risk surface that adds it; derived from part-03, no new seats); `references/rung-rules.md` (rubric, +1 modifier, caps, escalation, D57 trigger, G46 queueing, G48 pre-round); `references/d12-gate.md` (the two D12 conditions and the check that keeps code at 7); `references/fixtures/` (four input cases and their expected record first lines).
- **Out:** edits to `tools/review-ladder.md`, `review-7-panel`, `pr-review` or INTERFACES; the D12 remap and probe themselves (P0, after the move); templates (item 27); commits.
- **Do-not-create:** symlinks, installs, web fetches, scripts, a flag or env var that lowers the code-diff seat count, cost metrics.

## 4. Contracts table (cite anchors; do not restate)
| Contract | Anchor | Role |
|---|---|---|
| Inputs `RUN_HOME`, `SLUG`, `ARTIFACTS` (comma-separated paths), `KIND`, `STAKES`, `CONTENTION`, `NOVELTY`, `SECURITY_AUDIT`, `ORCHESTRATOR_TIER` (from `state.md` `orchestrator_tier`, A.2; the +1 rung modifier applies when it is not `design`; E31, AM-3 errata (g)) as `NAME=value`; `DELIVERY_ROOT` env | part D2.2 row 4; D1 | Step 0; `INPUT-ERROR <NAME> <reason>` per failing field, then stop |
| Enums `SECURITY_AUDIT` `guidance\|full` (D2.1; required, RESOLVED Q2); `KIND` `doc\|plan\|diff`; `STAKES` `reversible\|one-way`; `CONTENTION` `none\|contested`; `NOVELTY` `known\|novel`; `rung` `0\|1\|2\|2b\|3\|4` | part D2.1 | validate; bad value is `INPUT-ERROR <NAME> enum` |
| `SLUG` form `<subtask\|run>-<kind>-<n>`, minted by the caller | part A.1 `<slug>`; D2.2 row 4 | validate with `format`; never mint |
| Output file `RUN_HOME/review-tailor-<SLUG>.md`: line 1 `RUNG: <rung> seats: <n>`, lines 2+ seat table `seat-id<TAB>role<TAB>reason`; written by this skill itself | part D1.1 (`^RUNG: (0\|1\|2\|2b\|3\|4) seats: [0-9]+$`); A.6 | sole writer, atomic (A.1); `pr-review` `ROLES` derives from the seat ids |
| `seat-id` shape `^[a-z0-9-]+$`; persona tokens `review-tailor`, `review-seat` | part A.1 token shapes; D2.1 `persona` | use as written |
| Rung selection | `tools/review-ladder.md` §2-§4; part-02 §2.4 table | lowest rung covering the risk; +1 when no design-tier orchestrator exists |
| Slot ledger / bus caps | part-06 §7 item 31 (12 slots per bus, 50 cap); build-common | the table states the dispatch count; no cost figures |
| Security seat mode; security-audit | AM-1; part D2.1 `security_audit`, D2.2 row 4 ("the seat table names the security seat's mode"), A.5.3 | item 6 of section 8 |
| Port guard | part A.5.2 (AM-1) | none consumed; this skill binds no port; the per-review bus port is claimed by its launcher |

## 5. Inherited module API
Callers pass the inputs and read line 1 plus the seat table. The mechanism it names is then run by the caller: Rung 1 `doc-reviewer`, Rung 2 `panel-consultation`, Rung 2b `review-7-panel`, Rung 3 `pr-review`, Rung 4 `panel-review`. This skill dispatches no reviewer itself.

## 6. What you inherit
- Rules from card 4: ladder rubric plus +1 modifier; seats from §3.4-3.5 by risk surface present; justify each omitted default seat; per-repo review profile adds mandatory seats; never exceed 7 at Rung 2b or 9 at Rung 2.
- Every plan it writes starts with the G48 pre-round check (part-03 line 94) and states the D57 freeze trigger (two consecutive rounds with no change to the core sections).
- A finding that arrives mid-round is queued for the next round start or a separate pass, never injected into a running round (G46, `RLM:99`).

## 7. Known risky values
1. **D12 is off.** For `KIND=diff` the record always has `seats: 7` and the seven seat ids of `pr-review` Step 4, whatever the risk surface. The skill contains no branch that yields fewer. Turning it on needs the remap and the 3-seat probe recorded in `INTERFACES.md` (D12, part D2.3 `pr-review` row "seat count 7 until the D12 remap and probe are recorded here"); that is an INTERFACES amendment with consumer re-check (M21), not an edit of this skill alone.
2. Caps: at most 7 seats at Rung 2b, at most 9 at Rung 2. `RUNG:` seat count equals the number of seat rows.
3. Rung values are exactly the D1.1 set; `2b` is lowercase b.
4. The G48 pre-round check is a mechanical-tier (Haiku) agent step, a rule, not advisory (G48 adopted by owner rule B-3, `architecture/delivery-workflow-sources/owner-decisions.md:50`; integrator note, `reviews/16-review-tailor-rung1.md` "Integrator notes").
5. Advisory-only rules (D44, D54, D58, D61, D66) are not written as rules (D6).
6. Fixed-count rungs (amended: AM-4 16, D1.1 `RUNG:`; E31): a profile-mandatory seat outside a fixed-count rung's seat set is noted in the `mechanism:` line and the seat set stays fixed (D12, RT-Q1); a high-blast-radius code diff stays at Rung 3 and the one-way decision behind it is reviewed separately as `KIND=plan` at Rung 4 (RT-Q2).
7. A `review-7-panel` round is 10 dispatches (7 seats, synthesizer, fixer, fix-verifier), not 9 (E31); the `dispatch:` line counts 10.

## 8. Acceptance criteria
1. Frontmatter: `name: review-tailor`, `version: 0.1.0`, description under 1024 chars starting from the card trigger and containing "Use when"; states its place on the ladder per `tools/review-ladder.md` §5 (it chooses a rung, it is not one); model-invocable.
2. Sections `## Trigger`, `## Steps` (numbered, Step 0 first), `## Red flags`, `## Exit criteria`, `## Provenance`; body under 5k tokens and 500 lines.
3. Steps in order: Step 0; read the artifacts' size and risk surface; apply the rubric and +1 modifier; pick the lowest rung; select seats from `references/seat-catalog.md` by risk surface; justify each omitted default seat; apply caps and the D12 rule; write the record file; end with the dispatch count against the ledger.
4. Red flags include: "high stakes" without a nameable risk; starting high to be safe; fewer than 7 seats on a code diff; a seat added with no "finds what the others cannot"; injecting a mid-round finding; reusing last time's rung.
5. Exit criteria include: line 1 matches the D1.1 regex; seat count equals row count; every omitted default seat has a stated reason; the plan names G48 and D57.
6. Security (AM-1): the Security seat row in the seat table names its mode, the `SECURITY_AUDIT` value (`guidance`: diff-scoped, no files, no agents). Under `full` the plan adds a line for the full-mode run: output `RUN_HOME/<subtask>/security-audit/run-<N>/` (A.5.3), its agents (persona `security-auditor`) counted in the dispatch count against the ledger, and `validate-findings.cjs` as a `pre-pr-gate` row. This skill never chooses `full`; it only echoes the input.
7. Per-repo review profile: mandatory seats and Blocking rules are read from the profile keys A.2.2 `review_profile.mandatory_seats[]` and `review_profile.blocking_rules[]` (RESOLVED Q3, AM-2 row 5).
8. No cost figures; no web.

## 9. Verification commands (W = `~/projects/agent-hq-worktrees/delivery-w0`)
```bash
set -eu; W=~/projects/agent-hq-worktrees/delivery-w0; S=$W/skills/review-tailor; R=${FIXTURE_DIR:?the non-author verifier sets FIXTURE_DIR to its dry-run output directory}
test "$(grep -c '^## \(Trigger\|Steps\|Red flags\|Exit criteria\|Provenance\)$' $S/SKILL.md)" -eq 5
grep -q '^version: 0\.1\.0$' $S/SKILL.md
if grep -q 'disable-model-invocation' $S/SKILL.md; then echo "FAIL: disable-model-invocation"; exit 1; fi
sed -n '/^description:/p' $S/SKILL.md | grep -q 'Use when'
[ "$(wc -w < $S/SKILL.md)" -le 3500 ]; [ "$(wc -l < $S/SKILL.md)" -le 500 ]
for t in 'RUNG:' 'D12' 'G48' 'D57' 'INPUT-ERROR' 'security-audit' 'finds what' 'mechanism:' 'dispatch:'; do grep -rq -- "$t" $S || { echo "FAIL missing $t"; exit 1; }; done
if grep -rEi --exclude-dir=templates '/Users/[a-z]+|touri|ofw|runfrist|jetblue|notion|\$[0-9]+|cost' $S; then echo "FAIL: forbidden match"; exit 1; fi
if find $S -type l | grep -q .; then echo symlink; exit 1; fi
bash $W/tools/check-doc-length.sh $W >/dev/null
# fixture: a reader follows SKILL.md on the four cases below and saves each record as $R/case<k>.md and the bad-enum output as $R/case4-bad.out
head -1 $R/case1.md | grep -qx 'RUNG: 3 seats: 7'
head -1 $R/case2.md | grep -qx 'RUNG: 1 seats: 1'
head -1 $R/case3.md | grep -qE '^RUNG: 2b seats: [1-7]$'
head -1 $R/case4.md | grep -qE '^RUNG: 4 seats: [0-9]+$'
grep -qx 'INPUT-ERROR STAKES enum' $R/case4-bad.out
for k in 1 2 3 4; do f=$R/case$k.md; n=$(head -1 $f | sed -E 's/.*seats: //'); r=$(awk 'NR>1 && /^$/ {exit} NR>1' $f | grep -c . || true); [ "$n" = "$r" ] || { echo "seat count $f"; exit 1; }; done
echo SKILL-16-OK
```
Fixture cases in `references/fixtures/` (a reader agent follows the SKILL.md, no dispatch) and the expected record first line:
1. `KIND=diff`, any risk surface, small diff: `RUNG: 3 seats: 7` (D12 off).
2. `KIND=doc`, `STAKES=reversible`, `CONTENTION=none`, `NOVELTY=known`, one small file: `RUNG: 1 seats: 1` (RESOLVED Q1).
3. `KIND=doc`, epic architecture, `STAKES=reversible`: `RUNG: 2b seats: <n>` with n at most 7 and every omitted default seat justified.
4. `KIND=doc`, `STAKES=one-way`: `RUNG: 4 ...`; and `STAKES=maybe` gives exactly `INPUT-ERROR STAKES enum`.
Every first line matches `^RUNG: (0|1|2|2b|3|4) seats: [0-9]+$` and the number of seat rows equals `seats`.

## 10. Branch and worktree
Worktree W, branch `wt/delivery-w0`; write only section 3 paths; no git add, commit, branch, push or rebase. No symlinks, installs or web.

## 11. Decision Gate reminder
Write `.decisions/16-review-tailor.md` (fork, options, recommendation, `Outcome: Blocked`) instead of choosing when a value is open, when a fix needs an INTERFACES change, or when anything would lower the code-diff seat count below 7. Owner rulings (D12) are quoted, never reworded.

## Open points
- RESOLVED Q1 (PLAN-CHECK DEFAULT; AM-2 row 9): seat counts per rung: Rung 0 `seats: 0` (no rows), Rung 1 `seats: 1` (the one reviewer), Rung 2 the simulated members (at most 9), Rung 2b at most 7, Rung 3 exactly 7 (D12), Rung 4 the `panel-review` roster (11).
- RESOLVED Q2 (PLAN-CHECK DEFAULT, AM-2 row 9; INTERFACES D2.2 transport "every caller passes them"): the seat table is lines 2 up to the first blank line (`seat-id<TAB>role<TAB>reason`, the D1.1 form `pr-review` `ROLES` derives from); after the blank line come four `key: value` lines `mechanism:`, `tiers:`, `budget:`, `dispatch:` (the card 4 items). `SECURITY_AUDIT` is required like every NEW-skill input (`INPUT-ERROR SECURITY_AUDIT missing`); callers pass `state.md` `security_audit`.
- RESOLVED Q3 (PLAN-CHECK DEFAULT; AM-2 row 5 added the keys to INTERFACES A.2.2, `interfaces/part-a-state.md` A.2.2 `review_profile.*` row): read the profile keys `review_profile.mandatory_seats[]` and `review_profile.blocking_rules[]`; absent keys mean no mandatory seats, not an `INPUT-ERROR` (A.2.2 "absent = none").
- RESOLVED Q4 (INTERFACES D2.3 `pr-review` `ROLES` = seat ids; D1.1): `KIND=diff` uses the seven `pr-review` agent ids; `doc` and `plan` use the §3.4-3.5 lens seats.
- RESOLVED Q5 (INTERFACES D2.3 `pr-review` row "seat count 7 until the D12 remap and probe are recorded here"): no runtime detection; the skill is fixed at 7 for code and the switch is a later INTERFACES amendment with a skill change.
