# PR Review — Step 1, Step 2 path and Step 9 inside a run (port guard, A.5.2)

Applies when `RUN_HOME` is set. Standalone use (`RUN_HOME` unset) follows `bus-start-standalone.md`.
Inputs from the dispatch prompt, validated in Step 0: `RUN_HOME`, `RUN_ID`, `SUBTASK`, `BUS_PORT` (the
dispatch-plan port table `review-bus` candidate). No port is hardcoded and none is picked here.
Nothing in this flow writes under `/tmp` or `$TMPDIR`.

## Names (set once, used by every step below)

```bash
SESSION_UUID=$(uuidgen | tr '[:upper:]' '[:lower:]' | cut -c1-8)
SESSION_SUFFIX="review-${SESSION_UUID}"
SESSION_ID="${RUN_ID}-${SUBTASK}-${SESSION_SUFFIX}"   # ^[a-z0-9-]+$; never equal to the lead's <run-id>-<subtask> (C1.1)
APP_NAME="swarm-mcp-${RUN_ID}-${SUBTASK}-review"      # carries <run-id>-<subtask>; distinct from the lead's app
DATA_DIR="$RUN_HOME/$SUBTASK/bus"                     # spec value (task 10 §2, Q10-5)
DIFF_DIR="$RUN_HOME/review/$SUBTASK/pr-review-${SESSION_SUFFIX}"   # A.1: review/<subtask>/ is pr-review's
DIFF_PATH="$DIFF_DIR/diff.diff"
PM2=${PM2_BIN:-$(which pm2 2>/dev/null)}
[ -n "${PM2}" ] && [ -x "${PM2}" ] || { echo "ERROR: pm2 binary not found — set PM2_BIN or ensure pm2 is on PATH"; exit 1; }
```

## Order (never reorder)

