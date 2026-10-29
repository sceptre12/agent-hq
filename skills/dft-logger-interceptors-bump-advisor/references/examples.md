## Worked examples (from FOUND-1843 acceptance criteria)

**Scenario 1 — major bump, peer-output gate triggered**
> Given: a change description stating that a `dft-logger` major release
> altered the emitted log envelope field set (e.g. renamed `w3c_trace_id`).

```
Recommended bump: major
Justification: dft-logger major renamed the w3c_trace_id log-envelope field,
altering this package's observable output with no local code change →
matches the peer-output-gate rule that "a dft-logger change that alters this
package's observable behavior — the log message/attribute shape,
trace-header format, or the semantics of the re-exported parseTraceIds —
forces a coordinated major here even with no local code change."
Rubric source: projects/FoundationSemver/decisions/dft-logger-interceptors.md
```

**Scenario 2 — minor bump, additive local change**
> Given: a change description stating that a new optional `piiFilter`
> parameter was added to `logRequestInterceptorFactory` with no
> signature-breaking change.

```
Recommended bump: minor
Justification: Adds a new optional piiFilter parameter to
logRequestInterceptorFactory with no breaking signature change → matches
"new interceptor factory, a new optional parameter (like piiFilter), a new
export entry point, or additive fields in the log envelope."
Rubric source: projects/FoundationSemver/decisions/dft-logger-interceptors.md
```

**Scenario 3 — patch bump, non-breaking bug fix**
> Given: a change description stating that `getPureJson` was fixed to
> handle circular data without changing its signature or output shape.

```
Recommended bump: patch
Justification: Fixes getPureJson to handle circular data with no signature
or log-shape change → matches "bug fix inside a factory with no signature or
log-shape change (e.g. null-guarding a header, fixing getPureJson on
circular data)."
Rubric source: projects/FoundationSemver/decisions/dft-logger-interceptors.md
```

## Validation against real history

Cross-checked against `packages/dft-logger-interceptors/CHANGELOG.md` and
git tag history (FOUND-1843 Subtask 3 candidates):

- **v1.0.0** (FOUND-1123) — converted `@sgwshub/dft-api-client` and
  `@sgwshub/dft-logger` from regular `dependencies` to `peerDependencies`;
  no breaking API change; "compatible with `dft-logger@^1.0.0`" — actual
  bump **major** (0.x → 1.0.0). This does not match a MAJOR criterion above
  on local API grounds alone (no factory/signature/envelope change is
  documented) — it reads as a first-stable-release major, not a rubric-driven
  one. Flag this as a **known exception** (skill-author inference, not stated in the
  decision doc): this skill's rubric governs
  *changes to an existing 1.x+ contract*, not the initial 0.x→1.0 stabilization
  bump, which follows separate "first stable major" conventions outside this
  document's scope.
- **v1.0.1** (FOUND-1374) — `dft-logger` peer dependency range effectively
  moved to `^2.0.0` (a `dft-logger` major); shipped as **patch**. Applying
  this skill's peer-output gate: given only "a dft-logger major occurred"
  with no stated evidence either way of observable-output change, Step 2's
  peer-output gate lands in the "cannot tell" branch — this skill would emit
  the Step 3 AMBIGUOUS block (not a bare MINOR or PATCH), flagging that the
  release owner must manually confirm whether the log
  envelope/trace-header/parseTraceIds semantics changed before the actual
  bump can be finalized. The historical **patch** bump is therefore a
  **documented discrepancy** against this skill's rubric, matching the
  ticket's own open question about confirming this with the release owner
  during validation.
- **v1.0.2** (FOUND-1374) — rebuild-only republish after a tsconfig
  project-reference sync fix, "no source or API changes" — actual bump
  **patch** — matches the PATCH criterion (no signature or log-shape change).

