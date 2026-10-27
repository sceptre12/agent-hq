# Review hand-off: review-tailor, the loop, G48, D57, G46, D7

Sources: card 3 and card 4 (part-02 §2.2); part-02 §2.4 (rung per artifact); part-03 §3.4 (seats, orchestrator, synthesizer, fixer, fix-verifier) and line 94 (adopted rules); INTERFACES 1.10.0 (`architecture/delivery-workflow/INTERFACES.md:3`) part A.1 `<slug>` (`interfaces/part-a-state.md:7-53`), A.2 `orchestrator_tier` and `security_audit` (`part-a-state.md:60,72`), D1.1 `RUNG:` (`interfaces/part-d-enums-topics.md:12-31`), D2.1 enums (`:34-68`), D2.2 row 4 (`:78`); `skills/review-7-panel/SKILL.md` and `preround-check.md`; spec 16 (review-tailor) RESOLVED Q1-Q2.

## 1. The call (step 10)

| Input | Value |
|---|---|
| `RUN_HOME` | as received |
| `SLUG` | `run-doc-<n>`, `n` = 1 + the number of existing `RUN_HOME/review-tailor-run-doc-*.md` (spec 15 RESOLVED Q4; the same counter rule binds `delivery-dispatch-plan` with `run-plan-<n>`) |
| `ARTIFACTS` | comma-separated absolute paths: `architecture.md` and its parts, every `contracts/*` file, `test-plan.md`, `release-plan.md`, every `drafts/*.md`, every existing repo doc step 1 updated |
| `KIND` | `doc` |
| `STAKES` | `one-way` when `architecture.md` item 4 holds an irreversible choice (data deletion or migration without rollback, a public API or published package shape, an external publication, a money flow; this example list is a default of this skill, the axis values are part D `interfaces/part-d-enums-topics.md:47`); else `reversible` |
| `CONTENTION` | `contested` when item 4 lists an open decision with two or more live options, or the brief or `H1.notes.md` records a disagreement; else `none` |
| `NOVELTY` | `novel` when step 1 found no existing architecture doc or pattern for the surface; else `known` |
| `SECURITY_AUDIT` | `RUN_HOME/state.md` `security_audit`, unchanged (`guidance` when the key is absent, the A.2 default; part A.2, `interfaces/part-a-state.md:72`). The conductor sets that key; this skill never derives the value from its own `security_sensitive` line |
| `ORCHESTRATOR_TIER` | `RUN_HOME/state.md` `orchestrator_tier`, unchanged (part A.2, `interfaces/part-a-state.md:60`; D2.2 row 4, AM-3 errata (g)); required by `review-tailor`, no default; a missing key already stopped Step 0 (`INPUT-ERROR orchestrator_tier missing`) |

`STAKES`, `CONTENTION`, `NOVELTY` are chosen here; `SECURITY_AUDIT` and `ORCHESTRATOR_TIER` are read from their `state.md` carriers (reads under `RUN_HOME`, not new inputs of this skill). Values are D2.1 enums (`skills/review-tailor/references/step0-inputs.md` rows 6-8).

Record them in `review-architecture.md` as a fixed header block, lines 2-4, right after line 1 `ARCH: ready`, exactly these three `key: value` lines in this order, then one blank line:
```
STAKES: <reversible|one-way>
CONTENTION: <none|contested>
NOVELTY: <known|novel>
```
Each line holds the key, `: ` and the bare enum value, nothing else. These are the values `delivery-dispatch-plan` step 12 copies from `PLANS_DIR/review-architecture.md` into its own `review-tailor` call and never re-chooses (a missing line is `INPUT-ERROR <NAME> missing` there): D2.2 row 3 output consumed by rows 5 and 13 (INTERFACES 1.10.0 D8, AM-5 15 and 17); the conductor also passes lines 2-4 to the `pm` lead for `release-track` (C8, 29-28). The reason for each value goes in the record body, one line each, `why STAKES=<value>: <reason>` (likewise `CONTENTION`, `NOVELTY`). A re-entry writes the block again with the values of its new call.

## 2. Reading the record

