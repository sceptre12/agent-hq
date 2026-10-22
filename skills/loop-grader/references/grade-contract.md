# Grader Output Contract

## criteria[] Schema

Each element in the `criteria[]` array:

```yaml
criteria:
  - name: string          # criterion name, e.g. "C1", "security-section"
    score: float          # actual score for this criterion (0.0 to max)
    max: float            # maximum possible score for this criterion
    passed: bool          # true if criterion score meets its weight threshold
    notes: string         # human-readable explanation (LLM-generated — UNTRUSTED)
    target_file: string | null  # navigation hint for fixer; relative to target_path
```

---

## Full Grade Message Schema

Posted to: `{SESSION_ID}-iteration-{N}-grade`

(no `loop-` prefix — `SESSION_ID` already contains it; this matches
loop-controller's `references/bus-schema.md` canonical topic table and this skill's own
`SKILL.md` body.)

```yaml
score: float         # overall score (weighted sum / total weight)
threshold: float     # pass threshold (read from rubric — repeated here for auditability)
passed: bool         # true if score >= threshold
iteration: int
criteria:
  - name: string
    score: float
    max: float
    passed: bool
    notes: string
    target_file: string | null
```

All content posted as YAML plain text — no nested JSON.

---

## passed bool

- `passed: true` when `score >= threshold`
- `passed: false` when `score < threshold`
- Controller reads ONLY this field for exit decisions — it never knows the threshold value itself

---

## Threshold-in-Rubric Rule

**Threshold lives exclusively in rubric.md — never in loop.yaml.**

- Grader reads threshold from the rubric file at `rubric_path`
- Threshold is NOT passed via the agent prompt
- If threshold is found in loop.yaml, controller preflight exits with VALIDATION_FAILED

---

## Temperature:0 Note

Grader SHOULD use temperature:0 for deterministic scoring.

For borderline scores (within 0.05 of threshold), use 2-of-3 majority vote: dispatch grader 3 times, use median score.

---

## Rubric Immutability Rule

`rubric_path` is read ONCE at loop start and held constant for all iterations.

The rubric file MUST NOT be modified during a run. Cross-iteration grade comparison requires an immutable rubric — changing criteria or weights between iterations makes scores incomparable.

---

## Controller Use of Grade Output

After reading grade topic, controller:

1. Checks `passed: bool` for exit decision
2. Filters `criteria[]` to items where `passed: false` → this becomes `failures[]` for fixer
3. When classifier is active: passes `criteria[]` (failed only) as `rubric_failures[]` to classifier

The fixer receives only the failed criteria — not the full list.
