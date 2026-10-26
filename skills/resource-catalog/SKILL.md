---
name: resource-catalog
version: 0.1.1
description: Register, start, release, keep and audit every resource a delivery run creates, through catalog.sh. Use when before and after starting any worktree, branch, tag, process, pm2 app, port, bus, temp dir, container, lease, cron or background task in a run, when a port must be claimed first (port-check.sh --claim, then a port row), when a resource is found that no catalog row names, or when a lead reconciles with audit. One append-only TSV row per event; the script owns the cleanup commands.
---

## Trigger
Use when: a run is about to create, or has just created, a resource of any catalog kind (kinds and handle forms: `references/kinds-and-handles.md`); when a bound port is involved (`references/ports.md`); when `list --live` or `audit` is needed at resume, before a gate or at cleanup; or when a resource turns up that no row names.
Not for: deleting anything (that is `delivery-cleanup`, which acts on catalog rows only) and not for editing the catalog or the port registry by hand.

## Steps
Scripts: `~/projects/agent-hq/tools/delivery/catalog.sh` (the only appender; item 5) and `~/projects/agent-hq/tools/port-check.sh`. Examples below call `catalog.sh` as a bare name for brevity; the run-id in examples is `found-1234-20261102`.

0. Check inputs first. If `DELIVERY_ROOT` is unset, print `INPUT-ERROR DELIVERY_ROOT unset` and stop. If `RUN_HOME` is unset, print `INPUT-ERROR RUN_HOME unset` and stop. Pass `RUN_HOME` as an environment variable (the named exception to `NAME=value` arguments): an absolute path to an existing directory whose last segment is the run-id, matching `[a-z0-9-]+`; anything else is exit 2 from the script. On every call that registers a `worktree`, and on `audit`, also pass `WORKTREE_BASE` inline from the profile (`WORKTREE_BASE=<base> catalog.sh register worktree ...`); it must be absolute with no whitespace.
1. Register before you start. One call, 7 arguments after `register`: kind, handle, unit (or `-`), correlation_id, source, subtask (or `run`), owner_agent. It writes a `planned` row and prints the `row_id`. Field grammars (`catalog.sh`): correlation_id `^([A-Z][A-Z0-9]*-[0-9]+|PR-[0-9]+|run)$`, source `^[A-Za-z0-9._/:-]+$`, owner_agent `^[a-z0-9-]+$`.
   ```
   catalog.sh register tmpdir $RUN_HOME/tmp/st1 u07 FOUND-1234 delivery-run st1 impl-u07
   catalog.sh register pm2-app found-1234-20261102-st1-api - FOUND-1234 delivery-run st1 lead
   ```
   `unit` matches `^([ui][0-9]+|-)$`; use `-` for run-level rows, never empty. Handle grammar per kind: `references/kinds-and-handles.md` and INTERFACES A.5. The path kinds (`tmpdir`, `file`, `clone`, `bus`) and the path part of a `worktree` handle must be absolute, contain no `..`, and have a realpath strictly under `RUN_HOME` or `WORKTREE_BASE` (when it is set). The script rejects control characters, empty arguments, a handle that starts with `-`, `-0` or exponent forms in an int field, and any row over 400 bytes (A.8 A.5, AM-5 PR10-R2).
