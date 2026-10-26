# feature-change: team mode (`UNIT_MODE=team`)

One unit inside a delivery run. The lead (conductor, `delivery-run`) already fixed what solo Steps 0, 1, 8, 9 and 10 decide. `solo` (the default) is unchanged. Contracts: INTERFACES 1.5.0 D1, D2.3, C1, C1.1, C1.2, C2, C3, C4, D5, A.1, A.2, A.5, A.5.2, A.6, A.7. Open owner questions are marked `OQ-13-<n>` (this skill's own build questions, listed at the end; not the task spec's `Q13-<n>`); `OQ-13-1`, `OQ-13-2`, `OQ-13-7` and `OQ-13-8` are settled by INTERFACES 1.5.0 A.7 (AM-4 13); for the others the path written here applies until the owner answers.

## Input check (Step 0)
`UNIT_MODE` is `team` or `solo`; unset means `solo`. Any other value: print `INPUT-ERROR UNIT_MODE enum` and stop (D1, D2.3). In `team`, Step 0 then checks every brief field below, prints one line `INPUT-ERROR <NAME> <reason>` per failing field (D1 reason words only), and stops after the last line; no retry, no prompt, no silent stop, and never a guessed bus or path. Names are UPPER_SNAKE `NAME=value` (D2.3 input transport); `UNIT_MODE` is the one new skill input (D2.3), the others are brief-supplied values (`OQ-13-6`).

| Field | Value | Absent | Fails the check |
|---|---|---|---|
| `RUN_HOME` | `$DELIVERY_ROOT/<run-id>` (A.1), an existing directory; the "under `$DELIVERY_ROOT`" part is not checked here (`catalog.sh` rejects out-of-root handles, exit 2) | `missing` | `path` (not absolute or not a directory) |
| `RUN_ID` | `^[a-z0-9-]+$`, equal to the last segment of `RUN_HOME` (A.1) | `missing` | `format` |
| `SUBTASK` | `^(st[0-9]+\|pm)$` (A.1) | `missing` | `format` |
| `UNIT` | `^u[0-9]+$` (A.1; `i<N>` is the Integrator, not this skill) | `missing` | `format` |
| `AGENT_ID` | `^[a-z0-9-]+$`, the controller-minted `from_agent` of this dispatch (C1.1) | `missing` | `format` |
| `REPO` | absolute path of the repo's main checkout (same as solo) | `missing` | `path` |
| `SLUG` | the unit's ticket slug, `^[a-z0-9][a-z0-9-]*$` (A.1; no `<n>-` prefix in team mode) | `missing` | `format` |
| `TASK_FILE` | `<primary_repo>/.tasks/<unit>-<slug>.md` (A.6), an existing file named `$UNIT-$SLUG.md` | `missing` | `path` (not a file), `format` (name differs) |
| `REPO_PROFILE` | `<abs path>@<sha>` of `repo-profile.md`, `<sha>` the git blob id (A.2 `repo_profile`) | `missing` | `format` (not `<abs>@<40-hex>`), `sha` (`git hash-object <path>` differs from `<sha>`, D1), `path` (file absent) |
| `SUBTASK_BRANCH` | the sub-task's own ticket branch (dispatch-plan sub-task table `branch` column, `<sub-task key>-<slug>`, A.6 additions), never this unit's `$BR` (`OQ-13-5`) | `missing` | `format` (no local ref in `REPO`) |

