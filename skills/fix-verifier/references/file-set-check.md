# FILE_SET check (fix-verifier 1.1.0)

Why: one fixer per worktree, or one worktree per fixer with disjoint file sets computed from
the findings (M18). `FILE_SET` is per fixer. The check stops a fixer from widening a fix
beyond its findings (M24).

Transport: `FILE_SET=a.md,b.md`, an UPPER_SNAKE `NAME=value` argument (INTERFACES D2.3,
row R4-J22), never a key in the Input Contract JSON. Absent `FILE_SET` is valid: no
validation, no new finding, output identical to the unmodified skill. Never treat absence
as an empty set.

## Terms

- **Project root**: the root computed in Step 2 by the SKILL.md Security rules
  (canonicalize `changed_files` first, then marker precedence `.git` > `package.json` >
  `CLAUDE.md`, walking up from `changed_files[0]`).
- **Repo-relative**: relative to that project root. `FILE_SET` entries are repo-relative.
- **Canonical absolute path**: the Security canonicalization (`realpath` equivalent) of a
  path joined to the project root. It is the only form ever compared (below).
- **The orchestrator**: the caller that dispatches fix-verifier (the `lead` persona in a
  delivery run). Emitted finding text says "the orchestrator", never "lead".

## Step 0 (FILE_SET): validation (D1)

Ordering:
- Steps 1-2 run first. Their errors (empty `changed_files`, root resolved to `/`) keep their
  existing JSON shape and take precedence over Step 0.
- Step 0 runs after Steps 1-2 and finishes before any check runs and before the content of
  any changed or related file is read. Path lookups (existence, canonicalization) are not
  content reads.
- After a Step 0 `INPUT-ERROR`, Steps 3-5 are not reached.

Order of the rules:
1. **Split and trim.** Split the value on `,`; trim whitespace around each entry.
2. **`format`** (needs no root): `FILE_SET` is set but empty (`FILE_SET=`), or any entry is
   empty after trimming (`a.md,,b.md`, a trailing comma). Emit `INPUT-ERROR FILE_SET format`.
3. **`path`** (needs the project root): an entry is absolute (starts with `/`); or, after
   lexical normalization (below), it escapes the root (`../x`, `a/../../x`) or equals the
   root itself (`.`, `a/..`); or it exists and its canonical absolute path lies outside the
   root (a symlink out). Emit `INPUT-ERROR FILE_SET path`. Never silently dropped, never a
   `files_not_checked` entry (this exempts `FILE_SET` from the Security traversal rule).

One line per failing field: `FILE_SET` is one field, so at most one line; `format` wins
when both apply. `missing`, `enum` and `unset` are never emitted by this skill (D1
reserves them for other inputs).

## Two response shapes

1. The Output Contract JSON (every run without a Step 0 failure).
2. Only with a malformed `FILE_SET`: the single line `INPUT-ERROR FILE_SET <reason>`,
   matching D1's regex `^INPUT-ERROR [A-Za-z_][][A-Za-z0-9_.]* (missing|enum|path|unset|format|sha)$` (INTERFACES 1.5.0).
   The entire response is that line: no preamble, no explanation, no JSON, no code fence,
   no trailing text, no verdict. Then stop: no retry, no prompt, no checks.

The caller detects shape 2 by a first line matching `^INPUT-ERROR `, fixes the input and
re-dispatches with the same iteration number: the reply is not an iteration and gets no
`verify-*` record (INTERFACES 1.5.0 D1, AM-4 11-Q11-R1; SKILL.md Loop Integration).

Red flag: "I'll explain the `FILE_SET` error first, then print the line." No: print only
the line.

## Normalization (one form)

For each entry that passed Step 0:
1. Join it to the project root and collapse `.` segments, `..` segments and duplicate
   slashes lexically. Drop a trailing slash.
2. If that path exists, replace it with its canonical absolute path, using the same
   canonicalization step as `changed_files` in SKILL.md Security. If it does not exist (a deleted file
   can be in the set), keep the lexical form from 1.
3. Duplicates collapse to one set member.

Entries are exact file paths. A directory entry is not a prefix match: `docs` does not cover
`docs/a.md`. **Never compare mixed forms:** a repo-relative string is never compared with
an absolute one; both sides are canonical absolute paths (lexical only where the file does
not exist).

## Changed paths (set comparison, no shell)

Two sources, both normalized to canonical absolute paths as above:

1. **`changed_files`**, after the Security canonicalization, in input order. Every entry is
   compared, including entries that are unreadable, deleted, or listed in
   `files_not_checked`.
2. **`diff` file headers**, only when `diff` is supplied, in diff order. Text parsing only.

### Diff header parsing

- **Git-style diff** (it contains a `diff --git` line). A `diff --git a/X b/Y` line opens a
  file section. Its header block runs from that line to the section's first `@@` line (or
  the next `diff --git` line). Paths come only from the header block:
  - the `diff --git a/X b/Y` line itself (X and Y; covers binary and mode-only changes);
  - `rename from X` and `rename to Y` (covers pure renames);
  - `--- a/X` and `+++ b/Y` (covers deletions and the old side of renames).
  Every line after the section's first `@@` is hunk body until the next `diff --git` line;
  a hunk-body line starting with `---` or `+++` is never a header. Strip a single leading
  `a/` or `b/` from each path (git-style only); unquote C-quoted paths; when a path holds
  spaces, take it from the `---`/`+++`/`rename` lines rather than the `diff --git` line.
- **Plain unified diff** (no `diff --git` line). A header is a `--- X` line directly followed
  by a `+++ Y` line, outside any hunk body; a hunk body is the number of lines declared by
  its `@@ -l,s +l,s @@` counts. No `a/`/`b/` stripping.
- In both: cut anything after a TAB (timestamps); ignore `/dev/null`. A relative header path
  is joined to the project root; then normalize as above.

### Outside the project root

A `changed_files` entry rejected to `files_not_checked` (traversal attempt or outside the
project root), or a diff header path outside the root, is still a change outside
`FILE_SET`. It yields one Check 3 Medium finding: `file` is its canonical absolute path (or,
when it cannot be canonicalized, the header path joined to the project root and lexically
normalized, which is absolute), and the description says it
is outside the project root. Its `files_not_checked` entry stays exactly as today.

### Findings

One finding per changed path not in the set, de-duplicated by canonical absolute path:
`changed_files` order first, then diff order (a path already reported is not reported
again). `related_files` are not changes; never flag them.

Finding object:
- `check`: `"3"`; `severity`: `Medium`.
- `file`: the canonical absolute path (the root-joined path).
- `description`: `change outside FILE_SET: <repo-relative path>`; for a path outside the
  root: `change outside FILE_SET (outside the project root): <path>`.
- `recommended_fix`: `the orchestrator widens FILE_SET, or the fix agent reverts this file`.

Verdict follows the existing rule (a Medium finding yields `ISSUES_FOUND`). With every
changed path inside the set the check adds no finding. No new verdict value, no new check
id, no shell call by the verifier.

## Scope exception

The SKILL.md Check 3 text and Exit criterion 1 limit scope to `changed_files`. This
sub-check is the sole exception, and only when `FILE_SET` is supplied: it also reads the
`diff` file headers (paths only, never content). With `FILE_SET` absent the scope rule is
unchanged.
