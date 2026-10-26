# Rung rules (tools/review-ladder.md §1-§4, part-02 §2.4, card 4)

## 1. Rubric (lowest rung that covers the named risk)
`KIND=diff`: Rung 3 (pr-review), 7 seats (`d12-gate.md`). Rung 4 is not for code diffs.
`KIND=doc|plan`, order of rungs 0, 1, 2, 2b, 4 (Rung 3 is for diffs only):

| STAKES | Size, CONTENTION, NOVELTY | Rung |
|---|---|---|
| any | mechanical edit with no design content (typo, rename, format) | 0 |
| reversible | S, `none`, `known` | 1 |
| reversible | S or M with one of contested/novel; or M, `none`, `known` | 2 |
| reversible | M with both contested and novel; or L | 2b |
| one-way | any size | 4 |

A one-way door found inside an artifact is `STAKES=one-way`. A diff with a one-way door stays
Rung 3; its `mechanism:` line adds "decision doc goes through review-tailor KIND=plan".

## 2. +1 modifier (ladder §3)
When `RUN_HOME/state.md` records no design-tier orchestrator, move one step up the doc order
(1 to 2, 2 to 2b, 2b to 4, 0 to 1). Rung 4 and Rung 3 do not move. The key for that record is
not defined in INTERFACES A.2.2; absent or unreadable means a design-tier conductor exists.
Say which case applied in the `mechanism:` line ("modifier: none|+1").

## 3. Seat counts and caps
| Rung | Mechanism (caller runs) | seats |
|---|---|---|
| 0 | direct review | 0 (no rows) |
| 1 | `doc-reviewer` | 1 |
| 2 | `panel-consultation` | members with standing, 1 to 9 |
| 2b | `review-7-panel` | 1 to 7 |
| 3 | `pr-review` | exactly 7 |
| 4 | `panel-review` | 11 |

`seats:` equals the row count. Rung strings are only `0|1|2|2b|3|4`.

## 4. Escalation (for the caller, mid-review)
One rung up when: contradictory cross-cutting findings; simulated members genuinely deadlock
(Rung 2); a one-way door appears; the artifact outgrows one context. Re-run this skill with the
new facts; never keep last time's rung.

## 5. Per-repo review profile
`RUN_HOME/state.md` `repo_profile` is `<abs path>@<sha>`; read that profile file's
`review_profile.mandatory_seats[]` and `review_profile.blocking_rules[]` (key names proposed,
INTERFACES A.2.2 does not list them yet). Absent state, file or keys: no mandatory seats,
never an `INPUT-ERROR`. Mandatory seats go first and count against the cap. For Rung 3 the
seven stay; a mandatory seat matching a `pr-review` role is noted in that row's `reason`; one
matching none is named in `mechanism:` as `profile seat not covered: <id>` (seven is fixed).
Blocking rules are copied by id into `budget:` as `blocking: <ids>`.

## 6. Budget and dispatch line
Defaults, not owner-set: seat 10 min wall, synthesizer 10 min, fixer 20 min, fix-verifier 10 min
(`review-7-panel` Budgets); 12 min per-round allowance for the seat stage.
`dispatch:` states the count against the ledger (12 slots per bus, 50 cap, part-06 §7 item 31):

| Rung | Agents per round | Peak live |
|---|---|---|
| 0 | 0 | 0 |
| 1 | 1 | 1 |
| 2 | 1 (one agent plays all members) | 1 |
| 2b | 1 G48 check + seats + 1 synthesizer (+ fixer, fix-verifier when the bar is not met) | seats + 1 |
| 3 | 7 + gate + 7 + gate + synthesizer + cleanup = 18 | 8 |
| 4 | 11 + gate + 11 + gate + synthesizer + cleanup = 26 | 12 |

Plus the review orchestrator (a design-tier slot row, one per loop, D35) for Rungs 2b to 4.
Format: `dispatch: <per-round> per round, peak <n>, orchestrator 1; security_audit: <value>`.
Under `SECURITY_AUDIT=full` append `; full-mode run: output RUN_HOME/<subtask>/security-audit/run-<N>/`
(A.5.3), hunters and verifiers (persona `security-auditor`) counted against the ledger,
`validate-findings.cjs` as a `pre-pr-gate` row. Guidance: `security_audit: guidance` only.
Omitted default seats go in `tiers:` after `omitted:` as `id=reason` separated by `;`.

## 7. Quality rules written into every plan
- G48 pre-round check: a mechanical-tier (Haiku) agent checks the artifact against the known
  finding classes (unmeasured claims, arithmetic, cross-document contradictions, missing done
  conditions, protected values) before round 1 and after every fix; fixes land before any seat
  reads. A rule (D6), not advisory.
- D57 freeze trigger: two consecutive rounds with no change to the core sections.
- D7: review loops stop after round 3, then the owner decides.
- G46: a mid-round finding is queued for the next round start or a separate pass.
- Advisory-only rules (D44, D54, D58, D61, D66) are not written as rules (D6).
