---
name: dft-logger-bump-advisor
description: >
  Use when a change to @sgwshub/dft-logger (a diff, PR description, commit
  message, or free-text change summary) needs a version-bump recommendation
  before release. Triggers include "what bump does this need", "major or
  minor for dft-logger", "does this change the EventBody shape", "classify
  this dft-logger change", "is this a breaking change to dft-logger", or
  preparing a conventional-commit / release for dft-logger. Scoped to the
  base @sgwshub/dft-logger package only — not dft-logger-interceptors or
  dft-logger-middleware, which have their own advisor skills. Advisory
  only — does not modify package.json, CHANGELOG.md, or trigger a release.
model: sonnet
---

# dft-logger Bump Advisor

Classify a described change to `@sgwshub/dft-logger` as **major**, **minor**,
or **patch** by applying the package's documented contract-semver rubric,
and output the specifier plus a one-line justification tied to the exact
rubric criterion matched.

**Advisory only.** This skill never edits `package.json`, `CHANGELOG.md`, or
triggers a release. For the actual bump/tag/publish mechanics, use the
`package-release` skill (`~/.claude/skills/package-release/SKILL.md`) — this
skill's output is input a human considers before invoking that flow.

## Trigger

Use when a diff, PR description, or free-text change summary for `@sgwshub/dft-logger` needs a version-bump recommendation before release.

## Rubric source of truth

`projects/FoundationSemver/decisions/dft-logger.md` (Outcome section) —
mirrored on Confluence as "dft-logger Semver" (page ID `2454159376`). If
this skill's output ever looks wrong, re-read that file first; the rubric
below is a verbatim transcription of it, not a paraphrase, and if the two
ever disagree the doc wins.

## Why this package needs contract semver, not plain API semver

`@sgwshub/dft-logger` has no internal dependencies and is the
most-widely-depended-on runtime library in the inventory (two peers —
`dft-logger-interceptors`, `dft-logger-middleware` — plus direct consumers).
Its `EventBody` JSON shape (`timestamp`, `severityText`, `name`, `body`,
`attributes`) is serialized and shipped to **Splunk and Dynatrace**.
Downstream dashboards, alerts, and parsers key off exact field names — a
coupling that sits **outside the npm dependency graph** and is invisible to
npm/NX. A "non-breaking" TypeScript change (no exported type changed) can
still silently break production observability if it renames or drops an
emitted field.

The package's adopted policy (**Option 2 — contract semver**, per the
decision doc's Outcome section) therefore treats **two** surfaces as public
API, both governed by the same three tiers:

1. **TypeScript surface** — the `Logger` class, `LoggerOptions`, `SEVERITY`
   enum, exported types, transport constructors, util exports.
2. **Emitted-shape surface** — the serialized `EventBody`/`Attributes` JSON:
   field names, `severityText` label values, `SEVERITY` numeric ordering,
   and each shipped transport's default payload shape.

A change can trigger either surface independently — always check both, not
just "did an export change."

## Steps

### Step 1 — Read the change

Take whatever the caller supplies: a git diff, a PR description, or a
free-form summary. Classify it against **both** surfaces:

- **TS-surface question:** did any exported class/method/constructor
  signature, `LoggerOptions` field requiredness, `SEVERITY` enum, or
  exported util/transport change?
- **Emitted-shape question:** did the JSON actually written to a transport
  change — a field renamed/removed/retyped on `EventBody`/`Attributes`/
  `CustomerAttributes`/`CorrelationAttributes`, a `severityText` label
  changed, `SEVERITY` renumbered, or a shipped transport's default payload
  shape altered?

