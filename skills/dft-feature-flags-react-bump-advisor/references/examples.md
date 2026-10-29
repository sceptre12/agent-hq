## Worked examples (from FOUND-1836 acceptance criteria)

**Scenario 1 — patch, bugfix with no contract change**
> Given: "fix: SSR useEffect timing fix in FlaggedComponent, no prop or
> return shape changes"

```
Recommended bump: patch
Justification: Bugfix with no change to exported prop, return shape, or
behavioural contracts — matches the PATCH criterion for SSR/useEffect
timing fixes.
Rubric source: Confluence "dft-feature-flags-react Semver" (page ID 2453700612)
```

**Scenario 2 — minor, purely additive surface**
> Given: "feat: add new optional evaluationTimeoutMs prop to
> FeatureFlagProvider, existing usage unchanged"

```
Recommended bump: minor
Justification: Purely additive surface — new optional prop, existing usage
unchanged — matches the MINOR criterion for a new optional
FeatureFlagProvider config field.
Rubric source: Confluence "dft-feature-flags-react Semver" (page ID 2453700612)
```

**Scenario 3 — minor via verified Split major**
> Given: "chore: bump @splitsoftware/splitio from 11.x to 12.0.0 (major),
> verified IBrowserSDK shape, 'on'/'control' convention, and provider prop
> contract are unchanged"

```
Recommended bump: minor
Justification: Split SDK major bump verified not to change IBrowserSDK,
treatment convention, or provider prop contract — matches the MINOR
escalation-cleared criterion for a verified Split major.
Rubric source: Confluence "dft-feature-flags-react Semver" (page ID 2453700612)
```

**Scenario 4 — major, contract break**
> Given: "feat!: remove getGlobalSplitFactory export and change
> useFeatureFlag return shape"

```
Recommended bump: major
Justification: Contract break — removing/renaming an exported symbol
(getGlobalSplitFactory) and changing useFeatureFlag's return shape — matches
the MAJOR criterion for exported-symbol removal and return-shape change.
Rubric source: Confluence "dft-feature-flags-react Semver" (page ID 2453700612)
```

**Scenario 5 — major via unverified/confirmed-breaking Split major**
> Given: "chore: bump @splitsoftware/splitio to 12.0.0 (major), IBrowserSDK
> shape confirmed changed"

```
Recommended bump: major
Justification: Split SDK major bump that reshapes the leaked
SplitIO.IBrowserSDK type — matches the MAJOR criterion for a Split major
that alters the leaked type surface.
Rubric source: Confluence "dft-feature-flags-react Semver" (page ID 2453700612)
```

## Validation against real history

Cross-checked against `packages/dft-feature-flags-react/CHANGELOG.md` and
git tag history:

- **v1.0.0 → v1.0.1** (commit `817b5f08`, "fix: FOUND-1098 fix
  FlaggedComponent children default") — actual bump **patch** — matches the
  PATCH criterion (bugfix, no exported prop/return-shape change).
- **v1.0.1 → v1.0.2** (commit `17fbc118`, "chore: PCWA-10606 bump splitio to
  11.11.2 and splitio-react to 2.6.1") — actual bump **patch** — matches the
  PATCH criterion (Split SDK patch/minor bump, logged as `chore`; not a
  Split major, so the escalation rule does not apply).
- **v0.0.1-0 → v1.0.0** (commit `79c2fe69`, "feat: FOUND-498: add
  dft-feature-flags-react package") — initial release baseline; this
  predates the package having any prior public surface to compare against,
  so the rubric's break/additive/bugfix criteria don't apply verbatim — an
  initial release is its own category (major/initial baseline), not derived
  from the PATCH/MINOR/MAJOR diff rubric above.

