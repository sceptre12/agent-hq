---
name: dft-monorepo-mfe-setup
description: >
  Use when scaffolding a new NX monorepo with MFEs using the SGWS dft generators
  (@sgwshub/dft-web-monorepo-generator and @sgwshub/dft-mfe-generator). Covers
  the full setup flow including known generator bugs, Module Federation wiring
  fixes, Zephyr Cloud configuration, and required manual steps in app.zephyr-cloud.io.
  Trigger when Xavier says: "set up a new monorepo", "scaffold MFEs", "use dft generators",
  "initialize a new web monorepo", or "set up Zephyr for a new repo".
---

## Model Usage

This skill is **MIXED** — mechanical command steps are Haiku-eligible; judgment/debugging
steps require Sonnet — and it deliberately carries **no `model:` or `context: fork` field**
at the skill level. Two reasons:

1. **A whole-skill `model:`/`context: fork` can't express "mixed."** `model:` alone (no
   fork) only overrides the *current turn's* reasoning model — it resumes the session
   model on the very next turn, so it can't carry a Haiku pin across this skill's many
   steps anyway. `context: fork` runs the *entire* skill body as one isolated subagent's
   task with no access to the calling conversation, which would strand Steps 4-6: they
   need to see what was actually scaffolded in Steps 1-3 (app names, ports, remote names
   chosen) and make judgment calls building on it — that context does not survive a fork
   boundary, and forcing the whole skill into one fork would also break Step 6's need to
   walk Xavier through a manual, synchronous dashboard flow.
2. **Per-step delegation belongs to the orchestrating agent, not to frontmatter.** The
   agent running this skill (normally Sonnet, since Steps 4-6 need it) decides per step,
   using the annotations below, whether to do the step itself or delegate it out.

Steps eligible for Haiku delegation (pure command execution): **1, 2, 3, 7, Known Issues lookup**
Steps requiring Sonnet (judgment/diagnosis): **4, 5, 6**

**For a Haiku-eligible step, delegate it with the Agent tool** — not a Bash `claude -p`
re-exec (that spawns an untracked nested process with no result-passing back into this
session and defeats normal orchestration):

```
Agent({
  subagent_type: "general-purpose",
  model: "haiku",
  description: "Run <step name> of dft-monorepo-mfe-setup",
  prompt: "<the exact commands/instructions for that step, verbatim from below>"
})
```

Wait for that agent's report, verify the step's own "Verify" commands, then continue to
the next step in this same (Sonnet) session — Steps 4-6 depend on knowing exactly what
the delegated steps produced (app names, ports, generated file paths).

---

# DFT Monorepo + MFE Setup

## Overview

End-to-end process for initializing a new NX monorepo with the SGWS dft generator
suite and wiring Module Federation across a host + N remote MFEs via Zephyr Cloud.

**Core principle:** The generators have several known bugs and quirks that will break
a naive run. Follow this guide exactly to avoid them.

---

## Trigger

Use when scaffolding a new NX monorepo with MFEs using the SGWS dft generators
(`@sgwshub/dft-web-monorepo-generator` and `@sgwshub/dft-mfe-generator`) — "set up a new
monorepo", "scaffold MFEs", "use dft generators", "initialize a new web monorepo", or
"set up Zephyr for a new repo".

## Prerequisites

Before running any commands:

- Node.js 22.x via nvm.
  **Stopgap sibling-repo dependency:** activation currently borrows the `.nvmrc` from
  `~/projects/dgc-dev-proof-ecomm-web` (`cd ~/projects/dgc-dev-proof-ecomm-web && nvm use`)
  until the new repo has its own `.nvmrc`. This breaks if that repo is moved, renamed, or
  deleted. If the path is missing, fall back to `nvm use 22 || nvm install 22` wherever a
  step says to `cd` there. To retire the stopgap entirely, add an `.nvmrc` containing `22`
  to the new repo as an early setup step and use `nvm use` from the new repo instead.
- pnpm 9.x (available after nvm activation)
- GitHub PAT with `read:packages` scope in `~/.npmrc`:
  ```
  @sgwshub:registry=https://npm.pkg.github.com
  //npm.pkg.github.com/:_authToken=YOUR_PAT
  ```
  Copy from an existing project if needed: `cat ~/projects/dgc-dev-proof-ecomm-web/.npmrc`
