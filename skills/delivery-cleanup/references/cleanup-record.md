# Cleanup record

Path: `RUN_HOME/cleanup-<run-id>-<subtask|final>.md` (`<subtask>` is `st<N>` or `pm`). Never deleted by cleanup, never listed as a catalog resource. Contract: A.6 and D1.1 (`architecture/delivery-workflow/interfaces/part-a-state.md`, `part-d-enums-topics.md`).

## Layout, in order
1. Line 1 only: `CLEANUP DONE st<N>`, `CLEANUP DONE pm` or `CLEANUP DONE final`; regex `^CLEANUP DONE (st[0-9]+|pm|final)$`. It is carried by this line only, never by stdout.
2. `## dry-run`: the table from `references/dry-run-table.md`, the bases header, audit lines.
3. `## approved`: the approver and the explicit row-id list, with each `keep <reason>` decision.
4. `## executed`: the executor id, then every command run with its exit code, one per line; branch `.req` ids, their `DESK` lines and the `DONE` or `REJECTED` result (hand-off: `references/executor-rules.md`).
5. `## residual`: non-catalog finds (reported, not deleted), kept rows with reasons, mismatches, then the `validator` block ending `SPOT-CHECK PASS` or `SPOT-CHECK FAIL <n>`.

## Writers and atomic write
- Writer: the `cleanup-executor` (A.6). At the start of Step 4 it creates `cleanup-<run-id>-<subtask|final>.md.tmp` with `## dry-run` and `## approved` copied verbatim from its dispatch, then appends to `## executed` as it acts (a hand-off re-dispatch continues the same file). When every approved row and every hand-off result is applied it writes `## residual` last, without line 1, and stops writing.
- The `validator` appends its block to the end of the temp file (inside `## residual`). It writes nothing else.
- One temp file only (A.6). On the validator's `SPOT-CHECK PASS` line (the validator also ran the catalog checks, `references/executor-rules.md` Spot-check) the executor, without re-checking, inserts line 1 `CLEANUP DONE <subtask|final>` at the top of the same `.md.tmp` (an in-place edit of the temp, for example `printf '%s\n' 1i 'CLEANUP DONE st1' . w q | ed -s <tmp>`), which is its last write, then `mv`s the `.md.tmp` onto the final name. The final name appears only through that `mv`, so a reader that sees line 1 sees all sections.

## Failure path
On `SPOT-CHECK FAIL`, a count-basis mismatch, a block, or a scope row still latest `planned`, `live` or `failed` in `catalog.tsv` (a `failed` row is an attempt that did not complete, never done), no final file is written and no `CLEANUP DONE` line exists: the `.tmp` stays with the reason in `## residual`. With no line 1 the conductor never sets the sub-task `cleaned`, so mode `final` does not start. The approver reports it by a C2 `ESCALATE` with reason `human-step` naming the `.tmp` path and the reason (owner-accepted answer to OQ-A, AM-5 queue row "(19)"); it appears in the conductor's status. A re-run or a resumed host restarts at Step 1 with a new audit and dry run. Its executor first renames an existing `.md.tmp` to `.md.tmp.<n>` (`n` = 1 + the count of earlier `.md.tmp.*`; skill default) and copies that file's `## executed` lines into the new `## executed` under a line `prior attempt: <file>`, so no executed command is lost.

## Readers
The conductor sets the sub-task `cleaned` from line 1 (part A.2 `subtasks[].state` transitions). Mode `final` runs after every `subtasks[]` entry is `cleaned`, before `stage: done`, or after `state.md` `stage: stopped` (abandoned run, C5.1).
