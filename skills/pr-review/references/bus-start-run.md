# PR Review — Step 1 inside a run (port guard, A.5.2)

Applies when `RUN_HOME` is set. Standalone use (`RUN_HOME` unset) keeps the Step 1 script in
`SKILL.md` unchanged. Inputs from the dispatch prompt: `RUN_HOME`, `RUN_ID`, `SUBTASK`, `BUS_PORT`
(the dispatch-plan port table `review-bus` candidate; Step 0 refuses a missing one with
`INPUT-ERROR BUS_PORT missing`). No port is hardcoded and none is picked here.

## Order (never reorder)

1. **Claim.** Through `skills/port-claim` (Steps 1-4):
   `tools/port-check.sh --claim "$BUS_PORT" 127.0.0.1 "$BUS_PORT" swarm-bus "$RUN_ID" claimed "$RUN_ID-$SUBTASK" "pr-review bus"`.
   - Exit 0: claimed, continue.
   - Exit 1 (taken) or 2 (registry and listener disagree): refuse the launch. Do not add 10, do not
     auto-pick another port. Report to the lead (the dispatching `pre-pr-gate`).
   - Exit 3 (usage or registry unusable): stop-the-line.
2. **Register** (all `planned`), before the launch: `catalog.sh register` for kinds `port`
   (`$BUS_PORT`), `pm2-app` (`$APP_NAME`), `bus` (`$DATA_DIR`) and `tmpdir` (the diff scratch dir),
   with correlation id `$RUN_ID-$SUBTASK`.
3. **Launch**, with the port pinned so `get-port` cannot choose another:
   ```bash
   DATA_DIR="$RUN_HOME/$SUBTASK/bus"; APP_NAME="swarm-mcp-$RUN_ID-$SUBTASK"
   "$PM2" jlist | command grep -q "\"name\":\"$APP_NAME\"" && { echo "ERROR: pm2 app exists"; exit 1; }
   mkdir -p "$DATA_DIR/logs"
   DATA_DIR="$DATA_DIR" APP_NAME="$APP_NAME" PORT_RANGE_START="$BUS_PORT" PORT_RANGE_END="$BUS_PORT" \
     NODE_ENV=production "$PM2" start ecosystem.config.cjs
   ```
   Then poll `$DATA_DIR/port` as in the standalone script. If `$(cat "$DATA_DIR/port")` is not equal to
   `$BUS_PORT`, stop and report; do not continue on the other port. Run the health, identity-sample and
   loopback checks of the standalone script unchanged.
4. **Start**: `catalog.sh start` for the four rows. The `SESSION_ID` includes `$RUN_ID-$SUBTASK`.

The PreToolUse hook `tools/hooks/port-precheck.sh` is advisory: it catches a launch outside this path, it
does not replace the claim.

## Cleanup (Step 9, inside a run)

`end_session`, `pm2 delete "$APP_NAME"`, then remove the bus directory only when it is exactly the literal
`$RUN_HOME/$SUBTASK/bus` (`[ "$DATA_DIR" = "$RUN_HOME/$SUBTASK/bus" ]` and `$RUN_HOME` non-empty; never a
glob, never `/tmp`). Then `catalog.sh` marks the rows released. Release is cleanup only.