- Zephyr Cloud account at https://app.zephyr-cloud.io (see Zephyr section below)
- GitHub org access to `sgwshub`

**Verify auth before starting:**
```bash
# sibling-repo nvm stopgap — see Prerequisites note if this path is missing
cd ~/projects/dgc-dev-proof-ecomm-web && nvm use && \
  pnpm view @sgwshub/dft-web-monorepo-generator version && \
  pnpm view @sgwshub/dft-mfe-generator version
```
Both must return version strings. 401/403 = expired PAT, replace it.

---

## Steps

### Step 1 — Initialize monorepo

`create-nx-workspace` **always creates a new directory** — it cannot scaffold in-place.
Use a temp dir strategy to get scaffold files into an existing repo:

> **Haiku-eligible:** Pure command execution — if running on Sonnet, delegate via the Agent tool (`model: "haiku"`, `subagent_type: "general-purpose"`), passing this step verbatim as the prompt. See the Model Usage section above.

```bash
# 1. Generate into temp dir (NOT inside the target repo)
cd ~/projects
pnpm dlx create-nx-workspace@20.3.3 \
  --preset=@sgwshub/dft-web-monorepo-generator \
  --pm=pnpm \
  --name=YOUR-REPO-NAME-scaffold \
  --ci=skip

# 2. Copy scaffold into existing repo (preserves .git)
cp -r ~/projects/YOUR-REPO-NAME-scaffold/. ~/projects/YOUR-REPO-NAME/
rm -rf ~/projects/YOUR-REPO-NAME-scaffold

# 3. Install
cd ~/projects/YOUR-REPO-NAME && pnpm install
```

**Known generator bug:** The generator may write `"@sgwshub/dft-web-monorepo-generator": null`
(no version) in the generated `package.json`, causing pnpm to crash with
`Cannot read properties of null (reading 'startsWith')`.

Fix: Set the version manually in `package.json`, run `pnpm install`, then run the preset
generator directly:
```bash
pnpm nx generate @sgwshub/dft-web-monorepo-generator:preset
```

**Verify generator ran correctly:**
```bash
grep 'apps/' pnpm-workspace.yaml          # must show - 'apps/*'
grep -i "dft-\|plugin" nx.json            # must show dft plugin references
```

---

### Step 2 — Install MFE generator

> **Haiku-eligible:** Pure command execution — if running on Sonnet, delegate via the Agent tool (`model: "haiku"`, `subagent_type: "general-purpose"`), passing this step verbatim as the prompt. See the Model Usage section above.

```bash
# sibling-repo nvm stopgap — see Prerequisites note if this path is missing
cd ~/projects/dgc-dev-proof-ecomm-web && nvm use && cd ~/projects/YOUR-REPO-NAME
pnpm add -D -w @sgwshub/dft-mfe-generator @nx/react@20.3.3
```

`@nx/react` **must be pinned to `20.3.3`** — it is an exact peer dep. Do not use `@latest`.

---

### Step 3 — Scaffold MFEs

Port convention: host = 4200, remotes = 4210, 4220, 4230 (increment by 10).

> **Haiku-eligible:** Pure command execution — if running on Sonnet, delegate via the Agent tool (`model: "haiku"`, `subagent_type: "general-purpose"`), passing this step verbatim as the prompt. See the Model Usage section above.

Scaffold the host **and** its remotes together in a single command, using `--remotes`. This is the generator-supported path that auto-wires Module Federation. Do **not** scaffold the host first and then try to add remotes to it afterward with `--addToHost` — that sequence throws, because `--addToHost` only works when the target host does not exist yet (see the corrected-model note above; tracked in FOUND-3767).

```bash
pnpm nx g @sgwshub/dft-mfe-generator:mfe apps/myShell \
  --type=host --port=4200 --remotes=myRemoteA,myRemoteB

pnpm install
```

`--remotes` on the host generator creates `myRemoteA` and `myRemoteB` as remotes (ports auto-assigned starting at 4210) and wires both into the host automatically — see Step 4 to verify.

