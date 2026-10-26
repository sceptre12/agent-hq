# 0053. permission-tiers: executor profiles in bypass, research desks in auto (campaign close-out)

- **Status:** Accepted (2026-10-21)
- **Date:** 2026-10-21
- **Context of:** permission-tiers (project; `projects/permission-tiers.md`)
- **Numbering note:** highest ADR file on main was 0051; 0052 is held by `decisions/0052-cloudflare-remote-mcp-server.md` on branch `wt/cloudflare-mcp` (not on main), so this ADR is 0053.
- **Sources:** `architecture/permission-tiers.md`, `architecture/permission-tiers-02.md`, `plans/permission-tiers.md`, `plans/permission-tiers/evidence/`. CITED = docs; MEASURED = date + evidence file.

## Context

The owner's ask, R-8 (2026-10-21, verbatim): "What was this trying to accomplish? because the goal is to have two seperate profiles where the profile with the bypass mode does all the work without needing to ping me everytime for the ability to do work based on a plan. The profile with auto mode is allowed to search the internet but it pings me on things it things are dangerous but the bypass persmission agent is able to talk to the auto mode agent and they can go back and forth with each other... Thats it" [sic].

## Decision (as built)

1. **Executor tier** (`config/tiers/executor.json`): `bypassPermissions` + `permissions.deny` (web tools, new-dependency installs, download-and-run, force-push, plugin/MCP adds, self-widening edits; contract in -02 §1) + OS sandbox: `enabled`, `allowUnsandboxedCommands: false`, `network.strictAllowlist: true`, `allowedDomains` = localhost, 127.0.0.1, api.anthropic.com, github.com, `allowLocalBinding: true`, `filesystem.allowWrite` = `~/projects`, `~/.npm`, `~/Library/pnpm/store/v11`, `denyWrite` = `~/projects/agent-hq/config/tiers`, `~/claude-profiles/_trust`. Deny rules and the sandbox bind in bypass (MEASURED P0-b/c, 2.1.299; P5 2026-10-21 probes, 2.1.306).
2. **Desk tier** (`config/tiers/desk.json`): `auto` mode, 22 deny entries (force-push forms and config/profile-file edits), no sandbox block. The only tier that fetches the web, installs and scans.
3. **Cross-session messaging:** native `SendMessage`; both tiers launch with `--settings '{"crossSessionInbound":"accept"}'`. Profiles share one registry: each profile's `config/sessions` is a symlink to `~/claude-profiles/_sessions`, which is itself a symlink to `~/.claude/sessions` (re-pointed 2026-10-20 so tier profiles and the owner's ordinary sessions share one registry; MEASURED: `ls -la` 2026-10-21) (`plans/permission-tiers/p5-runbook.md` step 0.3). Grammar `RESEARCH/SUMMARY`, `INSTALL/INSTALLED/REJECTED`, `STATUS/BUSY`: -02 §2.
4. **Desk procedure** (-02 §3, a procedure, not a tool): step 0 ledger check; 1 fetch with lifecycle scripts disabled in a scratch dir; 2 advisory (`osv-scanner`, `pip-audit`); 3 lifecycle-script review (npm/pnpm); 4 content read by the desk's own `Read` (no nested CLI, R-8); 5 real install in the executor's path, ledger rows, reply. A failed or impossible step is REJECTED, never skipped.
5. **Ledger:** `~/claude-profiles/_trust/ledger.jsonl`, append-only, machine-local, outside hq; one BASELINE row plus DEP/TOOL/PLUGIN rows (-02 §4). It is the scanned-once record.
6. **Approved accounts:** a line in `tools/claude-profile/templates/executor-CLAUDE.md` (section "Approved GitHub accounts (R-7, R-9)"), obeyed by the executor and edited by the owner in the executor's chat (R-9).
7. **Bare-install denies dropped (R-10):** `Bash(npm install *)`, `Bash(npm i *)`, `Bash(pnpm install *)` removed from the executor list; `add`/`dlx` denies stay; the sandbox allowlist is the line against new downloads.

## Owner rulings

