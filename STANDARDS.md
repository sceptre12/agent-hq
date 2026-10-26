# STANDARDS

The single source of truth for how `hq` is run. Keep it lightweight — if a rule isn't
earning its keep, delete it.

## 1. Core principles

- **Lightweight over complete.** A small, obvious structure beats a sprawling one.
- **Context, not code.** No application source lives here. Link out to real repos.
- **Plain Markdown, plain git.** No build step, no tooling required to read or edit.
- **Capture at the moment of insight.** A decision or lesson written later is usually
  lost. Cheap-to-add entries beat perfect ones.

## 3. Naming

- **Learnings:** live in Hermes, recorded and asked through its API door (recipe: `tools/brain/templates/member-CLAUDE.md` (Memory section)).
  hq keeps tools (`architecture/hermes-agent-memory.md` §1).
- **Skills:** `skills/<name>/SKILL.md`, authored per `tools/skill-authoring.md`, installed by symlink into `~/.claude/skills/<name>` (ADR 0009).

## 4. Document format

- Every doc starts with an H1 title and, where useful, a one-line summary.
- Prefer short sections and tables over prose walls.
- Dates are ISO `YYYY-MM-DD`. Status values: `active` | `paused` | `archived` | `idea`.
- Split any doc that trends past ~500 lines into numbered parts (e.g. `doc-01.md`, `doc-02.md`) with an index file — **except plans**, which split by task into the §3 directory form instead. Keeps files agent-ingestible. Enforced for non-skill docs per §13 (ADR 0021).

## 5. Commit conventions

Lightweight Conventional-Commits, one line, imperative, lowercase type:

```
<type>: <summary>
```

Types used here:

| Type       | Use for                                              |
|------------|------------------------------------------------------|
| `add`      | New project record, ADR, learning, reference, retro. |
| `update`   | Editing existing content.                            |
| `decision` | Recording/changing an ADR's status.                  |
| `learning` | Capturing a reusable lesson.                         |
| `retro`    | Adding/closing a retrospective.                      |
| `chore`    | Structure, config, .gitignore, housekeeping.         |

Examples:
- `add: project context — zephyr-packages`
- `decision: 0002 accept per-account SSH keys`
- `learning: git includeIf must sit above chpwd hook`

Keep one logical change per commit. Commit-*message* conventions are convention, not
ceremony — not enforced. **Structural safety is enforced minimally** (ADR 0007): an hq
`pre-commit` hook blocks staged secrets and runtime state and runs the memory-safety
invariant subset; a `post-commit` hook nudges when commits are unpushed. Install once:
`git -C ~/projects/agent-hq config core.hooksPath tools/git-hooks`.

## 7. Where real code lives

Code repos are **siblings** under `~/projects/`, never nested inside `hq`. `hq` links to
them; it does not contain them.

## 8. End-of-session Compound ritual

At the end of every meaningful work session, spend ~5 minutes asking:

> "What from this session should be captured?"

Then, in order:

1. **Update `CLAUDE.md`** — any corrected preferences, corrected assumptions, or context
   the AI got wrong that it should carry forward. Keep the file under ~60 lines.
2. **Write learnings** — anything surprising, a gotcha, a pattern that worked: tell Hermes
   through the API door (recipe: `tools/brain/templates/member-CLAUDE.md` (Memory section)), not a new `learnings/` file.
5. (Optional) **Check INVARIANTS** — run through `INVARIANTS.md`; fix any failures before committing.
6. (Optional) **Update Serena notes** — if in a code repo session, check whether `.serena/memories/` notes need updating for architectural changes.
7. **PUSH** — `git push` to the private GitHub remote. Every commit batch must be published. This is the backup mechanism (no Time Machine; see ADR 0006).

This ritual is the single most important habit in hq. It's what turns ephemeral work into
durable, compounding knowledge. The final step — PUSH — is what makes it durable. See
Hermes skill `learnings/learnings-methodology` (was learnings/METHODOLOGY.md) for the full rationale.

