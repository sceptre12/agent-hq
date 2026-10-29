---
name: new-context-project
description: >
  Onboards a new project into hq's own project-record convention —
  ~/projects/hq/projects/<slug>.md, plus an architecture/<slug>.md design record when the
  project qualifies as a system/initiative under Rule 5. Use when the user says "create a
  new project record", "onboard this project into hq", "add this to hq", "save this
  project's context", or any variant of storing a project's context for the first time,
  or when work starts on a project hq has never recorded.
---

## Trigger

Use when a project has no `~/projects/hq/projects/<slug>.md` yet and the user wants one
created — a brand-new repo, an existing repo hq has never recorded, or any request to
"onboard"/"save context for"/"add to hq" a project. Not for updating an existing record —
if `projects/<slug>.md` already exists, edit it directly instead of running this skill.

Also use proactively — without waiting to be asked — when substantive work begins on any
project under `~/projects/` that has no project record yet under this convention.
Onboarding in practice usually happens implicitly, as a side effect of starting project
work, rather than via an explicit onboarding request — so don't wait for onboarding phrasing
before creating the record.

## Steps

1. **Determine the slug.** Ask if not already given, or infer it from the repo/directory
   name (kebab-case per `STANDARDS.md` §3, e.g. `dev-toolkit`). Run
   `ls ~/projects/hq/projects/` and confirm `<slug>.md` doesn't already exist — hq's
   `projects/` directory listing is its own index; there is no separate registry file to
   check or update.
2. **Read the template and one populated example** before writing anything:
   `~/projects/hq/projects/_TEMPLATE.md` (the structure to fill) and one existing record
   of comparable scope, e.g. `~/projects/hq/projects/x-context-docs.md`, to see how the
   sections read once actually populated.
3. **Create `~/projects/hq/projects/<slug>.md`** from the template, filling in from
   whatever's known — conversation context, the project's own README/CLAUDE.md, `git
   remote -v` for repo location. At minimum per `STANDARDS.md` §2: purpose, repo location,
   status, architecture summary. A record can start as a stub (`idea` or early `active`
   status) and grow later — do not leave template placeholder angle-brackets (`<...>`) in
   the committed file; write "unknown" or "TBD" explicitly instead where a section is
   genuinely not yet known. All dates and timestamps must be absolute ISO `YYYY-MM-DD`
   (`STANDARDS.md` §4) — never relative ("yesterday", "last week"), which rot the moment
   they're committed.
4. **Note git identity** in "Where it lives" if the project uses a non-default account —
   check `tools/git-profile-autoswitch.md` conventions and the repo's actual
   `git config user.email` / remote host, don't assume the default identity.