**Do NOT pass `--scope` to host or remote types** — `scope` only applies to `remoteState`
type with values `cross-feature` or `feature-specific`. Passing `--scope=ui` will error
or be silently ignored.

After the generator runs:
```bash
pnpm nx reset && pnpm nx sync
```

**Adding a remote to a host later, after this step, is currently unsupported by the generator.** `--addToHost=myShell` on a new remote will throw once `myShell` already exists — there is no generator-supported way to add a remote to an already-scaffolded host (tracked in FOUND-3767). Until that's fixed, that case is 100% manual on both `module-federation.config.ts` and `src/remotes.d.ts` — see Step 4's manual path.

---

### Step 4 — Verify Module Federation wiring (or wire it manually if adding to an already-existing host)

> **Sonnet required:** Requires judgment about correct configuration — do not delegate to Haiku.

**If you scaffolded the host with `--remotes` in Step 3** (the normal case), the generator has already wired everything — verify it, don't redo it:

```bash
grep -A2 "remotes" apps/myShell/module-federation.config.ts
# Expected: remotes: ['myRemoteA', 'myRemoteB'],  (name-only strings)

cat apps/myShell/src/remotes.d.ts
# Expected: declare module 'myRemoteA/Module'; and declare module 'myRemoteB/Module';
```

No manual edit is needed in this case.

**If you're instead trying to add a remote to a host that was already scaffolded in a previous run** — the `--addToHost` flag does not support this (see Step 3; tracked in FOUND-3767) — you must wire both files by hand:

```ts
// apps/myShell/module-federation.config.ts
// ✅ CORRECT — name-only, no URLs
remotes: ['myRemoteA', 'myRemoteB'],

// ❌ WRONG — full URL causes extractUrlAndGlobal runtime error
remotes: [
  ['myRemoteA', 'http://localhost:4210/remoteEntry.js'],
],

// ❌ ALSO WRONG — localhost URL without /remoteEntry.js still breaks Zephyr resolution
remotes: [
  ['myRemoteA', 'http://localhost:4210'],
],
```

NX's `mapRemotes` helper handles URL resolution — passing any URL (with or without
`/remoteEntry.js`) interferes with it. Use name-only strings.

```ts
// apps/myShell/src/remotes.d.ts
declare module 'myRemoteA/Module';
declare module 'myRemoteB/Module';
```

---

### Step 5 — Wire remotes into the host app

> **Sonnet required:** Requires judgment about correct configuration — do not delegate to Haiku.

The generator scaffolds `app.tsx` with static placeholder content. Replace it with
actual remote rendering using React Router:

```tsx
import { lazy, Suspense } from 'react'
import { NavLink, Route, Routes } from 'react-router-dom'

const MyRemoteA = lazy(() => import('myRemoteA/Module'))
const MyRemoteB = lazy(() => import('myRemoteB/Module'))

export function App() {
  return (
    <div>
      <nav>
        <NavLink to="/">Home</NavLink>
        <NavLink to="/remote-a">Remote A</NavLink>
        <NavLink to="/remote-b">Remote B</NavLink>
      </nav>
      <Suspense fallback={<div>Loading...</div>}>
        <Routes>
          <Route path="/" element={<Home />} />
          <Route path="/remote-a" element={<MyRemoteA />} />
          <Route path="/remote-b" element={<MyRemoteB />} />
        </Routes>
      </Suspense>
    </div>
  )
}
```

`react-router-dom` v6 and `BrowserRouter` are already installed and wired in
`bootstrap.tsx` by the generator. Mock remotes in tests:
```ts
jest.mock('myRemoteA/Module', () => () => <div>MyRemoteA</div>)
```

---

### Step 6 — Zephyr Cloud setup (MANUAL — cannot be automated)

> **Sonnet required (to guide the manual step):** The dashboard actions below must be done
> by a human — no model tier can perform them, so this is not automatable regardless of model.
> Sonnet is required for the agent-side work around them: walking Xavier through the dashboard
> steps, applying the `zephyr:dependencies` / tsconfig config, and diagnosing `ZE40003` fallout
> if resolution still fails. Do not delegate to Haiku.

> ⚠️ **This step requires manual action in https://app.zephyr-cloud.io**

