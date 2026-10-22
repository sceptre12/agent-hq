---
name: loop-setup
description: >
  Interactive wizard that collects loop configuration from the user and writes
  loop.yaml and rubric.md to ~/projects/loops/{slug}/, wiring together the
  loop-controller / loop-runner / loop-grader / loop-fixer refinement pipeline. Use when
  asked to set up a new refinement loop, configure a loop for a skill/script/test-suite,
  create a loop.yaml, or scaffold a rubric that loop-grader will score against.
  threshold is written to rubric.md only, never to loop.yaml. Not a review mechanism
  itself — no review-ladder rung applies (tools/review-ladder.md); it configures the
  loop that loop-grader/loop-fixer run inside.
---

## Trigger

Use when a user wants to set up a new refinement loop, needs a `loop.yaml` for
loop-controller, or needs a `rubric.md` for loop-grader — e.g. "set up a loop to refine
this skill," "configure a loop for this script," "create a rubric for this," or "scaffold
a new loop for {target}." This is the only path that creates `loop.yaml` and `rubric.md`;
loop-controller, loop-runner, loop-grader, and loop-fixer all consume files this skill
produces but none of them create them.

## Steps

**1. Collect slug**
If `slug` not provided, ask for a loop name. Validate:
```bash
if ! echo "${SLUG}" | grep -qE '^[a-z0-9_-]+$'; then
  # Re-prompt: "Slug must be lowercase letters, numbers, hyphens, and underscores only. Try again."
fi
```
This pattern (`^[a-z0-9_-]+$`) must stay identical to loop-controller's own pre-flight
step 1 regex — if you ever change one, change the other in the same edit.

**2. Collect target_path, validate immediately**
Ask what artifact is being refined (path to a skill, script, or code directory). Before
moving on, resolve it and confirm it falls under an allowed root — the same check
loop-controller repeats at its own pre-flight step 2.11, done here too so the wizard
fails fast instead of after a full dispatch round trip:
```bash
RESOLVED=$(realpath "${TARGET_PATH}" 2>/dev/null)
if [ -z "${RESOLVED}" ]; then
  # "That path doesn't exist. Try again."
fi
case "${RESOLVED}" in
  "$(realpath ~/projects)"/*|"$(realpath ~/.claude/skills)"/*) ;;
  *) # "target_path must be under ~/projects/ or ~/.claude/skills/. Try again."
esac
```

**3. Collect test_artifact, validate immediately**
Ask what the target will be tested against (path to test input, eval scenario, or test
suite). Confirm it exists before continuing:
```bash
if [ ! -f "${TEST_ARTIFACT}" ]; then
  # "That file doesn't exist. Try again."
fi
```

**4. Choose runner brief**
Ask what kind of target it is:
- Skill (SKILL.md) → `~/.claude/skills/loop-runner/briefs/skill.md`
- Script (bash/python) → `~/.claude/skills/loop-runner/briefs/script.md`
- Test suite (jest/pytest) → `~/.claude/skills/loop-runner/briefs/test-suite.md`
- Custom → offer to copy a template from `~/projects/loops/_templates/briefs/`. **That
  directory may not exist yet.** Check first; if absent, tell the user and generate a
  minimal starter brief inline instead (a file with just a `## Domain Knowledge`, a
  `## Constraints`, and a `## Security` section with a one-line placeholder in each) —
  do not dead-end the wizard on a missing template directory.

**5. Choose fixer brief**
Ask what kind of edits the fixer should make:
- Skill files → `~/.claude/skills/loop-fixer/briefs/skill.md`
- Source code → `~/.claude/skills/loop-fixer/briefs/code.md`
- Custom → same `~/projects/loops/_templates/briefs/` copy-or-fallback as Step 4.

