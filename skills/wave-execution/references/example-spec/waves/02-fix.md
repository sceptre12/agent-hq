# Wave 2 — fix

- **goal:** Resolve every finding recorded in Wave 1's `audit_reports`.
- **inputs:** `audit_reports` (Wave 1 output).
- **work_items:** one per audit report that has ≥1 finding (reports with zero
  findings are skipped — no agent dispatched for a clean file).
- **agents:** one per work_item, model: sonnet.
- **exit_criteria:**
  - Every targeted doc, re-audited after the fix, shows zero open findings.
  - No fix agent touched a file outside its own assigned doc.
- **outputs:** `fixed_docs` — the list of doc paths modified by this wave.
