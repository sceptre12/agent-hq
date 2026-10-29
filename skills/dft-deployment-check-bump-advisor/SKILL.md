---
name: dft-deployment-check-bump-advisor
description: >
  Use when classifying a change to @sgwshub/dft-deployment-check (a diff, PR
  description, commit message, or free-text change summary) against its
  documented behavior-first semver rubric to recommend a major/minor/patch
  version bump. Triggers include "what version bump does this need", "is this
  a breaking change to dft-deployment-check", "classify this
  dft-deployment-check change", or preparing a conventional-commit / release
  for the CI deployment-check gate. Advisory only — does not write
  package.json, tags, or CHANGELOG.
model: sonnet
---

# dft-deployment-check Bump Advisor

`@sgwshub/dft-deployment-check` is an NX plugin that acts as a **CI gate**:
it fails a build when a project's `package.json#version` was not bumped
before merge. Because it is consumed via `nx.json#plugins` (not imported as
code), its behavior — not its TypeScript signatures — is the contract every
downstream pipeline depends on. Its documented policy is **behavior-first
semver**: any tightening or loosening of what the gate enforces is a major,
even with no signature change.

This skill applies that rubric to a described change and outputs one
recommended bump level with a one-line justification tied to the specific
rubric clause matched.

**Advisory only.** This skill never edits `package.json`, tags, or
`CHANGELOG.md`. For the actual bump/publish mechanics, use the
`package-release` skill.

## Trigger

Use when a diff, PR description, commit message, or free-text change summary
for `@sgwshub/dft-deployment-check` needs a version-bump recommendation
before release.

## Rubric source of truth

`~/projects/context-docs/projects/FoundationSemver/decisions/dft-deployment-check.md`
(Outcome section) — mirrored on Confluence as "dft-deployment-check Semver"
(page ID `2454323203`, re-scrapeable via `query-confluence` if stale). The
rubric below is a verbatim transcription of that doc's Options-considered
table, not a paraphrase; if the two ever disagree, the doc wins. If the doc
is missing or unreachable, **fail clearly** — say so and stop. Do not fall
back to generic conventional-commit semver for this package; a rule
tightening landing as a patch can block every downstream pipeline, and a
loosening landing as a patch can let un-versioned deploys through.

## When NOT to use

- Bumping any other de-foundations package — this rubric is specific to
  `dft-deployment-check`'s CI-gate behavior.
- Actually writing the version bump — hand the recommendation to
  `package-release`; this skill only advises.

## The package's public surface

Two distinct surfaces, both part of the behavioral contract:

1. **The `createNodesV2` inference plugin** (`src/index.ts`) — decides
   *which* projects get gated and *how* the target is wired: runs only when
   `ALLOW_DEPLOYMENT_CHECK=true`; scopes to `apps/`, excluding
   `apps/examples/` and any path containing `e2e`; injects a
   `deploymentCheck` target (`executor: 'deployment-check:check'`) into
   projects with an existing NX target; adds `deploymentCheck` to the
   `build` target's `dependsOn`.
2. **The `check` executor** (`src/executors/check.ts` +
   `utils/checkPackageVersionChangeInCd.ts`) — the enforcement rule: finds
   the most recent merge commit on `main`, compares `package.json#version`
   at the merge base vs. the feature-branch parent, fails when they're
   equal. Throws on missing/empty `package.json` or git failures.

The executor's schema (`src/executors/schema.json`) is currently empty
(`properties: {}`) — there are no user-facing options today, so almost the
entire behavior is convention-driven, not signature-visible.

**Internal dependency treated as part of the contract:** dev-depends on
`@sgwshub/dft-get-project-target-state` (`workspace:*`); `index.ts` reads
`.packageJson.hasNxTarget` / `.projectJson.hasNxTarget` from it. A breaking
change to that output shape is a MAJOR here even though the dependency
itself is a dev/bundled one.

## Steps

### Step 1 — Read the change

Take whatever the caller supplies: a git diff, a PR description, or a
free-form change summary. Look specifically for:

- Changes to the `apps/`-only path scope, the `examples/` or `e2e` exclusion
  filters
- Changes to the `deploymentCheck` target name or `deployment-check:check`
  executor id
- Changes to the `ALLOW_DEPLOYMENT_CHECK` opt-in env var
- Changes to the "was bumped" comparison logic (what counts as a bump, e.g.
  requiring an increase or a matching git tag)
- Additions/removals/renames in `src/executors/schema.json`
- Changes to where the executor throws vs. returns `{ success: false }`
- Any change to how `dft-get-project-target-state`'s output is consumed
- Whether the change is purely internal (refactor, perf, dependency version
  bump, non-behavioral build tooling)

### Step 2 — Apply the rubric

