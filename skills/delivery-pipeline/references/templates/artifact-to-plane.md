# Template: artifact-to-plane table (design 5.11, M18; INTERFACES A.1, A.6, D6)

The single reference for where each artifact of the delivery workflow lives. A skill that writes a file looks its plane up here; it does not re-derive a path. The table in Part A is the design 5.11 table (7 rows) with the A.6 planes applied, plus one RUN row for the artifacts A.6 moves off the repo plane (the departures are listed under "Errata applied"); Part B adds the AM-1 rows; Part C gives the path rules every row depends on.

- **Writer / Reader:** writer the conductor (`delivery-pipeline`) when it creates `RUN_HOME` and `plans_dir` at stage 1, and the owner of this reference; readers: every skill of the family and the human. The per-artifact writer and reader columns are in INTERFACES D6; if this file and D6 differ, D6 wins.
- **Planes:** **repo** (committed; plan-plane files go first through sub-task `st0`), **RUN** = `RUN_HOME` = `$DELIVERY_ROOT/<run-id>`, **ROOT** = `$DELIVERY_ROOT`, **TMP** = `$TMPDIR` (volatile), **store** = the context store.
- **Dates:** `YYYY-MM-DD`.

## Part A. The table (design 5.11)

| Artifact | Plane | Durable? |
|---|---|---|
| `architecture.md`, `dispatch-plan.md`, `test-plan.md`, `release-plan.md` (v0) | repo `plans/<epic>/` (or the context store's project folder where the repo's `CLAUDE.md` names one) | yes, committed |
| `contracts/`, `.tasks/`, `.decisions/`, `CLAUDE.md` | repo, agent-facing | yes, committed |
| `retro.md`, `execution-log.md`, `release-plan.md` (v1) | RUN (`RUN_HOME/retro.md`, `RUN_HOME/execution-log.md`, `RUN_HOME/release-plan.md`) | survives reboot; RUN-only in this contract version (A.6, row R4-J19); committing to `plans/<epic>/` is a human step after CYCLE DONE |
| `state.md`, `substate.md`, slot rows, `catalog.tsv`, review and desk records, capture queue | `RUN_HOME` (`$DELIVERY_ROOT/<run-id>`, not `/tmp`) | survives reboot; archived at CYCLE DONE |
| bus `data_dir` and `bus.endpoint` | `RUN_HOME/<subtask>/` (`bus.endpoint`) and `RUN_HOME/<subtask>/bus/` (`data_dir`) | survives reboot; pm2 app re-verified at resume |
| pm2 apps, scratch | `$TMPDIR` | volatile; always re-verified at resume |
| session dump | context store `projects/<name>/sessions/` | curator promotes |
| learnings | Hermes port in `agent-hq` (D19) | Hermes-owned |

**Errata applied (A.6, D5, errata E17).**
- *Bus path:* the design row says `RUN_HOME/<subtask>/bus/` for both; the card 6 path governs: `bus.endpoint` is `RUN_HOME/<subtask>/bus.endpoint` (a file) and only the `data_dir` is the `bus/` directory.
- *Retro and `release-plan.md` v1:* the design row lists "retro" with the repo plane; it is removed from that row and given the RUN row above, because in this contract version `retro.md`, `execution-log.md` and `release-plan.md` v1 are RUN-only. Committing them to `plans/<epic>/` is a human step after CYCLE DONE. `release-plan.md` v0 (written by `delivery-architecture`) is repo `plans/<epic>/`.
- *Plan-plane files not in the design row:* `brief.md`, `facts.md`, `drafts/` (with `drafts/index.md`), `review-architecture.md`, `h1-packet.md`, `subtasks/<subtask>/substate.seed.md` and `subtasks/<subtask>/waves/` are repo `plans/<epic>/` (INTERFACES D6).

## Part B. AM-1 rows (INTERFACES 1.5.0)

| Artifact | Plane and path | Durable? |
|---|---|---|
| `security-audit/run-<N>/` (`findings.json`, `coverage-ledger.json`, `run-metadata.json`, `agents/`); full audit mode only | RUN `<subtask>/security-audit/run-<N>/`; `N` = 1 + the count of existing `run-*` directories (A.5.3). Never the skill's default `~` output directory | survives reboot; archived with the run |
| `skills/security-audit/` plus `PROVENANCE.md` | agent-hq repo, vendored unmodified (installed through the desk `INSTALL`) | yes, committed; read only for this family |
| `tools/ports.tsv`, `tools/app-ports.tsv`, `tools/hooks/port-precheck.sh` | agent-hq repo; registries filled at the move for the work machine | yes; `tools/port-check.sh --claim` appends only |

Guidance mode (`state.md` `security_audit: guidance`) writes no file; the RUN row exists only under `full`.

**AM-5 rows (INTERFACES 1.5.0 A.1, A.8, C8, D5).**

