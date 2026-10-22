# hermes-agent-ops — owner controls, open claims and risks for the Hermes instance (current design)

**Status: DRAFT (T-462). Not ratified. T6 ratified with changes (all folded); plan-check PC-H3 pending.**
Companion of `hermes-agent.md` (core) and `hermes-agent-memory.md` (learnings). Section numbers (§11, §12, §14) are kept because other records cite them. "UNMEASURED" = UNVERIFIED. Every "should/must" is Proposed pending owner ratification (Global Rule 9) unless it quotes an owner ruling.

## 11. Owner controls
- **Start/stop:** the always-on gateway is the owner's own LaunchAgent `local.hq.hermes-up` (owner rulings R-ab and 2026-10-12, `hermes-agent.md` §16). Stop: `launchctl bootout gui/$(id -u)/local.hq.hermes-up`. CLI: `hermes-up chat -q ...` or `hermes-up` (never bare `hermes`). Steps: `plans/hermes-agent/evidence/h2c-owner-runbook.md`; gateway design `plans/hermes-agent/tasks/02b-gateway.md`.
- **Approve:** `/skills pending|diff|approve|reject` and `/memory pending|approve <id>|approve all` (the commands exist: `hermes_cli/write_approval_commands.py:49-50,71-72`, MEASURED @908e4a4). With `write_approval` false only staged background replace/remove edits of memory wait for approval (`hermes-agent-memory.md` §3); the owner runs `/memory approve all` when they choose (optional). The shell-hook consent is given once by running `seed-hook-allowlist` (runbook B2).
- **Inspect:** `HERMES_HOME/config.yaml` (look for any saved "always" approval), `SOUL.md`, `skills/`, `pending/`, `memories/`, `shell-hooks-allowlist.json`, `logs/` (`agent.log`, `errors.log`), the snapshot's `MANIFEST.tsv` sha against `origin/main`.
- **Rotate-and-verify (answers R-u):** stop Hermes; record `shasum -a 256` of `memories/*`, every file under `skills/` and `pending/`, `SOUL.md`, `config.yaml` minus auth lines, and `state.db`, plus the session count; swap the credential; re-hash (all identical); run `hermes chat -q "Search your past sessions for the marker HERMES-PROBE-1 and reply with the session id; then name the hq sha in your index."`. Pass = hashes unchanged, session count +1, marker found, sha matches the manifest. Fail = stop and report; do not move state. (Spec: `plans/hermes-agent/tasks/05-rotation-check.md`; with memory ON, a legitimately changed `memories/` hash needs the owner's note of what wrote it.)
- **Durability:** state outside git; no backup agent (owner veto 2026-10-13); see `hermes-agent-memory.md` §7.

## 12. Claims still UNMEASURED (each needs a measurement before it is relied on)
1. A credential swap leaves `state.db`, `memories/`, `skills/` untouched (rotation check above).
2. `state.db`, `cron/`, `pending/` live under a custom `HERMES_HOME` (inferred from defaults; `state.db` exists today in `h1-home`, runbook G15).
3. With a custom `HERMES_HOME`, Anthropic OAuth reads `HERMES_HOME/auth.json`, not `~/.hermes/auth.json`.
4. The Anthropic endpoint host(s), OAuth login hosts and the installer's download hosts (probe P9 observes hosts).
5. Approval behaviour in API, cron and other unattended modes beyond the documented `cron_mode`/`unattended_mode` defaults (source-read only, `02b` §c).
6. Disabling toolsets removes them from every surface (probes P2, P16).
7. The `pre_tool_call` matcher covers every file read/write tool name (probes P3-P14).
8. hq `CLAUDE.md` passes Hermes's context-file injection scan.
9. Hermes `worktree: true` / `delegation.worktree_isolation` semantics vs Rule 6 (not used).
10. No telemetry is sent; the update-check disable key.
11. Install footprint and any VM claim of a docker backend.
12. External memory providers are off unless configured (`memory.provider` stays unset).
13. Cost per typical question at the chosen model.
14. `auth.adopt_external_logins: false` fully prevents reading or refreshing the Claude Code credential store.
15. All memory/learnings probes in `hermes-agent-memory.md` §10.

## 14. Risks
- **R1 — Poisoned or wrong learning.** Hermes writes memory and skills without owner approval (ruling 2). A bad entry persists across sessions; the memory write path has only a pattern scan (`tools/memory_tool_store.py:28-31`, MEASURED). Mitigation proposed: SOUL.md bars secrets and ranks hq git above memory/skills (`hermes-agent-memory.md` §8); the skills ledger and `curator rollback` (`config_defaults.py:1482-1491`, MEASURED); the owner can inspect and revert. Memory replace/remove through the API door applies unstaged (`hermes-agent-memory.md` §3).
- **R2 — Secrets in the digest.** A secret committed to hq would be snapshotted and sent to the model. Mitigation: path exclusions plus a regex scan that aborts the build; `config/` and evidence excluded.
- **R3 — "Always" approvals persist** silently in `config.yaml`. Mitigation: never choose "always"; config.yaml is frozen (`chflags uchg`) by the runbook; inspect it.
- **R4 — `--yolo` / `approvals.mode: off`** disables checks. Mitigation: the launcher refuses those args and env (probe P12).
- **R5 — Gateway hooks run in-process** with the gateway's privileges. Mitigation: `HERMES_HOME/hooks/` stays empty and `hermes-up` gateway mode refuses to start otherwise (02b).
- **R6 — External memory providers** would add cloud egress. Mitigation: `memory.provider` unset.
- **R7 — Self-written skills run as instructions** in later sessions, now without owner review. Mitigation: guard scanner on (`skills.guard_agent_created`), SOUL.md precedence over memory and skills; background skill deletes are archived but foreground deletes are a hard `rmtree` (`tools/skill_manager_tool.py:580-593`, MEASURED).
- **R8 — Egress is policy, not enforcement** on the host: a misconfigured toolset could reach other hosts. Mitigation: toolsets off, lazy installs off, probe P9.
- **R9 — Cost.** Every on-demand read is billed; unmeasured.
- **R10 — Fail-open defaults.** Shell hooks fail open unless `fail_closed: true` (hook config sets it; spawn error then blocks, `agent/shell_hooks.py:380-381,413` MEASURED). Probe P5.
- **R11 — Credential collision.** Auto-detect would borrow Claude Code credentials. Mitigation: `auth.adopt_external_logins: false`.
- **R12 — Stale digest.** Answers from an old sha. Mitigation: sha check before use; Hermes cites the sha.
- **R13 — Only copy.** Learnings live only in Hermes state, which is not in git. No backup agent (owner veto 2026-10-13); durability per `hermes-agent-memory.md` §7.
- **R14 — Curator archival.** Accepted and mitigated by the owner's decision A (2026-10-13): the curator is off (`curator.enabled` false, `hermes-agent-memory.md` §4 and §11), so it archives no Hermes-written skill. The config line is applied by the owner via the runbook, not by an agent.
