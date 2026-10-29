---
name: dft-component-generator-bump-advisor
description: >
  Use when a described change or diff to @sgwshub/dft-component-generator
  (the src/schema.json invocation schema, scaffolded output in
  files/**, the component generator id in generators.json, or the
  decision-tree/recommendation gating in src/utils/decision-tree.ts and the
  override-gating flow in src/generator.ts) needs a
  recommended semver bump. Triggers: "what bump is this for
  dft-component-generator", "does this need a major version", "semver this
  dft-component-generator change", "is this a breaking change for
  dft-component-generator", or reviewing a PR/commit touching
  packages/dft-component-generator before drafting a conventional-commit
  prefix or tagging a release. Advisory only — does not modify
  package.json, CHANGELOG.md, or nx.json; see package-release for the
  actual bump/publish flow.
---

# dft-component-generator Bump Advisor

## Overview

`@sgwshub/dft-component-generator`'s public surface is not a runtime API —
it has no internal de-foundations dependencies and consumers never `import`
from it at runtime. Its contract has three faces, per the package's
documented rubric:

1. **Generator invocation surface** — the `component` generator id in
   `generators.json` and the option schema in `src/schema.json`.
2. **Scaffolded output contract** — the shape of the files it writes
   (`.tsx` component, co-located `.spec.tsx`, barrel `index.ts`,
   `jest.setup.ts`, `generator-version.json` stamp, default `customPath`
   output directory). Note: `src/schema.json` declares a cosmetic
   `"default": "libs/shared/ui"` for `customPath`, but that value is never
   read at runtime — the actual operative default is `common/ui`, set via
   `initial: 'common/ui'` in `src/utils/prompts.ts` and mirrored as the
   `options.customPath || 'common/ui'` fallback in
   `src/utils/validation.ts`. Classify changes to *those* two call sites,
   not to `schema.json`'s metadata string, under the "default output path"
   MAJOR clause below.
3. **Decision-tree / recommendation behavior** — the architectural
   guidance computed in `src/utils/decision-tree.ts` that determines
   whether/where a component is generated. The actual override flow is an
   unconditional interactive `proceedAnyway`/`overrideReason` prompt
   sequence in `src/generator.ts`; note that the `overrideRecommendation`
   schema field is captured into `NormalizedSchema` but is never read to
   gate that flow — it is currently a write-only/inert field, not a
   functioning bypass mechanism.

The package's recommended policy is **"Full generator-contract semver — the
invocation schema, scaffolded-output shape, and recommendation gating are
all the contract; breaking the generated file structure or defaults is a
major."** This skill applies that documented rubric — not generic
semver-by-exports — to a change description and outputs one of
`major` / `minor` / `patch` plus a one-line justification citing the
specific rubric clause matched.

**Advisory only.** This skill never edits `package.json`, `CHANGELOG.md`,
or `nx.json`. For the actual bump/tag/publish mechanics, use the
`package-release` skill (`~/.claude/skills/package-release/SKILL.md`).

Source of truth: Confluence page "dft-component-generator Semver" (page ID
`2454290436`), mirrored in context-docs at
`~/projects/context-docs/projects/FoundationSemver/decisions/dft-component-generator.md`
(Outcome section). The rubric below is a verbatim transcription of that
doc's Option 1 criteria, not a paraphrase — if the two ever disagree, the
doc wins; re-read it first.

## Trigger

- Reviewing a PR/commit/diff touching `packages/dft-component-generator` —
  `src/schema.json`, `generators.json`, `src/utils/decision-tree.ts`, or
  any file under `files/**` that the generator writes to a consumer
  workspace.
- An author needs a bump recommendation before writing a
  conventional-commit prefix (`feat:`, `fix:`, `feat!:`).
- Feeding a recommendation into the `package-release` skill before
  tagging — this skill complements that flow, it does not replace
  bump/tag/publish mechanics.

**Not for:** any other de-foundations package — each has its own
rubric doc (see the other 20 child pages under "Foundations Package
Semver Defs"). Not for generic semver questions unrelated to this
package.

## Input

- `change_description` — a diff, PR description, or free-text summary of
  the change to `dft-component-generator`. That is the only required
  input.

## The rubric

Quoted verbatim from the rubric doc's Options section (Option 1, the
adopted policy):

| Bump | Fires when the change... |
|---|---|
| **MAJOR** (`feat!:` / `fix!:` / `BREAKING CHANGE`) | "remove/rename a schema option; add a new required option; flip a default that changes generated output or targeting (e.g. `customPath` default, `createPath`, `fetchesData`); remove/rename the `component` generator id; change the emitted file set or a structural convention consumers rely on — e.g. dropping the default export, moving the co-located `.spec.tsx`, changing the barrel `index.ts` re-export shape, or changing the default output path `libs/shared/ui`." |
| **MINOR** (`feat:`) | "add a new optional schema option with a safe default; add a new generated file that doesn't displace existing ones; additive, opt-in changes to boilerplate or the decision tree." |
| **PATCH** (`fix:`) | "bug fixes, prompt-wording/description tweaks, validation-message fixes, dependency bumps, and cosmetic template edits that don't change file structure or the emitted API." |

**Caveat (not in the source doc, added for accuracy):** the doc's "default output path `libs/shared/ui`" refers to `schema.json`'s cosmetic `"default"` metadata, which is never read at runtime. The operative default a change actually affects is `common/ui`, set via `initial: 'common/ui'` in `src/utils/prompts.ts` and mirrored as the `options.customPath || 'common/ui'` fallback in `src/utils/validation.ts`. Classify changes to those two call sites — not to `schema.json`'s metadata string — under this MAJOR clause.

## Steps

1. **Classify what changed.** Identify which surface(s) `change_description`
   touches:
   - Invocation schema (`src/schema.json` options, the `component`
     generator id in `generators.json`)
   - Scaffolded output shape (files under `files/**`, the default export,
     co-located `.spec.tsx`, barrel `index.ts`, `jest.setup.ts`,
     `generator-version.json` stamp, default output path — the real
     default is `common/ui` per `prompts.ts`/`validation.ts`, not
     `schema.json`'s inert `libs/shared/ui` metadata)
   - Decision-tree / recommendation gating
     (`src/utils/decision-tree.ts`; the `proceedAnyway`/`overrideReason`
     prompt flow in `src/generator.ts` — not `overrideRecommendation`,
     which is currently inert and not wired to any gating logic)
   - None of the above (docs, dependency bumps, internal refactor,
     build-config/release-target changes with no schema or output-shape
     change)
2. **Apply the rubric table** to each surface identified in Step 1 that you
   can confidently classify, checking **MAJOR first**, then MINOR, then
   PATCH, stopping at the first match per surface. If more than one
   surface is confidently classified and their bumps differ, report the
   highest (most breaking) bump among them — do not silently pick the
   lower one. This applies even when the surfaces differ sharply in
   severity (e.g. one cosmetic-looking edit plus one clearly-MAJOR
   structural change) — severity spread alone is not ambiguity; see Step 3
   for what actually is.

   **2a. "None of the above" surface.** If the touched surface is
   docs-only, a dependency bump, an internal refactor, or a build/release-
   config change with no schema, output, or decision-tree change, classify
   it **PATCH** directly. The absence of a literal rubric-table clause
   naming "build-config" or "internal refactor" is not ambiguity — it is
   this default.
3. **Only if you cannot confidently classify a touched surface at all** —
   the input doesn't say enough to tell whether a given surface was
   touched, or doesn't specify which rubric clause applies to it — do not
   guess. Output:

   ```
   AMBIGUOUS — cannot classify with confidence.
   Reason: <what's mixed or missing>
   Highest-bump interpretation: <major|minor|patch>, because <clause>
   Lowest-bump interpretation: <major|minor|patch>, because <clause>
   Recommend: request the specific schema/file diff before finalizing the
   release bump.
   ```

## Output format

For unambiguous classifications, output exactly:

```
Recommended bump: <major|minor|patch>
Justification: <one line, name the specific schema option/file/behavior
changed and quote or closely paraphrase the matched rubric clause>
Rubric source: ~/projects/context-docs/projects/FoundationSemver/decisions/dft-component-generator.md
```

See `references/examples.md` for worked examples and validation against real history.

## Red flags

| Mistake | Fix |
|---|---|
| Treating a boilerplate/template edit as automatically PATCH because "it's just output" | Under this package's adopted Option 1 policy, structural output changes (dropping the default export, moving `.spec.tsx`, changing the barrel `index.ts` shape, or changing the default output path) are MAJOR — the doc explicitly rejects the invocation-only Option 2 policy where output is non-contractual. |
| Flagging a change to `schema.json`'s `"default": "libs/shared/ui"` metadata as MAJOR, or missing a change to the real default | `schema.json`'s declared default is never read at runtime — it's dead metadata. The operative `customPath` default is `common/ui`, set via `prompts.ts`'s `initial` and mirrored in `validation.ts`'s fallback. Classify changes to those two call sites under the MAJOR "default output path" clause; a `schema.json`-only metadata edit is not itself a behavior change. |
| Classifying a default-value flip (e.g. `createPath`, `fetchesData`) as MINOR because "it's just a default" | A default flip that changes generated output or targeting is explicitly MAJOR per the rubric — non-interactive callers are coupled to exact default values. |
| Picking the lower bump when a change touches multiple surfaces that classify differently (e.g. a cosmetic docs tweak alongside a clearly MAJOR barrel `index.ts` shape change) | This is not ambiguity — both surfaces are confidently classified, just at different severities. Per Step 2, report the highest (MAJOR) bump. Reserve AMBIGUOUS (Step 3) for when you genuinely cannot tell whether/how a surface was touched. |
| Assuming this skill also performs the release | It does not — it is advisory only; hand the recommended specifier to `package-release` for the actual bump/publish. A human must still approve the actual bump — see the Jira ticket's Risks/Considerations section on false confidence in advisor output. |
| Treating internal build/release-config changes (e.g. removing an `nx.json`/`project.json` release target) as ambiguous | These are outside all three contract faces (schema, output, decision-tree) — classify PATCH, as validated against PR #214 / FOUND-1190 above. |

## Scope

Scoped to `@sgwshub/dft-component-generator` only, per FOUND-1840.
Generalizing this advisor pattern to the other 20 de-foundations packages
with their own semver rubric docs under "Foundations Package Semver Defs"
is a candidate follow-up per the ticket's Notes/Open Questions, not
covered here. If the package's policy changes (e.g. Option 2 is adopted
instead of Option 1), this skill's encoded rubric must be re-synced — see
the ticket's Risks/Considerations section on rubric drift.

## Exit criteria

- [ ] A bump tier was produced, or an explicit AMBIGUOUS/low-confidence report naming what's
  missing — never a silent guess.
- [ ] The justification names the specific changed surface and quotes the matched rubric clause.
- [ ] No edits were made to `package.json`, `CHANGELOG.md`, or `nx.json`.

## Provenance

Provenance: Hermes skill `learnings/skill-sharing` (corpus-wide porting authorship
attestation: ADR 0010).
Lineage: X-context-docs skills/dft-component-generator-bump-advisor@9d7143e
