## Worked examples (from FOUND-1845 acceptance criteria)

**Scenario 1 — patch, non-observable bug fix**
> Given: a change description stating only that the duplicate-log guard
> (`res.locals.dft_logged`) had a logic bug fixed, with no change to
> emitted fields, headers, or peer ranges.

```
Recommended bump: patch
Justification: Bug fix with no observable change to signatures, emitted
field set, header formats, or peer ranges → matches the PATCH criterion
"bug fix with no observable change to signatures, emitted field set,
header formats, or peer ranges."
Rubric source: Confluence page 2453798916 ("dft-logger-middleware Semver");
projects/FoundationSemver/decisions/dft-logger-middleware.md
```

**Scenario 2 — minor, additive log attribute**
> Given: a change description stating a new optional `attributes` field is
> added to the emitted log record without altering any existing field.

```
Recommended bump: minor
Justification: Purely additive and backward-compatible — new attributes
field that doesn't alter existing ones → matches the MINOR criterion
"purely additive and backward-compatible... new attributes fields... that
don't alter existing ones."
Rubric source: Confluence page 2453798916 ("dft-logger-middleware Semver");
projects/FoundationSemver/decisions/dft-logger-middleware.md
```

**Scenario 3 — major, breaking log-shape or header change**
> Given: a change description stating that `responseTime` is changed from
> a string (e.g. `"123ms"`) to a number, or that the `traceparent` header
> format is changed.

```
Recommended bump: major
Justification: Changing responseTime's type from string to number is a
consumer-observable breaking change even with no TS signature change →
matches the MAJOR criterion "changing a field's type (e.g. responseTime
string→number)" (equivalently "changing the traceparent format" for the
header variant).
Rubric source: Confluence page 2453798916 ("dft-logger-middleware Semver");
projects/FoundationSemver/decisions/dft-logger-middleware.md
```

## Validation against real history

Cross-checked against `packages/dft-logger-middleware/CHANGELOG.md`. Git
tags exist for 1.0.2/1.0.3 (and for 0.1.0/0.2.0, which predate 1.0.0); no
tag exists for 1.0.0/1.0.1 — since the tagging convention was already in
use before 1.0.0, the reason those two specific versions weren't tagged is
unknown/unstated, not a convention-timing artifact. The 1.0.0 example below
is CHANGELOG-verified only, not tag-verified like the other two:

- **v1.0.3** (2026-06-17, FOUND-1374) — "Rebuilt from clean workspace...
  no source or API changes; republished to ensure artifact integrity" —
  actual bump **patch**. Advisor: no change to any of the five contract
  axes → PATCH (no-op republish, matches the "no observable change"
  criterion).
- **v1.0.2** (2026-06-15, FOUND-1374) — kept the `dft-logger` peer at
  `workspace:^` (resolving to `^2.0.0`) while `dft-logger` itself went
  major; also a test-mocking fix — actual bump **patch**. Advisor: this is
  the peer-decoupling case explicitly — `dft-logger`'s major is not
  automatically inherited, and nothing in this package's own emitted
  fields changed → PATCH, matching the "decouple peer-major from own-major"
  guidance and the actual shipped tier.
- **v1.0.0** (2026-03-25, FOUND-1122) — converted `@sgwshub/dft-logger` and
  `express` from `dependencies` to `peerDependencies` as part of the first
  stable major release — actual bump **major**. Advisor: this changes how
  consumers must declare and resolve both peers (a peer-range-shape event
  affecting the express pin and the dft-logger peer contract) → MAJOR,
  matching the "peers" criterion and the first-stable-major convention.

All three match the tier actually shipped; no divergence to document.

