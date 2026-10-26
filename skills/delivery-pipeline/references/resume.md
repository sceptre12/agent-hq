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
   - A terminal `REJECTED` `.out` or a `.req.noreply` of an own request: re-post it as a human step; for `pr-merge` it stays the sub-task's 5b block marker (proposed, 29-16), so no new `pr-merge` is minted for that `head`.
   - `jira-*` results belong to `ticket-clerk`, which applies its own on start (A.6); the conductor only re-reads the epic key from `tickets.tsv`.
5. **Own machine row.** Mint the new conductor session token (`launcher.md`), write its row under `machine/.lock` (the old row's dead pid is reaped to `.dead`), and update `machine_ledger_row`.
6. **Re-arm** the 1-minute relay tick (session crons do not survive the session). Until step 7 has `REGISTERED <run-id> | run | ok`, the tick sends, relays, renames and launches nothing and `ticket-clerk` does not run (tick step 0, proposed 29-16).
7. **Registry re-send (B1).** Send `REGISTER-SENDER <run-id> | run | <own sender-id>` first, then one line for every `subtasks[]` entry whose `lead_id` is set and not `-`. A repeated identical line is `ok`.
   - `run` answered `refused` (the run is claimed by the old conductor's sender id): post a human step asking the owner to type `REBIND <run-id> <sender-id>` in the desk session (regex `^REBIND ([a-z0-9-]+) ([^ ]+)$`, B8), with this session's sender id. Wait; send nothing else (the tick only reads). After the desk rebinds, re-send every line. A `REGISTER-SENDER` with no reply follows the one no-reply rule (`tick-relay.md` §4).
8. **Requests and carriers in flight.** Re-attach every own `RUN_HOME/desk/*.req` (never `.req.noreply`) that has no `.out` and that a record owns (a `pr-*` request of the 5b step in flight, or a `pm/outbox/*.sending-<id>` carrier): poll and resend the same id once per B1. A `.req` whose verb and fields match an un-renamed `pm/outbox/<seq>.conductor-request` is adopted by that carrier (rename it `.sending-<id>`), never minted again (proposed, 29-16). Every `RUN_HOME/pm/outbox/*.conductor-request.sending-<id>` is re-sent with the same `<id>` (never re-minted) and renamed `.sent-<id>`; unrenamed `outbox/<id>.desk` and `outbox/register` files are handled by the next tick as usual.
9. **Inbox replay.** For each sub-task: an inbox `release` file whose effect `state.md` lacks -> set `state: released`, `released_utc`. Then re-derive every due `RELEASE`, `MERGED` and `INVALIDATE` from `state.md` (`reentered`, `merge_sha`, merge order) and write each one no inbox file records, once (proposed, 29-14; `tick-relay.md` §Inbox writes). This covers a crash after `MERGED` and before the successor's `RELEASE`, and a back-edge written before its `INVALIDATE`.
10. **Dead lead state (card 1, C5.3).** For every sub-task that is `released`, `building`, `pr-open`, or `merged` and not yet `cleaned`: if `substate.lock/owner`'s pid fails `kill -0`, relaunch (below). A sub-task with `session` set (launch intent written, proposed 29-13) counts as launched whatever its `state`: with a live `machine/<session>.row` pid or a `substate.lock` it is left alone; with neither it gets the startup check (`tick-relay.md` §7), never a second launch under the same token.
11. **Continue** at `state.md` `stage` (`stages.md`), entering each stage by its re-entry predicate (proposed, 29-17), then print the status post (every open item counts as new once):

| `stage` | Skip the stage skill when | Else |
|---|---|---|
| 1 | `repo_profile` set (or re-derived as `<profile path>@<sha>` from the profile file `delivery-intake` wrote) | re-invoke `delivery-intake` |
| 1 -> 2 | `gates/H0.ok` exists | wait for it (post) |
| 2 | `review-architecture.md` line 1 `ARCH: ready` | re-invoke `delivery-architecture` |
| 2 -> 3 | live `H1.ok` recorded in `gates.H1`; an `H1.changes` whose name and `utc=` equal `h1_handled` is already handled | apply the H1 branch once |
| 3 | `plan-check.md` line 1 `PLAN-CHECK: clean`, no round-3 open finding (29-23), `subtasks[]` filled | re-invoke `delivery-dispatch-plan`; fill `subtasks[]` |
| 4-7 | always continue on the tick | - |
| 8 | `capture/read-back.md` line 1 `READ-BACK: pass` (29-24) | re-run the capture step |

## Lead relaunch (C5.3)

**Triggers:** reboot; `stop_reason: spawn-cap` read in `substate.md` (the old lead wrote it, removed its lifetime `substate.lock` and exited); a dead lead found at conductor resume; a dead lead found on the 1-minute tick (owner pid fails `kill -0` while `state` is `released|building|pr-open`).

| Backend | Action |
|---|---|
| `claude-p` | Wait until `RUN_HOME/<subtask>/substate.lock` is gone (the spawn-cap hand-over) or stale (dead owner pid; the new lead breaks it per A.3, the conductor never does). Run the `launcher.md` ledger check, then launch a fresh child with the same D2.2 row 6 inputs, a new `session` token, and the brief `resume <subtask>: re-read substate.md, inbox/ and gates/` on stdin |
| `agent-tool` | Status-post line asking the owner to start a new session and type the same brief (C5.3) |

- `subtasks[].state` is unchanged by a relaunch. The new lead clears `stop_reason: spawn-cap` at its resume (A.3, AM-4 W2-5) and registers again: each lead start renames earlier `register*` files and writes a fresh `outbox/register`, which the tick consumes (`lead_id`, `session` updated; the desk replaces the sub-task's sender id, B1).
- The new lead is a new session, so its spawn count starts at 0 (A.3).
- **Launch intent first (proposed, 29-13).** Before exec the conductor writes the new `session` (`-l<n>`, `n` = the stored count + 1) and `relaunch_phase` (the current `phase`) to `state.md`. A dead lead whose current `machine/<session>.row` pid is live is not yet dead; skip it.
- A lead that dies again with `phase` still equal to `relaunch_phase` is reported to the owner with the sub-task, both session tokens, `homes/<session>/lead.log` and `substate.md` paths, and not relaunched a third time (the conductor's reading of "never a third attempt", with stop-and-report from card 1; proposed, 29-6); the `spawn-cap` trigger counts the same way, so a missing lock does not re-trigger every tick.
- Not relaunched: a `pm` with `postmerge: FAIL`, a `POSTMERGE: STOP` record or a terminal `release_record` (proposed, 29-19).
- `wave-execution` resumes from its checkpoint because `session_id` is unchanged; the lead's own C5.3 steps (slot rows, catalog audit, lease reclaim, pm2 check) are `delivery-run`'s, never the conductor's.
