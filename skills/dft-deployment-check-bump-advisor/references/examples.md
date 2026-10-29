## Worked examples (from FOUND-1839 acceptance criteria)

**Scenario 1 — Major bump: gating rule change**
> Given: a change description that adds a new path filter, changes the
> `apps/`-only scope, or changes the `examples/e2e` exclusion; or renames the
> `deploymentCheck` target or `deployment-check:check` executor; or changes
> the `ALLOW_DEPLOYMENT_CHECK` opt-in var; or changes the meaning of "version
> was bumped"; or adopts a breaking `dft-get-project-target-state` output
> shape.

```
BUMP: major
JUSTIFICATION: MAJOR — change to which projects are gated (path filter /
  apps-only-scope / examples-e2e exclusion change), matching the rubric's
  "any change to which projects are gated" clause.
RUBRIC SOURCE: context-docs-worktrees/foundation-semver/projects/FoundationSemver/decisions/dft-deployment-check.md
```

**Scenario 2 — Minor bump: additive, backward-compatible change**
> Given: a change description that adds a new optional executor schema
> option defaulting to today's behavior, gates additional projects only
> behind a new opt-in flag, adds diagnostic/log output, or bumps a
> dependency within a compatible range.

```
BUMP: minor
JUSTIFICATION: MINOR — new optional executor schema option that defaults to
  today's behavior, matching the rubric's additive-surface-growth clause.
RUBRIC SOURCE: context-docs-worktrees/foundation-semver/projects/FoundationSemver/decisions/dft-deployment-check.md
```

**Scenario 3 — Patch bump: non-behavioral fix**
> Given: a change description that is a bug fix restoring already-documented
> behavior (e.g. comparing parsed version instead of grepping the string
> "version"), an internal refactor, a performance change, or a
> non-behavioral build change.

```
BUMP: patch
JUSTIFICATION: PATCH — bug fix restores documented behavior (parsed-version
  comparison instead of string grep), matching the rubric's named PATCH
  example verbatim.
RUBRIC SOURCE: context-docs-worktrees/foundation-semver/projects/FoundationSemver/decisions/dft-deployment-check.md
```

**Scenario 4 — Ambiguous change: no confident match**
> Given: a change description that does not clearly match any single rubric
> tier (e.g. "updated the merge-base detection logic" with no detail on
> whether the comparison semantics changed).

```
BUMP: ambiguous — recommending major as the conservative default
REASON: description does not say whether the merge-base detection change
  alters the "version was bumped" comparison semantics or only its internal
  implementation.
CONSERVATIVE TIER: major, because this package gates every app's build in a
  consuming workspace — an under-classified tightening/loosening of the
  comparison rule risks an all-pipelines incident.
Recommend: get the specific diff to checkPackageVersionChangeInCd.ts (or a
  clearer change description) before finalizing the release bump.
```

## Validation against real history

Cross-checked against `packages/dft-deployment-check/CHANGELOG.md`:

- **0.1.1** (FOUND-496, "Update shared workspace dependencies") — actual bump
  **patch**. Under this rubric: a dependency update with no change to gated
  paths, target/executor names, the opt-in var, or the "was bumped"
  semantics is a non-behavioral change — matches the PATCH tier's "internal
  refactors, perf, non-behavioral build changes" clause, consistent with
  what actually shipped.
- **0.1.0** (ECOP-1149, "Move deployment check plugin to standalone
  package") — actual bump **minor** (initial `0.x` feature release, no prior
  version to compare against). Not independently re-derivable under this
  rubric since it predates the package's existence as a standalone unit;
  included here only as the CHANGELOG's earliest recorded entry, not as a
  rubric test case.

