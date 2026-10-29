---
name: nx-generator-bump-advisor
description: >
  Use when a change to @sgwshub/nx-generator (a diff, PR description, or a
  summarized list of changed generators/schema/CDK output/exports) needs a
  version-bump recommendation before release. Triggers include "what bump
  does this nx-generator change need", "major or minor for nx-generator",
  "classify this nx-generator change", or preparing a conventional-commit /
  release for nx-generator. Advisory only — does not modify package.json or
  CHANGELOG; see package-release for the actual bump/publish flow.
model: sonnet
---

# nx-generator Bump Advisor

Classify a described change to `@sgwshub/nx-generator` as **major**,
**minor**, or **patch** by applying the package's documented rubric, and
output the specifier plus a one-line justification tied to the exact rubric
criterion matched.

**Advisory only.** This skill never edits `package.json`, `CHANGELOG.md`, or
`nx.json`. For the actual bump/tag/publish mechanics, use the
`package-release` skill.

## Trigger

Use when a diff, PR description, or free-form summary of a change to
`@sgwshub/nx-generator` needs a version-bump recommendation before release.

## Rubric source of truth

`~/projects/context-docs/projects/FoundationSemver/decisions/nx-generator.md`
(Action items / Outcome sections) — mirrored on Confluence as "nx-generator
Semver (FoundationSemver)" (page ID `2453962790`, re-scrapeable via
`query-confluence` if the local copy looks stale). If this skill's output
ever looks wrong, re-read that file first; the rubric below is a close
paraphrase of it that preserves every criterion, and if the two ever
disagree the doc wins. (Last verified against source: 2026-07-28 — if the
decision doc has since been edited, re-diff Step 2 below against its Action
Items section before trusting either copy.)

`@sgwshub/nx-generator` is two products in one artifact: (1) a generator
plugin — `generators.json` registers `app`, `bff`, `route`, `workflow`,
loaded globally by every consumer via the root `nx.json`; and (2) a runtime
library — `src/index.ts` re-exports the CDK construct layer
(`app-factory`, `environment-stacks`, `base-api-gateway-stack`,
`api-gateway-v1`, naming/tagging/config utils) plus 11 Lambda "layers"
runtime modules, with a `./shared` subpath export, imported at runtime by
every generated BFF. It is pre-1.0 (`0.1.16`) but the decision doc mandates
applying **1.0-style discipline now** rather than the SemVer 0.x
"minor-may-break" allowance, because it is the highest-blast-radius package
in the repo: a bad release breaks scaffolding for every new project AND the
runtime of every already-generated BFF, and its CDK output carries the same
destructive-infra risk class as `dft-iac-generator` (naming/tagging changes
can cause CloudFormation logical-ID churn → resource replacement/teardown).

## Steps

### Step 1 — Read the change

Take whatever the caller supplies: a git diff, a PR description, or a
free-form summary. If it's a raw diff, focus on:
- `generators.json` and each generator's schema (`app`, `bff`, `route`,
  `workflow`) — required options, enum values (e.g. `bff`'s
  `express|gigya|apigee|proxy|workflow` features), option types/semantics
- Generated output shape: CDK stack structure, `cdk.json`, env files,
  `project.json` targets, route/express file layout, and specifically
  naming/tagging code (`naming-utils`, `tag-manager`, `to-valid-tag`) that
  determines CloudFormation resource identity
- `src/index.ts` and `src/shared/**` exports (CDK constructs, the 11
  Lambda-layer runtime modules) — additions, removals, renames, retyping
- Node/NX/`aws-cdk-lib` engine floor changes in `package.json`
- Behavior-only changes with no schema/output/export diff (bugfixes,
  internal refactors, template fixes that don't move file paths or logical
  IDs)

### Step 2 — Apply the rubric

Check criteria in this order — **MAJOR first**, then MINOR, then PATCH.
Evaluate the change against **all three tiers** before finalizing — do not
stop at the first tier that matches. A change can satisfy multiple criteria;
always report the highest bump among all matches (see Step 3 for mixed
changes instead of silently picking the lower one). Before finalizing,
confirm you actually checked MAJOR, MINOR, and PATCH — not just the first
criterion that happened to match.

### MAJOR — breaking a generator contract, generated output, or runtime export
- Removing or renaming a generator (`app`, `bff`, `route`, `workflow`) or a
  required schema option, or changing an option's type/semantics
