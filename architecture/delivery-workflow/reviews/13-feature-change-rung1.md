# Item 13 `feature-change` EXTEND: Rung 1 loop record

- **Artifact:** `skills/feature-change/SKILL.md` and `skills/feature-change/references/team-mode.md`, in worktree `~/projects/agent-hq-worktrees/delivery-extends`, branch `ext/delivery-extends`. Base commit 4a46616; the round 1 and 2 fixes are uncommitted, and Worker1 commits them.
- **Spec:** `architecture/delivery-workflow/tasks/13-feature-change.md` (W).
- **Loop:** one orchestrator (D35), and a separate agent for every role and round:
  - G48 pre-round screen: Haiku.
  - Review: Sonnet, running the installed, unmodified `doc-reviewer` (M29).
  - Fix: Opus, never the author.
  - Fix-verify: Sonnet, running the installed, unmodified `fix-verifier`.
  - §9 fixture dry run: a separate non-author Sonnet verifier, which dispatched one unit agent.
- **Round cap:** 3 (D7).
- **Date:** 2026-10-26.
- **INTERFACES:** the brief named 1.2.0. AM-3 (1.3.0, W commit 8cba98e) landed during round 1. AM-3 does not list `feature-change` as a consumer. The round 2 fixer re-checked every anchor against 1.3.0, and `team-mode.md` now cites 1.3.0.
- **Deviation:** in round 1 the G48 screen ran in parallel with the review rather than strictly before it. Both sets of hits went to the fixer together.
- **Working files:** in the orchestrator's scratchpad (`loop13/`): pre-round, review, fix, fix-verify and fixture notes for each round.

## Result

**Stopped after round 2 at B=0 M=0 L=7. The final fix-verify was CLEAN. §9: `EXT-13-OK`, exit 0.**

| Round | Pre-check (G48) | Review | Fix | Fix-verify / §9 |
|---|---|---|---|---|
| 1 | 2 Blocking (unit vs lead worktree add, C1 Wave 0; COMMON block `HUSKY=0` on commit), about 9 Medium | B=4 M=7 L=3 | all B/M fixed or turned into owner questions OQ-13-1..8 | fix-verify ISSUES B=0 M=1 L=3. §9 fixture `EXT-13-OK`, exposing 1 Medium and 4 Low |
| 2 | 10 hits. 3 rejected by the orchestrator: the version claim, the "no one retry" claim and the `WORKTREE_BASE` claim; INTERFACES is 1.3.0 and states all three | B=0 M=4 L=10. The fixture Medium was reclassified Low (R2-5): A.6 builds unit and sub-task branches from distinct tickets | all Medium closed, OQ-13-9..11 added; the cheap Lows fixed | fix-verify CLEAN B=0 M=0 L=2. §9 fixture `EXT-13-OK`, 3 new Lows |

## The three known §9-verifier defects in `references/team-mode.md`, as resolved
1. **ROLLED vs ESCALATE, and "gate runner absent":**
   - A failure table now maps every failure path to one (verdict, reason) pair. It uses only the C2 closed set and the C2 pairing: `PASS` takes `none`; `ROLLED` takes `budget`, `lane-unavailable`, `env-bug` or `merge-conflict`; `ESCALATE` takes any other code.
   - Every row has a determinable 40-hex `head`.
   - A missing `gate-runs/<head>.md` is never `PASS`. It follows `ESCALATE` `contract-gap` until the owner answers OQ-13-1. INTERFACES has no gate-specific code, so no new code was invented (spec §11).
2. **Bus transport:**
   - The post uses the existing `swarm-communication` `broadcast` tool over `POST /mcp`. The skill links to that skill and adds no bus client (spec §3).
   - The port is read from `$data_dir/port` (D5 / ADR 0054 A9). Before posting, the skill runs a `/health` identity check: `data_dir`, and `app_name` = `pm2_app`.
   - `from_agent` = `AGENT_ID`, the dispatch-record id (C1.1, C2). `session_id` is passed explicitly.
   - Success means `status:"sent"` only. Anything else uses the C4 `.verdict` fallback with no re-send. The unit never starts or restarts the bus (C1.1).
3. **catalog.sh arguments, order and NEXT `<n>`:**
   - Full values per the script table and the A.5 handle grammar:
     - worktree: `"$WT#$REPO@$SUBTASK_BRANCH"`
     - branch: `"$REPO#$BR@$SUBTASK_BRANCH"`
     - `correlation_id` = `KEY`; `source` = `feature-change`; `owner_agent` = `AGENT_ID`.
   - `RUN_HOME` and `WORKTREE_BASE` are set inline on each call.
   - Order: register branch, register worktree, `git worktree add -b`, start branch, start worktree.
   - Case B covers a worktree the lead already added in Wave 0 (C1). Case C covers resume after a `ROLLED` re-dispatch: an idempotent re-entry that follows the A.5 supersede key and never re-registers a live row.
   - NEXT is written `NEXT: <unit>.<n>` (the round 1 form `u<unit>` produced `uu1`). `<n>` is the step number in the `.tasks` §9 list per C3, and `0` before the first step. Skipped feature-change steps write nothing.

