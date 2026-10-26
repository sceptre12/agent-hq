# PR Review — Step 8 review record (local-diff mode)

Line 1 is `CODE-GATE-REVIEW: PASS head=<HEAD_SHA> blocking=0 medium=0` only when both counts are 0, else
`CODE-GATE-REVIEW: FAIL head=<HEAD_SHA> blocking=<b> medium=<m>`. Line 2 is
`Reviewed-By: <seat-id> <session> <TASK-id>` (A.6). Line 3 is an empty placeholder reserved for
`Verified-By: <seat-id> head=<sha>` (A.6), line 4 is blank, and the Phase B report starts at line 5. The
verifying seat REPLACES line 3 in place, e.g.
`sed -i '' "3s/^$/Verified-By: <seat-id> head=<sha>/" "$RECORD_PATH"`, and never appends. File
paths in the record (`repo_dir`, `RECORD_PATH`, any path the report names) are written `~`-relative,
never as an absolute home path. Standalone, only a PASS record is copied to
`task-pipeline/.review/<head-sha>.md` in the merge commit; a FAIL record stays with the author. Inside a
run the record is the A.6 file `RUN_HOME/review/<subtask>/record-<head>.md` (`RECORD_PATH`), which the
desk reads via `record_path`; the A.6 path governs there.

The orchestrator writes `RECORD_PATH` from the synthesizer's Phase B report. Inputs and their sources:

- `PHASE_B_REPORT_FILE="$(dirname "$RECORD_PATH")/phase-b-${HEAD_SHA}.md"`: the orchestrator writes the
  synthesizer's reply (the Phase B report, verbatim) to this file. Inside a run that directory is
  `RUN_HOME/review/<subtask>/` (A.1, pr-review's); never `/tmp` or `$TMPDIR` in a run. It is not copied
  elsewhere.
- `B`, `M`: the Blocking and Medium counts of the report's severity summary
  (`X Blocking, Y Medium, Z Advisory`, `synthesizer-brief.md` Step 4): `B=X`, `M=Y`.
- `HEAD_SHA` (Step 2); `SEAT_ID`, `MEMBER_SESSION_NAME`, `TASK_ID` (Step 0 validated them against the
  A.6 line-2 regexes, so no field is empty).

```bash
# Never write line 2 with an empty field (Step 0 already refused one; this is the backstop)
[ -n "$SEAT_ID" ] && [ -n "$MEMBER_SESSION_NAME" ] && [ -n "$TASK_ID" ] || { echo "ERROR: record line 2 field empty — stop"; exit 1; }
# Inside a run the record is the A.6 file for this head
if [ -n "${RUN_HOME:-}" ]; then
  [ "$RECORD_PATH" = "$RUN_HOME/review/$SUBTASK/record-$HEAD_SHA.md" ] || { echo "ERROR: RECORD_PATH is not the A.6 path for head $HEAD_SHA — stop"; exit 1; }
fi
PHASE_B_REPORT_FILE="$(dirname "$RECORD_PATH")/phase-b-${HEAD_SHA}.md"
[ -s "$PHASE_B_REPORT_FILE" ] || { echo "ERROR: Phase B report not written to $PHASE_B_REPORT_FILE — stop"; exit 1; }
# PASS only if B=0 and M=0; otherwise FAIL with the real counts
if [ "$B" -eq 0 ] && [ "$M" -eq 0 ]; then V=PASS; else V=FAIL; fi
printf 'CODE-GATE-REVIEW: %s head=%s blocking=%s medium=%s\nReviewed-By: %s %s %s\n\n\n' \
  "$V" "$HEAD_SHA" "$B" "$M" "$SEAT_ID" "$MEMBER_SESSION_NAME" "$TASK_ID" > "$RECORD_PATH"
cat "$PHASE_B_REPORT_FILE" >> "$RECORD_PATH"
# Identity check — no secrets or tokens in the record; must print 0
grep -cE 'sk-ant-|gh[opsu]_|github_pat_' "$RECORD_PATH"
# Line 1 shape (PASS or FAIL); must print 1. A PASS line also matches the A.6 line-1 regex.
sed -n 1p "$RECORD_PATH" | grep -cE '^CODE-GATE-REVIEW: (PASS|FAIL) head=[0-9a-f]{40} blocking=[0-9]+ medium=[0-9]+$'
# A.6 shape check of line 2; must print 1
sed -n 2p "$RECORD_PATH" | grep -cE '^Reviewed-By: ([a-z0-9-]+) ([a-z0-9-]+) ([A-Za-z0-9_-]+)$'
# Line 3 is the empty Verified-By placeholder (must be empty before verification); line 4 blank
[ -z "$(sed -n 3p "$RECORD_PATH")" ] && [ -z "$(sed -n 4p "$RECORD_PATH")" ] || { echo "ERROR: record line 3/4 not empty — stop"; exit 1; }
```

A grep count other than 0 (secrets) or 1 (line 1 and line 2 shapes) is a stop-on-anomaly: do not hand
the record over. The skill never writes `Verified-By:`; line 3 is written by the verifying seat (A.6),
whose `seat-id` differs from line 2's, by replacing the empty line 3 in place.