0. **Pre-check, before any claim.** Stop and report, with nothing claimed or registered, when
   `"$PM2" jlist | command grep -q "\"name\":\"$APP_NAME\""` (the app exists) or when `$DATA_DIR`
   already exists (a directory this review did not create, for example another app's bus). This review
   never starts a second bus on an existing `data_dir` and never deletes one it did not create.
1. **Claim.** Through `skills/port-claim` (Steps 1-4):
   `tools/port-check.sh --claim "$BUS_PORT" 127.0.0.1 "$BUS_PORT" swarm-bus "$RUN_ID" claimed "$RUN_ID-$SUBTASK" "pr-review bus"`.
   - Exit 0: claimed, continue.
   - Exit 1 (taken) or 2 (registry and listener disagree): refuse the launch on `$BUS_PORT`; never
     auto-pick. Make exactly one retry: set `BUS_PORT=$((BUS_PORT + 10))` and run the same `--claim`
     line once more, before any bind (INTERFACES 1.3.0 A.5.2, D2.3, AM-3 / owner OQ-2). If
     `BUS_PORT + 10` exceeds 65535, that counts as the second refusal. Exit 0 on the retry: continue
     with this `BUS_PORT` in every step below. A second exit 1 or 2: stop the line and report to the
     lead (the dispatching `pre-pr-gate`); the report names both ports, and notes that the +10 port may
     be the next sub-task's `review-bus` slot in the dispatch-plan port table. Never a second +10.
   - Exit 3 (usage or registry unusable): stop-the-line.
2. **Register** (all `planned`), before the launch, with the INTERFACES script-table signature
   `catalog.sh register <kind> <handle> - <correlation_id> pr-review "$SUBTASK" <owner_agent>` (A.5:
   `source` column 12 = `pr-review`, the appending skill; `owner_agent` column 8 = this orchestrator's
   `agent_id`; `correlation_id` column 5 = the dispatching `pre-pr-gate`'s value for this sub-task,
   `<JIRA-KEY>`, `PR-<n>` or `run`, from the dispatch prompt; its field name is an integrator gap like
   the other dispatch-prompt fields): kinds `port` (`$BUS_PORT`), `pm2-app` (`$APP_NAME`), `bus`
   (`$DATA_DIR`) and `tmpdir` (`$DIFF_DIR`). See the `resource-catalog` skill.
3. **Launch**, with the port pinned so `get-port` cannot choose another (the retry port when the
   retry was taken, C1.1):
   ```bash
   mkdir -p "$DATA_DIR/logs" "$DIFF_DIR"
   printf '%s\n' "$APP_NAME" > "$DATA_DIR/.created-by"   # cleanup removes only a dir this marker proves it created
   cd ~/projects/agent-hq/tools/swarm-communication-layer || { echo "ERROR: swarm-communication-layer not found"; exit 1; }
   export NVM_DIR="$HOME/.nvm"; [ -s "${NVM_DIR}/nvm.sh" ] && source "${NVM_DIR}/nvm.sh" && nvm use --lts > /dev/null 2>&1
   DATA_DIR="$DATA_DIR" APP_NAME="$APP_NAME" PORT_RANGE_START="$BUS_PORT" PORT_RANGE_END="$BUS_PORT" \
     NODE_ENV=production "$PM2" start ecosystem.config.cjs
   ```
   Then poll the port file and require the claimed port:
   ```bash
   TRIES=0; until [ -f "$DATA_DIR/port" ] || [ $TRIES -ge 30 ]; do sleep 0.3; TRIES=$((TRIES + 1)); done
   [ -f "$DATA_DIR/port" ] || { echo "ERROR: port file not written after 9s"; exit 1; }
   PORT=$(cat "$DATA_DIR/port")
   [ "$PORT" = "$BUS_PORT" ] || { echo "ERROR: bus bound $PORT, not the claimed $BUS_PORT — stop and report"; exit 1; }
   ```
   Then run the `/health` check, the three identity samples (`app_name` = `$APP_NAME`, `data_dir` =
   `$DATA_DIR`) and the loopback guard exactly as in `bus-start-standalone.md` "Step 1", from the
   `curl -sf http://localhost:${PORT}/health` line through the bind-address guard (they use `PORT`,
   `APP_NAME` and `DATA_DIR`, all set here).
4. **Start**: `catalog.sh start <kind> <handle>` for the four rows. Print and capture
   `SESSION_ID`, `DATA_DIR`, `APP_NAME`, `PORT`, `DIFF_PATH` and `SESSION_SUFFIX`.

**Stop after a claim** (`resource-catalog/references/ports.md`, failure branches). Any stop after step 1
succeeded (port-file mismatch, health, identity or loopback failure): run the cleanup below for what this
review created; release the claim at once with a `released` row through `port-claim`
(`port-check.sh --claim "$BUS_PORT" 127.0.0.1 "$BUS_PORT" swarm-bus "$RUN_ID" released "$RUN_ID-$SUBTASK" "pr-review bus"`);
then mark every catalog row registered so far `catalog.sh fail <kind> <handle>` (the launch failed;
`release` is only for rows that ran); then report.

The PreToolUse hook `tools/hooks/port-precheck.sh` is advisory: it catches a launch outside this path, it
does not replace the claim. `tools/port-check.sh`, the hook and `catalog.sh` arrive with their own
branches (port-guard PR, `resource-catalog`); this flow runs once they are on the branch.

## Step 2 inside a run

Step 2 uses the `DIFF_PATH` above (from Step 1), never a `/tmp` path (`/tmp` is unwritable in the
executor tier). The scripts in `diff-fetch.md` take `DIFF_PATH` as an input.

## Cleanup (Step 9, inside a run)

`end_session` (explicit `session_id`), then:

```bash
APP_NAME="$APP_NAME" DATA_DIR="$DATA_DIR" DIFF_PATH="$DIFF_PATH" DIFF_DIR="$DIFF_DIR" RUN_HOME="$RUN_HOME" SUBTASK="$SUBTASK" bash -c '
  PM2=${PM2_BIN:-$(which pm2 2>/dev/null)}
  [ -n "$PM2" ] && [ -x "$PM2" ] && "$PM2" delete "$APP_NAME" 2>/dev/null || true
  [ -n "$RUN_HOME" ] && [ "$DIFF_PATH" = "$DIFF_DIR/diff.diff" ] && rm -f "$DIFF_PATH" && rmdir "$DIFF_DIR"
  [ -n "$RUN_HOME" ] && [ "$DATA_DIR" = "$RUN_HOME/$SUBTASK/bus" ] \
    && [ "$(cat "$DATA_DIR/.created-by" 2>/dev/null)" = "$APP_NAME" ] && rm -rf "$DATA_DIR"
'
```

Literal paths only, never a glob, never `/tmp`. The bus directory is removed only when its
`.created-by` marker names this review's `APP_NAME`; otherwise it is left in place and reported. Then
release the port claim through `port-claim` and `catalog.sh release` the four rows. Release is cleanup
only.
