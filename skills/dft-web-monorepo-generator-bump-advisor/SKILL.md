---
name: dft-web-monorepo-generator-bump-advisor
description: >
  Use when a change to @sgwshub/dft-web-monorepo-generator (a diff, PR
  description, or a summarized change description) needs a version-bump
  recommendation before release. Triggers include "what bump does this need",
  "major or minor for dft-web-monorepo-generator", "classify this
  dft-web-monorepo-generator change", "does this need a migration", or
  preparing a conventional-commit / release for dft-web-monorepo-generator.
  Advisory only — does not modify package.json, migrations.json, or
  CHANGELOG; see package-release for the actual bump/publish flow, and
  migration-assessment for a deeper migration-authoring brief.
model: sonnet
---

# dft-web-monorepo-generator Bump Advisor

Classify a described change to `@sgwshub/dft-web-monorepo-generator` as
**major**, **minor**, or **patch** by applying the package's documented
rubric, and output the specifier plus a one-line justification tied to the
exact rubric criterion matched.

**Advisory only.** This skill never edits `package.json`, `migrations.json`,
or `CHANGELOG.md`, and never sets a conventional-commit type. For the actual
bump/tag/publish mechanics, use the `package-release` skill
(`~/.claude/skills/package-release/SKILL.md`). For authoring the migration
itself once one is known to be required, use `migration-assessment`.

## Trigger

Use when a diff, PR description, or free-text change summary for `@sgwshub/dft-web-monorepo-generator` needs a version-bump recommendation before release.

## Rubric source of truth

`context-docs/projects/FoundationSemver/decisions/dft-web-monorepo-generator.md`
(Outcome section) — mirrored on Confluence as "dft-web-monorepo-generator
Semver" (page ID `2453504002`). If this skill's output ever looks wrong,
re-read that file first; the rubric below is a verbatim transcription of it,
not a paraphrase, and if the two ever disagree the doc wins.

**Fail closed:** if the rubric doc is missing, unreadable, or has changed its
Options/Outcome section since this transcription, do not guess a bump from
first principles. Report:

```
CANNOT CLASSIFY — rubric doc unavailable or changed.
Reason: <missing | unreadable | Outcome section no longer matches this skill's transcription>
Recommend: re-read context-docs/projects/FoundationSemver/decisions/dft-web-monorepo-generator.md
and update this skill before classifying further changes.
```

`@sgwshub/dft-web-monorepo-generator`'s public surface is **the shape of the
scaffolded workspace it emits, not just its trivial TS API**
(`src/index.ts` merely re-exports `presetGenerator`; the schema is minimal —
`{ name }`, required). The emitted shape includes: `package.json` (pinned
`packageManager`, `engines`, `scripts`, commitizen config, curated
`devDependencies`), `nx.json` (`namedInputs.production`, the
`@nx/js/typescript` plugin block, workspace plugins), `tsconfig.base.json`
compiler options, `pnpm-workspace.yaml`, and the tooling/dotfile templates
(`.husky/*`, `.github/*`, `.vscode/*`, `.npmrc`, `.nvmrc`, `.node-version`,
`.pnpm-version`, `.prettierrc`, `generator-version.json`, etc.) under
`src/preset/files/`. Because re-running `preset` on an existing workspace is
not a supported workflow, output changes reach already-generated workspaces
**only** through a migration in `migrations.json` — this is why the rubric
ties bump level directly to migration need.

## Steps

### Step 1 — Read the change

Take whatever the caller supplies: a git diff, a PR description, or a
free-form summary of changed behavior. If it's a raw diff, focus on:
- Any file under `src/preset/files/` (the emitted template tree) or
  `src/preset/helpers/` (`nx-json.helper.ts`, `package-json.helper.ts`,
  `tsconfig.helper.ts`) — these determine what ships into new workspaces
- `migrations.json` and `src/migrations/*` — whether a migration is being
  added/changed alongside the emitted-output change
- The `preset` generator's schema (`schemas/*.json`) — required vs. optional
  properties
- `package.json` `dependencies`/`devDependencies` version changes for
  packages the generator pins into consumer workspaces (e.g.
  `@sgwshub/dft-sonarqube-*`, `dft-deployment-check`, `dft-target-cleaner`)
- Whether the change is confined to docs, tests, or internal refactors with
  no diff to anything the generator actually emits

### Step 2 — Apply the rubric

Check criteria in this order — **MAJOR first**, then MINOR, then PATCH — and
stop at the first match. A change can satisfy multiple criteria; always
report the highest bump among all matches (see Step 3 for mixed changes
instead of silently picking the lower one).

### MAJOR — emitted shape breaks, or the generator's required surface breaks
- Any change to emitted `nx.json` / `package.json` / `tsconfig.base.json` /
  `pnpm-workspace.yaml` / tooling-template structure that an existing
  generated workspace could not adopt without manual intervention
- Removal or rename of the `preset` generator itself
- Removal or rename of a **required** schema property (currently: `name`)
- Every MAJOR (and any MINOR whose additive change needs to reach
  already-generated workspaces — see below) **must ship a paired migration in
  `migrations.json`** — flag this explicitly in the output even if the input
  didn't mention one

