# Fix record r1b: delivery-pipeline (W2 item 29), 2026-10-26

Narrow fixer r1b. Inputs: verify-fix-delivery-pipeline-r1-2026-10-26.md (v1-01 M, v1-02 M; Lows v1-03 and v1-06 per dispatch), preround-delivery-pipeline-r2-2026-10-26.md (C2 x1, C5 x4). Paths under `skills/delivery-pipeline/`.

| finding id | status | file:line after the fix | one-line change |
|---|---|---|---|
| v1-01 | FIXED | SKILL.md:19; references/stages.md:71 | Step 6 "ready" is now launch-ready on `depends-on` only (R2, 29-14); one sentence each says merge order (29-18) governs only the 5b merge precondition, never a release. |
| v1-02 | FIXED | SKILL.md:22 (R4); references/tick-relay.md:9; references/resume.md:18; references/provenance.md:51 | The gate now covers every tick and stage step: no desk send, relay, rename, lead launch (tick 4b, 4c, 7; SKILL steps 6, 12) or `ticket-clerk` run (tick 9) before `REGISTERED <run-id> \| run \| ok`; only file reads and local `state.md`/inbox writes go on. The "read only" step list is gone. |
| v1-03 | FIXED | SKILL.md:22 (R2); references/tick-relay.md:102 | Added "except `RELEASE pm`, written by step 12 (first and second `pm` lead)". |
| v1-06 | FIXED | references/launcher.md:51 | The command-shape lead-in now says that for `pm` the first command is `cd "<primary_repo>"` (Worktree row). The bash block is unchanged. |
| v1-04 | not in scope | - | L, not named in the dispatch. |
| v1-05 | not in scope | - | L, not named in the dispatch. The am5-queue.md part is the integrator's. |
| PR2-C2 | FIXED | references/provenance.md:9 | Dropped the unpointed scope-control retro claim. No path:line for the retro was found in W or in hq, so the row now cites `workflow-orchestration` `SKILL.md:73` only. |
| PR2-C5a | FIXED | SKILL.md:25 | "(29-16)" -> "(proposed, 29-16)". |
| PR2-C5b | FIXED | SKILL.md:27 | "the `st0` backend, 29-19" -> "the `st0` backend, proposed 29-19". |
| PR2-C5c | FIXED | references/resume.md:48 | Added "proposed, 29-6" to the third-relaunch bullet (29-6 is the relaunch-limit row). |
| PR2-C5d | FIXED | references/tick-relay.md:101 | Added "proposed, 29-14" to the INVALIDATE-recipient clause. |

## Owner questions

None new. This pass has no OWNER or OBJECTION rows.

## New proposed conventions

None. The edits reuse 29-6, 29-14, 29-16, 29-18 and 29-19. The 29-16 row in provenance.md:51 is widened to cover the gate's launch and `ticket-clerk` scope.

## Checks

- `bash SCRATCH/s9-29.sh`: last line `PIPELINE-29-OK`, with 0 failure words.
- `peek:true`: 0 hits.
- `wc -w SKILL.md`: 3652 words (limit 3800).
- `bash tools/check-doc-length.sh .`: 0 blocking files.
- Templates untouched and no new files.
