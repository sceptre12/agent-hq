# 23 delivery-shepherd: Rung 1 loop record

- **Artifact:**
  - `skills/delivery-shepherd/SKILL.md`
  - `skills/delivery-shepherd/references/flags-and-nudges.md`
  - Both are a W1 pilot draft; the spec is `tasks/23-delivery-shepherd.md`.
- **Date:** 2026-10-26. **INTERFACES checked:** 1.3.0 (AM-3: the shepherd also flags `STALLED` and `PROMPT-OPEN`; the lead decides `TaskStop`; owner OQ-3, D10).
- **Loop:** one orchestrator (D35), and one agent per role, never reused across roles.
  - G48 pre-round screen: Haiku.
  - Review: Sonnet, applying the installed `doc-reviewer`.
  - Fix: Opus, not the author.
  - Fix-verify: Sonnet, applying the installed `fix-verifier`.
  - The same fixer, verifier and screener were resumed for later rounds, each in its own role.
- **Round cap:** 3 rounds (D7). Reviewers skipped lint and typo nits.
- **Working files:**
  - Snapshots `snap-r0` to `snap-r3`.
  - Diffs and findings files are in the build scratchpad under `r1-23/`.

## Focus checks requested by the dispatch

| Check | Result |
|---|---|
| DRIFT definition | **Was underspecified at r0.** The rule was: unit differs from the row's unit, `n` is past the last §9 step, or the unit is not in the plan. That is narrower than C7, has no expected-step rule, and leaves a "step" undefined.<br>**Now** it is labelled "this skill's reading of C7". `DRIFT` fires when:<ul><li>the `NEXT:` unit differs from the row's `unit`, or</li><li>`<n>` is greater than K (the count of non-comment command lines in the fenced block of the tasks file's `## 9`, the reading of C3), or</li><li>the row's unit has no `dispatch-plan.md` row.</li></ul>It does **not** fire on `n=0`, on a regression, on free text, or on ordering between agents. It applies only to `u<N>` rows. The nudge's `next:` always uses the row's unit, through an explicit expected-step rule. |
| 10-minute tick (D10) | Clean in every round. "Every 10 minutes, armed by the lead, never by this skill" (SKILL.md:20), plus a Red-flags row. |
| Never calls `TaskStop` | Clean in every round. All 9 occurrences are a prohibition or the lead's action (listed by the r3 fix-verify). |

## Round 1

**Screen: 0 Blocking, 5 Medium, 4 Low.**

**Review: 2 Blocking, 4 Medium, 3 Low. Verdict NOT READY.**

The two were merged into F1-F7 (Blocking and Medium) and L1-L6 (Low):
- **F1 (Blocking):** the nudge's `next:` had no derivation, and DRIFT was too narrow.
- **F2 (Blocking):** no nudge could be built when the agent had no `NEXT:` line.
- **F3:** the on-change dedupe could not be executed.
- **F4:** the CREEP path did not fit the fixed template.
- **F5:** there was no token for `scope-check.sh` exit 2.
- **F6:** the bus read had no endpoint and no topic.
- **F7:** a unit-level record falsely freed sibling agents.

**Fix:** all closed. The fix added:
- the expected-step rule, with `<unit>.0` and the `dispatch-plan.md` row as fallback;
- exact-line dedupe, with its limit disclosed;
- a CREEP nudge with no path;
- a skill-local reply item `unchecked <agent-id> <reason>`;
- bus endpoint and topic taken from `bus.endpoint` (D5) and D4;
- a match on `from_agent` or the `.verdict` stem;
- an exemption for `i<N>` and `-` rows;
- `Provenance: pending pilot` as the last line.

**Fix-verify: ISSUES_FOUND (1 Medium: stale step cross-reference).**

**Post-fix screen: 1 Blocking, 6 Medium, 2 Low.**
- The Blocking (the bus call lacked `session_id` and `topics`) was downgraded to Medium by the orchestrator.

## Round 2

Findings G1-G7:
- **G1:** step cross-references.
- **G2:** the `read_messages` parameters, and `since`-paging per `skills/swarm-communication/references/tools.md`.
- **G3:** a watchdog-written line suppressed the shepherd's nudge.
- **G4-G7:** Low.

**Fix:** all closed. However, the G3 fix introduced a nudge on every tick for `STALLED` and `PROMPT-OPEN`.

**Fix-verify: ISSUES_FOUND (1 Medium: a contradiction with the reference's known-limit line, plus 2 Low).**

**Post-fix screen: 1 Medium** (the every-tick nudge had no bound and no basis in C7 or the spec), **2 Low.**

## Round 3

**H1 orchestrator ruling** (conservative, inside C7):
- Every flag is nudged exactly once, on the tick this skill appends its line.
- If the line is already present, written by either half, this skill sends no nudge.
- The unverified claim about the watchdog half was removed.
- A neutral open-question line stays in the files.

**Also fixed:**
- **H2:** the exclusive `since` boundary is noted (at worst a one-tick delay of an advisory flag).
- **H3:** the Contracts line now cites A.6 and `tools.md`.

**Fix-verify: CLEAN.**

**Post-fix screen: 0 Blocking, 0 Medium, 2 Low.**

## Final

- **0 Blocking, 0 Medium.**
- **Low still open (informational):**
  - `read_messages` ordering is unstated in `tools.md`, so the direction of `since`-paging is unverified.
  - Dedupe by message `id` was not adopted (the one-tick delay note covers it).

### §9 done-condition

```
$ bash v23.sh   # spec §9 block verbatim
SKILL-23-OK     # exit 0
```

Run by the orchestrator and independently by the fix-verifier. SKILL.md is 1976 words. `check-doc-length` reports 0 blocking. The verifier confirmed that `TaskStop` appears only as the lead's action.

## Owner questions (no answer written into the skill)

- **OQ1:** A.4 allows `i<N>` units, but the C3 `NEXT:` regex admits only `u<N>`. Should Integrator rows get the DRIFT and CREEP checks and nudges?
  - Recommended: no, exempt them, as the text does now.
- **OQ2:** The `ticks.md` line `<FLAG> <agent-id>` carries no cause. A flag that clears and then recurs, or a DRIFT or CREEP whose cause changes, is not appended or nudged again. Should C7 allow a clear record or a shepherd state file?
  - Recommended: no, keep C7 and accept the limit. Agent ids are fresh per dispatch, and the lead sees the live state on its own tick.
- **OQ3:** When the `delivery-run` watchdog half writes a `STALLED` or `PROMPT-OPEN` line first, this skill sends no nudge for it. Who nudges in that case?
  - Recommended: whichever half appends the line sends the one C7-template nudge. This would be stated in C7 as an erratum and in `delivery-run`'s watchdog half.
- **OQ4 (INTERFACES erratum, not a skill defect):** C2 (part-c:86) and D4 (part-d:117) say the rendezvous topic's "Readers: the sub-task lead only". C7 (part-c:184) has the shepherd read FREE-CANDIDATE evidence from the bus.
  - Recommended: amend C2 and D4 to "the lead, plus the shepherd peek-only for FREE-CANDIDATE". The skill already states that peek-only reading.
- **Note:** `rung1-brief.md` says INTERFACES 1.2.0. The dispatch and INTERFACES.md say 1.3.0, and 1.3.0 was used.
