# Bus Schema Reference

## Canonical Bus Topic Table

| Topic | Written by | Read by | Normal path | Error path |
|---|---|---|---|---|
| `{SESSION_ID}-iteration-{N}-runner-output` | loop-runner | controller | yes | yes (status=failed) |
| `{SESSION_ID}-iteration-{N}-grade` | loop-grader | controller | yes | no |
| `{SESSION_ID}-iteration-{N}-classified` | loop-finding-classifier | controller | yes (classifier path) | no |
| `{SESSION_ID}-iteration-{N}-fixed` | loop-fixer | controller | yes | yes (runner-error path) |
| `{SESSION_ID}-iteration-{N}-regression-rollback` | controller | audit/observability only | yes (regression gate) | no |
| `{SESSION_ID}-result` | controller | the orchestrator that dispatched loop-controller (not loop-setup) | yes | yes (EXIT_ERROR) |

> **Note (runner-output):** loop-grader receives `artifact_path` via its agent-prompt
> dispatch — it does not read the runner-output topic directly.

> **Note (runner-output):** `artifact_path` in runner-output messages is always a file
> path, never a directory (result messages carry no `artifact_path` field at all — see
> `final_artifact_path` in the result message schema below).

---

## Canonical Topic Name Strings

Every topic string below uses `{SESSION_ID}` with **no extra `loop-` prefix** —
`SESSION_ID` already contains one (see derivation in `SKILL.md` pre-flight). A topic
with a doubled prefix is one nothing subscribes to; the controller hangs in its AWAIT
state forever.

```
{SESSION_ID}-iteration-{N}-runner-output
{SESSION_ID}-iteration-{N}-grade
{SESSION_ID}-iteration-{N}-classified
{SESSION_ID}-iteration-{N}-fixed
{SESSION_ID}-result
```

---

## Message Shape (YAML plain text — no nested JSON)

### runner-output message
```yaml
artifact_path: string | null   # null when status=failed
run_id: string
iteration: int
status: success | failed
error_detail: string | null
```

### grade message
```yaml
score: float
threshold: float
passed: bool
iteration: int
criteria:
  - name: string
    score: float
    max: float
    passed: bool
    notes: string
    target_file: string | null
```

### classified message
```yaml
in_scope:
  - finding_id: string
    severity: Blocking | Medium | Advisory
    description: string
    fix: string | null
    maps_to: string
    target_file: string | null
deferred:
  - finding_id: string
    severity: Blocking | Medium | Advisory
    description: string
    reason: string
run_id: string
iteration: int
```

### fixed message
```yaml
status: success | failed
target_path: string
iteration: int
error_detail: string | null
```

### regression-rollback message
```yaml
grade_score: float
best_score: float
best_iteration: int
rollback_failed: bool
```

### result message
```yaml
# EXIT_PASS
exit_reason: PASS
best_score: float
best_iteration: int
iterations_completed: int
final_artifact_path: string
rollback_count: int
rollback_failed: bool
deferred_findings: []

# EXIT_EXHAUSTED
exit_reason: EXHAUSTED
best_score: float
best_iteration: int
iterations_completed: int
final_artifact_path: string   # target_path after restore to best-scoring iteration
rollback_count: int
rollback_failed: bool
deferred_findings: []

# EXIT_ERROR
exit_reason: ERROR
reason: TIMEOUT | VALIDATION_FAILED | BUS_START_FAILED | RUNNER_FAILED | GRADER_FAILED | FIXER_FAILED | CLASSIFIER_FAILED
best_score: float
best_iteration: int
iterations_completed: int
final_artifact_path: null
rollback_count: int
rollback_failed: bool
deferred_findings: []
```

---

## run_id vs SESSION_ID

`run_id` in bus message payloads and `SESSION_ID` in topic strings are the same value.
When constructing a topic string, always use `SESSION_ID`; when populating a `run_id`
field in a payload, pass `SESSION_ID`.

---

## Quorum and Timeout Behavior

