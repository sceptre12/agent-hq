---
name: dft-mfe-generator-bump-advisor
description: Use when a PR diff, draft CHANGELOG entry, or free-text change description touches @sgwshub/dft-mfe-generator and a recommended semver bump (major/minor/patch) is needed before release — e.g. "what version bump does this need", "is this a breaking change for dft-mfe-generator", "classify this diff for semver", or ahead of running package-release's version-bump step on dft-mfe-generator. Advisory only — does not gate or modify the release pipeline.
---

# dft-mfe-generator Bump Advisor

## Overview

Given a diff or change description for `@sgwshub/dft-mfe-generator`, apply the
package's documented output-contract semver rubric and recommend
major/minor/patch with a one-line justification tied to the matched rubric
clause. Advisory only — the recommendation feeds into the `package-release`
skill's `--specifier` step; it never bumps a version or blocks a release
itself.

## Trigger

Use when a PR diff, draft CHANGELOG entry, or free-text change description for
`@sgwshub/dft-mfe-generator` needs a version-bump recommendation before release.

## Rubric source of truth — re-read, don't trust this snapshot forever

The rubric below is a snapshot for fast lookup. The authoritative rubric lives in:

```
~/projects/context-docs/projects/FoundationSemver/decisions/dft-mfe-generator.md
```

(mirrored on Confluence as "dft-mfe-generator Semver", page ID `2453274649`).
As of authoring, that doc's Outcome section is marked **"Approval pending"**.
Before relying on this skill for a real classification, re-read the source doc
(or re-scrape the Confluence mirror via `query-confluence` if it's stale) to
confirm the rubric hasn't been revised — e.g. Option 2 adopted instead, or the
approval resolved with changes. If the source doc disagrees with this file,
the source doc wins; flag the drift rather than silently using the stale copy.

## The core distinction: what is the versioned surface?

`dft-mfe-generator`'s public surface is **not** its npm exports —
`src/index.ts` exports only a handful of symbols and almost nobody imports
them programmatically. The real, consumer-observable contract is threefold:

1. **Generator schema / CLI options** — the flags and enums a consumer passes
   on `nx g @sgwshub/dft-mfe-generator:mfe ...` (`schema.json`).
2. **The shape of files scaffolded into consumer repos** — MF config, rspack
   wiring, generated runtime/logger, `project.json` tags,
   `generator-version.json`. This output lives in the consumer's repo
   *forever* after generation.
3. **`migrations.json`** — the `nx migrate` factory that retroactively fixes
   already-generated output, since generated output can't be re-run cleanly.

Because this is a generator, a change that alters scaffolded output can break
*already-generated* MFEs at build/runtime even when `src/index.ts` is
byte-identical. Output shape — not exports — is the dominant signal.

### Apply the rubric

| Tier | Fires when | Rubric clause (cite in justification) |
|---|---|---|
| **Major** | Removing/renaming a schema option, or a breaking enum/default change; OR the shape of scaffolded MF config, rspack wiring, or generated runtime bootstrap changes such that already-generated MFEs would break, AND no version-gated `migrations.json` factory covers it; OR a `dft-rspack-config` major bump that requires consumers to manually adopt a new host/rspack-config major (no automatic path) | "breaking output without an automatic migration is major" |
| **Minor** | New generator or new optional schema option with a backward-compatible default; OR scaffolded output changes but ships an idempotent, version-gated `migrations.json` factory (the `2-x-0` pattern); OR a `dft-rspack-config` pin bump to a new minor whose output change is migration-covered | "migration-covered/additive output is minor" |
| **Patch** | Fixes to the generator's own logic that don't change intended output shape; a bug-fix inside an *existing* migration factory (e.g. `2.2.1` fixing the `2-2-0` regex); doc/typo fix; a template fix restoring previously-documented behavior | "fixes to the generator's own logic that don't change intended output shape ... is patch" |

### Fallback: exports-only / internal-only changes

If the diff touches **only** `src/index.ts` exports or internal code, with no
change to schema options, scaffolded file shape, or `migrations.json` — do
**not** apply the major/minor output-shape criteria above. The source doc
explicitly rejected "Option 2" (code-export semver) as the primary basis for
this package. Default to **patch**, but still flag any breaking change to an
exported function signature or `*GeneratorSchema` type for manual review —
lower blast radius than an output break, but still a real consumer-facing
break worth a human look.

## Steps

1. Read the change description (PR diff, draft CHANGELOG entry, or free text).
2. Classify what's touched: schema options? scaffolded file shape (MF
   config / rspack wiring / generated runtime / tags /
   `generator-version.json`)? `migrations.json`? or exports/internal-only?
