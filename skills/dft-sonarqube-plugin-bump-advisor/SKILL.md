---
name: dft-sonarqube-plugin-bump-advisor
description: >
  Use when classifying a change to @sgwshub/dft-sonarqube-plugin (a diff, PR
  description, commit message, or free-text change summary) against its
  documented contract-based semver rubric to recommend a major/minor/patch
  version bump. Triggers include "what version bump does this need", "is this
  a breaking change to dft-sonarqube-plugin", "classify this dft-sonarqube-plugin
  change", or any request to reason about the dft-sonarqube-executor
  peer-dependency bump alongside a dft-sonarqube-plugin change. Advisory only —
  does not write package.json or version files.
---

# dft-sonarqube-plugin Bump Advisor

## Overview

`@sgwshub/dft-sonarqube-plugin`'s public contract is **the inferred NX target
graph it emits into a consumer's `nx.json`** — target names, executor
references, `dependsOn` edges, pass-through options, and ignore-path
defaults — not its version relationship to its peer, `dft-sonarqube-executor`.
This skill applies that documented rubric to a change description and outputs
one recommended bump level with a one-line justification citing the rubric
criterion. It replaces ad-hoc/lockstep guessing (historically 5 of 6 releases
just mirrored the executor's version bump — see Background) with a
repeatable, auditable classification.

Source of truth for the rubric: `~/projects/context-docs/projects/FoundationSemver/decisions/dft-sonarqube-plugin.md`
in context-docs. If that doc is missing or unreachable, **fail clearly** —
say so and stop. Do not guess a bump level from general semver conventions;
this package's rubric is contract-based, not diff-size-based.

## Trigger

Use when a diff, PR description, commit message, or free-text change summary for
`@sgwshub/dft-sonarqube-plugin` needs a version-bump recommendation before release.

## When NOT to use

- Bumping any other de-foundations package — this rubric is specific to
  `dft-sonarqube-plugin`'s target-graph contract.
- Actually writing the version bump — hand the recommendation to the
  `package-release` skill; this skill only advises.

## Background: why the peer pin matters

The plugin's peer dependency on `@sgwshub/dft-sonarqube-executor` has **not
stayed pinned to an exact version** — per this file's own Validation section
below, release 1.1.0 already moved it from an exact pin (`1.0.1`) to a caret
range (`^1.1.0`). **Before asserting the peer pin's current shape in a real
recommendation, re-check `packages/dft-sonarqube-plugin/package.json`'s
actual `peerDependencies` entry** — do not assume this doc's snapshot, or
either pin shape described below, is still accurate.

Historically, while the pin was an exact version, *every* executor release —
patch, minor, or major — forced an edit to this plugin's `package.json`.
That edit was **not** an automatic trigger for a matching bump here. You must
always classify the *underlying executor change* against the same
three-tier rubric, asking: does it change what this plugin's consumers
observe or must do? If the pin is currently a caret range instead, only an
executor release that falls outside that range forces a hand re-pin at
all — compatible releases resolve automatically with no plugin edit.

- Executor change is internal-only (refactor, perf, dependency bump, no
  change to the `:sonarqube` sub-executor name or option semantics) →
  patch/minor here, regardless of the executor's own bump level.
- Executor change renames the sub-executor, changes option meaning, or drops
  an option this plugin forwards → major here, because the plugin's emitted
  graph now behaves differently for consumers.

A peer-executor **major** does **not** automatically force a **major** here.
The peer version delta tells you whether an edit is needed (always, if the
pin is exact; only outside-range, if the pin is a caret range); it never
tells you the bump level on its own.

## Steps

### Apply the rubric

Apply tiers in this order — check MAJOR first, then MINOR, then PATCH (a
change can satisfy multiple descriptions; the highest-impact tier wins):

| Tier | Criterion (quoted from the decision doc) | Look for in the change description |
|------|---|---|
| **MAJOR** | "Any change that alters what an existing consumer observes or must do" | Renaming/removing an emitted target (`sonarqube`, `sonar-lint`, `clean:lint`); changing the executor reference string; changing `dependsOn` edges; changing default ignore paths so a different set of projects gets targets; removing/renaming a pass-through option; changing package.json-vs-project.json conflict behavior (e.g. throw → warn); raising the peer to a range whose new major changes behavior the plugin surfaces (renamed sub-executor, changed option semantics, dropped option) |
| **MINOR** | "Additive, backward-compatible surface growth" | Adding a new inferred target; adding new pass-through options; adding new ignore-path configuration; adding an opt-in behavior that defaults to today's output; raising the peer to a new minor that exposes new optional capability the plugin now forwards |
| **PATCH** | "Bug fixes that preserve the emitted target graph exactly" | Correcting ignore-path matching; fixing package.json-vs-project.json conflict detection; tightening the `hasNxTarget` check; dependency-only lockfile refreshes that don't change the required peer range; widening the peer range within the same major (e.g. `^1.0.0`→`^1.1.0`) **iff no new option is required** |

If the description is too sparse to tell whether an executor change is
internal-only or consumer-observable, do not force a guess — flag it as
ambiguous and name the missing information needed to classify it (see Red
flags below).

### Output format

```
BUMP: <major|minor|patch|ambiguous>
JUSTIFICATION: <one line citing the rubric tier and the specific criterion, e.g.
  "MINOR — additive pass-through option added; emitted target graph unchanged.">
PEER-PIN NOTE: <only if the change touches the dft-sonarqube-executor peer version —
  state the peer pin's current shape (re-check package.json rather than assuming
  the last-known shape still holds), whether that shape forces this edit
  unconditionally (exact pin) or only when the release falls outside the pinned
  range (caret range), and that the bump level was still driven by the underlying
  executor change's consumer-observable impact, not by the pin shape itself.>
MISSING INFO: <only when BUMP is ambiguous — name exactly what's missing, e.g.
  "need to know whether the executor's :sonarqube sub-executor name or option
  semantics changed.">
```

Omit the `PEER-PIN NOTE` line entirely when the change doesn't touch the peer
version. When `BUMP: ambiguous`, omit `JUSTIFICATION` and instead emit
`MISSING INFO`; still include `PEER-PIN NOTE` if the ambiguous change touches
the peer version, since the pin-shape fact should be re-checked and reported
regardless of whether the underlying executor impact is known.

See `references/examples.md` for worked examples and validation against real history.


Cross-checked against `packages/dft-sonarqube-plugin/CHANGELOG.md`:

- **1.1.0** (two bullets under the CHANGELOG's `### Fixed` header — an
  ignore-path/watch-mode fix and a `.scannerwork` exclusion, implying
  `fix:`-tagged commits per this project's conventional-commit release
  mechanics — plus a peer bump from exact `1.0.1` to `^1.1.0` "to pick up
  SonarQube server-existence check") shipped as **minor**. Under this
  rubric: the two fixes alone would be patch-level, but the peer bump
  description ("server-existence check") reads as new executor-side
  capability being forwarded rather than a pure internal refactor —
  consistent with a MINOR classification per the peer-major handling test,
  matching what actually shipped.
- **1.0.0** (CHANGELOG: "No code changes required," described as a stability
  signal) would **not** be re-derived as major under this rubric — no
  rubric criterion fired (no target/executor-reference/dependsOn/option
  change). This is the documented case of a major that was "declared, not
  earned"; flag such requests as a policy decision outside the rubric rather
  than reclassifying history.

## Red flags

- **"The executor bumped its major, so this must be major too"** — false by
  default, regardless of the peer pin's current shape. Ask whether the
  executor change is internal-only or renames/changes an option this plugin
  forwards.
- **Change description doesn't say whether an executor change is
  internal-only** — do not assume either direction. Output:
  `BUMP: ambiguous` and name exactly what's missing (e.g. "need to know
  whether the executor's `:sonarqube` sub-executor name or option semantics
  changed").
- **"It's just a dependency bump, so it's always a patch"** — only true when
  no new option is required and the peer range widens within the same major.
  A dependency bump that adds forwarded capability is minor; one that changes
  forwarded option semantics is major.
- **Rubric doc unreachable** — see Overview: fail clearly rather than falling
  back to generic conventional-commit semver.

## Related skills

- `package-release` — the release flow this advisor's recommendation feeds
  into (bump, tag, publish mechanics). This skill only recommends the bump.
- `dft-sonarqube-executor-bump-advisor` — the companion advisor for
  `@sgwshub/dft-sonarqube-executor`, the peer package this plugin depends on
  (see Background above for the pin's current shape); use that skill to
  classify an executor-side change, not this one.

## Exit criteria

- [ ] A bump tier was produced, or `BUMP: ambiguous` with `MISSING INFO` naming the gap —
  never a silent guess.
- [ ] A change touching the executor peer version includes a `PEER-PIN NOTE` that re-checks
  the pin's current shape rather than assuming a prior snapshot.
- [ ] No edits were made to `package.json`, `CHANGELOG.md`, or any version/tag file.

## Provenance

Provenance: Hermes skill `learnings/skill-sharing` (corpus-wide porting authorship
attestation: ADR 0010).
Lineage: X-context-docs skills/dft-sonarqube-plugin-bump-advisor@9d7143e (trimmed:
canonicalized a repo-relative rubric-source path to the real
`~/projects/context-docs/...` path)
