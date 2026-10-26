---
name: review-tailor
version: 0.1.0
description: Use when an artifact (doc, plan or code diff) needs review and the rung and seats are not yet chosen, before invoking a review skill. Writes one record file whose line 1 is `RUNG: {rung} seats: {n}`, then a seat table; dispatches nothing. Ladder place (tools/review-ladder.md §5): not a rung itself; it chooses one, always the lowest that covers a nameable risk: Rung 0 direct review, 1 doc-reviewer, 2 panel-consultation, 2b review-7-panel, 3 pr-review (code diffs), 4 panel-review (one-way doors). After it writes the record, invoke the chosen rung's skill; for a typo-level edit, review directly (Rung 0) without it.
---

## Trigger
Use when an artifact needs review and the rung and seats are not yet chosen: delivery stage 2
(architecture and ticket drafts), stage 3 (dispatch plan), stage 4b (pre-PR diff review).
Callers: `delivery-architecture`, `delivery-dispatch-plan`, `pre-pr-gate`. Consumers of the
record: those callers and the `pr-review` `ROLES` derivation (INTERFACES D2.3). Not for running
the review: this skill selects, the caller dispatches.

## Steps
0. **Step 0, validate inputs** (`references/step0-inputs.md`). Inputs are `NAME=value`;
   `DELIVERY_ROOT` is env. Check in the order listed there; print one
   `INPUT-ERROR <NAME> <reason>` line per failing field (reason `missing|enum|path|unset|format`),
   then stop: no retry, no prompt, no record file. All valid: continue.
1. **Read size and risk surface.** Open every path in `ARTIFACTS`. Classify size S (one
   artifact, fits one context, roughly 500 lines or fewer), M (2 to 4 artifacts, or one
   large) or L (epic scale or a multi-document system). List the risk surfaces present
   (security, concurrency, API/contract, data/migration, UI, release, IaC, supply chain,
   docs). Name each as a concrete risk; "high stakes" with no nameable risk is dropped.
   Also classify, from reading the artifacts, whether the change is a mechanical edit with no
   design content (the Rung 0 row); no input carries this.
2. **Apply the rubric** (`references/rung-rules.md` §1) to `KIND`, size, `STAKES`,
   `CONTENTION`, `NOVELTY`. `KIND=diff` is Rung 3 always (task spec 16 §7.1, D12).
3. **Apply the +1 modifier** (`references/rung-rules.md` §2): when `ORCHESTRATOR_TIER` is not
   `design`, move one rung up (INTERFACES D2.2 row 4, part A.2 `orchestrator_tier`, AM-3
   errata (g)), except `KIND=diff` (stays 3) and Rung 4 (top). Rung 0 moves to 1, so a Rung 0
   record always says `modifier: none`. `design`: no shift.
4. **Pick the lowest rung** that covers the named risks. Write down, in one line each, the
   rubric inputs that decided it. Escalation triggers (`rung-rules.md` §4) are for the
   caller mid-review; never start high to be safe.
5. **Select seats** from `references/seat-catalog.md` by risk surface present (task spec 16
   §6). `KIND=diff`: the seven `pr-review` ids, nothing else. `doc`/`plan`: lens seats (2b),
   panel members (2), the one reviewer (1), the 11-seat roster (4), no seats (0). At 2b,
   fill in this order up to the cap (`seat-catalog.md` §A, selection rule): profile-mandatory
   seats (`rung-rules.md` §5), defaults whose surface is present, then surface seats; a
   surface seat displaces defaults in the order that section gives. At 2, profile-mandatory
   seats first, then members by the `seat-catalog.md` §C rule. Each row's `reason` is its
   "finds what the others cannot".
6. **Justify each omitted default seat** in one line, listed in the `tiers:` line's tail after
   `omitted:` as `id=reason`: either its surface is absent, or `displaced by <seat>` when the
   cap forced it out. At Rung 2 the same tail lists each member not selected. Rungs 0, 1, 3
   and 4 have fixed sets and write `omitted: none` (`rung-rules.md` §6). A seat with no
   "finds what the others cannot" is not added.
7. **Apply caps and the D12 rule** (`references/d12-gate.md`): at most 7 seats at Rung 2b, 3 to
   9 at Rung 2, exactly 7 at Rung 3, the 11-seat roster at Rung 4, 1 at Rung 1, 0 at Rung 0.
   There is no branch, flag or env var that yields fewer than 7 for a code diff.
   Security row (id `security` or `security-engineer`, at every rung where one appears,
   Rung 4 included): its `reason` ends `mode=<SECURITY_AUDIT value>`. For `KIND=diff` the
   `guidance` mode is diff-scoped (`skills/security-audit` loaded by the seat), no files, no
   agents; for `doc`/`plan` the row carries the mode and its lens text only. Under `full`
   add the full-mode run line to `dispatch:` (`rung-rules.md` §6). This skill never chooses
   `full`; it echoes the input.
