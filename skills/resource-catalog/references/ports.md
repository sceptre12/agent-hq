# Port rows (INTERFACES A.5.2, amendment AM-1)

Scope: every port a run binds: e2e lanes, dev servers, the sub-task bus, `pr-review`'s per-review bus. `catalog.sh` never calls `port-check.sh`; the caller runs them as separate commands, in this order. All paths below are `~/projects/agent-hq/tools/...`. Work through the `port-claim` skill rules. Examples use run-id `found-1234-20261102` and sub-task `st1`.

## Order before launch
1. Candidate: take the port from the dispatch plan's port table. That table fixes every candidate at plan time, before any check, by `<base> + 20·k` (`st<N>` bus `k = 2N`, review bus `k = 2N + 1`, lane binds by consecutive bind index; fixed app ports keep their app port), so the one retry at candidate + 10 after a refusal lands on an odd ten no candidate uses (INTERFACES 1.10.0 A.5.2, AM-4 W2-3; the one retry is AM-3, owner OQ-2; below).
2. Check, then claim, with `project` = `<run-id>` and `source` = `<run-id>-<subtask>`:
   ```
   port-check.sh 3110
   port-check.sh --claim 3110 127.0.0.1 3000 web found-1234-20261102 claimed found-1234-20261102-st1 e2e-lane
   ```
   `--claim` takes 8 positional fields (`-` for an empty `container_port` or `note`) and re-runs the check first.
3. Register, 7 arguments after `register`:
   ```
   catalog.sh register port 3110 u07 FOUND-1234 delivery-run st1 impl-u07
   ```
   This writes the `planned` row.
4. Launch the thing that binds the port (never before step 2 returned 0). A bus server is started with `PORT_RANGE_START=<port> PORT_RANGE_END=<port>` (the claimed port), and its `$DATA_DIR/port` must equal the claim (A.5.2).
5. Verify with `lsof -nP -iTCP:3110 -sTCP:LISTEN`, then mark it:
   ```
   catalog.sh start port 3110
   ```
   The row is now `live`.

## Failure branches by `port-check.sh` exit code
| Exit | Meaning | Action |
|---|---|---|
| 0 | free | continue to the next step |
| 1 | taken | refuse the launch; never auto-pick. Make exactly one retry at candidate + 10: check and `--claim` it (steps 2-5) before any bind. A second refusal stops the line; report to the lead. A lane reports C2 reason `lane-unavailable` |
| 2 | registry and `lsof` disagree | same as 1 (the one claimed retry, then stop), a hard stop for the candidate and not a warning |
| 3 | usage error or refused field; or unusable registry | usage or field error: fix the invocation and rerun. Registry unusable (missing, empty, unreadable, malformed row): stop the line and report (A.5.2); never delete the row |

If the launch fails after a claim, release the claim at once (not at cleanup) with a `released` row of the same port and source (`port-claim` Step 4), then mark the catalog row:
```
port-check.sh --claim 3110 127.0.0.1 3000 web found-1234-20261102 released found-1234-20261102-st1 e2e-lane
catalog.sh fail port 3110
```

## `--force` is never used in a run
`port-check.sh --claim ... --force` appends over a conflict. In a delivery run, never pass it: a refused claim (exit 1 or 2) is the refusal, answered only by the one +10 retry and then a stop and report. Per `port-check.sh`, `--force` overrides exit 1 or 2 only, never exit 3, and prefixes the note with `forced`. A self-release (a `released` row for a port whose every active registry row has the same `project`, the run-id) needs no `--force`; if a release is refused, report it, do not force it.

## Release (cleanup only)
The normal path, after a successful launch. After the listener is stopped (confirm with `lsof`), release in this order: a `released` claim row with the same port and the same source, then the catalog row.
```
port-check.sh --claim 3110 127.0.0.1 3000 web found-1234-20261102 released found-1234-20261102-st1 e2e-lane
catalog.sh release port 3110
```
The registry is append-only: a stale row is superseded by a `released` row, never edited, and `kill` by port is never the release. The release itself is run by `delivery-cleanup`.

## The hook
The PreToolUse(Bash) hook `tools/hooks/port-precheck.sh` checks launches made outside this path against `tools/app-ports.tsv` and `lsof` and asks the human on a live listener. It is advisory, always exits 0, and does not substitute for the claim.
