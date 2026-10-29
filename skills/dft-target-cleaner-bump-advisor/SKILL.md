---
name: dft-target-cleaner-bump-advisor
description: >
  Use when a change to @sgwshub/dft-target-cleaner (a diff, PR description, or
  a summarized change to its matching logic or config schema) needs a
  version-bump recommendation before release. Triggers include "what bump
  does this need", "major or minor for dft-target-cleaner", "classify this
  dft-target-cleaner change", or preparing a conventional-commit / release for
  dft-target-cleaner. Advisory only — does not modify package.json or
  CHANGELOG; see package-release for the actual bump/publish flow.
model: sonnet
---

# dft-target-cleaner Bump Advisor

Classify a described change to `@sgwshub/dft-target-cleaner` as **major**,
**minor**, or **patch** by applying the package's documented behavior-first
rubric, and output the specifier plus a one-line justification tied to the
exact rubric clause matched.

**Advisory only.** This skill never edits `package.json`, `CHANGELOG.md`, or
`nx.json`. For the actual bump/tag/publish mechanics, use the `package-release`
skill (`~/.claude/skills/package-release/SKILL.md`).

## Trigger

Use when a diff, PR description, or free-text change summary for `@sgwshub/dft-target-cleaner` needs a version-bump recommendation before release.

## Rubric source of truth

Primary: `~/projects/context-docs/projects/FoundationSemver/decisions/dft-target-cleaner.md`
(Options table, Option 1 — the adopted policy). If that path doesn't resolve
(e.g. local `context-docs` main hasn't been pulled yet), fall back to the
Confluence mirror, "dft-target-cleaner Semver" (page ID `2453667846`). If
this skill's output ever looks wrong, re-read that doc first; the rubric
below is a faithful synthesis of that doc's Option 1 cell and its Action
Items (not a single verbatim quote — e.g. the `getProjectTargetState`
criterion, the `pathingGroupsToClean`-array-conversion MAJOR criterion, and
the `createNodesInternal` export-break criterion are all drawn from Action
Items / inferred from the "TypeScript surface" framing below, not quoted
verbatim from the Options table cell itself), and if the two ever disagree
the doc wins.

`@sgwshub/dft-target-cleaner` is an NX plugin that hooks into the project
graph via `createNodesV2` and overwrites matching project targets with the
`nx:noop` executor. Its public contract has **two faces**:

1. **The TypeScript surface** — the `createNodesV2` export (the plugin's
   consumption path, referenced from `nx.json`), the `TargetCleanerSchema`
   config shape (`pathsToIgnore`, `projectsToIgnore`, `projectGroupsToClean`,
   `pathingGroupsToClean`), and the test-only `createNodesInternal` export
   (lower blast radius since it isn't consumed via `nx.json`, but a
   removal/rename of it is still a MAJOR export break under Step 2).
2. **The behavioral contract** — *which* targets actually get no-op'd for a
   given config: `projectGroupsToClean` matches by `basename(projectRoot)`
   and takes precedence over pathing groups; `pathingGroupsToClean` matches
   by prefix/exact path comparison; a default `pathsToIgnore` of `['tools']`
   is always merged in; only projects that declare an NX target are
   considered.

The behavioral contract is **not encoded in the type signature** — a change
to matching semantics can be a functional break with zero schema change. That
is why this package is versioned by matching behavior, not just its
TypeScript surface.

## Steps

### Step 1 — Read the change

Take whatever the caller supplies: a git diff, a PR description, or a
free-form summary. If it's a raw diff, focus on:
- `src/index.ts` (precedence/matching orchestration),
  `src/utils/isProjectApartOfProjectGroup.ts`,
  `src/utils/pathingGroupUtilities.ts` (`ensurePathsAreValid`,
  `isProjectApartOfPathingGroup`) — this is the **target-determination
  path**, and "matching logic" as used throughout this skill (the PATCH
  caveat in Step 2, the Note-append rule in Step 4) refers specifically to
  changes here: anything that could alter *which* targets get no-op'd.
  `src/utils/cleanTarget.ts` is execution-only mechanics (how a matched
  target gets overwritten with `nx:noop`), not target-determination — a
  style/perf-only refactor there is PATCH per Step 2, and only counts as
  touching "matching logic" if it changes *which* targets get no-op'd (Step
  2 has no separate criterion for *how* the noop is applied, so a change
  confined to execution mechanics alone — e.g. swapping the executor used —
  is out of scope for this rubric's MAJOR/MINOR/PATCH criteria as currently
  written; treat it as PATCH unless it also changes which targets are
  selected).
- `src/types/target-cleaner-schema.ts` (`TargetCleanerSchema`, `ProjectTarget`,
  `PathingGroup`)
- Whether the change alters the **no-op'd-target output** for any existing,
  unchanged config, vs. only being reachable through a new opt-in key
- `@sgwshub/dft-get-project-target-state`'s return shape — it is a
  devDependency bundled into `dist`, but a breaking change to its output
  shape changes this plugin's matching behavior even with no TypeScript
  signature change in `dft-target-cleaner` itself

### Step 2 — Apply the rubric

Check criteria in this order — **MAJOR first**, then MINOR, then PATCH — and
stop at the first match. A change can satisfy multiple criteria; always
report the highest bump among all matches (see Step 3 for mixed changes
instead of silently picking the lower one).

### MAJOR — alters the matching outcome, or breaks the schema/export surface
- Any change that alters which projects/targets get no-op'd for an
  **unchanged config** — including changes to precedence order (project
  groups vs. pathing groups), `basename` vs. full-path matching, prefix vs.
  exact matching, the default `tools` ignore, or target-detection rules
