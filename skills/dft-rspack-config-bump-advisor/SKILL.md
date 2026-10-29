---
name: dft-rspack-config-bump-advisor
description: >
  Use when a described change to @sgwshub/dft-rspack-config (a PR diff, change
  summary, or list of modified exports/defaults/templates) needs a semver bump
  classification before choosing major/minor/patch for a release or PR review.
---

# dft-rspack-config Bump Advisor

## Overview

Classifies a described change to `@sgwshub/dft-rspack-config` against its
documented behavior-first SemVer rubric and outputs a recommended specifier
(`major` | `minor` | `patch`) with a one-line justification naming the
matched rubric criterion and the affected consumption channel.

This skill is advisory only: it never modifies the package's version,
`package.json`, or `CHANGELOG.md`, and it never runs a release. It is a
pre-release input to the `package-release` skill, not a replacement for it.

**Authoritative rubric source:** Confluence page "dft-rspack-config Semver"
(page ID 2453569538). Every criterion in the Step 2 table below is taken
verbatim from that page's Action Items section (the bulleted major/minor/patch
list) and its Outcome section (the "Recommended policy" paragraph). To
spot-check the table against the source, re-read those two sections on the
Confluence page and diff them against Step 2 — if that page's Action Items or
Outcome section change, this skill's Step 2 table must be re-derived from it.

## Trigger

Invoke this skill whenever someone needs a semver recommendation for a change
to `@sgwshub/dft-rspack-config` before a release decision is finalized —
typically one of:

- A PR author or reviewer classifying a diff before choosing a conventional-commit
  type (`feat`/`fix`/`!:`) for the PR title or commit message.
- A release planner deciding what specifier to pass into the `package-release`
  skill for this package (this skill's output is an input to that skill, not
  a step inside it — run this skill first, then hand its `Specifier` value to
  `package-release` manually).
- Anyone auditing a historical CHANGELOG entry for this package against the
  documented rubric (see Historical Validation Notes below).

This skill takes a change description as input and returns text (a specifier
+ justification). It does not read git history, run any commands, or write to
any file — the caller supplies the description and consumes the output.

## Why behavior-first, not literal semver

`@sgwshub/dft-rspack-config` reaches consumers through two distinct channels
with two different blast radii:

| Channel | What lives here | How it reaches consumers |
|---|---|---|
| **Caret-shipped** | Plugins/utils exported from `.` and `./utils` (`withDefinePlugin`, `withEjsIndexTemplate`, `withNeatTheme`, `withTsConfigResolution`, `withVersionJson`, `getAuthToken`, `getRspackTemplatesPath`, `isZephyrBuild`) | `dft-mfe-generator` pins `^0.5.1`; any new minor/patch is picked up on the next `pnpm install` / lockfile refresh, with **no code change** in the consuming app |
| **Template-only** | `./files/*.template` EJS templates (`rspack.base.config.ts.template`, `rspack.config.ts.template`, `.prod`, `.prodS3`, `.e2e`, `.analysis`) | Copied as source into a generated app **only at scaffold time** (a frozen snapshot); edits here affect newly generated apps, not existing ones |

Because the caret channel silently fans a change out to every existing app on
next install, the rubric classifies by **what the change does to consumers
already on the caret range**, not by whether an API type signature literally
changed.

**Version-number note:** the package shipped a baseline reset to `1.0.0` on
2026-07-16 (a non-semver-mandated reset, not a stability declaration — see
`CHANGELOG.md`). Before and after that reset, the same behavior-first rubric
applies unchanged: literal `1.x` stability guarantees do not retroactively
apply, and the pre-reset `0.x` history does not mean "anything goes" either.
Apply Step 1–3 exactly the same way regardless of which side of the 1.0.0
reset the current version sits on (see Historical Validation Notes below for
where shipped tags and this rubric already diverge, independent of the
reset).

## Steps

### Step 1 — Classify by channel

For each discrete piece of the change, decide which channel it flows through:

- **Caret-shipped**: touches a `.` or `./utils` export, or changes the
  default behavior/output of a `with*` plugin.
- **Template-only**: touches only `./files/*.template` content, and does not
  also change a shipped plugin default.

A change can touch both channels at once (e.g. a template edit that also
flips a plugin default) — see Step 3.

### Step 2 — Apply the rubric

| Tier | Criteria (any one match qualifies) |
|---|---|
| **major** (`!:` / breaking) | Remove or rename an export or subpath · Change a `with*` option or return type incompatibly · Flip or remove a shipped default that changes build output or runtime for existing apps (e.g. `includeDefaults`, `enableMocking` resolution, `resolve.extensions` order, `withVersionJson` field rename/removal, `isZephyrBuild` default flip) · Raise a peerDependency to a new major (`@rspack/core`, `@nx/rspack`) |
| **minor** (`feat`) | Add a new plugin/util/export · Add a new optional option with a backward-compatible default · Add a new `.template` file or new opt-in behavior · Extend `VersionJsonData` additively |
| **patch** (`fix`) | Bug fix that restores documented behavior · Internal refactor with no observable change · Doc/test-only changes to shipped behavior descriptions |

