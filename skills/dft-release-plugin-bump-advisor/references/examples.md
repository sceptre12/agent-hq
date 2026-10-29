## Worked examples (from FOUND-1834 acceptance criteria)

**Scenario 1 — major bump, release-affecting behavior change**
> Given: a diff that modifies the branch/version gates or dist-tag mapping in
> `release.ts`.

```
Recommended bump: major
Justification: Modifies the branch/version gates and dist-tag mapping in
release.ts → matches "any change to release-affecting behavior or the public
contract is major".
Rubric source: context-docs/projects/FoundationSemver/decisions/dft-release-plugin.md
```

**Scenario 2 — always-major override beats a lower commit prefix**
> Given: a diff that edits `inferSpecifierFromCommits`, and the author's
> commit message is prefixed `fix:`.

```
Recommended bump: major
Justification: Edits inferSpecifierFromCommits, one of the rubric's explicit
always-major signals, treated as major regardless of commit prefix — the
"fix:" prefix is not deferred to.
Rubric source: context-docs/projects/FoundationSemver/decisions/dft-release-plugin.md
```

**Scenario 3 — minor bump, new backward-compatible capability**
> Given: a diff that adds a new opt-in executor option defaulting to today's
> existing behavior.

```
Recommended bump: minor
Justification: Adds a new opt-in executor option that defaults to today's
behavior, with no change to any existing release outcome → matches "new
backward-compatible capability that does not change any existing release
outcome".
Rubric source: context-docs/projects/FoundationSemver/decisions/dft-release-plugin.md
```

**Scenario 4 — patch bump, documented-intent fix with zero outcome change**
> Given: a diff that only corrects an error-message typo, with an
> accompanying characterization test proving no release-outcome change.

```
Recommended bump: patch
Justification: Corrects an error-message typo with a characterization test
proving zero change to any currently-correct release outcome → matches
"fixes that make behavior match documented intent with zero change to any
currently-correct release outcome".
Rubric source: context-docs/projects/FoundationSemver/decisions/dft-release-plugin.md
```

## Validation against real history

Cross-checked against `packages/dft-release-plugin/CHANGELOG.md` and the
de-foundations git history:

- **v1.0.0** (2026-05-15, FOUND-1252, initial release) — baseline; not a bump
  to classify.
- **v1.0.1** (2026-06-03, FOUND-1252) — shipped as a patch-looking
  `1.0.0`→`1.0.1` bump, but the underlying changes replaced
  `getLastStableTag`/`detectIsFirstVersion` with `getLatestReachableTag`,
  made disk `package.json` the source of truth for version computation (see
  the disk-as-source-of-truth ambiguity note above), and simplified the
  release executor's publish path — always-major or MAJOR-tier touch-points.
  Applying this rubric: **major**, not patch, because it edits
  `getLatestReachableTag` and version-computation/dist-tag-mapping semantics
  directly. This is the ticket's designated always-major test case: the
  actual shipped bump undersold the change relative to what the rubric would
  recommend.
- **PR #209 "fix: FOUND-1252 release plugin versioning fixes"** — same
  underlying change as v1.0.1, committed with a `fix:` prefix while editing
  `release.ts`'s dist-tag mapping (`distTag` computation moved and the
  `isOnMain`/prerelease branching restructured) and disk-as-truth version
  computation. Applying this rubric: **major**, regardless of the `fix:`
  prefix — this is the ticket's second always-major test case, confirming the
  advisor overrides the commit prefix rather than deferring to it.

