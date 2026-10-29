---
name: dft-feature-flags-react-bump-advisor
description: >
  Use when a change to @sgwshub/dft-feature-flags-react (a diff, PR
  description, changelog entry, or a summarized list of changed
  exports/behaviors) needs a version-bump recommendation before release.
  Triggers include "what bump does this need", "major or minor for
  dft-feature-flags-react", "classify this dft-feature-flags-react change",
  or preparing a conventional-commit / release for dft-feature-flags-react —
  including any @splitsoftware/splitio or @splitsoftware/splitio-react
  dependency bump inside it. Advisory only — does not modify package.json or
  CHANGELOG; see package-release for the actual bump/publish flow.
model: sonnet
---

# dft-feature-flags-react Bump Advisor

Classify a described change to `@sgwshub/dft-feature-flags-react` as
**major**, **minor**, or **patch** by applying the package's documented
rubric, and output the specifier plus a one-line justification tied to the
exact rubric criterion matched.

**Advisory only.** This skill never edits `package.json`, `CHANGELOG.md`, or
`nx.json`. For the actual bump/tag/publish mechanics, use the
`package-release` skill (`~/.claude/skills/package-release/SKILL.md`).

## Trigger

Use when a diff, PR description, or free-text change summary for `@sgwshub/dft-feature-flags-react` needs a version-bump recommendation before release.

## Rubric source of truth

Confluence page **"dft-feature-flags-react Semver"** (page ID `2453700612`)
is the durable primary source — read it via the `query-confluence` skill.
It is mirrored in the de-foundations context-docs repo at
`~/projects/context-docs/projects/FoundationSemver/decisions/dft-feature-flags-react.md`
(Outcome section) for local/offline reference; that local mirror may live in
a feature-branch worktree rather than `main` at any given time, so treat the
Confluence page as authoritative if the two ever disagree. If this skill's
output ever looks wrong, re-read the Confluence page first; the rubric below
is a faithful transcription of its substance, not necessarily a word-for-word
quote, and the page wins over this file.

`@sgwshub/dft-feature-flags-react`'s public surface (`src/index.ts`):

- **`useFeatureFlag(flagName: string)`** — returns
  `{ treatment: string; isReady: boolean; isEnabled: boolean }`. `isEnabled`
  is defined as `treatment === 'on'`. Swallows errors and returns a safe
  `{ treatment: 'control', isReady: false, isEnabled: false }` fallback.
- **`FeatureFlagProvider`** — props
  `{ userIdentifier: string; splitIoClientKey: string; siteId?: string; children? }`.
  Throws if `userIdentifier` or `splitIoClientKey` is missing.
- **`FlaggedComponent`** — props
  `{ flagName: string; renderFlagged: () => ReactElement<…>; renderLoading?: () => ReactNode; children? }`.
- **`getGlobalSplitFactory()` / `setGlobalSplitFactory(factory)`** —
  read/write the shared `SplitIO.IBrowserSDK` factory on
  `window[Symbol.for('SGWS_GLOBAL_SPACE')].splitFactory`.

Two contracts beyond the TypeScript signatures matter: (1) the **string
treatment convention** (`'on'` = enabled, `'control'` = error/undefined
fallback), and (2) the **`SGWS_GLOBAL_SPACE` window shape** — an implicit
cross-MFE integration contract other code reads/writes directly.

Both Split packages (`@splitsoftware/splitio`, `@splitsoftware/splitio-react`)
are ordinary **`dependencies`** (bundled), not peer deps — a Split SDK
upgrade ships *inside* this package, and this wrapper re-exposes the ambient
`SplitIO.IBrowserSDK` type, so the Split SDK's type surface leaks into this
package's public API. This is the central policy question the rubric
resolves.

## Steps

### Step 1 — Read the change

Take whatever the caller supplies: a git diff, a PR description, a
changelog entry, or a free-form summary of changed exports/behavior. If it's
a raw diff, focus on:
- `src/index.ts` is a barrel file only — it just re-exports from
  `src/client/`. The actual prop shapes, return shapes, and behavior live in
  the implementation files: `src/client/useFeatureFlag.ts`,
  `src/client/FeatureFlagProvider.tsx`, `src/client/FlaggedComponent.tsx`,
  `src/client/getGlobalSplitFactory.ts`. Also check `src/constants.ts` and
  `src/global.d.ts` (the actual `SGWS_GLOBAL_SPACE` window-shape
  declaration). A diff can change a required prop or the window shape while
  leaving `src/index.ts` untouched — don't rely on the barrel file alone. The
  compiled `dist/index.d.ts` is the fallback if only build output is
  available.
- `package.json` `dependencies["@splitsoftware/splitio"]` /
  `dependencies["@splitsoftware/splitio-react"]` version changes — note
  whether the bump is major, minor, or patch
- Whether the change description includes an explicit verification
  statement for a Split **major** bump (see the escalation rule in Step 2)
- Behavior-only changes with no exported-signature diff (bugfixes, internal
  refactors, SSR/timing fixes)

### Step 2 — Apply the rubric

Check criteria in this order — **MAJOR first**, then MINOR, then PATCH — and
stop at the first match. A change can satisfy multiple criteria; always
report the highest bump among all matches (see Step 3 for mixed changes
instead of silently picking the lower one).

