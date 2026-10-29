## Worked examples (from FOUND-1840 acceptance criteria)

**Scenario 1 — major bump, breaking change to schema or output contract**

> Given: a change description that removes the `owningTeam` required
> schema option (or otherwise removes/renames a schema option, adds a new
> required option, flips a default like `createPath` or `fetchesData`, or
> changes the emitted file set / default export / barrel `index.ts` shape
> / default output path — i.e. the `common/ui` default in
> `prompts.ts`/`validation.ts`, not `schema.json`'s cosmetic
> `libs/shared/ui` metadata).

```
Recommended bump: major
Justification: Removes the required owningTeam schema option → matches the
"remove/rename a schema option" MAJOR clause.
Rubric source: ~/projects/context-docs/projects/FoundationSemver/decisions/dft-component-generator.md
```

**Scenario 2 — minor bump, additive opt-in change**

> Given: a change description that adds a new optional schema option with
> a safe default, or adds a new generated file that doesn't displace
> existing ones, or makes an additive opt-in change to the decision tree.

```
Recommended bump: minor
Justification: Adds a new optional schema option with a safe default and
no change to existing generated output → matches the "additive, opt-in
changes to boilerplate or the decision tree" MINOR clause.
Rubric source: ~/projects/context-docs/projects/FoundationSemver/decisions/dft-component-generator.md
```

**Scenario 3 — patch bump, non-structural fix or cosmetic edit**

> Given: a change description that is a bug fix, a prompt-wording or
> description tweak, a validation-message fix, a dependency bump, or a
> cosmetic template edit that does not change file structure or the
> emitted API.

```
Recommended bump: patch
Justification: Bug fix with no change to file structure or emitted API →
matches the "bug fixes... that don't change file structure or the emitted
API" PATCH clause.
Rubric source: ~/projects/context-docs/projects/FoundationSemver/decisions/dft-component-generator.md
```

## Validated against real history

Cross-checked against `packages/dft-component-generator` commit history in
de-foundations, per FOUND-1840 subtask 3:

| Change | Actual scope | Rubric verdict | Matches |
|---|---|---|---|
| PR #213 / FOUND-1066 (commit `9c3e590d`) — pinned `package.json` dependency ranges to exact lockfile-resolved versions, no schema/output change | Dependency bump only, no schema or file-set change | **PATCH** — matches "dependency bumps... that don't change file structure or the emitted API" | Yes |
| PR #203 / FOUND-1130 (commit `fb3fa81f`) — added changelog-generation entries to `CHANGELOG.md` only | Non-functional, docs-only | **PATCH** — no schema, output, or decision-tree change | Yes |
| PR #214 / FOUND-1190 (commit `f9a75882`) — removed old `release` target from `project.json` | Internal build/release config, not the invocation schema or scaffolded-output contract | **PATCH** — no change to `src/schema.json`, `generators.json`, or `files/**` output | Yes |

