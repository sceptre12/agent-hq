# 09 wave-execution EXTEND — Rung 1 loop record

- **Artifact:** `skills/wave-execution/` (`SKILL.md`, `references/spec-format.md`,
  `references/frontier-mode.md`, `references/example-spec/**` including `tests/`) and
  `architecture/wave-execution.md`, in worktree `~/projects/agent-hq-worktrees/delivery-extends`
  (branch `ext/delivery-extends`, base commit `6092662`). Fixes are uncommitted; Worker1 commits.
- **Spec:** `architecture/delivery-workflow/tasks/09-wave-execution.md` (in `delivery-w0`).
  Authority: ADR 0054 (accepted), INTERFACES part C (C1.1-C1.3). The brief named INTERFACES
  1.2.0; the file now reads `version: 1.3.0` (AM-3). The anchors used (C1.1-C1.3, C2, D5) resolve in both.
- **Loop:** one orchestrator (D35), with a separate agent for every role and a fresh agent each round:
  - G48 pre-round screen: Haiku.
  - Review: Sonnet, running the installed `doc-reviewer` skill (M29).
  - Fix: Opus.
  - Fix-verify: Sonnet, running the installed `fix-verifier` skill.
- **Round cap:** 3 (D7).
- **Date:** 2026-10-26.

## Result

**Finished in 3 rounds at B=0 M=0 L=0 open.** All Lows found were fixed. Six owner questions are open
(below). The last fix-verify was CLEAN. The §9 block printed `EXT-09-OK` with rc=0, run by the verifier
and re-run by the orchestrator.

| Round | Pre-check (G48) | Review | Fix | Fix-verify |
|---|---|---|---|---|
| 1 | 25 items; 1 Blocking proposed (`fix_loop_cap` shape, downgraded to M after checking ADR A5:105), 4 M | B=0 M=3 L=13 | M1-M8 plus 4 Lows fixed; 4 parts turned into owner questions | ISSUES (2 Low, carried forward) |
| 2 | 7 items (2 M: barrier lane release, already an OQ; runtime work_item fields) | B=0 M=1 L=6 | All fixed; 1 new owner question | CLEAN |
| 3 | 9 items (1 M: undefined `<k>` in id shapes) | B=0 M=0 L=4 | All 7 fixed (`<k>` plus 4 Lows, rule-9 wording, run.sh labels) | CLEAN |

## Key changes

**Round 1**
- **M1 `fix_loop_cap`:** declared once per wave everywhere. It is counted per wave in a barrier wave and per
  work_item in a frontier wave (A5).
- **M2:** a frontier wave is a wave with at least one edge. `depends_on: []` declares none.
- **M3:** the rule-15 not-enumerated fixture now uses per-work_item `depends_on` under a runtime-rule
  `work_items` value. `run.sh` detects that shape.
- **M4:** lane scope is "one run (one invocation of the skill)". Gate-pass lane release is limited to
  frontier waves.
- **M5:** a `step_complete` wave must enumerate its work_items. This is derived from rule 9 and tested by
  a new mutation case, so the test count went from 16/16 to 17/17.
- **M6:** agent ids are unique per agent and match `^[a-z0-9-]+$`. The record `tier` comes from `agents`.
- **M8, the stale-text class (the known follow-up):**
  - `waves/03-verify.md:10` no longer calls wave 3 "the terminal wave".
  - The README's outputs table, its "rules 1-11, 13-15" line and the `../../SKILL.md` link are corrected.
  - spec-format uses an `outputs: none` marker.
  - The architecture doc's description of the example now includes the build wave.
- **Lows:**
  - The `step_complete` pass now includes "and the exit_criteria hold".
  - Rule 11 in the architecture doc now includes `step_complete`.
  - The Operating Mode Gate name is used in place of `is_subagent`.

**Round 2**
- Per-work_item fields are declared on listed entries. Only rule 15 (edges) and rule 9 (`step_complete`)
  require a wave to list its work_items.
- Rule 9 now states the listing requirement itself.
- Rule 12 now refers to "rules 1-11 and 13-15".
- The role list now reads (worker, gate, fix).
- Gate ids take the form `<work_item>-gate<k>-<nonce>`.
- Barrier release is now subject to slot and lane admission.
- The "0 additional agents" aside is dropped.
- The bundle is described as the "legacy form (waves 1-3, no new fields)".

