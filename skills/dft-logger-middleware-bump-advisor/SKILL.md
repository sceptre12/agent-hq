---
name: dft-logger-middleware-bump-advisor
description: >
  Use when a change to @sgwshub/dft-logger-middleware (a diff, PR
  description, CHANGELOG draft entry, or a summarized change description)
  needs a version-bump recommendation before release. Triggers include
  "what bump does this need", "major or minor for dft-logger-middleware",
  "classify this dft-logger-middleware change", or preparing a
  conventional-commit / release for dft-logger-middleware. This package's
  breaking-change surface is broader than TS signatures — it also covers
  the emitted log-record shape, req/res mutations, W3C trace-header
  formats, and peer ranges. Advisory only — does not modify package.json
  or CHANGELOG; see package-release for the actual bump/publish flow.
model: sonnet
---

# dft-logger-middleware Bump Advisor

Classify a described change to `@sgwshub/dft-logger-middleware` as **major**,
**minor**, or **patch** by applying the package's documented contract-aware
rubric, and output the specifier plus a one-line justification tied to the
exact rubric criterion matched.

**Advisory only.** This skill never edits `package.json`, `CHANGELOG.md`, or
`nx.json`. For the actual bump/tag/publish mechanics, use the
`package-release` skill (`~/.claude/skills/package-release/SKILL.md`).

## Trigger

Use when a diff, PR description, or free-text change summary for `@sgwshub/dft-logger-middleware` needs a version-bump recommendation before release.

## Rubric source of truth

Confluence page "dft-logger-middleware Semver" (page ID `2453798916`) —
mirrored in
`projects/FoundationSemver/decisions/dft-logger-middleware.md`
(Outcome section). If this skill's output ever looks wrong, re-read that
page/doc first; the rubric below is a verbatim transcription of it, not a
paraphrase, and if the two ever disagree the doc wins.

**Why "breaking" is broader here than function signatures:** the middleware's
most-consumed "API" is not its exported functions — it is the *shape of what
it writes*. Non-npm consumers (log aggregation/search, dashboards, alerts,
distributed-tracing collectors) parse the emitted log records and trace
headers directly and never show up as npm dependents. A code-signature-only
policy would silently mislabel a shape/header break as a minor or patch.

`@sgwshub/dft-logger-middleware`'s full observable contract has **five**
axes, all of which count:

1. **TS signatures** — `loggerMiddleware(baseLogger, headerSanitizer?)`,
   `createRequestLogger(req, baseLogger)`, utilities (`applyContext`,
   `sanitizeHeaders`, `getNodeContextAttributes`,
   `getTraceparentHeadersConfig`), types (`LoggerAttributes`,
   `LoggedRequest`, `ExpressMiddleware`, `SanitizeHeaders`), and the three
   export entry points `.`, `./utils`, `./createRequestLogger`.
2. **Emitted log-record shape** — two distinct records, not one flat field
   list:
   - **REQUEST record:** `message` text, `attributes.headers` (sanitized),
     `attributes.type` (`REQUEST | RESPONSE`, with `ERROR` reserved for
     consumer use).
   - **RESPONSE record:** `message` text, `attributes.statusCode`,
     `attributes.responseTime` (a **string** like `"123ms"`),
     `attributes.type`. (`headers` is never on RESPONSE; `statusCode`/
     `responseTime` are never on REQUEST.)
   - **Both records:** `contextAttributes.correlationAttributes`
     (`w3c_trace_id`, `w3c_span_id`, `w3c_parent_span_id`, `browser_id`,
     `userAgent`, browser name/version, OS) is present on both via the
     shared `applyContext` merge.
3. **req/res mutations** — `req.loggerAttributes = { startTime,
   contextAttributes }`, `res.locals.dft_logged = true` (duplicate-log
   guard), and the `res.json`/`res.send`/`res.end` monkey-patches.
4. **W3C trace-header formats** — `traceparent` formatted
   `00-{32hex}-{16hex}-01`, and the `x-browser-session-correlation-id`
   header.