- Any change to generated CDK output that **alters resource identity**
  (naming/tagging/stack structure) and can cause CloudFormation
  replacement/teardown — treat this as MAJOR **by default** even if the
  generator's own schema is unchanged, because it shares `dft-iac-generator`'s
  destructive-change risk class
- Removing, renaming, or retyping any `./` or `./shared` runtime export
  (CDK constructs, the 11 Lambda-layer modules)
- Raising the Node/NX/`aws-cdk-lib` engine floor in a way that breaks
  consumers

### MINOR — purely additive, no disturbance to existing schema/output/exports
- A new generator
- A new optional schema option, with a default
- An additive new export in `./` or `./shared`
- A new optional `bff` feature
- Additive template files that don't disturb existing resources

### PATCH — bugfix with no schema/output/export change
- A bug fix to a generator that doesn't change its schema or the shape of
  generated output
- An internal fix to `shared/**` that preserves exported signatures and
  generated-artifact structure
- A template fix that doesn't alter file paths, CDK logical IDs, or resource
  identities

### Step 3 — Handle ambiguous or mixed changes

If the described change touches **both** an internal-only path and a
schema/output/export-affecting path — or you cannot tell whether generated
CDK resource identity is affected — do not silently pick the lower bump.
Report:

```
AMBIGUOUS — cannot classify with confidence.
Reason: <what's mixed or missing>
Highest-bump interpretation: <major|minor|patch>, because <criterion>
Lowest-bump interpretation: <major|minor|patch>, because <criterion>
Recommend: request the generated-output diff (a fresh `nx g @sgwshub/nx-generator:bff`
or equivalent run, diffed against the prior generator output) or the specific
schema/export change before finalizing the release bump.
```

This applies in particular to changes that touch naming/tagging code
(`naming-utils`, `tag-manager`, `to-valid-tag`) without stating whether the
resulting CloudFormation logical IDs actually change — don't assume "no" by
default; that assumption is exactly what the MAJOR-by-default rule in Step 2
exists to prevent.

### Step 4 — Output format

For unambiguous classifications, output exactly:

```
Recommended bump: <major|minor|patch>
Justification: <one line, name the specific generator/schema/export/CDK
output changed and quote or closely paraphrase the matched rubric criterion>
Rubric source: ~/projects/context-docs/projects/FoundationSemver/decisions/nx-generator.md
```

See `references/examples.md` for worked examples (FOUND-1842 acceptance criteria) and validation against real commit history.

## Red flags

| Rationalization | What to do instead |
|---|---|
| Treating this package like ordinary 0.x SemVer, where minors may break | The decision doc explicitly rejects that allowance for this package — apply 1.0-style discipline now regardless of the `0.` prefix |
| Assuming a naming/tagging code change is safe because the generator's schema didn't change | Resource-identity-affecting CDK output changes are MAJOR by default even with an unchanged schema — this package shares `dft-iac-generator`'s destructive-change risk class |
| Classifying a `nx.json`/release-tooling-only change (no schema/output/export touched) as patch by default | It's outside this rubric's classified surface — report it as out-of-scope, don't force a tier |
| Picking the lower bump when a change is genuinely mixed | Use Step 3 — report AMBIGUOUS and both interpretations, and ask for the generated-output diff before finalizing |
| Assuming this skill also performs the release | It does not — it is advisory only; hand the recommended specifier to `package-release` for the actual bump/publish |

## Scope

Scoped to `@sgwshub/nx-generator` only, per FOUND-1842. No `migrations.json`
currently exists for this package (unlike `dft-mfe-generator`), so a MAJOR
recommendation here has no automated migration path yet — flag that gap when
recommending major for a generated-output change.

## Exit criteria

- [ ] A bump tier (major/minor/patch) was produced, or an explicit AMBIGUOUS
  report with both interpretations — never a silent guess.
- [ ] The justification names the specific changed generator/schema/export/
  CDK output and quotes or closely paraphrases the matched rubric criterion.
- [ ] No edits were made to `package.json`, `CHANGELOG.md`, or `nx.json`.

## Provenance

Provenance: Hermes skill `learnings/skill-sharing` (corpus-wide porting
authorship attestation: ADR 0010).
Lineage: X-context-docs skills/nx-generator-bump-advisor@9d7143e (trimmed:
canonicalized the stale `context-docs-worktrees/foundation-semver/...` rubric
path, which no longer exists on disk, to the real `~/projects/context-docs/...`
path)