5. **Decide whether this project needs an architecture record.** Per ADR 0011, an
   `architecture/<slug>.md` is for a *system* — something with real components,
   interfaces, and settled design decisions worth ratifying (Rule 5's bar). A thin context
   stub for a small script or a project that's just "on the radar" does not need one yet
   (Rule 5's sub-threshold exemption). If it qualifies:
   - Read one existing architecture record for shape (e.g.
     `architecture/loop-system.md` for a multi-component system, or
     `architecture/doc-reviewer.md` for a single-skill record).
   - Create `architecture/<slug>.md` with at least: one-line summary, `## What This Is`,
     `## Components`, `## Interfaces`, and any `## Settled decisions` already made.
   - Cross-link it from the project record's "Decisions & learnings" section, and
     cross-link back per ADR 0011's lineage-citation convention.
   - If genuinely unsure whether it qualifies, don't guess — this is exactly the
     structural fork hq's decision gate covers (hq `CLAUDE.md`, "Decision gate": "On any
     structural ambiguity or fork: write options + recommendation to decisions/ and stop
     — do not guess; surface it and let the human decide."). Write the options and a
     recommendation to `decisions/` and STOP — do not silently create, and do not
     silently skip, the architecture record. Follow the existing ADR convention when
     writing that options write-up: copy `decisions/_TEMPLATE.md` (per `STANDARDS.md`
     §4, "Templates live as `_TEMPLATE.md` in each dir"), and number it sequentially as
     `decisions/NNNN-<kebab-title>.md` per `STANDARDS.md` §3 — never reuse a number.
6. **If the project's own repo has no agent-facing pointer yet**, add a short
   `CLAUDE.md` there following `~/projects/CLAUDE.md`'s existing pattern (a pointer to hq,
   ≤15 lines per `STANDARDS.md`) — not a bespoke per-repo constitution. Most repos under
   `~/projects/` already inherit this from the shared root `~/projects/CLAUDE.md`; only add
   a repo-local one if this project genuinely needs something beyond the shared pointer.
7. **Commit.** A single new project record (± an architecture stub) is a two-file,
   single-commit op — per this workspace's worktree-only policy, if one exists, run even
   this single-commit op in a dedicated worktree (following this workspace's own
   worktree-naming convention, if one exists — e.g. `<repo>-worktrees/<slug>`), merge to
   main, push, remove the worktree. If this onboarding is part of a larger multi-commit
   work unit already running in a worktree, commit there instead and let that unit's own
   merge/push close it out. Message: `add: project context — <slug>` (STANDARDS.md §2 step 3).

## Red flags

| Rationalization | What to do instead |
|---|---|
| "I'll build the full shared/decisions/sessions folder structure like the old system." | hq's project record is one flat file (`projects/<slug>.md`) by design — `STANDARDS.md` §1 is "lightweight over complete"; don't recreate a multi-folder KB structure hq doesn't use. |
| "I'll register this in an index file so it's discoverable." | hq has no separate project index — the `projects/` directory listing *is* the index (Step 1). Don't create one. |
| "I'll write a session context dump for this conversation." | hq's durable layer is git markdown (this record, ADRs, learnings); ephemeral session context is agentmemory's job (hq `CLAUDE.md`, "Memory ownership") — outside hq, git-ignored, never a `projects/` concern. |
| "Every project needs an architecture record for completeness." | Only create one when the project clears Rule 5's system/initiative bar (Step 5) — a thin stub doesn't need one yet; over-creating churns a folder meant for real design records. |
| "This is a small addition, I'll just commit straight to main without checking status." | No direct-to-main authoring at all — worktree even for one commit, per this workspace's worktree-only policy if one exists. |
| "I'm not sure this qualifies for an architecture record, I'll just decide and move on." | Don't guess — per hq `CLAUDE.md`'s decision gate, write the options + a recommendation to `decisions/` and STOP; the human decides (Step 5's last bullet). |

## Exit criteria

- [ ] `~/projects/hq/projects/<slug>.md` exists, follows `_TEMPLATE.md`'s section
      structure, and has no unfilled template placeholder brackets left in it.
- [ ] `git -C ~/projects/hq/projects` listing (or `git status`) confirms no duplicate or
      stray registration file was created.
- [ ] If the project qualifies as a system/initiative (Step 5), `architecture/<slug>.md`
      exists and is cross-linked from the project record — otherwise, no architecture file
      was created for a sub-threshold project.
- [ ] The commit (or, in a worktree, the pending change) uses the `add: project context —
      <slug>` message convention and touches only the new record(s).

## Provenance
Provenance: learnings/skill-sharing.md (2026-07-04 entry, "Skills have no standardized
export path" — the same porting pipeline this skill entered hq through).
Lineage: X-context-docs skills/new-context-project@9d7143e (originally ported @87ed5a6; re-pinned to this round's snapshot)

### Refit notes (declared changes vs. source — this is a heavy, ruled refit)

User ruling 2026-07-05 (`plans/dev-workspace-base-skills.md` triage table, `new-context-project`
row: `PORT-AS-REFIT`): retarget the skill onto hq's own onboarding convention
(`projects/<slug>.md` + conditional `architecture/<slug>.md`) instead of the source's
`~/projects/context-docs` knowledge base, which does not exist on this machine and whose
directory-per-project + curator-promotion model hq deliberately does not use
(`STANDARDS.md` §1, "lightweight over complete"; hq `CLAUDE.md`, "Memory ownership"). Every
element of the source is accounted for below — mapped, dropped, or replaced, none silently
lost.

**Mapped (source idea → hq equivalent):**
- `meta.md` fields (name, purpose, architecture, key people, goals) → folded into the
  single `projects/<slug>.md` file's existing sections (`_TEMPLATE.md`'s Meta / Purpose &
  context / Architecture summary), rather than a separate `meta.md` file — hq's project
  record is already one file, not a `meta.md` + `shared/*.md` split.
- `shared/architecture.md` (curator-only placeholder in source) → hq's equivalent is the
  *optional*, conditionally-created `architecture/<slug>.md` (Step 5) — but promoted to a
  first-class design record gated by Rule 5/ADR 0011's system bar, not a perpetually-empty
  curator placeholder nobody but a curator agent may touch.
- `shared/open-questions.md` → no dedicated file; open questions fold into the project
  record's "Current state & next steps" section (`_TEMPLATE.md`), or, if the ambiguity is a
  structural fork rather than routine project status, go to hq's decision-gate mechanism
  (hq `CLAUDE.md`) instead — a stronger placement than an unowned placeholder file.
- Registering in `_index.md` → dropped; hq's `projects/` directory listing is its own
  index (Step 1). No index file exists or is created.
- Source Rules bullet "All timestamps must be absolute (no relative dates like
  'yesterday')" → carried over into Step 3, aligned with hq's own existing convention
  (`STANDARDS.md` §4, "Dates are ISO `YYYY-MM-DD`") — kept because it survives the KB
  retarget unchanged: relative dates rot in any durable record, hq's included.
  (Gate 4 finding: this bullet was initially neither ported nor declared dropped —
  restored here.)
- Onboarding the project's own repo with a `CLAUDE.md`/`contracts/`/`.tasks/`/`.decisions/`
  agent layer (source's `CLAUDE.md` "Onboarding a New Project" section, mined via
  `~/projects/X-context-docs/CLAUDE.md`) → hq already has a settled, much lighter
  equivalent: the shared root `~/projects/CLAUDE.md` pointer file (≤15 lines,
  `STANDARDS.md` §3) that every repo under `~/projects/` inherits by directory position; a
  bespoke per-repo `contracts/`/`.tasks/`/`.decisions/` layer is not hq's convention and was
  not carried over (Step 6 only adds a repo-local `CLAUDE.md` when the shared pointer
  genuinely isn't enough, and even then follows the pointer's own short pattern, not the
  source's fuller "agent constitution" shape).

**Dropped (no hq equivalent, superseded by an existing hq mechanism):**
- The full `shared/{architecture,conventions,open-questions,execution-log,panel-protocol}.md`
  + `decisions/` + `sessions/` per-project folder tree (source Step 3-4) — hq's project
  record is one file; ADRs already live centrally at `decisions/NNNN-*.md` (not
  per-project), and there is no hq equivalent to a per-project `panel-protocol.md` or
  `execution-log.md` (those are `X-context-docs`-specific curator-workflow artifacts).
- The session-context-dump step in full (source Step 5: timestamped `sessions/{ts}_pid-
  {pid}/context.md` + `artifacts/`) — superseded by agentmemory, which already owns
  ephemeral/automatic memory outside hq, git-ignored (hq `CLAUDE.md`, "Memory ownership");
  a `projects/`-folder session dump would duplicate a job hq has already assigned
  elsewhere.
- The `_templates/_index` machinery generally (source Step 1's template-reading list:
  `meta.md`, `session.md`, `execution-log.md`, `panel-protocol.md` templates) — hq has
  exactly one template, `projects/_TEMPLATE.md` (Step 2), and no others to read.
- The curator-promotion discipline ("do NOT write to `shared/` beyond placeholders — only
  the curator promotes content there") — has no hq analogue; hq's `projects/<slug>.md` is
  written directly by whoever's onboarding the project, growing over time
  (`STANDARDS.md` §2, "a project record can start as a stub and grow").
- `decisions/.gitkeep` requirement — moot; hq's `decisions/` is a single shared top-level
  folder already tracked by git, not an empty per-project folder needing a keep-file.

**Structural refit (authoring standard):** added `## Trigger`, `## Red flags`, `## Exit
criteria`, `## Provenance` (source had no equivalents — its "Rules" section became a
component of `## Red flags`, reworded as rationalization → do-instead pairs, plus new rows
for the hq-specific pitfalls above that the source's own model didn't need to guard
against, e.g. rebuilding the dropped folder structure or skipping the Rule 5 architecture
gate).