Zephyr requires a configured environment before remote dependency resolution works.
Without this, builds show `ZE40003` errors and remotes won't resolve at runtime.

**Required manual steps:**

1. Go to https://app.zephyr-cloud.io
2. Find your application group (matches your repo/org name)
3. Create a new **environment** (e.g. `demo`, `staging`, `production`)
4. Set that environment as the **default environment** for resolving remote linkages
   when no other environment is specified

Once the environment is created, add `zephyr:dependencies` to each **host** app's
`package.json` pointing remotes at that environment tag:

```json
{
  "name": "myShell",
  "version": "0.0.1",
  "private": true,
  "zephyr:dependencies": {
    "myRemoteA": "myRemoteA@DEMO",
    "myRemoteB": "myRemoteB@DEMO"
  }
}
```

Also add TypeScript project references to the host's `tsconfig.json` and
`tsconfig.app.json` so the compiler resolves the remote types:

```json
// tsconfig.json references array — add before existing entries
{ "path": "../myRemoteA" },
{ "path": "../myRemoteB" }

// tsconfig.app.json references array
{ "path": "../myRemoteA/tsconfig.app.json" },
{ "path": "../myRemoteB/tsconfig.app.json" }
```

**Verify Zephyr resolved remotes after next build:**
```
ZEPHYR   Resolved remotes:
ZEPHYR     myRemoteA → https://demo-myremotea-...ze.southernglazers.com/remoteEntry.js
ZEPHYR   Resolved zephyr dependencies: myRemoteA, myRemoteB
```
If you still see `ZE40003`, the environment was not set as default in Zephyr Cloud.

---

### Step 7 — Build and deploy to Zephyr

> **Haiku-eligible (after first-time auth):** Once OAuth is done, builds are pure command
> execution — if running on Sonnet, delegate via the Agent tool (`model: "haiku"`,
> `subagent_type: "general-purpose"`), passing the build commands verbatim as the prompt.
> The one-time browser OAuth below is interactive and must be completed by a human — do not
> delegate that part to any agent.

First-time auth — run this interactively (agents cannot complete browser auth):

```bash
# sibling-repo nvm stopgap — see Prerequisites note if this path is missing
cd ~/projects/dgc-dev-proof-ecomm-web && nvm use && cd ~/projects/YOUR-REPO-NAME
pnpm nx run myShell:build:production
# When prompted: "You can hit Enter to open it up on your browser" → hit Enter
# Complete OAuth in browser
```

Once authenticated, builds can be run via agents:
```bash
pnpm nx run myRemoteA:build:production --skip-nx-cache
pnpm nx run myRemoteB:build:production --skip-nx-cache
pnpm nx run myShell:build:production --skip-nx-cache
```

Zephyr prints a live URL per build:
```
ZEPHYR   https://xavier-thomas-sgws-com-XXXX-myshell-...ze.southernglazers.com
```

---

## Known Issues & Fixes

| Issue | Symptom | Fix |
|-------|---------|-----|
| Generator null version bug | `Cannot read properties of null ('startsWith')` | Manually set version in package.json, run `pnpm install`, run `nx g :preset` directly |
| Wrong MF remote format | `extractUrlAndGlobal is not a function` at rspack runtime | Use name-only strings in remotes array, not URLs |
| ZE40003 on host build | `Failed to resolve remote dependency` | Create environment in app.zephyr-cloud.io, set as default, add `zephyr:dependencies` to host package.json |
| Zephyr auth timeout | `ZE10018: Failed to authenticate` | Run build interactively, hit Enter when prompted, complete browser OAuth |
| `--scope=ui` error | Silent fail or schema error on generator | Remove `--scope` entirely for host/remote types |
| `--nxCloud=skip` flag | Generator hangs or ignores flag | Use `--ci=skip` instead |
| Nested scaffold directory | Scaffold lands in `repo/repo/` | Run generator from parent dir into temp name, then `cp -r` into repo root |
| ESLint flat-config `ignores` narrowing (`nx migrate latest`) | `src/__tests__/**` starts failing lint that previously passed (observed in `header`, `footer`) after `@nx/eslint:convert-to-flat-config` runs | Legacy `ignorePatterns: ['__tests__']` was recursive; flat-config `ignores: ['__tests__']` is not — widen to `ignores: ['**/__tests__/**']`. Diff a full `nx run-many -t lint --all` before/after the migration to catch other affected projects |
| Flat-config default preset enables new rules (`nx migrate latest`) | New unrelated lint errors appear post-migration, e.g. `prefer-const` in `common/scripts/setup-certs` | Not a code regression — flat-config's `flat/javascript` preset enables rules the old `.eslintrc.json` didn't. Fix the flagged code if trivially correct, or disable the specific rule per-file/project in `eslint.config.mjs` |

