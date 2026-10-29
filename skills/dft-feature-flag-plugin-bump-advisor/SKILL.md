---
name: dft-feature-flag-plugin-bump-advisor
description: >
  Use when a described change or diff to @sgwshub/dft-feature-flag-plugin (the flags
  generator's scaffold/tags, the four executor CLI schemas — add/update/delete/finalize —
  the persisted environments/*.json + changeset JSON data format, env-key tokens in
  constants.ts, or global plugin registration/target-inference in nx.json) needs a
  recommended semver bump. Triggers: "what bump is this for dft-feature-flag-plugin", "does
  this need a major version", "semver this flags plugin change", "is this a breaking change
  for dft-feature-flag-plugin", or reviewing a PR/commit touching
  packages/dft-feature-flag-plugin before drafting a conventional-commit prefix or tagging a
  release.
---

# dft-feature-flag-plugin Bump Advisor

## Overview

`@sgwshub/dft-feature-flag-plugin` is registered globally in the root `nx.json` plugins
array, so NX loads it for every project in `de-foundations` and in every consuming repo
(e.g. `dgc-dev-proof-ecomm-web`) — not just projects that opted into the flags generator.
Its public surface has three parts, all of which count as the contract for semver purposes:
the flags generator's scaffold output and NX tags, the four executor CLI schemas
(`add`/`update`/`delete`/`finalize`), and the persisted on-disk JSON data format
(`environments/*.json`, changeset files under `.changes/`, and the env-key substitution
tokens in `constants.ts`). This package ships no `migrations.json`, so a mis-classified
breaking change has no automated remediation path for existing repos.

Generic conventional-commit-derived bumps (`feat`→minor, `fix`→patch, `!:`→major) miss this
package's package-specific escalation rule: **any change to global plugin
registration/target-inference, or any change that forces existing repos to migrate
committed flag state or CI scripts, is a major** — because global registration makes the
entire monorepo an effective consumer.

This skill applies the package's documented rubric — not generic semver — to a change
description and outputs one of `major` / `minor` / `patch` plus a one-line justification
citing the specific rubric clause.

Source of truth: Confluence page "dft-feature-flag-plugin Semver" (page ID `2453274631`) and
`projects/FoundationSemver/decisions/dft-feature-flag-plugin.md` in context-docs. Confluence is
canonical if the two ever diverge; the decision doc is a mirrored snapshot. If either source is
later revised, re-read it — the table below is a snapshot, not the canonical copy.

## Trigger

- Reviewing a PR/commit/diff touching `packages/dft-feature-flag-plugin` — the flags
  generator's scaffold/tags, any of the four executor schemas, `environments/*.json`,
  `.changes/` changeset shape or naming, `trimOldestChangesets.ts`, `constants.ts` env-key
  tokens, or the plugin's registration/target-inference behavior in `nx.json`.
- An author needs a bump recommendation before writing a conventional-commit prefix
  (`feat:`, `fix:`, `feat!:`).
- Feeding a recommendation into the `package-release` skill before tagging — this skill
  complements that flow, it does not replace bump/tag/publish mechanics.
- Double-checking a change against the package's own documented historical mis-classification
  (v1.0.1 shipped as a patch despite containing a `feat:`-prefixed line — see Validated
  against historical releases below).

**Not for:** any other `dft-*` package (different rubrics — see the sibling
`*-bump-advisor` skills for other packages, or `migration-assessment` specifically for
`dft-mfe-generator`/`dft-web-monorepo-generator`). Not for generic semver questions
unrelated to this package.

## Input

- `change_description` — a diff or free-text description of the change to
  `dft-feature-flag-plugin`. That is the only required input.

## The rubric

Quoted verbatim from the Confluence page "dft-feature-flag-plugin Semver" (page ID
`2453274631`), Options section, Option 1 — Broad-surface strict semver (recommended):

| Bump | Fires when the change... |
|---|---|
| **Patch** (`fix`) | "internal bug fixes, docs, dependency bumps with no behavior change, output that stays byte-compatible with existing consumers." |
| **Minor** (`feat`) | "new executor, new optional CLI arg, new generated file/tag, new optional field in emitted JSON — anything purely additive that leaves existing repos and their on-disk state valid." |
| **Major** (`!:`) | "any change to plugin registration/target-inference semantics; removing/renaming an executor or generator; removing/renaming a CLI arg or making an optional one required; changing environments/*.json / changeset naming / env-key token shape in a way that requires existing repos to migrate their committed flag state." |

**Escalation rule (applies on top of the table above):** escalate to major any change that
alters global plugin registration/target-inference, or forces existing repos to migrate
committed flag state or CI scripts — since global registration makes the entire monorepo an
effective consumer.

**Documented historical mis-classification:** the rubric doc itself records that v1.0.1
shipped as a patch even though its CHANGELOG entry includes a `feat:`-prefixed line ("Add
link to Feature Flags docs") alongside a `docs:` line. Under the commit-type mapping above, a
`feat:` line should drive a minor — v1.0.1 is a documented mis-classification, not a clean
"docs-only patch." Treat this as a known pattern to catch, not a precedent to repeat.

## Steps

1. **Classify what changed.** Identify which surface(s) `change_description` touches:
   - Global plugin registration/target-inference semantics (how the plugin is listed or
     inferred in `nx.json`)
   - Generator scaffold output / NX tags (the flags generator, `generator-version.json`)
   - Executor CLI schemas (`add`, `update`, `delete`, `finalize` — args, required/optional
     status)
   - Persisted JSON/env-key format (`environments/*.json`, `.changes/` changeset naming or
     shape, `constants.ts` env-key tokens)
   - None of the above (internal bug fix, docs, dependency bump with no behavior change)
2. **Check the escalation rule first.** If the change touches global plugin
   registration/target-inference, or would force an existing repo to edit committed flag
   state or CI scripts to keep working, the bump is **major** regardless of how additive it
   otherwise looks — stop here.
3. **Otherwise, apply the rubric table** to the classified surface(s). If multiple surfaces
   are touched, the bump is the highest (most breaking) one that applies.
4. **Check for the historical mis-classification pattern.** If the change description
   contains a mix of commit-type-prefixed lines (e.g. both a `feat:` line and a `docs:` line)
   where any individual line would independently drive a minor under the rubric, the overall
   bump is that minor (or higher) — do not let an accompanying `docs:` line pull the result
   down to patch. Explicitly note when this matches the documented v1.0.1 pattern.
5. **If the change description is too sparse to classify confidently** — e.g. it doesn't say
   whether a new arg is optional or required, or whether a JSON field is new/optional vs.
   replacing an existing one — do not guess. Output a low-confidence flag naming exactly
   what's missing, plus your best-guess bump, rather than asserting a bump you can't justify
   from the rubric.

## Output format

```
BUMP: major | minor | patch
JUSTIFICATION: <one line citing the rubric clause that drove the recommendation>
MIGRATION NOTE: <n/a, or a note that this package ships no migrations.json — a major
  recommendation must be paired with manual migration guidance>
CONFIDENCE: high | low — <if low, name the missing information>
```

See `references/examples.md` for worked examples and validation against real history.

## Red flags

| Mistake | Fix |
|---|---|
| Letting an accompanying `docs:` line pull a mixed change down to patch | A `feat:`-prefixed line independently drives a minor under the commit-type mapping regardless of what else ships alongside it — see the v1.0.1 pattern in Scenario 4. |
| Treating an additive-looking scaffold/tag change as automatically safe | Confirm it doesn't invalidate existing on-disk state before calling it MINOR — the rubric's MINOR bar is "leaves existing repos and their on-disk state valid," not merely "adds something." |
| Judging a JSON-format or env-key-token change by diff size | A small code diff to `environments/*.json` shape, changeset naming, or a `constants.ts` token can break every consumer's flag state or CI silently — classify by blast radius, not diff size. |
| Missing the global-registration escalation | Any change to plugin registration/target-inference semantics in `nx.json` is major even if the diff looks small — check this rule first, before the surface-specific table. |
| Forgetting the no-migrations.json caveat on MAJOR | This package ships no `migrations.json` — a major recommendation must be paired with a note that manual migration guidance is needed, since there's no automated remediation path. |
| Forcing a bump when the description is ambiguous | Output `CONFIDENCE: low` and name the missing fact (e.g. "unclear whether the new field is optional or replaces an existing field") rather than guessing between MINOR and MAJOR. |

## Related skills

- `package-release` — the release flow this advisor's recommendation feeds into (bump, tag,
  publish mechanics). This skill only recommends the bump; it does not perform the release.
- `migration-assessment` — covers `dft-mfe-generator` and `dft-web-monorepo-generator`
  instead of `dft-feature-flag-plugin`; also useful context since this package's lack of a
  `migrations.json` is a deliberate contrast with that pattern.
- Sibling `*-bump-advisor` skills (e.g. `dft-bff-generator-bump-advisor`) — same shape,
  different package-specific rubrics.

## Exit criteria

- [ ] A bump tier was produced, or an explicit AMBIGUOUS/low-confidence report naming what's
  missing — never a silent guess.
- [ ] The justification names the specific changed surface and quotes the matched rubric clause.
- [ ] No edits were made to `package.json`, `CHANGELOG.md`, or `nx.json`.

## Provenance

Provenance: Hermes skill `learnings/skill-sharing` (corpus-wide porting authorship
attestation: ADR 0010).
Lineage: X-context-docs skills/dft-feature-flag-plugin-bump-advisor@9d7143e
