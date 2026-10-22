# loop.yaml Schema Reference

`loop.yaml` is the single configuration file the controller reads at pre-flight, under
`~/projects/loops/<slug>/loop.yaml`. All fields are validated (or, for `finding_classifier`,
explicitly *not* validated — see below) before any sub-agent is dispatched.

---

## Fields

### `schema_version`
- **Type:** integer, required
- **Must equal:** `1`
- **Validated:** pre-flight step 1
- **Consumed by:** controller only
- **VALIDATION_FAILED message:** `schema_version must be 1, got {value}`

---

### `target_path`
- **Type:** string, required
- **Purpose:** Path to the single file being refined across iterations. Must name
  exactly one file, never a directory — the loop's snapshot/rollback (`SKILL.md`
  Security section) does a plain `cp`, not a recursive copy, so a directory here
  would silently fail to roll back. Every runner/fixer brief in this set
  (`loop-runner/briefs/{skill,script}.md`, `loop-fixer/briefs/{skill,code}.md`)
  states the same single-file rule and notes that any companion files a brief also
  edits live alongside `target_path` but are not themselves snapshotted or rolled
  back.
- **Validated:** pre-flight — must exist, resolve via `realpath`, fall within allowed roots
  (`~/projects/`, `~/.claude/skills/`)
- **Consumed by:** controller (passes to runner and fixer on each iteration)
- **VALIDATION_FAILED messages:** two distinct messages are emitted — one for resolution
  failure (`target_path could not be resolved — path does not exist`) and one for
  out-of-root failure (`target_path outside allowed roots (~/projects, ~/.claude/skills)`).

---

### `test_artifact`
- **Type:** string, required
- **Purpose:** Path to the test input passed to the runner on each iteration
- **Validated:** pre-flight — must exist
- **Consumed by:** controller (passed to runner brief as context)
- **VALIDATION_FAILED message:** `test_artifact does not exist: {path}`

---

### `runner_brief`
- **Type:** string, required
- **Purpose:** Path to the runner brief file; defines runner instructions
- **Validated:** pre-flight — must exist; must contain a `## Security` section
- **Consumed by:** loop-runner sub-agent
- **VALIDATION_FAILED message:** `runner_brief not found or missing ## Security section: {path}`
- **Path validation note:** must be absolute or project-relative; reject paths containing
  `..` or that resolve outside the project root.

---

### `rubric_path`
- **Type:** string, required
- **Purpose:** Path to the rubric file; **immutable during a run** — the controller reads
  it once at pre-flight
- **Validated:** pre-flight — must exist
- **Consumed by:** loop-grader sub-agent (controller passes the path)
- **VALIDATION_FAILED message:** `rubric_path does not exist: {path}`

---

### `fixer_brief`
- **Type:** string, required
- **Purpose:** Path to the fixer brief file; defines fixer instructions
- **Validated:** pre-flight — must exist; must contain a `## Security` section
- **Consumed by:** loop-fixer sub-agent
- **VALIDATION_FAILED message:** `fixer_brief not found or missing ## Security section: {path}`

---

### `finding_classifier`
- **Type:** string | null, optional (default: `null`)
- **Purpose:** A **pure feature-flag path**: non-null activates the classifier path
  (loop-finding-classifier is dispatched each iteration and its `in_scope`/`deferred`
  output gates the fixer and the dual-gate PASS check per `references/state-machine.md`).
  Null disables the classifier path entirely — the no-classifier path runs instead.
- **Validated:** pre-flight — **presence/nullity only.** The controller does **not**
  check that the path exists, is readable, or contains a `## Security` section, and does
  **not** read its content or pass it to loop-finding-classifier.
- **Consumed by:** nothing reads this path's *content* today — loop-finding-classifier's
  own contract (its `SKILL.md` Inputs) declares no brief-file input at all. Treat the field
  purely as the boolean "is the classifier path on" switch.
- **Refit note (Gate 2 fix):** the source skill validated this field at pre-flight exactly
  like `runner_brief`/`fixer_brief` (existence + `## Security` header, `VALIDATION_FAILED`
  otherwise) — but no dispatch call anywhere ever passed the path to
  loop-finding-classifier, and loop-finding-classifier's own contract never declared a
  brief-file input. That validated value was fully orphaned. This port resolves it by
  documenting the field as content-free (this entry) rather than by inventing a
  content-consuming behavior loop-finding-classifier doesn't implement. If brief-driven
  classifier customization is wanted later, add the field to loop-finding-classifier's
  declared Inputs and its dispatch call together, in the same change — not as a
  pre-flight-only gate with no downstream consumer.

