---
name: resource-catalog
version: 0.1.0
description: Register, start, release, keep and audit every resource a delivery run creates, through catalog.sh. Use when before and after starting any worktree, branch, tag, process, pm2 app, port, bus, temp dir, container, lease, cron or background task in a run, when a port must be claimed first (port-check.sh --claim, then a port row), when a resource is found that no catalog row names, or when a lead reconciles with audit. One append-only TSV row per event; the script owns the cleanup commands.
---

## Trigger
Use when: a run is about to create, or has just created, a resource of any catalog kind (kinds and handle forms: `references/kinds-and-handles.md`); when a bound port is involved (`references/ports.md`); when `list --live` or `audit` is needed at resume, before a gate or at cleanup; or when a resource turns up that no row names.
Not for: deleting anything (that is `delivery-cleanup`, which acts on catalog rows only) and not for editing the catalog or the port registry by hand.

## Steps
Scripts: `~/projects/agent-hq/tools/delivery/catalog.sh` (the only appender; item 5) and `~/projects/agent-hq/tools/port-check.sh`. Examples below call `catalog.sh` as a bare name for brevity.

0. Step 0, inputs. `RUN_HOME` is an environment variable (absolute, its last segment the run-id), the named exception to `NAME=value` arguments; unset is exit 2 from the script. If `DELIVERY_ROOT` is unset, print `INPUT-ERROR DELIVERY_ROOT unset` and stop. If `RUN_HOME` is unset, print `INPUT-ERROR RUN_HOME unset` and stop. A call that registers a worktree also passes `WORKTREE_BASE` inline from the profile (`WORKTREE_BASE=<base> catalog.sh register worktree ...`), because the script checks the path against `RUN_HOME` or that registered base.
1. Register before you start. One call, 7 arguments after `register`: kind, handle, unit (or `-`), correlation_id, source, subtask (or `run`), owner_agent. It writes a `planned` row and prints the `row_id`.
   ```
   catalog.sh register tmpdir /abs/run-home/tmp/st1 u07 <JIRA-KEY>-1234 delivery-run st1 impl-u07
   catalog.sh register pm2-app found-1234-st1-api - <JIRA-KEY>-1234 delivery-run run lead
   ```
   `unit` matches `^([ui][0-9]+|-)$`; use `-` for run-level rows, never empty. Handle grammar per kind: `references/kinds-and-handles.md` and INTERFACES A.5. Path-kind handles must have a realpath under `RUN_HOME` or the registered worktree base; the script rejects control characters and any row over 400 bytes.
2. Start the resource, then mark it: `catalog.sh start <kind> <handle>` writes `live`. Do not start before the `planned` row exists (the pre-PR gate fails on any `planned` row left behind).
3. Release when you stop it: `catalog.sh release <kind> <handle>`; a `released` row supersedes the earlier ones (supersede key is kind plus handle, latest row wins). If the start failed, `catalog.sh fail <kind> <handle>`.
4. Keep with a reason when a resource must outlive the run: `catalog.sh keep <kind> <handle> <reason>`. A `kept` row is a D8 flag for the human.
5. Ports. A port row is never the first step: claim with `port-check.sh --claim` first, then register, launch, start, in that order. Full sequence, release and failure branches: `references/ports.md` (A.5.2).
6. Leases. `lane-lease` register is compare-and-append and writes `live` directly. Exit 3 means the lease is held: do not wait in a loop; report it (a lane maps to C2 `lane-unavailable`).
7. Look: `catalog.sh list --live [--subtask <st>]` prints the live rows as TSV. `catalog.sh audit` prints `MATCH` (row and reality agree), `GHOST` (row says live, resource gone) and `SQUATTER` (resource exists, no row) lines, checked with `kill -0`, `lsof` and `git worktree list`. Never `ps` or `pgrep`.
8. Exit codes: 0 ok. 2 usage or a rejected row: fix the arguments, never retry the same call. 3 lane-lease held: report. 4 lock timeout (script retries 1 s up to 60 s): report, do not append by hand.
9. Stop row, an unregistered resource found: register it (source names who found it), flag it to the lead, and do not kill or delete it by pattern. Cleanup acts only on catalog rows (D9); a SQUATTER is reported, not removed.

## Red flags
| Rationalization | What to do instead |
|---|---|
| "I'll register it after it starts, it is faster." | Register first (`planned`), start, then `start`. A started thing with no row is a SQUATTER and nothing can clean it. |
| "I'll write the cleanup command into the row." | Rows hold kind and handle only. The per-kind table inside `catalog.sh` owns every command (M26). |
| "A quick edit of `catalog.tsv` or `ports.tsv` fixes this row." | Only `catalog.sh` appends the catalog and only `port-check.sh --claim` appends the registry. A stale row is superseded by a later row. |
| "The port is taken, I'll keep adding 10." | One retry only: claim candidate + 10 before any bind; a second refusal stops the line and is reported (A.5.2, AM-3, OQ-2). |
| "The port hook did not ask, so it is free." | The PreToolUse hook `port-precheck.sh` is advisory and always exits 0. It does not replace the claim. |
| "It is an orphan, `pkill` it." | Register it, flag it, kill by catalog row (literal pid) at cleanup only. |
| "I'll pass `RUN_HOME=<path>` as an argument." | It is the environment variable. |

## Exit criteria
- [ ] Step 0 passed: `DELIVERY_ROOT` and `RUN_HOME` set, else `INPUT-ERROR` printed and stopped.
- [ ] Every resource started in this step has a `planned` row before the start and a `live` row after; every one stopped has `released`, `failed` or `kept` (with reason).
- [ ] Every example register call had exactly 7 arguments; `unit` is `-` or `u<N>`/`i<N>`.
- [ ] Every bound port was claimed (exit 0) before its `register port` row; a failed claim means no launch and a report.
- [ ] No command was written into a row; `RUN_HOME/catalog.tsv` and `tools/ports.tsv` were not edited by hand.
- [ ] Any unregistered resource found was registered and flagged, not killed (D9).

## Provenance
Provenance: pending pilot (<pilot-run-id>). Card 8 (design part-02 §2.2) and part-04 §5.6; INTERFACES 1.1.0 A.5, A.5.1, A.5.2 (amendment AM-1, agent-hq PR #9), re-checked against 1.3.0 (AM-3: owner OQ-2 one +10 retry; 17 kinds); cleanup facts C1, C6, C7 (live-only cleanup, orphan sweep); port-registry collision incident 2026-09-04 via `skills/port-claim`. Drafted 2026-10-26 (task 18).