5. **Peer ranges** — the `express@5.1.0` exact pin, and the
   `@sgwshub/dft-logger` (`workspace:^`, resolving to `^2.0.0`) peer range.

Also part of the contract: **redaction behavior** driven by
`DEFAULT_SENSITIVE_HEADERS`, `DEFAULT_SENSITIVE_PATTERNS`,
`SAFE_HEADERS_ALLOWLIST`, `REDACTION_TEXT = "[REDACTED]"`, and the
**status→log-level policy**. The implementation's actual branching is
`>=200 && <400 → info`, `>=400 && <500 → warn`, `else → error` — so it is
not strictly "5xx→error"; any status code outside 2xx/3xx/4xx, including
1xx, also falls into the error branch.

## Steps

### Step 1 — Read the change

Take whatever the caller supplies: a git diff, a PR description, a
CHANGELOG draft entry, or a free-form change summary. If it's a raw diff,
focus on:
- `src/middleware/index.ts` (the actual middleware logic — `src/index.ts`
  is only a re-export barrel), `src/middleware/_types.ts`,
  `src/createRequestLogger/index.ts`, `src/constants.ts`, and
  `src/utils/*.ts`, read against any of the five contract axes above (or
  their compiled `dist/*.d.ts` equivalents)
- `package.json` `peerDependencies.express` and
  `peerDependencies.@sgwshub/dft-logger` version/range changes
- Any change to the fields/structure of what gets logged or attached to
  `req`/`res`, even if no exported TS signature changed
- Behavior-only changes with no exported-signature diff (bugfixes, internal
  refactors, redaction-list additions)

### Step 2 — Apply the rubric

Check criteria in this order — **MAJOR first**, then MINOR, then PATCH —
and stop at the first match. A change can satisfy multiple criteria; always
report the highest bump among all matches (see Step 3 for mixed changes
instead of silently picking the lower one).

### MAJOR — any consumer-observable removal, rename, or retype

**On signatures:**
- Removing or renaming an export or entry point
- Making a previously optional param required

**On emitted shape (breaking even with no signature change):**
- Removing or renaming an `attributes` field (`type`, `statusCode`,
  `responseTime`, correlation fields)
- Changing a field's type (e.g. `responseTime` string → number)
- Changing the `req.loggerAttributes` / `res.locals.dft_logged` contract
- Changing the status→log-level mapping

**On headers:**
- Changing the `traceparent` format
- Renaming `x-browser-session-correlation-id`

**On redaction:**
- *Un-redacting* a previously redacted header, or moving a header into the
  allowlist (an information-disclosure regression)

**On peers:**
- *Narrowing* the `@sgwshub/dft-logger` peer range
- Bumping the pinned `express` version (any change to the exact pin)

### MINOR — purely additive and backward-compatible

- New exports
- New **optional** params (e.g. an options object on `loggerMiddleware`)
- **New** `attributes` fields or **new** headers that don't alter existing
  ones
- A new log level
- Widening the `dft-logger` peer range to admit a newer compatible major
  *without changing behavior* — per Option-2 judgment this can be
  patch/minor rather than automatically inheriting the peer's major (see
  peer-decoupling note below)

### PATCH — bug fixes with no observable change

- No change to signatures, emitted field set, header formats, or peer
  ranges
- Examples from the doc: fixing the duplicate-log guard, correcting
  `responseTime` arithmetic, *adding* entries to
  `DEFAULT_SENSITIVE_HEADERS`/`DEFAULT_SENSITIVE_PATTERNS` (redacting
  *more* is a safety fix, not a shape change), non-semantic message
  wording, perf

### Peer-major decoupling — always an explicit decision, not an automation

A `dft-logger` major bump is **not automatically** this package's major
(precedent: `1.0.2`, which kept `dft-logger` at `workspace:^`/`^2.0.0` while
`dft-logger` itself went major). It **is** major here only if:
- the widened peer range forces consumers off a version they can still
  use, or
- the peer bump changes any field this package re-emits.

