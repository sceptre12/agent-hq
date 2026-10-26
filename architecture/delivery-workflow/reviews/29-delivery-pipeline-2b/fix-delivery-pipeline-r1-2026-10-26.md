# Fix record R1: delivery-pipeline (W2 item 29), 2026-10-26

Input: `panel7-delivery-pipeline-r1-2026-10-26.md` (1 B, 29 FIX M incl. PR1-C1/C2/C5, 3 OWNER M) and `preround-delivery-pipeline-r1-2026-10-26.md` (C4, C7 are notes, not applied). Lows (l-01..l-17) not applied, per dispatch. Fixer: Opus, no sub-agents. Paths are relative to `skills/delivery-pipeline/`.

Most fixes are closed once, where the rule comes from, not at each site. Four derivation rules are in `SKILL.md:22` (R1-R4), with full text in provenance 29-13..29-16:
- R1: the launch intent is persisted before exec.
- R2: due inbox messages are re-derived from `state.md` on each tick and at resume.
- R3: every new stop is posted on the tick that finds it, and every wait ends the turn.
- R4: every conductor send has one no-reply rule, and nothing is sent before `REGISTERED run ok`.

| finding id | status | file:line after the fix | one-line change |
|---|---|---|---|
| PR1-C1 | FIXED | references/provenance.md:9 | Dropped the unresolved `:42-44` cite. The retro is now cited by name only. |
| PR1-C2 | FIXED | SKILL.md:10, :58; references/stages.md:9, :52, :54; references/launcher.md:3; references/provenance.md:20-21 | Added a `path:line` for each INTERFACES part and section and for D4/D5/D7/D16/D18/D19/D25/Q1/OQ-1, and the owner-decisions line pointers. |
| PR1-C5 | FIXED | SKILL.md:19, :41; references/launcher.md:26-27; references/tick-relay.md:53; references/stops-and-posts.md:73 | The cap of 200 points to D4. Marked as "default, proposed 29-2, owner to decide": seat count 31 and the build count. Marked as default: the 5+5 poll and the plan-plane commit human step. |
| r1-01 (B) | FIXED | references/stages.md:103; SKILL.md:25; references/provenance.md (29-19) | Before the second `pm` lead, the old `<run-id>-pm` worktree is removed with `delivery-cleanup MODE=subtask SUBTASK=pm`. Counterpart caveat: `delivery-cleanup` Step 0 (`skills/delivery-cleanup/SKILL.md:13`) asks for a terminal release record as `pm` evidence. If it refuses, the conductor posts the worktree path and catalog row as a human step and waits, so CYCLE DONE stays reachable through the owner. The panel's literal fix alone would hit INPUT-ERROR. |
| r1-02 | FIXED | references/stages.md:99; SKILL.md:19, :25 | `pm` REPO = `primary_repo`, BACKEND = the `st0` backend (29-19). |
| r1-03 | FIXED | references/stages.md:102; references/tick-relay.md (§5 table); references/stops-and-posts.md (stops table); SKILL.md:25 | While `postmerge` is empty, read `postmerge-<pm_sha>.md` line 1. On `POSTMERGE: STOP`, post the reason, the path and the `H-destructive.<row-id>` GATE line, with no ticket event, then wait. |
| r1-04 | FIXED | references/stages.md:55; SKILL.md:17; references/resume.md:24 | `h1_handled` (name + `utc=`) is recorded before re-invoking. H1 is pending again only when the live file differs (29-17). |
| r1-05 | FIXED | references/stages.md:87-89; SKILL.md:23 | The merge precondition and `predecessors[]` are now every sub-task with a lower `merge order` (`st0` first). `RELEASE` stays on `depends-on` (29-18). |
| r1-06 | FIXED | references/tick-relay.md:102 (+4b at :20); references/resume.md (step 9); SKILL.md:22 (R2) | Due `RELEASE`/`MERGED`/`INVALIDATE` are re-derived on each tick and at resume. Stages 5b and 6 no longer write `RELEASE` themselves (29-14). |
| r1-07 | FIXED | references/tick-relay.md:101; SKILL.md:21 | The back-edge writes `reentered: true`, `state: building` and the cleared `merge_sha` in one write. `INVALIDATE` is re-derived from `reentered` and sent only to released successors (29-14). |
| r1-08 | FIXED | references/tick-relay.md:84; references/launcher.md (Catalog row, pid file); SKILL.md:22 (9f) | Startup check for a launched lead with no lock, no `register.consumed` after 10 min (default) and a dead `homes/<session>/pid`: post `lead.log` and allow one relaunch (29-13). |
| r1-09 | FIXED | references/launcher.md:28 (step 5), :62; references/resume.md (step 10); SKILL.md:19, :22 (R1) | `session`, the release and `relaunch_phase` are written before exec. A sub-task with `session` set counts as launched at resume (29-13). |
| r1-10 | FIXED | references/resume.md:47-48; SKILL.md:24 | The relaunch count comes from `-l<n>`, with the baseline `relaunch_phase` stored before exec. A sub-task with a live row is skipped. A second death is posted with its paths. Spawn-cap counts the same way (29-13). |
| r1-11 | FIXED | references/tick-relay.md (step 0); references/resume.md:18-19 | Tick step 0 send gate: nothing is sent, relayed or renamed before `REGISTERED <run-id> \| run \| ok` (29-16). |
| r1-12 | FIXED | references/resume.md:24-33 (table); SKILL.md:15 | Per-stage re-entry predicates: a stage skill is skipped when its exit artifact exists. `repo_profile` is re-derived from the profile file (29-17). |
| r1-13 | FIXED | references/tick-relay.md:3, :20-24, step 10; references/stops-and-posts.md (Status post); SKILL.md:22 (R3, 9i) | Defined the tick prompt. Every wait posts and then ends the turn. The tick continues stages, launches ready sub-tasks, runs the 5b check and posts new items (29-15). |
| r1-14 | FIXED | references/stages.md:65; SKILL.md:18 | Before the first launch, check the plan's review section for open B/M findings at round 3; that is a D7 stop (29-23; the counterpart marker is a question). |
| r1-15 | FIXED | references/stages.md:110; SKILL.md:27; references/stops-and-posts.md (Capture line) | `capture/read-back.md` line 1 is `READ-BACK: pass\|<n> differences`. One fix and re-run, then the owner (29-24). |
| r1-16 | FIXED | references/tick-relay.md:48-53 (§4) | One no-reply rule now also covers relayed `CONDUCTOR-REQUEST`s and `REGISTER-SENDER`. A terminal REJECTED `.out` is posted (29-16). |
| r1-17 | FIXED | references/tick-relay.md:74 (§3); references/resume.md (step 8) | An orphan own `.req` with the same verb and fields is adopted before a new id is minted. Resume re-attaches only a `.req` that a record or carrier owns (29-16). |
| r1-18 | FIXED | references/resume.md:15; references/tick-relay.md (§4); references/stages.md:87 | Resume re-posts terminal `pr-merge` REJECTED and `.req.noreply`. The file is the 5b block marker for that `head` (29-16). |
| r1-19 | FIXED | references/stops-and-posts.md:13; SKILL.md:22 (9h) | The post gives each sub-task waiting for e2e the exact `GATE <run-id> H-e2e.<subtask> ok` line and the `.feature` list path. |
| r1-20 | FIXED | references/stops-and-posts.md:37; references/tick-relay.md (4d); SKILL.md:22 (9i) | `unblocked` is appended once when a blocking item the previous post listed is gone (29-15). |
| r1-21 | FIXED | references/stops-and-posts.md:71; SKILL.md:27 | The final post leads with the release verdict and, on ROLLED-BACK, the rollback evidence. The `done` event is left as owner question O-3. |
| r1-22 | FIXED | references/stages.md:103; SKILL.md:25 | `st<N>` takes the failed gating sub-task's ticket key, else the epic key (29-20). |
| r1-23 | FIXED | SKILL.md:16; references/tick-relay.md (§4); references/resume.md:19 | Wait for `REGISTERED run ok` before intake. Every REGISTER-SENDER follows the 5+5 no-reply rule and is then posted (29-16). |
| r1-24 | FIXED | references/launcher.md:26-27; SKILL.md:19 | Launched entries with no row yet count 31 (and build=1) in the ledger check (29-13). |
| r1-25 | FIXED | references/launcher.md:45, command shape (`cd`) | The conductor adds the sub-task worktree and its catalog row before the scrub. The child's cwd is that worktree. `pm` is exempt (29-22). |
| r1-26 | FIXED | references/launcher.md:42; SKILL.md:19 | The network-write list comes from `$DELIVERY_ROOT/launcher/disallowed-tools.txt`. If it is absent: `INPUT-ERROR launcher.disallowed_tools missing` (29-21). |
| r1-27 | FIXED | references/tick-relay.md:74, :84; references/resume.md (relaunch); SKILL.md:22 (9f) | A `pm` with FAIL, STOP or a terminal release is never relaunched. `CLEANUP DONE pm` counts only with a terminal release (29-19). |
| O-1 | OWNER | references/provenance.md:39 (29-5 unchanged) | Not resolved. |
| O-2 | OWNER | references/provenance.md:40 (29-6 unchanged) | Not resolved. The tick dead-lead set is unchanged (`merged` not added). |
| O-4 | OWNER | references/stops-and-posts.md (D7 bullet unchanged) | Not resolved. |
| O-3, O-5, O-6 | OWNER (L) | - | Not resolved. O-3 is named in the final-post text as an owner question. |
| l-01..l-17 | not applied | - | Lows, per dispatch. Exceptions: r1-08 needed the l-15 pid file, and r1-12 covers part of l-02 (stage 8 predicate). |
| n-1..n-4, preround C4, C7 | NOTE | - | Outside fixer scope. |

