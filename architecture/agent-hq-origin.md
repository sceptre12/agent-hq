# agent-hq origin — architecture

One-line summary: how agent-hq was carved out of the owner's private `hq` repo as a sanitized, machine-neutral
copy of the agent rules, tooling and settings, what was configured afterwards, and how the repo is worked day to day.

- **Status:** descriptive record, written 2026-10-28 against `main` at `7840774`. Not an authority: on conflict the
  ADRs in `decisions/`, `config/CLAUDE.md` and `architecture/hq-code-gate.md` win.
- **Scope of this record:** WHAT/WHY (ADR 0011). Sources are the repo itself and the Claude Code session transcripts
  cited below by UUID prefix and date. Transcript timestamps are UTC; commit dates are the committer's local date.
- **Session key:** `c502cd4c` (desk session, 2026-10-22 to 10-25, the creation session); `5028202c` and `ac4c270d`
  (the two executor workers, 2026-10-22); `6b3c8e56` (2026-10-23, a fresh-agent probe started inside agent-hq);
  `8adadfef` (desk, 2026-10-25 onward); `f10369a8` (Worker2, 2026-10-25 onward); `c17bda54` (Worker1 orchestrator,
  2026-10-25 onward: delivery workflow, history rewrite, clone consolidation); `439830c4` and `7607cd9a`
  (2026-10-27, delivery-pilot conductor and lead sessions).

## 1. Why agent-hq exists

`hq` is the owner's private command-center repo: rules, standards, ADRs, project records, learnings, plans and
personal tooling, full of machine paths and personal project names. On 2026-10-22 the owner asked for a second repo
(`c502cd4c`, 16:16Z, paraphrased): one that "somewhat mirrors hq" with no personal information at all; general rules
and standards for how agents operate, not specific to one machine; the owner's Claude settings minus the MCP servers;
and the tooling. Two constraints shaped everything after it:

- **No rule rewrites.** "don't create new rules or transform other rules". Files were copied byte-identical; the only
  edits allowed were owner-approved removals or placeholder substitutions of personal strings, plus retargeting.
- **Executors do the writing.** The desk session planned and verified; the two permission-skipped worker sessions
  copied and edited, constrained to material that already existed in hq.

### What came over, and what stayed in hq

| Came over (sanitized) | Stayed in hq (deliberately) |
|---|---|
| `config/CLAUDE.md` cut to its Rules sections (Rules 1–7, 9–13) | Rule 8 (a Notion rule) and everything from "User Preferences" down (owner D3, 2026-10-22) |
| `config/settings.json`: global settings minus MCP entries and 46 project-specific permission entries | MCP server config; project-derived allow/ask/autoMode entries (owner D7) |
| `config/tiers/executor.json`, `desk.json`, overlays README, with `$HOME` paths (owner D6) | personal-project tier overlays |
| `STANDARDS.md`, `INVARIANTS.md` + runner, retargeted to agent-hq and trimmed to present subjects (owner D2; 2026-10-23 trim ruling) | the 12 invariants whose subject was not copied (`projects/`, `memory/`, standing holds, …) |
| `architecture/` records for topology, permission tiers, Hermes, swarm bus, code gate, reviews | project records, `plans/`, `learnings/`, `retros/`, `inbox/`, `references/` (incl. the context-docs reference) |
| `skills/`, `agents/`, `tools/` (code gate, git hooks, cprof, Hermes tooling, trust, container-exec) | `skills/new-context-project`, `skills/skill-export` (owner D1, "Drop both"); `tools/brain/` launcher (D5); `tools/task-pipeline/` (dropped 2026-10-22: its fixtures carried a third-party project name); named-profile files (D4) |
| a sanitized ADR subset in `decisions/` (`7ee4e92`, 2026-10-25) | the rest of hq's ADRs |

Later, the delivery-workflow skill family and its design (`architecture/delivery-workflow/`) were built directly in
agent-hq; the records of the first pilot run of that workflow were kept in hq, not here (`c17bda54`, 2026-10-28).

## 2. Creation timeline (2026-10-22 to 2026-10-23)

Shas below are on current `main`. Sessions before the 2026-10-27 rewrite (§4) cite different, pre-rewrite shas.

