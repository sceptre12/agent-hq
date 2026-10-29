## Worked examples

**Scenario 1 — MAJOR (breaking scaffold/NX target change)**

> Change description: "Renamed the `package` NX target's output artifact from
> `deployment.zip` to `bundle.zip` in `updateProjectConfiguration.ts`."

```
BUMP: major
JUSTIFICATION: MAJOR — changes the package target's output artifact path, which breaks
  existing deploy pipelines expecting deployment.zip.
MIGRATION REQUIRED: yes — already-scaffolded repos reference deployment.zip in their deploy
  pipelines; a migrations.json entry must rewrite the reference.
CONFIDENCE: high
```

**Scenario 2 — MINOR (additive scaffold/flag change)**

> Change description: "Added a new optional `--enableCors` schema flag; when set, scaffolds
> an additional CORS middleware file. Also widened the `cors` dependency range from `^2.8.0`
> to `^2.8.5` compatibly."

```
BUMP: minor
JUSTIFICATION: MINOR — new optional schema flag plus a compatible dependency-range widening;
  existing scaffolded projects remain valid without regenerating or migrating.
MIGRATION REQUIRED: no — existing scaffolded projects remain valid without migration.
CONFIDENCE: high
```

**Scenario 3 — PATCH (shape-preserving fix)**

> Change description: "Compatible dependency-range correction — `dft-logger ~0.4.0` →
> `^1.0.0`, `express ~5.1.0` → `^5.1.0` — to fix an express-4-vs-5 / logger type-skew.
> FOUND-1112-style fix, no generated file or schema change."

```
BUMP: patch
JUSTIFICATION: PATCH — compatible dependency-range correction with no change to generated
  output shape or accepted CLI flags.
MIGRATION REQUIRED: n/a — no change to generated output shape or CLI schema.
CONFIDENCE: high
```

## Validated against historical releases

The skill reproduces the package's own release history when run against the actual
CHANGELOG.md entries:

| Version | Change | Rubric verdict | Matches actual release |
|---|---|---|---|
| `2.0.7` | Dependency-range correction (`dft-logger ~0.4.0→^1.0.0`, `dft-logger-middleware ~0.1.0→^1.0.1`, `express ~5.1.0→^5.1.0`), no shape change (FOUND-1112) | **PATCH** | Yes — released as `2.0.7` |
| `2.0.8` | Added `migrations.json` + `update-2-0-7` migration + `nx-migrations` wiring — a new opt-in migration; existing projects remain valid | **MINOR** | Yes — released as `2.0.8` (an additive migration is a MINOR-class change per the rubric) |
| `2.0.9` | Stamp-alignment fix — renamed migration, corrected `TARGET_VERSION` to match published version — no shape/flag change | **PATCH** | Yes — released as `2.0.9`, and the rubric explicitly cites this as a PATCH example |
