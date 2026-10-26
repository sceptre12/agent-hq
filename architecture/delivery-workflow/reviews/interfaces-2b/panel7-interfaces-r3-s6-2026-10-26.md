id | sev | artifact file:line | defect | source | fix
s6-1 | M | part-a-state.md:207,213 | resume "marks catalog rows stale" but no stale state/subcommand exists | part-03:90 | define stale marking or use audit + released/failed only
s6-2 | M | part-a-state.md:213,233 | lane-lease / gate-runner leases leak on crash; no reclaim at resume | part-c:137 | add lease-reclaim step, name releaser
s6-3 | M | part-c:118 | old register.consumed survives lead hand-over; new lead's DESK rejected sender | part-b:16,22 | fresh register on every lead start
s6-4 | M | part-b:37,63 | crash between mkdir .inflight and target write; no rule, no cleanup | part-b:63 step 9 | derive target from .req; state inflight removal
s6-5 | M | part-c:116 | inbox seq O_EXCL cannot work with utc in filename; order by utc not seq | part-c:118 | explicit seq marker file; order by seq
s6-6 | M | part-a-state.md:80,85 | no back-edge after merged/cleaned; re-entry after MERGED/cleanup undefined | part-01:75,81,83 | re-entry = new sub-task id via pm/new-units.md
s6-7 | L | part-b:22 | .req.noreply terminal but late .out never read | part-b:37 | scan .out for noreply ids
s6-8 | L | part-a-state.md:14 | run-id mint not mkdir-claimed | part-a:14 | mkdir claim, next suffix
totals B/M/L 0/6/2
