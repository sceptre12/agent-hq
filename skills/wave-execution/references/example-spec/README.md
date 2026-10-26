# Example spec bundle — audit → fix → verify → build

A small, from-scratch 4-wave bundle (three barrier waves, one frontier wave)
proving the `spec_root` format described in `../spec-format.md`. It is
illustrative only — not tied to any real project. It audits a directory of
Markdown docs, fixes what the audit finds, verifies the fixes stuck, then builds
a small docs site from them.

Layout used here: **Option B** (`waves/NN-<name>.md`).

| Wave | Goal | Outputs feed |
|---|---|---|
| 1 — audit | Find issues in each doc under `target_dir`. | Wave 2 |
| 2 — fix | Resolve every finding from Wave 1. | Wave 3 |
| 3 — verify | Confirm zero open findings and clean formatting. | (barrier; Wave 4 reads Wave 2's `fixed_docs`) |
| 4 — build | DAG-frontier wave: build a small docs site; `index`, `toc`, `site`, `release-note` released by `depends_on` edges, serialized by `lane`, each gated by `step_complete`. | (terminal) |

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
  wave's `exit_criteria` becomes the rubric all 3 judges vote against,
  instead of the default single-agent check Waves 1–2 still use.

## ADR 0054 additions

Wave 4 and `bundle.md` demonstrate the ADR 0054 fields. Waves 1-3 declare none of
them, so the legacy 3-wave bundle (waves 1-3 alone) still validates and runs as before.

- **`bundle.md`** carries the bundle-level fields `session_id`, `output_topic` and
  `bus_endpoint` (and `dispatch_budget` when used). Option B has no other bundle-level
  home, so this file is the bundle header; `max_concurrent`, `invocation` and
  `tier_override` are invocation arguments and never appear in it.
- **Wave 4** is a frontier wave: it enumerates its work_items, each with `persona`, `lane`,
  `depends_on` and a `done_condition` (`{"token", "command"}`), uses `gate_type:
  step_complete` and a per-work_item `fix_loop_cap`. `index` and `toc` share a lane, so
  they run one after the other; `site` waits for both; `release-note` waits for `site`.
- **Runtime rules the example relies on** (`../SKILL.md`, `../frontier-mode.md`): an
  `example-run/build/bus.endpoint` whose `session_id=` or `topic=` differs from `bundle.md`
  (or lacks a key) halts the run before any dispatch; lane `writer-a` stays busy from
  `index`'s dispatch until its gate passes or it escalates; a `tier_override` such as
  `site=opus` is recorded as `tier` in that worker's dispatch record line; gate agents get
  ids like `site-gate-<nonce>` (workers `site-<nonce>`, fixers `site-fix1-<nonce>`).
- **Tests:** `bash tests/run.sh` checks rules 4, 5, 9, 11, 13, 14 and 15 over this bundle,
  the legacy 3-wave form, `tests/fixtures/valid/` and one `tests/fixtures/invalid-<rule>-<case>/`
  per negative case. Last line: `WAVE-EXEC-TESTS: PASS <n>/<n>`.
