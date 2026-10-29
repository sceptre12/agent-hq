---
name: dft-logger-interceptors-bump-advisor
description: >
  Use when a change to @sgwshub/dft-logger-interceptors (a diff, PR
  description, or a summarized change to its factories/exports) — or a
  dft-logger peer release that might alter emitted log shape — needs a
  version-bump recommendation before release. Triggers include "what bump
  does this need", "major or minor for dft-logger-interceptors", "does this
  dft-logger peer bump need a coordinated major here", "classify this
  dft-logger-interceptors change", or preparing a conventional-commit /
  release for dft-logger-interceptors. Advisory only — does not modify
  package.json, CHANGELOG, or peerDependencies ranges; see package-release
  for the actual bump/publish flow.
model: sonnet
---

# dft-logger-interceptors Bump Advisor

Classify a described change to `@sgwshub/dft-logger-interceptors` as
**major**, **minor**, or **patch** by applying the package's documented
rubric, and output the specifier plus a one-line justification tied to the
exact rubric criterion matched.

**Advisory only.** This skill never edits `package.json`, `CHANGELOG.md`, or
`peerDependencies` ranges. For the actual bump/tag/publish mechanics, use the
`package-release` skill (`~/.claude/skills/package-release/SKILL.md`).

## Trigger

Use when a diff, PR description, or free-text change summary for `@sgwshub/dft-logger-interceptors` needs a version-bump recommendation before release.

## Rubric source of truth

`projects/FoundationSemver/decisions/dft-logger-interceptors.md` (Outcome
section) — mirrored on Confluence as "dft-logger-interceptors Semver" (page
ID `2454126622`) (mirror; if this skill's output looks wrong, treat the local
decisions.md file, not the Confluence mirror, as authoritative). If this
skill's output ever looks wrong, re-read that file first; the rubric below
closely follows that document — matched criteria are quoted directly where
the source's wording allows; the peer-output gate below adds an explicit
third branch (AMBIGUOUS / "cannot tell") for cases the source doc doesn't
address as a discrete outcome. If this skill's output and the source doc
disagree on a covered criterion, the doc wins.

`@sgwshub/dft-logger-interceptors`'s public surface, spread across four
export entry points (`.`, `./request`, `./response`, `./utils`):
`logRequestInterceptorFactory(logger, piiFilter?) => RequestInterceptor`,
`logRequestErrorInterceptorFactory(...)`, `addTraceHeaders` (a
`RequestInterceptor` that injects the `traceparent` and
`x-browser-session-correlation-id` headers), `logResponseInterceptorFactory(logger) => ResponseInterceptor`,
`logResponseErrorInterceptorFactory(...)`, the `getPureJson(obj)` utility, and
`parseTraceIds` — **re-exported from `@sgwshub/dft-logger`** (aliased from
`parseTraceparent`, kept for backward compatibility).

**Why this package is different from a normal local-API rubric:** it does
not merely depend on `@sgwshub/dft-logger` — it re-exports one of that
package's symbols as its own public API, and the log shape it emits (the
`{ message, attributes.correlationAttributes.{w3c_trace_id, w3c_span_id} }`
envelope) is *jointly* determined by this package and by `dft-logger`. It
also imports `getBrowserId` and `generateHexadecimals` directly from
`@sgwshub/dft-logger` (used inside `addTraceHeaders.ts`), so the peer-coupling
surface extends beyond the re-exported `parseTraceIds` to those two helper
symbols as well. Both
`@sgwshub/dft-api-client` and `@sgwshub/dft-logger` are declared as
`peerDependencies` (`workspace:^`), not regular dependencies — consumers, not
this package, pin the peer versions. That means **a `dft-logger` major can
silently change this package's observable output with zero local code
change**, which is the specific failure mode the peer-output gate below
exists to catch.

## Steps

### Step 1 — Read the change

Take whatever the caller supplies: a git diff, a PR description, or a
free-form summary of changed exports/behavior/peer releases. If it's a raw
diff, focus on:
- Any file under `src/index.ts`, `src/request/`, `src/response/`, `src/utils/`
  (or their compiled `dist/*.d.ts` equivalents)
- `package.json` `peerDependencies.@sgwshub/dft-logger` /
  `peerDependencies.@sgwshub/dft-api-client` range changes
- Behavior-only changes with no exported-signature diff (bugfixes, internal
  refactors)
- **A description that isn't about this package's own code at all** — e.g.
  "`dft-logger` shipped a major" — is still in scope. This is the
  peer-output-gate case; do not dismiss it as "not a change here."

### Step 2 — Apply the rubric

Check criteria in this order — **peer-output gate first**, then MAJOR, then
MINOR, then PATCH — and stop at the first match. A change can satisfy
multiple criteria; always report the highest bump among all matches (see
Step 3 for mixed changes instead of silently picking the lower one).

### Peer-output gate — check this first, always
If the change description involves a `dft-logger` **major** release (with or
without any local code change here), assess whether it alters this
package's *observable* behavior:
- **Log message/attribute shape** (the `message`, `w3c_trace_id`,
  `w3c_span_id`, `correlationAttributes` envelope fields)