## Owner questions
- O-1 (M, OBJECTION 29-5): before the `pm` relaunch, should the finished `pm/` dir be renamed, or should delivery-run add "`PM_SHA` differs from `pm_sha`: re-initialise"? Who owns it?
- O-2 (M, OBJECTION 29-6): should the dead-lead check over `merged` not yet `cleaned` also run on the live tick, not only at resume?
- O-4 (M): how does a human clearing decision reach a stopped lead (a new inbox type, or a relaunch brief with the grant), and who clears `stop_reason`?
- O-3 (L): does a rolled-back release mark the tickets `done`?
- O-5 (L, OBJECTION 29-3): should `planned` and `released` (no `substate.md`) map to stage 4, and should `stopped` be skipped for the stage minimum?
- O-6 (L, OBJECTION 29-11): for `security_sensitive`, should a bad value be `enum` and two lines be `format`?
- Raised by this fix (r1-01): `delivery-cleanup` `MODE=subtask SUBTASK=pm` asks for a terminal release record as evidence. Should it accept a `POSTMERGE: FAIL` record, so the stale `pm` worktree can be removed before a second `pm` lead without a human step? (Counterpart owner to decide.)
- Raised by this fix (r1-14): `delivery-dispatch-plan` should name a stable marker for "round 3 with open B/M" in its review section (counterpart question).

