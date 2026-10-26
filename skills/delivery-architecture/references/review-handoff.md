# Review hand-off: review-tailor, the loop, G48, D57, G46, D7

Sources: card 3 and card 4 (part-02 §2.2); part-02 §2.4 (rung per artifact); part-03 §3.4 (seats, orchestrator, synthesizer, fixer, fix-verifier) and line 94 (adopted rules); INTERFACES 1.1.0 part A.1 `<slug>`, D1.1 `RUNG:`, D2.1 enums, D2.2 row 4; `skills/review-7-panel/SKILL.md` and `preround-check.md`; spec 16 (review-tailor) RESOLVED Q1-Q2.

## 1. The call (step 10)

| Input | Value |
|---|---|
| `RUN_HOME` | as received |
| `SLUG` | `run-doc-<n>`, `n` = 1 + the number of existing `RUN_HOME/review-tailor-run-doc-*.md` (spec 15 RESOLVED Q4; the same counter rule binds `delivery-dispatch-plan` with `run-plan-<n>`) |
| `ARTIFACTS` | comma-separated absolute paths: `architecture.md` and its parts, every `contracts/*` file, `test-plan.md`, `release-plan.md`, every `drafts/*.md` |
| `KIND` | `doc` |
| `STAKES` | `one-way` when `architecture.md` item 4 holds an irreversible choice (data deletion or migration without rollback, a public API or published package shape, an external publication, a money flow); else `reversible` |
| `CONTENTION` | `contested` when item 4 lists an open decision with two or more live options, or the brief or `H1.notes.md` records a disagreement; else `none` |
| `NOVELTY` | `novel` when step 1 found no existing architecture doc or pattern for the surface; else `known` |
| `SECURITY_AUDIT` | `guidance`; `full` only when the conductor or the operator explicitly says `full` for this invocation. This skill never infers `full` from its own `security_sensitive` line (the conductor reads that line, part A.2) |

Values are D2.1 enums. Write the reason for each of `STAKES`, `CONTENTION`, `NOVELTY` into the review record.

## 2. Reading the record

`RUN_HOME/review-tailor-<SLUG>.md` (writer `review-tailor`): line 1 `RUNG: <rung> seats: <n>`; lines 2 up to the first blank line, the seat table `seat-id<TAB>role<TAB>reason`; then `mechanism:`, `tiers:`, `budget:`, `dispatch:` lines (AM-2 row 9). Validate line 1 against `^RUNG: (0|1|2|2b|3|4) seats: [0-9]+$` (`INPUT-ERROR rung enum` otherwise). Link the file from `review-architecture.md`; never copy the seat table (D22, spec 15 RESOLVED Q3).

Card 3 floor (part-02 §2.4): 1 for a story-scale tree, 2b for an epic-scale tree, 4 for a one-way door (`tree-rules.md` §Typed tree). A record below the floor is not run: report `RUNG below card-3 floor: <record rung> < <floor>` to the conductor and stop.

## 3. Mechanism per rung

| Rung | Mechanism | Notes |
|---|---|---|
| 1 | `doc-reviewer` with `skills/doc-reviewer/references/delivery-doc-checks.md`, then a fixer, then `fix-verifier` | the Rung 1 trio |
| 2 | `panel-consultation` | simulated members, at most 9 |
| 2b | `review-7-panel` | at most 7 seats, synthesizer, fixer, fix-verifier, under one orchestrator |
| 4 | `panel-review` | 11 agents on the bus |

You dispatch one review orchestrator (D35) and brief it with: the record path, the artifact paths, the seat list from the record, the D57 trigger (section 5), the G46 rule (section 6), the D7 cap, the protected values (section 7), and the COMMON block (`architect-brief.md`). A mechanism that starts a bus claims its port before launch through `tools/port-check.sh --claim` (part A.5.2, run by its launcher, not by this skill). Count the record's `dispatch:` line against the slot ledger before you dispatch.

## 4. G48 pre-round check

Before round 1, on the whole artifact set, and after every fix, before the fix-verifier or any seat re-reads: one fresh mechanical-tier (Haiku) agent, read-only, never the author or the fixer, runs `skills/review-7-panel/preround-check.md` (C1-C7) on the artifacts. Its fails go to the fixer and are fixed before any seat reads. Use the same checklist at every rung. The record name follows `review-7-panel` (`preround-<artifact>-r<N>-<date>.md`).

## 5. D57 freeze trigger (relayed)

`review-tailor` states the trigger in its plan (two consecutive rounds with no change to the core sections, card 4 and spec 16). Copy the record's statement into the orchestrator brief word for word; do not restate it in your own words. Once it fires, scope is frozen: later findings outside the core go to the queue (section 6), not into a fix.

## 6. G46: no injection into a running round

A finding that arrives while a round runs (from you, a re-measure, the conductor, or a late seat) is queued for the next round start or a separate pass, never handed to the running round (G46, `RLM:99`: mid-round injection caused 3 of 4 Mediums in one loop). Keep the queue in the review record as `queued: <finding> -> round <N+1> | separate pass`.

## 7. Fixes

- The fixer is never the author (part-03 §3.4); you do not fix review findings yourself.
- Fixer brief: the synthesizer's findings with an exact `fix:` field each, and the protected values that must not change: `ARCH: ready` and `DRAFTS:` line forms, every minted slug, every `step_id`, the `security_sensitive` line (changed only with a stated reason from `security-sensitive.md`), every contract pin (refreshed together, never one side).
- `fix-verifier` runs after each fix with `FILE_SET` = the files the fix touched; never the fixer.
- ADR 0014 T1: a second fix round that adds Mediums escalates the fixer one tier for that round; never a third top-tier attempt.
- D60: the same finding class in two consecutive rounds replaces the mechanism; the verifier checks the affected section got shorter, in bytes.
- D59: an edge enumeration is closed by one check and labelled; a parked owner item is asked, not re-worded.

## 8. Stop

Stop at 0 Blocking / 0 Medium from a synthesizer round (then the Low pass the mechanism names), or after round 3 (D7). At the D7 stop, list every open finding (id, severity, one line, record path) in `review-architecture.md` and in the H1 packet's "Open findings" block; the owner decides. A frozen "(fact)" contradicted by re-measurement pauses the loop and is re-measured first (D51).