1. **Audit and copy rules** (`c502cd4c`, 16:16–16:58Z). The desk's audit of 652 candidate files found most core files
   held a few personal strings. Owner ruling (16:26Z): include clean files, keep references working, carry over no
   personal or personal-project work. Rulings at 16:36Z and 17:04Z added permission tiers (paths made generic),
   STANDARDS (GitHub name removed), the Hermes architecture, agent topology and the pr-review references, all sanitized.
   Worker1 copied rules/docs, Worker2 copied tools and filtered settings; the desk diffed every file against hq.
2. **Orphan pass and cohesion audits** (owner request 16:34Z). A reference graph was built and files whose referrers
   were all skipped were proposed for deletion, with owner approval first. Four audits (tools, skills, rules, settings)
   ran in parallel; the hook fixture suite passed 44/44 from the new repo.
3. **Ten owner decisions, one at a time** (owner request 18:08Z, answers 18:21–19:46Z): D1 drop the two hq-only skills;
   D2 retarget defaults to agent-hq and trim INVARIANTS; D3 rules only in `config/CLAUDE.md`; D4 leave out named-profile
   files; D5 leave out `tools/brain/`; D6 bring tier files with `$HOME`; D7 drop project-derived settings entries;
   D8 prune stale `test-map.tsv` rows; D9 delete three orphans; D10 name `agent-hq`, create the remote now. Two follow-ups
   the same evening: drop `tools/task-pipeline` (23:18Z) and replace remaining profile names with placeholders (23:27Z).
4. **Bootstrap commit and remote** — `81051d0` (2026-10-22), pushed to a private GitHub repo with `core.hooksPath`
   set to `tools/git-hooks`. The pre-push hook refuses to create `main` on an empty remote, so that one push, and one
   follow-up push of `main` that fixed the gate's repo slug, ran with the hook overridden (`c502cd4c`, 23:31Z and
   2026-10-23 01:35Z). Invariant 29 later got a root-commit exemption (`49b4a2a`, 2026-10-25).
5. **PR #1, gate repo slug** — `64e2fdc`, `c7c3e0d`, merged as `be6ccaa` with `Code-Gate-PR: #1`. Owner ruling
   (2026-10-23 01:23Z): hard-code the agent-hq repo slug in `tools/code-gate/lib.sh`. PR #1 had no review marker at
   merge; its retroactive review findings were fixed forward in PR #7 (`962b707`, 2026-10-26).
6. **Entry point** — root `README.md` and `CLAUDE.md` copied from hq with dead folder-map rows removed (owner,
   2026-10-23 01:54Z): `d2011eb`, merged `8859d81`.