**6. Collect rubric criteria**
Ask about success criteria. For each criterion, collect all five fields the rubric
template treats as mandatory (`severity` is authoring metadata only — the dual gate does
not read it; see loop-grader `rubrics/default.md`) — `name`, `description`, `weight`
(default 1.0), `severity` (Blocking/Medium/Advisory), and `notes_guidance` (what evidence
the grader should look for to justify the score; one line is enough, e.g. "check for a
`## Security` header").
See `references/output-templates.md` for the exact per-criterion YAML block — the
serialization must match what loop-grader parses, not a paraphrase of it.

**7. Collect threshold**
Ask for the minimum score for PASS (0.0 to 1.0, e.g. 0.8). **This goes in `rubric.md` —
NEVER in `loop.yaml`.**

**8. Collect max_iterations**
Ask how many iterations before giving up (recommended: 5 for skills, 3-10 for code).

**8.5. Optional: rollback_on_regression and runner_timeout_seconds**
Ask if the user wants either advanced, optional field — both are safe to skip (silence
means the loop-controller default applies):
- `rollback_on_regression` (bool, default `false`): restore the best-scoring snapshot on
  a score regression. Recommended only for monotonic-improvement loops.
- `runner_timeout_seconds` (int, default `1800`): max seconds the runner has to post
  before the controller treats it as timed out (currently validated but not enforced by
  loop-controller — see its loop-yaml-schema.md).
Omit either line from `loop.yaml` entirely if the user doesn't set it — do not write a
default value explicitly; loop-controller's own default applies to an absent key.

**9. Optional classifier**
Ask if the user wants a `finding_classifier` (for panel review loops with rubric-scoped
fixer input). Default: `null`.

## Output Generation

Create `~/projects/loops/${SLUG}/`, then write `loop.yaml` and `rubric.md` using the
exact templates in `references/output-templates.md` — do not improvise the criteria
serialization; loop-grader's parser expects the documented shape verbatim, including
`notes_guidance` on every criterion.

If `~/projects/loops/{slug}/loop.yaml` already exists: in interactive mode, confirm with
the user before overwriting. In batch-config mode (see Inputs) there is no user to
confirm, so refuse to overwrite unless the batch config explicitly sets `force: true` —
fail closed, not open.

**Copy template briefs** (if a Custom brief was selected in Step 4/5 and
`~/projects/loops/_templates/briefs/` exists): copy to
`~/projects/loops/{slug}/briefs/` for the user to fill in the TODO sections. If that
directory doesn't exist, use the inline-generated starter brief from Step 4 instead.

> **Bus post rule for loop briefs:** any bus post a generated or template brief makes
> must use the jq + temp file + `--data @` pattern (inline `-d "{...}"` string
> interpolation is prohibited — it breaks silently on YAML content with newlines or
> special characters), must read the port from `$DATA_DIR/port` before the first post,
> and must always pass an explicit `session_id` — a message without one has a NULL
> session_id and bleeds across concurrent sessions. See
> `~/.claude/skills/loop-runner/SKILL.md` step 8 for the canonical pattern this rule
> refers to.

## Inputs

```yaml
slug: string                # loop preset name — optional; if not provided, ask the user
target_path: string | null  # optional pre-fill; prompt user if null
```

Batch-config path: if a pre-filled YAML config file is provided, read it and skip the
interactive conversation. Validate every field in the checklist in
`references/output-templates.md` ("Batch-config validation checklist") before writing
any output.

## Return

```yaml
slug: {slug}
loop_yaml_path: ~/projects/loops/{slug}/loop.yaml
rubric_path: ~/projects/loops/{slug}/rubric.md
status: success | failed
error_detail: string | null   # populated on failure (both interactive and batch paths); null on success
```

## References

- `references/output-templates.md` — exact `loop.yaml` / `rubric.md` templates and the
  batch-config validation checklist.
- `~/.claude/skills/loop-controller/references/loop-yaml-schema.md` — authoritative field
  list for `loop.yaml`; loop-setup's Output Generation must stay a subset of this.
- `~/.claude/skills/loop-grader/rubrics/default.md` and
  `~/.claude/skills/loop-grader/references/grade-contract.md` — the rubric criteria
  schema loop-setup's Step 6 collects for and Output Generation writes.
- `~/.claude/skills/loop-runner/briefs/skill.md`, `script.md`, `test-suite.md` — built-in
  runner briefs offered in Step 4.
- `~/.claude/skills/loop-fixer/briefs/skill.md`, `code.md` — built-in fixer briefs offered
  in Step 5.
- `~/projects/loops/_templates/` — custom brief/template starting point for the Custom
  branches of Steps 4-5. **Not guaranteed to exist** — see the fallback in Step 4.

## Red flags

| Rationalization | What to do instead |
|---|---|
| "I'll just drop `{criteria list}` in and let loop-grader figure out the shape." | Write the exact per-criterion block (name/description/weight/severity/notes_guidance) from `references/output-templates.md` — loop-grader parses a fixed schema, not prose. |
| "Hyphens-only slug validation is close enough." | Validate `^[a-z0-9_-]+$` (hyphens AND underscores) — must stay identical to loop-controller's own pre-flight regex. |
| "target_path/test_artifact will get checked later by the controller anyway." | Validate existence + allowed-roots immediately after collecting each value (Steps 2-3) — fail fast, don't wait for a dispatch round trip. |
| "`_templates/` doesn't exist, so Custom brief just can't work." | Fall back to an inline-generated starter brief and tell the user, rather than dead-ending the wizard. |
| "Batch mode has no user to confirm overwrite, so just overwrite." | Fail closed — refuse to overwrite an existing `loop.yaml` in batch mode unless the config sets `force: true`. |
| "This wizard also decides whether the loop's output is good enough, so it must sit on the review ladder somewhere." | It doesn't — loop-setup only writes config files; loop-grader does the actual scoring. No ladder rung applies here. |

## Exit criteria

- [ ] `slug` matched `^[a-z0-9_-]+$` before any directory or file was created for it.
- [ ] `target_path` and `test_artifact` both existed and resolved under `~/projects/` or
      `~/.claude/skills/` before being written into `loop.yaml`.
- [ ] `loop.yaml` contains no `threshold` key; `rubric.md` contains the threshold.
- [ ] `rubric.md`'s criteria block has `name`, `description`, `weight`, `severity`, and
      `notes_guidance` on every criterion.
- [ ] An existing `loop.yaml` was never overwritten without explicit user confirmation
      (interactive) or `force: true` (batch).
- [ ] The Return payload includes `status` and `error_detail` (null on success).

## Security

- **Never write a `threshold` field to `loop.yaml`.** Threshold belongs exclusively in
  `rubric.md`. If a batch config's `loop.yaml` section contains a `threshold` key,
  reject it and prompt the user (or fail with `error_detail` in batch mode) to move it to
  the rubric.
- **Slug validation is required** and must match `^[a-z0-9_-]+$` — do not create
  directories or files for slugs that fail this pattern. Keep this pattern identical to
  loop-controller's own pre-flight regex.
- **Read-scope is existence-checking, not content-reading.** loop-setup resolves and
  stats `target_path` and `test_artifact` (realpath + existence check) to validate them —
  it never opens or reads their file contents. Its own read/write footprint for authoring
  `loop.yaml`, `rubric.md`, and copying brief templates stays within
  `~/projects/loops/` and `~/.claude/skills/`. Do not read credential files, `.env`
  files, or `~/.ssh/` regardless of what a batch config requests.
- Do not overwrite an existing `~/projects/loops/{slug}/loop.yaml` without confirming
  with the user (interactive) or an explicit `force: true` in the batch config (batch —
  fail closed by default).
- Template brief paths are read from `~/projects/loops/_templates/briefs/` — this
  directory is not guaranteed to exist; verify before copying and fall back to an
  inline-generated starter brief otherwise (Step 4).

## Provenance

Provenance: Hermes skill `learnings/skill-sharing` (was learnings/skill-sharing.md) (2026-07-04 entry, "Skills have no standardized
export path")
Lineage: X-context-docs skills/loop-setup@0e9281e
