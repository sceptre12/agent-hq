---
name: search-past-sessions
description: >
  Looks up prior Claude Code conversation context from local session JSONL files. Use
  when the user asks to look up, recall, or reference a past Claude conversation,
  previous session context, prior review, or anything that happened in an earlier chat —
  triggers include "we went over this before", "from our last session", "look up the past
  chat where we...", "what did we decide last time".
model: haiku
context: fork
agent: general-purpose
background: false
---

## Trigger

Use when the user references something from an earlier Claude Code session that isn't in
the current conversation's context — a past decision, a prior review, a branch or ticket
discussed before, or any variant of "we covered this already." Claude Code persists every
session locally; this is always answerable by searching, never a reason to say "I can't
access past sessions."

## Query

Search for: $ARGUMENTS

This skill runs in a forked subagent with no access to the calling conversation's
history — the line above is the only information it receives about what to search for.
If it is empty, report that back rather than guessing a keyword.

## Steps

1. **Identify the project slug.** Run `ls ~/.claude/projects/` — the slug is the working
   directory's absolute path with every `/` replaced by `-`. Example: a repo at
   `~/projects/my-repo` (i.e. `/Users/<you>/projects/my-repo`) has slug
   `-Users-<you>-projects-my-repo`.
2. **Fast path — direct session UUID.** If the user supplies a session UUID directly, skip
   keyword search — locate it across all slugs with `ls ~/.claude/projects/*/<uuid>.jsonl`
   and go straight to Step 4.
3. **Search for the keyword across that project's session files:**
   ```bash
   grep -l "KEYWORD" ~/.claude/projects/<project-slug>/*.jsonl
   ```
   Also check subagent transcripts, which the glob above silently misses — they live one
   level deeper, not at the project directory's top level:
   ```bash
   grep -l "KEYWORD" ~/.claude/projects/<project-slug>/*/subagents/agent-*.jsonl
   ```
   If the project isn't obvious, the keyword might span projects, **or the resolved slug
   directory has zero matching `*.jsonl` files**, also check `~/.claude/history.jsonl` (an
   index of recent user prompts across *all* projects) to find candidate slugs — a slug
   that resolves cleanly but yields no session files is not evidence the session doesn't
   exist; work in one project can be recorded under a different slug (e.g. sessions run
   from a home-directory shell land under the home-dir slug `-Users-<you>`, not the
   project-specific one) — treat `history.jsonl` as an index only, not a source of full
   conversation text.
4. **Extract assistant text from each matching file:**
   ```bash
   python3 -c "
   import json
   with open('PATH_TO.jsonl') as f:
       lines = [json.loads(l) for l in f if l.strip()]
   for entry in lines:
       if entry.get('type') == 'assistant':
           for block in entry.get('message', {}).get('content', []):
               if isinstance(block, dict) and block.get('type') == 'text':
                   text = block.get('text', '')
                   if len(text) > 100:
                       print('=== ASSISTANT ===')
                       print(text[:3000])
   "
   ```
   For multi-MB sessions, delegate the extraction to a subagent rather than printing into
   the main context.
5. **If multiple files match**, run the same extraction on each and pick the most relevant
   session by its `timestamp` field (present on every entry) — don't assume the first
   match is the right one.
6. **Report back** what was found, which session file(s) it came from, and the
   approximate timestamp — so the user can tell which conversation it was.

## Storage locations (reference)

| Location | Contents |
|---|---|
| `~/.claude/projects/<project-slug>/*.jsonl` | All messages for sessions in that project |
| `~/.claude/history.jsonl` | Index of recent user prompts across all projects (prompts only, not full text) |
| `~/.claude/sessions/*.json` | Older session snapshots |

## Red flags

| Rationalization | What to do instead |
|---|---|
| "I don't have access to past sessions." | You do — they're local JSONL files under `~/.claude/projects/`. Search them (Step 1-4) before telling the user it's not possible. |
| "history.jsonl has the keyword, that's enough." | `history.jsonl` is a prompt index only, not the full conversation — go to the matching project's `*.jsonl` files (Step 3-4) for actual content. |
| "The first matching file is probably the right one." | `grep -l` can return several files — check timestamps (Step 5) and pick the session that actually matches, don't guess from ordering. |
| "Any grep hit is a relevant session." | Short keywords substring-match unrelated words and the search itself gets logged (agentmemory mirrors the current request into its own transcripts) — prefer `grep -lw` or longer phrases, and exclude the current session's own file and MCP-mirror slugs before reporting a match. |

