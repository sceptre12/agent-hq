# Example spec bundle — audit → fix → verify

A small, from-scratch 3-wave bundle proving the `spec_root` format described in
`../spec-format.md`. It is illustrative only — not tied to any real project. It
audits a directory of Markdown docs, fixes what the audit finds, then verifies the
fixes stuck.

Layout used here: **Option B** (`waves/NN-<name>.md`).

| Wave | Goal | Outputs feed |
|---|---|---|
| 1 — audit | Find issues in each doc under `target_dir`. | Wave 2 |
| 2 — fix | Resolve every finding from Wave 1. | Wave 3 |
| 3 — verify | Confirm zero open findings and clean formatting. | (terminal) |

Caller-supplied input for this bundle: `target_dir` — an absolute path to a
directory of Markdown files to audit. Substitute your own `spec_root`-external
input here; wave-execution never assumes what `target_dir` points at.

This bundle also demonstrates two of the optional ADR 0023 gate/schema fields
(`../spec-format.md` § Gate and output-schema fields), each still validating
against preflight rules 1–11:

- **Wave 1's** `work_item` attaches an `output_schema` (graft 4) — its audit
  report must validate as an array of `{file, line, issue}` objects, not just
  free text.
- **Wave 3** declares `gate_type: judge_panel` with `judges: 3` (graft 3) — the
  terminal wave's `exit_criteria` becomes the rubric all 3 judges vote against,
  instead of the default single-agent check Waves 1–2 still use.