## New proposed conventions
All rows are in references/provenance.md §Conventions pending INTERFACES, :48-59.
- 29-13: launch intent before exec. Stored launch count and `relaunch_phase`, the ledger counts pending launches, startup-failure check, second-death post.
- 29-14: due `RELEASE`/`MERGED`/`INVALIDATE` re-derived from `state.md` on each tick and at resume; `reentered` flag.
- 29-15: tick prompt; every wait posts and ends the turn; new items posted on the tick that finds them; `unblocked` detection.
- 29-16: one no-reply rule for every conductor send; orphan `.req` adoption; REJECTED/noreply as the 5b block marker; send gate before `REGISTERED run ok`.
- 29-17: stage re-entry predicates; `h1_handled` marker.
- 29-18: merge-order predecessors for 5b and `predecessors[]`.
- 29-19: `pm` host (`repo`/`backend`, cleaned only after a terminal release, no relaunch after FAIL/STOP/terminal, stale-worktree removal or human step).
- 29-20: `st<N>` ticket key.
- 29-21: network-write tool list file.
- 29-22: the conductor adds the sub-task worktree; child cwd.
- 29-23: stage 3 round-3 review-section detection.
- 29-24: `READ-BACK:` verdict file.

New `state.md` fields proposed (not in the frozen template): `relaunch_phase`, `reentered`, `h1_handled`.

## Checks
- `cd W && bash SCRATCH/s9-29.sh`: last line `PIPELINE-29-OK`. None of MISSING/UNLINKED/NO-USE-WHEN/D16-VIOLATION/LENGTH-FAIL/BODY-OVER-BUDGET/TEMPLATES-TOUCHED/EXTRA-OR-MISSING-FILE/RULE-MISSING.
- `bash tools/check-doc-length.sh .`: 0 blocking. Reference files total 471 lines; the largest is under 130.
- `wc -w SKILL.md`: 3607 (at most 3800).
- `git status`: only the 7 skill files modified; templates untouched.
