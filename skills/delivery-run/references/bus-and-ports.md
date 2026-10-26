# Sub-task bus and ports

Depth for the SKILL.md step "bus claim, start, `bus.endpoint`" and for every later bus restart. Mode `build` only: `plan-pr` and `post-merge` start no bus (A.2 Modes). Authority, cited and not restated differently: INTERFACES 1.4.0 part A A.5.2 (port claims), A.3 (`bus.endpoint`), A.5 and A.5.1 (catalog rows), part C C1.1 (bus port, `bus_endpoint`, restarter), C5.3 step 4, C7 (bus down), part D D4, D5; spec 28 RESOLVED R-4, Q3, Q4, AM4-3; AM-4 rows W2-1, W2-3 and 18.

## Values

| Value | Setting | Source |
|---|---|---|
| `session_id` | `<run-id>-<subtask>`, the `bundle.md` value (equals the seed's `session_id`) | C1.1, A.3 |
| topic | `<run-id>-<subtask>-rendezvous`, the `bundle.md` `output_topic` | C1.1, D4 |
| `data_dir` | `RUN_HOME/<subtask>/bus/` (absolute; never `/tmp` or `$TMPDIR`) | A.1, D4, R-4 |
| pm2 app | `swarm-mcp-<session_id>` | R-4 (W' `wave-execution` step 4 name form), A.1 namespacing |
| candidate port | the P8 port-table `candidate` cell of `<PLANS_DIR>/dispatch-plan.md` for this sub-task's `bus` row, as written (it equals `ports.bus_base + 20·2N` for `st<N>`, AM-4 W2-3) | C1.1 bus port, A.5.2, Q4 |
| retry port | candidate + 10, one time only | A.5.2 (AM-3 OQ-2) |
| catalog keys | `correlation_id` = the sub-task `ticket` key of the dispatch-plan sub-task table; `source` `delivery-run`; `subtask` `<subtask>`; `owner_agent` = the lead's `SESSION` token; `unit` `-` | A.5, A.6 dispatch-plan additions |

The lead claims the candidate cell exactly as written. It never recomputes the formula, never picks another port, and never makes a second retry. With 20-spacing every candidate sits on an even ten from its base and every +10 retry on an odd ten that no candidate uses, so the one retry cannot land on another sub-task's candidate (Q4).

## Start order (once per sub-task; before any dispatch)

0. **Existing app or claim.** `pm2 jlist` and look for the exact app name, and read the latest catalog rows of this sub-task.
   - `bus.endpoint` present: go to "Restart" below with its values (C5.3 step 4).
   - No `bus.endpoint`, but a `planned` or `live` catalog `port` or `bus` row of this sub-task, or the app listed (a crash between steps 1 and 6, or a stop the human has since fixed): take `port` from the `port` row; make no claim and register nothing (`tools/port-check.sh` refuses a second claim by the same source, and the +10 retry is spent at most once, A.5.2). Enter at step 3 when the app is not listed, at step 4 when it is, then step 5 for every row still `planned`, then step 6 (proposed CV31).
   - Never a second `pm2 start` for a listed app.
1. **Claim** through the `port-claim` skill (A.5.2 order step 1), with `project` = `<run-id>` and `source` = `<run-id>-<subtask>`:
   ```
   tools/port-check.sh --claim <candidate> 127.0.0.1 - swarm-bus <run-id> claimed <run-id>-<subtask> sub-task-bus
   ```
   - exit 0: continue at step 2 with `port` = candidate.
   - exit 1 (taken) or 2 (registry and `lsof` disagree): one retry, claimed the same way at candidate + 10 before any bind. Exit 0 on the retry: continue with `port` = candidate + 10.
   - the retry refused (exit 1 or 2): write `stop_reason: port-refused` in `substate.md`, print the refusal line and the `substate.md` path, and stop. The conductor reports to the owner (AM4-3).
   - exit 3 on the candidate or on the retry (registry unusable): `stop_reason: port-refused` at once, no retry after exit 3 (Q3, AM-4 W2-1). A usage error (also exit 3 for a refused field) is a fault in this command line; fix it before any claim is retried, never treat it as a refusal.
2. **Register** the three planned rows (A.5.2 step 2; A.5 handle grammar):
   ```
   catalog.sh register port <port> - <ticket> delivery-run <subtask> <SESSION>
   catalog.sh register pm2-app swarm-mcp-<session_id> - <ticket> delivery-run <subtask> <SESSION>
   catalog.sh register bus <RUN_HOME>/<subtask>/bus - <ticket> delivery-run <subtask> <SESSION>
   ```
   Every `catalog.sh` call carries `RUN_HOME` inline, and `WORKTREE_BASE` inline when the profile sets `worktree_base` (INTERFACES script table).
3. **Start pinned** (A.5.2 step 3; swarm-communication start idiom). `mkdir -p` the `data_dir` under `umask 077`, then from the bus repo:
   ```
   DATA_DIR=<data_dir> APP_NAME=swarm-mcp-<session_id> PORT_RANGE_START=<port> PORT_RANGE_END=<port> NODE_ENV=production pm2 start ecosystem.config.cjs
   ```
   Both range variables carry the claimed port as two assignments (A.5.2, C1.1, AM-4 row 18). Poll for `<data_dir>/port` up to 30 times at 0.3 s (the `swarm-communication` start idiom, `skills/swarm-communication/SKILL.md:88`).
4. **Port equality.** `<data_dir>/port` must equal the claimed `port` (A.5.2), and `lsof -nP -iTCP:<port> -sTCP:LISTEN` must show the listener. Then run the identity preflight of `swarm-communication` (`/health` 2-3 times: `status: ok`, and `app_name`/`data_dir` equal to the values above).
   - On any failure here the launch failed after a claim: `pm2 delete swarm-mcp-<session_id>`, release the claim at once with a `released` row of the same port and source (`port-claim` Step 4, `resource-catalog` `references/ports.md`), `catalog.sh fail` each of the three rows, write `stop_reason: human` with the observed and claimed ports, and stop. A.5.2 requires the equality but names no `stop_reason` for a failure, so the lead uses the generic `human` stop.
5. **Mark live** (A.5.2 step 4): `catalog.sh start port <port>`, `catalog.sh start pm2-app swarm-mcp-<session_id>`, `catalog.sh start bus <data_dir>`.
6. **Write `bus.endpoint`** atomically: write a temp file in `RUN_HOME/<subtask>/`, then `mv` it to `bus.endpoint` (A.1 atomic writes). It holds exactly these key=value lines (A.3, D5):
   ```
   port=<port>
   data_dir=<absolute data_dir>
   pm2_app=swarm-mcp-<session_id>
   pid=<pid from pm2 pid swarm-mcp-<session_id>>
   session_id=<bundle.md session_id>
   topic=<bundle.md output_topic>
   ```
   Before the `mv`, check that `session_id=` equals `substate.md` `session_id` and `<run-id>-<subtask>`, and that `topic=` equals `<session_id>-rendezvous`. A mismatch is a stop row (A.3): write `stop_reason: human` with both values and stop. The plan is then defective, so the lead edits neither file.

Only after step 6 may anything be dispatched. `start_session` is not the lead's call: `wave-execution` runs it in its step 5 on the attached bus (C1.1).

## Restart (the lead is the only restarter)

- The lead is the only process that restarts the bus (C1.1, D5). The controller never starts, restarts or deletes an attached bus (W' step 4), and no worker does.
- The only verb is `pm2 restart swarm-mcp-<session_id>`. Never `pm2 reload`, which overlaps workers on the shared state file. Never `pm2 delete` while the sub-task runs, and never a second `pm2 start` of a listed app.
- After a restart, re-run step 4 (port equality, listener, identity preflight). Then rewrite `bus.endpoint` atomically with the new `pid=` and every other line unchanged. The pinned range means the port cannot move. A different port is a failed restart.
- **Bus down** (C7): on every tick the watchdog half runs `kill -0 <pid>` on the `bus.endpoint` pid and `lsof -nP -iTCP:<port> -sTCP:LISTEN` on its port. If either fails, run `pm2 restart`. Two failed restarts in a row: write `stop_reason: stop-the-line:S8` and stop (A.3 row S8). Meanwhile agents post through the status-file fallback (C4); `verdicts.md` covers the relay.
- **Resume** (C5.3 step 4): compare the pm2 app named in `bus.endpoint` with `pm2 jlist`. If listed, use `pm2 restart` only. If not listed (pm2 lost its process list over a reboot), start it once by step 3 on the same claimed port: the claim and the catalog rows still stand, so no new claim is made and nothing is registered again. Then run steps 4 and 6. If that start fails step 4, it counts as a failed restart under the S8 rule.

## Ports the lead does not claim

- **Per-review bus.** `pre-pr-gate` passes `BUS_PORT` (the P8 `review-bus` candidate, `ports.bus_base + 20·(2N+1)`) to `pr-review`, which claims it in its Step 1 and makes its own one +10 retry (D2.3). If `pre-pr-gate` reports a review-bus stop (`PREPR: STOP` with the refusal line in the checklist), the lead writes `stop_reason: port-refused` (Q3).
- **Lane ports.** A lane that binds a port claims it per A.5.2 before its launch (C1.1 lane lease). The lane runner does that under its brief. A second refusal comes back as the C2 reason `lane-unavailable` (`verdicts.md`). The lead leases the lane (`ledger.md`) and claims none of its ports.
- **Teardown** is never the lead's. The `port`, `pm2-app` and `bus` rows are released by `delivery-cleanup` after `MERGED` (A.5.1 rows `port`, `pm2-app`, `bus`; `handoffs-and-modes.md`).

## Red flags

| Thought | Reality |
|---|---|
| "The candidate is taken, I'll take the next free port." | Never auto-pick. One claimed retry at candidate + 10, then `port-refused` (A.5.2). |
| "Exit 3 is just a flaky registry, retry it." | Exit 3 means the registry is unusable: `stop_reason: port-refused`, no retry (Q3). |
| "Start the bus first, claim once it is up." | Claim, register `planned`, then bind. A bind before the claim is an unclaimed port. |
| "The formula gives a different port than the table." | Claim the table cell as written; the plan is the authority (Q4). |
| "The bus looks hung, `pm2 reload` is gentler." | `pm2 restart` only; two failures is S8. |
| "Let `wave-execution` restart it." | The lead is the only restarter of an attached bus (C1.1). |
