# Cleanup record

Path: `RUN_HOME/cleanup-<run-id>-<subtask|final>.md` (`<subtask>` is `st<N>` or `pm`). Never deleted by cleanup, never listed as a catalog resource.

## Layout, in order
1. Line 1 only: `CLEANUP DONE st<N>`, `CLEANUP DONE pm` or `CLEANUP DONE final`; regex `^CLEANUP DONE (st[0-9]+|pm|final)$`. It is carried by this line only, never by stdout.
2. `## dry-run`: the table from `references/dry-run-table.md`, the bases header, audit lines.
3. `## approved`: the approver and the explicit row-id list, with each `keep <reason>` decision.
4. `## executed`: the executor id, then every command run with its exit code, one per line; branch `.req` ids and the `DONE` or `REJECTED` result.
5. `## residual`: non-catalog finds (reported, not deleted), kept rows with reasons, mismatches, the `validator` result (`SPOT-CHECK PASS` or `FAIL`).

## Atomic write
The executor writes the whole file to `cleanup-<run-id>-<subtask|final>.md.tmp`, checks that `## residual` is complete, then `mv` onto the final name. A reader that sees line 1 sees all sections. Line 1 is written only after the `validator` has passed; a failed spot-check leaves the temp file and no `CLEANUP DONE`.

## Readers
The conductor sets the sub-task `cleaned` from line 1 (part A.3 transitions). Mode `final` runs only after every `subtasks[]` entry is `cleaned`, and before `stage: done`.
