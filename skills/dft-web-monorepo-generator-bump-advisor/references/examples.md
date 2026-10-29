## Worked examples (from FOUND-1830 acceptance criteria)

**Scenario 1 — major bump, shape-breaking emitted output**
> Given: a change description that alters the emitted `nx.json` or
> `package.json` shape such that an existing generated workspace could not
> adopt it without intervention.

```
Recommended bump: major
Justification: Changes the emitted nx.json/package.json shape in a way an
existing generated workspace cannot self-adopt → matches the "any change to
emitted output that existing workspaces cannot adopt without intervention"
MAJOR criterion.
Migration required: yes
Rubric source: context-docs/projects/FoundationSemver/decisions/dft-web-monorepo-generator.md
```

**Scenario 2 — minor bump, additive emitted config**
> Given: a change description that adds a new optional dotfile, a new
> optional schema property, or bumps a pinned dependency's minor version.

```
Recommended bump: minor
Justification: Adds a new optional dotfile/schema property (or a dep minor
bump) with no change to existing generated shape → matches the "additive
emitted config / dep minor bump" MINOR criterion.
Migration required: optional
Rubric source: context-docs/projects/FoundationSemver/decisions/dft-web-monorepo-generator.md
```

**Scenario 3 — patch bump, non-shape-changing fix**
> Given: a change description limited to typo fixes, formatting, a
> dependency patch bump, an internal refactor, or a doc-only change.

```
Recommended bump: patch
Justification: Fixes a typo/formatting issue (or an internal refactor) with
no change to emitted shape → matches the "fixes to generated content that
don't change shape" PATCH criterion.
Migration required: no
Rubric source: context-docs/projects/FoundationSemver/decisions/dft-web-monorepo-generator.md
```

## Validation against real history

Cross-checked against `packages/dft-web-monorepo-generator/CHANGELOG.md` in
de-foundations:

- **2.0.0** (2026-05-29, FOUND-1194) — migration factories v1.2.1 → v2.0.0:
  `.npmrc` changes (`package-manager-strict-version`, `engine-strict`),
  Husky post-checkout hook replaced, generator package relocated from
  `dependencies` to `devDependencies` — emitted shape changes existing
  workspaces cannot self-adopt, shipped with a paired migration factory —
  actual bump **major** — matches the shape-breaking MAJOR criterion.
- **2.3.0** (2026-06-24, FOUND-1555 per git history; CHANGELOG entry itself
  omits the ticket) — pins `dft-sonarqube-executor` to exact `1.1.0` and
  bumps `dft-sonarqube-plugin` to `^1.1.0`, via an additive dep-pin migration
  touching existing repos — actual bump **minor** — matches the
  dep-minor-bump MINOR criterion (migration present because it touches
  existing repos, consistent with "optional unless it touches existing
  repos").
- **2.0.1** (2026-06-03, FOUND-1194) — fixes worktree path contamination in
  `known-repos.json`, a bug fix with no emitted-shape change — actual bump
  **patch** — matches the no-shape-change PATCH criterion.
- **2.4.0** (2026-07-13, FOUND-1228) — migration `2-4-0` pins
  `dft-sonarqube-executor` to exact `1.2.0` in consumer repos (picks up the
  `packages/` base-directory fix) and pins newly scaffolded workspaces to
  the same version — an exact dep-pin migration touching existing repos —
  actual bump **minor** — matches the dep-minor-bump MINOR criterion
  (migration present because it touches existing repos).
- **2.4.1** (2026-07-22, FOUND-1228) — removes a stale disk-based
  precondition in migrations `2-3-0`/`2-4-0` that broke multi-hop
  `nx migrate --run-migrations` runs; a bug fix inside existing migrations'
  own internal bookkeeping with no emitted-shape change — actual bump
  **patch** — matches the "fixes to logic that doesn't touch emitted output"
  PATCH criterion.
- **2.5.0** (2026-07-26, FOUND-1882) — migration `2-5-0` extends
  peer-dependency drift protection by re-running the `2-1-0`
  lockfile-resolved dep-pinning pass with `peerDependencies` in scope,
  idempotently re-freezing drifted peer-resolved versions across migration
  hops — an additive change to existing migration logic touching existing
  repos — actual bump **minor** — matches the general MINOR heading
  ("additive emitted config, or a dep minor bump"); an edge case that
  doesn't literally match one of the four enumerated MINOR sub-bullets,
  since it extends existing migration logic to reach already-generated
  workspaces rather than bumping a literal dependency version number
  (migration present because it touches existing repos).

