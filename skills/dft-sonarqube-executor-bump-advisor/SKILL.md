---
name: dft-sonarqube-executor-bump-advisor
description: >
  Use when classifying a change to @sgwshub/dft-sonarqube-executor (a diff, PR
  description, commit message, or free-text change summary) against its
  documented behavior-inclusive semver rubric to recommend a major/minor/patch
  version bump. Triggers include "what version bump does this need", "is this
  a breaking change to dft-sonarqube-executor", "classify this
  dft-sonarqube-executor change", "does this change what scans fail", or any
  request to reason about the dft-sonarqube-plugin peer-pin coordination
  alongside a dft-sonarqube-executor change. Advisory only — does not write
  package.json, CHANGELOG.md, or version/tag files.
---

# dft-sonarqube-executor Bump Advisor

## Overview

`@sgwshub/dft-sonarqube-executor`'s public contract is **its options schema
plus its pass/fail (gate/exit-code) contract** — not just its JSON schema
shape. It hard-codes non-overridable defaults (`sonar.qualitygate.wait`,
`sonar.projectKey`, sources/tests roots, report paths, default `timeout`) and
default test inclusion/exclusion globs that determine whether a scan returns
`success:false` and fails CI. Because CI pass/fail is derived from these
baked-in defaults, **a behavioral change that alters what counts as a failing
scan is breaking even when the schema is untouched.** Generic "schema-only"
semver gets this package wrong — considered in isolation, it would have
called the historical 0.2.0 exclusion-pattern change (shipped minor, arguably
major) an invisible patch.

This skill applies the package's documented rubric — behavior-inclusive
semver — to a change description and outputs one recommended bump level
(`major`/`minor`/`patch`) with a one-line justification citing the exact
rubric clause matched. It replaces manual, ad-hoc judgment against the
decisions doc during PR review with a repeatable, auditable classification.

**Freshness caveat:** the decision doc and Confluence page are a snapshot as
of their last review, not a live read of the package's source. Before
treating any *specific value* cited below (e.g. a peer-pin range, a default
timeout number) as current fact, spot-check it against
`packages/dft-sonarqube-executor` and `packages/dft-sonarqube-plugin` in the
de-foundations repo — these packages release frequently and specific values
can drift out from under the doc. The *rubric tiers themselves* (what counts
as major/minor/patch) are the durable part of this skill; the illustrative
numbers are not.

Source of truth: Confluence page **"dft-sonarqube-executor Semver"** (page ID
`2453209098`) and `~/projects/context-docs/projects/FoundationSemver/decisions/dft-sonarqube-executor.md`
(Outcome section). The rubric below is a verbatim
transcription of that doc's Options/Outcome sections, not a paraphrase — if
the two ever disagree, the doc wins. **If that doc/page is missing or
unreachable, fail clearly** — say so and stop. Do not fall back to generic
semver or conventional-commit conventions; this package's rubric is
behavior-based, not diff-size-based or type-based.

## Trigger

Use when a diff, PR description, commit message, or free-text change summary for
`@sgwshub/dft-sonarqube-executor` needs a version-bump recommendation before release.

## When NOT to use

- Bumping any other de-foundations package — this rubric is specific to
  `dft-sonarqube-executor`'s options-schema-plus-gate-contract surface. For
  `@sgwshub/dft-sonarqube-plugin` itself, use the
  `dft-sonarqube-plugin-bump-advisor` skill instead.
- Actually writing the version bump, tag, or publish — hand the
  recommendation to the `package-release` skill; this skill only advises.

## Peer-dependency note: the plugin's peer pin on this package

`@sgwshub/dft-sonarqube-plugin` declares this package as a **required peer
dependency**. Per the decision doc (as of its last review), that pin was an
**exact version** (e.g. `"1.0.1"`, not a caret range) — but peer-pin ranges
change across releases, sometimes independent of stability-guarantee
adoption (the plugin's own Validation-against-real-history section
documents the pin already moving to a caret range at least once, for
reasons unrelated to that guarantee; the doc's Action Items also separately
recommend relaxing it once the guarantee is adopted). **Before asserting
exact-pin behavior in a real recommendation, re-check the plugin's current
`peerDependencies` entry** in
`packages/dft-sonarqube-plugin/package.json` — do not assume the doc's
snapshot is still accurate.

Because NX's `version.generatorOptions.updateDependents` is set to `"never"`,
the plugin is **not** auto-bumped when this executor releases. If the peer
pin is still an exact version, every executor release forces a hand re-pin of
the plugin's `peerDependencies` entry in the same release wave, or peer
resolution breaks for every consumer. If the pin has since moved to a caret
range, only an executor release outside that range forces a hand re-pin —
compatible releases resolve automatically.

This coordination need (whatever its current shape) is not what determines
the bump level here — the bump level is driven purely by whether the change
alters the options schema or the pass/fail contract, per the rubric below.
**A major-bump recommendation carries extra weight**: it means the change is
also very likely to land outside whatever range the plugin currently
tolerates, so surface the coordination need explicitly in the output (see
PEER-PIN NOTE below) whenever the recommended bump is major, phrased against
the peer pin's *current* shape rather than assumed to be an exact pin.

## Steps

### Apply the rubric

