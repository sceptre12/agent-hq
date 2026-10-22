# Runner Output Contract

## YAML Schema

Posted to: `{SESSION_ID}-iteration-{N}-runner-output` — this exact string, **no
extra `loop-` prefix**; `SESSION_ID` already contains it (canonical registry:
`loop-controller/references/bus-schema.md`). Post it using the canonical `jq --arg`
+ curl pattern in `SKILL.md` step 8, with `session_id` passed explicitly.

```yaml
artifact_path: string | null   # null when status=failed
run_id: string                 # equals SESSION_ID
iteration: int                 # current iteration number (1-indexed)
status: success | failed       # required field — always present
error_detail: string | null    # populated when status=failed; null otherwise
```

---

## Null artifact_path Rule

- `artifact_path` MUST be `null` when `status: failed`
- `artifact_path` MUST be a non-null string when `status: success`
- Controller MUST NOT dispatch grader when `artifact_path: null`

---

## Always-Post Requirement

The runner MUST post to the bus topic on ALL outcomes — including failure.

- On success: post with `status: success`, `artifact_path: <path>`
- On failure: post with `status: failed`, `artifact_path: null`, `error_detail: <reason>`

**Never silently fail.** If the runner exits without posting to the bus topic, the
controller will hang awaiting `AWAIT_RUNNER` indefinitely.

---

## artifact_path Constraint

- Runner writes output to: `/tmp/{SESSION_ID}/runner-output/iter-{N}/`
- `artifact_path` must resolve within `DATA_DIR` (i.e. within `/tmp/{SESSION_ID}/`)
- Paths outside DATA_DIR are invalid — controller will reject them
- Runner must create the output directory if it does not exist

---

## Controller Behavior on Runner Failure

When runner posts `status: failed`:
1. Controller skips grader dispatch
2. Controller dispatches fixer with `error_detail` from this message
3. Iteration is counted (N++ still occurs)
4. No grade topic is produced for this iteration (gap in grade sequence is expected)

---

## Example Messages

### Success
```yaml
artifact_path: /tmp/loop-skill-refiner-20260609-a3f2/runner-output/iter-1/output.md
run_id: loop-skill-refiner-20260609-a3f2
iteration: 1
status: success
error_detail: null
```

### Failure
```yaml
artifact_path: null
run_id: loop-skill-refiner-20260609-a3f2
iteration: 1
status: failed
error_detail: "SKILL.md at target_path not found"
```