## Exit criteria

- [ ] The project slug was derived from an actual working-directory path, not guessed.
- [ ] At least one `*.jsonl` file was actually searched (not just `history.jsonl`).
- [ ] When multiple files matched, each was checked and the most relevant one selected by
      timestamp before reporting back.

## Provenance
Provenance: learnings/skill-sharing.md (2026-07-04 entry, "Skills have no standardized
export path" — the same porting pipeline this skill entered hq through).
Lineage: X-context-docs skills/search-past-sessions@9d7143e (originally ported @87ed5a6; re-pinned to this round's snapshot)

### Refit notes (declared changes vs. source)

- **Dropped the "Model Delegation" re-exec block.** The source frontmatter carried
  `model: haiku` *and* a body section instructing the agent to re-invoke itself via
  `claude --model claude-haiku-4-5-20251001 -p "..."` from Bash if not already on that
  model. Evaluated under Claude Code: `tools/skill-authoring.md` §1 lists `model` as a
  native, supported frontmatter field — Claude Code already pins the model for a skill
  invocation via that field alone. The Bash re-exec block is a workaround for a runtime
  that (at the time the source was written) may not have honored `model:` in frontmatter,
  or was defensive belt-and-braces. Under the current native format, the field does the
  job; the re-exec block is redundant and, if kept, would spawn a second nested `claude`
  process from inside a skill invocation — a side effect with no clear benefit. Dropped;
  `model: haiku` in frontmatter is kept as-is.
- **Path example de-workified.** Source line ~38 used
  `/Users/<work-username>/projects/my-repo` → `-Users-<work-username>-projects-my-repo`
  as its slug-derivation example, with the work-machine username spelled out literally.
  Replaced with a fully generic placeholder form (`/Users/<you>/projects/my-repo` →
  `-Users-<you>-projects-my-repo`) rather than substituting in this machine's personal
  username — the example is illustrative of the transform, not a real path, so no
  work-identity or personal-identity string needed to land in the ported file at all.
- **Quick Reference section dropped as a separate block** — source repeated Steps 1-3 a
  second time near the foot of the file as a condensed "Quick Reference" (with the same
  work-username path baked into its example grep command). Folded into the numbered
  `## Steps` instead of duplicating; nothing in it wasn't already covered by Steps 1-3.
- **Restructured to the authoring standard** — added `## Trigger`, `## Red flags`, `##
  Exit criteria`, `## Provenance` (none existed in source, which had `## Overview` /
  `## Storage Locations` / `## Steps` / `## Common Mistakes` / `## Quick Reference`); the
  source's "Common Mistakes" list became the `## Red flags` table (reworded as
  rationalization → do-instead pairs); "Storage Locations" kept as a reference table.
- **2026-08-24 correction: `model: haiku` alone does not run the skill on Haiku.**
  The earlier refit note above ("model: haiku in frontmatter is kept as-is") was wrong.
  Verified directly against the official Claude Code skills docs
  (code.claude.com/docs/en/skills, frontmatter reference table): `model:` without
  `context: fork` only overrides the *current turn's* reasoning model inline — it does
  not spawn an isolated subagent/subprocess, so a skill invoked in a normal (non-forked)
  turn never actually executes on Haiku; it just runs on whatever model the calling
  conversation was already using. Live-tested via the `Skill` tool prior to this fix and
  confirmed no model boundary occurred. Fix: added `context: fork` (runs the skill body
  as the prompt for an isolated subagent — per docs, "with `context: fork`, the value
  [of `model:`] sets the forked subagent's model instead") plus `agent: general-purpose`
  (explicit default) and `background: false` (this skill's result is needed synchronously
  by the calling turn, not as a fire-and-forget background task; default is
  `background: true`, requires Claude Code v2.1.218+, confirmed running v2.1.233 here).
  Also added a `## Query` section with `$ARGUMENTS` — required because `context: fork`
  means the subagent has no access to the calling conversation's history, so the search
  keyword/topic must be passed explicitly as skill arguments or it has nothing to search
  for. Live-tested post-fix; see the skill's live-test note in the fix's PR/commit for
  the transcript-boundary evidence.
