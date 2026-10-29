## Worked examples (from FOUND-1838 Gherkin acceptance criteria)

### Scenario 1 — Patch: internal fix, no export or emitted-field change

**Input:** A diff that fixes a redaction/sanitizer bug (or a
circular-serialization bug, perf issue, or docs-only change) with no change
to any exported signature and no observable change to emitted field
names/values.

```
Recommended bump: patch
Justification: Redaction/sanitizer bug fix with no change to any export
signature and no observable change to emitted field names/values — matches
the rubric's PATCH criterion verbatim.
Rubric source: projects/FoundationSemver/decisions/dft-logger.md; Confluence page 2454159376 ("dft-logger Semver")
```

### Scenario 2 — Minor: additive optional field

**Input:** A diff that adds a new optional `LoggerOptions` field, a new
exported level/transport/util, or an additive optional field on
`EventBody`/`Attributes`/`CustomerAttributes`/`CorrelationAttributes`.

```
Recommended bump: minor
Justification: Adds a new optional LoggerOptions field (non-breaking,
existing calls unaffected) — matches the rubric's MINOR criterion "new
optional LoggerOptions field."
Rubric source: projects/FoundationSemver/decisions/dft-logger.md; Confluence page 2454159376 ("dft-logger Semver")
```

### Scenario 3 — Major: breaking export or emitted-shape change

**Input:** A diff that removes/renames an export, changes a `Logger`
method or constructor signature, makes an optional option required,
renumbers `SEVERITY`, changes a `severityText` label, or renames/removes/
retypes an emitted `EventBody` field.

```
Recommended bump: major
Justification: Renumbers the SEVERITY enum, which the rubric names
explicitly as a MAJOR trigger regardless of whether any TypeScript type
changed.
Rubric source: projects/FoundationSemver/decisions/dft-logger.md; Confluence page 2454159376 ("dft-logger Semver")
Note: per the decision doc, any commit touching a transport,
BaseEventFormatter, or EventBody/Attributes shape MUST first ship as a
Jira-preid prerelease under a dist-tag and be validated against the
Splunk/Dynatrace pipeline before a latest release.
Also run: dft-logger-interceptors-bump-advisor and
dft-logger-middleware-bump-advisor to assess whether their peer-output
gates require a coordinated release for this major.
```

## Validation against real history

Cross-checked against `packages/dft-logger/CHANGELOG.md` (FOUND-1838
Subtask 3 candidates):

| Version | Change | Rubric verdict | Actual shipped bump |
|---|---|---|---|
| `2.0.1` (2026-06-29, FOUND-1394) | Fixed `getAttributes` crash on undefined `contextAttributesProvider` result (Node runtime); public `ContextAttributesProvider` type contract unchanged | PATCH (no export signature change, no emitted-field change) | patch — match |
| `2.0.0` (2026-06-11) | `WebTransport` batching became default, wire format changed single-object → JSON array, `errorTimeout` unit changed ms → seconds, `haltTransmission` option removed | MAJOR (removed export/option, plus a changed transport default payload shape) | major — match |
| `1.1.0` (2026-03-30, FOUND-1057) | Serialization-pipeline refactor for performance (single `stringify` call, redaction moved to operate on the JSON string) — no export signature change, no emitted-field change | **PATCH** under the current rubric | **minor** — **documented discrepancy** |

**The `1.1.0` case is a deliberate discrepancy test, not a rubric bug.**
Under the *current* contract-semver rubric, a perf-only refactor with no
export or emitted-field change is PATCH. It historically shipped as a
`1.1.0` minor — before this rubric's Option 2 was formally adopted. This
skill must recommend **patch** for an equivalent change today and flag the
mismatch with past practice rather than silently mirroring it:

```
Recommended bump: patch
Justification: Internal serialization-pipeline refactor for performance,
no export signature change, no observable change to emitted field
names/values — matches the rubric's PATCH criterion.
Rubric source: projects/FoundationSemver/decisions/dft-logger.md; Confluence page 2454159376 ("dft-logger Semver")
Note: v1.1.0 (FOUND-1057) shipped an equivalent perf-only refactor as a
minor, before this contract-semver rubric was adopted. Apply the current
rubric, not historical practice — this is a known, intentional discrepancy
with pre-rubric history, not evidence that perf refactors should be minor.
```

