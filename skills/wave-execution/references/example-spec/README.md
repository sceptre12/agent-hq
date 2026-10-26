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
| 2 — fix | Resolve every finding from Wave 1. | Waves 3 and 4 (`fixed_docs`) |
| 3 — verify | Confirm zero open findings and clean formatting. | none |
| 4 — build | DAG-frontier wave: build a small docs site; `index`, `toc`, `site`, `release-note` released by `depends_on` edges, serialized by `lane`, each gated by `step_complete`. | none (`docs_site` is the last wave's output) |

Caller-supplied input for this bundle: `target_dir` — an absolute path to a
directory of Markdown files to audit. Substitute your own `spec_root`-external
input here; wave-execution never assumes what `target_dir` points at.

This bundle also demonstrates two of the optional ADR 0023 gate/schema fields
(`../spec-format.md` § Gate and output-schema fields), each still validating
against every preflight rule (1-11, 13-15):

- **Wave 1's** `work_item` attaches an `output_schema` (graft 4) — its audit
  report must validate as an array of `{file, line, issue}` objects, not just
  free text.
- **Wave 3** declares `gate_type: judge_panel` with `judges: 3` (graft 3) — the
  wave's `exit_criteria` becomes the rubric all 3 judges vote against,
  instead of the default single-agent check Waves 1–2 still use.

## ADR 0054 additions

Wave 4 and `bundle.md` demonstrate the ADR 0054 fields. Waves 1-3 declare none of
them, so the legacy form (waves 1-3, no new fields) still validates and runs as before.

- **`bundle.md`** carries the bundle-level fields `session_id`, `output_topic`,
  `bus_endpoint` and `gates_command` (and `dispatch_budget` when used). Each wave 4 gate agent
  runs `gates_command` on its work_item's posted head under a lane lease and alone writes that
  head's `gate-runs/<head>.md` (INTERFACES 1.8.0 AM-8 V14). Option B has no other bundle-level
  home, so this file is the bundle header; `max_concurrent`, `invocation` and
  `tier_override` are invocation arguments and never appear in it.
- **Wave 4** is a frontier wave: it enumerates its work_items, each with `persona`, `lane`,
  `depends_on` and a `done_condition` (`{"token", "command"}`), uses `gate_type:
  step_complete` and one `fix_loop_cap` declared for the wave and counted per work_item. `index` and `toc` share a lane, so
  they run one after the other; `site` waits for both; `release-note` waits for `site`.
- **Integrator items (note):** this example has none. In a delivery run each blocker's Integrator
  item is an ordinary work_item of its dependents' wave and each dependent `depends_on` it; a
  dependency across waves is wave order, never an edge, so rule 15 is unchanged (INTERFACES 1.8.0
  AM-8 V13).
- **Runtime rules the example relies on** (`../../SKILL.md`, `../frontier-mode.md`): an
  `example-run/build/bus.endpoint` whose `session_id=` or `topic=` differs from `bundle.md`
  (or lacks a key) halts the run before any dispatch, and an invocation without the
  `invocation` argument halts with `BUNDLE-ERROR invocation` (INTERFACES 1.5.0 C1.1); in the
  dispatch record a wave 1-3 worker carries `persona` `none` and a wave-level gate agent
  `unit` `wave-<N>`; lane `writer-a` stays busy from
  `index`'s dispatch until its per-item gate passes or it escalates (a frontier wave; in a barrier
  wave a lane is released at the holder's completion post, `UNIT-VERDICT`, INTERFACES 1.6.0 AM-6 C-4;
  lane release is a runtime rule, so `tests/run.sh`, a static bundle checker, does not test it); a `tier_override` such as
  `site=opus` is recorded as `tier` in that worker's dispatch record line; gate agents get
  ids like `site-gate1-<nonce>` (workers `site-<nonce>`, fixers `site-fix1-<nonce>`), each id
  distinct per agent.
- **Enumeration (test notation):** a wave enumerates its work_items when its `work_items`
  value is empty or starts with `enumerated below` and every work_item is listed as a
  `  - **<id>**` entry; any other value is a runtime rule (e.g. waves 1-3).
- **Tests:** `bash tests/run.sh` checks rules 4, 5, 9, 11, 13, 14 and 15 over this bundle,
  the legacy form (waves 1-3, no new fields), `tests/fixtures/valid/` and one `tests/fixtures/invalid-<rule>-<case>/`
  per negative case, plus that `bundle.md` declares `gates_command` as one non-empty line. Last line:
  `WAVE-EXEC-TESTS: PASS <n>/<n>`.
