# feature-change: team mode (`UNIT_MODE=team`)

One unit inside a delivery run. The lead (conductor, `delivery-run`) already fixed what solo Steps 0, 1, 8, 9 and 10 decide. `solo` (the default) is unchanged. Contracts: INTERFACES D2.3, C2, C3, C4, D5, A.1, A.5, A.7.

## Input check (Step 0)
`UNIT_MODE` is `team` or `solo`; unset means `solo`. Any other value: print `INPUT-ERROR UNIT_MODE enum` and stop (D1). In `team` the brief also supplies `RUN_HOME`, `SUBTASK`, the unit id (`^u[0-9]+$`), `AGENT_ID`, the run id and the `.tasks/<unit>-<slug>.md` path. A missing one: `INPUT-ERROR <field> missing` per field, then stop. If `RUN_HOME` is unset, stop; never guess a bus or a path.

## Per-step table
| Solo step | Team mode |
|---|---|
| 0 Repo policy lookup | Replaced: `GATES` = `gates.command` from the repo profile (A.7); `ROUTE` is moot. Arrival duty still runs. |
| 1 Ticket | team: skip ticket creation; say "ticket owned by the conductor". Read the key for `SLUG` from `RUN_HOME/tickets.tsv` (latest row per slug governs; `-` = absent). No Jira or tracker call. |
| 2 Worktree | Branch is `<JIRA-KEY>-<slug>` (key matches `^[A-Z][A-Z0-9]+-[0-9]+$`), created only after the key is read back. Key absent: finish with `ESCALATE`, reason `spec-gap`, no worktree. Register first, see below. |
| 3-4 Implement, tests | Unchanged. |
| 5 Repo gates | Run the affected checks locally while working. Final record: see Gate runner. |
| 6 Distinct verifier | Unchanged (never the implementer). |
| 7 Review rung | The rung is the unit table's `review path`; `pre-pr-gate` owns the PR-level `pr-review`. |
| 8 Integrate | team: skip integration; the Integrator persona is the single writer of the sub-task branch. No push, no merge, no PR. |
| 9 Cleanup | team: skip cleanup; `delivery-cleanup` removes the worktree. Never run `git worktree remove`. |
| 10 Record | team: skip the ledger row and the ticket update; the lead owns the record (`ticket-clerk` runs only in the conductor session). |
| 11 Scope | Unchanged. |

## Catalog registration (before `git worktree add`)
`WORKTREE_BASE=<base from the profile> catalog.sh register worktree <handle> <unit> <correlation_id> <source> <subtask> <owner_agent>`, then `git worktree add`, then `catalog.sh start` for the handle. `WORKTREE_BASE` is passed inline on that command, the handle sits under it. Do the same for the branch row (kind `branch`). Exit 2, 3 or 4 from `catalog.sh`: stop the unit, no worktree add, report the code.

## NEXT line (C3)
After each step of the unit's §9 list, overwrite the single line in your own `RUN_HOME/<subtask>/status/<agent-id>.md`: `NEXT: u<unit>.<n> <text>`, matching `^NEXT: (u[0-9]+)\.([0-9]+) .+$`; `<n>` is the step number, `0` before the first. Write only your own file, never another agent's.

## Gate runner (A.7)
At unit end request affected lint+test+typecheck from the gate runner once per push or batch. The gate runner, a separate mechanical agent, writes `GATE-PASS <sha> <cmds>` to `RUN_HOME/<subtask>/gate-runs/<sha>.md`. This skill only reads `gate-runs/<head>.md` and cites it; it never writes `GATE-PASS` itself. Commits outside a desk push run the repo hooks; never set `HUSKY=0` and never pass `--no-verify`.

## UNIT-VERDICT (C2, C4)
Post a bare JSON object (no text prefix), exactly four keys, on topic `<run-id>-<subtask>-rendezvous` with `session_id = <run-id>-<subtask>`:
`{"unit":"<id>","verdict":"PASS|ROLLED|ESCALATE","head":"<sha>","reason":"<code>"}`
- Bus coordinates come from `RUN_HOME/<subtask>/bus.endpoint` (D5), never guessed.
- `head` = `git rev-parse HEAD` in the unit worktree at posting.
- `PASS` only after a distinct verifier reported every AC MET and the gate-runs file for `head` exists; reason `none`.
- Else `ROLLED` or `ESCALATE` with a reason from: `decision-gate`, `spec-gap`, `contract-gap`, `tier-exhausted`, `budget`, `env-bug`, `merge-conflict`, `human-step`, `gherkin-checkpoint`.
- Bus unreachable: write the exact same record to `RUN_HOME/<subtask>/status/<agent-id>.verdict` and stop (C4).

## Port guard
This skill binds no port; any dev server a unit starts is claimed per A.5.2 through `port-claim` first. `security-audit` is not used here (the security seat belongs to the review step).
