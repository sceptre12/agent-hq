# PR Check Migration Needed — Detailed Trigger Rules

Companion to `SKILL.md`. Contains full per-generator trigger rules, the
output-vs-behavior distinction, and the local package dependency rule.
---

## dft-mfe-generator — trigger rules

**Migration needed when:**
- Any change to generator templates that alters the content or structure of
  generated output files (check `src/files/` for changed file bytes)
- `@sgwshub/dft-rspack-config` change that modifies the shape of the generated
  `rspack.config.ts` (this package is a direct dep of the generator and its
  shape flows into generated files)
- `@sgwshub/dft-logger` change that renames, moves, or removes any of these
  exports used in generated templates: `Logger`, `SEVERITY`, `WebConsoleTransport`
  (imported in generated `src/app/logger/index.ts`)
- `@sgwshub/dft-logger-interceptors` change that renames or removes
  `logRequestInterceptorFactory`, `logResponseInterceptorFactory`,
  `logResponseErrorInterceptorFactory` (referenced in generated `src/api/apiClient.ts`)
- NX major version bump that changes workspace/generator API contracts
  (flag as "investigate" — do not auto-conclude yes or no)

**NOT a trigger:**
- Internal generator refactors with no output change
- Optional variable additions with safe defaults
- `dft-logger` patch/minor that is fully backwards-compatible

---

## dft-web-monorepo-generator — trigger rules

**Migration needed when:**
- Any change to generator templates that alters the content or structure of
  generated output files
- Schema changes that add required inputs or rename existing ones (consumers
  running older generator invocations will break)
- NX major version bump (flag as "investigate")

**NOT a trigger:**
- Internal refactors with no output change
- New optional schema fields with defaults

---

## dft-bff-generator — trigger rules

**Migration needed when:**
- Any change to generator templates that alters generated BFF files
  (e.g. `app.ts`, `loggerMiddleware.ts`, or any other `src/files/` output)
- `@sgwshub/dft-logger-middleware` change that renames or moves `loggerMiddleware`
  or `createRequestLogger` (used in generated `src/app.ts` and
  `src/utils/loggerMiddleware.ts`)
- `@sgwshub/dft-logger` change that renames or removes `Logger`, `NodeTransport`,
  or `SEVERITY` (used in generated `src/utils/loggerMiddleware.ts`)
- Dependency range changes in the generated `package.json` output (e.g. bumping
  pinned versions that consumers are expected to adopt)
- NX major version bump (flag as "investigate")

**NOT a trigger:**
- Internal generator refactors with no output change
- Backwards-compatible logger patch bumps

---

## dft-iac-generator — trigger rules

**Migration needed ONLY when:**
- A required variable is added to `variables.tf` in any of the three foundation
  modules in de-foundations-iac: `modules/foundations/bff`,
  `modules/foundations/bff-deployment-backend`, or
  `modules/foundations/harness-workspace`
- An existing variable is removed or renamed in any of those three modules
  (the generator hard-codes module calls in generated `.tf` files; renamed
  variables break the call signature)

Note: the generator lives in de-foundations but its migration trigger is
changes to `modules/foundations/` in **de-foundations-iac**, not de-foundations.
Watch for cross-repo PRs or linked changes.

**NOT a trigger:**
- Optional variables added with defaults
- New sub-generators added (no change to existing generated output)
- Template-only changes (new files generated, cosmetic output changes)
- Changes to `idp-product.json` schema or `$schema` fields
- Default value changes in modules (behavioral change, not an API break)
- Any change that does not affect the module call signature in generated `.tf` files

---

## Output-vs-behavior distinction

A generator can change **how** it generates without changing **what** it generates.

Examples of internal-only changes (no migration needed):
- Generator logic refactored into helper functions
- Performance improvement in how templates are rendered
- New CLI flag that defaults to existing behavior

Examples of output changes (migration needed):
- A template file in `src/files/` is modified (different content written to consumers)
- A new file is added to `src/files/`
- A file is removed from `src/files/`
- A hardcoded import path in a template changes

**Reviewer check:** Inspect whether the diff touches any file under `src/files/`
or any template string/object that controls generated file content. If yes,
treat as an output change. If no, it is an internal refactor.

---

## Local package dependency rule

If a PR updates a local de-foundations package (e.g. `dft-logger`,
`dft-rspack-config`, `dft-logger-middleware`) and that package is imported
**directly in generator-output template files** (not just in the generator
itself), a migration may be needed even if the generator package itself is
untouched.

How to check:
1. Find which exports from the changed package are referenced in generator
   template files (files under `src/files/` for any generator).
2. Check whether the PR adds, removes, or renames any of those exports.
3. If yes and the change is not fully backwards-compatible: migration needed.
4. If the change is additive and all existing export names are preserved: no
   migration needed.

This rule applies across all four generators. The per-generator trigger rules
above already call out the specific exports to watch for each generator.