If the input doesn't say enough to answer either question with confidence,
do not guess — go to [Step 4](#step-4--ambiguous-input-do-not-guess).

If it's a raw diff, focus on these concrete paths under
`packages/dft-logger/src/` (or their compiled `dist/*.d.ts` equivalents):
- **TS-surface files:** `src/index.ts` (export barrel), `src/Logger/index.ts`
  (the `Logger` class), `src/Logger/_types.ts` (`LoggerOptions`,
  `ContextAttributesProvider`), `src/Logger/constants.ts` (the `SEVERITY`
  enum and `SEVERITY_LABELS`)
- **Emitted-shape files:** `src/event/_types.ts` (`EventBody`/`Attributes`/
  `CustomerAttributes`/`CorrelationAttributes`), `src/transports/*`
  (each transport's default payload shape,
  `src/transports/BaseTransport/BaseEventFormatter.ts`, and
  `src/transports/DynatraceWebTransport/DynatraceEventFormatter.ts`)

### Step 2 — Apply the rubric

Quoted rubric language is from the decision doc's Action Items ("Bump rules
for this package") — use it verbatim or closely paraphrased in the
justification. Check MAJOR first, then MINOR, then PATCH, and stop at the
first match — a change satisfying a higher tier is never downgraded by also
having lower-tier characteristics.

### MAJOR — breaking either surface

- Remove or rename any export
- Change a `Logger` method or constructor signature
- Make an optional option required
- **Renumber `SEVERITY`** or change a `severityText` label
- Rename/remove/retype any emitted `EventBody` field (including on
  `Attributes`/`CustomerAttributes`/`CorrelationAttributes`)
- Change a shipped transport's default payload shape

### MINOR — additive on either surface, no existing behavior changed

- New optional `LoggerOptions` field
- New exported level/transport/util
- **Additive** optional field on `EventBody`/`Attributes`/
  `CustomerAttributes`/`CorrelationAttributes`
- New transport package

### PATCH — no observable change to either surface

- Redaction/sanitizer fixes
- Circular-serialization fixes
- Perf work
- Docs
- Internal refactors with **no** change to any export signature and **no**
  observable change to emitted field names/values

### Step 3 — Output format

```
Recommended bump: <major|minor|patch>
Justification: <one line, name the specific export/field/behavior changed
and quote or closely paraphrase the matched rubric criterion>
Rubric source: projects/FoundationSemver/decisions/dft-logger.md; Confluence page 2454159376 ("dft-logger Semver")
```

### Mandatory prerelease note

If the change touches a transport, `BaseEventFormatter`, or the
`EventBody`/`Attributes` shape — regardless of whether it lands as major or
minor — append this line to the output, per the decision doc's Action
Items:

```
Note: per the decision doc, any commit touching a transport,
BaseEventFormatter, or EventBody/Attributes shape MUST first ship as a
Jira-preid prerelease under a dist-tag and be validated against the
Splunk/Dynatrace pipeline before a latest release.
```

### Mandatory sibling-coordination trigger

If the recommended bump is **major**, also run the
`dft-logger-interceptors-bump-advisor` and `dft-logger-middleware-bump-advisor`
skills against this same change. Per the decision doc's Outcome section, a
`dft-logger` major "requires a coordinated release: both peers widen their
peer range (`^3.0.0`) and re-publish before consumers can adopt 3.x" — each
sibling's own peer-output gate determines whether it must ship a coordinated
major, minor, or nothing. Do not assume the caller will remember to do this
separately; append a line to the output naming both sibling skills whenever
this skill's own verdict is major.

### Step 4 — Ambiguous input: do not guess

The decision doc's own Option 2 tradeoff states this policy "requires human
judgment (tooling can't auto-detect an emitted-shape change from the
diff)." If the input doesn't clearly say whether the emitted `EventBody`
JSON (not just the TS type) changed, do not emit a single confident
recommendation. Instead:

```
Cannot classify with confidence: <what's missing — e.g. "diff shows a new
field on the internal Attributes builder but doesn't say whether it's
copied through into the serialized EventBody output">

Per the rubric, classifying an emitted-shape change requires confirming
whether the actual serialized JSON output changed (field names/values), not
just whether a TypeScript type changed. State that explicitly, then
re-run this advisor.
```

See `references/examples.md` for worked examples and validation against real history.

## When NOT to use

- The change is to `dft-logger-interceptors` or `dft-logger-middleware` —
  those are separate packages with their own decision docs and advisor
  skills (`dft-logger-interceptors-bump-advisor`,
  `dft-logger-middleware-bump-advisor`). A `dft-logger` major may force a
  bump in those packages via their own peer-output gates, but that
  assessment happens in *their* skill, not this one.
- You need to know whether a migration script is required for correctness
  — that's a `pr-check-migration-needed` concern, not this skill's.
- You want the release to actually happen — hand this skill's recommended
  specifier to `package-release`.

## Red flags

| Mistake | Fix |
|---|---|
| Treating this as generic "exported symbol" semver | The rubric governs **two** surfaces — TypeScript exports AND the emitted `EventBody`/`Attributes` JSON shape. A change can be MAJOR on emitted-shape grounds alone with zero TS-surface change. |
| Assuming "no TS type changed" means PATCH or MINOR | Check the emitted JSON separately — a field can be renamed in the serialized output without the TypeScript type itself changing (e.g. a runtime `JSON.stringify` key remap). |
| Mirroring the `v1.1.0` minor as precedent for "perf refactors are minor" | That release predates this rubric's adoption. Apply the current rubric — perf-only refactors with no signature/emitted-field change are PATCH. See Validation section. |
| Guessing whether an emitted-shape change occurred when the input only discusses TS types | Flag AMBIGUOUS per Step 4 — the decision doc explicitly says this "requires human judgment (tooling can't auto-detect an emitted-shape change from the diff)." |
| Skipping the mandatory-prerelease note for a MINOR emitted-shape addition | The prerelease gate applies to any transport/`BaseEventFormatter`/`EventBody`/`Attributes`-touching change, not just MAJORs — always check and append the note when applicable. |
| Applying this skill to `dft-logger-interceptors` or `dft-logger-middleware` changes | Out of scope — use their own advisor skills, which additionally handle the peer-output gate for a `dft-logger` major. |
| Stopping at this skill's own MAJOR verdict without triggering the peers | A `dft-logger` major doesn't automatically bump the peers, but it does require *assessing* them — always instruct the caller to run `dft-logger-interceptors-bump-advisor` and `dft-logger-middleware-bump-advisor` per the Step 3 coordination trigger. |

## Scope

Scoped to `@sgwshub/dft-logger` only, per FOUND-1838. Generalizing to read
any package's decision doc under `projects/FoundationSemver/decisions/` is
a candidate follow-up (see FOUND-1737), not covered here.

## Exit criteria

- [ ] A bump tier was produced, or an explicit AMBIGUOUS report with both interpretations —
  never a silent guess.
- [ ] The justification names the specific changed surface and quotes or closely
  paraphrases the matched rubric criterion.
- [ ] No edits were made to `package.json`, `CHANGELOG.md`, or `nx.json`.

## Provenance

Provenance: Hermes skill `learnings/skill-sharing` (corpus-wide porting authorship
attestation: ADR 0010).
Lineage: X-context-docs skills/dft-logger-bump-advisor@9d7143e
