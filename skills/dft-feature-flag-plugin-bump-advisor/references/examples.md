## Worked examples

Each example below is derived from one Gherkin scenario in FOUND-1833's Acceptance Criteria.

**Scenario 1 — Major bump: breaking change to executor CLI schema**

> Change description: the `add` executor's required `--description` CLI argument is removed.

```
BUMP: major
JUSTIFICATION: MAJOR — matches "removing/renaming a CLI arg or making an optional one
  required"; removing --description breaks existing CI scripts that pass it.
MIGRATION NOTE: this package ships no migrations.json — flag for the user that removing the
  arg needs manual migration guidance for repos whose CI scripts pass --description.
CONFIDENCE: high
```

**Scenario 2 — Minor bump: additive optional CLI arg and generated tag**

> Change description: a new optional `--env-group` argument is added to the `add` executor,
> plus a new generated NX tag on the scaffolded project.

```
BUMP: minor
JUSTIFICATION: MINOR — matches "new optional CLI arg, new generated file/tag... anything
  purely additive that leaves existing repos and their on-disk state valid"; existing repos
  and their on-disk state remain valid without --env-group or the new tag.
MIGRATION NOTE: n/a — purely additive, no existing repo needs to migrate anything.
CONFIDENCE: high
```

**Scenario 3 — Patch bump: internal bug fix with no behavior change**

> Change description: an internal bug fix in `trimOldestChangesets.ts`, with no change to
> on-disk output shape.

```
BUMP: patch
JUSTIFICATION: PATCH — matches "internal bug fixes... with no behavior change, output that
  stays byte-compatible"; the fix is internal and the on-disk output shape is unchanged.
MIGRATION NOTE: n/a — no output-shape change, nothing to migrate.
CONFIDENCE: high
```

**Scenario 4 — Edge case: mixed commit lines matching the historical v1.0.1 mis-classification**

> Change description: contains both a `feat:`-prefixed line and a `docs:`-prefixed line,
> mirroring the package's actual v1.0.1 release.

```
BUMP: minor
JUSTIFICATION: MINOR — the feat: line independently drives a minor under this policy's
  commit-type mapping; the accompanying docs: line does not pull the result down to patch.
MIGRATION NOTE: n/a — additive, nothing to migrate.
CONFIDENCE: high
NOTE: this input matches the documented historical mis-classification pattern — the
  package's actual v1.0.1 release shipped as a patch under this same mix of commit lines,
  which the rubric doc itself calls out as a mis-classified example. Do not repeat it.
```

## Validated against historical releases

| Version | Change | Rubric verdict | Matches actual release |
|---|---|---|---|
| `1.1.0` | Added a new NX tag on `flags-bff` (FOUND-650, additive scaffold change) | **MINOR** | Yes — released as `1.1.0` |
| `1.0.1` | Mixed `feat:` ("Add link to Feature Flags docs") + `docs:` commit lines | **MINOR** (per rubric) | No — actually released as `1.0.1` (a patch). This is the documented mis-classification the skill exists to catch — see Scenario 4 above. |