- Any breaking change to `TargetCleanerSchema` or its exports (e.g. removing
  a key, changing a key's type — such as the planned array conversion of
  `pathingGroupsToClean`, or removing/renaming any of the package's public
  exports: `createNodesV2`, the test-only `createNodesInternal`, or
  `TargetCleanerSchema`'s exported types). `createNodesInternal` has a lower
  blast radius (it isn't consumed via `nx.json`), but a removal/rename of it
  is still a MAJOR export break.
- A breaking change to `getProjectTargetState`'s return shape (bundled
  dependency, but its output shape is part of this plugin's effective
  contract)

### MINOR — new opt-in surface, inert unless enabled
- A new optional config key or match mode that does not change behavior for
  any config that doesn't explicitly set it
- A new export

### PATCH — matching outcome unchanged for all existing configs
- Docs, perf, internal refactors
- Fixes that keep the matching outcome **identical** for all existing configs
- **Caveat, always surface in the output if the change touches matching
  logic (per Step 1's definition):** per the rubric, "behavioral changes
  require a golden-fixture test proving the before/after target diff before
  choosing the bump." If the described change touches matching logic at
  all — even a claimed patch/bugfix — and no before/after target-diff
  evidence is given, do not silently accept "patch"; flag the missing
  evidence (see Step 3). This caveat does not apply to changes confined to
  execution mechanics only (e.g. a pure `cleanTarget.ts` refactor) — those
  are plain PATCH per Step 1's carve-out, with no golden-fixture note
  needed.

### Step 3 — Handle ambiguous, mixed, or evidence-free changes

If the described change (a) touches both an internal-only path and the
matching outcome/schema, (b) you cannot tell from the input whether the
no-op'd-target set changes for any existing config, or (c) claims to be a
behavioral fix/patch with **no golden-fixture before/after target diff**
supplied, do not silently pick the lower bump. Report:

```
AMBIGUOUS — cannot classify with confidence.
Reason: <what's mixed, missing, or unverified>
Highest-bump interpretation: <major|minor|patch>, because <criterion>
Lowest-bump interpretation: <major|minor|patch>, because <criterion>
Recommend: request the golden-fixture before/after no-op'd-target diff (or
the specific config/matching-path affected) before finalizing the release
bump.
```

### Step 4 — Output format

For unambiguous classifications, output exactly:

```
Recommended bump: <major|minor|patch>
Justification: <one line, name the specific matching rule/export/schema key
changed and quote or closely paraphrase the matched rubric clause>
Rubric source: ~/projects/context-docs/projects/FoundationSemver/decisions/dft-target-cleaner.md
```

If the change touches matching logic at all (per Step 1's definition —
i.e. it could alter *which* targets get no-op'd; this excludes changes
confined to execution mechanics only, such as a pure `cleanTarget.ts`
refactor), append this line (per the rubric's golden-fixture requirement)
regardless of which tier was chosen:

```
Note: behavioral changes require a golden-fixture test proving the
before/after no-op'd-target diff before this bump is finalized.
```

If the recommended bump is **minor** and the package is still on a `0.x`
version — check the current version in `package.json` at execution time,
don't rely on any version number written here (it will go stale) — always
append this line too, since a `0.y` MINOR is not guaranteed non-breaking
under semver's own `0.y` convention:

```
Note: this package is pre-1.0 — per semver 0.y convention, a MINOR bump can
still carry breaking changes until a deliberate 1.0.0 is declared. Confirm
this MINOR is genuinely additive/inert before relying on it as non-breaking.
```

See `references/examples.md` for worked examples and validation against real history.

## Red flags

| Mistake | Fix |
|---|---|
| Classifying a matching-logic bugfix as PATCH just because it was called a "fix" | If a fix changes the no-op'd-target set for any existing config, it is MAJOR under this rubric regardless of the conventional-commit type used (`fix:` at face value is not sufficient evidence of PATCH — see Step 2's MAJOR criteria) |
| Accepting "patch" for a behavioral change with no fixture evidence | Flag it via Step 3 (AMBIGUOUS) instead — the rubric requires a golden-fixture before/after diff before finalizing any behavioral-change bump |
| Treating a new inert config key as MAJOR because it changes the schema | Only a *breaking* schema/export change is MAJOR; a new opt-in key that's inert unless enabled is MINOR |
| Assuming 0.x means "MINOR can't break anything" | The rubric doc notes MINOR may still carry breaking changes per semver 0.y convention until a deliberate 1.0.0 is planned — surface this caveat, don't silently assume stable-semver guarantees |
| Assuming this skill also performs the release | It does not — it is advisory only; hand the recommended specifier to `package-release` for the actual bump/publish |

## Scope

Scoped to `@sgwshub/dft-target-cleaner` only, per FOUND-1837. Generalizing to
read any package's decision doc under
`projects/FoundationSemver/decisions/` is a candidate follow-up, not covered
here.

## Exit criteria

- [ ] A bump tier was produced, or an explicit AMBIGUOUS report with both interpretations —
  never a silent guess.
- [ ] The justification names the specific changed surface and quotes or closely
  paraphrases the matched rubric criterion.
- [ ] No edits were made to `package.json`, `CHANGELOG.md`, or `nx.json`.

## Provenance

Provenance: Hermes skill `learnings/skill-sharing` (corpus-wide porting authorship
attestation: ADR 0010).
Lineage: X-context-docs skills/dft-target-cleaner-bump-advisor@9d7143e
