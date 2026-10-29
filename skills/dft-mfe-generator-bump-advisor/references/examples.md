## Worked examples (from FOUND-1835 acceptance criteria)

### Example 1 — Major: breaking scaffold output, no migration

Change: rewrites `module-federation.config.ts.template`'s `exposes` shape so
already-generated hosts/remotes fail to resolve `./Module` at runtime. No
`migrations.json` entry added.

```
BUMP: major
Justification: Breaking change to scaffolded MF config with no version-gated migration — "breaking output without an automatic migration is major".
Manual review flag: none
```

### Example 2 — Minor: migration-covered output change

Change: widens the `@sgwshub/dft-rspack-config` pin from `0.7.0` to `^1.0.0`
in `REQUIRED_ROOT_DEV_DEPENDENCIES`, ships `migrate-2-5-0` to bring existing
consumers' root `package.json` up to the new range (idempotent, skips
versions that already satisfy it).

```
BUMP: minor
Justification: Scaffold-output change (dependency pin) ships with an idempotent, version-gated migration — "migration-covered/additive output is minor".
Manual review flag: none
```

Matches real history: `dft-mfe-generator@2.5.0` (FOUND-1212).

### Example 3 — Patch: migration bug-fix preserving output shape

Change: fixes `applyTestEnvironment` in migration `2-2-0` to match against raw
content instead of stripped content, preventing duplicate `testEnvironment`
entries — no change to the generator's intended output shape, just a bug in
the existing migration's matching logic.

```
BUMP: patch
Justification: Bug-fix inside an existing migration factory that doesn't change intended output shape — "migration bug-fixes (e.g. 2.2.1 fixing the 2-2-0 regex) ... is patch".
Manual review flag: none
```

Matches real history: `dft-mfe-generator@2.2.1`.

### Example 4 — Fallback: exports-only change

Change: adds a fifth named export to `src/index.ts` with no change to
`schema.json`, scaffolded templates, or `migrations.json`.

```
BUMP: patch
Justification: Exports-only/internal change with no output-contract impact — code-export semver was rejected as the primary basis for this package, so this falls back to patch per the exports-only fallback.
Manual review flag: none
```

### Additional historical check — 2.4.0 (FOUND-1253)

Change: adds `migrate-2-4-0` to inject the `execContext` parameter into
`withEjsIndexTemplate` script generators at every call site, plus bumps the
`dft-rspack-config` pin from `0.6.4` to `0.7.0` with a paired
`packageJsonUpdates` entry.

```
BUMP: minor
Justification: Additive output change (new required generator param) ships with an idempotent, version-gated migration, paired with a migration-covered dependency pin bump — "migration-covered/additive output is minor".
Manual review flag: none
```

Matches real history: `dft-mfe-generator@2.4.0`.

