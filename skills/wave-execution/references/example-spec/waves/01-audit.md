# Wave 1 — audit

- **goal:** Identify issues (broken links, stale claims, formatting errors) in
  every Markdown file under `target_dir`.
- **inputs:** `target_dir` (caller-supplied, absolute path to a directory of
  `.md` files).
- **work_items:** one per `.md` file found under `target_dir`.
- **agents:** one per work_item, model: sonnet.
- **exit_criteria:**
  - Every work_item's agent posted an audit report (a findings list, possibly
    empty) — no agent errored or failed to post.
  - Each audit report is well-formed: a list of `{file, line, issue}` entries
    (an empty list is a valid pass, not a missing report).
- **output_schema** (per `work_item`, ADR 0023 graft 4 — demonstrates
  `references/spec-format.md` § Gate and output-schema fields):
  ```json
  {
    "type": "array",
    "items": {
      "type": "object",
      "properties": {
        "file": { "type": "string" },
        "line": { "type": "integer", "minimum": 1 },
        "issue": { "type": "string" }
      },
      "required": ["file", "line", "issue"],
      "additionalProperties": false
    }
  }
  ```
- **outputs:** `audit_reports` — the list of audit-report paths, one per input
  file, keyed by the file it covers.
