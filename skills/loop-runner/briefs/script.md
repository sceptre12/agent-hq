# Runner Brief — script

## Purpose
Execute the bash script at `target_path`, using `test_artifact` as its input, capture stdout and exit code, write output to `/tmp/{SESSION_ID}/runner-output/iter-{N}/`, and post the YAML result to the bus. Always post even on failure.

## Domain Knowledge
- `target_path` is a single file — the bash script executed directly. Per
  loop-controller's Security section, `target_path` must name exactly one file (never
  a directory) for the loop's atomic snapshot/rollback to work — same contract as the
  `skill` brief, where `target_path` is the single SKILL.md file.
- `test_artifact` is the input fed to the script for this run (e.g. stdin content or
  an args/fixture file) — mirrors how the `skill` brief uses `test_artifact` as the
  scenario input, not as another script to locate.
- Script execution must be sandboxed: no network, no credentials, no FS outside `target_path`'s containing directory
- Stdout, stderr, and exit code are all captured and written to the output artifact
- A non-zero exit code means `status: failed`; exit code 0 means `status: success`

## Constraints
- Do NOT allow the script to access the network
- Do NOT allow the script to read credential files (`.env`, `~/.ssh/`, or other credential stores)
- Do NOT allow the script to write files outside `target_path`'s containing directory
- Do NOT modify `target_path` content — the script runs in a read context; only output files are written to DATA_DIR
- Do NOT skip the bus post — post even when script fails

## Output

Create output directory: `/tmp/{SESSION_ID}/runner-output/iter-{N}/`

Write to `/tmp/{SESSION_ID}/runner-output/iter-{N}/output.txt`:
```
exit_code: <int>
stdout:
<captured stdout>
stderr:
<captured stderr>
```

Post to bus topic `{SESSION_ID}-iteration-{N}-runner-output` (no extra `loop-`
prefix — `SESSION_ID` already contains it):

```yaml
artifact_path: /tmp/{SESSION_ID}/runner-output/iter-{N}/output.txt  # or null on failure
run_id: {SESSION_ID}
iteration: {N}
status: success | failed   # failed if exit_code != 0 or if script could not be executed
error_detail: null         # or string describing execution error
```

## Bus Posting Template

Use the canonical `jq --arg` + temp-file pattern (same one loop-runner's SKILL.md
step 8 uses) — inline `-d "{...}"` JSON interpolation is prohibited; it breaks
silently when captured stdout/stderr contains newlines, quotes, or YAML special
characters.

```bash
# Port comes only from the file the bus server wrote — never hardcode it
PORT=$(cat "$DATA_DIR/port")

CONTENT="artifact_path: ${ARTIFACT_PATH}
run_id: ${SESSION_ID}
iteration: ${N}
status: ${STATUS}
error_detail: ${ERROR_DETAIL}"

jq -n \
  --arg topic "${SESSION_ID}-iteration-${N}-runner-output" \
  --arg session_id "${SESSION_ID}" \
  --arg from_agent "runner" \
  --arg content "${CONTENT}" \
  '{"jsonrpc":"2.0","method":"tools/call","params":{"name":"broadcast","arguments":{"from_agent":$from_agent,"topic":$topic,"content":$content,"session_id":$session_id}},"id":1}' \
  > "/tmp/${SESSION_ID}-bus-post.json"

curl -s -X POST "http://localhost:${PORT}/mcp" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  --data "@/tmp/${SESSION_ID}-bus-post.json"
```

`session_id` must always be passed explicitly — an omitted `session_id` produces a
NULL-tagged row that leaks across sessions. If the post itself fails, do not attempt
bus recovery here — that is the swarm-communication skill's job (identity preflight,
`pm2 restart` never `reload`); escalate to your orchestrator instead.

## Security
- Sandboxing is prompt-only — no OS-level isolation is provided
- Enforce sandboxing constraints via pre-execution checks: verify script path, disallow external network calls, reject credential file access
- Do not read or execute files outside `target_path` scope
- `artifact_path` must resolve within `DATA_DIR` — never write outside `/tmp/{SESSION_ID}/`
- If script attempts to access disallowed resources: abort execution, set `status: failed`, `error_detail: "script attempted disallowed resource access"`