Match the change to the **most severe** tier that applies — a change
matching both a minor and a major criterion is major.

### Step 3 — Ambiguous or mixed-channel changes

If a change touches both channels (per Step 1), do **not** collapse it into
one unexplained recommendation:

1. Classify the caret-shipped piece against Step 2.
2. Classify the template-only piece against Step 2.
3. Recommend the **higher (more conservative)** of the two tiers.
4. Report both classifications separately in the output, even though only
   the higher one is the final recommendation.

If the change description doesn't say clearly which channel a piece flows
through, don't guess — surface the ambiguity and ask the author to clarify
which channel is affected, rather than silently picking a tier. Use the
"Ambiguity surfaced" output format below, not the normal or mixed-channel
format, when this happens.

## Output format

**Normal (single-channel, unambiguous) change:**

```
Specifier: major | minor | patch
Justification: "<rubric criterion matched>" — <channel: caret-shipped | template-only>
```

**Mixed-channel change (both channels identified in the description):**

List both channel classifications before the final (higher) recommendation —
see Example 4.

**Ambiguity surfaced (channel cannot be determined from the description):**

Do not emit a `Specifier` line at all — a specifier implies a resolved
classification, and none exists yet. Instead:

```
Ambiguity: cannot classify — channel unclear
Missing information: <what the description fails to state, e.g. "does this
  change also alter a shipped plugin default, or is it template-only?">
Clarification needed: <specific question for the author, e.g. "Does this
  template edit also change the wiring order or defaults in
  rspack.base.config.ts.template's basePlugins list, or is it purely additive
  to the template?">
```

Once the author answers, re-run Step 1–3 with the clarified description and
emit the normal or mixed-channel format above.

See `references/examples.md` for worked examples and validation against real history.

## Red flags

| Mistake | Fix |
|---|---|
| Classifying by API type signature alone | Classify by observable behavior delivered to consumers on the caret channel — a types-only change can still be a major if it breaks callers, and a same-signature change can still be a major if a default flips |
| Treating template-only changes as always safe | Template edits are minor by default (new-app-facing), but if they also alter a default that affects existing apps, that piece is caret-shipped and must be classified separately at the higher tier |
| Silently picking the lower tier on a mixed change | Always report both channel classifications and take the higher (more conservative) tier — never collapse without explanation (Step 3) |
| Deferring to the package's `nx release ... patch` script as policy | That script is a hard-coded convenience default, not a semver policy — always run the rubric regardless of what the release script defaults to |
| Assuming the literal version number (0.x or the 1.0.0 baseline reset) changes the rubric | The behavior-first rubric applies identically on both sides of the 1.0.0 reset — neither pre-1.0 "anything goes" nor post-1.0 stability guarantees override it (see "Version-number note" above) |
| Matching history instead of the rubric during validation | Historical shipped tags (e.g. 0.7.0, 0.6.4) already diverge from this rubric — report the divergence, don't quietly conform the recommendation to match precedent |
| Guessing which channel an under-specified change flows through | If the description doesn't say, surface the ambiguity and ask for clarification — don't silently assume a channel |

## Cross-references

- Source rubric: Confluence "dft-rspack-config Semver" (page ID 2453569538)
- `dft-mfe-generator` (`de-foundations/packages/dft-mfe-generator`) — the
  consumer whose `^0.5.1` caret pin on this package is the reason the
  caret-shipped channel exists at all; its
  `src/mfe/helpers/constants.ts` pins the range and
  `createRspackConfigs.ts` is what copies the template snapshot at scaffold
  time. Read this package's pin and template-copy logic if a change's
  channel is unclear from the description alone.
- `package-release` skill (`~/.claude/skills/package-release/SKILL.md`) —
  this skill is a pre-release advisory step, invoked *before* and separately
  from `package-release`: run this skill first to get a `Specifier`, then
  hand that value to `package-release` manually as its bump-type input. This
  skill does not call `package-release` and `package-release` does not call
  this skill — there is no automatic handoff between them today.
- Jira: FOUND-1832 (this skill's originating ticket) · FOUND-1737 (parent
  epic — tailored semver policy rollout across de-foundations packages)

## Exit criteria

- [ ] A `Specifier` (major/minor/patch) was produced, or an `Ambiguity` block naming the
  missing channel information — never a silent guess.
- [ ] A mixed-channel change reports both channel classifications before the final
  (higher) recommendation.
- [ ] No edits were made to `package.json`, `CHANGELOG.md`, or any `.template` file.

## Provenance

Provenance: Hermes skill `learnings/skill-sharing` (corpus-wide porting authorship
attestation: ADR 0010).
Lineage: X-context-docs skills/dft-rspack-config-bump-advisor@9d7143e
