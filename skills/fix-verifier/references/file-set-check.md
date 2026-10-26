# FILE_SET check (fix-verifier 1.1.0)

Why: one fixer per worktree, or one worktree per fixer with disjoint file sets computed from
the findings (M18). `FILE_SET` is per fixer. The check stops a fixer from widening a fix
beyond its findings.

## Step 0 validation (D1)
Run only when `FILE_SET` is supplied. Print one line per failing field and stop (no retry,
no prompt, no verdict):
- `INPUT-ERROR FILE_SET format` - set but empty (`FILE_SET=`), or an empty entry.
- `INPUT-ERROR FILE_SET path` - an entry that is absolute, or that escapes the project root
  after canonicalization (`../x`). Never silently dropped.
- `INPUT-ERROR FILE_SET missing|enum|unset` - reserved by D1 for the caller's transport.
Absent `FILE_SET` is valid: no new finding, output identical to the unmodified skill (never
treat absence as an empty set).

## Comparison
1. Canonicalize every entry against the computed project root (same order as Security).
2. Compare with canonicalized `changed_files` (absolute). Do not compare mixed forms.
3. Each changed file not in the set: one finding, `check: "3"`, severity Medium, `file` =
   that absolute path, description naming `FILE_SET`, `recommended_fix`: "lead widens
   FILE_SET or the fixer reverts this file".
4. `related_files` are not changes; never flag them.
5. Verdict follows the existing rule (Medium yields `ISSUES_FOUND`). No new verdict value,
   no new check id, no shell call.