| Artifact | Plane and path | Writer |
|---|---|---|
| in-run `pr-review` bus: `bus.endpoint` and `data_dir` `bus/` | RUN `review/<subtask>/<review-id>/`; one fresh session `pr-review-<uuid8>` per review (the M12 namespacing exception for review buses, E42) | `pr-review` Step 1 |
| `pm/inbox/<seq>-<yyyymmddThhmmssZ>-verdict.md` (inbox type `verdict`) | RUN `pm/inbox/` | `post-merge-verify` verdict agent (C5.1, C8) |
| `capture/read-back.md` (line 1 `READ-BACK: pass` or `READ-BACK: <n> differences`) | RUN `capture/` | read-back agent (C8, 29-24) |
| `launcher/disallowed-tools.txt` (one tool name per line; absent or empty is `INPUT-ERROR launcher.disallowed_tools missing`) | ROOT `launcher/`, written at the move | the move operator (A.8, 29-21) |
| `homes/<session>/pid`, `homes/<session>/prompt` (0600) | ROOT `homes/<session>/` | the launch subshell (A.8, 29-39) |

## Part C. Path rules every row depends on

| Rule | Statement | Source |
|---|---|---|
| `DELIVERY_ROOT` | env var, absolute, `^/[^[:space:]]+$`, no default, created with `umask 077`. Unset: Step 0 prints `INPUT-ERROR DELIVERY_ROOT unset` and stops | A.1, D1 |
| `RUN_HOME` | `$DELIVERY_ROOT/<run-id>`; durable run state, never `/tmp` or `$TMPDIR` | A.1 |
| `plans_dir` | the primary repo's `plans/<epic>/`; for a provisional run-id `plans/<run-id>/`, not renamed when the key arrives | A.1, A.2 |
| Multi-repo epic | the primary repo (`state.md` `primary_repo`, from the stage 1 `PRIMARY_REPO` input; restated in `architecture.md` section 3) governs; other profiles linked from it (`linked_profiles[]`) | A.1, A.2.2 |
| Worktrees | `worktree_base` (profile key) under `$DELIVERY_ROOT`; sub-task `<worktree_base>/<run-id>-<subtask>`, unit `<worktree_base>/<run-id>-<subtask>-<unit>` | A.1, A.6 |
| Namespacing | every pm2 app, bus `data_dir`, temp dir and worktree name carries `<run-id>-<subtask>`; exception: an in-run review bus lives under `RUN_HOME/review/<subtask>/<review-id>/` with session `pr-review-<uuid8>` (E42) | A.1, D4, D5 |
| Atomic writes | temp file in the same directory, then `mv`; a file written by several agents of one kind is `<agent-id>-<purpose>-<n>.md` | A.1 |
| Desk mailbox | `RUN_HOME/desk/` is the desk mailbox; the desk inbox is `$DELIVERY_ROOT/desk-inbox` (desk-owned) | A.1, D6 |

## Part D. Where each run-file lives (quick index; full writer column in A.6 and D6)

| Path | Plane | Writer |
|---|---|---|
| `RUN_HOME/state.md` | RUN | conductor |
| `RUN_HOME/gates/<gate-file>` (`<gate>.<run-id>.ok`, incl. `grant.*`, `H-destructive.*`, `RESUME.*`) | RUN | desk only |
| `RUN_HOME/<subtask>/substate.md`, `substate.lock/`, `substate.seed.md` (copy) | RUN | lead |
| `RUN_HOME/<subtask>/slots/<agent-id>.row` (`.stale`, `.freed`) | RUN | lead |
| `RUN_HOME/<subtask>/status/`, `shepherd/ticks.md`, `lanes/`, `gate-runs/<sha>.md`, `dispatch/<invocation>.jsonl`, `inbox/`, `outbox/`, `escalations/` | RUN | per A.3, A.6, part C |
| `RUN_HOME/catalog.tsv` (one per run; rows carry `subtask`) | RUN | `catalog.sh` only |
| `RUN_HOME/review/<subtask>/` (`record-<head>.md`, `fix-*`, `verify-*`, `checklist-<subtask>.md`, `pr-body.md`) | RUN | `pre-pr-gate`, `pr-review`, seats |
| `RUN_HOME/bodies/`, `RUN_HOME/capture/`, `RUN_HOME/desk/<id>.req`, `<id>.out` | RUN | body writers; capture agent; requester and desk |
| `RUN_HOME/merge-<sha>.md`, `cleanup-<run-id>-<subtask\|final>.md`, `tickets.tsv`, `ticket-events.log`, `ticket-events.cursor`, `plan-check.md`, `ci/<pr>.md`, `postmerge-<sha>.md`, `release-<sha>.md`, `release-plan.md` (v1), `retro.md`, `execution-log.md`, `pm/new-units.md`, `review-tailor-<slug>.md` | RUN | per A.6 |
| `$DELIVERY_ROOT/desk-inbox/`, `desk-log/<run-id>.jsonl`, `machine/<session>.row`, `homes/<agent>`, `pw-browsers` | ROOT | desk; each session; launcher |

Planes by durability: RUN and ROOT survive reboot; TMP never does, so every TMP item is re-verified at resume (`pm2 jlist`, `kill -0`).

## Part E. Checks before a skill writes a new artifact

- [ ] the artifact is a row in Part A, B or D, or in INTERFACES A.6; if not, stop and report to the conductor (no invented path).
- [ ] the path starts at `RUN_HOME`, `plans_dir`, the repo root or `$DELIVERY_ROOT`; never `/tmp`, never `$TMPDIR` for durable state.
- [ ] every sha in the name or body is 40-hex.
- [ ] the write is atomic when the file has more than one reader.