---

### `max_iterations`
- **Type:** integer, required, minimum 1
- **Purpose:** Hard iteration ceiling; controller exits EXIT_EXHAUSTED when `N >= max_iterations`
- **Validated:** pre-flight — must be integer ≥ 1
- **Consumed by:** controller (enforced after every grade/classify step)
- **VALIDATION_FAILED message:** `max_iterations must be an integer >= 1, got {value}`

---

### `rollback_on_regression`
- **Type:** bool, optional, **default: false**
- **Purpose:** When true, controller overwrites `target_path` with the best-scoring
  `.bak` snapshot on score regression; recommended only for monotonic-improvement loops
- **Consumed by:** controller only — never passed to runner, grader, fixer, or classifier
- **Known constraint:** a plain boolean cannot express an "only restore at EXIT_EXHAUSTED"
  mode; that would need a v2 extension.

---

### `log_path`
- **Type:** string | null, optional (default: `null`)
- **Purpose:** Path for the run log file (JSONL); `null` disables run logging
- **Validated:** pre-flight — if non-null, parent directory must exist
- **Consumed by:** controller only — never passed to runner, grader, fixer, or classifier
- **VALIDATION_FAILED message:** `log_path parent directory does not exist: {path}`

---

### `runner_timeout_seconds`
- **Type:** integer, optional, default: 1800
- **Purpose:** Maximum seconds to wait for the runner to post to its bus topic before EXIT_ERROR
- **Validated:** pre-flight — if present, must be integer ≥ 1
- **Consumed by:** declared but not currently enforced (port-time note) — no
  bus-polling watchdog implementing this field exists anywhere in the controller's
  Steps; `state-machine.md`'s `AWAIT_RUNNER` row relies solely on the Agent tool's own
  built-in dispatch timeout. This field is validated pre-flight and never injected
  into any sub-agent dispatch (it is controller-only, per the Sub-agent Consumption
  Summary table below).
- **VALIDATION_FAILED message:** `runner_timeout_seconds must be an integer >= 1, got {value}`

---

### `threshold` — FORBIDDEN

`threshold` **must not appear in `loop.yaml`.** Threshold belongs exclusively in `rubric.md`.
If `threshold` is present as a key, the controller exits immediately:

```
VALIDATION_FAILED: threshold field found in loop.yaml — threshold belongs exclusively in rubric.md
```

---

## Minimal Valid Example

```yaml
schema_version: 1
target_path: ~/projects/my-project/doc.md
test_artifact: ~/projects/my-project/test-input.md
runner_brief: ~/.claude/skills/loop-runner/briefs/skill.md
rubric_path: ~/projects/my-project/rubric.md
fixer_brief: ~/.claude/skills/loop-fixer/briefs/skill.md
max_iterations: 5
rollback_on_regression: false  # optional bool, default false — controller only
```

---

## Sub-agent Consumption Summary

Fields NOT passed to sub-agents: `rollback_on_regression`, `log_path`, and
`runner_timeout_seconds` are controller-only, never injected into any dispatch prompt
(see the table below — all three are "no" across every sub-agent column).

| Field | Runner | Grader | Fixer | Classifier | Controller |
|---|---|---|---|---|---|
| target_path | yes | no | yes | no | yes |
| test_artifact | yes | no | no | no | yes |
| runner_brief | yes | no | no | no | yes |
| rubric_path | no | yes | no | no | yes |
| fixer_brief | no | no | yes | no | yes |
| finding_classifier | no | no | no | no (flag only — see entry above) | yes |
| max_iterations | no | no | no | no | yes |
| rollback_on_regression | no | no | no | no | yes (controller only) |
| log_path | no | no | no | no | yes (controller only) |
| runner_timeout_seconds | no | no | no | no | yes |

## Slug format

The canonical slug pattern is `^[a-z0-9_-]+$` (letters, digits, hyphen, underscore) — this
is the broader of the two patterns seen across the loop-* family and is the one this
skill enforces (pre-flight step 1 and the state-machine secondary guard, both in
`SKILL.md`). loop-setup's own validator is a strict subset of this pattern; if the two
ever diverge, this file is the source of truth for loop-controller's own acceptance.
