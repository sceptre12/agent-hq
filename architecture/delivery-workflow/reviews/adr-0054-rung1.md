# ADR 0054 — Rung 1 loop record

- **Artifact:** `decisions/0054-adr-0023-amendment-delivery-workflow.md` (the ADR 0023
  amendment for `wave-execution`). Its status stays "proposed — awaiting owner ratification".
- **Loop:** one orchestrator (D35), and a separate agent for every role:
  - G48 pre-round screen: Haiku.
  - Review: Sonnet, running the `doc-reviewer` skill.
  - Fix: Opus.
  - Fix-verify: Sonnet, running the `fix-verifier` skill.
- **Round cap:** 3 rounds (D7). The pre-round screen ran before round 1 and after each fix.
- **Date:** 2026-10-26.
- **Sources given to reviewers:**
  - `decisions/0023-wave-execution-workflow-grafts.md`
  - `architecture/wave-execution.md`
  - `skills/wave-execution/` (`SKILL.md`, `references/spec-format.md`)
  - `architecture/delivery-workflow/part-01..06-*.md`
  - the round-2 changelog rows "B1 completion signal" and "M17 waves mapping"
  - `architecture/delivery-workflow/interfaces/`
  - the owner rulings

## Result

**Stopped after round 3 (D7) at B=0 M=0 A=3.** The last fix-verify was CLEAN. The ADR is 313
lines; `tools/check-doc-length.sh` flags nothing for it.

| Round | Pre-check (G48) | Review | Fix | Fix-verify |
|---|---|---|---|---|
| 1 | 18 hits, 0 wrong line refs | B=1 M=10 A=3 | F1-F14 fixed, or turned into owner questions Q2-Q10; open item 1 recorded as decided (A9) | CLEAN, A=2 |
| 2 | 14 hits | B=0 M=3 A=2 | F1-F3 fixed, plus the in-ADR advisories; follow-up deferred bus recovery to `INTERFACES.md` | ISSUES (M=1), then fixed |
| 3 | 14 hits | B=0 M=1 A=2 | F1 (barrier-wave `step_complete` verdict combination) turned into new Q11 | ISSUES (orphaned "pending Q5"), then fixed; final CLEAN, A=1 |

## Key changes by round

**Round 1**
- **A0 (new):** `session_id`, `output_topic` and `bus_endpoint` are bundle-level spec fields
  and are covered by the checkpoint hash. `max_concurrent` is a per-invocation argument, so a
  changing slot count no longer voids the checkpoint on resume. This fixes the Blocking F1.
- **Defect fixes:**
  - A5's unreachable `TaskStop` of live dependents was dropped.
  - The escalation payload now carries the work_item.
  - A7 separates completions from gate verdicts by `from_agent`.
  - The pinned-resume collision is covered.
  - `gate_agents` for `step_complete` is defined.
  - The gate-invariant changes are listed.
- **Owner-facing points** became the Owner questions section, Q2-Q10. Each is a yes/no question
  with a Recommended line and a Meanwhile line, and the affected text is marked "pending Q<n>".

**Owner ruling received mid-loop.** Open item 1 became A9, an optional `bus_endpoint`: when it
is set, the skill attaches to the caller's bus and skips teardown; when it is absent, nothing
changes. The coordinator relayed the ruling, and the orchestrator checked it against the owner
rulings ("INTERFACES owner questions (2026-10-26)", Q2 YES) before passing it to the fixer.

**Round 2**
- Rule 14 applies the literal rule only to a bundle-level `output_topic`. The per-wave
  `{SESSION_ID}-wave-{N}-output` stays valid, as today.
- `from_agent` ids carry a per-invocation nonce.
- A9 now spells out what attaching does to the identity preflight, step 5, step 8 `cleanup()`
  and § Bus Rules.
- Who recovers an attached bus is left to `INTERFACES.md`; the ADR does not decide it.

**Round 3**
- A4 says the barrier-wave combination of per-work_item `step_complete` verdicts is undecided
  (pending Q11). The sources disagree: `adversarial_verify` fails on any falsification, while
  `judge_panel` takes the majority (0023 lines 69-71; `wave-execution.md` lines 179-181).
- The orchestrator made one mechanical edit: the Status line now reads Q2-Q11.

## Owner questions left open (the ADR's Owner questions section)

- **Q1:** decided by the owner (A9).
- **Open item 2:**
  - **Q2:** does a work_item get one optional done-condition field, required under
    `step_complete` and checked by rule 9? Recommended: yes.