2. Start the resource, then mark it: `catalog.sh start <kind> <handle>` writes `live`. Do not start before the `planned` row exists (the pre-PR gate fails on any `planned` row left behind).
3. Release when you stop it: `catalog.sh release <kind> <handle>`; a `released` row supersedes the earlier ones (supersede key is kind plus handle, latest row wins). If the start failed, `catalog.sh fail <kind> <handle>`. For a `port`, the normal release is cleanup only: the `released` claim row first, then the catalog row (Release in `references/ports.md`); a launch that fails after the claim supersedes the claim at once with a `released` row of the same port and source (`port-claim` Step 4) and marks the row `fail` (`references/ports.md`).
4. Keep with a reason when a resource must outlive the run: `catalog.sh keep <kind> <handle> <reason>`. A `kept` row is a D8 flag for the human.
5. Ports. A port row is never the first step: claim with `port-check.sh --claim` first, then register, launch, start, in that order. Never pass `--force` in a run. Full sequence, release and failure branches: `references/ports.md` (A.5.2).
6. Take a lease by registering kind `lane-lease` (the same 7 arguments as step 1); the register is compare-and-append and writes `live` directly. On exit 3 the lease is held: do not wait in a loop; report it to the lead (C2 `lane-unavailable` covers only a refused port, part C).
7. Look. `catalog.sh list --live [--subtask <st>]` prints, for every kind-plus-handle pair whose latest row is `planned` or `live`, that latest row only, as TSV (`--subtask` filters on column 3; INTERFACES script table). Run `WORKTREE_BASE=<base> catalog.sh audit` (without `WORKTREE_BASE` it prints no SQUATTER line). It reads every kind-plus-handle pair whose latest row is `planned` or `live` and prints:
   - `MATCH<TAB><row_id>`: the resource is alive (`kill -0`, `lsof`, `git worktree list`, `git show-ref`, `test -e`, the bus pid, `pm2 jlist`); a `lane-lease` is always `MATCH`.
   - `GHOST<TAB><row_id>`: the latest row is `planned` or `live` and the resource is gone.
   - `SQUATTER<TAB>-<TAB>worktree:<path>`: only a git worktree under `WORKTREE_BASE` named `<run-id>-*` with no open row (repos taken from the catalog's `worktree` rows).
   Audit prints no line for `container`, `image`, `workspace`, `db`, `cron`, `bgtask`, or for `pm2-app` when `pm2` or `jq` is missing; check those by hand. Port squatters and CONFLICT come from `port-check.sh --audit`, not from `catalog.sh audit`. Never `ps` or `pgrep`.
8. Act on the `catalog.sh` exit code: on 0 continue; on 2 (usage or a rejected row) fix the arguments, never retry the same call; on 3 (lane-lease held) report; on 4 (lock timeout after 1 s retries up to 60 s) report, never append by hand; on 5 (`audit` only: `lsof` missing or failing for a `port` row, which `tools/delivery/catalog-audit.sh` names on stderr) the audit has no verdict for that row: treat it as neither `MATCH` nor `GHOST`, do not act on the missing line, and report the rows named on stderr to the lead (A.8 A.5, AM-5 PR10-M4).
9. When you find a resource no row names, register it (the source names who found it), then `catalog.sh start` it once verified alive (a `planned` row left behind fails the pre-PR gate and audits as GHOST), flag it to the lead, and do not kill or delete it by pattern. Cleanup acts only on catalog rows (D9); report a SQUATTER, never remove it.

## Red flags
| Rationalization | What to do instead |
|---|---|
| "I'll register it after it starts, it is faster." | Register first (`planned`), start, then `start`. A started thing with no row is invisible to cleanup, and audit names only an unregistered worktree, so nothing else surfaces it. |
| "I'll write the cleanup command into the row." | Rows hold kind and handle only. The per-kind table inside `catalog.sh` owns every command (M26: the design's catalog ruling, kind plus handle only, changelog row M26 and INTERFACES A.5). |
| "A quick edit of `catalog.tsv` or `ports.tsv` fixes this row." | Only `catalog.sh` appends the catalog and only `port-check.sh --claim` appends the registry. A stale row is superseded by a later row. |
| "The port is taken, I'll keep adding 10." | One retry only: claim candidate + 10 before any bind; a second refusal stops the line and is reported (A.5.2, AM-3, OQ-2). |
| "The claim was refused, `--force` gets it through." | Never in a run. A refused claim is the refusal: one +10 retry, then stop (`references/ports.md`). |
| "Audit printed no SQUATTER, so nothing is orphaned." | Audit's SQUATTER covers worktrees only, and needs `WORKTREE_BASE`. Run `port-check.sh --audit` for ports and check the silent kinds by hand. |
| "The port hook did not ask, so it is free." | The PreToolUse hook `port-precheck.sh` is advisory and always exits 0. It does not replace the claim. |
| "It is an orphan, `pkill` it." | Register it, flag it, kill by catalog row (literal pid) at cleanup only. |
| "I'll pass `RUN_HOME=<path>` as an argument." | It is the environment variable. |

## Exit criteria
- [ ] Step 0 passed: `DELIVERY_ROOT` and `RUN_HOME` set, else `INPUT-ERROR` printed and stopped.
- [ ] Every resource started in this step has a `planned` row before the start and a `live` row after; every one stopped has `released`, `failed` or `kept` (with reason).
- [ ] Every example register call had exactly 7 arguments; `unit` is `-` or `u<N>`/`i<N>`.
- [ ] Every bound port was claimed (exit 0) before its `register port` row, without `--force`; a failed claim means no launch and a report.
- [ ] No command was written into a row; `RUN_HOME/catalog.tsv` and `tools/ports.tsv` were not edited by hand.
- [ ] Any unregistered resource found was registered and flagged, not killed (D9).

## Provenance
Provenance: pending pilot (pilot-run-id assigned by the conductor at the first run). Friction: cleanup-agent facts C1, C6, C7 (ids from the design part-01 id table, Hermes `brain/cleanup-agent-facts-20261025`; not INTERFACES part C): C1 the owner standard of a clean-up agent after every work stream, within an approved never-touch scope; C6 the owner's words to clean up old worktrees and the orphaned processes the brain caused; C7 the measured part-2 clean-up pass under C6. The rules applied here (catalog rows only, processes ended by literal pid never by pattern, worktrees removed only after checks) come from the design: D9 and cards 8 and 9 (part-02 §2.2). Port-registry collision incident 2026-09-04: Hermes `learnings/port-collisions`, via `skills/port-claim`. Contract: card 8 (design part-02 §2.2) and part-04 §5.6; INTERFACES 1.1.0 A.5, A.5.1, A.5.2 (amendment AM-1, agent-hq PR #9), re-checked against 1.3.0 (AM-3: owner OQ-2 one +10 retry; 17 kinds) and 1.5.0 (AM-4 W2-3 `<base> + 20·k`, row 20 `list --live`; AM-5 PR10-M4 audit exit 5, PR10-R2 handle guards; item 33). Drafted 2026-10-26 (task 18).
