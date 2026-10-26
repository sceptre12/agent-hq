# Resume, reconcile, lock and hand-over

Depth for the SKILL.md steps "lifetime `substate.lock` and seed copy" and "reconcile (also on a first start)", and for every restart. Authority (INTERFACES 1.4.0): part C C5.3 (brief, triggers, steps 1-6 with 3a and 3b, hand-over, order after `TaskStop`, bus paging); part A A.3 (lock and break, seed, `stop_reason`, `interfaces_version`), A.4 (resume encoding by rename), A.5 (`catalog.sh audit`); part B B1 (re-attach, applied-result scan); spec 28 RESOLVED Q2, PC-W2-8; AM-4 row W2-5.

## Brief and triggers (C5.3)

The resume brief, the same on both backends:

```
resume <subtask>: re-read substate.md, inbox/ and gates/
```

For `claude -p` the conductor launches a fresh child through the launcher spec with this brief on stdin. For `agent-tool` the owner restarts the session and types it.

Triggers:
- a reboot (M15);
- the spawn cap (`cap - 5`, the hand-over below);
- dead lead state found by the conductor at its own resume;
- a dead lead found on the conductor's 1-minute tick: the `owner` pid in `substate.lock` fails `kill -0` while `subtasks[].state` is `released|building|pr-open`.

The checkpoint of `wave-execution` is the sole resume authority for what has passed. `session_id` is unchanged, so the controller resumes from it (ADR 0054 Q6). The lead never marks a work_item passed from its own memory, and a completion post that the checkpoint does not record is re-gated.

## Lifetime lock (A.3)

1. `mkdir RUN_HOME/<subtask>/substate.lock`. On success, write `owner` (`<pid> <ISO UTC>`, `^[0-9]+ [0-9TZ:-]+$`) to a temp file inside the lock directory and `mv` it to `owner`. The lead holds the lock for its whole life, so header writes need no second lock.
2. **The lock exists.** It is stale when the `owner` pid fails `kill -0`, or when `owner` is missing or unparsable and the directory is older than 120 s (A.3 lock rule, `interfaces/part-a-state.md:186`, also for the 1 s / 60 s waiter below).
   - **Not stale:** another lead is live. Refuse to start: print `substate.lock held by <owner>` and stop, without touching `substate.md`. Two leads on one `substate.md` is stop-the-line S6, so this refusal is what keeps it from happening.
   - **Stale:** break it. `mv substate.lock substate.lock.broken-<own pid>-<yyyymmddThhmmssZ>` (only one breaker's `mv` succeeds), then read `owner` inside the renamed directory. If it is not the `<pid> <utc>` that was tested stale (another breaker's fresh lock was moved), rename the directory back to `substate.lock` with a plain rename and start over. Otherwise `mkdir substate.lock`. If the `mv` or `mkdir` fails, start over from the stale test; a waiter retries every 1 s and gives up after 60 s. Remove the renamed directory once the new lock is held, and append the break time to `substate.md` `lock_breaks`.
3. **Seed copy (mode `build`, first start only):** copy `<PLANS_DIR>/subtasks/<subtask>/substate.seed.md` verbatim to `RUN_HOME/<subtask>/substate.seed.md`, never edit the copy, and create `substate.md` from it, adding every other A.3 field empty or derived. In `plan-pr` and `post-merge`, `substate.md` is initialized from `subtask_id`, `session_id` and `phase: seeded` only (A.2 Modes). On a resume, `substate.md` exists and is re-read, not re-created.

## Hand-over on the spawn-cap path (C5.3, A.3)

- **Old lead:** once `ledger.md`'s spawn check fails and no invocation is live, it writes `stop_reason: spawn-cap`, removes its lifetime lock (`rm` of `owner`, then `rmdir substate.lock`), and exits.
- **New lead:** it finds no lock, or only a stale one, and starts. It clears `stop_reason: spawn-cap` at resume (PC-W2-8, AM-4 W2-5). Its spawn count starts at 0 because it is a new session (A.3).
- `stop_reason: invalidate` is not cleared at resume. It is cleared only when a `RELEASE` with a higher `<seq>` than the `INVALIDATE` is consumed (`control-channel.md`, proposed CV30).
- Every other `stop_reason` (`stop-the-line:*`, `d7-round3`, `human`, `port-refused`) maps the sub-task to `stopped` (A.2 W2-5). A lead started on such a `substate.md` prints the reason and stops. Only the human's decision, delivered through the conductor, clears it.

## Reconcile: C5.3 steps, in order (also on a first start)

