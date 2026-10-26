# Fix record, round 3 (FINAL, D7), delivery-pipeline (W2 item 29), 2b review-7-panel

Input: `panel7-delivery-pipeline-r3-2026-10-26.md` (0/15/5; 14 FIX M including PR3-C5, s7-4 OWNER). Fixer: Opus, did not author the skill. Lows (s3-2, s4-3, s4-4, s6-4, s6-5) not applied: the dispatch prompt names only the M rows. Paths are under `skills/delivery-pipeline/`.

| finding id | status | file:line after the fix | one-line change |
|---|---|---|---|
| PR3-C5 | FIXED | references/resume.md:20, :33; references/stages.md:56; references/tick-relay.md:106; SKILL.md:26 | Tagged: REBIND wait `(default)`; stage 3 row `proposed 29-23/29-29/29-34`; H1.reject resume `(proposed 29-30)`; inbox `Order (default)`; stop clearing `(default; ... owner to decide)`. |
| s1-1 | FIXED | references/tick-relay.md:74; references/stages.md:104; SKILL.md:27; references/provenance.md:67 | `CLEANUP DONE pm` counts only with a terminal release and a cleanup record newer than the current `pm` `launched_utc` (29-32). |
| s3-1 | FIXED | references/stops-and-posts.md:51-53, :64; references/tick-relay.md:56; references/stages.md:91; SKILL.md:25 | Every own/relayed `REJECTED` (terminal or curable) is posted with code, class, `detail`, `.out`; curable resend once per cause on a stated trigger (marker: head/record changed; order: predecessor merged; action-failed/stale-session/gate-missing: owner's word); blocks 5b until then (29-33). |
| s3-3 | FIXED | references/stages.md:64; references/resume.md:33; SKILL.md:18 | Resume at stage 3 with `PLAN-CHECK: <n> findings` or the plan's round-3 stop record re-posts and waits; re-invoke only on the owner's word (29-34). |
| s3-4 | FIXED | references/tick-relay.md:80; references/provenance.md:70 | Key rule for unit `-` records (sub-task's plan `ticket`, `pm` the epic key); such a record is open only while `stop_reason`/`state: stopped` stands (29-35). |
| s4-1 | FIXED | references/stages.md:103; SKILL.md:27; references/provenance.md:71 | FAIL re-entry handled once per `pm_sha`: `st<N>` records `pm_sha` in the write that adds it; re-entry runs (tick and resume) only when no entry carries the current `pm_sha` (29-36). |
| s4-2 | FIXED | references/tick-relay.md:62, :68; references/stages.md:87; SKILL.md:24, :25; references/provenance.md:72 | One forward-only substate->state mapping rule, A.2 back-edge the only exception; `pr` row only from `released|building`; 5b precondition adds `pr-open` with `merge_sha` empty (29-37). |
| s5-1 | FIXED | references/stages.md:103; SKILL.md:27; references/provenance.md:55 (29-20 rewritten) | After the dispatch-plan call, `st<N>`'s key is read from the plan's `ticket`; no second key derived. |
| s6-1 | FIXED | references/stops-and-posts.md:27; references/tick-relay.md:70; SKILL.md:26 | Every `human` stop post names `homes/<session>/lead.log` and `RUN_HOME/<subtask>/substate.md` (default). |
| s6-2 | FIXED | references/tick-relay.md:70, :73, :86; references/stops-and-posts.md:27; references/resume.md:51; SKILL.md:26; references/provenance.md:66 (29-31 amended) | `pm` `human` without a `POSTMERGE: STOP` record -> `stopped`, posted with paths, skipped by the dead-lead check. |
| s6-3 | FIXED | references/stages.md:65; references/resume.md:33; SKILL.md:18 | New stage 3 row: dispatch-plan stop without `plan-check.md` is posted (missing key or clash) and waits; intake re-run, profile refresh, H0 re-ask on the owner's word (29-34). |
| s7-1 | FIXED | references/launcher.md:26; SKILL.md:19; references/provenance.md:73 | A lead row counts max(31, `live_count`) until its pid is dead or, for this run, `CLEANUP DONE <subtask>`; a row-less live launch 31 (29-38). |
| s7-2 | FIXED | references/launcher.md:46 | Full worktree `register` (7 args) and `start` with `RUN_HOME` and `WORKTREE_BASE` inline (29-22, 29-39). |
| s7-3 | FIXED | references/launcher.md:47, :52-68 | Detached background subshell registers `$BASHPID`, writes `homes/<session>/pid`, `exec`s `env -i ... claude` with stdin from a 0600 prompt file; all fds redirected (29-39). |
| s7-4 | OWNER | references/launcher.md:46 (text unchanged) | Left as is per dispatch. |

SKILL.md trims to stay at budget (no rule dropped; each now lives only in the reference it pointed to): step 2 applied-result scan and REBIND detail (resume.md steps 4, 7), step 11 `blocked` set wording (stops-and-posts.md §blocked set), step 13 post contents (stops-and-posts.md §Status post), step 14 final human steps (stops-and-posts.md §Final post).

## Owner questions
- s7-4 (OBJECTION-type): may a `pm` lead start with cwd `primary_repo` (main checkout) given "dedicated worktree per process" and G1, or must it launch from a conductor-added detached worktree?
- s3-1 / s3-3 / s6-3: the "owner's word" triggers (curable `action-failed`, `stale-session`, `gate-missing` resend; stage 3 re-invoke after a D7 stop; intake re-run after a dispatch-plan stop) are skill defaults, not owner decisions made.
- 29-38: whether the max(31, `live_count`) floor should apply to other runs' lead rows identified only by session-token shape.
- Known owner questions not re-raised (per synthesis): OBJECTION 29-5, 29-6, stopped sub-task exit, cleanup refusing on a POSTMERGE FAIL run, dispatch-plan round-3 marker, spec at INTERFACES 1.3.0, `H-destructive` GATE grammar, `ref=` not compared.

## New proposed conventions
29-32 (pm cleanup freshness), 29-33 (REJECTED posting and curable resend triggers), 29-34 (stage 3 stops and resume), 29-35 (non-unit escalation key and openness), 29-36 (FAIL re-entry once per `pm_sha`), 29-37 (forward-only state mapping), 29-38 (ledger max(31, live_count)), 29-39 (detached launch wrapper, catalog calls). Amended in place: 29-20 (key read from the plan), 29-31 (`pm` human without STOP record -> stopped). All in references/provenance.md §Conventions pending INTERFACES.

## Checks
- `bash SCRATCH/s9-29.sh` (from W): last line `PIPELINE-29-OK`; no MISSING/UNLINKED/NO-USE-WHEN/D16-VIOLATION/LENGTH-FAIL/BODY-OVER-BUDGET/TEMPLATES-TOUCHED/EXTRA-OR-MISSING-FILE/RULE-MISSING lines; `peek:true` absent.
- `wc -w SKILL.md`: 3799.