### MINOR — additive emitted config, or a dep minor bump
- A new plugin added to the emitted `nx.json`
- A new optional dotfile or tooling template added to the emitted output
- A new optional schema property on the `preset` generator
- A dependency **minor** version bump pinned into the generated
  `package.json` (e.g. bumping `@sgwshub/dft-sonarqube-plugin` to a new
  `^x.y.0`)
- Migration is **optional** for MINOR — required only if the additive change
  needs to reach already-generated workspaces (i.e. it "touches existing
  repos"); otherwise a MINOR can ship without one

### PATCH — no shape change
- Fixes to generated content that don't change shape (typos, formatting,
  dependency **patch** bumps)
- Internal refactors with no diff to what the generator emits
- Doc-only changes
- Fixes to logic that doesn't touch emitted output (e.g. a bug in an
  existing migration's own internal bookkeeping, or a non-emitting helper)

### Step 3 — Handle ambiguous or mixed changes

Per the ticket's stated risk posture: **false negatives (recommending a
lower bump than warranted) carry more risk than false positives** given this
package's blast radius — it defines the foundational structure of every new
web monorepo. If a described change is genuinely mixed, or you cannot tell
from the input whether emitted shape is affected, do not silently pick the
lower bump. Bias ambiguous shape changes toward MAJOR for human review, and
report:

```
AMBIGUOUS — cannot classify with confidence.
Reason: <what's mixed or missing>
Highest-bump interpretation: <major|minor|patch>, because <criterion>
Lowest-bump interpretation: <major|minor|patch>, because <criterion>
Recommend: request the emitted-file diff (specifically: what changes in
src/preset/files/ or the helper mutators' output) before finalizing the
release bump. Default to the highest-bump interpretation until confirmed.
```

### Step 4 — Output format

For unambiguous classifications, output exactly:

```
Recommended bump: <major|minor|patch>
Justification: <one line, name the specific emitted file/behavior changed
and quote or closely paraphrase the matched rubric criterion>
Migration required: <yes | optional | no>
Rubric source: context-docs/projects/FoundationSemver/decisions/dft-web-monorepo-generator.md
```

`Migration required` follows directly from Step 2: `yes` for any MAJOR or for
a MINOR whose additive change needs to reach already-generated workspaces;
`optional` for other MINORs; `no` for PATCH.

See `references/examples.md` for worked examples and validation against real history.

## Red flags

| Mistake | Fix |
|---|---|
| Classifying by the *size* of the diff rather than whether emitted shape changed | A one-line change to `nx-json.helper.ts` that alters emitted `nx.json` structure is still MAJOR; a 500-line internal refactor with no emitted-output diff is still PATCH |
| Treating a dependency bump's own semver as the package's bump | Only a non-breaking dep **patch** bump is PATCH and a dep **minor** bump is MINOR; if the dep bump itself changes what a generated workspace needs to adopt (e.g. a new required peer), treat it as the shape-change criterion it actually triggers, not the dep's own semver |
| Assuming a MINOR never needs a migration | A MINOR (new plugin, new optional file) still requires a migration if the additive change needs to reach already-generated workspaces — only skip it when the addition is genuinely optional for existing repos |
| Picking the lower bump when a change is genuinely mixed | Use Step 3 — report AMBIGUOUS and bias toward the highest-bump interpretation, per this package's stated false-negative risk |
| Assuming this skill also authors the migration or performs the release | It does not — it is advisory only; hand the recommended specifier and migration flag to `package-release` for publish, and to `migration-assessment` for the migration brief |

## Related skills

- `package-release` — this skill's recommended bump feeds its
  `--specifier=<patch|minor|major>` step; it does not replace that flow.
- `migration-assessment` — a related but distinct judgment: whether a change
  needs a **new migration script at all**, across `dft-web-monorepo-generator`
  and `dft-mfe-generator` (its currently-supported scope). This skill assumes
  that judgment is already made (or makes its own call in Step 2) and asks
  the different question of which semver tier the change — migration-covered
  or not — belongs to, specifically for `dft-web-monorepo-generator`.

## Scope

Scoped to `@sgwshub/dft-web-monorepo-generator` only, per FOUND-1830.
Generalizing to read any package's decision doc under
`projects/FoundationSemver/decisions/` is a candidate follow-up, not covered
here (see the sibling `dft-api-client-bump-advisor`, `dft-iac-generator-bump-advisor`,
etc. for the same per-package pattern applied elsewhere).

## Exit criteria

- [ ] A bump tier was produced, or an explicit AMBIGUOUS report with both interpretations —
  never a silent guess.
- [ ] The justification names the specific changed surface and quotes or closely
  paraphrases the matched rubric criterion.
- [ ] No edits were made to `package.json`, `CHANGELOG.md`, or `nx.json`.

## Provenance

Provenance: Hermes skill `learnings/skill-sharing` (corpus-wide porting authorship
attestation: ADR 0010).
Lineage: X-context-docs skills/dft-web-monorepo-generator-bump-advisor@9d7143e