Profile keys read in Step 0 (A.2.2): `worktree_base` (absolute; its root check is `catalog.sh`'s, A.5) and `gates.command`; a missing key prints `INPUT-ERROR worktree_base missing` or `INPUT-ERROR gates.command missing` (A.2.2 "A missing key fails the reader's Step 0"). A unit launched without the Agent tool prints `INPUT-ERROR tools` before Step 3 (a launcher defect, INTERFACES 1.6.0 AM-6 C-5; never an `ESCALATE`).

## Per-step table
| Solo step | Team mode |
|---|---|
| 0 Repo policy lookup | Replaced by the input check above: `GATES` = `gates.command` from `REPO_PROFILE` (A.7 Command row); `ROUTE` is moot. Arrival duty (Rule 6) is surface-only: run its two commands read-only and quote their output in the unit report; `$REPO` is the lead's main checkout (it holds the sub-task worktrees), so never fix it and never stop on it; no failure row (`OQ-13-11`). |
| 1 Ticket | team: skip ticket creation; say "ticket owned by the conductor". Read the key, see Key below. No Jira, tracker or desk call. |
| 2 Worktree | Worktree `$WORKTREE_BASE/$RUN_ID-$SUBTASK-$UNIT` (C1.1 dispatch record row), branch `<JIRA-KEY>-<slug>`, created only after the key exists. Catalog first, see Worktree and catalog. |
| 3-4 Implement, tests | Before Step 3, confirm the Agent tool is available: the engine (`wave-execution`) runs in the lead session, the unit and its gate agent run at depth 1, and the unit dispatches its `review path` reviewer at depth 2 (A.7 "depth-2 agents never dispatch" means agents at depth 2 spawn nothing, INTERFACES 1.6.0 AM-6 C-5; 1.8.0 AM-8 V3); the unit dispatches no verifier (Step 6). Absent = a launcher defect: print `INPUT-ERROR tools` and stop, before any edit (no record, as for any Step 0 `INPUT-ERROR`). Otherwise unchanged. A `HANDBACK` ends the unit per the failure table. |
| 5 Repo gates | Run the checks locally while working. The `GATE-PASS` record is not the unit's: the engine's per-work_item gate agent writes `gate-runs/<head>.md` after the post (A.7, AM-4 13), see Unit end. |
| 6 Distinct verifier | The distinct verifier is `wave-execution`'s per-work_item gate agent (depth 1, dispatched by the engine), which runs `gates.command` (the bundle `gates_command`) on the posted head under a lane lease and is the single writer of `GATE-PASS` in `gate-runs/<head>.md` (A.7, AM-4 13, `OQ-13-8`; INTERFACES 1.8.0 AM-8 V14); the unit dispatches no verifier. |
| 7 Review rung | The rung is the unit table's `review path` (C1.2); `pre-pr-gate` owns the PR-level `pr-review`. At most 3 rounds, then stop (D7). |
| 8 Integrate | team: skip integration; the Integrator persona is the single writer of the sub-task branch. No push, no merge, no PR. |
| 9 Cleanup | team: skip cleanup; `delivery-cleanup` removes the worktree. Never run `git worktree remove`. |
| 10 Record | team: skip the ledger row and the ticket update; the lead owns the record (`ticket-clerk` runs only in the conductor session, A.6). Run Unit end instead. |
| 11 Scope | Unchanged. |

## Key
`RUN_HOME/tickets.tsv` is the desk read-back store: `ticket-clerk` fills it from the `jira-create` read-backs and lists `feature-change` as a reader (A.6), so reading it is the "key read back from the desk" of A.1 / C1.2 without a desk request (spec §3).
`KEY=$(awk -F'\t' -v s="$SLUG" '$1==s{k=$2} END{print k}' "$RUN_HOME/tickets.tsv")` (latest row per slug governs). Empty, `-`, or not matching `^[A-Z][A-Z0-9]+-[0-9]+$`: the key is absent; end the unit with `ESCALATE` `spec-gap` and create no branch. Then `BR=$KEY-$SLUG`; `$BR` equal to `$SUBTASK_BRANCH` stops the unit before any catalog call (failure table, add row).

## Worktree and catalog (A.5, script table)
`CATALOG` = `tools/delivery/catalog.sh` of the agent-hq checkout (default `$HOME/projects/agent-hq/tools/delivery/catalog.sh`; INTERFACES names only `catalog.sh`). Every call carries `RUN_HOME` and `WORKTREE_BASE` as inline assignments on that one command, never exported. Values: `WB` = profile `worktree_base`; `WT=$WB/$RUN_ID-$SUBTASK-$UNIT`; `BR=$KEY-$SLUG`; `<base>` = `$SUBTASK_BRANCH` (the branch the unit is content-merged into, A.5 handle grammar); `correlation_id` = `$KEY`; `source` = `feature-change`; `unit` = `$UNIT`; `subtask` = `$SUBTASK`; `owner_agent` = `$AGENT_ID`.

Pick the case from `git -C "$REPO" worktree list --porcelain` and, when it lists `worktree $WT`, `git -C "$WT" symbolic-ref -q --short HEAD`:

| Case | State | Do |
|---|---|---|
| A | no line `worktree $WT` (spec §8 AC3) | the block below: `catalog.sh register worktree` and `register branch`, add, `start` both |
| B | `$WT` listed, HEAD detached (`symbolic-ref` exits non-zero): the lead's Wave 0 add, already registered (C1 Wave 0 setup) | no add and no second `worktree` row; register the branch row (block line 1), `git -C "$WT" switch -c "$BR"`, then `start branch` (block line 4). Who adds the unit worktree is `OQ-13-4` |
| C | `$WT` listed on `$BR`: a re-entry (the re-dispatch after `ROLLED` is a fresh invocation with `tier_override`, C1.1; or a resumed dispatch) | no add, no switch. Rows: read `RUN_HOME="$RUN_HOME" WORKTREE_BASE="$WB" "$CATALOG" list --live --subtask "$SUBTASK"`; if no row has kind `branch` (column 6) and handle `$REPO#$BR@$SUBTASK_BRANCH` (column 7), `register` then `start` it; likewise `worktree` when no live `worktree` row has a handle starting `$WT#`. A `live` row is never registered again (supersede key `kind` + `handle`, A.5). Continue from the committed state in `$WT` |
| other | `$WT` listed on any other branch | failure table, add row |

Case A:
```bash
RUN_HOME="$RUN_HOME" WORKTREE_BASE="$WB" "$CATALOG" register branch "$REPO#$BR@$SUBTASK_BRANCH" "$UNIT" "$KEY" feature-change "$SUBTASK" "$AGENT_ID"
RUN_HOME="$RUN_HOME" WORKTREE_BASE="$WB" "$CATALOG" register worktree "$WT#$REPO@$SUBTASK_BRANCH" "$UNIT" "$KEY" feature-change "$SUBTASK" "$AGENT_ID"
git -C "$REPO" worktree add "$WT" -b "$BR" "$SUBTASK_BRANCH"
RUN_HOME="$RUN_HOME" WORKTREE_BASE="$WB" "$CATALOG" start branch "$REPO#$BR@$SUBTASK_BRANCH"
RUN_HOME="$RUN_HOME" WORKTREE_BASE="$WB" "$CATALOG" start worktree "$WT#$REPO@$SUBTASK_BRANCH"
```
The start point is `OQ-13-5` (here the sub-task branch tip, never `origin/main`; `scope-check.sh` measures from `merge-base HEAD <sub-task branch>`, script table).

Any `catalog.sh` exit other than 0 stops the unit before the add or the switch (Cases A, B) or before any edit (Case C): map it with the failure table. Exit 3 only answers `lane-lease` rows, so it is not expected for `worktree` or `branch` rows. If the add or the switch fails after register, run `catalog.sh fail` for each row this unit registered, then the failure table.

## NEXT line (C3)
File: your own `RUN_HOME/$SUBTASK/status/$AGENT_ID.md`, one current line, overwritten; never another agent's file (a re-dispatched unit has its own `AGENT_ID` and never reads the earlier agent's file).
Form: `NEXT: <unit>.<n> <text>` with `<unit>` = `$UNIT` (it already carries the `u`), e.g. `NEXT: u3.2 tests written`; it matches `^NEXT: (u[0-9]+)\.([0-9]+) .+$`.
`<n>` = the number of the last completed command of the `TASK_FILE` §9 verification list; `0` before the first. Write `<unit>.0` once the worktree exists (Case C: once it is confirmed), then after each §9 command; after the last command `<n>` is that command's number. Feature-change step numbers are never used, and a skipped feature-change step writes nothing. The last `NEXT:` write comes before the post or the `.verdict` write, so the record is always the unit's final write. A unit that stops before its worktree exists writes no `NEXT:` line.

