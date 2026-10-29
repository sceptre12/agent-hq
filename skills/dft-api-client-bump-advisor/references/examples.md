## Worked examples (from FOUND-1823 acceptance criteria)

**Scenario 1 — major bump, contract break**
> Given: a change description that removes the public `formatUrlAndParams`
> method from `ApiClient`, or narrows the `ResponseInterceptor` type
> signature.

This scenario's Given has two independent branches — either one alone is
enough to trigger MAJOR. Both worked below:

Branch A — removes an exported method:
```
Recommended bump: major
Justification: Removes the exported ApiClient.formatUrlAndParams method →
matches the "removing/renaming an exported symbol" MAJOR criterion.
Rubric source: ~/projects/context-docs/projects/FoundationSemver/decisions/dft-api-client.md
```

Branch B — narrows an interceptor type (no runtime signal — this is the
case the rubric's High-impact rating exists to catch):
```
Recommended bump: major
Justification: Narrows the ResponseInterceptor type signature → matches the
"narrowing or reshaping any interceptor type" MAJOR criterion; this is a
compile-time-only break for dft-logger-interceptors with no runtime symptom,
so it must not be under-classified as patch/minor.
Rubric source: ~/projects/context-docs/projects/FoundationSemver/decisions/dft-api-client.md
```

**Scenario 2 — minor bump, additive surface**
> Given: a change description that adds a new opt-in field to
> `InstanceConfigs` (e.g. a new capability alongside `errorRetryCheck`)
> without changing behavior of existing calls.

```
Recommended bump: minor
Justification: Adds a new optional field to InstanceConfigs with no change
to existing call behavior → matches the "purely additive surface" MINOR
criterion.
Rubric source: ~/projects/context-docs/projects/FoundationSemver/decisions/dft-api-client.md
```

**Scenario 3 — patch bump, bugfix with no signature change**
> Given: a change description that fixes an ESM/CJS `getAxiosWithCreate`
> interop bug or a `nullReplacementResponseInterceptor` correctness bug, with
> no exported signature change.

This scenario's Given also has two independent branches — both worked below:

Branch A — ESM/CJS interop fix:
```
Recommended bump: patch
Justification: Fixes getAxiosWithCreate ESM/CJS interop with no exported
signature or type change → matches the "bugfixes with no change to any
exported signature or type" PATCH criterion.
Rubric source: ~/projects/context-docs/projects/FoundationSemver/decisions/dft-api-client.md
```

Branch B — interceptor correctness fix with the same signature:
```
Recommended bump: patch
Justification: Fixes a nullReplacementResponseInterceptor correctness bug
(behavior only) with no change to its exported type signature → matches the
same "bugfixes with no change to any exported signature or type" PATCH
criterion. Contrast with Branch B of Scenario 1: a *behavior* fix to an
interceptor is patch, but *narrowing its type* is major — the distinction is
signature/type change, not which interceptor is touched.
Rubric source: ~/projects/context-docs/projects/FoundationSemver/decisions/dft-api-client.md
```

## Validation against real history

Cross-checked against the de-foundations repo's
`packages/dft-api-client/CHANGELOG.md`:
- **v0.0.3** (FOUND-865) — `getAxiosWithCreate` ESM/CJS interop fix — actual
  bump **patch** — matches the literal PATCH example above.
- **v1.1.0** (PCWA-10844) — added `errorRetryCheck`, `maxRetries`,
  `RetryErrorContext`, `ErrorRetryCheck` as new additive exports — actual
  bump **minor** — matches the MINOR additive-surface criterion.
- **v1.0.1** (FOUND-1374) — removed spurious `peerDependencies` entries, no
  exported signature change — actual bump **patch** — matches PATCH.

