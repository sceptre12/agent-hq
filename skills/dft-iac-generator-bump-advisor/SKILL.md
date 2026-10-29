---
name: dft-iac-generator-bump-advisor
description: >
  Use when a PR diff or change description touches @sgwshub/dft-iac-generator
  (packages/dft-iac-generator) and someone needs a recommended semver bump —
  triggers on *.tf.template diffs, generators.json changes, moduleSourcePath
  edits, var.* additions/renames/removals, required_providers/required_version
  changes, or generator-version.json/schema edits. Also triggers on "what bump
  is this", "is this a major", "does this need a migration to avoid a major"
  for dft-iac-generator.
---

# dft-iac-generator Bump Advisor

## Overview

`@sgwshub/dft-iac-generator`'s real public surface is the **generated
Terraform/OpenTofu**, not its TypeScript API. A resource rename, a
`moduleSourcePath` change, or a `var.*` rename can make an already-generated
project's next `terraform plan` **destroy and recreate live AWS/Harness
resources** — a materially higher-risk failure mode than a normal code API
break. This skill applies the package's documented **infra-blast-radius
semver rubric** (not generic "exported symbol" semver) to a described change
and outputs one of `major` / `minor` / `patch` with a justification tied to
the rubric.

**Source of truth:** [dft-iac-generator.md](~/projects/context-docs/projects/FoundationSemver/decisions/dft-iac-generator.md)
(FoundationSemver decision doc, re-scrapeable via `query-confluence` if stale). If that doc is revised, re-sync this skill —
do not let the encoded rubric drift from the documented policy. If asked to
re-verify the rubric against that path and the file is unreadable (moved
worktree, deleted path), do not fall back to the encoded rubric below as if
freshness were guaranteed — say the source doc could not be confirmed current
and ask for it, per [Step 4](#step-4--ambiguous-input-do-not-guess)'s
no-guessing format.

**Downstream consumer:** the bump this skill recommends is advisory input to
the `package-release` skill's conventional-commit-driven release flow
(`feat`→minor, `fix`→patch, `!:`/`BREAKING CHANGE`→major). This skill decides
*which* of those the change should be; `package-release` still owns *how* the
bump ships.

## When NOT to use

- The change is to a different `de-foundations` package (e.g.
  `dft-mfe-generator`, `dft-bff-generator`) — those have their own decision
  docs; use `pr-check-migration-needed` / `migration-assessment` instead.
- You need to know whether a migration script is *required* for correctness
  (not just whether it downgrades a major to a minor) — that's
  `pr-check-migration-needed`'s `SKILL-02.md` rules for `dft-iac-generator`.

## Trigger

Use when a diff, PR description, or free-text description of a change to
`@sgwshub/dft-iac-generator` (a Terraform module/template change) needs a
version-bump recommendation before release.

## Inputs

- `change_description`: a diff (of `*.tf.template` files, `generators.json`,
  schema files, `generator-version.json`) or free-text description of a
  change to `dft-iac-generator`.
- Optional: whether a migration script (`migrations.json` entry) and/or
  Terraform `moved {}` / `import` blocks ship alongside the change.

## Steps

### Step 1 — Classify the terraform plan verb

For every change, first decide what `terraform plan` would do to an
**already-generated, live** project if this change were applied to it:

| Verb | Meaning |
|---|---|
| **no-op** | Plan shows no changes for existing resources |
| **in-place update** | Plan updates attributes without destroying anything |
| **replace / destroy-recreate** | Plan destroys and recreates one or more resources/modules |

This is the pivot the whole rubric hangs on for the resource/module/`var.*`/
`moduleSourcePath`/`required_providers`/control-plane-workspace-restructuring
bullets below. Two MAJOR triggers — removing/renaming a generator ID and a
backward-incompatible schema option change — are TypeScript/schema-surface
breaking changes evaluated on their own terms, not derived from a terraform
plan verb; don't force those two through this step's plan-verb question. If
you cannot determine the verb from the input for the plan-verb-derived
bullets, stop and go to
[Step 4 — Ambiguous input](#step-4--ambiguous-input-do-not-guess).

### Step 2 — Apply the rubric

Quoted rubric language is from the decision doc's Outcome section — use it
verbatim or closely paraphrased in the justification.

### PATCH — "no-op terraform plan for existing generated projects"

- Comment / formatting / README fixes
- Cosmetic `outputs.tf` label changes
- Version-stamp bumps only (the `update-1-2-0` pattern: bumping
  `generator-version.json` stamps, no template/resource change)
- Internal generator refactors that emit byte-equivalent or plan-equivalent
  `.tf`
- Bug fixes that correct a clearly-broken template **without moving any
  resource address**

### MINOR — "purely additive output" OR a destructive change neutralized by a shipped migration

Fires on either of two independent conditions:

1. **Purely additive, non-destructive:** a new optional generator schema
   option defaulting off; a new `var.*` with a safe default; a new opt-in
   resource/flag that yields *update-in-place* (not replace); a new generator
   target (e.g. a fourth generator alongside `bff`/`deployment-backend`/`control-plane`).
2. **Neutralized major:** an otherwise-breaking resource/module rename,
   removal, or `moduleSourcePath` change that ships **with** an `nx-migrations`
   codemod (a `migrations.json` entry) that emits Terraform `moved {}` blocks
   or documented `import`/`terraform state mv` steps, such that existing
   projects' next plan is a no-op. The migration is what downgrades this from
   MAJOR to MINOR — a destructive-shaped change with no shipped migration is
   still MAJOR (see below).

### Precedent-based extensions (not verbatim in the decision doc's Outcome section)

The two bullets below are the skill author's extrapolation from real shipped
history (CHANGELOG precedent), applying the rubric's stated principles to
cases the Outcome section doesn't spell out explicitly. Treat these as
lower-authority than the quoted rubric bullets above and below — if the
decision doc is ever revised to address either case directly, the doc wins.

- **Editor/tooling-only additions with no enforcement wired up** (e.g. a
  `$schema` / companion `.schema.json` file with no `ajv` call in the
  generator or pipeline) are PATCH, not MINOR — precedent: `1.1.2`'s
  `idp-product.schema.json`, where the CHANGELOG's own note says it "ships as
  a patch rather than a minor" because it's not a new enforcement boundary.
- **A deprecated-but-retained fallback** (old field kept working alongside a
  new one) is additive, not destructive — MINOR, not MAJOR — even though it
  changes default behavior for new generations. Precedent: `1.1.0`'s
  `baseDomain` deprecated-alias fallback alongside the new two-domain fields.

### MAJOR — "destroy and recreate live resources with no safe migration"

- Renaming or removing a resource or `module` block
- Changing `moduleSourcePath` (the `module "bff" { source = ... }` value)
- Renaming or removing a consumed `var.*` (the `variables.tf` this references
  often lives in the separate `de-foundations-iac` repo, not in the
  `de-foundations` diff under review — watch for a linked cross-repo PR, per
  `pr-check-migration-needed`'s `SKILL-02.md` cross-repo warning)
- Restructuring the control-plane workspace set
- Tightening `required_providers` / `required_version` in a way that forces
  replacement
- Removing or renaming a generator ID (in `generators.json` / `src/index.ts`)
- A backward-incompatible schema option change

None of these get to be MAJOR by default and then escape it — always check
whether condition 2 under MINOR (a shipped migration + `moved`/`import`
blocks) applies before finalizing MAJOR. If it does, the verdict is MINOR.

### Step 3 — Output format

```
Recommended bump: <major|minor|patch>

Justification: <one line quoting or closely paraphrasing the specific rubric
clause that drove the decision, naming the concrete change>
```

### Step 4 — Ambiguous input: do not guess

Per FOUND-1829's Reliability requirement, **false negatives (under-classifying
a destructive change) are the highest-severity failure mode** for this
package — bias toward flagging ambiguity over guessing.

If the input doesn't clearly indicate the terraform plan verb (no-op /
in-place / replace) for the affected resource, do not emit a single confident
recommendation. Instead:

```
Cannot classify with confidence: <what's missing — e.g. "diff doesn't show
whether var.foo is consumed by module 'bff' or dead code">

Per the decision doc's PR-checklist item: state the expected terraform plan
verb (no-op / in-place / replace) for the affected resource on existing
generated projects, then re-run this advisor.
```

See `references/examples.md` for worked examples and validation against real history.

## Red flags

| Mistake | Fix |
|---|---|
| Treating this as generic "exported symbol" semver | This package's real surface is the emitted `.tf`, not `src/index.ts` — Option 2 in the decision doc is explicitly the *wrong*, dangerous default for this package |
| Calling a migrated rename MAJOR | Check for a shipped `migrations.json` codemod + `moved`/`import` block first — if present, it's MINOR, not MAJOR |
| Guessing the terraform plan verb from vague language ("tweaked", "updated", "changed") | Flag as ambiguous per Step 4 rather than assuming no-op or in-place |
| Assuming a new `$schema`/`.schema.json` file is always MINOR (additive file = additive feature) | Check whether it's enforced (`ajv`) anywhere — if it's editor/tooling-only with no enforcement, it's PATCH per the `1.1.2` precedent |
| Confusing this skill with a migration-*requirement* check | This skill only asks "does a migration exist to downgrade this to MINOR" — whether one is *required* for correctness is `pr-check-migration-needed`'s job |

## Exit criteria

- [ ] A bump tier was produced, or an explicit AMBIGUOUS/do-not-guess report when the input
  is insufficient — never a silent guess.
- [ ] The justification names the specific terraform-plan-verb/resource change and quotes
  the matched rubric criterion.
- [ ] No edits were made to `package.json`, `CHANGELOG.md`, or any `.tf.template` file.

## Provenance

Provenance: Hermes skill `learnings/skill-sharing` (corpus-wide porting authorship
attestation: ADR 0010).
Lineage: X-context-docs skills/dft-iac-generator-bump-advisor@9d7143e (trimmed: genericized
a leaked work-machine absolute path — `/Users/Xavier.Thomas/projects/context-docs-worktrees/
foundation-semver/...`, a stale worktree — to the real `~/projects/context-docs/...` path)
