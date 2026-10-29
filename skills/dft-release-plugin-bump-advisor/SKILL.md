---
name: dft-release-plugin-bump-advisor
description: >
  Use when a change to @sgwshub/dft-release-plugin (a diff, PR description, or a
  summarized list of changed executor logic/behavior) needs a version-bump
  recommendation before release. Triggers include "what bump does this need",
  "major or minor for dft-release-plugin", "classify this dft-release-plugin
  change", or preparing a conventional-commit / release for dft-release-plugin.
  Advisory only — does not modify package.json, CHANGELOG, or nx.json, and does
  not perform the mandatory all-packages dry-run/sign-off gate; see
  package-release for the actual bump/publish flow.
model: sonnet
---

# dft-release-plugin Bump Advisor

Classify a described change to `@sgwshub/dft-release-plugin` as **major**,
**minor**, or **patch** by applying the package's documented rubric, and
output the specifier plus a one-line justification tied to the exact rubric
criterion matched.

**Advisory only.** This skill never edits `package.json`, `CHANGELOG.md`, or
`nx.json`, and never runs or substitutes for the all-packages `--dryRun` +
human sign-off gate the rubric recommends before any release of this package.
That gate is currently an unchecked action item on the rubric doc, not yet
implemented as tooling — do not assume it exists elsewhere just because this
skill defers to it. For the actual bump/tag/publish mechanics, use the
`package-release` skill (`~/.claude/skills/package-release/SKILL.md`); as of
this writing that skill's dry-run step previews a single package, not an
all-packages dry-run, so verify its current state before assuming it closes
this gap.

## Why this package is different from every other advisor

Every other de-foundations package uses standard conventional-commit mapping
(`fix:`→patch, `feat:`→minor, `!:`→major) verbatim. `@sgwshub/dft-release-plugin`
does **not**: it is the NX release-automation engine registered globally in
`nx.json`, injecting `version`/`release` targets into ~20 packages under
`packages/*`, and it releases **itself** with the exact logic it ships (a
change to its own release logic is only proven correct on the *next* release
cycle, after the old published engine has already shipped it). A mistake here
is silently fleet-wide, not contained to one package. **The override rule:
any change to release-affecting behavior or the public contract is major,
regardless of the commit prefix the author chose.** Do not let a `fix:` or
`feat:` prefix in the input override this — that prefix is exactly what the
rubric says to ignore for this package.

## Trigger

Use when a diff, PR description, or free-text change summary for `@sgwshub/dft-release-plugin` needs a version-bump recommendation before release.

## Rubric source of truth

`context-docs/projects/FoundationSemver/decisions/dft-release-plugin.md`
(Outcome + Action items sections) — mirrored on Confluence as "dft-release-plugin
Semver" (page ID `2453471264`). If this skill's output ever looks wrong,
re-read that file first; the rubric below is a verbatim transcription, not a
paraphrase, and if the two ever disagree the doc wins.

**Path note:** the doc lives directly in this skill's own worktree at
`projects/FoundationSemver/decisions/dft-release-plugin.md` — no
worktree-hopping needed. If you read it from the plain `~/projects/context-docs`
main checkout and get a 404, that checkout is simply behind origin/main (it
was observed one commit behind, missing the merge that added this doc); the
fix is to `git pull` there, not to search other worktrees.

`@sgwshub/dft-release-plugin`'s public contract: the `createNodes` glob (which
packages get targets injected), the injected `version`/`release` target
names/shapes, the two executor option schemas (`version`: `specifier`,
`preid`, `dryRun`; `release`: `dryRun`), and above all the
**version-computation and gating semantics**: bump inference
(`inferSpecifierFromCommits`), tag topology (`getLatestReachableTag`),
prerelease graduation, disk-as-source-of-truth, the main-vs-prerelease branch
gates, dist-tag mapping, and tag creation/collision logic in
`version.ts`/`release.ts`.

## Steps

### Step 1 — Read the change

Take whatever the caller supplies: a git diff, a PR description, or a
free-form summary of changed behavior. Identify whether it touches any of:
- `src/executors/version/version.ts` — bump inference, prerelease graduation,
  disk-as-truth, preid derivation, first-release detection
- `src/executors/release/release.ts` — branch/version gates, dist-tag
  mapping, tag creation/collision guard, publish flow
- The `createNodes`/`createNodesV2` glob or injected target names/shapes
- The executor option schemas (`specifier`, `preid`, `dryRun` for `version`;
  `dryRun` for `release`)
- Anything else (docs, tests-only, internal refactor with no behavior change)

Also note the author's chosen commit prefix (`feat:`/`fix:`/`!:`) if given —
you will need it in Step 2 to demonstrate you are *not* deferring to it when
the always-major override applies.

### Step 2 — Apply the rubric

Check criteria in this order — **the always-major override first**, then
MAJOR, then MINOR, then PATCH — and stop at the first match.

### ALWAYS MAJOR — overrides commit prefix, checked first
The rubric names these as major signals **regardless of commit prefix**. If
the change touches any of these, the answer is major even if the diff "looks
additive" or the author wrote `fix:`/`feat:`. This bucket applies only to
changes that alter behavior in these files/areas — a change confined to
comments, docs, or test-only code inside these same files/functions (no
behavior change) does not trigger this bucket; classify it per Step 1's
"docs, tests-only" category instead:
- `inferSpecifierFromCommits` (bump-inference logic/regexes)
- `getLatestReachableTag` (tag-topology resolution)
- The prerelease-graduation branch in `version.ts`
- The branch/version gates in `release.ts` (main-vs-prerelease enforcement)
- The dist-tag mapping in `release.ts` (`latest` vs prerelease id)
- The `createNodes`/`createNodesV2` glob
- Injected target names (`version`, `release`) or their shapes
- Either executor's option schema (`specifier`, `preid`, `dryRun`)