Check tiers in this order — **MAJOR first**, then MINOR, then PATCH — and
report the highest tier that matches (a change can satisfy more than one
description; the highest-impact tier always wins).

### MAJOR — any change to what the gate enforces
Quoted from the decision doc:
- "any change to which projects are gated (path filters, `apps/`-only scope,
  examples/e2e exclusion)"
- "the target/executor names (`deploymentCheck`, `deployment-check:check`)"
- "the opt-in env var"
- "the meaning of 'version was bumped' (e.g. now requiring the bump be an
  increase, or requiring a tag)"
- "removing/renaming schema options"
- "throwing where it used to pass or passing where it used to throw"
- "adopting a breaking `dft-get-project-target-state` output shape"

### MINOR — additive, backward-compatible surface growth
Quoted from the decision doc:
- "new optional executor schema options that default to today's behavior"
- "gating additional projects only behind a new opt-in flag"
- "additional log/diagnostic output"
- "a compatible dependency range bump"

### PATCH — non-behavioral fixes
Quoted from the decision doc:
- "bug fixes that restore documented behavior (e.g. the existing fix that
  compares parsed version instead of grepping 'version')"
- "internal refactors, perf, non-behavioral build changes"

### Step 3 — Handle ambiguous changes

If the description does not clearly match a single tier — e.g. it's too
sparse to tell whether a change affects the gated-project set, or whether a
schema addition really defaults to today's behavior — **do not silently
guess**. Per FOUND-1839's Risks/Considerations section (misclassification
risk, no enforcement authority — this skill is advisory, not a gate), surface
the ambiguity explicitly and recommend the more conservative (higher) tier,
flagging it for human review:

```
BUMP: ambiguous — recommending <higher-tier> as the conservative default
REASON: <what's missing or unclear>
CONSERVATIVE TIER: <major|minor|patch>, because <why this is the safer
  default given the blast radius>
Recommend: get the specific diff or a clearer change description before
  finalizing the release bump.
```

Given this package's blast radius (widest of any package in the monorepo —
gates every app's build), never resolve ambiguity toward the *lower* tier.

### Step 4 — Output format

For unambiguous classifications, output exactly:

```
BUMP: <major|minor|patch>
JUSTIFICATION: <one line citing the matched rubric clause verbatim or near-
  verbatim, e.g. "MAJOR — changes the examples/e2e exclusion filter, which
  changes which projects are gated.">
RUBRIC SOURCE: ~/projects/context-docs/projects/FoundationSemver/decisions/dft-deployment-check.md
```

See `references/examples.md` for worked examples and validation against real history.

## Red flags

- **"No exported TypeScript type changed, so it can't be major"** — false by
  default. This package's contract is CI-gate *behavior*, not signatures;
  the rubric explicitly rejects "signature-only" classification (see
  Option 2 in the decision doc, not adopted) because the executor's schema
  is empty and nearly every real change is behavior-only.
- **"It's just a dependency bump, so it's always a patch"** — only true when
  the range bump is compatible and introduces no forwarded behavior change.
  Check whether the dependency change is `@sgwshub/dft-get-project-target-state`
  specifically — a breaking shape change there is MAJOR regardless of how
  small the version delta looks.
- **Change description is sparse or mixed across tiers** — do not pick the
  lower tier to "resolve" ambiguity. Use Step 3: report ambiguous and
  recommend the higher (more conservative) tier given the package's blast
  radius.
- **Rubric doc unreachable** — do not fall back to generic conventional-commit
  semver. Report the doc is missing and stop.

## Related skills

This skill's `BUMP` output feeds directly into `package-release`'s
`--specifier=<patch|minor|major>` step — hand the recommended tier to that
skill to actually cut the release. It does not overlap with
`pr-check-migration-needed` or `migration-assessment`, which assess whether a
migration script is needed, not which semver tier applies.

## Scope

Scoped to `@sgwshub/dft-deployment-check` only, per FOUND-1839.
Generalizing to read any package's decision doc under
`projects/FoundationSemver/decisions/` is a candidate follow-up (see the
ticket's Open Questions), not covered here.

## Exit criteria

- [ ] A bump tier was produced, or an explicit AMBIGUOUS report with both interpretations.
- [ ] The justification names the specific gate behavior changed and quotes the matched
  rubric criterion.
- [ ] No edits were made to `package.json`, `CHANGELOG.md`, or `nx.json`.

## Provenance

Provenance: Hermes skill `learnings/skill-sharing` (corpus-wide porting authorship
attestation: ADR 0010).
Lineage: X-context-docs skills/dft-deployment-check-bump-advisor@9d7143e (trimmed:
canonicalized a stale `context-docs-worktrees/foundation-semver/...` rubric path to the real
`~/projects/context-docs/...` path)