3. If scaffolded output changed, check whether a version-gated, idempotent
   `migrations.json` factory covers exactly that change.
   - Covered → **minor**.
   - Not covered → **major**.
4. If only schema options changed: removed/renamed/breaking enum-or-default
   change → **major**. New optional option with a backward-compatible
   default → **minor**.
5. If none of the above fired (internal logic fix, migration bug-fix,
   doc/typo, exports-only) → **patch**. Still flag an exported-signature
   break for manual review even under a patch recommendation.
6. If the diff mixes tiers (e.g. a patch-tier migration bug-fix bundled with a
   minor-tier new schema option), recommend the **highest** tier that fired
   and name every component in the justification — don't let a bundled
   patch-tier fix mask a minor/major one.
7. Watch for silent drift: a `@sgwshub/dft-rspack-config` pin bump changes
   this package's *effective* output with no diff line in this package
   itself. If the change description mentions a rspack-config pin bump, treat
   it as a scaffold-output change subject to steps 3–4 — never a no-op.
   Distinguish the two shapes this can take: a pin bump paired with a
   version-gated migration that brings existing consumers along
   automatically is **minor**; a pin bump onto a new host/rspack-config
   major that consumers must manually adopt — no automatic path — is
   **major**.
8. Output the recommendation in the format below.

### Output format

```
BUMP: major | minor | patch
Justification: <one line, semicolon-separated list of every matched rubric clause>
Manual review flag: <none | exported-signature break — <symbol/type name>>
```

See `references/examples.md` for worked examples (FOUND-1835 acceptance criteria).

## Red flags

| Mistake | Fix |
|---|---|
| Treating `src/index.ts` exports as the primary contract | The real contract is schema options + scaffolded output + `migrations.json` (see Core Distinction). Exports-only changes fall back to patch. |
| Assuming "has a migration" always means minor | A migration only downgrades an otherwise-major change to minor if it actually covers that specific breaking change. A partial or non-idempotent migration doesn't count as coverage. |
| Missing a `dft-rspack-config` pin bump as an output change | A pin bump changes effective output with no diff line in this package. Treat it as scaffold-output, not a no-op (step 7). |
| Trusting this skill's rubric snapshot indefinitely | Re-read the source decision doc (see Rubric source of truth) before relying on this copy — it can drift, especially while marked "Approval pending." |
| Letting this skill gate or auto-bump the release | Advisory only. Feed the `BUMP` output into `package-release`'s `--specifier=<patch|minor|major>` step; a human still reviews and approves the PR. |
| Picking the lowest tier in a mixed diff | Recommend the **highest** tier that fired across all changes in the diff (step 6). |

## Related skills

- `package-release` — this skill's `BUMP` output feeds its
  `--specifier=<patch|minor|major>` step; it does not replace that flow.
- `migration-assessment` — a related but distinct judgment: whether a change
  needs a **new migration script at all**, across `dft-mfe-generator` and
  `dft-web-monorepo-generator` (its currently-supported scope). This skill
  assumes that judgment is already made (or makes its own call in step 3)
  and asks the different question of which semver tier the change —
  migration-covered or not — belongs to, specifically for
  `dft-mfe-generator`.

## Scope

Scoped to `@sgwshub/dft-mfe-generator` only, per FOUND-1835. See sibling
`*-bump-advisor` skills (e.g. `dft-web-monorepo-generator-bump-advisor`,
`dft-api-client-bump-advisor`) for other de-foundations packages.

## Exit criteria

- [ ] A bump tier (major/minor/patch) was produced, with every matched rubric clause named
  (never the lowest tier in a mixed diff — step 6).
- [ ] A scaffold-output change states whether a version-gated `migrations.json` factory
  covers it before concluding minor vs. major.
- [ ] No edits were made to `package.json`, `CHANGELOG.md`, or `migrations.json`.

## Provenance

Provenance: Hermes skill `learnings/skill-sharing` (corpus-wide porting authorship
attestation: ADR 0010).
Lineage: X-context-docs skills/dft-mfe-generator-bump-advisor@9d7143e (trimmed:
canonicalized a stale `context-docs-worktrees/foundation-semver/...` rubric path to the
real `~/projects/context-docs/...` path)
