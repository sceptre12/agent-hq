---
name: organizing-files
description: >-
  Maintain a coded filing system for ~/Documents via the fileorg CLI. Use when
  the user says "file this," "where's the file about X," "organize Documents,"
  or "what folder does this go in." Shells out to fileorg.py; the CLI is the
  only thing that touches the index or moves files.
---

## Trigger

Use when filing a new document, answering "where's the file about X," organizing or
tidying `~/Documents`, or deciding what folder a file belongs in — "file this,"
"organize Documents," "what folder does this go in." `fileorg.py` (this directory) is
the single tool that owns the SQLite index and every move under the taxonomy; never
move, rename, or delete a taxonomy file by hand — shell out to the CLI instead.

## Steps

`fileorg.py` is stdlib-only Python; always run it with the absolute interpreter path so
it also works headlessly (`/usr/bin/python3`, not bare `python3`):

1. **Refresh the index and see drift.**
   ```
   /usr/bin/python3 fileorg.py scan
   ```
   Walks `~/Documents`, reconciles the index against the filesystem, and reports drift
   (loose files, uncoded folders, junk, duplicates). Idempotent — re-running never
   duplicates rows.

2. **File one file — dry-run first, then move.**
   ```
   /usr/bin/python3 fileorg.py place /path/to/incoming-file.pdf --dry-run
   /usr/bin/python3 fileorg.py place /path/to/incoming-file.pdf
   ```
   `--dry-run` prints the planned classification and destination without moving
   anything. Drop the flag to move the file and record it in the index. See
   Red flags below for what happens on low confidence or a destination collision.

3. **Find a file.**
   ```
   /usr/bin/python3 fileorg.py query keyword another-keyword
   ```
   Searches code, filename, description, and tags in the index — terms are ANDed.

4. **Annotate a file.**
   ```
   /usr/bin/python3 fileorg.py note /path/to/CODE-Name/file.pdf "short description"
   /usr/bin/python3 fileorg.py tag  /path/to/CODE-Name/file.pdf tag-one tag-two
   ```
   Attach a free-text description or searchable tags to an already-indexed file.

5. **Sweep a directory — dry-run first, then live.**
   ```
   /usr/bin/python3 fileorg.py sweep ~/Downloads --dry-run
   /usr/bin/python3 fileorg.py sweep ~/Downloads
   ```
   Files every top-level file in the directory (default `~/Downloads`) through the
   same classifier `place` uses — confident matches are auto-filed, everything
   low-confidence / folder-ambiguous / collision / or destination-protected is staged to
   `SYS-Unsorted/` with `needs-review` (see Protected paths below for the distinction:
   a source file that is itself inside a protected path is refused as a pure no-op
   instead). Subdirectories are skipped (no recursion),
   and in-progress downloads (`.crdownload`, `.download`, `.part`, `.tmp`) are left
   for a later run. A per-run PID-file lock means a second overlapping `sweep`
   logs `already running, skipping` and exits 0 rather than colliding. One summary
   line (scanned / filed / staged / errored) is appended to
   `${XDG_DATA_HOME:-~/.local/share}/file-organizer/logs/sweep.log` on every run,
   dry-run included. This is also the verb the daily launchd job invokes — run the
   `--dry-run` form and review it before installing the job live.

6. **Apply an already-decided classification — dry-run first, then move.**
   ```
   /usr/bin/python3 fileorg.py apply-classification /path/to/staged-file.pdf FIN-Finance --dry-run
   /usr/bin/python3 fileorg.py apply-classification /path/to/staged-file.pdf FIN-Finance
   ```
   Moves ONE file into ONE already-named destination folder — the folder is a
   decision you (or an LLM classification pass) have already made, not one the
   tool computes. The destination `folder` must be a **real, recognized**
   `CODE-Name` folder that exists on disk under `~/Documents`; a hallucinated,
   misspelled, or unknown folder name is **refused** and the file is left
   untouched — the verb never creates a folder, never guesses, never falls back.
   The same protected-path guard `place` uses runs on the resolved destination:
   a file that would land in a protected tree is refused and staged to
   `SYS-Unsorted/` with `needs-review` instead (see Protected paths below), no
   matter how confident the caller was. A destination collision is refused and
   staged the same way. Every move — success and refuse-and-stage — goes through
   the one mover the tool uses everywhere. This verb is what the on-demand
   `organize-backlog` workflow calls for each confidently-classified staged file — use `organize-backlog-scope.js` to preview scope, then `organize-backlog-run.js` to classify and file. It is **interactive/on-demand only** —
   there is no scheduled job for it.

