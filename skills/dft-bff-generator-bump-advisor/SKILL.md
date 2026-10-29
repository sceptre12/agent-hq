---
name: dft-bff-generator-bump-advisor
description: >
  Use when a described change or diff to @sgwshub/dft-bff-generator (CLI schema in
  src/bff/schema.json, scaffolded output in src/bff/files/**, injected dependency ranges in
  helpers/constants.ts, generator-version.json stamp, or migrations.json) needs a
  recommended semver bump. Triggers: "what bump is this for dft-bff-generator", "does this
  need a major version", "semver this dft-bff-generator change", "is this a breaking change
  for dft-bff-generator", or reviewing a PR/commit touching packages/dft-bff-generator
  before drafting a conventional-commit prefix or tagging a release.
model: sonnet
---

# dft-bff-generator Bump Advisor

## Overview

`@sgwshub/dft-bff-generator`'s real public surface is not its npm exports — `dist/index.js`
exports almost nothing consumers import at runtime. The public contract is what the
generator *does to a consumer workspace*: the CLI schema, the scaffolded output shape, the
injected dependency ranges, and the migration surface. Generic "SemVer the exports" logic
gets this package wrong (it would have called the FOUND-1112 dependency-range fix and the
2.0.9 stamp fix invisible patches — they weren't invisible, they broke/repaired generated
projects).

This skill applies the package's documented rubric — not generic semver — to a change
description and outputs one of `major` / `minor` / `patch` plus a one-line justification
citing the specific rubric clause. Advisory only — it does not gate, tag, or publish a
release; it only recommends the bump.

Source of truth: Confluence page "dft-bff-generator Semver" (page ID `2454061059`,
re-scrapeable via `query-confluence` if stale) and
`~/projects/context-docs/projects/FoundationSemver/decisions/dft-bff-generator.md`.
If either source is later revised, re-read it — the table below is a snapshot, not the
canonical copy.

## Trigger

Use when reviewing a PR/commit/diff touching `packages/dft-bff-generator` —
`src/bff/files/**`, `helpers/constants.ts` dependency ranges, `src/bff/schema.json`,
`updateProjectConfiguration.ts` targets, or `migrations.json` — or before writing a
conventional-commit prefix (`feat:`, `fix:`, `feat!:`), or before feeding a recommendation
into the `package-release` skill (this skill recommends the bump; it does not tag/publish).

**Not for:** `dft-mfe-generator` or `dft-web-monorepo-generator` (different packages,
different rubrics — see the `dft-mfe-generator-bump-advisor` and
`dft-web-monorepo-generator-bump-advisor` skills). Not for generic semver questions unrelated
to this package.

## Input

- `change_description` — a diff or free-text description of the change to
  `dft-bff-generator`. That is the only required input.

## The rubric

| Bump | Fires when the change... | Migration required? |
|---|---|---|
| **MAJOR** (`feat!:` / `fix!:` / `BREAKING CHANGE`) | Removes/renames a schema option, or makes an optional one required; renames/removes a generated file or NX target (`build`, `package`); changes the `package` target's output artifact (e.g. drops `deployment.zip` or changes its path); changes `generator-version.json` schema non-additively; tightens an injected dependency to an incompatible major (e.g. `express ^5 → ^6`); changes the Lambda bundle contract (`build-lambda.js` output name/path/target runtime) in a way that breaks existing deploy pipelines. | **Yes** — every MAJOR that affects already-scaffolded repos MUST ship a `migrations.json` entry. |
| **MINOR** (`feat:`) | Adds a new optional schema flag; adds a new generated file/route/target that leaves existing projects valid; widens an injected dependency range compatibly; adds a new opt-in migration. | No — existing scaffolded projects remain valid without migration. |
| **PATCH** (`fix:`) | Bug fixes with no change to generated shape or accepted flags; compatible dependency-range corrections (the FOUND-1112-style fix); docs/internal refactors; stamp-alignment fixes (e.g. correcting `generator-version.json`'s stamp to match the published version, as in 2.0.9). | N/A — no change to generated output shape or CLI schema. |

**Invariant to check regardless of bump:** the `generator-version.json` stamp emitted by
templates must equal the published package version. A change that breaks this invariant is
itself a MAJOR-class bug (see 2.0.9's fix, which was a *correction* toward the invariant and
is PATCH — see Red flags below for why direction matters).

## Steps

1. **Classify what changed.** Identify which surface(s) `change_description` touches: CLI
   schema (`src/bff/schema.json`); scaffolded output shape (`src/bff/files/**`, NX targets in
   `updateProjectConfiguration.ts`, `build-lambda.js` contract); injected dependency ranges
   (`helpers/constants.ts` — `BFF_DEPENDENCIES` / `BFF_DEV_DEPENDENCIES`); migration surface
   (`migrations.json`, `generator-version.json` stamp); or none of the above (docs, tests,
   internal refactor with no output-shape change).
2. **Apply the rubric table** to the classified surface(s). If multiple surfaces are
   touched, the bump is the highest (most breaking) one that applies.
3. **If the result is MAJOR**, determine whether it affects already-scaffolded repos (nearly
   always yes for output/schema/dependency-major changes). If so, the output MUST note that a
   `migrations.json` entry is required.
4. **If the change description is too sparse to classify confidently** — e.g. it doesn't say
   whether a dependency bump is compatible or incompatible, or whether a new flag is
   optional or required — do not assert a single bump you can't justify from the rubric.
   Instead output both the highest-bump and lowest-bump interpretation consistent with the
   description, each labeled `AMBIGUOUS`, plus a low-confidence flag naming exactly what
   fact is missing to resolve between them.
5. **Output format.** For unambiguous classifications:

   ```
   BUMP: major | minor | patch
   JUSTIFICATION: <one line citing the rubric clause that drove the recommendation>
   MIGRATION REQUIRED: yes | no | n/a
   CONFIDENCE: high | low — <if low, name the missing information>
   ```

   For the ambiguous case (step 4):

   ```
   AMBIGUOUS — cannot classify with confidence.
   Reason: <what's mixed or missing>
   Highest-bump interpretation: <major|minor|patch>, because <rubric clause>
   Lowest-bump interpretation: <major|minor|patch>, because <rubric clause>
   Recommend: request the specific diff/fact needed to resolve between them.
   ```

See `references/examples.md` for worked examples and validation against the package's real
release history (2.0.7/2.0.8/2.0.9).

## Red flags

| Rationalization | What to do instead |
|---|---|
| "A dependency-range change is always PATCH — deps aren't the CLI schema." | Check direction and compatibility: compatible widening/correction is PATCH or MINOR; tightening to an incompatible major (e.g. `^5 → ^6`) is MAJOR. |
| "It's just an internal refactor, so it's PATCH." | If the generator writes different bytes into `src/bff/files/**` output, it's a shape change — classify by what changed, not by "it's just a refactor." |
| "A stamp-alignment fix is always PATCH." | Only a *correction toward* the invariant (stamp matches published version) is PATCH, as in 2.0.9. A change that breaks the invariant is a bug, not a safe patch — flag it. |
| "I'll skip the migration flag on MAJOR since it's implied." | Every MAJOR that affects already-scaffolded repos MUST note `MIGRATION REQUIRED: yes` — this is a rubric invariant, not optional context. |
| "The description is ambiguous, I'll just pick one." | Report `AMBIGUOUS` with both a highest- and lowest-bump interpretation and name the missing fact. |
| "I'll apply this rubric to dft-mfe-generator too, they're similar." | Those packages have their own rubrics and their own skills — use `dft-mfe-generator-bump-advisor` / `dft-web-monorepo-generator-bump-advisor` instead. |

## Exit criteria

- [ ] A bump tier was produced, or an explicit AMBIGUOUS report with both interpretations.
- [ ] A MAJOR result states whether `MIGRATION REQUIRED` and names the rubric clause matched.
- [ ] No edits were made to `package.json`, `CHANGELOG.md`, `migrations.json`, or `nx.json`.

## Related skills

- `package-release` — the release flow this advisor's recommendation feeds into (bump, tag,
  publish mechanics). This skill only recommends the bump; it does not perform the release.
- `pr-check-migration-needed` — determines whether a PR needs a migration script at all
  (applies SKILL-02.md rules directly for `dft-bff-generator`); this skill's `MIGRATION
  REQUIRED` flag is a lighter-weight signal pointing at the same concern, not a replacement
  for that skill's full assessment.
- `dft-mfe-generator-bump-advisor` / `dft-web-monorepo-generator-bump-advisor` — the
  equivalent semver-bump rubric skills for those two packages.
- `migration-assessment` — answers a different question (whether a change needs a *new
  migration script at all*) for `dft-mfe-generator` and `dft-web-monorepo-generator`; it does
  not provide a semver rubric for any package, including `dft-bff-generator`.

## Scope

Scoped to `@sgwshub/dft-bff-generator` only. For other packages' semver-bump rubrics, use
the sibling `*-bump-advisor` skill for that package.

## Provenance

Provenance: Hermes skill `learnings/skill-sharing` (corpus-wide porting authorship
attestation: ADR 0010).
Lineage: X-context-docs skills/dft-bff-generator-bump-advisor@9d7143e (trimmed: genericized
a leaked work-machine absolute path — `/Users/Xavier.Thomas/projects/context-docs-worktrees/
foundation-semver/...`, a stale worktree — to the real `~/projects/context-docs/...` path)
