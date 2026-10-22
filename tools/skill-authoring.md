# Skill authoring standard

One-line summary: how hq writes a **skill** — Claude Code's native `SKILL.md` format with
Addy Osmani's agent-skills discipline (explicit trigger, red-flags table, non-negotiable
exit criteria) folded in. Every hq skill traces to recorded friction; none is invented.

- **Status:** active
- **Applies to:** all skills authored under hq (plan item P4, plans/addy-alignment-plan.md §3)
- **Governing ruling:** Q4 — *native* Claude Code skill format; convert to other formats
  only when a concrete need appears (plans/addy-alignment-plan.md §6).

## 1. Native format — verified, not remembered

The format below was verified against official Anthropic documentation before this standard
was written (Q4 requires grounding in the real native format, not memory):

- Agent Skills overview (the open standard, progressive-disclosure model, field limits):
  `https://platform.claude.com/docs/en/agents-and-tools/agent-skills/overview`
- Claude Code skills (locations, full frontmatter reference, symlink behavior, sizing tip):
  `https://code.claude.com/docs/en/skills`
- **Verified:** 2026-07-04.

A skill is a **directory** whose entrypoint is a `SKILL.md` file: YAML frontmatter between
`---` markers, then a Markdown body. Claude Code follows the [Agent Skills](https://agentskills.io)
open standard and extends it (invocation control, `context: fork`, dynamic context).

| Fact (verified) | Value |
|---|---|
| Entrypoint | `SKILL.md` (required); other files optional, loaded on demand |
| Discovery / trigger | the `description` field — Claude reads it to decide when to load the skill |
| `name` limits | ≤ 64 chars; lowercase letters, numbers, hyphens only; may not contain "anthropic"/"claude"; defaults to the directory name |
| `description` limits | non-empty; ≤ 1024 chars; no XML tags. In the skill listing, `description` + `when_to_use` is truncated at 1,536 chars — key use case first |
| Locations | Personal `~/.claude/skills/<name>/SKILL.md` (all projects) · Project `.claude/skills/<name>/SKILL.md` (that repo) · also Enterprise, Plugin |
| Symlinks | a skill entry in a skills dir **may be a symlink** to a directory elsewhere on disk; Claude Code follows it and reads the target's `SKILL.md` |
| Sizing tip (official) | keep `SKILL.md` under 500 lines; move detail to separate files |

Useful frontmatter fields (all optional; only `description` is recommended):
`name`, `description`, `when_to_use`, `disable-model-invocation` (manual-only skills),
`user-invocable`, `allowed-tools`, `model`, `effort`, `context: fork` + `agent`.

## 2. Required skill anatomy (Addy's pattern on the native format)

Addy's agent-skills pattern is specific — frontmatter + explicit trigger + steps +
red-flags/anti-rationalization table + non-negotiable exit criteria. hq **requires** all
five, mapped onto the native file so the skill stays a valid `SKILL.md`.

| Element (Addy) | Where it lives in `SKILL.md` | Non-negotiable |
|---|---|---|
| **Frontmatter** | native YAML block | `description` present, ≤ 1024 chars, key use case first |
| **Explicit trigger** | folded into `description` as a "Use when …" clause, **and** restated as a `## Trigger` line at the top of the body | the "Use when …" phrasing is mandatory — it is the discovery signal |
| **Numbered steps** | `## Steps` — an ordered list | each step is an action, not narration |
| **Red-flags / anti-rationalization table** | `## Red flags` — a two-column table: *rationalization Claude might make* → *what to do instead* | at least the failure modes drawn from the skill's provenance |
| **Non-negotiable exit criteria** | `## Exit criteria` — a checklist that must all pass before the skill is "done" | phrased as verifiable checks, not aspirations |
| **Provenance** (hq addition, §5) | `## Provenance` line at the foot | links the friction entry the skill derives from |

Keep the body concise: once invoked, a skill's content stays in context for the rest of the
session, so every line is a recurring token cost. State what to do, not why.

## 3. Progressive-disclosure sizing (token budget)

The native format loads in three levels (verified, overview doc): **L1 metadata** (`name` +
`description`, ~100 tokens, always in context), **L2 the `SKILL.md` body** (loaded when
triggered, official guidance "under 5k tokens"), **L3 bundled files** (loaded on demand via
bash, effectively unlimited).

**hq per-skill budget: the `SKILL.md` body targets ≤ 5,000 tokens (L2).**

- *Rationale:* it matches Anthropic's own stated L2 ceiling ("under 5k tokens") and roughly
  tracks the official "under 500 lines" tip — one anchor, two sources, no guesswork.
- *Tunable:* 5k is a starting ceiling, not a law; revise it if measurement (a retro DX
  tally, P5) shows skills are being truncated or under-used. Record any change here.

**The rule:** depth beyond the budget does **not** get crammed into `SKILL.md`. It moves to a
linked reference file in the skill directory (`reference.md`, `examples.md`, a script) and is
referenced from the body so Claude loads it only when the task needs it (L3). L1 metadata
stays tiny regardless; the body is the thing under budget.

## 4. Validation checklist

A finished skill must pass every check below. This is the acceptance gate for P4.2's first
skills ("a sample skill validates against it").

- [ ] Directory + `SKILL.md` at a valid location (personal / project / hq-authored symlink).
- [ ] `name` ≤ 64 chars, lowercase-hyphen, not "anthropic"/"claude" (or omitted → dir name).
- [ ] `description` present, ≤ 1024 chars, non-empty, no XML tags, key use case first,
      and contains an explicit **"Use when …"** trigger clause.
- [ ] Body has all five required sections: `## Trigger`, `## Steps`, `## Red flags`,
      `## Exit criteria`, `## Provenance`.
- [ ] `## Steps` are numbered, imperative actions.
- [ ] `## Red flags` is a rationalization → do-instead table with ≥ 1 real failure mode.
- [ ] `## Exit criteria` are verifiable checks, not aspirations.
- [ ] `SKILL.md` body is within the token budget (§3); overflow moved to linked files.
- [ ] `## Provenance` links a recorded friction entry (a Hermes learning, or an existing learnings/ or retros/ file) — §5.
- [ ] Manual-only workflows with side effects set `disable-model-invocation: true`.

## 5. Provenance rule (skills derive from friction, never invention)

Per P4.2's ratified done-when, **every hq skill must trace to a recorded friction entry** —
a Hermes learning (existing ones imported from `learnings/`) or a `retros/…` finding. Skills exist to freeze a workflow that
has already cost us something; a skill with no recorded friction behind it is speculation and
is rejected at review. The trace is a one-line `## Provenance` link at the foot of `SKILL.md`
(e.g. `Provenance: Hermes skill learnings/skill-sharing (imported from learnings/skill-sharing.md)`). This is the
same one-owner-per-fact discipline as the rest of hq: the friction is owned in Hermes (and retros);
the skill points at it, it does not re-narrate it.

## 6. Minimal worked example (illustrative — NOT installed)

The skill below is a format demonstration only. It is **not** installed anywhere (not in
`~/.claude/skills/`, not in any repo's `.claude/skills/`) and its provenance link is
illustrative. It exists solely to show the required anatomy passing the §4 checklist.

```markdown
---
name: hq-push-check
description: Confirms hq's end-of-session commits are pushed to the backup remote. Use when wrapping up an hq work session, before closing the terminal, or whenever "am I backed up?" comes up.
disable-model-invocation: true
allowed-tools: Bash(git status *) Bash(git log *) Bash(git push *)
---

## Trigger
Use when ending an hq session, or any time you need to confirm hq is backed up. hq push is
the ONLY backup mechanism (ADR 0006); an unpushed commit is unbacked knowledge.

## Steps
1. Run `git -C ~/projects/agent-hq status -sb` — confirm the working tree is clean.
2. Run `git -C ~/projects/agent-hq log --branches --not --remotes --oneline` — list unpushed commits.
3. If any commits are listed, run `git -C ~/projects/agent-hq push`.
4. Re-run step 2 and confirm it prints nothing.

## Red flags
| Rationalization | What to do instead |
|---|---|
| "I committed, so it's safe." | Commit is local only; step 3 push is what backs it up. |
| "I'll push at the end of the week." | Push every batch — the gap is the unbacked window. |
| "`git status` was clean, so I'm done." | Clean tree ≠ pushed; run step 2, not just step 1. |

## Exit criteria
- [ ] Working tree is clean.
- [ ] `git log --branches --not --remotes` prints nothing (zero unpushed commits).

## Provenance
Provenance: Hermes skill learnings/skill-sharing (imported from learnings/skill-sharing.md)  (illustrative link)
```

This example passes §4: valid `name`, a `description` with a "Use when …" trigger under the
char limit, all five body sections, numbered imperative steps, a real red-flags table, a
verifiable exit checklist, a provenance line, and `disable-model-invocation: true` because
pushing is a side-effecting workflow the human should time.

## 7. Where hq skills live

Settled by user ruling 2026-07-03: **author skills in hq** under a `skills/` directory
(so they live in git, one owner, ADR-0001 plain-markdown, verifiable at review) and **install
by symlinking** each into `~/.claude/skills/<name>` — a mechanism the native format explicitly
supports (§1). hq holds the source of truth; the symlink makes it live. Record the decision as
an ADR + STANDARDS §3 naming row (batched at Compound time) before P4.2 ships the first skill.