**Taxonomy (supporting detail).** Top-level folders are `CODE-Name` (e.g.
`FIN-Finance`, `WRK-Work`). `SYS-` is reserved for the tool's own folders (like
`SYS-Unsorted/`) and is never a category. The 16 category codes and their keywords
live in `codes.default.json`; personal renames go in a local, non-synced
`codes.local.json` beside the index database.

**Protected paths — legal-discovery guard (supporting detail, ADR 0018).**
`codes.local.json` (the same local, non-synced file used for personal code renames
above) can also carry a `"protected"` array: paths, relative to the Documents root,
that `place` must never move into, out of, or overwrite — for example an active
legal-discovery export. Shape (neutral placeholder path — replace with the real
relative path being protected):
```json
{
  "protected": ["LEG-Case/Export"]
}
```
Every subpath beneath a protected entry is covered, including one reached through a
symlink (a symlinked protected directory, or a symlinked subdirectory inside one, is
still caught). A source file that is itself inside a protected path is refused as a
pure no-op (`refuse-protected-source` — nothing moves, nothing is staged, nothing is
recorded). A computed destination that lands inside a protected path is refused and
the file is staged to `SYS-Unsorted/` with `needs-review` instead
(`refuse-protected`) — it never falls back to a different folder for the same code.
**Without a `codes.local.json`, or without a `"protected"` key in it, the guard is
INACTIVE.** `place` still runs — a generic user with nothing to protect needs a
working tool with zero config — but prints a
`warning: no protected paths configured (ADR 0018 guard inactive)` line to stderr on
every invocation, so a guarded run and an unguarded run are never indistinguishable.
If the Documents tree contains a legal export or anything else that must never move,
configure `protected` FIRST, before running `scan` or `place` against that tree.

## Red flags

| Rationalization | What to do instead |
|---|---|
| "I'll just pick the category myself and tell the CLI." | The CLI never prompts you to pick a category — `place` classifies fully automatically, by keyword/extension rule or an already-coded relocation. There is no manual-override path to invent. |
| "The match looks close enough, I'll guess the folder." | LOW CONFIDENCE — no rule match, a scoring tie, or a computed code with zero or more than one matching `CODE-Name` folder on disk — always stages to `SYS-Unsorted/` with a `needs-review` tag. Never guess-file a file into a category by hand. |
| "A file's already at that destination, I'll move mine on top of it." | The CLI refuses to overwrite. If the computed destination already exists, it re-routes the incoming file to `SYS-Unsorted/` instead — never silent, never clobbered. |
| "SYS-Unsorted already has a file with that name too, force it through." | A second collision at the `SYS-Unsorted/` staging path aborts the move entirely (nothing is recorded) rather than clobbering the file already staged there. |
| "I'll skip --dry-run, I'm confident about this one." | Prefer `--dry-run` first regardless — it costs nothing and previews the planned destination before anything actually moves. |
| "The index looks stale, I'll just hand-edit index.db." | The database is a rebuildable index, not ground truth — `~/Documents` is ground truth. Re-run `scan` to reconcile instead of touching the DB directly. |
| "There's no legal export in this tree, I don't need to set up `protected`." | The guard is inactive by default with no `codes.local.json` `"protected"` list — `place` still runs, but check stderr: it prints a `guard inactive` warning on every single invocation until `protected` is configured. If the tree has anything that must never move, configure it FIRST. |
| "The daily sweep can just run live without me checking it first." | Run `sweep ~/Downloads --dry-run` and review the planned actions before the launchd job is installed live — same dry-run-before-live ritual `place` uses. The sweep never prompts; a wrong keyword map silently mis-files, so preview first. |
| "The LLM said this file goes in that folder, I'll trust it and move it there directly." | Route it through `apply-classification` — it re-validates that the folder is a real, recognized folder on disk, re-runs the protected-path guard on the destination, and refuses collisions, no matter how confident the classifier was. A hallucinated folder name is refused and the file left untouched; it never creates a folder or falls back to a guess. |

## Exit criteria

- [ ] The file is either placed at its coded destination or staged in `SYS-Unsorted/`
      with `needs-review` — never left unaccounted for.
- [ ] Nothing was overwritten: no move proceeded when the computed destination (or its
      `SYS-Unsorted/` fallback) already existed.
- [ ] The index reflects the file's final location (re-run `scan` if state is uncertain).
- [ ] `--dry-run` was used to preview before a first-time or non-trivial move.
- [ ] If the Documents tree contains anything that must never move (e.g. a
      legal-discovery export), `protected` is configured in `codes.local.json` before
      `scan` or `place` ran against it — if unsure, check stderr for the guard-inactive
      warning.

## Provenance
Provenance: architecture/file-organizer.md (§3.1 binds this skill to
`tools/skill-authoring.md`'s house format). No separate friction/learning entry exists for this skill; the architecture
spec is the recorded design source it derives from.