## Final §9 (spec block verbatim, `FIXTURE_DIR` = the round 2 verifier's results dir)
```
stdout: EXT-13-OK   stderr: empty   exit code: 0
```
- **Fixture:**
  - A 1-AC toy repo with `UNIT_MODE=team`, a stub `RUN_HOME`, and a `bus.endpoint` pointing nowhere.
  - `catalog.sh` does not exist yet, so a test double wrote the 12-field A.5 rows. Only the argument shapes were exercised.
  - The unit ran at depth 3 with no Agent tool. It ended `ESCALATE` `contract-gap` through the `.verdict` C4 fallback.
  - Not exercised: the PASS path, Cases B and C, the real `catalog.sh`, a reachable bus.
- **Review-time check:** no push, no ticket or desk call, no worktree removal. PASS in both rounds.
- **Static lines** (solo diff 0 removed lines, `version: 1.1.0`, anatomy, forbidden grep, EXTEND-scope porcelain): pass. `check-doc-length.sh`: 0 blocking.

## Open Lows (not fixed; for the integrator)
- FV2-1: Case C does not say what to do with uncommitted edits left by a predecessor that ran out of budget.
- FV2-2: on Case C re-entry NEXT restarts at `<unit>.0`, which the shepherd may read as a regression.
- Fixture r2 D6: the Agent-tool probe runs after Step 2, so a unit with no Agent tool registers and adds a worktree before it escalates.
- Fixture r2 D7: no NEXT text is given for an early escalate.
- Fixture r2 D8: the C4 fallback does not say to create `status/` if it is missing.
- Fixture r2 unit slip: the unit agent named its branch `ABC-2-toy`, but the `$KEY-$SLUG` rule gives `ABC-2-toy-add`. Recorded as an agent error; a worked example in team-mode.md would help.
- Spec defects outside this item: spec 13 line cites are stale (D2.3 "line 102", C2 "lines 56-84", A.7 "lines 308-325", A.6 "line 306"), and spec 13 cites "AM-2 row 16", which does not exist.

## Owner questions (each with a recommended answer; the skill follows the path in the right column of `team-mode.md` §Open owner questions until answered)

| Id | Question | Recommended answer | Why INTERFACES 1.3.0 does not decide it |
|---|---|---|---|
| OQ-13-1 | C2 reason when `gate-runs/<head>.md` is absent at unit end | `ESCALATE` `contract-gap` | A.7 writes the file only on a pass and names no reason; C2 has no gate code |
| OQ-13-2 | How a unit requests the gate runner, and how long it waits | the lead dispatches the runner per unit head (it holds the `gate-runner/<n>` lease) when the unit's NEXT line signals a gate request; the unit waits up to its budget, then OQ-13-1 | A.7 gives writer, cadence, command and lease, but no request channel; spec §3 forbids the skill creating one. **Until answered, every team unit ends ESCALATE unless a runner file already exists for its head.** |
| OQ-13-3 | `head` of a record posted with no unit worktree | `git -C $REPO rev-parse $SUBTASK_BRANCH` | C2 defines `head` only as the unit worktree head |
| OQ-13-4 | Who adds the unit worktree: the lead in Wave 0 (C1) or the unit (spec §8 AC3) | the lead (C1, frozen later); the unit registers only the branch row (Case B) | C1 and spec AC3 contradict each other; the skill handles both |
| OQ-13-5 | Unit branch start point and A.5 `<base>` | brief field `SUBTASK_BRANCH` (dispatch-plan sub-task `branch`); its tip; never `origin/main` | no contract names the unit start point or a brief field for it |
| OQ-13-6 | Brief field names beyond `UNIT_MODE` (`RUN_HOME`, `RUN_ID`, `SUBTASK`, `UNIT`, `AGENT_ID`, `REPO`, `SLUG`, `TASK_FILE`, `REPO_PROFILE`, `SUBTASK_BRANCH`) | confirm them as the unit-brief names that `delivery-run` and item 27b pass | D2.3 lists only `UNIT_MODE`; D1 and D2.2 require exact names |
| OQ-13-7 (cross-item) | The COMMON block (part-03 §3.0) tells units to commit with `HUSKY=0`; A.7 limits it to desk pushes and PR creation | amend the COMMON block to link A.7 instead of restating it; the skill follows A.7 | conflict sits in part-03 / item 27b, outside this item |
| OQ-13-8 (cross-item) | C1.1 says depth-2 agents "none of which dispatches", but a team unit needs a distinct verifier at depth 3 | erratum to C1.1: allow one level of non-dispatching sub-agents (measured limit 3) | C1.1 vs spec §8 AC6 |
| OQ-13-9 | Reason at the D7 round cap (AC not met, or review B/M still open) | `fix-loop-cap-exhausted` (provisional; same lead action as any ESCALATE) | C2 defines it as a lead-side code; spec §4 omits it |
| OQ-13-10 | Reasons for a non-lane port refusal (candidate plus its one +10 retry, or `port-check.sh` exit 3) and for a `catalog.sh` lock timeout | `ESCALATE` `human-step`; `ROLLED` `env-bug` | A.5.2 maps only lanes (`lane-unavailable`); C2 ties `env-bug` to the e2e writer |
| OQ-13-11 | Arrival duty (Rule 6) in team mode | surface-only (read-only, reported, never fixed, never a stop), or skip it | INTERFACES and the design are silent for depth-2 units |
