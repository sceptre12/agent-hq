# panel7 delivery-pipeline r3 s4 (crash and resume)

| id | sev | artifact file:line | defect | source file:line | fix |
|---|---|---|---|---|---|
| s4-1 | M | references/stages.md:103; SKILL.md:27 | POSTMERGE: FAIL re-entry has no handled marker; pm substate stays FAIL, read every tick; a crash between adding st<N> and the dispatch-plan call adds a second st<N+1> for the same new-units.md | interfaces/part-a-state.md:87; references/resume.md:36 | key re-entry on pm_sha (record it on st<N>); add st<N> only when no entry carries the current pm_sha, on tick and at resume |
| s4-2 | M | references/tick-relay.md:68; references/stages.md:87 | 5b precondition lacks "state pr-open and merge_sha empty"; row "pr set -> pr-open" is unconditional, so after DONE is applied the unchanged substate regresses merged to pr-open or restarts pr-approval-state/pr-merge for the merged head | interfaces/part-a-state.md:87; references/resume.md:13 | add the guard; make substate-to-state mapping forward-only except the A.2 back-edge |
| s4-3 | M | references/resume.md:14 | scan appends any pr-approval-state DONE h_pr true to gates.H-pr without sub-task, newest, or headRefOid == ci GREEN sha | references/stages.md:88; references/provenance.md:46 (29-12) | apply the 29-12 test and newest-per-sub-task rule |
| s4-4 | L | SKILL.md:29 (14(3)); references/resume.md:37 | crash mid final cleanup leaves a .tmp read as SPOT-CHECK FAIL (owner's word) while the stopped row re-runs once; no marker separates them | skills/delivery-cleanup/references/cleanup-record.md:13 | a .tmp without a SPOT-CHECK block is a crash: re-dispatch once |

Checked without finding: launch intent before exec (startup check recovers), RELEASE/RELEASE pm/MERGED/INVALIDATE re-derivation keys, back-edge single write, pr-merge DONE before merge-<sha>.md (scan + atomic rewrite), relay/carrier renames (same-id resend), REBIND gate, h1_handled order.

totals 0/3/1