## Unit end (ordered)
1. All work committed on `$BR` in `$WT`; `git -C "$WT" status --porcelain` is empty. Each commit carries `HUSKY=0` as an inline assignment on that one command (the work profile's interactive `prepare-commit-msg` hook), never exported, and never `--no-verify` (A.7, the single statement; AM-4 13, `OQ-13-7`).
2. The `review path` ended at 0 Blocking / 0 Medium (Step 7), within 3 rounds (D7).
3. `HEAD=$(git -C "$WT" rev-parse HEAD)` (40-hex); any later commit means step 2 again for the new head.
4. Gate record: the unit never requests the gate runner, never waits for or reads `gate-runs/<head>.md` and never runs `gates.command` as the record (`OQ-13-1`, `OQ-13-2`). After the post, `wave-execution`'s per-work_item gate agent runs the gate command on `$HEAD` and writes `RUN_HOME/$SUBTASK/gate-runs/$HEAD.md` (A.7, AM-4 13); a gate failure is the engine's fix loop, not a unit failure class.
5. Write your last `NEXT:` line, then post the record (below) with `head` = `$HEAD`, and stop.

`PASS` only when steps 1-3 all hold for the same `$HEAD`; reason `none`.

## Failure table (C2 verdict -> reason pairs)
C2 pairing: `PASS` takes only `none`; `ROLLED` takes only `budget`, `lane-unavailable`, `env-bug`, `merge-conflict`; `ESCALATE` takes every other non-`none` code. No code outside the C2 closed set (spec §11). `head` on every row that posts: if `git -C "$REPO" worktree list --porcelain` lists `worktree $WT`, `git -C "$WT" rev-parse HEAD` (C2 "the unit worktree's head"); otherwise (key absent, a `$BR` clash, a catalog exit or a failed add in Case A) `git -C "$REPO" rev-parse "$SUBTASK_BRANCH"`, which Step 0 proved exists (`OQ-13-3`).

| Failure | Verdict | Reason |
|---|---|---|
| Step 0 `INPUT-ERROR`, or `INPUT-ERROR tools` before Step 3 (no Agent tool, AM-6 C-5) | no record (D1: print, stop); C4 "No post" makes it a gate failure handled by the lead | - |
| Key absent in `tickets.tsv` | `ESCALATE` | `spec-gap` |
| `catalog.sh` exit 2 (usage or rejected row) or an unexpected exit 3 | `ESCALATE` | `contract-gap` |
| `catalog.sh` exit 4 (lock timeout) | `ROLLED` | `env-bug` (`OQ-13-10`) |
| `$BR` equals `$SUBTASK_BRANCH`, `git worktree add` or `switch -c` fails, or `$WT` is on another branch | `ESCALATE` | `contract-gap` |
| Step 3 `HANDBACK` (layer outside the repo) | `ESCALATE` | `spec-gap` |
| A `.decisions/<unit>.md` was written (spec §11 class) | `ESCALATE` | `decision-gate` |
| AC NOT MET or review Blocking/Medium still open after round 3 (D7) | `ESCALATE` | `fix-loop-cap-exhausted` (`OQ-13-9`) |
| Dev-server port refused at its candidate and at its one +10 retry, or `port-check.sh` exit 3 (A.5.2, AM-3) | `ESCALATE` | `human-step` (`OQ-13-10`) |
| The unit's `budget` (C1.2: brief text the lead copies into the slot row `budget_min`) passes before Unit end completes | `ROLLED` | `budget` |

Every `ESCALATE` pauses the unit for the human (C2 lead handling); a `ROLLED` is re-dispatched one tier up, which re-enters through Case C.

## UNIT-VERDICT post (C2, C4, D5)
Record: a bare JSON object, no text prefix, exactly four keys, one line: `{"unit":"<UNIT>","verdict":"PASS|ROLLED|ESCALATE","head":"<40-hex>","reason":"<code>"}`.
Transport: the `broadcast` MCP tool of the existing `swarm-communication` skill (`skills/swarm-communication/SKILL.md` steps 2, 4 and 5; arguments in its `references/tools.md`), over `POST http://localhost:$PORT/mcp`. This skill adds no bus client.
1. Read `RUN_HOME/$SUBTASK/bus.endpoint` (D5): `data_dir`, `pm2_app`, `session_id`, `topic`. `session_id` must be `$RUN_ID-$SUBTASK` and `topic` must be `$RUN_ID-$SUBTASK-rendezvous` (C1.1).
2. `PORT` = the content of `$data_dir/port` (D5 Readers, ADR 0054 A9); the `port=` line is not used.
3. `/health` per swarm-communication step 2, sampled 2-3 times: it answers each time, its `app_name` equals the file's `pm2_app` and its `data_dir` equals the file's `data_dir`.
4. `broadcast` with `from_agent` = `$AGENT_ID` (registered in the dispatch record, C1.1; the lead acts only on registered senders, C2), `topic`, `content` = the record as a string, `session_id` passed explicitly.
5. Success is only a parsed response with `status:"sent"` whose `data_dir` equals the file's.

Unreachable (C4 Trigger) = `bus.endpoint` missing or disagreeing with step 1, no `$data_dir/port`, `/health` refused or mismatched on any sample, or any `broadcast` answer other than step 5. Then write the exact same record to `RUN_HOME/$SUBTASK/status/$AGENT_ID.verdict` and stop. Never re-send a post (the bus has no dedup; C4 precedence lets the lead reconcile the same record). Never start, restart or stop the bus and never call `start_session` or `end_session`: `delivery-run` is the only restarter (C1.1).

## Port guard
This skill binds no port; any dev server a unit starts is claimed per A.5.2 through `port-claim` first (one +10 retry, AM-3). `security-audit` is not used here (the security seat belongs to the review step).

## Owner questions
Each is recorded in the item 13 Rung 1 record. `OQ-13-1`, `-2`, `-7` and `-8` are settled by INTERFACES 1.5.0 A.7 (AM-4 13); for the others the path in the right column is the one this file follows until the owner answers.

| Id | Question | Path followed here |
|---|---|---|
| `OQ-13-1` | C2 reason when `gate-runs/<head>.md` is absent at Unit end | settled (A.7): the unit does not read the file; "gate runner absent" is not a unit failure class |
| `OQ-13-2` | How a unit requests the gate runner, and how long it waits | settled (A.7): no request, no wait; the engine's gate agent runs after the post |
| `OQ-13-3` | `head` of a record posted with no unit worktree | `git -C "$REPO" rev-parse "$SUBTASK_BRANCH"` |
| `OQ-13-4` | Who adds the unit worktree: the lead in Wave 0 (C1) or the unit (spec §8 AC3) | both handled (Cases A, B) |
| `OQ-13-5` | Unit branch start point and A.5 `<base>` | `SUBTASK_BRANCH` tip, never `origin/main` |
| `OQ-13-6` | Brief field names other than `UNIT_MODE` | the names in the Step 0 table |
| `OQ-13-7` | COMMON block restates `HUSKY=0` for unit commits; A.7 limited it to desk pushes and PR creation (cross-item) | settled (A.7): inline `HUSKY=0` on commits and desk pushes, never exported, never `--no-verify` |
| `OQ-13-8` | C1.1 "none of which dispatches" vs the distinct verifier a unit needs (cross-item) | settled (A.7; INTERFACES 1.8.0 AM-8 V3): the engine runs in the lead session, the unit and its gate agent are depth 1, and that per-work_item gate agent is the distinct verifier; the unit dispatches none |
| `OQ-13-9` | Reason a unit posts at the D7 round cap (`fix-loop-cap-exhausted` is C2's lead-side code; spec §4 omits it) | `fix-loop-cap-exhausted`; any ESCALATE code gets the same lead action |
| `OQ-13-10` | Reasons for a non-lane port refusal (A.5.2 names none) and a catalog lock timeout (C2 ties `env-bug` to the e2e writer) | `human-step`; `ROLLED` `env-bug` |
| `OQ-13-11` | Arrival duty (Rule 6) in team mode: surface-only or skipped | surface-only, never fixed, never a stop |