### MAJOR — any other release-affecting behavior or contract change
- Any change to version-computation semantics not already listed above
  (e.g. disk-as-source-of-truth logic, `extractTicketId` preid derivation —
  see note below on this one)
- Tag creation/collision-guard logic changes
- Anything that changes what version, dist-tag, or gate outcome an existing
  release would produce — "even when the diff looks additive"

**Known rubric ambiguity — `extractTicketId`:** the rubric doc's "Relevant
data" section calls `extractTicketId`'s regex "part of the contract" in the
same breath as `inferSpecifierFromCommits`, but the doc's own explicit
always-major list (Action Items) omits `extractTicketId`. This skill places
it in the plain MAJOR tier above, not the ALWAYS MAJOR tier — the recommended
bump is major either way, so this only affects which justification text you
cite. Treat this as an open question against the rubric doc itself rather
than assuming this skill's tiering choice is authoritative — surface it as an
explicit note in the PR review comment / classification output you produce
for this skill invocation, don't silently "fix" it here.

**Known rubric ambiguity — disk-as-source-of-truth and tag-creation/collision
logic:** the "Rubric source of truth" section above lists disk-as-source-of-truth
and tag creation/collision-guard logic as part of the "above all" load-bearing
contract, in the same breath as the explicit ALWAYS MAJOR touch-points. But
the ALWAYS MAJOR checklist in Step 2 omits both — they only appear in the
plain MAJOR tier (`disk-as-source-of-truth logic`, `Tag creation/collision-guard
logic changes`). The recommended bump is major either way under either tier,
so this only affects which justification text and rubric clause you cite.
Treat this the same way as the `extractTicketId` ambiguity above: don't
silently resolve it as this skill's tiering being authoritative — surface it
as an explicit note in the PR review comment / classification output you
produce for this skill invocation.

### MINOR — new backward-compatible capability, no change to existing outcomes
- A new opt-in executor option that defaults to today's existing behavior
- A new log line or diagnostic with no behavioral effect
- Any addition that provably does not change any *existing* release's
  computed version/dist-tag/gate outcome

### PATCH — fixes behavior to match documented intent, zero outcome change
- Typo or error-message wording fixes
- Internal refactor with characterization-test proof that no currently-correct
  release outcome changes
- Applies **only** when there is no change to any currently-correct release
  outcome — if you cannot confirm that, do not default to patch; escalate per
  Step 3

### Step 3 — Handle ambiguous or mixed changes

If the described change is too sparse to confirm whether a currently-correct
release outcome changes, or it mixes a listed always-major touch-point with
what looks like an unrelated cosmetic fix, do not default to the lower bump.
Report:

```
AMBIGUOUS — cannot classify with confidence.
Reason: <what's mixed or missing>
Highest-bump interpretation: <major|minor|patch>, because <criterion>
Lowest-bump interpretation: <major|minor|patch>, because <criterion>
Recommend: request the specific diff to src/executors/version/version.ts or
src/executors/release/release.ts (or characterization-test results) before
finalizing the release bump.
```

### Step 4 — Output format

For unambiguous classifications, output exactly:

```
Recommended bump: <major|minor|patch>
Justification: <one line naming the specific function/gate/behavior changed
and quoting or closely paraphrasing the matched rubric clause>
Rubric source: context-docs/projects/FoundationSemver/decisions/dft-release-plugin.md
```

If the always-major override applied, the justification must say so
explicitly and must not cite or defer to the commit prefix — see Scenario 2
below for the exact phrasing expected.

See `references/examples.md` for worked examples and validation against real history.

## Red flags

| Mistake | Fix |
|---|---|
| Deferring to a `fix:`/`feat:` commit prefix when the diff touches an always-major touch-point | The rubric's override is explicit: these signals are major "regardless of commit prefix" — never let the prefix downgrade the bump |
| Treating an additive-looking diff (e.g. a new branch in an if/else, a simplified code path) as automatically minor/patch | The rubric says "even when the diff looks additive" — additive *shape* does not mean additive *behavior*; check whether any release outcome changes |
| Classifying purely by which file changed without checking whether the change is docs/tests-only | Only release-affecting behavior or contract changes trigger major/minor — pure docs or test-only changes in these files are not automatically major |
| Defaulting to patch when you can't confirm zero release-outcome change | Patch requires proof (characterization test or clear reasoning) of zero outcome change — if you can't confirm it, use Step 3's AMBIGUOUS path instead |
| Assuming this skill also performs the release or the mandatory dry-run gate | It does not — it is advisory only; hand the recommended specifier to `package-release`, and the mandatory all-packages `--dryRun` + human sign-off gate remains a separate, required step before any release of this package |

## Scope

Scoped to `@sgwshub/dft-release-plugin` only, per FOUND-1834. Generalizing to
read any package's decision doc under
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
Lineage: X-context-docs skills/dft-release-plugin-bump-advisor@9d7143e
