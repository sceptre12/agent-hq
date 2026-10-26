# Wave 3 — verify

- **goal:** Confirm the fixed docs are clean: zero open findings and passing
  Markdown lint.
- **inputs:** `fixed_docs` (Wave 2 output).
- **work_items:** a single verification pass covering all of `fixed_docs`.
- **agents:** 1, model: sonnet.
- **gate_type:** `judge_panel` (ADR 0023 graft 3 — demonstrates
  `references/spec-format.md` § Gate and output-schema fields; this wave
  closes the audit/fix cycle, so its correctness is worth a panel rather than
  a single check).
- **judges:** 3
- **exit_criteria** (supplied verbatim to all 3 judges as the panel rubric):
  - Verifier reports zero findings across every doc in `fixed_docs`.
  - Markdown lint passes on every doc in `fixed_docs`.
- **outputs:** none (Wave 4 reads Wave 2's `fixed_docs` directly).
