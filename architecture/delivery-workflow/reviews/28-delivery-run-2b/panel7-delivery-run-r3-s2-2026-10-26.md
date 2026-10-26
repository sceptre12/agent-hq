# delivery-run panel7 r3 seat s2 (COUNTERS AND CAPS)

| id | sev | artifact file:line | defect | source file:line | fix |
|---|---|---|---|---|---|
| s2-1 | L | skills/delivery-run/SKILL.md:58; references/ledger.md (Machine ledger row, "plus 31") | Machine admission sums other leads' CURRENT live_count (14 at start: 13 reserved + 1) plus 31, but each admitted lead can grow to 31 later and nothing re-sums at dispatch (10.2 checks the 30 only); with more than 6 leads the 200 sum is reachable by ordering. Practically bounded by rule 8 (3 build leads) so no B/M. | interfaces/part-a-state.md:230 ("summed before every launch against 200"); owner-decisions.md:5 (D4) | Optional: at 10.2 also re-sum machine rows under machine/.lock (others' live_count + this lead's post-dispatch count <= 200), wait on failure. |
| s2-2 | L | skills/delivery-run/references/ledger.md ("Who gets a row" table) | Table lists rows only for pre-pr-gate and ci-fix-loop agents; post-merge-verify runners, Test-adequacy seat and verdict agent (rows written by the lead, persona review-seat/validator, not under reserved review:10) are only covered by the generic "Before any lead-own or hosted dispatch" line. | skills/post-merge-verify/SKILL.md:41-42,85 | Add a table row for post-merge-verify agents (row, budget durations.pr_review_min). |

Checked and found consistent (no finding): free-slot formula and controller-row ordering (10.2 vs 10.5, A.4 :224), reserved sum 13 in live_count and machine admission (29-2), spawn check at 10.1 and mid-invocation (A.3 :166), shepherd reserved seat with spawn check, TaskStop'd rows staying counted until confirmed gone (tick.md step 9 CV24), re-dispatch only after the live invocation returns, Wave 0 rows and spawn counting, hosted-skill spawn headroom.

totals 0/0/2