Apply tiers in this order — check MAJOR first, then MINOR, then PATCH (a
change can satisfy multiple descriptions; the highest-impact tier wins):

| Tier | Criterion (quoted from the decision doc's Outcome) | Look for in the change description |
|------|---|---|
| **MAJOR** | "remove/rename a schema property, tighten a type, make an option required, remove a non-overridable default a consumer relied on, or make the gate stricter so a scan that passed before now fails" | Removing/renaming one of the 9 schema properties (`projectsToIgnore`, `projectPathsToIgnore`, `overrideDefaultTestInclusions`, `overrideDefaultTestExclusions`, `addTestInclusions`, `addTestExclusions`, `timeout`, `verbose`, `extraProperties`); tightening a property's type; adding a `required` entry; tightening default test-exclusion globs so more files enter scope; changing the forced `sonar.qualitygate.wait` default; changing the non-overridable default `timeout` value (check the current default in `sonarqube.ts` — it has changed across releases, e.g. from milliseconds to seconds) in a way that makes previously-passing scans time out/fail; changing non-overridable `sonar.projectKey`/sources/tests-root/report-path defaults in a way that changes scan outcomes |
| **MINOR** | "add a new optional property, add opt-in behavior, loosen exclusions in a way that can only reduce failures" | Adding a new optional schema property; adding a new opt-in flag/behavior that defaults to today's output; loosening default test-exclusion globs so fewer files enter scope (can only reduce failures, never introduce new ones) |
| **PATCH** | "internal fixes, logging, dependency bumps that don't change scan outcomes" | Bug fixes, logging changes, refactors, or dependency bumps where the schema is unchanged AND no non-overridable default or gate behavior changes — i.e., the set of scans that pass/fail is provably identical before and after |

If the description is too sparse to tell whether a behavioral change affects
scan outcomes, do not force a guess — flag it as ambiguous and name the
missing information needed to classify it (see Red flags below).

### Output format

```
BUMP: <major|minor|patch>
JUSTIFICATION: <one line citing the rubric tier and the specific criterion, e.g.
  "MAJOR — tighter default test exclusions bring more files into scope, making a
  previously-passing scan fail per the rubric's Major clause.">
PEER-PIN NOTE: <only when BUMP is major — dft-sonarqube-plugin is not auto-bumped
  (updateDependents: "never"); re-check the plugin's current peerDependencies entry
  for this package and coordinate a re-pin in the same release wave if this major
  falls outside the range the plugin currently tolerates.>
```

Omit the `PEER-PIN NOTE` line entirely when the recommended bump is minor or
patch. When the verdict is ambiguous, use this shape instead of the
major/minor/patch template above:

```
BUMP: ambiguous
JUSTIFICATION: <state exactly what's missing from the change description that
  prevents classification>
PEER-PIN NOTE: <only include if a major verdict is one of the plausible outcomes —
  phrase as "if this resolves to major, re-check the plugin's current peer-pin
  range before assuming coordination is needed.">
```

See `references/examples.md` for worked examples and validation against real history.

## Red flags

- **"The schema didn't change, so it's not breaking"** — false by default
  under behavior-inclusive semver. Always check non-overridable defaults and
  gate behavior even when the schema is untouched.
- **"The changelog/PR says no breaking changes"** — not evidence on its own.
  The decision doc explicitly calls out 1.0.0's "no breaking changes" note
  as a case that needs independent scan-outcome verification, not
  acceptance at face value.
- **Change description doesn't say whether exclusions got tighter or
  looser** — do not assume either direction. Output `BUMP: ambiguous` and
  name exactly what's missing (e.g. "need to know whether the glob change
  narrows or widens the set of files brought into scan scope").
- **"It's just a dependency bump, so it's always a patch"** — only true if
  the dependency bump cannot change scan outcomes (e.g. a test-only or
  build-tooling dependency). A dependency bump that changes `@sonar/scan`'s
  own default gate behavior is not automatically patch.
- **Rubric doc/page unreachable** — do not fall back to generic
  conventional-commit semver. Report the doc is missing and stop.

## Related skills

- `package-release` — the release flow this advisor's recommendation feeds
  into (bump, tag, publish mechanics). This skill only recommends the bump.
- `dft-sonarqube-plugin-bump-advisor` — the companion advisor for
  `@sgwshub/dft-sonarqube-plugin`, the required-peer consumer of this
  package (see Peer-dependency note above for the pin's current shape); use
  that skill to classify a plugin-side change, not this one.

## Exit criteria

- [ ] A bump tier was produced, or an explicit `BUMP: ambiguous` with the missing fact named
  — never a silent guess.
- [ ] A major bump states the `PEER-PIN NOTE` (re-check `dft-sonarqube-plugin`'s current
  `peerDependencies` entry); omitted entirely for minor/patch.
- [ ] No edits were made to `package.json`, `CHANGELOG.md`, or any version/tag file.

## Provenance

Provenance: Hermes skill `learnings/skill-sharing` (corpus-wide porting authorship
attestation: ADR 0010).
Lineage: X-context-docs skills/dft-sonarqube-executor-bump-advisor@9d7143e (trimmed:
canonicalized a repo-relative rubric-source path to the real
`~/projects/context-docs/...` path)
