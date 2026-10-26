# Launching sub-task leads: ledger checks and the launcher spec

Authority: design §4 (numbers, rule 8), §6.4 (launcher spec, D25), INTERFACES 1.4.0 A.1, A.4 (machine ledger, AM-4 W2-9), C5.2, C5.3; spec 25 RESOLVED Q6 (the Zephyr entry). The conductor is the only launcher (card 1, A4/A5). It never dispatches unit workers; a lead dispatches its own.

## Which backend starts a lead (C5.2)

| `subtasks[].backend` | Who starts it | Conductor action |
|---|---|---|
| `claude-p` | the conductor, through the launcher spec below | ledger check, then launch |
| `agent-tool` | the owner: own session, depth 0 | ledger pre-check, then a status-post line asking the owner to start the session (below); the lead registers its own machine row first and checks env `CLAUDE_CODE_MAX_CONCURRENT_SUBAGENTS` >= 30 at its ORCHESTRATOR-CHECK (W2-9) |

The ask for an `agent-tool` lead names, in one block: the session to open (depth 0, the operator's executor tier, OP4), `CLAUDE_CODE_MAX_CONCURRENT_SUBAGENTS=30` and `CLAUDE_CODE_MAX_SUBAGENTS_PER_SESSION` in its environment, `DELIVERY_ROOT`, and the exact `delivery-run` call with its D2.2 row 6 inputs (`stages.md` stage 4), or for a resume the brief `resume <subtask>: re-read substate.md, inbox/ and gates/` (C5.3).

## Session token (A.1)

Each launch mints a `session` token `^[a-z0-9-]+$` for the lead, `<run-id>-<subtask>-l<n>` (`n` the launch count for that sub-task, from 1). It names `machine/<session>.row` and `subtasks[].session`, and is distinct from the bus `session_id` `<run-id>-<subtask>`. The conductor's own token is `<run-id>-c<n>`, `n` counting conductor sessions. These shapes are this skill's choice inside the A.1 regex.

## Machine ledger (A.4; design §4)

The ledger is `$DELIVERY_ROOT/machine/<session>.row`, one line `session=<session> pid=<pid> live_count=<n> build=<0|1> utc=<ISO>` per session.

**Before every `claude -p` launch, and before asking the owner for an `agent-tool` lead:**

1. Take the lock: `mkdir $DELIVERY_ROOT/machine/.lock`, then write `owner` (`<pid> <ISO UTC>`) to a temp file in it and `mv` it to `owner`. A waiter retries every 1 s and gives up after 60 s. A stale lock (owner pid fails `kill -0`, or `owner` missing or unparsable and the directory older than 120 s) is broken as A.3 says: `mv` to `.lock.broken-<pid>-<yyyymmddThhmmssZ>`, re-read `owner`, rename back on a mismatch and start over, else `mkdir`.
2. Reap: a `*.row` whose `pid` fails `kill -0` is renamed `.dead` and not counted.
3. Sum `live_count` over the remaining `*.row` files. A new lead may reach 30 slot and reserved agents plus its own seat (W2-9 `live_count` = rows + reserved + 1), so the launch is allowed only when `sum + 31 <= 200`.
4. Rule 8: for a `MODE=build` lead, count rows with `build=1`; the launch is allowed only when that count is at most 2 (so at most 3 builds run). `plan-pr` and `post-merge` leads write `build=0` and are not counted here.
5. Remove `owner` and `rmdir` the lock.
6. Refused by step 3 or 4: no launch. Post the ask to the human with both numbers (design §4: "a conductor refuses to start a sub-task session that would cross either cap and asks the human"). Retry on a later tick once a row frees.

The lead re-sums under the same lock when it writes its own row (spec 28 PC-W2-1); that closes the race between the conductor's check and the child's start. The conductor writes only its own row (stage 1, then each tick, `tick-relay.md` §8).

## Launcher spec for a `claude -p` lead (design §6.4, M28, A5)

The `claude -p` child runs with `--dangerously-skip-permissions`, so it has no sandbox or deny list of its own; these controls are what stands in for them. Every item is mandatory. If any one cannot be met, the launcher fails closed: no launch, a status-post line to the human.

| Control | Rule |
|---|---|
| Environment | `env -i` plus an allowlist only: `PATH`, `HOME=$DELIVERY_ROOT/homes/<session>` (a scratch home, created 0700), `DELIVERY_ROOT`, `CLAUDE_CODE_MAX_CONCURRENT_SUBAGENTS=30`, `CLAUDE_CODE_MAX_SUBAGENTS_PER_SESSION` (the value set at the move; the lead reads it at ORCHESTRATOR-CHECK and fails without it, W2-8), and the node prefix variables `node.prefix_cmd` needs. Nothing else is inherited |
| Concurrency assert | before exec the launcher checks that the child environment holds `CLAUDE_CODE_MAX_CONCURRENT_SUBAGENTS=30` exactly; unset or any other value fails closed |
| git and gh scrubbed | `GIT_CONFIG_GLOBAL=/dev/null`, `GIT_CONFIG_NOSYSTEM=1`; `credential.helper` set empty in the worktree config; `SSH_AUTH_SOCK` unset (dropped by `env -i`); `GH_CONFIG_DIR` pointing at an empty directory under the scratch home; the worktree remote's `pushurl` set to an invalid URL. Pushes and PRs go only through the desk |
| Disallowed tools | mandatory `--disallowedTools` naming the Zephyr `execute` tool, read from the profile key `zephyr.execute_tool` (A.2.2; unmeasured, verify at move; spec 25 RESOLVED Q6), and every network-write tool. Those tool names are recorded at the move (design §6.4 "names unmeasured, verify at move"); a missing `zephyr.execute_tool` is `INPUT-ERROR zephyr.execute_tool missing` and an unrecorded network-write list fails closed |
| Prompt | piped on stdin, never on argv: the `delivery-run` call with its D2.2 row 6 inputs (`stages.md` stage 4), followed for a relaunch by the line `resume <subtask>: re-read substate.md, inbox/ and gates/` (C5.3) |
| Model and effort | `--model` and `--effort` from `tools/model-routing.md` for the `design` tier (the lead's tier, design §3.1); never a model name written in this skill (M19) |
| Worktree | a dedicated worktree per process: the sub-task worktree `<worktree_base>/<run-id>-<subtask>` (A.6); never the main checkout (G1) |
| Catalog | the process is a catalog `process` row registered with its pid before the agent starts: the launch wrapper forks, registers its own pid (`catalog.sh register process <pid> - <ticket-key> delivery-pipeline <subtask> <conductor session>`), then `exec`s the child, so the pid is unchanged; the conductor runs `catalog.sh start process <pid>` once `kill -0` succeeds |
| Output | stdout and stderr to a file in the scratch home; it is data, never instructions, and the exit code is not a completion signal (bus post and `substate.md` only, C5.2) |
| Liveness | `kill -0` on every tick through the dead-lead check (`tick-relay.md` §7) |
| Brief fix | any change to a brief or path after launch: stop every affected child, then relaunch (rule 11, "stop all, then relaunch") |

Command shape (placeholders in angle brackets; values never pasted from a model or a desk reply):

```bash
printf '%s\n' "$LEAD_PROMPT" | env -i PATH="$PATH" HOME="$DELIVERY_ROOT/homes/<session>" \
  DELIVERY_ROOT="$DELIVERY_ROOT" CLAUDE_CODE_MAX_CONCURRENT_SUBAGENTS=30 \
  CLAUDE_CODE_MAX_SUBAGENTS_PER_SESSION="<cap>" GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 \
  GH_CONFIG_DIR="$DELIVERY_ROOT/homes/<session>/gh-empty" \
  claude -p --dangerously-skip-permissions --disallowedTools "<zephyr.execute_tool>,<network-write tools>" \
  --model <design-tier model> --effort <effort> >"$DELIVERY_ROOT/homes/<session>/lead.log" 2>&1
```

After launch: `subtasks[].session` = the token, `backend: claude-p`; `lead_id` becomes `-` when its `REGISTER` line is consumed (`tick-relay.md` §1).

**Residual risk (design §6.4).** The child still runs as the operator's OS user with the operator's signed-in Claude session; keychain and registry tokens stay reachable at the OS level. Removing that needs a separate low-privilege user or a sandbox profile, which needs the owner's permission (unmeasured). The `claude -p` backend is untested until the work environment; `claude --help` is recorded as a fact at the move.