- **No quorum model.** Each topic is written by exactly one block (single writer per
  topic per iteration).
- **Timeout:** governed by the Agent tool's built-in behavior — no configurable
  timeout parameter is actually enforced in this skill's Steps.
  `runner_timeout_seconds` (loop-yaml-schema.md) is validated pre-flight but declared
  but not currently enforced (port-time note): there is no bus-polling watchdog for
  the runner AWAIT state anywhere in the controller's Steps.
- **Production recommendation:** wrap each dispatch in an external watchdog process that
  kills the controller after N minutes and posts EXIT_ERROR to the result topic.
- **Port file polling:** bus port file at `$DATA_DIR/port` — the *only* legitimate port
  source (never hardcode a port number). Poll max 30 × 0.3s = 9s; `BUS_START_FAILED` if
  absent after timeout.
- **Health gate:** after the port poll, sample `/health` 2-3 times and require both
  `"status":"ok"` **and** `app_name`/`data_dir` matching this session's `APP_NAME`/
  `DATA_DIR` in every response, before any sub-agent is dispatched (see `SKILL.md`
  Bootstrap Sequence and the `swarm-communication` skill, which this identity discipline
  is shared with).
- **Error path fixer topic:** on runner failure (`status: failed`), the controller
  dispatches the fixer with `error_detail`. The fixer posts to the **same**
  `{SESSION_ID}-iteration-{N}-fixed` topic on both the normal and runner-error paths.

## Bus post pattern (canonical)

Build every bus post with `jq --arg` to a temp JSON file, never an inline
`-d "{...}"` string — inline interpolation breaks silently on newlines/quotes/YAML
special characters in `error_detail`, `grader_notes`, or finding descriptions, and is
also the shell-injection surface `references/agent-briefs.md` documents. This is the
same canonical pattern `loop-fixer` and `loop-runner` use for their own bus posts:

```bash
PORT=$(cat "$DATA_DIR/port")   # port comes only from this file — never hardcode it

CONTENT="exit_reason: PASS
best_score: ${BEST_SCORE}
best_iteration: ${BEST_ITERATION}
iterations_completed: ${N}
final_artifact_path: ${TARGET_PATH}
rollback_count: ${ROLLBACK_COUNT}
rollback_failed: ${ROLLBACK_FAILED}
deferred_findings: ${DEFERRED_FINDINGS_YAML}"

jq -n \
  --arg topic "${SESSION_ID}-result" \
  --arg session_id "${SESSION_ID}" \
  --arg from_agent "controller" \
  --arg content "${CONTENT}" \
  '{"jsonrpc":"2.0","method":"tools/call","params":{"name":"broadcast","arguments":{"from_agent":$from_agent,"topic":$topic,"content":$content,"session_id":$session_id}},"id":1}' \
  > "/tmp/${SESSION_ID}-bus-post.json"

curl -s -X POST "http://localhost:${PORT}/mcp" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  --data "@/tmp/${SESSION_ID}-bus-post.json"
```

`session_id` is always passed explicitly — never rely on it being ambient or inherited
(swarm-communication-layer discrepancy #6: an omitted `session_id` produces a
NULL-tagged row `end_session` can never clean up).

## AWAIT polling (read_messages)

```bash
jq -n \
  --arg agent_id "controller" \
  --arg session_id "${SESSION_ID}" \
  --arg topic "${SESSION_ID}-iteration-${N}-grade" \
  '{"jsonrpc":"2.0","method":"tools/call","params":{"name":"read_messages","arguments":{"agent_id":$agent_id,"session_id":$session_id,"topics":[$topic],"peek":true}},"id":1}' \
  > "/tmp/${SESSION_ID}-poll.json"

curl -s -X POST "http://localhost:${PORT}/mcp" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  --data "@/tmp/${SESSION_ID}-poll.json"
```

Poll every 5 seconds until a message appears. If the sub-agent returns without posting,
that is EXIT_ERROR — never retry inline, never impersonate the sub-agent's post.
