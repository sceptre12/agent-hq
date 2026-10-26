V1 FIXED INTERFACES.md:83 D3 row now "seven events plus `archive` mapped to the stage table, `TICKET-EVENT` line"
V2 FIXED INTERFACES.md:57 A.4 row now the five-field form `session= pid= live_count= build= utc=`
V3 FIXED part-b-desk.md:36,105 `.inflight` holds `<verb> <target>`; before step 9 the desk reads back the target for any request whose verb+target has an `.inflight` without a `DONE` `.out` (fresh-id resend after `action-failed` covered); DEFAULT (integrator), log INTERFACES.md:111
V4 FIXED part-b-desk.md:18,47,62 any `<id>` with `<subtask>` `run` needs the transport sender = the registry's `run` id (conductor), else `REJECTED sender`, in B1, B2.1 `sender` and B3 step 1; DEFAULT (integrator), log INTERFACES.md:112
V5 FIXED part-c-waves-control.md:110,118 `CONDUCTOR-REQUEST <run-id> pm <seq> <verb> <fields-json>` in `pm/outbox/<seq>.conductor-request` with regex, conductor sends with `run`; part-b-desk.md:85-87 requester cites it; part-d-enums-topics.md:54,69 lead message + D2.2 row 1 conductor verbs; DEFAULT (integrator), log INTERFACES.md:113
V6 FIXED INTERFACES.md:33 `catalog.sh register` gains `<subtask|run> <owner_agent>` (catalog columns 3, 8); log INTERFACES.md:114
V7 FIXED part-a-state.md:208 `worktree` removed from the plain-path kind list
V8 FIXED part-c-waves-control.md:68 comma inserted: `budget`, `fix-loop-cap-exhausted`
Checks: check-doc-length.sh 0 blocking; line counts 182/278/158/174/155.