`RUN_HOME/review-tailor-<SLUG>.md` (writer `review-tailor`): line 1 `RUNG: <rung> seats: <n>`; lines 2 up to the first blank line, the seat table `seat-id<TAB>role<TAB>reason`; then `mechanism:`, `tiers:`, `budget:`, `dispatch:` lines (AM-2 row 9). Validate line 1 against `^RUNG: (0|1|2|2b|3|4) seats: [0-9]+$` (`INPUT-ERROR rung enum` otherwise). The seat set is the record's and stays fixed (except for a rung raised to the floor, below); a profile-mandatory seat outside a fixed-count rung appears only as a note in `mechanism:` (part D1.1 `RUNG:` row, `interfaces/part-d-enums-topics.md:19`, AM-4 16, RT-Q1). An `INPUT-ERROR` from `review-tailor` is not a review round (part D1, AM-4): fix the input and call again with the same `SLUG`. Link the file from `review-architecture.md`; never copy the seat table (D22, spec 15 RESOLVED Q3).

Card 3 floor (design card 3, `architecture/delivery-workflow/part-02-skill-inventory.md:54`, and part-02 §2.4 `:90-96`): 1 for a story-scale tree, 2b for an epic-scale tree, 4 for a one-way door (`tree-rules.md` §Typed tree). **An epic's review rung is at least 2b (7 seats), whatever `review-tailor`'s generic rubric returns** (owner ruling 2026-10-26, `architecture/delivery-workflow-sources/owner-decisions.md:95`: "an epic gets at least the 7-seat review (design card 3 wins)"; INTERFACES D8 D2.2 row 4, AM-5 15). The run rung is the higher of the record rung and the floor (rung order 0 < 1 < 2 < 2b < 3 < 4). When the record is below the floor, the run uses the floor rung's mechanism (section 3) and its seat count (2b: 7 seats, fitted by the orchestrator under `skills/review-7-panel/SKILL.md` §Seat-perspective fitting; the record's seats are input to that fit), counts that mechanism's dispatch against the slot ledger, and `review-architecture.md` carries the line `rung raised: <record rung> -> <floor> (design card 3; owner 2026-10-26)`. `review-tailor`'s record is not edited.

## 2a. Item 12, filled before round 1 (step 10)

Owner D1 (`architecture/delivery-workflow-sources/owner-decisions.md:2`) is read as: every byte the human accepts was seen by a review round. So `architecture.md` item 12 is filled once, right after the run rung is set and before round 1, and is not edited after the last round. It keeps the template lines (`templates/architecture.md` item 12) and holds only what is known then, plus pointers:
```
Rung: <run rung>; seats: see `RUN_HOME/review-tailor-<SLUG>.md`; rounds: see `review-architecture.md`; open findings at round 3: see `review-architecture.md`
Record file: `review-architecture.md`.
```
The final round count, the B/M/L counts and any open findings live in `review-architecture.md` and the packet, both hashed in the packet. Item 12 is not excluded from the hash (a default of this skill; no owner decision needed). A re-entry refills item 12 the same way for its new `SLUG` before its round 1.

## 3. Mechanism per rung

| Rung | Mechanism | Notes |
|---|---|---|
| 1 | `doc-reviewer` with `skills/doc-reviewer/references/delivery-doc-checks.md`, then a fixer, then `fix-verifier` | the Rung 1 trio |
| 2 | `panel-consultation` | simulated members, at most 9 (card 4, `architecture/delivery-workflow/part-02-skill-inventory.md:56`) |
| 2b | `review-7-panel` | at most 7 seats (card 4, `architecture/delivery-workflow/part-02-skill-inventory.md:56`), synthesizer, fixer, fix-verifier, under one orchestrator |
| 4 | `panel-review` | 11 agents on the bus |

