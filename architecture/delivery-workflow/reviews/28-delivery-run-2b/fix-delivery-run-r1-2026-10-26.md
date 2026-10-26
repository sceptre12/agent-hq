# delivery-run 2b, fix record round 1 (2026-10-26)

Input: `panel7-delivery-run-r1-2026-10-26.md` (APPROVAL BAR NOT MET 2/26/12). Fixer: separate Opus agent, not the author. Paths: S = skills/delivery-run/SKILL.md, H = references/handoffs-and-modes.md, T = references/tick.md, C = references/control-channel.md, L = references/ledger.md, V = references/verdicts.md, B = references/bus-and-ports.md, RS = references/resume.md. Line numbers are post-fix.

finding id | status | files:lines changed | what changed (one sentence)
---|---|---|---
PR1-C2a | FIXED | T:54; H:27 | The turn-close rule now cites `interfaces/part-c-waves-control.md:182` and `part-02-skill-inventory.md:62`, and the card 6 Stop cites `part-02-skill-inventory.md:60` (the Stop line is on :60, not :62).
PR1-C5a | FIXED | L:73; B:41; RS:26; C:73 | Each timing now carries its source: A.3 lock rule `part-a-state.md:186` (covers `machine/.lock`, 120 s, 1 s / 60 s), `swarm-communication/SKILL.md:88` (30 x 0.3 s), B1 `.out` polling `part-b-desk.md:22` (5 + 5 min).
R1-01 | FIXED | S:191-193; H:142 | `spec_root` is now the bundle root `PLANS_DIR/subtasks/<subtask>` (holds `bundle.md` and `waves/`), with the checkpoint in `PLANS_DIR/subtasks/.wave-execution-state/` (proposed CV20).
R1-02 | FIXED | S:170-177,214-219; H:24,27; T:24; H:143 | `fetch` and steps 10.1-10.8 now run before every invocation, and `phase: integrating` is set at the first `i<N>` dispatch-record line, because the controller rolls into `02-integrate.md` itself (proposed CV21).
R1-03 | FIXED | S:173-174; H:25 | Before the first invocation the lead checks that the `i<N>` form a `depends_on` chain or share one `lane`, else `stop_reason: human` (proposed CV21).
R1-04 | FIXED | S:170-172,208-212; H:29-33; V:56 | The loop ends on a return whose dispatch record has no line with every unit in `integrated` (W' "All passed"); otherwise a no-line return is `stop_reason: human`; no invocation starts while an escalation is open (proposed CV21).
R1-05 | FIXED | S:103-104; H:19,140 | The constitution path is now `PLANS_DIR/subtasks/<subtask>/constitution.md` (bundle root), including CV19's own text.
R1-08 | FIXED | S:226-229; T:57-64; L:66; H:38,73,144 | New "Hosted skills" rule: hosted Agent calls are own calls, run in the background and waited in 10-minute slices with the watchdog half between, hosted reserved-seat agents get a deadline, and ci `pending` is bounded (proposed CV22).
R1-09 | FIXED | S:62-63,70-72; T:8; C:48,55; H:145 | The tick is armed right after the machine row (bus steps skipped until `bus.endpoint`), and the register wait has a 20-minute bound ending in a `human-step` escalation and `stop_reason: human` (proposed CV23).
R1-11 | FIXED | S:179-183,162; T:25; L:42,86 | Lease and free-slot checks now precede the controller row and the `invocation` bump, a wait releases this pass's leases, and a tick step re-enters step 10 when no invocation is live (proposed CV21).
R1-12 | FIXED | S:133-135; T:16; H:130,145 | The unexecutable 12-minute probe is replaced: a `claude -p` lead runs the C1.1 blocking fallback from its start until PC-W2-7 is measured (proposed CV23, CV8 marked superseded).
R1-13 | PARTIAL | T:66-78; S:271-273 | A "Wait states" table now gives every wait's end, its `phase`/`stop_reason`, and the `agent-tool` mechanism. The `claude -p` mechanism for the RELEASE, ANSWER, MERGED and WAITING-HUMAN waits is named as owner question O5 and left undecided.
R1-14 | FIXED | S:159-160; T:38; H:146 | A controller `TaskStop` now runs a TaskList confirm, a sweep of every live row's worktree and lease, and rows stay `.row` until each agent is confirmed gone (proposed CV24).
R1-16 | OWNER | H:105 | Owner question O1, not decided. (interim, owner question O1): `release-track` is now called with `STAKES`/`CONTENTION`/`NOVELTY` only from an owner-named carrier; without one the lead prints `INPUT-ERROR <NAME> missing`, writes `stop_reason: human` and stops before `release-track`.
R1-17 | FIXED | H:103-104 | `post-merge-verify` now gets inline `WORKTREE_BASE` (profile `worktree_base`) and `REPO_PROFILE`. The lead's own pm worktree add is removed, because `post-merge-verify` Step 2 adds that worktree.
R1-18 | FIXED | H:106-107; H:154 | `POSTMERGE: FAIL` now has an end state (`phase: post-merge`, the lead's own cron released, other rows go to `final` cleanup, path printed; proposed CV32), and `POSTMERGE: STOP` leaves `postmerge` empty and writes `stop_reason: human` (AM-5 row 21).
R1-19 | FIXED | C:22-23,33 | The decided `verdict` inbox type (AM-5 row 21) is added for `pm`: the tick leaves it unconsumed, and the hosted `post-merge-verify` Step 10 renames it.
R1-20 | FIXED | H:108; T:76; H:147 | During `RELEASE: WAITING-HUMAN`, every tick now re-invokes `release-track` (Step 0 resume) (proposed CV25). The wait bound is left as owner question O6.
R1-21 | FIXED | S:233-235; H:43-50; H:148 | `PREPR: STOP` is now classified from checklist evidence (a `review-bus` refusal line, then a round-3 `verify-*-3.md`, else `stop-the-line:S2`) (proposed CV26).
R1-22 | FIXED | S:244-245; H:63; H:149 | Before relaying each `ci-fix-loop` push, the lead appends `push-head: <expect_head>` to `ci/<pr>.md`, so the desk's later-push precondition can be met (proposed CV27).
R1-23 | FIXED | S:255-257; H:72; H:150 | When the PC-W2-3 re-run moves the head again, the lead now later-pushes, re-runs `ci-fix-loop` and repeats, and a third cycle is `d7-round3` (proposed CV28).
R1-24 | FIXED | T:61; L:66; H:144 | Hosted Agent calls are now checked one by one against `cap - 5`; a dispatching agent needs `spawns + 11` headroom and adds its reported count afterwards; a mid-skill failure hands over (proposed CV22). No per-skill worst-case total is set, because no source gives one.
R1-25 | FIXED | S:52-53; L:40; H:103,151 | In `plan-pr`/`post-merge` the lead now writes the A.3 seed `reserved` map at step 2 and uses it in the formula and the machine row (proposed CV29).
R1-26 | FIXED | S:59-62; L:74,76 | The machine admission sum now counts 31 for the new lead (AM-5 29-2), and the row still carries the real `live_count`.
R1-27 | FIXED | S:76-78,271; C:24; RS:35; H:152 | After an `INVALIDATE`, only a `RELEASE` with a higher `<seq>` now starts the lead or clears `invalidate` (proposed CV30).
R1-28 | FIXED | S:108-110,114-115; RS:48; H:153 | On a resume, Wave 0 items already done are skipped, and an existing `bus.endpoint` takes the restart path with no new claim (proposed CV31).
R1-33 (L) | PARTIAL | S:163 | Fixed in the same edit at no cost: "wave-controller excluded" added to the shepherd threshold. The inbox-before-dispatch-record ordering part is left as it was.
R1-06 | OWNER | (none) | Owner question O2 (CV19 objection), not decided. Only CV19's wrong path was corrected (R1-05).
R1-07 | OWNER | S:106-108; H:11 | Owner question O3 (CV1 objection), not decided. The text now says the early tick cannot fire during a blocking Wave 0 call and names O3. No interim was added, because any interim would pick one of the owner's options.
R1-10, R1-15, R1-35..38 | OWNER | (none) | L-level objections (O4, O7, O8), not decided. With R1-09 the RELEASE wait is now covered by the tick, so O4's practical effect is reduced.
R1-29..32, R1-34 (L) | not touched | - | Lows not closed by an edit made for another row (brief rule).

## New proposed conventions
- CV20: `spec_root` = the bundle root `PLANS_DIR/subtasks/<subtask>`. The checkpoint then lives in `subtasks/.wave-execution-state/`.
- CV21: the invocation loop. Before each invocation: fetch, then 10.1-10.8. The `i<N>` serial check runs once. `phase: integrating` is set at the first `i<N>` line. No invocation while an escalation is open. The loop ends on a no-line return with everything integrated; any other no-line return is `human`. A wait releases leases and the tick re-enters the loop.
- CV22: hosted skills. Their Agent calls are the lead's own, run in the background and waited in 10-minute slices, and they get the `spawns + 11` headroom. Reserved-seat deadlines come from `durations.*`. The ci `pending` bound follows the post-merge-verify OQ-G precedent.
- CV23: the tick is armed after the machine row, with no bus steps before `bus.endpoint`. The register wait is bounded at 20 min. A `claude -p` lead uses the blocking fallback until PC-W2-7 is measured. This supersedes the CV8 probe.
- CV24: controller `TaskStop`. The lead confirms the stop in TaskList and sweeps every live row's worktree and lease. A row is freed only when its agent is confirmed gone.
- CV25: `pm` `WAITING-HUMAN`. Every tick re-invokes `release-track`.
- CV26: the `PREPR: STOP` classification: refusal line, then round-3 verify, else S2.
- CV27: the `push-head: <sha>` line in `ci/<pr>.md` before each `ci-fix-loop` push.
- CV28: the PC-W2-3 re-run cycle repeats until `ci` names `head`. A third cycle is `d7-round3`.
- CV29: the A.3 seed `reserved` map is written in `plan-pr`/`post-merge`.
- CV30: after an `INVALIDATE`, only a `RELEASE` with a higher `<seq>` counts.
- CV31: on a resume, Wave 0 items already done are skipped, and the bus takes the restart path.
- CV32: the `pm` end state on `POSTMERGE: FAIL`.

## Owner questions
- O1 (R1-16, B): where does the `pm` lead read `STAKES`, `CONTENTION` and `NOVELTY` for `release-track`? An interim fail-closed stop is in place.
- O2 (R1-06, CV19): how is the constitution agent's record verified as a C2 `PASS`?
- O3 (R1-07, CV1): how are the blocking Wave 0 agents bounded and observed?
- O4 (R1-10, CV15): should the RELEASE-wait cron be mandatory or optional? (The early tick of CV23 may make this moot.)
- O5 (R1-13): what is the wait mechanism of a `claude -p` lead for RELEASE, ANSWER, MERGED and WAITING-HUMAN?
- O6 (R1-20): who sets the bound on the `pm` WAITING-HUMAN wait?
- O7 (R1-15, CV13): is stopping the whole controller for one stalled agent the accepted convention?
- O8 (R1-35 CV7, R1-36 CV17, R1-37 CV16, R1-38 CV6): the four L-level convention objections.
- O9 (R1-01, integrator): AM-5 wording for INTERFACES C1 "a `waves/` spec_root", which CV20 reads as the bundle root.
- New, for the counterpart owners (integrator): `ci-fix-loop` Finish must keep the body lines when it writes `ci/<pr>.md` line 1 (CV27), and `pre-pr-gate` should fix its refusal-line text (CV26).

## Checks
- `bash SCRATCH/s9-28.sh`, last lines: `VERBATIM-OK`, `SKILL-28-OK`.
- `wc -w SKILL.md`: 3461 (cap 3700).
- Line counts: bus-and-ports 81, control-channel 82, handoffs-and-modes 164, ledger 100, resume 64, tick 92, verdicts 106.
- No file was added under the skill, `references/briefs/` and `references/templates/` were not touched, and nothing was git-added or committed.
