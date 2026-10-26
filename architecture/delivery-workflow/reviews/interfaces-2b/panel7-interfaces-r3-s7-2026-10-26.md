# panel7 interfaces 2b, round 3, seat s7 (cold implementer)

Paths below are relative to architecture/delivery-workflow/interfaces/ unless noted.

| id | sev | artifact file:line | defect | source | fix |
|---|---|---|---|---|---|
| s7-1 | M | part-d-enums-topics.md:70,73,78,80 | D2.2 names no run-addressing input (RUN_HOME, run-id, subtask, head, pm_sha) for intake, dispatch-plan, pre-pr-gate, post-merge-verify and gives prose, not field identifiers, though Step 0 (part-d:8) needs field names | part-02-skill-inventory.md:50,54; part-a-state.md:244,250,257 | identifier-named inputs per skill, incl. RUN_HOME and subtask |
| s7-2 | M | part-a-state.md:241,13-15,95 | intake writes plans/<epic>/ but no epic exists at stage 1; plans_dir is conductor-written; intake input is raw intent only | part-a-state.md:13,15; part-d:70 | conductor creates plans_dir and passes it to intake |
| s7-3 | M | part-a-state.md:242; part-d:70,136 | repo-profile.md location "per its header" (new profile has none); no token returns path@sha for state.md repo_profile | part-a-state.md:63 | add a PROFILE token or fix the path |
| s7-4 | M | part-d:70; part-b-desk.md:156 | nobody named as the one asking the human to type GATE H0; intake "confirm question" vs H0 unclear | part-02-skill-inventory.md:50 | name prompter and intake stop point |
| s7-5 | M | part-a-state.md:37,244; part-d:73,140 | Plan-checker writes plan-check.md and runs rules 1-11,13-15 but is no skill/persona with an invocation; PLAN-CHECK is dispatch-plan's output | part-c-waves-control.md:51 | define checker call and the findings loop |
| s7-6 | M | part-d:101 vs part-a-state.md:264; part-b-desk.md:89 | ticket key in unit table: conductor writes it (D3) vs dispatch-plan reads tickets.tsv / jira-get; D2.2 row 5 lists only drafts | part-d:73 | one rule for who supplies the key |
| s7-7 | M | part-d:73,80 | new_units re-entry has no output grammar (new st<N>, seed, waves, .tasks, ticket), minter or invoker (pm lead cannot add subtasks[]) | part-a-state.md:87; part-c:148 | define re-entry output and invoker |
| s7-8 | M | part-a-state.md:250,262; part-d:78,93 | record line 3 Verified-By writer has no output in fix-verifier EXTEND; invokers of pr-review, fixer, verifier, gate runner unnamed for pre-pr-gate | part-02-skill-inventory.md:68 | per-actor writer and invoker of each line |
| s7-9 | M | part-b-desk.md:73,74; part-a-state.md:279 | push before vs after pre-pr-gate unsettled; rebase after an earlier push is non-fast-forward with force forbidden | part-a-state.md:270 | say whether a push precedes 4b |
| s7-10 | M | part-d:80 vs part-b-desk.md:88; part-d:81 | test-report-push: card 12 gives it to post-merge-verify, interfaces give payload and request to release-track | part-02-skill-inventory.md:72 | one owner, one point in sequence |
| s7-11 | M | part-d:26; part-c:116 | cleanup trigger MERGED only matches st<N>; pm has no trigger/evidence/approver; mode vs subtask redundant for final | part-a-state.md:85 | define pm cleanup and subtask when mode=final |
| s7-12 | M | part-b-desk.md:80 vs :18 | branch-delete requester is the cleanup executor agent, but B1 says the host session sends DESK lines | part-d:77 | host sends, executor writes .req only |
| s7-13 | M | part-d:26; part-a-state.md:254 | cleanup record has token on line 1 but dry-run/approved/executed/residual sections undefined; no write-last rule | part-02-skill-inventory.md:67 | fix sections and write-last rule |
| s7-14 | L | part-a-state.md:244,190 | dispatch-plan "writes" empty catalog.tsv though catalog.sh is sole writer | part-02-skill-inventory.md:61 | say who creates the file |

totals B/M/L: 0/13/1
