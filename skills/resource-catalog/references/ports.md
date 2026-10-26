# Port rows (INTERFACES A.5.2, amendment AM-1)

Scope: every port a run binds: e2e lanes, dev servers, the sub-task bus, `pr-review`'s per-review bus. `catalog.sh` never calls `port-check.sh`; the caller runs them as separate commands, in this order. All paths below are `~/projects/agent-hq/tools/...`. Work through the `port-claim` skill rules.

## Order before launch
1. Candidate: take the port from the dispatch plan's port table. The "+10 rule" is only that table's plan-time formula `<base> + 10*k`, fixed before any check. It is never a collision fallback.
2. Check, then claim, with `project` = `<run-id>` and `source` = `<run-id>-<subtask>`:
   ```
   port-check.sh 3110
   port-check.sh --claim 3110 127.0.0.1 3000 web <JIRA-KEY>-1234-20261102 claimed <JIRA-KEY>-1234-20261102-st1 e2e-lane
   ```
   `--claim` takes 8 positional fields (`-` for an empty `container_port` or `note`) and re-runs the check first.
3. Register, 7 arguments after `register`:
   ```
   catalog.sh register port 3110 u07 <JIRA-KEY>-1234 delivery-run st1 impl-u07
   ```
   This writes the `planned` row.
4. Launch the thing that binds the port (never before step 2 returned 0).
5. Verify with `lsof -nP -iTCP:3110 -sTCP:LISTEN`, then mark it:
   ```
   catalog.sh start port 3110
   ```
   The row is now `live`.

## Failure branches by `port-check.sh` exit code
| Exit | Meaning | Action |
|---|---|---|
| 0 | free | continue to the next step |
| 1 | taken | refuse the launch; never auto-pick or add 10; report to the lead. A lane reports C2 reason `lane-unavailable` |
| 2 | registry and `lsof` disagree | same as 1, a hard stop and not a warning |
| 3 | usage error or unusable registry | stop-the-line; report a malformed row, never delete it |

If the launch fails after a claim: `catalog.sh fail port 3110` and supersede the claim with a `released` row (below).

## Release (cleanup only)
After the listener is stopped (confirm with `lsof`), release in this order: a `released` claim row with the same port and the same source, then the catalog row.
```
port-check.sh --claim 3110 127.0.0.1 3000 web <JIRA-KEY>-1234-20261102 released <JIRA-KEY>-1234-20261102-st1 e2e-lane
catalog.sh release port 3110
```
The registry is append-only: a stale row is superseded by a `released` row, never edited, and `kill` by port is never the release. The release itself is run by `delivery-cleanup`.

## The hook
The PreToolUse(Bash) hook `tools/hooks/port-precheck.sh` checks launches made outside this path against `tools/app-ports.tsv` and `lsof` and asks the human on a live listener. It is advisory, always exits 0, and does not substitute for the claim.