1. **Mark stale.** Rename every `slots/*.row` to `.stale`. Run `catalog.sh audit` (with `RUN_HOME`, and `WORKTREE_BASE` when set). No catalog row is marked stale, because `state` has no such value (A.5).
2. **Re-verify** each `.stale` row and each audit line by `kill -0` (pids; `claude-p` rows), `lsof` (ports, the bus), `git worktree list` (worktrees), git refs (branches, unit heads), and the audit `MATCH`/`GHOST`/`SQUATTER` lines. Every `agent-tool` row is dead on a lead restart (A3), because its agents lived in the old session.
3. **Free the dead, restore the live.** A dead row is renamed `.freed`, a live one back to `.row` (A.4). For each `GHOST` audit line write `catalog.sh release` or `catalog.sh fail`, and nothing else. A `SQUATTER` is reported in `escalations/` and never touched.
   - **3a. Lease reclaim.** For every `live` `lane-lease` row of this sub-task (`lane/<name>` and `gate-runner/<n>`) whose `owner_agent` has no live `.row` after step 3, or is the old lead's `SESSION`, write `catalog.sh release lane-lease <handle>`. Re-lease per C1.1 before the next dispatch (`ledger.md`).
   - **3b. Dispatch-record reconcile.** Every `agent_id` in `dispatch/*.jsonl` that has no `.row`, `.stale` or `.freed` file gets a row written (`ledger.md` field rules) and verified as in step 2.
4. **Bus.** Check the pm2 app against `bus.endpoint` and restart it with `pm2 restart`, never `reload`; an app pm2 no longer lists gets one start on the same claimed port, and a partly started bus with no `bus.endpoint` enters `bus-and-ports.md` step 0 (`bus-and-ports.md` "Resume", proposed CV31). The merged tick is already armed at SKILL.md step 3 on every start, so it is not armed a second time here (`tick.md`).
5. **Read `inbox/` and `gates/`** (`control-channel.md`). Then read verdicts in the order TaskStop, orphan sweep, re-read verdicts (bus and `status/*.verdict`), then free rows. At resume there is nothing to stop, so the sweep runs over the dead rows' worktrees. Bus reads past `limit 200` repeat with the last seen message id as the cursor until a page returns fewer than 200.
   Also before any send: apply the desk applied-result scan (`RUN_HOME/desk/*.out` of the lead's own verbs whose result is not yet recorded), then re-attach to each `*.req` that has no `.out` and is not `.req.noreply` (B1).
6. **Only then dispatch.** Wave 0 and the bus are not redone: each Wave 0 item that the catalog (`live` `worktree` rows), the `status/` files or the checkpoint show done is skipped, and an existing `bus.endpoint` takes the restart path, never a new claim (proposed CV31; `bus-and-ports.md` step 0). The next invocation bumps `invocation` in `substate.md` before the call. The controller resumes at the unpassed work_items.

## Re-entry by `phase` (proposed CV38)

After steps 1-5 a resumed lead re-enters at the row for its `substate.md` `phase` and never writes a lower `phase` (A.2 transitions; SKILL.md 10.3 sets `building` only from `seeded`). Steps 0-6 run on every start; step 8's restart path runs whenever `bus.endpoint` exists.

| `phase` | Re-entry |
|---|---|
| `seeded`, `building`, `integrating` | SKILL.md step 7 (done items skipped), 8, then the step 10 loop |
| `prepr` | SKILL.md step 12: `pre-pr-gate` re-invoked from its Step 0 |
| `pr-open` | SKILL.md step 13 at the first request whose `DONE` `.out` is not applied (B1 applied-result scan) |
| `ci` | SKILL.md step 14: `ci-fix-loop` re-invoked |
| `merged` | no `cleanup-<run-id>-<subtask>.md` with line 1 `CLEANUP DONE <subtask>`: re-run `delivery-cleanup` from its Step 1 (`skills/delivery-cleanup/SKILL.md` step 8) with the `MERGED` inbox file, still unconsumed, as the `merge_sha` source; with that line: `phase: done` |
| `done` | write `substate.md`, print its path, end |
| `post-merge`, `release` (`pm`) | `handoffs-and-modes.md` mode `post-merge` step 2 or step 3; each hosted skill resumes at its Step 0 |

`REGISTER` is written again on every start, resume included. The new identity replaces the old one in the desk registry (B1 "a line for a `<subtask>` already registered replaces its id"). No `DESK` line goes out before this start's `register.consumed` (`control-channel.md`).

## `interfaces_version` on resume

Step 0 runs on every start: the dispatch-plan header `interfaces_version` (and, in mode `build`, the seed copy's) is compared with `state.md` `interfaces_version`. A mismatch is `INPUT-ERROR interfaces_version format` and a stop (D2.2 row 6). The A.2 example's `1.1.0` is illustrative and not authoritative; the live files are compared (AM4-4).

## Red flags

| Thought | Reality |
|---|---|
| "The lock is old, just delete it." | Break only a stale lock, by the A.3 rename-and-check procedure. A live owner means refuse (S6). |
| "My memory says u07 passed." | The checkpoint is the sole authority (O-Q6). |
| "Dispatch first, reconcile while it runs." | Steps 1-5 complete before any dispatch (C5.3 step 6). |
| "The bus is down after reboot, start a new one on a fresh port." | Same claimed port, `pm2 restart`, or a single start of an unlisted app. Never a new claim (`bus-and-ports.md`). |
| "The run is resumed, set `phase: building`." | Re-enter by `phase` and never lower it (proposed CV38). |
| "Clear `port-refused` and carry on." | Only the human clears a stop; the lead stops again. |