7. **Fresh-agent probe loop** (owner, 2026-10-23 01:52Z: point a new agent at the repo and see whether it can get up
   to speed). The first attempt (`6b3c8e56`) stopped at "Not logged in"; the probe was then run from the desk session.
   Round-1 fixes: STANDARDS trimmed to present subjects and folder maps completed (`1bacf63`, merged `63abe35`); tools
   fixes (`0203816`, PR #2, merged `8579022`). Owner ruling (02:39Z): the built-in code review counted as the review for
   the gate, because the swarm bus that `pr-review` needs was not yet set up for agent-hq.
8. **Vendored swarm bus** (owner, 2026-10-23 02:49Z: copy the bus code into `tools/`). `cb6727e`, merged `3de3fcd`;
   skills point at the in-repo copy. Owner ruling (03:10Z): exclude it from the code gate, "no need to review something
   thats already stable" — `ca4ef51`/`09c28cf`, PR #3, merged `708cb7c`.
9. **Sandboxed temp dirs.** Executors could stage but not commit, because bare `mktemp` wrote outside their sandbox.
   Owner (2026-10-23 02:47Z): leave the sandbox as it is. The tools were fixed instead to take `mktemp` templates under
   `TMPDIR` — `42d0e40`, PR #5, merged `15a875b` (2026-10-25).

## 3. Configuration after creation (2026-10-25 to 2026-10-28)

| Date | Change | Commit on `main` |
|---|---|---|
| 2026-10-25 | Owner: route all `gh` commands through the desk (`c17bda54`, 13:06Z); desk is research-only, the workers plan and execute (`8adadfef`, 13:00Z) | — |
| 2026-10-25 | STANDARDS consistency edits approved (`c502cd4c`, 12:45Z); invariant 4 threshold, invariant 29 root exemption | `1248b13`, `ddaf6c6` |
| 2026-10-25 | Sanitized ADR subset; doc fixes from owner D3 rulings | `8ab42b5`, `376d528` |
| 2026-10-26 | Hermes setup templates under `tools/hermes/setup/` | `e9a6523` (PR #8) |
| 2026-10-26 | Port-clash guard (owner, `c17bda54` 16:08Z) | `bcaac58` (PR #9) |
| 2026-10-26 | Vendored security-audit skill (owner request 15:21Z) | `9191056` |
| 2026-10-26 | Delivery workflow skill family, design accepted by the owner (13:38Z) | `90fa8ec` (PR #13), `2520698` (PR #14), `fc1db28` (PR #15) |
| 2026-10-26 | Try-it-on-your-machine guide and `cprof --auth bedrock`; Hermes install-and-lock guide (owner request 23:50Z) | `2e2aafa` (PR #16), `37b569e` (PR #17) |
| 2026-10-27 | INTERFACES 1.10.0 | `ac3e3ae` (PR #18) |
| 2026-10-27 | History rewrite and force push (§4) | rewritten line ends at `ac3e3ae` |
| 2026-10-27 | cprof link default source root, README, Bedrock profile.env | `0a00904` (#19), `2abad21` (#20), `30a75a9` (#21) |
| 2026-10-28 | Delivery RUNBOOK and leadership explainer; PR #22 superseded by #23 after a rebase | `17044fc` (PR #23) |
| 2026-10-28 | cprof Bedrock self-heal | `7840774` (#24) |

## 4. The history rewrite (2026-10-27)

- **Why.** Owner (`c17bda54`, 2026-10-27 16:34Z): remove a personal-project name and strip it from git history, and
  remove the Notion page-id references. A scan also found employer-internal names and home paths in files, and the
  personal email in commit metadata.
- **How.** File fixes were prepared on a `wt/sanitize` branch, then the desk ran `git filter-repo --replace-text` with
  a mailmap (author email moved to the GitHub noreply form) in a mirror clone. Verified: forbidden-string counts all 0,
  the rewritten `main` tree equal to the sanitize branch tree. The owner ran the force push from their own terminal;
  the desk's classifier and both tier files deny force pushes. Pre-rewrite `37dd4a4` became `ac3e3ae`.
- **Consequences.** Every sha changed; author dates were kept, which is why `git log` still shows 2026-10-22 onward.
  Review records, trailers and transcripts written before the rewrite cite old shas. The filter-repo commit map lived in
  the mirror, which was deleted on 2026-10-28. GitHub keeps old commits reachable through PR refs until its own garbage
  collection runs (`c17bda54`, 17:10Z).
- **Rule that came out of it.** A pre-rewrite clone shares no commits with `origin`: a pull tries to merge unrelated
  histories, and a push would put the removed strings back. Such clones are deleted and re-cloned, never pulled.

## 5. Current configuration (verified at `7840774`)

- **Hooks.** `core.hooksPath = tools/git-hooks` (relative, so all worktrees share it): `pre-commit`, `post-commit`,
  `pre-push`, `session-end-push-check.sh`. A fresh clone must set it (`config/README.md`; residual R3 in
  `hq-code-gate.md` §6).
- **Code gate** (`tools/code-gate/`, `architecture/hq-code-gate.md`, Rule 10).
  - Scope (`scope.conf`): shell, python and JS/TS sources, any executable file, and the gate's own config. Markdown is
    not in scope. Excluded: `plans/*`, `config/settings.json`, the vendored swarm bus, and vendored security-audit
    `*.test.cjs` (run through mapped wrappers).
  - Mapped tests: every in-scope file has a row in `test-map.tsv` or is listed in the shrink-only `grandfathered.txt`.
    `pre-push` runs the mapped tests from the base's copy of the gate and prints `CODE-GATE: PASS n_run=<k>` or
    `CODE-GATE: FAIL …`.
  - Review: a push of `main` also runs `check-review.sh`. Each in-scope first-parent commit must be a `--no-ff` merge
    carrying a `Code-Gate-PR: #N` trailer, and the PR's last marker comment must be
    `CODE-GATE-REVIEW: PASS head=<sha> blocking=0 medium=0`, posted after `pr-review` (Rung 3) reaches 0 Blocking /
    0 Medium. Invariants 27–29 in `INVARIANTS.md` make a skipped gate visible after the fact.
- **Vendored swarm bus** at `tools/swarm-communication-layer/` (`src/`, `shared/`, `test/`, `decisions/`, lockfile,
  pm2 config, schema). It is outside the code gate and has its own test suite.
- **Permission tiers** (`config/tiers/`): `executor.json` (55 deny rules, sandbox on, network allowlist, writes limited
  to `~/projects`, `~/.npm` and the pnpm store, `config/tiers` itself write-denied); `desk.json` (22 deny rules);
  `auth-bedrock.json`; overlays. Both tiers deny `git push --force` and `-f` in all forms.
- **cprof** (`tools/claude-profile/`): isolated per-shell profiles with their own config dir and auth (OAuth token or
  `--auth bedrock`), `--tier executor|desk` rendering from `config/settings.json` + the tier file, and `cprof link`
  defaulting to `~/projects/agent-hq`. Walkthrough: `tools/onboarding.md`.
- **Hermes** (`tools/hermes/`, `tools/hermes/setup/`): backup, digest and learnings-import tooling, plus templates to
  rebuild the owner's Hermes install (launcher, gateway plist, `pre-tool-call` hook with a pinned allowlist, SOUL,
  config extract). `INSTALL.md` covers installing at the pin and locking the config; `check-config` verifies it. No
  secrets or state are copied.

## 6. How agent-hq is used now

- **One clone.** `~/projects/agent-hq` stays on `main` and is only ever fast-forwarded from `origin/main`. Another
  computer also pushes to `main` (PRs #19–#21 and #24 came from GitHub-side merges), so fetch before starting work.
  The owner's ruling (`c17bda54`, 2026-10-28 04:32–04:40Z): one clone, worktrees for work, main checkout tracks main.
- **All work in worktrees.** `~/projects/agent-hq-worktrees/<slug>` on `wt/<slug>` (Rule 6; ADR 0017). Never author on
  `main`.
- **Doc-only branches** (nothing in gate scope) merge locally with `git merge --no-ff wt/<slug>` and a push of `main`.
  The hook passes them as `CODE-GATE: PASS n_run=0` (e.g. `8859d81`, `63abe35`).
- **In-scope code**: worktree → commit with tests and map rows → `git push -u origin wt/<slug>` (pre-push gate) →
  open PR → `pr-review` → marker comment → `--no-ff` merge in the main checkout with `Code-Gate-PR: #N` → push `main` →
  remove the worktree (`hq-code-gate.md` §5). Example: PR #23, two review rounds (0/1, then 0/0), merged as `17044fc`.
- **Who does what.**
  - Executor sessions (Worker1, Worker2) author in worktrees, run tests and push `wt/` branches.
  - The desk session runs `gh` (open/close PRs, post the marker) and anything needing wider network; on PR #23 it also
    did the merge and pushed `main`.
  - The owner runs one-way steps the tiers deny, e.g. the force push of the rewrite.
  - Force push is denied to both tiers. Remote-branch deletion was refused in the executor session on 2026-10-28, but
    is not in the repo's tier deny list (it came from that session's live settings: unverified in-repo).
- **Pre-rewrite clones** (anything cloned before 2026-10-27 17:09Z) are deleted and re-cloned, never pulled (§4).

## 7. Open items at the time of writing

- PRs #19, #20, #21 and #24 were merged on GitHub with no `Code-Gate-PR` trailer, though they touch in-scope cprof
  files. Rule 10 says never merge on GitHub. Whether invariant 29 / `check-review.sh` now flags them: unverified.
  A GitHub web merge also stamped the account's email instead of the noreply form (`c17bda54`, 2026-10-28 04:28Z).
- Pending as of 2026-10-28 04:46Z (`c17bda54`): Worker2 profile removal, ratifying the agent trust bootstrap, desk
  permission rules, and folding Hermes's answers into an improvement plan before the second delivery-pilot run.
- `origin/wt/am10-ci-run-id` still exists on the remote; deleting remote branches needs the desk or the owner.
- Executor write access to `~/.pm2` and temp dirs was granted by the owner on 2026-10-26 (`c17bda54`, 01:23Z and
  02:19Z) for the live profiles (`~/.pm2` also in the hq tier source); agent-hq's `config/tiers/executor.json` at
  `7840774` does not list either. Whether that gap is intended: unverified.