If a described change widens the `dft-logger` peer range, do not default to
"peer went major → this package is major." Ask whether either condition
above holds; if the input doesn't say, flag it per Step 3 (ambiguous) rather
than guessing. Every peer-range move should carry an explicit
CHANGELOG-recorded call regardless of which tier you land on.

### Step 3 — Handle ambiguous or mixed changes

If the described change touches both an internal-only path and one of the
five contract axes — or you cannot tell from the input whether the emitted
shape, headers, or peer semantics are affected — do not silently pick the
lower bump. Report:

```
AMBIGUOUS — cannot classify with confidence.
Reason: <what's mixed or missing>
Highest-bump interpretation: <major|minor|patch>, because <criterion>
Lowest-bump interpretation: <major|minor|patch>, because <criterion>
Recommend: request the dist/*.d.ts diff, the emitted log-record sample
(before/after), or the specific peer-range delta before finalizing the
release bump.
```

This also applies to peer-major decoupling calls (see above) when the input
doesn't state whether consumer-facing behavior actually changed.

### Step 4 — Output format

For unambiguous classifications, output exactly:

```
Recommended bump: <major|minor|patch>
Justification: <one line, name the specific field/header/signature/peer
changed and quote or closely paraphrase the matched rubric criterion>
Rubric source: Confluence page 2453798916 ("dft-logger-middleware Semver");
projects/FoundationSemver/decisions/dft-logger-middleware.md
```

See `references/examples.md` for worked examples and validation against real history.

## When NOT to use

- The change is to the base `dft-logger` package itself, not
  `dft-logger-middleware` — that's a separate package with its own decision
  doc and advisor skill (`dft-logger-bump-advisor`). A `dft-logger` major
  may force a peer-decoupling call in *this* package (see the
  peer-major-decoupling section above), but the assessment of `dft-logger`'s
  own change happens in its own skill, not this one. Use this skill only to
  assess whether a `dft-logger` release forces a coordinated bump *here*.
- You need to know whether a migration script is required for correctness
  — that's a `pr-check-migration-needed` concern, not this skill's.
- You want the release to actually happen — hand this skill's recommended
  specifier to `package-release`.

## Red flags

| Mistake | Fix |
|---|---|
| Judging bump tier only from the TS diff | This package's real blast radius is the emitted log/trace shape, not just exported functions — always check all five contract axes (signatures, log-record shape, req/res mutations, trace headers, peer ranges) |
| Treating any `dft-logger` peer major bump as automatically major here | Peer-major and own-major are decoupled (precedent: 1.0.2) — it's major only if the range change forces consumers off a still-usable version or changes a re-emitted field; otherwise ask/flag ambiguous rather than defaulting to major |
| Calling a `responseTime`/`traceparent` type or format change "internal" because no exported TS signature changed | These are breaking even with zero signature diff — non-npm consumers (dashboards, alerts, trace collectors) parse them directly |
| Treating "adding redaction entries" as a shape change | Redacting *more* is a PATCH safety fix; only un-redacting or allow-listing a previously redacted header is MAJOR |
| Picking the lower bump when a change is genuinely mixed | Use Step 3 — report AMBIGUOUS and both interpretations instead of guessing |
| Assuming this skill also performs the release | It does not — it is advisory only; hand the recommended specifier to `package-release` for the actual bump/publish |

## Scope

Scoped to `@sgwshub/dft-logger-middleware` only, per FOUND-1845. Rubric
source is Confluence page 2453798916 and its mirrored decision doc;
generalizing to read any package's decision doc automatically is a
candidate follow-up, not covered here.

## Exit criteria

- [ ] A bump tier was produced, or an explicit AMBIGUOUS report with both interpretations —
  never a silent guess.
- [ ] The justification names the specific changed surface and quotes or closely
  paraphrases the matched rubric criterion.
- [ ] No edits were made to `package.json`, `CHANGELOG.md`, or `nx.json`.

## Provenance

Provenance: Hermes skill `learnings/skill-sharing` (corpus-wide porting authorship
attestation: ADR 0010).
Lineage: X-context-docs skills/dft-logger-middleware-bump-advisor@9d7143e