At Rungs 2b and 4 you dispatch one review orchestrator (D35); it dispatches the G48 checker, the seats, the synthesizer, the fixer and `fix-verifier`. At Rungs 1 and 2 there is no review orchestrator (`skills/review-tailor/references/rung-rules.md` peak table): you dispatch the G48 checker, the one reviewer, a non-author fixer and `fix-verifier` yourself. Brief the orchestrator (or, at Rungs 1-2, each agent with its part) with: the record path, the artifact paths, the seat list from the record (at a raised rung, the seat count to fit), the D57 trigger (section 5), the G46 rule (section 6), the D7 cap stated as: after a round-3 miss (NOT MET) there is no fixer, no `fix-verifier`, no pre-round slot and no further round; the round-3 synthesizer's open Blocking and Medium rows go to the owner (owner D7, section 8; this overrides `skills/review-7-panel/SKILL.md` §Steps step 5 for round 3), the protected values (section 7), the records directory `RUN_HOME/review/<SLUG>/` and the loop ledger `RUN_HOME/review/<SLUG>/ledger.md` (`skills/review-7-panel/SKILL.md` §Loop ledger: its location is set in the brief; both paths are defaults of this skill, under the run's records plane, part A.1), and the COMMON block (`architect-brief.md`). Round numbering (`-r<N>-` record names) starts at 1 in that directory; each call mints a new `SLUG` (step 10), so an `H1.changes` re-entry gets a new directory and never reuses a record name. The review record lists the directory, the ledger and every round record path. A mechanism that starts a bus claims its port before launch through `tools/port-check.sh --claim` (part A.5.2, run by its launcher, not by this skill). Count the record's `dispatch:` line against the slot ledger before you dispatch.

## 4. G48 pre-round slot (G48 check plus K1-K15)

Before round 1, on the whole artifact set, and after every fix, before the fix-verifier or any seat re-reads: one fresh mechanical-tier (Haiku) agent, read-only, never the author or the fixer, runs `skills/review-7-panel/preround-check.md` (C1-C7) and the `tree-rules.md` §Checks K1-K15 on the artifacts. Its fails go to the fixer, are fixed, and the slot re-runs on the touched files before any seat reads; so the artifact a round reviews is already K-clean, and every K-driven fix is seen by a review round (owner D1: the final artifact must still be reviewed). The orchestrator dispatches this checker at Rungs 2b-4; you do at Rungs 1-2. Use the same checklist at every rung. The record name follows `review-7-panel` (`preround-<artifact>-r<N>-<date>.md`).

## 5. D57 freeze trigger (relayed)

`review-tailor` states the trigger in its plan (two consecutive rounds with no change to the core sections, card 4 and spec 16). Copy the record's statement into the orchestrator brief word for word; do not restate it in your own words. Once it fires, scope is frozen: later findings outside the core go to the queue (section 6), not into a fix.

## 6. G46: no injection into a running round

A finding that arrives while a round runs (from you, a re-measure, the conductor, or a late seat) is queued for the next round start or a separate pass, never handed to the running round (G46, `RLM:99`, `RLM` key in `../SKILL.md` §Provenance: mid-round injection caused 3 of 4 Mediums in one loop). Keep the queue in the review record as `queued: <finding> -> round <N+1> | separate pass`.

## 7. Fixes

- The fixer is never the author (part-03 §3.4); you do not fix review findings yourself.
- Fixer brief: the synthesizer's findings with an exact `fix:` field each, and the protected values that must not change: `ARCH: ready` and `DRAFTS:` line forms, every minted slug, every `step_id`, the `security_sensitive` line (changed only with a stated reason from `security-sensitive.md`), every contract pin (refreshed together, never one side).
- `fix-verifier` runs after each fix with `FILE_SET` = the files the fix touched; never the fixer.
- ADR 0014 T1 (`decisions/0014-model-tier-operating-policy.md:55`): a second fix round that adds Mediums escalates the fixer one tier for that round; never a third top-tier attempt.
- D60: the same finding class in two consecutive rounds replaces the mechanism; the verifier checks the affected section got shorter, in bytes.
- D59: an edge enumeration is closed by one check and labelled; a parked owner item is asked, not re-worded.

## 8. Stop

Stop at 0 Blocking / 0 Medium from a synthesizer round, then the Low pass and its verifier the mechanism names (`skills/review-7-panel/SKILL.md` §Steps step 6). Or stop at a round-3 NOT MET (D7): no fixer and no verifier run after it; the open findings are that round-3 synthesizer's open Blocking and Medium rows, copied as they are (id, severity, one line, record path) into `review-architecture.md` and the H1 packet's "Open findings" block; the packet hashes the artifacts exactly as round 3 reviewed them (item 12 included: it was filled before round 1, section 2a); the owner decides. Step 12's final K-check re-run follows either stop; a failure there is listed as an open finding, never fixed outside a round. A frozen "(fact)" contradicted by re-measurement pauses the loop and is re-measured first (D51).