### MAJOR — any contract break
- Removing or renaming an exported symbol (`useFeatureFlag`,
  `FlaggedComponent`, `FeatureFlagProvider`, `get/setGlobalSplitFactory`)
- Changing a component's required props or `useFeatureFlag`'s return shape
- Redefining `isEnabled` (currently `treatment === 'on'`) or the `'control'`
  fallback semantics
- Changing the `SGWS_GLOBAL_SPACE` window shape
- A `@splitsoftware/splitio*` **major** bump that reshapes the leaked
  `SplitIO.IBrowserSDK` type or alters treatment/runtime semantics — **or**
  where the change description does not explicitly confirm those are
  unchanged (see the escalation rule below: absence of verification means
  you cannot classify as minor)

### MINOR — purely additive surface, existing usage unchanged
- A new exported hook/component
- A new *optional* prop (e.g. a new optional `FeatureFlagProvider` config
  field)
- A new field on `useFeatureFlag`'s return object
- A `@splitsoftware/splitio*` **major** bump that has been *explicitly
  verified* not to change `IBrowserSDK`, the `'on'`/`'control'` convention,
  or the provider prop contract

### PATCH — bugfix with no exported signature or contract change
- No change to any exported prop, return shape, or the two behavioural
  contracts
- Examples from the doc: the `1.0.1` `FlaggedComponent children` default
  fix, error-fallback correctness, SSR/`useEffect` timing fixes
- `@splitsoftware/splitio*` **patch/minor** bumps (e.g. `splitio
  11.8→11.11`, logged as `chore`)

### Hard escalation rule (Split major bumps)

This is the sharp edge of the whole rubric — a `@splitsoftware/splitio*`
**major** version bump is **never** automatically minor. It requires an
explicit statement in the change description confirming all three of:
`IBrowserSDK` shape unchanged, `'on'`/`'control'` treatment convention
unchanged, and `FeatureFlagProvider`/`SplitFactoryProvider` prop contract
unchanged.

- Verification statement present and affirmative → **MINOR**.
- Verification statement present and says something changed → **MAJOR**.
- No verification statement at all (silence, not confirmation) → treat as
  **MAJOR** per the "or where the change description does not explicitly
  confirm" MAJOR criterion above. Do not default to minor just because the
  Split bump wasn't described as breaking — the rubric requires proof, not
  absence of evidence.

### Step 3 — Handle ambiguous or mixed changes

If the described change touches **both** an internal-only path and an
exported signature/type/contract — or you cannot tell from the input
whether an exported symbol or the Split escalation rule is affected — do not
silently pick the lower bump. Report:

```
AMBIGUOUS — cannot classify with confidence.
Reason: <what's mixed or missing>
Highest-bump interpretation: <major|minor|patch>, because <criterion>
Lowest-bump interpretation: <major|minor|patch>, because <criterion>
Recommend: request the dist/index.d.ts diff, the specific exported symbol
list, or (for a Split major) the explicit IBrowserSDK/treatment/prop
verification statement before finalizing the release bump.
```

### Step 4 — Output format

For unambiguous classifications, output exactly:

```
Recommended bump: <major|minor|patch>
Justification: <one line, name the specific export/symbol/behavior changed
and quote or closely paraphrase the matched rubric criterion>
Rubric source: Confluence "dft-feature-flags-react Semver" (page ID 2453700612)
```

See `references/examples.md` for worked examples and validation against real history.

## Red flags

| Mistake | Fix |
|---|---|
| Treating a Split major bump as minor by default because it "seems fine" | The escalation rule requires an *explicit* verification statement (IBrowserSDK, treatment convention, provider props all unchanged) before it can be minor — silence means MAJOR, not "probably minor" |
| Classifying a Split dependency bump purely by its own semver | Only a non-breaking Split patch/minor bump is PATCH; a Split **major** always triggers the escalation rule regardless of what changed in this package's own code |
| Picking the lower bump when a change is genuinely mixed | Use Step 3 — report AMBIGUOUS and both interpretations instead of guessing |
| Assuming this skill also performs the release | It does not — it is advisory only; hand the recommended specifier to `package-release` for the actual bump/publish |
| Treating the initial-release commit as a normal PATCH/MINOR/MAJOR case | An initial release (`0.0.1-0 → 1.0.0`) is a baseline, not a diff against a prior public surface — classify it separately, don't force it through the break/additive/bugfix criteria |

## Scope

Scoped to `@sgwshub/dft-feature-flags-react` only, per FOUND-1836.
Generalizing to read any package's decision doc under
`projects/FoundationSemver/decisions/` is a candidate follow-up, not covered
here.

## Exit criteria

- [ ] A bump tier was produced, or an explicit AMBIGUOUS report with both interpretations —
  never a silent guess.
- [ ] The justification names the specific changed surface and quotes or closely
  paraphrases the matched rubric criterion.
- [ ] No edits were made to `package.json`, `CHANGELOG.md`, or `nx.json`.

## Provenance

Provenance: Hermes skill `learnings/skill-sharing` (corpus-wide porting authorship
attestation: ADR 0010).
Lineage: X-context-docs skills/dft-feature-flags-react-bump-advisor@9d7143e
