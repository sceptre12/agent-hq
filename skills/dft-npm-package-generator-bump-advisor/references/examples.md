## Worked examples

**Scenario 1 — MAJOR (breaking schema/output-shape change)**

> Change description: "Dropped the `exports` key from the `package.json` template scaffolded
> for `node`-type packages, and made `generator-version.json` fail its own
> `additionalProperties: false` schema by adding an unlisted field."

```
BUMP: major
JUSTIFICATION: MAJOR — drops a key (`exports`) from the emitted package.json and breaks
  generator-version.json's own additionalProperties: false schema, both explicit MAJOR
  output-shape criteria.
SCOPE: future scaffolds only — no migrations.json exists for this package; packages already
  created with the old shape are unaffected but new ones inherit broken release config until
  fixed.
CONFIDENCE: high
```

**Scenario 2 — MINOR (additive schema/output-shape change)**

> Change description: "Added a new optional `capabilities: 'both'` enum value (schema already
> allowed `executors`/`generators`) plus a new optional `initGit` schema flag; when set, adds an
> additional `.gitattributes` template file to the scaffold. Also bumped `@nx/devkit`/`@nx/js`
> pins from `20.3.3` to `20.4.0` (same major line)."

```
BUMP: minor
JUSTIFICATION: MINOR — new optional schema flag plus an additive scaffold file, and an
  additive NX pin bump within the same major line; existing scaffolded packages remain valid
  and no existing option/output contract changes.
SCOPE: n/a (no MAJOR)
CONFIDENCE: high
```

**Scenario 3 — PATCH (bug fix restoring intended output) / NO BUMP (docs/chore)**

> Change description: "Fixed the name-collision guard in `generator.ts` so it correctly rejects
> a pre-existing package directory instead of silently overwriting it — no schema or template
> change. Separately, corrected a typo in README.md."

```
BUMP: patch
JUSTIFICATION: PATCH — bug fix restoring intended scaffolding behavior (name-collision guard)
  with no change to the documented option schema or output contract.
SCOPE: n/a (no MAJOR)
CONFIDENCE: high

--- README typo, classified separately ---
BUMP: none
JUSTIFICATION: NO BUMP — docs-only change with no observable output or option change
  (chore:/docs: per conventional-commits config).
SCOPE: n/a (no MAJOR)
CONFIDENCE: high
```

**Scenario 4 — Mixed surfaces (highest tier wins)**

> Change description: "Added a new optional `initGit` schema flag (additive, MINOR-tier) in the
> same PR that also drops the `types` key from the `nx-plugin` package.json template (MAJOR-tier
> output-shape break)."

```
BUMP: major
JUSTIFICATION: MAJOR — the diff mixes a MINOR-tier additive schema flag with a MAJOR-tier
  output-shape break (dropped `types` key); per Decision procedure step 2, the bump is the
  highest tier that fired, not an average or the first one classified.
SCOPE: future scaffolds only — no migrations.json exists for this package.
CONFIDENCE: high
```

## Validated against historical releases

| Version | Change | Rubric verdict | Matches actual release |
|---|---|---|---|
| `0.1.0` | Initial ECOP-833 release (commit `6fc9b05d`, tagged `3291fe4c`, 2025-10-09) — first publish of the `make-publishable` generator, an additive baseline | **MINOR** (initial feature release) | Yes — released as `0.1.0` |
| `1.0.0` | FOUND-1018 (`b9e382e1`, standardizing `generator-version.json`) landed on `main` seven months later but was **never independently released** — it shipped bundled inside FOUND-1190's `create` generator rewrite (`f91a8993`, PR #195), which removed the `make-publishable` generator, executor, and `makePackagePublishable` utility entirely | **MAJOR** | Yes — released as `1.0.0`, explicitly documented as "Breaking Change" in CHANGELOG.md. Lesson: a MINOR-tier change (FOUND-1018) bundled into the same release as a MAJOR-tier change (FOUND-1190) still ships as MAJOR — the highest tier in the release wins, same rule as Decision procedure step 2 for a single diff. |
| — | Pinned de-foundations third-party deps to exact lockfile-resolved versions (FOUND-1066, PR #213, commit `9c3e590d`) — touches this package's own `package.json` `dependencies` (`enquirer`, `tslib`), but is repo-wide lockfile-declaration pinning, not a change to scaffolded option/output contract | **N/A — no bump** | Yes — not a version bump for this package; scoped to internal dependency pinning, not the generator's contract |
