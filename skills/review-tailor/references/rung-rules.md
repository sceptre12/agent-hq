# Rung rules (tools/review-ladder.md §1-§4, task spec 16 §6-§7, card 4)

## 1. Rubric (lowest rung that covers the named risk)
`KIND=diff`: Rung 3 (pr-review), 7 seats, whatever the risk surface (task spec 16 §7.1 and §9
case 1; `d12-gate.md`). A one-way door or high blast radius inside a diff is reviewed through a
separate run of this skill with `KIND=plan` on its decision doc (the route consistent with
spec §7.1). part-02 §2.4 lists "high blast radius: 4" as a code-diff escalation; INTERFACES
1.5.0 D1.1 `RUNG:` settles it (RT-Q2, AM-4 16): the code diff stays at Rung 3 and the one-way
decision behind it is reviewed separately as `KIND=plan` at Rung 4.
`KIND=doc|plan`, order of rungs 0, 1, 2, 2b, 4 (Rung 3 is for diffs only, ladder §1 "Not for:
prose/architecture docs"):

| STAKES | Size, CONTENTION, NOVELTY | Rung |
|---|---|---|
| any | mechanical edit with no design content (typo, rename, format), classified in Step 1 from reading the artifacts (no input carries it) | 0 |
| reversible | S, `none`, `known` | 1 |
| reversible | S or M with exactly one of `contested`/`novel`; or M, `none`, `known` | 2 |
| reversible | both `contested` and `novel` (any size); or L | 2b |
| one-way | any size | 4 |

Precedence when rows overlap: the one-way row first (ladder §1 lists one-way-door decisions
under Rung 4, and ladder §4 escalates a one-way door wherever it is found), then the Rung 0
mechanical-edit row (ladder §1 Rung 0 "trivial/mechanical changes", not for "anything with a
design fork"), then the remaining rows (ladder §2: the lowest rung that covers the risk). So a
mechanical edit to a one-way decision is Rung 4.
The both-`contested`-and-`novel` row is 2b at every size: ladder §1 says Rung 2 is not for
"decisions where perspective independence actually matters", and a genuine fork in new
territory is such a decision (ladder §2 contention and novelty). A one-way door found inside a
doc or plan is `STAKES=one-way` (ladder §4).
This rubric works from the inputs, not the artifact type; part-02 §2.4 is the delivery
workflow's per-artifact expectation for the same choice (e.g. epic architecture 2b, dispatch
plan 2b above 10 units else 1). Step 4's decision lines show which inputs gave the rung.
Epic floor (INTERFACES 1.5.0 D8, D2.2 row 4, AM-5 15): an epic's review rung is at least 2b;
design card 3 wins over this generic table. An epic-scale artifact (Step 1 size L) that the
rubric or the modifier would place below 2b is raised to 2b, and the `mechanism:` line says
`floor: epic 2b`; Rung 4 stays 4.

## 2. +1 modifier (ladder §3; INTERFACES D2.2 row 4, part A.2 `orchestrator_tier`, AM-3 errata (g))
Ladder §3, as written: "When the executing/orchestrating models are mid-tier only ... shift
**+1 rung** for the same artifact ... When a top-tier orchestrator is present, the ladder
applies as written." `ORCHESTRATOR_TIER` is the caller's copy of the `state.md` key
`orchestrator_tier` (key: `interfaces/part-a-state.md:59`), enum as D2.1 `tier`. When it is not `design`, move one step
up the doc order (0 to 1, 1 to 2, 2 to 2b, 2b to 4). Rung 4 is the top rung and does not move;
Rung 3 (`KIND=diff`) is fixed by task spec 16 §7.1 and does not move. `design`: no shift.
Write the case in the `mechanism:` line as `modifier: none` or `modifier: +1`. A Rung 0
record always says `modifier: none`: with `+1` the rung is 1, not 0.

## 3. Seat counts and caps (task spec 16 RESOLVED Q1, §7.2; INTERFACES D1.1)
| Rung | Mechanism (caller runs) | seats |
|---|---|---|
| 0 | direct review | 0 (no rows) |
| 1 | `doc-reviewer` | 1 |
| 2 | `panel-consultation` | members with standing, 3 to 9 (at least 3: `panel-consultation` Exit criteria) |
| 2b | `review-7-panel` | 1 to 7 |
| 3 | `pr-review` | exactly 7 |
| 4 | `panel-review` | 11 |

`seats:` equals the row count. Rung strings are only `0|1|2|2b|3|4`.

## 4. Escalation (for the caller, mid-review; ladder §4)
One rung up when: contradictory cross-cutting findings; simulated members genuinely deadlock
(Rung 2); a one-way door appears; the artifact outgrows one context. Re-run this skill with the
new facts; never keep last time's rung.

## 5. Per-repo review profile (task spec 16 RESOLVED Q3, §8.7)
`RUN_HOME/state.md` `repo_profile` is `<abs path>@<sha>`; read that profile file's
`review_profile.mandatory_seats[]` and `review_profile.blocking_rules[]` (listed in
`interfaces/part-a-state.md:113`, AM-2 row 5, reader `review-tailor`). For an artifact in a linked clone the profile is the
one INTERFACES row R4-J2 resolves (`interfaces/part-a-state.md:136`): the primary profile when
the path is under one of its `clones[]`, else the `linked_profiles[]` entry whose `clone`
contains it. Absent state, file or keys: no mandatory seats, never an `INPUT-ERROR`.
Mandatory seats by rung:
- Rungs 2 and 2b: mandatory seats go first and count against the cap (task spec 16 §6: the
  profile adds mandatory seats; never exceed 7 at 2b or 9 at 2).
- Rung 0: none; it has no seats (task spec 16 RESOLVED Q1, `seats: 0`).
- Rungs 1, 3 and 4: the counts are fixed (RESOLVED Q1; Rung 3 also D12) and the fixed set
  stays. A mandatory seat already in the fixed set changes nothing. Otherwise the seat set stays
  fixed (D12) and the `mechanism:` line notes the mandatory seat that is not in it
  (`mandatory-outside-set: <seat-id>`; INTERFACES 1.5.0 D1.1 `RUNG:`, RT-Q1, AM-4 16).
Blocking rules are copied by id into the `budget:` line.

## 6. Budget, tiers and dispatch line
The four line names `mechanism:`, `tiers:`, `budget:`, `dispatch:` come from task spec 16
RESOLVED Q2; their contents below (labels such as `modifier:`, `omitted:`, `security_audit:`,
`mode=`) are this skill's record convention, not an INTERFACES field.
Defaults, not owner-set: seat 10 min wall, synthesizer 10 min, fixer 20 min, fix-verifier 10 min
(`review-7-panel` Budgets); 12 min per-round allowance for the seat stage.

`tiers:` names the tier of each role the run uses (part-03 §3.1, §3.4; INTERFACES D2.1 `tier`):
seats `verify` (part-03 §3.1; part-03 line 36 sets the tailor's own tier, `verify`, `design`
on one-way doors, not a seat tier), synthesizer `verify`,
G48 checker `mechanical`, fixer `design`, fix-verifier `verify`, and the review orchestrator
`design` where one runs (Rungs 2b to 4). Then `omitted:` followed by `id=reason` entries
separated by `;`: at 2b the omitted default seats and any surface seat the cap kept out
(`seat-catalog.md` §A), at 2 the members not selected (`seat-catalog.md` §C). Rungs 0, 1, 3
and 4 have fixed sets (RESOLVED Q1) and always write `omitted: none`.

`dispatch:` states the agent count. Two anchors, for different ledgers. Build anchor (task
spec 16 §4): part-06 §7 item 31, 12 slots per `review-7-panel` bus under the 50 cap, counting
every role a 2b loop uses in a round (7 seats + orchestrator + synthesizer + fixer + verifier
+ gate checker = 12). Runtime anchor: each review holds b=10 reserved slots (part-03 line 14
and §4 lines 69, 76-78). A 2b loop fits b=10 because its roles do not all live at once: its
peak below is seats + 1 = at most 8. Counts come from each mechanism's own dispatch table plus one G48 checker per round,
which runs before every review loop (part-03 line 94); Rung 0 is a direct review, not a loop
(ladder §1), so no G48 checker, fixer or fix-verifier and no loop rule applies to it.

Peak live (defined once, used for every rung): the most agents of this review alive at the
same time = the seat agents running together + the review orchestrator where one runs
(Rungs 2b to 4, one per loop, D35). The G48 checker runs before the seats and the
synthesizer, fixer and fix-verifier after them, so none of them adds to the peak. At Rungs 1
and 2 one agent does the review and there is no review orchestrator. The mechanism tables
have no peak column; each value below is derived by this rule.

| Rung | Agents per round (from the mechanism's table) | Peak live |
|---|---|---|
| 0 | 0 | 0 |
| 1 | 1 G48 + 1 reviewer = 2 | 1 (reviewer) |
| 2 | 1 G48 + 1 (one agent plays all members) = 2 | 1 (that agent) |
| 2b | 1 G48 + seats + 1 synthesizer (`review-7-panel` Budgets) = 9 at 7 seats | seats + 1 |
| 3 | 1 G48 + 20 (`pr-review` table: bus startup, diff fetch, 7, gate, 7, gate, synthesizer, cleanup) = 21 | 7 + 1 = 8 |
| 4 | 1 G48 + 28 (`panel-review` table: bus startup, start session, 11, gate, 11, gate, synthesizer, cleanup) = 29 | 11 + 1 = 12 |

The per-round counts above are the base and do not include the fixer and fix-verifier; Rungs
1 to 4 add those two (+2) per round when findings remain (2b at 7 seats: 9, or 11 with
findings). The review
orchestrator (design tier, one per loop, D35) is counted in the peak at Rungs 2b to 4 and is
absent at Rungs 0 to 2. When the peak is larger than the b=10 reserved slots (Rung 4), fitting
it is the caller's slot ledger (part-03 §4); this skill only reports the number.
Format, every rung: `dispatch: <base> per round, +2 when findings remain, peak <n>;
security_audit: <value>`, where `<base>` is the table's per-round count and `<n>` its peak
live. Rungs 2b to 4 may add `(seats <s> + orchestrator 1)` after the peak, since it adds up
there; Rungs 1 and 2 write the peak alone (`peak 1`, one agent). Rung 0: `dispatch: 0 per
round, peak 0; security_audit: <value>` (no loop, so no +2).
Rung 0 `mechanism:` is `direct review; modifier: none; G48: not run (direct review, no
loop)` and its `budget:` line reads `no loop: D7, D57 and G46 not applicable` plus any copied
blocking rules.
Under `SECURITY_AUDIT=full` append `; full-mode run: output RUN_HOME/<subtask>/security-audit/run-<N>/`
(A.5.3), hunters and verifiers (persona `security-auditor`) counted against the ledger,
`validate-findings.cjs` as a `pre-pr-gate` row (task spec 16 §8.6). Guidance:
`security_audit: guidance` only.

## 7. Quality rules written into every plan (part-03 line 94; task spec 16 §6, §7.4-7.5)
- G48 pre-round check: a mechanical-tier (Haiku) agent checks the artifact against the known
  finding classes (unmeasured claims, arithmetic, cross-document contradictions, missing done
  conditions, protected values) before round 1 and after every fix; fixes land before any seat
  reads. A rule adopted by owner-decisions.md B-3 (line 50), not advisory; D6 covers the six
  numbered rules (D35, D55, D57, D59, D60, D62). Rungs 1 to 4 only (Rung 0 has no loop).
- D57 freeze trigger: two consecutive rounds with no change to the core sections.
- D7, quoted (`architecture/delivery-workflow-sources/owner-decisions.md` line 8): "after fix round 3 with open B/M findings, the
  sub-task STOPS and the owner gets the open findings; other sub-tasks continue."
- G46: a mid-round finding is queued for the next round start or a separate pass.
- Advisory-only rules (D44, D54, D58, D61, D66) are not written as rules (D6).
