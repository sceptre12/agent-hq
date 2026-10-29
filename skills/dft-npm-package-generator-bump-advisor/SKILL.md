---
name: dft-npm-package-generator-bump-advisor
description: >
  Use when a described change or diff to @sgwshub/dft-npm-package-generator (CLI schema in
  src/generators/create/schema.json, scaffolded output templates in src/scaffold/{node,browser,
  nx-plugin}.ts and src/scaffold/files/**, the generator-version.json stamp/schema, or pinned
  dependency versions like @nx/devkit / @nx/js in emitted output) needs a recommended semver
  bump. Triggers: "what bump is this for dft-npm-package-generator", "does this need a major
  version", "semver this dft-npm-package-generator change", "is this a breaking change for
  dft-npm-package-generator", or reviewing a PR/commit touching
  packages/dft-npm-package-generator before drafting a conventional-commit prefix or tagging a
  release.
---

# dft-npm-package-generator Bump Advisor

## Overview

`@sgwshub/dft-npm-package-generator`'s real public surface is not its npm exports — it's a
**factory**: its `create` generator scaffolds new publishable packages (`browser` | `node` |
`nx-plugin`) into the de-foundations monorepo, and its behavior is observed through the *shape
of what it writes* into every new package, not just its own runtime API. The contract is the
**union of two layers**: (1) the option schema consumers pass to `create`, and (2) the
scaffolded output shape it emits — including the `generator-version.json` provenance stamp and
the pinned dependency versions baked into generated files (e.g. `@nx/devkit`/`@nx/js` in
nx-plugin output). Breaking either layer is major. Generic "SemVer the exports" logic misses
this — the package's own v1.0.0 release removed the entire `make-publishable` generator/executor,
a breaking change invisible if you only look at `src/index.ts`.

This skill applies the package's documented rubric — not generic semver — to a change
description and outputs one of `major` / `minor` / `patch` plus a one-line justification citing
the specific rubric clause.

Source of truth: Confluence page "dft-npm-package-generator Semver" (page ID `2454421505`) and
`~/projects/context-docs/projects/FoundationSemver/decisions/dft-npm-package-generator.md`. If that page
is later revised, re-read it — the table below is a snapshot, not the canonical copy.

## Trigger

- Reviewing a PR/commit/diff touching `packages/dft-npm-package-generator` —
  `src/generators/create/schema.json`, `src/scaffold/{node,browser,nx-plugin}.ts`,
  `src/scaffold/files/**` templates, `schemas/generator-version.schema.json`, or the pinned
  `@nx/devkit`/`@nx/js` versions in `nx-plugin.ts`.
- An author needs a bump recommendation before writing a conventional-commit prefix (`feat:`,
  `fix:`, `feat!:`).
- Feeding a recommendation into the `package-release` skill before tagging — this skill
  complements that flow, it does not replace bump/tag/publish mechanics.

**Not for:** `dft-bff-generator`, `dft-mfe-generator`, or `dft-web-monorepo-generator`
(different packages, different rubrics — see their own bump-advisor skills or the
`migration-assessment` skill). Not for generic semver questions unrelated to this package.

## Input

- `change_description` — a diff or free-text description of the change to
  `dft-npm-package-generator`. That is the only required input.

## The rubric — two-layer contract

**Layer 1 — Option schema** (`src/generators/create/schema.json`): required `name` (regex
`^[a-z0-9][a-z0-9-]*$`) and `packageType` (`browser` | `node` | `nx-plugin`); optional
`capabilities` (`executors` | `generators` | `both`), `executorName`, `generatorName`.

**Layer 2 — Scaffolded output shape**: the generated `package.json` (`exports`, `files`,
`main`/`module`/`types`), `project.json`, tsconfigs/eslint/jest, `src/index.ts` templates; for
`nx-plugin` also `executors.json`/`generators.json` manifests; the `generator-version.json`
provenance stamp (validated by `schemas/generator-version.schema.json`,
`additionalProperties: false`, `generator` pinned to a const string); and pinned dependency
versions baked into emitted output (`@nx/devkit`/`@nx/js` at `20.3.3`, via two separate
constants in `nx-plugin.ts` — `NX_DEVKIT_VERSION` for `@nx/devkit`, `NX_JS_VERSION` for
`@nx/js`).

| Bump | Fires when the change... |
|---|---|
| **MAJOR** (`feat!:` / `fix!:` / `BREAKING CHANGE`) | Removes/renames a schema option, makes an optional option required, or tightens the `name` regex so previously-valid inputs now fail; removes/renames a `packageType`/`capabilities` enum value; breaks emitted output shape — drops/renames a `package.json` key (`exports`, `files`, `main`/`module`/`types`), changes the `generator` const, breaks `generator-version.json`'s own `additionalProperties: false` schema, or restructures the nx-plugin `executors.json`/`generators.json` manifest paths; bumps the pinned `@nx/devkit`/`@nx/js` output version across a major NX line. |
| **MINOR** (`feat:`) | Adds a new optional schema option, a new `packageType`, or a new `capabilities` value; adds new files/keys to a scaffold additively (new template file, new optional `package.json` field, additive prompt); bumps pinned NX versions additively within the same major line. |
| **PATCH** (`fix:`) | Fixes a bug in scaffolding logic that restores intended output (e.g. corrects a malformed template, fixes the name-collision guard, fixes prompt defaults) without changing the documented output contract. |
| **NO BUMP** (`chore:`/`docs:`) | Comment/README/internal-refactor changes with no observable output or option change — no version bump, per this repo's conventional-commits config. |

**Invariant to check regardless of bump — no migration lever exists for this package.** Unlike
`dft-bff-generator` or `dft-mfe-generator`, `dft-npm-package-generator` ships no
`migrations.json` — generator runs are one-shot, and scaffolds are never re-applied. A MAJOR
output-shape change is therefore **never retroactively downgraded to MINOR by a migration**
(there is no migration to check for coverage); it only affects packages `create`d *after* the
new version ships. State this scope explicitly in the justification — it is a framing note about
blast radius, not a reason to lower the bump.

## Steps

1. **Classify what changed.** Identify which surface(s) `change_description` touches:
   - Option schema (`src/generators/create/schema.json`)
   - Scaffolded output shape (`src/scaffold/{node,browser,nx-plugin}.ts`,
     `src/scaffold/files/**`, per-type `package.json`/`project.json` templates,
     `executors.json`/`generators.json` for nx-plugin)
   - Provenance stamp (`generator-version.json` content or
     `schemas/generator-version.schema.json` itself)
   - Pinned dependency versions in emitted output (`@nx/devkit`/`@nx/js` in `nx-plugin.ts`, or
     dependency versions written into generated `package.json`)
   - None of the above (docs, tests, internal refactor with no output/option change)
2. **Apply the rubric table** to the classified surface(s). If multiple surfaces are touched,
   the bump is the highest (most breaking) one that applies.
3. **If the result is MAJOR**, note in the justification that it affects only packages scaffolded
   after this version ships (no `migrations.json` exists to retrofit already-created packages) —
   do not use that scoping to downgrade the bump.
4. **If the change description is too sparse to classify confidently** — e.g. it doesn't say
   whether a new option is optional or required, or whether an NX version bump stays within the
   same major line — do not guess. Output a low-confidence flag naming exactly what's missing,
   plus your best-guess bump, rather than asserting a bump you can't justify from the rubric.

## Output format

```
BUMP: major | minor | patch | none
JUSTIFICATION: <one line citing the rubric clause that drove the recommendation>
SCOPE: future scaffolds only — no migrations.json exists for this package | n/a (no MAJOR)
CONFIDENCE: high | low — <if low, name the missing information>
```


See `references/examples.md` for worked examples and validation against real release history.

## Red flags

| Mistake | Fix |
|---|---|
| Judging the package by `src/index.ts` exports | The real contract is the option schema plus scaffolded output shape (see the two-layer rubric) — exports are nearly irrelevant; the package is a factory, not a library. |
| Assuming a MAJOR output-shape change needs `migrations.json` coverage to ship | This package has **no** migration mechanism at all (see Invariant). Don't wait for a migration that will never exist, and don't downgrade the bump because "no migration is needed" — that reasoning applies to `dft-bff-generator`/`dft-mfe-generator`, not this package. |
| Treating an NX pin bump as always safe | Only additive bumps within the same major line are MINOR; a pin bump across a major NX line is MAJOR (breaks consumer monorepos on the old line). |
| Calling a dependency-pinning PR a version bump for this package | Check whether the change touches this package's *own contract* (schema, scaffold templates, stamp) versus incidental repo-wide tooling changes that happen to touch its `package.json` (see the FOUND-1066 historical example) — the latter is not a bump trigger. |
| Forcing a bump when the description is ambiguous | Output `CONFIDENCE: low` and name the missing fact (e.g. "unclear whether the new option is optional or required") rather than guessing between MINOR and MAJOR. |
| Applying this rubric to `dft-bff-generator`, `dft-mfe-generator`, or `dft-web-monorepo-generator` | Those packages have different rubrics and (for two of them) an actual migration mechanism — see their own bump-advisor skills or `migration-assessment`. |

## Related skills

- `package-release` — the release flow this advisor's recommendation feeds into (bump, tag,
  publish mechanics). This skill only recommends the bump; it does not perform the release.
- `dft-bff-generator-bump-advisor` / `dft-mfe-generator-bump-advisor` — sibling advisors for
  packages that *do* have a migration mechanism, where migration coverage can downgrade an
  otherwise-MAJOR change to MINOR. That downgrade path does not apply here.
- `migration-assessment` — covers `dft-mfe-generator` and `dft-web-monorepo-generator` instead
  of `dft-npm-package-generator`.

## Exit criteria

- [ ] A bump tier (major/minor/patch/none) was produced, or an explicit low-confidence flag
  naming exactly what's missing — never a silent guess.
- [ ] A MAJOR result states the future-scaffolds-only scope note (no `migrations.json` exists
  for this package) without using it to downgrade the bump.
- [ ] No edits were made to `package.json`, `CHANGELOG.md`, or any generator source file.

## Provenance

Provenance: Hermes skill `learnings/skill-sharing` (corpus-wide porting authorship
attestation: ADR 0010).
Lineage: X-context-docs skills/dft-npm-package-generator-bump-advisor@9d7143e
