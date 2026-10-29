---
name: dft-global-typings-bump-advisor
description: Use when a PR diff, changeset summary, or ticket description changes @sgwshub/dft-global-typings and the correct semver bump (major/minor/patch) needs to be determined before a release — e.g. "what version bump does this dft-global-typings change need?", "does this PR need a major for dft-global-typings?", or reviewing a dft-global-typings PR/release before package-release runs.
model: sonnet
---

# dft-global-typings Bump Advisor

## Overview

`@sgwshub/dft-global-typings` has no options schema and no generator/executor
schema — its real public contract is **behavioral**: for a given workspace
state, which projects get a `globalTypeNoop` NX target, and what `inputs` that
target carries. That output feeds `nx affected` directly. This skill applies
the package's documented behavior-as-contract rubric mechanically, so a
reviewer doesn't have to manually re-derive "does this change any affected
edge?" from scratch every time.

**Rubric source of truth:** `~/projects/context-docs/projects/FoundationSemver/decisions/dft-global-typings.md`
— mirrored on Confluence as "dft-global-typings Semver" (page ID `2453209114`,
re-scrapeable via `query-confluence` if stale).
Read the **Outcome** section of that file before applying the rubric below —
if that doc has been edited since this skill was last updated, the rubric
below may be stale; flag the discrepancy rather than silently trusting this
copy.

## Trigger

- A PR diff, changeset summary, or ticket description touches
  `packages/dft-global-typings/**` and a version-bump recommendation is needed
  before `package-release` runs.
- Reviewing/authoring a `dft-global-typings` release and unsure whether a
  change is patch, minor, or major.

**Out of scope:** this skill is advisory only — it does not modify source,
tag, publish, or apply the bump. That remains owned by the `package-release`
skill (`~/.claude/skills/package-release/SKILL.md`).

## When NOT to Use

- The change is to `@sgwshub/dft-get-project-target-state` itself — that
  package has its own decision doc / Confluence page (page ID `2453602320`)
  governing its semver, not this rubric. No
  `dft-get-project-target-state-bump-advisor` skill exists yet, so treat that
  package as out of scope rather than reusing this rubric for it.
- You need to know whether a migration script is required for correctness —
  that's a `pr-check-migration-needed` concern, not this skill's.
- You want the release to actually happen — hand this skill's recommended
  specifier to `package-release`.

## Input Contract

A change description for `dft-global-typings` — a PR diff, a summarized
changeset, or free text describing the behavioral change. No fixed schema;
read it for intent.

## Steps

### Apply the rubric

Apply these three tiers, in this exact priority order when multiple tiers
match (**MAJOR wins over MINOR wins over PATCH** — see Multi-Category
Changes below):

### MAJOR — any change that can alter the affected set or target contract
- Editing the include/exclude filter globs (`apps/**`, `common/**`,
  `tools/**`, `apps/examples/**`, any `e2e` path)
- Changing the `projectType.includes(globalTypeFile)` substring match rule,
  or its folder-vs-file granularity
- Renaming/reshaping the `globalTypeNoop` target — its name, `executor`, or
  `inputs` semantics
- Tightening error conditions that previously passed (a workspace that used
  to build now throws)
- Bumping the `@nx/devkit` **major** version
- Removing or changing the signature of exported `createNodesV2` /
  `createNodesInternal`

### MINOR — strictly additive coverage, never removes an existing affected edge
- Detecting an additional `tsconfig` variant, or an additional
  `common/types` file kind, **in addition to** what's covered today
- A new opt-in behavior that is off by default
- Existing projects' affected results are provably unchanged by the change

### PATCH — output stays byte-for-byte identical for all correct-case input
- Crash/robustness fixes (e.g. safer handling of a missing `tsconfig`) that
  don't change output for inputs that already worked correctly
- Error-message wording changes
- Internal refactors of `getNamedInputMap` / `getGlobalTypesUsed` that leave
  the emitted target set and `inputs` byte-for-byte identical
- Non-breaking `@nx/devkit` patch/minor bumps

### Multi-Category Changes

If a single change matches criteria in more than one tier, resolve to the
**highest** tier that matches — MAJOR beats MINOR beats PATCH. Example: a
change that is "additive" (MINOR-shaped) but also edits a filter glob
(MAJOR-shaped) is a MAJOR, because the glob edit alone is sufficient to alter
the affected set.

### When You Cannot Determine Intent

If the change description doesn't say whether the affected-graph output
changes — e.g. it names a file touched but not what changed in it, or is too
vague to map to any bullet above — **do not guess a tier**. Report:

> Cannot determine version-bump tier: the change description doesn't specify
> [the missing detail]. Please clarify [what's missing] before a
> recommendation can be made.

Guessing patch/minor by default is the exact failure mode this skill exists
to remove — treat an ambiguous input as a stop condition, not a tie-breaker.

### Output format

```
RECOMMENDED BUMP: <major | minor | patch | CANNOT DETERMINE>
JUSTIFICATION: <one line citing the specific rubric clause matched>
```

The justification must name the matched clause, not just the tier (e.g. "MAJOR
— changes the filter globs under apps/**" rather than just "MAJOR"). This
output is meant to be pasted directly into a PR description or release note.

See `references/examples.md` for worked examples (FOUND-1827 acceptance criteria).

## Red flags

| Mistake | Reality |
|---|---|
| "It only changed exported TS signatures, so it's mechanical semver." | The rubric explicitly rejects exported-signature-only semver for this package (Option 2 in the rubric doc) — there's no options schema, so almost nothing would ever be a MAJOR under that model, missing the real risk. |
| "It's additive, so it must be MINOR." | Additive-looking changes that also touch a filter glob, the `includes()` match rule, or the target shape are MAJOR — additivity alone doesn't override a MAJOR trigger (see Multi-Category Changes). |
| "The description is vague but it's probably a small change, call it patch." | Never default an ambiguous change to patch or minor. Report "cannot determine" per the rubric's explicit ambiguous-input requirement (FOUND-1827 Scenario 4). |
| "This also decides the actual release bump." | This skill is advisory only. The bump/tag/publish flow is owned by `package-release`; a human still confirms before it's applied. |

## Rubric Drift

This skill's rubric is a copy of the Outcome section in
`~/projects/context-docs/projects/FoundationSemver/decisions/dft-global-typings.md`. If that source
doc changes (e.g. the folder-vs-file granularity open question gets
resolved), update the MAJOR/MINOR/PATCH bullets above in lockstep — don't let
this skill's copy silently drift from the source of truth.

## Scope

Scoped to `@sgwshub/dft-global-typings` only.

## Exit criteria

- [ ] A bump tier (major/minor/patch) or an explicit CANNOT DETERMINE report was produced —
  never a silent guess.
- [ ] The justification names the specific matched rubric clause, not just the tier.
- [ ] No edits were made to `package.json`, `CHANGELOG.md`, or any generator source file.

## Provenance

Provenance: Hermes skill `learnings/skill-sharing` (corpus-wide porting authorship
attestation: ADR 0010).
Lineage: X-context-docs skills/dft-global-typings-bump-advisor@9d7143e (trimmed:
canonicalized two repo-relative rubric-source paths to the real
`~/projects/context-docs/...` path)
