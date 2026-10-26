# Panel7 delivery-run r1 s1 (cold lead)

id | sev | artifact file:line | defect | source file:line | fix
---|---|---|---|---|---
s1-1 | M | SKILL.md:198-200; handoffs-and-modes.md:24 | fetch must precede the invocation that runs 02-integrate.md, but the engine has no wave-range argument, so nothing stops an invocation after 01-build | W' wave-execution/SKILL.md:28-32; part-c-waves-control.md:19-23 | fetch before every invocation, or name the stop mechanism
s1-2 | M | SKILL.md:70-72; control-channel.md:54 | RELEASE wait has no mandatory wake/bounded wait for claude-p; tick armed only at step 9 | control-channel.md:35; tick.md:8 | mandatory inbox cron for the wait
s1-3 | M | SKILL.md:155-156 | loop exit with all remaining units escalated/blocked leaves substate undefined and no statement of waiting on ANSWER | handoffs-and-modes.md:24; part-a-state.md:169 | define the waiting state
s1-4 | M | handoffs-and-modes.md:93-94 | pm: WORKTREE_BASE, REPO_PROFILE (post-merge-verify) and STAKES/CONTENTION/NOVELTY (release-track) not passed or sourced | post-merge-verify/SKILL.md:13-17; release-track/SKILL.md:17-20 | name sources and pass them
s1-5 | M | handoffs-and-modes.md:95; SKILL.md:86-88 | POSTMERGE: FAIL ends with no phase/stop_reason and no cleanup; cron/worktree/lock left | delivery-cleanup/SKILL.md:7,10 | define FAIL end state
s1-6 | M | SKILL.md:231-238,267-280 | done-detection (CLEANUP DONE line 1, phase: done, lock release) only in the reference; no exit criterion | handoffs-and-modes.md:74; delivery-cleanup/SKILL.md:13 | add to step 15 and exit criteria
s1-7 | M | SKILL.md:198-235 | hosted skills run in the lead's turn with no call model; tick cannot fire while blocked, so their agents are unobserved | part-c-waves-control.md:186; tick.md:20,52 | run as background tasks or bound the wait
s1-8 | M | SKILL.md:94-100 | OBJECTION CV1: Wave 0 blocking agents with no tick; stalled baseline gate unobserved | tick.md:8 | arm tick before Wave 0 or bounded wait + TaskStop
s1-9 | L | SKILL.md:90-93,214 | worktree_base, pr-create labels[], pr-comment body format have no named source | dispatch-plan.md template P3; verbs.md:61 | name sources

totals 0/8/1