**Round 3**
- `<k>` is defined once in spec-format. The binding constraint is that ids are unique and match the charset.
- A bundle-level `output_topic` overrides the gate posting topic.
- The dispatch-record path is `dirname(<resolved bus_endpoint>)/dispatch/<invocation>.jsonl`.
- spec-format now gives the work_item entry shape and points to `waves/04-build.md`.
- Resume teardown is qualified to "no `bus_endpoint`".

## Owner questions (open; each needs behaviour that neither ADR 0054 nor INTERFACES states)

1. **Barrier-wave lane release.** In a barrier wave, when does a work_item stop holding its lane? The wave
   has only a wave gate, so releasing at gate pass would deadlock two work_items on the same lane.
   **Recommended:** release when no agent serving the work_item is live, that is, after its worker's
   completion post is counted (or its fix agent's, in a fix loop). Do not wait for the wave gate.
   Affects `SKILL.md` § lane (about lines 113-115), `frontier-mode.md` about lines 22-25, and `spec-format.md:104`.
2. **`unit` for a wave-level gate agent.** What value does the dispatch record carry in `unit` for a barrier
   wave's wave-level gate agent (`exit_criteria`, `adversarial_verify` or `judge_panel`)?
   **Recommended:** `wave-<N>`. This needs a change-control widening of the INTERFACES C1.1 `^[ui][0-9]+$`
   pattern. Delivery barrier waves use `step_complete`, so delivery runs never hit this case.
   Affects `frontier-mode.md` about line 43 and `spec-format.md` about line 160.
3. **`persona` in the record when none is declared.** What does a worker's dispatch record carry in
   `persona` when the work_item declares none? **Recommended:** `null`. Affects `frontier-mode.md` about line 43.
4. **`bus_endpoint` without the values it is checked against.** What happens when `bus_endpoint` is
   declared without a bundle `session_id` or `output_topic`, or when the `invocation` argument is absent?
   **Recommended:**
   - A missing bundle value halts at step 4, before any dispatch. The existing mismatch rule already
     implies this, and A9 adds no preflight rule for it.
   - A missing `invocation` is a `VALIDATION_FAILED` invocation-argument check at step 2.

   Affects `SKILL.md` about lines 70-72 and `spec-format.md` about lines 142 and 151.
5. **`persona`/`lane` on runtime-generated work_items.** Can work_items that a wave generates at runtime
   carry `persona` or `lane`? **Recommended:** no. They take the defaults (no persona, no lane constraint),
   and a wave that needs either lists its work_items. Affects `spec-format.md:99`.
6. **Advisory: lineage names.** Should the Provenance and lineage text naming "X-context-docs" and the
   "employer-specific 7-wave" origin stay in agent-hq? These names are not in the SUB list.
   Affects `SKILL.md` about line 304, and `architecture/wave-execution.md` lines 23-27 and about line 332.

## Notes for the integrator

- **The test count is now 17/17, not 16/16.** Round 1 added one mutation case. §9 accepts any `n/n`.
- **The task spec §2 anchor is wrong.** It cites "part A bus.endpoint", but `bus.endpoint` is defined in
  part D §D5. This is in the spec, not the item, so it was not edited.
- **The task spec §4 rule-15 row is incomplete.** It does not mention that a `step_complete` wave must also
  enumerate its work_items (that requirement comes from rule 9). Also a spec-side note, not edited.
- **`architecture/wave-execution.md:158` is dangling.** It cites `plans/dev-workspace-base-skills.md`, which
  is absent from the worktree. This is pre-existing; Low.
- **Other skills in the same worktree were being changed at the same time.** `doc-reviewer`,
  `fix-verifier` and `feature-change` are owned by other loops. The §9 scope-guard regex allows them.

## §9 result (non-author run by the round-3 verifier; orchestrator re-run identical)

```
EXT-09-OK
rc=0
```

`tests/run.sh` last line: `WAVE-EXEC-TESTS: PASS 17/17`. `SKILL.md` is 2818 words against the 3700 limit,
and its frontmatter has `version: 1.1.0`. `check-doc-length.sh` reports 0 blocking files.
