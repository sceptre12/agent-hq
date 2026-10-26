# Resume: conductor resume, `REBIND`, applied-result scan, lead relaunch

Authority: card 1 (resume, missing-state stop), INTERFACES 1.4.0 B1 (registry, re-claim, applied-result scan R4-J9, `.out` polling), B8 (`REBIND`), C5.1, C5.3, A.2 (AM-4 W2-5), A.3 (lock), A.4.

## Conductor resume (input `RUN_HOME`)

Run in this order; nothing is sent to the desk and no lead is launched before step 7. The applied-result scan (step 4) comes before every send, the registry re-send included (B1 "before any send").

1. **Step 0 and ORCHESTRATOR-CHECK** (`SKILL.md`). `RUN_HOME` is an existing directory under `$DELIVERY_ROOT` holding `state.md` (D2.2 row 1).
2. **Read `state.md`.** Missing (`INPUT-ERROR RUN_HOME path`) or unparsable (`INPUT-ERROR RUN_HOME format`): derive the rebuild from the run's own files (`RUN_HOME/*/substate.md`, `merge-*.md`, `cleanup-*.md`, `gates/`, `tickets.tsv`, `RUN_HOME/desk/*.out`, the dispatch plan), marking no step done that lacks its record, print it as the report and write nothing, then stop (card 1 stop). The run continues only on the owner's word.
3. **Version pins.** Compare `interfaces_version` with the live `INTERFACES.md` (`<version>@<sha256>`) and each `skill_versions` entry with the installed target hash. A mismatch means an amendment or a reinstall landed mid-run: stop and report (D7 change control; reviewed content must equal running content, design §6.5). Never rewrite a pin to make it match.
4. **Applied-result scan (R4-J9), before any send.** Scan `RUN_HOME/desk/*.out` for ids with `<subtask>` `run` of the conductor's own verbs whose result the record does not yet show, and apply each (local writes only):
   - `pr-merge` `DONE` with no `merge-<sha>.md` or no `merge_sha` in `state.md`: write `merge-<sha>.md`, set `merge_sha` and `state: merged`, then the `MERGED` inbox and any due `RELEASE` (`stages.md` stage 5b step 4).
   - `pr-approval-state` `DONE` with `h_pr` true and no pointer in `gates.H-pr`: append it.
   - `jira-*` results belong to `ticket-clerk`, which applies its own on start (A.6); the conductor only re-reads the epic key from `tickets.tsv`.
5. **Own machine row.** Mint the new conductor session token (`launcher.md`), write its row under `machine/.lock` (the old row's dead pid is reaped to `.dead`), and update `machine_ledger_row`.
6. **Re-arm** the 1-minute relay tick (session crons do not survive the session).
7. **Registry re-send (B1).** Send `REGISTER-SENDER <run-id> | run | <own sender-id>` first, then one line for every `subtasks[]` entry whose `lead_id` is set and not `-`. A repeated identical line is `ok`.
   - `run` answered `refused` (the run is claimed by the old conductor's sender id): post a human step asking the owner to type `REBIND <run-id> <sender-id>` in the desk session (regex `^REBIND ([a-z0-9-]+) ([^ ]+)$`, B8), with this session's sender id. Wait; send nothing else. After the desk rebinds, re-send every line.
8. **Requests and carriers in flight.** Re-attach every own `RUN_HOME/desk/*.req` (never `.req.noreply`) that has no `.out`: poll and resend the same id once per B1. Every `RUN_HOME/pm/outbox/*.conductor-request.sending-<id>` is re-sent with the same `<id>` (never re-minted) and renamed `.sent-<id>`; unrenamed `outbox/<id>.desk` and `outbox/register` files are handled by the next tick as usual.
9. **Inbox replay.** For each sub-task: an inbox `release` file whose effect `state.md` lacks -> set `state: released`, `released_utc`; a `merged` sub-task with no `merged` inbox file (consumed or not) -> write `MERGED <subtask> <merge_sha>`. The write order of `tick-relay.md` §Inbox writes makes this check complete.
10. **Dead lead state (card 1, C5.3).** For every sub-task that is `released`, `building`, `pr-open`, or `merged` and not yet `cleaned`: if `substate.lock/owner`'s pid fails `kill -0`, relaunch (below).
11. **Continue** at `state.md` `stage` (`stages.md`), and print the status post.

## Lead relaunch (C5.3)

**Triggers:** reboot; `stop_reason: spawn-cap` read in `substate.md` (the old lead wrote it, removed its lifetime `substate.lock` and exited); a dead lead found at conductor resume; a dead lead found on the 1-minute tick (owner pid fails `kill -0` while `state` is `released|building|pr-open`).

| Backend | Action |
|---|---|
| `claude-p` | Wait until `RUN_HOME/<subtask>/substate.lock` is gone (the spawn-cap hand-over) or stale (dead owner pid; the new lead breaks it per A.3, the conductor never does). Run the `launcher.md` ledger check, then launch a fresh child with the same D2.2 row 6 inputs, a new `session` token, and the brief `resume <subtask>: re-read substate.md, inbox/ and gates/` on stdin |
| `agent-tool` | Status-post line asking the owner to start a new session and type the same brief (C5.3) |

- `subtasks[].state` is unchanged by a relaunch. The new lead clears `stop_reason: spawn-cap` at its resume (A.3, AM-4 W2-5) and registers again: each lead start renames earlier `register*` files and writes a fresh `outbox/register`, which the tick consumes (`lead_id`, `session` updated; the desk replaces the sub-task's sender id, B1).
- The new lead is a new session, so its spawn count starts at 0 (A.3).
- A lead that dies again before its `phase` advances is reported to the owner, not relaunched a third time (the conductor's reading of "never a third attempt", with stop-and-report from card 1).
- `wave-execution` resumes from its checkpoint because `session_id` is unchanged; the lead's own C5.3 steps (slot rows, catalog audit, lease reclaim, pm2 check) are `delivery-run`'s, never the conductor's.
