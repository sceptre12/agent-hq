---
name: review-tailor
version: 0.1.0
description: Chooses the review rung and the seats for an artifact and writes one record file (`RUNG: <rung> seats: <n>` plus a seat table). Use when an artifact (doc, plan or code diff) needs review and you must choose the rung and the seats before invoking a review skill. It sits beside the ladder in tools/review-ladder.md, not on it: it picks the rung and dispatches nothing. The caller runs the rung: 1 doc-reviewer, 2 panel-consultation, 2b review-7-panel, 3 pr-review (code diffs), 4 panel-review (one-way doors). Always the lowest rung that covers a nameable risk.
---

## Trigger
Use when an artifact needs review and the rung and seats are not yet chosen: delivery stage 2
(architecture and ticket drafts), stage 3 (dispatch plan), stage 4b (pre-PR diff review).
Callers: `delivery-architecture`, `delivery-dispatch-plan`, `pre-pr-gate`, the `pr-review`
`ROLES` derivation. Not for running the review: this skill selects, the caller dispatches.

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
2. **Apply the rubric** (`references/rung-rules.md` §1) to `KIND`, size, `STAKES`,
   `CONTENTION`, `NOVELTY`. `KIND=diff` is Rung 3 always.
3. **Apply the +1 modifier** (`references/rung-rules.md` §2): only when `RUN_HOME/state.md`
   records no design-tier orchestrator. Absent record means a design-tier conductor exists
   (part-03 §3.1): no shift.
4. **Pick the lowest rung** that covers the named risks. Write down, in one line each, the
   rubric inputs that decided it. Escalation triggers (`rung-rules.md` §4) are for the
   caller mid-review; never start high to be safe.
5. **Select seats** from `references/seat-catalog.md` by risk surface present. Order:
   profile-mandatory seats first (`review_profile.mandatory_seats[]`, `rung-rules.md` §5),
   then default seats, then surface seats. `KIND=diff`: the seven `pr-review` ids, nothing else.
   `doc`/`plan`: lens seats (2b), panel members (2), the one reviewer (1), the 11-seat
   roster (4), no seats (0). Each row's `reason` is its "finds what the others cannot".
6. **Justify each omitted default seat** in one line (why its surface is absent), listed
   in the `tiers:` line's tail after `omitted:`. A seat with no "finds what the others
   cannot" is not added.
7. **Apply caps and the D12 rule** (`references/d12-gate.md`): at most 7 seats at Rung 2b, at
   most 9 at Rung 2, exactly 7 at Rung 3, the 11-seat roster at Rung 4, 1 at Rung 1, 0 at
   Rung 0. There is no branch, flag or env var that yields fewer than 7 for a code diff.
   Security seat row: its `reason` ends `mode=<SECURITY_AUDIT value>`; `guidance` is
   diff-scoped (`skills/security-audit` loaded by the seat), no files, no agents. Under `full` add the full-mode run line to `dispatch:`
   (`rung-rules.md` §6). This skill never chooses `full`; it echoes the input.
8. **Write the record** `RUN_HOME/review-tailor-<SLUG>.md` atomically (temp file in
   `RUN_HOME`, then `mv`): line 1 `RUNG: <rung> seats: <n>` (regex
   `^RUNG: (0|1|2|2b|3|4) seats: [0-9]+$`), lines 2+ one row per seat
   `seat-id<TAB>role<TAB>reason` (`seat-id` matches `^[a-z0-9-]+$`), a blank line, then four
   lines `mechanism:`, `tiers:`, `budget:`, `dispatch:`. `n` equals the row count. This skill
   is the sole writer of that file.
   - `mechanism:` the skill the caller runs, then the G48 pre-round check: a mechanical-tier
     (Haiku) agent checks the artifact against the known finding classes before round 1 and
     after every fix; fixes land before any seat reads. A rule, not advisory.
   - `budget:` D7 (loops stop after round 3, then the owner decides), the D57 freeze trigger
     (two consecutive rounds with no change to the core sections), G46 (a finding that
     arrives mid-round is queued for the next round start or a separate pass, never injected),
     and per-seat wall budgets from `rung-rules.md` §6.
   - `dispatch:` agent count against the ledger (`rung-rules.md` §6), `security_audit:` echo.
9. **End with the dispatch count.** Print the record's line 1 and the `dispatch:` line as the
   last two stdout lines, and stop. Do not dispatch any reviewer.

## Red flags
| Rationalization | What to do instead |
|---|---|
| "High stakes" with no nameable risk | Name the risk, or drop a rung. |
| "Start high to be safe" | Lowest rung that covers the risk; escalate on a trigger only (`tools/review-ladder.md` §4). |
| "A small diff only needs 3 seats" | Code diff is 7 seats until the D12 remap and probe are recorded in INTERFACES; no branch below 7. |
| "Add the performance seat, it can't hurt" | A seat with no "finds what the others cannot" is not added. |
| "A finding just arrived, add it to the running round" | G46: queue it for the next round start or a separate pass. |
| "Same rung as last time" | Rungs attach to artifacts, not habits; re-run the rubric. |
| "I will dispatch the seats myself" | This skill writes the record; the caller runs the mechanism. |
| "Caller left SECURITY_AUDIT out, assume guidance" | `INPUT-ERROR SECURITY_AUDIT missing`; never default it. |

## Exit criteria
- [ ] Line 1 of the record matches `^RUNG: (0|1|2|2b|3|4) seats: [0-9]+$`.
- [ ] `seats: n` equals the number of seat rows (lines 2 up to the first blank line).
- [ ] `KIND=diff` has `seats: 7` and the seven `pr-review` ids.
- [ ] Rung 2b has at most 7 rows and Rung 2 at most 9.
- [ ] Every omitted default seat has a stated reason; every row has a reason.
- [ ] The Security row (when present) names `mode=<SECURITY_AUDIT>`; `full` adds the run line.
- [ ] `mechanism:` names G48; `budget:` names D57, D7 and G46; `dispatch:` has the count.
- [ ] No web fetch, no dispatch performed.

## Provenance
Provenance: pending pilot (<pilot-run-id>). Friction: ladder failure mode "tank at a water-gun
fight" (`tools/review-ladder.md` §4); G14 under-selection on contested designs (card 4,
part-02 §2.2); G46 mid-round injection (`RLM:99`); G48 pre-round check (`RLM:101`).
