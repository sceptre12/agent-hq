# r3 s1 cold conductor walkthrough
| id | sev | artifact file:line | defect | source file:line | fix |
|---|---|---|---|---|---|
| s1-1 | M | references/tick-relay.md:74; SKILL.md step 9g; references/stages.md:103,107 | pm is marked cleaned from any `cleanup-<run-id>-pm.md` `CLEANUP DONE pm` once release_record is terminal; the POSTMERGE FAIL re-entry runs `delivery-cleanup MODE=subtask SUBTASK=pm` itself, leaving that same file, so the second pm lead counts as cleaned before its own cleanup runs and CYCLE DONE (2)/final cleanup proceed over a live pm worktree | skills/delivery-cleanup/references/cleanup-record.md:3,15 | count the pm record only when newer than the current pm `launched_utc` |

Walkthrough INTENT->CYCLE DONE and one POSTMERGE FAIL re-entry otherwise defined (L only: no tick trigger lists the step 14 entry explicitly; step 9i generic wording suffices).

totals 0/1/0
