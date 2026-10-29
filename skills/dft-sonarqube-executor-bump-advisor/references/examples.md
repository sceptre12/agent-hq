## Worked examples

**Scenario 1 — Major: gate/behavior change that alters scan outcomes**
> Change description: "Tightened the default test-exclusion glob in
> `utils/constants.ts` so fewer files are excluded from analysis; a project
> that previously had a passing scan under the old default now returns
> `success:false` because previously-ignored files now trip the quality
> gate. No schema property was added, removed, or renamed."

```
BUMP: major
JUSTIFICATION: MAJOR — tighter default test exclusions bring more files into
  scope, making a scan that passed before now fail, per the rubric's Major
  clause (gate stricter with unchanged schema).
PEER-PIN NOTE: dft-sonarqube-plugin is not auto-bumped (updateDependents:
  "never"); re-check the plugin's current peerDependencies entry for this
  package and coordinate a re-pin in the same release wave if this major
  falls outside the range the plugin currently tolerates.
```

**Scenario 2 — Minor: additive, opt-in change**
> Change description: "Added a new optional `failOnNewIssuesOnly` schema
> property; when unset, behavior is identical to today's default gate
> evaluation. No existing scan's pass/fail outcome changes."

```
BUMP: minor
JUSTIFICATION: MINOR — new optional schema property that is opt-in and
  cannot change any existing scan's pass/fail outcome, per the rubric's
  Minor clause.
```

**Scenario 3 — Patch: outcome-neutral fix**
> Change description: "Refactored the internal logging around
> `sonar.qualitygate.wait` polling and bumped an internal test-only
> dependency. No schema property, non-overridable default, or gate behavior
> changed; the set of scans that pass/fail is identical before and after."

```
BUMP: patch
JUSTIFICATION: PATCH — internal logging refactor and dependency bump with no
  change to scan outcomes, per the rubric's Patch clause.
```

## Validation against real history

Cross-checked against `packages/dft-sonarqube-executor/CHANGELOG.md` and the
decision doc's own History section, per FOUND-1844's validation subtask:

- **0.2.0** (2025-12-30, FOUND-564) — "refined default test exclusion
  patterns to reduce false positives in source/test file detection," shipped
  as **minor**, no schema change. Under this rubric: if the refinement made
  the exclusion **tighter** (more files newly in scope, previously-passing
  scans could now fail), this is a **MAJOR** divergence from what shipped —
  this is exactly the under-classification case the decision doc's History
  section calls out by name. If the refinement instead **loosened**
  exclusions (fewer false positives = fewer files wrongly failing), it is
  correctly **MINOR** per the rubric's "loosen exclusions... reduce
  failures" clause. The change description alone doesn't disambiguate
  direction — flag as ambiguous and request the actual glob diff before
  asserting which of these two outcomes applies.
- **1.0.0** (2026-03-31, FOUND-1154) — PR/branch-mode analysis refactoring,
  changelog claims "no breaking changes." Under this rubric: whether this is
  re-derived as major depends entirely on whether the refactor changed which
  scans pass/fail (e.g. different default branch/PR comparison base
  changing gate outcomes) — the decision doc names this as an ambiguous case
  precisely because a "no breaking changes" note doesn't itself prove no
  outcome change. Do not accept the changelog's own self-assessment as
  proof; without a scan-outcome-level diff this cannot be confidently
  classified below MAJOR.
- **1.2.0** (2026-07-13, FOUND-1228) — recognizing `packages/` as a valid
  base directory in `getBaseProjectDir` (shipped minor) plus an
  `includes()`→`startsWith()` matching fix bundled in the same release.
  Under this rubric: `getBaseProjectDir` resolves the non-overridable
  `sonar.projectKey` default, so this does touch a MAJOR-listed surface —
  but the MAJOR clause fires on a non-overridable-default change only when
  it makes a *previously-passing* scan fail, not on any touch to that
  surface. Recognizing a new base directory only turns projects that
  previously fell outside recognition (and thus errored or were skipped)
  into correctly-scanned ones; it cannot flip an existing passing scan to
  failing. That is additive, opt-in-by-default capability growth (existing
  projects outside `packages/` are unaffected) → **MINOR**, matching what
  shipped. The `includes()`→`startsWith()` fix, considered in isolation,
  only changes outcomes if the looser `includes()` matching was previously
  catching extra paths that `startsWith()` now excludes (or vice versa) —
  if it is a pure correctness fix with no change to which projects get
  scanned, it is **PATCH** in isolation; bundling it into the same minor
  release as the additive change does not itself require re-classifying the
  whole release, since MINOR already dominates a PATCH-level fix in the
  same wave.

