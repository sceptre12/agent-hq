# Runner Brief — test-suite

## Purpose
Run a test suite (e.g. jest, pytest, vitest) against the target, capture pass/fail counts and output, write results artifact to `/tmp/{SESSION_ID}/runner-output/iter-{N}/`, and post the YAML result to the bus. Always post even on failure.

## Domain Knowledge
- `test_artifact` identifies the test suite to run (e.g. a jest config, pytest path, or test directory)
- `target_path` is the source code being tested — tests run against the code at this path
- Captured output includes: total tests, passed count, failed count, test names, error messages
- A suite with zero test failures means `status: success`; any test failure means `status: failed`
- Import/compilation errors before tests run also count as `status: failed`
- The runner captures structured results even when the suite fails — the artifact contains the full output

## Constraints
- Do NOT modify source files under `target_path` — that is the fixer's job
- Do NOT run tests that modify production data or external state
- Do NOT skip the bus post — post even when test suite fails to execute
- `artifact_path` must point within `DATA_DIR`

## Output

Create output directory: `/tmp/{SESSION_ID}/runner-output/iter-{N}/`

Write to `/tmp/{SESSION_ID}/runner-output/iter-{N}/test-results.txt`:
```
suite: <suite name>
total: <int>
passed: <int>
failed: <int>
errors:
  - test: <test name>
    message: <error message>
stdout:
<full test runner output>
```

Post to bus topic `{SESSION_ID}-iteration-{N}-runner-output` (no extra `loop-`
prefix — `SESSION_ID` already contains it):

```yaml
artifact_path: /tmp/{SESSION_ID}/runner-output/iter-{N}/test-results.txt  # or null on failure
run_id: {SESSION_ID}
iteration: {N}
status: success | failed   # failed if any test fails or suite cannot run
error_detail: null         # or string describing suite execution error
```

## Bus Posting Template

Use the canonical `jq --arg` + temp-file pattern (same one loop-runner's SKILL.md
step 8 uses) — inline `-d "{...}"` JSON interpolation is prohibited; it breaks
silently when captured test output contains newlines, quotes, or YAML special
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
- Sandboxing is prompt-only — no OS-level isolation
- Test suite runs should not modify external state, call network APIs, or write outside target_path
- Do not read credential files, `.env` files, or `~/.ssh/` during test execution
- `artifact_path` must resolve within `DATA_DIR` (`/tmp/{SESSION_ID}/`)