The ritual is intentionally MINIMAL — no morning review, no evening check-in, just this
one end-of-session step. If it starts feeling heavy, cut it further.

## 12. Source file length

- Source files we author default to **≤~300 lines**. Soft default, not a hard cap.
- **Skills are exempt** (blanket exception — skill files stay wherever they land).
- **Test files are exempt**, same as skills: `*.test.*`, `*.spec.*`, or anything under a
  `__tests__/`, `test/`, or `tests/` path segment. Large test files are low-risk.
- Over the limit? **Split into multiple files.** Never compress, delete, or reword content
  just to hit the number — split-don't-butcher is the point of the rule.
- Excludes vendored/generated code, lockfiles, and data fixtures.
- **Scope:** applies to hq and to projects we author from it — not to cloned, forked,
  third-party, or vendored repos we merely work inside.
- Escape hatch: list the path in a `.file-length-allowlist` at the repo root with a
  mandatory one-line reason (`<path> — <reason>`); no reason, the checker fails closed.
- Enforced by `tools/check-file-length.sh` (see ADR 0016 for the full rationale — 300 is a
  convention anchor, not a measured defect threshold).

## 13. Doc length (non-skill)

- Authored non-skill `.md` docs default to **≤~500 lines**. Soft default, not a hard cap (ADR 0021).
- **Skills are exempt** (blanket — `SKILL.md` and every skill `references/*` file; reference-file
  growth is the sanctioned SKILL.md overflow valve per `tools/skill-authoring.md`).
- Over the limit? **Split, don't butcher.** Plans split by task into the §3 directory form;
  narrative docs split into numbered parts per §4. Never compress, delete, or reword content
  just to hit the number.
- Excludes third-party/generated docs we don't author.
- **Crossing the cap requires the owner's explicit approval — every file, every time** (ADR 0029,
  amends 0021). Not scoped to newly-authored files. **Precedent, existing allowlist entries,
  and "campaign convention" are not justifications.** Hitting the boundary mid-task → split
  (needs no approval, always available), or **stop and ask**; never proceed-and-allowlist.
- Escape hatch: `.doc-length-allowlist` at the repo root with a mandatory one-line reason
  (`<path> — <reason>`); no reason, the checker fails closed. An entry is valid only with a
  recorded owner approval (ADR 0029). Pre-0021 over-limit docs are grandfathered onto the
  allowlist (ADR 0021 migration clause) and are forward-only debt: they stay, are reported by
  name and line count on every run, and are split on the next substantive touch.
- Enforced by `tools/check-doc-length.sh`, mirroring `check-file-length.sh`. Allowlisted
  over-cap files are reported but do **not** fail the check; non-allowlisted ones do.
  It runs on **every commit** (invariant 25 is in the pre-commit `--fast` subset), matching
  the markdown family case-insensitively (`.md`/`.markdown`/`.mdx`, any casing).

## 14. Test gate evidence: default order is a hidden scope

- "The suite passes" implicitly means "passes *in whatever order this run used*" — usually
  default declaration order. That scoping is easy to miss until a hidden ordering dependency
  (shared/module-level state one test mutates and a later test relies on, unreset) hides behind
  it.
- **For other JS/TS test suites**, this is a candidate default, not (yet) a mandate: sequential
  stays the standard fast loop; add a seed-logged randomized run where a suite has module-level
  singletons, shared mutable mocks, or any other plausible source of order-dependency, and keep
  it non-blocking until the suite has a track record under the practice.
- Not currently wired into any script or invariant — compliance depends on whoever assembles gate
  evidence remembering the second command and recording the seed. See ADR 0030 and
  Hermes skill `learnings/enforcement-gates` (was learnings/enforcement-gates.md)'s 2026-08-18 entry for the tooling gap this leaves open.
