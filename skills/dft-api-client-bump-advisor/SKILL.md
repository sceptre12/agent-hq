---
name: dft-api-client-bump-advisor
description: >
  Use when a change to @sgwshub/dft-api-client (a diff, PR description, or a
  summarized list of changed exports/behaviors) needs a version-bump
  recommendation before release. Triggers include "what bump does this need",
  "major or minor for dft-api-client", "classify this dft-api-client change",
  or preparing a conventional-commit / release for dft-api-client. Advisory
  only — does not modify package.json or CHANGELOG; see package-release for
  the actual bump/publish flow.
model: sonnet
---

# dft-api-client Bump Advisor

Classify a described change to `@sgwshub/dft-api-client` as **major**,
**minor**, or **patch** by applying the package's documented rubric, and
output the specifier plus a one-line justification tied to the exact rubric
criterion matched.

**Advisory only.** This skill never edits `package.json`, `CHANGELOG.md`, or
`nx.json`. For the actual bump/tag/publish mechanics, use the `package-release`
skill.

## Trigger

Use when a diff, PR description, or free-form summary of a change to
`@sgwshub/dft-api-client` needs a version-bump recommendation before release.

## Rubric source of truth

`~/projects/context-docs/projects/FoundationSemver/decisions/dft-api-client.md`
(Outcome section) — mirrored on Confluence as "dft-api-client Semver" (page ID
`2454388737`, re-scrapeable via `query-confluence` if the local copy looks
stale). If this skill's output ever looks wrong, re-read that file first; the
rubric below is a faithful transcription of its Outcome section, restructured
into bullets for scannability — if the two ever disagree in substance, the
doc wins.

`@sgwshub/dft-api-client`'s public surface (`src/index.ts`): the `ApiClient`
class (constructor takes `InstanceConfigs`; method `formatUrlAndParams`
returns `{ formattedUrl, params }` synchronously; methods `get`, `post`,
`put`, `patch`, `delete` each return a curried
`(data, requestConfig) => Promise<AxiosResponse>`), the interceptor/retry
types in `instance/_types.ts` (`InstanceConfigs`, `RequestInterceptor`,
`ResponseInterceptor`, `RequestErrorInterceptor`, `ResponseErrorInterceptor`,
`ErrorRetryCheck`, `RetryErrorContext`, `InterceptorErrorCause`), the
`enableThrowErrorOnError` opt-in config field, a module augmentation of
axios's `AxiosRequestConfig`, the `DEFAULT_HEADERS` constant, the
`nullReplacementResponseInterceptor`, and subpath exports `./instance`,
`./interceptors`. Axios is a pinned runtime dependency whose types are
augmented, so the **axios major version is part of the contract**.

## Steps

1. **Read the change.** Take whatever the caller supplies: a git diff, a PR
   description, or a free-form summary of changed exports/behavior. If it's a
   raw diff, focus on: any file under `src/index.ts`, `src/instance/`,
   `src/interceptors.ts` (or their compiled `dist/*.d.ts` equivalents);
   `package.json` `dependencies.axios` version changes; and behavior-only
   changes with no exported-signature diff (bugfixes, internal refactors).

2. **Apply the rubric.** Check criteria in this order — **MAJOR first**, then
   MINOR, then PATCH — and stop at the first match. Checking MAJOR first
   means the first match found is always the highest-bump match, by
   construction — you never need to keep scanning after a MAJOR hit. Step 3
   covers the separate case where the description doesn't give you enough to
   tell whether it touches a higher-bump criterion at all — don't resolve
   that uncertainty by silently picking the lower bump.

   **MAJOR — any break to the contract:**
   - Removing or renaming an exported symbol (a class, method, type,
     constant, or subpath export)
   - Changing an `ApiClient` method signature or its curried return shape
   - Narrowing or reshaping any interceptor type (`RequestInterceptor`,
     `ResponseInterceptor`, `RequestErrorInterceptor`,
     `ResponseErrorInterceptor`, `ErrorRetryCheck`)
   - Changing `DEFAULT_HEADERS`
   - Altering default retry semantics (the `maxRetries` default of 1, or the
     retry-then-re-run-interceptors flow)
   - Bumping the **axios major** version (its augmented `AxiosRequestConfig`
     types are part of this package's API)

   **MINOR — purely additive surface, behavior of existing calls unchanged:**
   - A new exported interceptor
   - A new optional field on `InstanceConfigs` or the `AxiosRequestConfig`
     augmentation (e.g. a new opt-in capability alongside `errorRetryCheck`)
   - A new `ApiClient` method
   - A widened (more-permissive) type on an existing export

   **PATCH — bugfix with no exported signature or type change:**
   - No change to any exported signature or type
   - Examples from the doc: the ESM/CJS `getAxiosWithCreate` interop fix,
     retry `_retryCount` accounting fixes, `nullReplacementResponseInterceptor`
     correctness fixes, non-breaking axios **patch/minor** bumps, internal
     refactors

3. **Handle ambiguous or mixed changes.** If the described change touches
   **both** an internal-only path and an exported signature/type — or you
   cannot tell from the input whether an exported symbol is affected — do not
   silently pick the lower bump. Report:

   ```
   AMBIGUOUS — cannot classify with confidence.
   Reason: <what's mixed or missing>
   Highest-bump interpretation: <major|minor|patch>, because <criterion>
   Lowest-bump interpretation: <major|minor|patch>, because <criterion>
   Recommend: request the `dist/*.d.ts` diff (or the specific exported symbol
   list) before finalizing the release bump.
   ```

4. **Output format.** For unambiguous classifications, output exactly:

   ```
   Recommended bump: <major|minor|patch>
   Justification: <one line, name the specific export/symbol/behavior changed
   and quote or closely paraphrase the matched rubric criterion>
   Rubric source: ~/projects/context-docs/projects/FoundationSemver/decisions/dft-api-client.md
   ```

See `references/examples.md` for worked examples (FOUND-1823 acceptance
criteria) and validation against the package's real release history.

## Red flags

| Rationalization | What to do instead |
|---|---|
| "Type-only narrowing has no runtime impact, so it's minor/patch." | Type-only changes to exported types are still MAJOR under this rubric — downstream packages break at compile time with no runtime signal. |
| "I'll classify an axios dependency bump by the semver of the bump alone." | Only a non-breaking axios patch/minor bump is PATCH; an axios **major** bump is always MAJOR here, regardless of what changed in dft-api-client's own code. |
| "This change is genuinely mixed, I'll just pick the lower bump." | Use Step 3 — report AMBIGUOUS and both interpretations instead of guessing. |
| "I should also just apply the bump myself." | This skill is advisory only — hand the recommended specifier to `package-release` for the actual bump/publish. |

## Exit criteria

- [ ] A bump tier (major/minor/patch) was produced, or an explicit AMBIGUOUS
  report with both interpretations — never a silent guess.
- [ ] The justification names the specific changed export/symbol/behavior and
  quotes or closely paraphrases the matched rubric criterion.
- [ ] No edits were made to `package.json`, `CHANGELOG.md`, or `nx.json`.

## Scope

Scoped to `@sgwshub/dft-api-client` only, per FOUND-1823, one of the
per-package skills under the parent epic FOUND-1737 ("Roll out tailored
semver policy for de-foundations packages"). Generalizing to read any
package's decision doc under `projects/FoundationSemver/decisions/` is a
candidate follow-up, not covered here.

## Provenance

Provenance: Hermes skill `learnings/skill-sharing` (corpus-wide porting
authorship attestation: ADR 0010).
Lineage: X-context-docs skills/dft-api-client-bump-advisor@9d7143e