- **Trace-header contract** (`traceparent`, `x-browser-session-correlation-id`
  — this covers changes to `getBrowserId`/`generateHexadecimals` semantics,
  not just header field names)
- **`parseTraceIds` semantics** (it is re-exported from `dft-logger`'s
  `parseTraceparent` — any change to its signature or meaning counts)

→ If **yes**, observable output changed: **MAJOR**, coordinated in lockstep
  with the peer's major, with the peer range narrowed to the new major (`^X`).
→ If **no**, the peer went major but nothing observable here changed:
  **MINOR** — ship as a peer-range-widening minor with a CHANGELOG note
  (this is the one case where a peer *major* still only produces a minor
  here — see Common Mistakes).
→ If you **cannot tell** whether output changed: do not guess — flag
  AMBIGUOUS per Step 3 and recommend the release owner manually assess the
  peer's release notes/diff.

A `dft-logger` **non-major** bump (minor/patch) is not gated — evaluate it
under the normal local-API rules below (it typically doesn't move this
package's version at all unless it also touches this package's own code).

### MAJOR — any break to the local contract
- Removing or renaming an exported factory or `parseTraceIds`
- Changing a factory's required signature
- Changing the `Logger`/interceptor contract
- Removing or renaming a log-envelope field
- (Also reached via the peer-output gate above, independent of local code)

### MINOR — purely additive surface, behavior of existing calls unchanged
- A new interceptor factory
- A new optional parameter (e.g. `piiFilter`)
- A new export entry point
- Additive fields in the log envelope
- (Also reached via the peer-output gate above when a `dft-logger` major
  changes nothing observable)

### PATCH — bugfix with no signature or log-shape change
- Bug fix inside a factory with no signature or log-shape change — e.g.
  null-guarding a header, fixing `getPureJson` on circular data

### Step 3 — Handle ambiguous or mixed changes

If the described change touches **both** an internal-only path and an
exported signature/log-shape — or you cannot tell whether a `dft-logger`
major actually altered observable output — do not silently pick the lower
bump. Report:

```
AMBIGUOUS — cannot classify with confidence.
Reason: <what's mixed or missing — e.g. "dft-logger major release, but no
information on whether the log envelope or parseTraceIds semantics changed">
Highest-bump interpretation: <major|minor|patch>, because <criterion>
Lowest-bump interpretation: <major|minor|patch>, because <criterion>
Recommend: request the dft-logger release notes/diff (or confirm with the
release owner whether the emitted log envelope, trace-header format, or
parseTraceIds semantics changed) before finalizing the release bump — this
is a release-owner MUST-assess judgment call per the decision doc, not
something to guess.
```

### Step 4 — Output format

For unambiguous classifications, output exactly:

```
Recommended bump: <major|minor|patch>
Justification: <one line, name the specific export/symbol/behavior (or peer
event) changed and quote or closely paraphrase the matched rubric criterion>
Rubric source: projects/FoundationSemver/decisions/dft-logger-interceptors.md
```

See `references/examples.md` for worked examples and validation against real history.

## When NOT to use

- The change is to the base `dft-logger` package itself, not
  `dft-logger-interceptors` — that's a separate package with its own
  decision doc and advisor skill (`dft-logger-bump-advisor`). Use this
  skill only to assess whether a `dft-logger` release forces a coordinated
  bump *here* via the peer-output gate above.

## Red flags

| Mistake | Fix |
|---|---|
| Treating a `dft-logger` peer major with no local code change as "nothing to bump here" | The peer-output gate can force a bump (minor at minimum, major if output changed) with **zero local code change** — always check the gate first, even for peer-only inputs |
| Assuming a `dft-logger` major always means a major here | Only assess **major** here if the peer change alters observable output (log envelope, trace-header, `parseTraceIds` semantics); if it doesn't, it's a **minor** peer-range widening, not major and not "no bump" |
| Guessing whether a `dft-logger` change is "observable" when the input doesn't say | Flag AMBIGUOUS per Step 3 — the decision doc frames this as a release-owner MUST-assess judgment call, not something the skill should infer silently |
| Treating the re-exported `parseTraceIds` as "not really this package's API since it just proxies dft-logger" | It's explicitly first-class public API here — any change to its signature or semantics (regardless of origin) is MAJOR |
| Assuming this skill also performs the release or narrows the peer range | It does not — it is advisory only; hand the recommended specifier to `package-release` for the actual bump/publish and peer-range edit |

## Scope

Scoped to `@sgwshub/dft-logger-interceptors` only, per FOUND-1843.
Generalizing to read any package's decision doc under
`projects/FoundationSemver/decisions/` is a candidate follow-up (see
FOUND-1737), not covered here.

## Exit criteria

- [ ] A bump tier was produced, or an explicit AMBIGUOUS report with both interpretations —
  never a silent guess.
- [ ] The justification names the specific changed surface and quotes or closely
  paraphrases the matched rubric criterion.
- [ ] No edits were made to `package.json`, `CHANGELOG.md`, or `nx.json`.

## Provenance

Provenance: Hermes skill `learnings/skill-sharing` (corpus-wide porting authorship
attestation: ADR 0010).
Lineage: X-context-docs skills/dft-logger-interceptors-bump-advisor@9d7143e