- **Author's design choices:**
  - **Q3:** do gate and fix agents stay outside `max_concurrent`? Recommended: no. Counting
    them makes "`max_concurrent` = free slots" enforce D4's cap of 30.
  - **Q4:** do edges stay within one wave? Recommended: yes.
  - **Q5:** in a frontier wave, does each work_item get its own gate, fix loop and budget term?
    Recommended: yes.
  - **Q6:** is the checkpoint the sole authority on resume, so posts it has not recorded are
    re-gated? Recommended: yes.
  - **Q7:** does the caller consume the fallback file? Recommended: yes.
  - **Q8:** when a bundle-level `output_topic` is set, does a different per-wave value fail
    validation? Recommended: yes.
  - **Q9:** is `max_concurrent` an invocation argument? Recommended: yes.
  - **Q10:** are `persona` and `lane` set per work_item? Recommended: yes.
- **Raised by the round-3 review:**
  - **Q11:** in a barrier wave, does `step_complete` require every gate to pass? Recommended:
    yes.

## Advisories left (not fixed)

1. A4's phrase "which output each gate agent reads" is tagged "pending Q11", but Q11 asks only
   about combining verdicts. Either drop the phrase or fold it into Q11.
2. "Barrier wave" is used in the ADR but not defined there.
3. Follow-ups outside the ADR, for the owners of those files:
   - `interfaces/part-c-waves-control.md` is stale in four places: it says C1.2 `TaskStop`s
     dependents, uses the old rule-14 wording, cites A9 at the wrong lines, and has
     `bus_endpoint` reading the port from a file.
   - Design `part-02` lines 60 and 84 have no `bus_endpoint` and call `max_concurrent` per-wave.

## Working files

The pre-checks, reviews, fix logs and fix-verifies for each round, plus ADR snapshots
`adr-r0/r1/r2.md`, are in the orchestrator's session scratch directory under `adr0054-loop/`.

## Owner answers applied and ratification (2026-10-26)

- **Owner answers** (`owner-decisions.md`, "ADR 0054 questions"): Q2 yes; Q3 gate and fix agents
  count toward `max_concurrent`; Q4-Q11 yes, as recommended above. Each is written into the ADR
  citing "owner 2026-10-26"; the Owner questions section is now "Owner decisions".
- **Advisories closed:** A4 no longer tags "which output each gate agent reads" as Q11 (it is
  left to `INTERFACES.md` part C, C1.2); "barrier wave" is defined once in the Decision preamble.
- **Fix-verify (Sonnet, `fix-verifier`): CLEAN**, 0 Blocking, 0 Medium, 3 Advisory (the second
  sense of "barrier" in "declared waves stay barriers to each other"; the derived "a gate or fix
  agent waits for a slot"; the done-condition field name points at stale C1.2 text).
- **Status set to** "accepted 2026-10-26 (owner ratified conditional on fix-verify)".

## INTERFACES lines that now need updating (owned by the INTERFACES loop; not edited here)

1. `interfaces/part-c-waves-control.md:19` — `max_concurrent` formula reserves 3 units per
   reservation row and says "owner to decide whether gate and fix agents count (Q3)"; Q3: they
   count toward `max_concurrent`.
2. `interfaces/part-c-waves-control.md:20` — "Value rule pending ADR 0054 Q5"; Q5 decided.
3. `interfaces/part-c-waves-control.md:36` — done condition carried as a `## Done condition`
   section, citing the ADR "Meanwhile" and "owner to decide (Q2)"; Q2: a per-work_item field,
   required under `step_complete`, checked by rule 9; C1.2 must name the field.
4. `interfaces/part-c-waves-control.md:37` — gate walks the `## Done condition` section; now the
   done-condition field. C1.2 should also state which output each gate agent reads (A4).
5. `interfaces/part-c-waves-control.md:3,23` — ADR 0054 line refs (`:37-181`, `:168-181`) are
   stale; A9 is now at lines 179-197.
6. `interfaces/part-c-waves-control.md:32` — lead `TaskStop`s dependents (stale, A5).
7. `interfaces/part-c-waves-control.md:23` (C1.1 `bus_endpoint`) — "ratifies with ADR 0054":
   now ratified.
8. `interfaces/part-a-state.md:181` — free-slot formula `30 - live_rows - 3 x reservation_rows
   - ...`; recheck against Q3 (gate and fix agents counted inside `max_concurrent`).
9. `INTERFACES.md:37` (N1) — Q3 "owner to decide", 3-unit reservation.
10. `INTERFACES.md:38` (N2) — Q2 "owner to decide", "Meanwhile" carrier.
11. `INTERFACES.md:44` (N8) — Q4, Q9 "owner to decide".
12. `INTERFACES.md:45` (N9) — Q5 "owner to decide".
13. `INTERFACES.md:33,123,145` — "meanwhile" framing, C1.2 `## Done condition` row, E12 "ADR 0054
    proposed text".
14. `INTERFACES.md:92` (C1.1 row) — `bus_endpoint` "ratifies with ADR 0054": now ratified.
15. Design `part-02` line 60 and 84 (errata via INTERFACES E12) — per-wave `max_concurrent`, no
    `bus_endpoint`.
