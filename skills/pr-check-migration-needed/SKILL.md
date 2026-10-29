---
name: pr-check-migration-needed
description: >
  Use when reviewing a PR in de-foundations to determine whether the changes
  require a new migration script to be written before shipping. Triggers include:
  "does this PR need a migration?", "check if this needs a migration script",
  "migration check for this PR", "does this change break consumers?".
  The user must provide either (a) a PR number/URL or branch name, or
  (b) paste the Confluence migration guide content / provide local file paths.
  Delegates trigger logic for dft-mfe-generator and dft-web-monorepo-generator
  to the migration-assessment skill; applies references/trigger-rules.md rules
  directly for dft-bff-generator and dft-iac-generator.
model: sonnet
---

# PR Check Migration Needed

## Trigger

Use when reviewing a `de-foundations` PR to determine whether it requires a new
migration script for `dft-mfe-generator`, `dft-web-monorepo-generator`,
`dft-bff-generator`, or `dft-iac-generator` before shipping. The user must supply
either a PR number/URL/branch name, or the Confluence migration guide content (pasted
or as local file paths).

Full per-generator trigger rules are in `references/trigger-rules.md`.

## Generator coverage — quick reference

| Generator | Migration trigger summary |
|-----------|--------------------------|
| `dft-mfe-generator` | Template output changes, dft-rspack-config shape, dft-logger named exports used in templates, dft-logger-interceptors named exports, NX major bump |
| `dft-web-monorepo-generator` | Template output changes, required schema input changes, NX major bump |
| `dft-bff-generator` | Template output changes, dft-logger-middleware named exports, dft-logger Node exports, generated package.json dep range changes, NX major bump |
| `dft-iac-generator` | Public API break in `modules/foundations/` in de-foundations-iac only (required var added/removed/renamed) |

See `references/trigger-rules.md` for the full "migration needed / NOT a trigger" breakdown per generator.

## Steps

1. **Gather inputs.**
   - **The PR diff:**
     ```bash
     # If user gave a branch name:
     git -C ~/projects/de-foundations diff main...<branch-name> \
       -- packages/dft-mfe-generator packages/dft-web-monorepo-generator \
          packages/dft-bff-generator packages/dft-iac-generator

     # If user gave a PR number, fetch via gh:
     gh pr diff <number> --repo sgwshub/de-foundations \
       -- packages/dft-mfe-generator packages/dft-web-monorepo-generator \
          packages/dft-bff-generator packages/dft-iac-generator
     ```
   - **Existing migration docs** (auto-read — no user action needed): read all four —
     `~/projects/de-foundations/packages/dft-mfe-generator/docs/mfe-generator-migration-agent-guide.md`,
     `.../mfe-generator-migration-agent-guide-b.md`,
     `~/projects/de-foundations/packages/dft-web-monorepo-generator/docs/web-monorepo-generator-migration-agent-guide.md`,
     `.../web-monorepo-generator-migration-agent-guide-b.md`. They define the current
     migration contract, file shapes, transformer patterns, and what each generator
     already handles.
   - **Consumer migration guide (user-supplied).** The user must paste the Confluence
     page content directly, or provide local file paths to saved copies. If missing for
     the generator(s) in scope, ask before proceeding:
     > "Please paste the Confluence migration guide content (or provide local file
     > paths) for the generator(s) in scope."

2. **Read `migrations.json` and package versions:**
   ```bash
   cat ~/projects/de-foundations/packages/dft-mfe-generator/migrations.json
   cat ~/projects/de-foundations/packages/dft-web-monorepo-generator/migrations.json
   # Add bff-generator and iac-generator if they exist in the repo
   ```
   Read `package.json` for each package in scope to get the current version (baseline
   `FROM_VERSION` for any new migration).

3. **Determine scope and trigger rules.** Identify which generators are touched by the
   PR diff, then split:
   - `dft-mfe-generator`, `dft-web-monorepo-generator` — trigger assessment is delegated
     to the `migration-assessment` skill in step 4; use `references/trigger-rules.md`
     here only to pre-scope which changes look relevant.
   - `dft-bff-generator`, `dft-iac-generator` — apply `references/trigger-rules.md`'s
     trigger rules directly yourself; `migration-assessment` does not cover these.

   Also apply the **local package dependency rule** (`references/trigger-rules.md`): if
   the PR changes a de-foundations package that is imported directly by generator
   template output files, and the change is not fully backwards-compatible, a migration
   may be needed regardless of which generator package the diff is in.

4. **Invoke the `migration-assessment` skill.** Once triggers are assessed for
   `dft-mfe-generator` and `dft-web-monorepo-generator`, pass:
   - `context_type`: `pr_diff`
   - `changes_description`: the full PR diff text from step 1
   - `package_scope`: infer from which packages have changes

   For `dft-bff-generator` and `dft-iac-generator`, apply `references/trigger-rules.md`'s
   trigger rules directly (`migration-assessment`'s M/W checklists don't cover these yet).

5. **Augment with PR-specific context.** Cross-reference the verdict with
   `migrations.json` from step 2 (confirm `FROM_VERSION` is correct) and the Confluence
   consumer guide from step 1 (confirm manual steps are captured). Amend the brief if the
   Confluence guide documents steps not already captured.

## Network Unavailable

This skill makes an outbound network call: `gh pr diff` (GitHub API — fetches PR diff).

If network connectivity is unavailable when this skill is invoked:
- Do not attempt the `gh pr diff` call
- Log or echo: `[SKIPPED] network unavailable — pr-check-migration-needed skipped`
- Exit 0 in script/automated contexts (do not error — launchd tracks LastExitStatus)
- If running interactively: inform the user the check could not be completed and suggest retrying when connectivity is restored

To verify connectivity before running: use the `network-check` skill.

## Red flags

| Rationalization | What to do instead |
|---|---|
| "The change is internal so no migration." | Check whether internal refactors change generated output — if the generator writes different bytes to consumer files, it needs a migration. See the output-vs-behavior rule in `references/trigger-rules.md`. |
| "It's a minor version bump." | Version number alone doesn't determine migration need. The content change does. |
| "There's already a migration for this." | Confirm by reading `migrations.json` and checking the exact field/file involved. Don't assume coverage. |
| "The Confluence guide says manual." | Manual steps still need to be called out in the brief even if they can't be scripted. |
| "It only changed the generator logic, not a template file." | Check whether the generator logic change causes different bytes in any `src/files/` output. |

## Exit criteria

- [ ] All four generators were checked for whether the PR touches them, not just the
  one the user mentioned.
- [ ] `dft-mfe-generator`/`dft-web-monorepo-generator` verdicts came from invoking
  `migration-assessment`; `dft-bff-generator`/`dft-iac-generator` verdicts came from
  applying `references/trigger-rules.md` directly.
- [ ] A "migration required" verdict is backed by a full migration brief, cross-checked
  against `migrations.json` and the Confluence consumer guide.

## Provenance

Provenance: Hermes skill `learnings/skill-sharing` (corpus-wide porting authorship
attestation: ADR 0010).
Lineage: X-context-docs skills/pr-check-migration-needed@9d7143e (restructured: merged
SKILL.md + SKILL-02.md into one SKILL.md entrypoint + `references/trigger-rules.md`,
per `tools/skill-porting.md` Gate 2's existing multi-file-source rule; pointed the
connectivity-check cross-reference at the `network-check` skill instead of a
work-machine-only absolute script path)