**Note on the two ESLint flat-config rows above:** both are core Nx behaviors (not `@sgwshub/dft-web-monorepo-generator` or `@sgwshub/dft-mfe-generator` issues) — they will recur on **any** repo running `nx migrate latest` through an ESLint 8→9 flat-config conversion, regardless of which `@sgwshub` generators are involved. Always run a full `nx run-many -t lint --all` (not just `nx affected`) immediately after any core Nx migration that touches ESLint config, and diff the result against a pre-migration baseline lint run, before assuming the migration succeeded cleanly.

---

## Quick Verification Checklist

After full setup, these should all pass:

```bash
# All targets green
pnpm nx affected -t lint test typecheck build --base=main --head=HEAD

# MF config uses name-only remotes
grep "remotes" apps/myShell/module-federation.config.ts
# Expected: remotes: ['myRemoteA', 'myRemoteB']

# Zephyr resolved remotes in build log
pnpm nx run myShell:build:production --skip-nx-cache 2>&1 | grep "Resolved remotes"
```

## Network Unavailable

This skill makes outbound network calls: npm registry at `npm.pkg.github.com` (package resolution and downloads via `pnpm`), and Zephyr Cloud at `app.zephyr-cloud.io` (MFE deployment and registration).

If network connectivity is unavailable when this skill is invoked:
- Do not attempt `pnpm install`, `pnpm add`, `pnpm dlx`, or any Zephyr Cloud operations
- Log or echo: `[SKIPPED] network unavailable — dft-monorepo-mfe-setup skipped`
- Exit 0 in script/automated contexts
- If running interactively: inform the user that setup cannot proceed without network access (npm registry and Zephyr Cloud are both required) and suggest retrying when connectivity is restored

To verify connectivity before running: use the `network-check` skill.

## Red flags

| Rationalization | What to do instead |
|---|---|
| "I'll scaffold the host first, then add remotes with `--addToHost`." | `--addToHost` only works when the target host doesn't exist yet (FOUND-3767) — scaffold host + remotes together with `--remotes` in one command. |
| "I'll pass a full URL in the remotes array." | Use name-only strings (`remotes: ['myRemoteA']`) — any URL form breaks `mapRemotes`/`extractUrlAndGlobal` at runtime. |
| "I'll pass `--scope=ui` to the host/remote generator." | `--scope` only applies to `remoteState` type — passing it to host/remote errors or is silently ignored. |
| "ZE40003 showed up, I'll just retry the build." | ZE40003 means the Zephyr environment wasn't set as default — fix it in app.zephyr-cloud.io, retrying won't help. |
| "I'll delegate Step 6's Zephyr dashboard clicks to an agent." | Those are manual human actions in app.zephyr-cloud.io — no model tier can perform them; only the agent-side guidance around them is delegatable (and only to Sonnet). |
| "I'll run `nx affected` instead of `nx run-many --all` after an Nx migration." | Flat-config ESLint migrations can affect projects `nx affected` won't catch — run a full `nx run-many -t lint --all` and diff against the pre-migration baseline. |

## Exit criteria

- [ ] `pnpm nx affected -t lint test typecheck build --base=main --head=HEAD` passes.
- [ ] `module-federation.config.ts` uses name-only remote strings, confirmed by grep.
- [ ] A production build's output shows `ZEPHYR Resolved remotes:` for every remote, not
  a `ZE40003` error.

## Provenance

Provenance: Hermes skill `learnings/skill-sharing` (corpus-wide porting authorship
attestation: ADR 0010).
Lineage: X-context-docs skills/dft-monorepo-mfe-setup@9d7143e
