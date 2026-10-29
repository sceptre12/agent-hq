## Worked examples (from FOUND-1842 acceptance criteria)

**Scenario 1 — major bump, resource-identity-affecting CDK output change**
> Given: a proposed change to nx-generator that alters generated CDK output
> resource identity (naming/tagging/stack structure) in a way that can cause
> CloudFormation replacement/teardown.

```
Recommended bump: major
Justification: Alters generated CDK output resource identity (naming/tagging/
stack structure), risking CloudFormation replacement/teardown → matches "any
change to generated CDK output that alters resource identity ... and can
cause CloudFormation replacement/teardown."
Rubric source: ~/projects/context-docs/projects/FoundationSemver/decisions/nx-generator.md
```

**Scenario 2 — minor bump, additive new export**
> Given: a proposed change to nx-generator that adds a new optional schema
> option with a default, or an additive new export in `./` or `./shared`.

```
Recommended bump: minor
Justification: Adds a new optional schema option with a default (or an
additive `./`/`./shared` export) with no change to existing behavior →
matches "new optional schema option (with a default); additive new export in
./ or ./shared."
Rubric source: ~/projects/context-docs/projects/FoundationSemver/decisions/nx-generator.md
```

**Scenario 3 — patch bump, non-breaking internal fix**
> Given: a proposed change to nx-generator that is a bug fix to a generator
> that doesn't change its schema or the shape of generated output.

```
Recommended bump: patch
Justification: Bug fix to a generator with no change to its schema or the
shape of generated output → matches "bug fixes to a generator that don't
change its schema or the shape of generated output."
Rubric source: ~/projects/context-docs/projects/FoundationSemver/decisions/nx-generator.md
```

## Validation against real history

Cross-checked against `packages/nx-generator/` commit history in
de-foundations (per FOUND-1842's validation subtask). `nx-generator` has no
released tags past its initial `0.1.16` seed, so these are classified by
what each change touched, not by an actual historical bump to compare
against:

- **`133c2fc1` "add pino" (#4)** — added `pino`/`pino-lambda` as new declared
  dependencies, used by `shared/cdk/utils/logger.ts` (an internal CDK-side
  utility, not one of the public 11 layer modules) and injected as a
  template dependency into generated BFF apps by the `bff` generator; the
  `shared/layers/logger.ts` runtime layer module itself uses
  `@aws-lambda-powertools/logger`, unaffected by this commit. Purely
  additive dependency declaration, no existing schema/export/output changed
  — classifies as **minor** (additive new capability, no disturbance to
  existing behavior).
- **`fb3fa81f` "FOUND-1130 implement per-package changelog generation"
  (#203)** — changes release/changelog tooling repo-wide (`nx.json`, new
  `docs/RELEASE_WORKFLOW.md`, new `scripts/tag-release.sh`, a
  `CHANGELOG.md`→`CHANGELOG.legacy.md` rename, and new per-package
  `CHANGELOG.md` files including one for `packages/nx-generator`); touches
  no generator schema, no generated CDK output, and no `./`/`./shared`
  export for nx-generator specifically — outside this rubric's classified
  surface entirely (release tooling, not a change to the package's
  generator/runtime contract). Flagged here as an example of a change that
  is **not classifiable by this rubric** — report it as out-of-scope rather
  than forcing a bump tier, rather than defaulting to patch.
- **`9c3e590d` "FOUND-1066 pin de-foundations third-party deps to exact
  lockfile-resolved versions" (#213)** — pins existing dependency ranges to
  exact versions; "no version bumps, pure declaration realignment" per its
  own description; no schema/output/export change — classifies as **patch**
  at most (internal declaration change, preserves exported signatures and
  generated-artifact structure), and arguably no bump at all since nothing
  observable to a consumer changed.

