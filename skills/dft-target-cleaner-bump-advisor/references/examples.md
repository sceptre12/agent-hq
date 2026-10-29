## Worked examples (from FOUND-1837 acceptance criteria)

**Scenario 1 — major bump, behavioral matching change**
> Given: a change description stating that `pathingGroupsToClean` prefix
> matching now also matches on `basename`, altering which targets get
> no-op'd for an existing, unchanged config.

```
Recommended bump: major
Justification: Changes pathingGroupsToClean's prefix-matching rule to also
match on basename, altering which targets get no-op'd for an unchanged
config → matches the "alters which projects/targets get no-op'd for an
unchanged config" MAJOR criterion.
Rubric source: ~/projects/context-docs/projects/FoundationSemver/decisions/dft-target-cleaner.md
Note: behavioral changes require a golden-fixture test proving the
before/after no-op'd-target diff before this bump is finalized.
```

**Scenario 2 — minor bump, new opt-in config key**
> Given: a change description stating a new optional config key, e.g.
> `matchMode`, is added to `TargetCleanerSchema` and is inert unless
> explicitly enabled.

```
Recommended bump: minor
Justification: Adds a new optional matchMode key to TargetCleanerSchema that
is inert unless enabled → matches the "new opt-in config keys or match modes
that are inert unless enabled" MINOR criterion.
Rubric source: ~/projects/context-docs/projects/FoundationSemver/decisions/dft-target-cleaner.md
Note: this package is pre-1.0 — per semver 0.y convention, a MINOR bump can
still carry breaking changes until a deliberate 1.0.0 is declared. Confirm
this MINOR is genuinely additive/inert before relying on it as non-breaking.
```

**Scenario 3 — patch bump, non-behavioral fix**
> Given: a change description stating a dependency version bump or internal
> refactor of `cleanTarget.ts` that keeps the matching outcome identical for
> all existing configs.

```
Recommended bump: patch
Justification: Internal refactor of cleanTarget.ts / dependency bump with no
change to the matching outcome for any existing config → matches "fixes that
keep the matching outcome identical for all existing configs, docs, perf,
internal refactors" PATCH criterion. cleanTarget.ts is execution-only
mechanics (Step 1), so this does not touch "matching logic" and no
golden-fixture note is required.
Rubric source: ~/projects/context-docs/projects/FoundationSemver/decisions/dft-target-cleaner.md
```

## Validation against real history

Cross-checked against `packages/dft-target-cleaner/CHANGELOG.md`:
- **v0.1.1** (FOUND-496 + FOUND-857) — shared-workspace-dependency and MFE
  generator build-dependency-resolution fixes — build/dependency wiring, not
  matching-outcome logic — actual bump **patch** — matches the PATCH
  criterion ("fixes that keep the matching outcome identical... internal
  refactors").
- **v0.1.0** (ECOP-1150) — extraction of the plugin into a standalone
  package — this is the package's initial extraction/release, not a change
  against a prior matching-outcome baseline, so the rubric's tiers don't
  cleanly apply; treated as out-of-scope for this rubric rather than forced
  into a tier.

**Open question — no real MAJOR example exists yet.** Both real historical
bumps for this package (`0.1.0`, `0.1.1`) are non-behavioral. No
behavioral-matching change that would trigger a MAJOR bump has actually
shipped for `dft-target-cleaner`, per FOUND-1837's own Notes/Open Questions.
**The MAJOR case above (Scenario 1) is a synthetic/hypothetical worked
example, not validated against real history** — treat this skill's MAJOR
classification as sound per the rubric's stated rules, but currently
untested against a real-world case. Re-validate against the CHANGELOG once a
real behavioral-matching change ships.