- **R-1 (2026-10-12, OQ-1):** "1 makes the most sense. And yes there may be a set grup of Researchers that just sit and take in request for researching something specific and distill the information over to the agent based on what they are looking for. More importantly the research agent would be a specialized role anyways so this becomes more efficent" (generic `desk` plus `desk-<domain>`).
- **R-2 (2026-10-13, OQ-T):** "We'll do similar how to i need to already provide the token on profile creation I'll continue doing that".
- **R-3 (2026-10-14, OQ-R):** "Lets move forward with 1 for QQ-R" (ratified as written; D8 unchanged).
- **R-4 (2026-10-14, OQ-3):** "QQ-3 yes" (desk installs `osv-scanner` and `pip-audit` via Homebrew).
- **R-5 (2026-10-14):** "main repair" per `plans/permission-tiers.md` line 10; "Then this session should revert its commit from main so that other sessions can move forward while this session focuses on fixing its own things" (transcript a224ebab line 1518).
- **R-6 (2026-10-15):** "Yes lets purefully focus on the initial ask. And we have to stop expanding scope that continually causes drifts waste time and money and ends up causing more issues."
- **R-7 (2026-10-17):** "an EWxecutor should be able to push to github and read only from approved github accounts and i can modify that approval list in the executors chat" [sic].
- **R-8 (2026-10-21):** quoted in Context; consequence: desk step 4 is its own `Read`, no nested CLI or credentials.
- **R-9 (2026-10-21):** "We dont need to over enforce that part and I want us to stay within scope" (closes OQ-5: template line, no hook).
- **R-10 (2026-10-21):** "qq-6 1" (closes OQ-6: option 1, patterns dropped).

## Amendments to the ratified design

- **D7 amended** (-02 §4, panel F11b): the ledger was audit-only; the desk now reads it at step 0 and a `DEP` row with the same `manager`, exact `name@version` and verdict `INSTALLED` skips steps 1-4 (step 5 still runs). P5 4.3: ledger hit answered in about 9 s (`p5-run-2026-10-21.md`).
- **D8 unchanged:** no blocking hooks. P0-a showed a PreToolUse deny and an exit-2 hook both stop a Bash call in bypass (MEASURED 2.1.299); the owner declined the hook layer (R-3) and R-9 confirms.
- **Docs sentence falsified:** "plain `ssh`, `scp`, and `rsync` over SSH fail" (CITED docs). MEASURED 2026-10-21 (P5 probes 3 and C2, 2.1.306): SSH to an allowlisted host works; to a non-allowlisted host the proxy refuses ("403 host is not on the allow list"). The allowlist binds for SSH; the "executor repos must use HTTPS remotes" consequence was removed (-02 §1).

## Known no-ops and leftovers (named, NOT fixed)

- `Write(path)` deny entries are no-op duplicates of their `Edit(path)` twins in both tier fragments (the harness warns "not matched by file permission checks - only Edit(path) rules are", `p5-run-2026-10-21.md` §3).
- `Bash(bun install *)` is still in the executor deny list; by the same pattern shape as the measured `pnpm install *` case it would match bare `bun install` (UNMEASURED for bun).
- `rm -rf` is not denied in the executor (no `rm` rule among E1-E13; `p5-run-2026-10-21.md` §2 records "rm -rf not denied" from a compaction summary, raw output lost).
- Latent: `cprof-tiers.zsh` deep-merges `sandbox.filesystem.denyWrite` as a plain array replace, so an overlay that sets `denyWrite` would overwrite the base entries; no current overlay sets it (`plans/permission-tiers.md` anomaly log).
- E9 known gap: force-push global-option forms other than `-C` (`--git-dir`, `--work-tree`, `-c`) are not patterned; backstop is remote branch protection (-02 §1).

## Evidence pointers

- P0 facts (P0-a/b/c/e/f/g/g2, 2.1.299): `architecture/permission-tiers-02.md` §5; the raw `p0*/P0*-RESULT.md` files were lost with the session scratchpad in the 2026-10-21 machine crash (`p5-run-2026-10-21.md` §5).
- P5 pre-check: `plans/permission-tiers/evidence/p5-precheck-2026-10-17.md` (Q1/Q2 measured; Q3/Q4 NOT MEASURED, classifier block).
- P5 run: `plans/permission-tiers/evidence/p5-run-2026-10-21.md` (4.4 NOT RUN; 4.1-4.3, 4.5 PASS).
- Panel consultation (Rung 2, simulated panel): `plans/permission-tiers/evidence/panel-consultation-2026-10-16.md`.

## Descoped

The first-download scan tool (~1,100 lines, PR #52) was descoped under R-6 after 4 panels, 3 fix passes and a Fable T1/T2 verdict REDESIGN; PR closed unmerged, branch `wt/permission-tiers-p3` kept. The scan is the desk procedure above.

## Consequences

- Planned work in executor profiles runs unattended; installs and web research route through a desk. Existing profiles are unchanged.
- Accepted: the desk is a classifier-guarded session following a checklist, not a verified tool (-02 §3 residual); the hard line is the executor deny list plus sandbox.
- Owner-run, not part of this change: `cprof rm p0tiers`; `rm -rf ~/projects/p5-scratch`.