8. **Write the record** `RUN_HOME/review-tailor-<SLUG>.md` atomically (temp file in
   `RUN_HOME`, then `mv`): line 1 `RUNG: <rung> seats: <n>` (regex
   `^RUNG: (0|1|2|2b|3|4) seats: [0-9]+$`), lines 2+ one row per seat
   `seat-id<TAB>role<TAB>reason` (`seat-id` matches `^[a-z0-9-]+$`), a blank line, then four
   lines `mechanism:`, `tiers:`, `budget:`, `dispatch:`. `n` equals the row count. This skill
   is the sole writer of that file.
   - `mechanism:` the skill the caller runs, the modifier applied (`rung-rules.md` §2), then
     the G48 pre-round check: a mechanical-tier (Haiku) agent checks the artifact against the
     known finding classes before round 1 and after every fix; fixes land before any seat
     reads (part-03 line 94; adopted by owner-decisions.md B-3, line 50). A rule, not advisory.
   - Rung 0 is a direct review, not a loop (ladder §1): G48 and the loop rules (D7, D57, G46)
     do not apply. Its lines say so (`rung-rules.md` §6): `mechanism:` ends
     `G48: not run (direct review, no loop)` and `budget:` names D7, D57 and G46 as not
     applicable.
   - `tiers:` the tier of each role in the run, then `omitted:` (`rung-rules.md` §6).
   - `budget:` D7 quoted (`rung-rules.md` §7), the D57 freeze trigger (two consecutive rounds
     with no change to the core sections), G46 (a finding that arrives mid-round is queued for
     the next round start or a separate pass, never injected), and per-seat wall budgets from
     `rung-rules.md` §6.
   - `dispatch:` agent count against the ledger (`rung-rules.md` §6), `security_audit:` echo.
9. **End with the dispatch count** (task spec 16 §8.3). Skill convention: print the record's
   line 1 and the `dispatch:` line as the last two stdout lines, and stop. Do not dispatch any
   reviewer.

## Red flags
| Rationalization | What to do instead |
|---|---|
| "High stakes" with no nameable risk | Name the risk, or drop a rung. |
| "Start high to be safe" | Lowest rung that covers the risk; escalate on a trigger only (`tools/review-ladder.md` §4). |
| "Small doc, but panel-review to be safe" | Wrong rung: Rung 1 (`doc-reviewer`) covers it (`tools/review-ladder.md` §4). |
| "A small diff only needs 3 seats" | Code diff is 7 seats until the D12 remap and probe are recorded in INTERFACES; no branch below 7. |
| "Add the performance seat, it can't hurt" | A seat with no "finds what the others cannot" is not added. |
| "A finding just arrived, add it to the running round" | G46: queue it for the next round start or a separate pass. |
| "Same rung as last time" | Rungs attach to artifacts, not habits; re-run the rubric. |
| "I will dispatch the seats myself" | This skill writes the record; the caller runs the mechanism. |
| "Caller left SECURITY_AUDIT or ORCHESTRATOR_TIER out, assume a default" | `INPUT-ERROR <NAME> missing`; never default it. |

## Exit criteria
- [ ] Line 1 of the record matches `^RUNG: (0|1|2|2b|3|4) seats: [0-9]+$`.
- [ ] `seats: n` equals the number of seat rows (lines 2 up to the first blank line).
- [ ] `KIND=diff` has `seats: 7` and the seven `pr-review` ids.
- [ ] Rung 2b has at most 7 rows and Rung 2 has 3 to 9.
- [ ] Every omitted default seat (2b) or member (2) has a stated reason; Rungs 0, 1, 3 and 4
      write `omitted: none`; every row has a reason.
- [ ] The `security` or `security-engineer` row (when present) names `mode=<SECURITY_AUDIT>`;
      `full` adds the run line.
- [ ] `mechanism:` names G48 and the modifier; `budget:` names D57, D7 and G46; `dispatch:`
      has the count. At Rung 0 both lines state that G48 and the loop rules do not apply.
- [ ] No web fetch, no dispatch performed.

## Provenance
Provenance: pending pilot run; no run id exists yet and the pilot records it here. Friction:
ladder failure mode "tank at a water-gun fight" (`tools/review-ladder.md` §4); G14
under-selection on contested designs (card 4, part-02 §2.2); G46 mid-round injection (task
spec 16 §6; part-02 §2.2 card 4, line 56; part-06 line 79 "a mid-round injection caused 3 of 4
Mediums"); G48 pre-round check (part-03 line 94; part-06 line 79 "a pre-round check cut 5
rounds to 1"; owner-decisions.md B-3, line 50).
