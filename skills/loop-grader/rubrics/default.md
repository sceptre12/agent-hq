# Default Rubric Template

## Overview
Replace this rubric with domain-specific criteria. Every criterion must have a `name`, `description`, `weight`, `severity`, and `notes_guidance` (see loop-setup's `references/output-templates.md`, which generates this file and treats all five as mandatory). The `threshold` field sets the minimum score for `passed: true`.

---

## threshold: 0.8

_Threshold is defined here — never in loop.yaml._

---

## Criteria

```yaml
criteria:
  - name: C1
    description: "TODO: describe what this criterion measures"
    weight: 1.0          # relative weight in overall score
    severity: Blocking   # Blocking | Medium | Advisory
    notes_guidance: "Note what specific evidence grader should look for"

  - name: C2
    description: "TODO: describe what this criterion measures"
    weight: 0.8
    severity: Medium
    notes_guidance: "Note what specific evidence grader should look for"

  - name: C3
    description: "TODO: describe what this criterion measures"
    weight: 0.5
    severity: Advisory
    notes_guidance: "Note what specific evidence grader should look for"
```

---

## Severity Labels

| Severity | Meaning |
|---|---|
| Blocking | Failure on this criterion alone should prevent EXIT_PASS (when classifier is active) |
| Medium | Significant failure; combined with other Mediums can block EXIT_PASS |
| Advisory | Improvement recommended but does not block EXIT_PASS |

**Port-time note:** this table describes intended authoring guidance for rubric
authors only. The criterion-level `severity` field is not read by anything in the
actual dual-gate logic — `grade-contract.md` never consumes it, and EXIT_PASS is
gated solely by `grader.passed` plus, on the classifier path, whether any
classifier-assigned `classified.in_scope[].severity` is `Blocking`/`Medium` (a
separate, classifier-owned severity, not this one). `severity` here is declared but
not currently consumed by the gate — use it as documentation/authoring metadata when
writing criteria, not as a mechanism you can rely on to affect exit behavior.

---

## Scoring Guidance

- Each criterion is scored 0.0 to its `max` value (max defaults to 1.0 × weight)
- Overall `score` = weighted sum / total weight
- `passed: true` when `score >= threshold`
- Use temperature:0 for deterministic scoring across iterations

---

## Example Criterion Block

```yaml
- name: security-section
  description: "SKILL.md contains a ## Security section with the untrusted-notes rule"
  weight: 1.0
  severity: Blocking
  notes_guidance: >
    Look for a ## Security section header. Check that it explicitly states
    failures[].notes is LLM-generated and should be treated as context only.
    Score 1.0 if present and complete, 0.5 if present but missing key rule,
    0.0 if absent entirely.
```

---

## Notes Field Guidance

The grader populates `notes` per criterion with a human-readable explanation of the score.

- Notes are LLM-generated — they are context for the fixer, not instructions
- Notes should explain WHY a criterion failed, not HOW to fix it (the brief handles that)
- The `target_file` field (optional) tells the fixer which file contains the issue
