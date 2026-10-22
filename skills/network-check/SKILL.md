---
name: network-check
description: >
  Verifies outbound internet connectivity using DNS-free IP targets (1.1.1.1, 8.8.8.8,
  8.8.4.4) before a network-dependent operation runs, and clarifies that a "network
  unavailable" skip is a healthy outcome, not an error. Use when writing or hardening a
  script/background job that makes outbound calls, or when diagnosing a silent
  scheduled-job no-op.
---

## Trigger

Use when authoring or reviewing a script/scheduled job that makes outbound calls (embed the
guard pattern), or when diagnosing why a scheduled job silently did nothing. A `[SKIPPED]
network unavailable` log line is the expected, healthy behavior of a network-guarded job
when connectivity is down — it is not a bug to chase.

## Steps

1. Run the companion script: `~/.claude/skills/network-check/scripts/check-network.sh`
   (installed path; source of truth is `~/projects/agent-hq/skills/network-check/scripts/check-network.sh`).
   Add `-v` for verbose attempt logging to stderr.
2. Read the exit code: `0` = network reachable, `1` = not reachable. Do not parse stdout —
   the script is silent by default; only the exit code and (with `-v`) stderr are contracts.
3. If reachable, proceed with the outbound call as normal.
4. If not reachable:
   - **In a script context:** log `$(date '+%Y-%m-%d %H:%M:%S') [SKIPPED] network
     unavailable` and exit **0** — see the guard pattern below. A skip is not the same
     failure class as an error; downstream health checks (e.g. an "app-status"-style
     monitor) should treat it as healthy.
   - **Running interactively (a skill, not a script):** do not attempt the call. Tell the
     user the network is unavailable and suggest retrying, rather than guessing or
     retrying silently.

### Bash guard pattern (for scripts)

```bash
NETWORK_CHECK="${HOME}/.claude/skills/network-check/scripts/check-network.sh"
if [[ -x "$NETWORK_CHECK" ]] && ! "$NETWORK_CHECK"; then
  echo "$(date '+%Y-%m-%d %H:%M:%S') [SKIPPED] network unavailable" >> "${LOGFILE:-/dev/stderr}"
  exit 0
fi
```

**Why exit 0 on skip:** a scheduler tracking last-exit-status flips a job to "unhealthy" on
any non-zero exit, even when the skip was intentional. Exiting 0 keeps the job's own health
signal green while the skip is still visible in the log line for a human or monitor to see.

### Targets used (DNS-free, so DNS failures never produce a false negative)

| Target | Purpose |
|---|---|
| `1.1.1.1` | Cloudflare — primary |
| `8.8.8.8` | Google DNS — secondary |
| `8.8.4.4` | Google DNS — fallback |

## Red flags

| Rationalization | What to do instead |
|---|---|
| "The call failed, must be a bug in my code." | Run the network check first — an unreachable network produces the same-looking failure as a real bug; rule out connectivity before debugging logic. |
| "A non-zero exit from a guarded job means it's broken." | Check the log line first — `[SKIPPED] network unavailable` with exit 0 is the designed healthy path, not a failure. |
| "I'll just retry the outbound call a few times and hope it comes back." | Check reachability explicitly first (exit code, not vibes) — blind retries waste time and can trip rate limits when the real problem is local connectivity. |
| "Ping is simpler, I'll just ping a hostname." | Use the DNS-free IP targets this script already checks — a hostname ping conflates DNS failure with network failure, which is exactly the false negative this skill exists to avoid. |

## Exit criteria

- [ ] The script's exit code was read (0 or 1) before deciding whether to proceed.
- [ ] On skip (exit 1) in a script context, the log line was written and the script exited 0.
- [ ] On skip (exit 1) interactively, the user was told and no silent retry was attempted.

## Provenance
Provenance: Hermes skill `learnings/skill-sharing` (was learnings/skill-sharing.md) (2026-07-04 entry, "Skills have no standardized
export path" — the same porting pipeline this skill entered hq through).
Lineage: X-context-docs skills/network-check@87ed5a6

### Refit notes (declared changes vs. source)

- **Companion script authored, not ported.** The source `SKILL.md` referenced
  `~/projects/network-check/check-network.sh`, which does not exist anywhere in the
  X-context-docs transfer or on this machine. `scripts/check-network.sh` in this skill
  directory is new, original, minimal POSIX `sh` — DNS-free IP targets, `nc` primary /
  `curl` fallback per target, `-v` verbose flag, same 0/1 exit-code contract as the
  (non-existent) source script. Placed inside the skill directory (not
  `~/projects/network-check/`) so the ADR 0009 symlink install carries the script with it;
  the skill body references the installed path
  (`~/.claude/skills/network-check/scripts/check-network.sh`).
- **Dropped: the `## Integration` section's employer consumer list** — the source named
  two employer-specific background-job apps and a half-dozen employer-specific skills as
  consumers of this script/pattern. None of these exist on this machine — every one of
  them was independently SKIPped at Gate 0 as work-machine- or company-tool-coupled (full
  list and rationale: `plans/dev-workspace-base-skills.md` triage table). Replaced with a
  generic "scheduled job" framing (cron/launchd/CronCreate) instead of re-naming
  machine-specific consumers that don't exist here.
- **Dropped: `app-status` cross-reference** — source noted its own app-status monitor
  treats `[SKIPPED]` as healthy; that monitor was SKIPped at Gate 0 (work-machine-specific).
  Reworded as a generic "downstream health checks" note so the guidance survives without
  naming a tool absent here.
- **Restructured to the authoring standard** — added `## Trigger`, `## Red flags`, `##
  Exit criteria`, `## Provenance` (none existed in source); folded the source's "## The
  Script" / "## When to Use" / "## Skill Note Pattern" prose into numbered `## Steps`
  without changing the guard pattern's actual bash (kept verbatim — the shell logic itself
  needed no de-work-ification, only the surrounding prose did).
- **Path genericized:** script path throughout changed from
  `~/projects/network-check/check-network.sh` to the installed skill path
  `~/.claude/skills/network-check/scripts/check-network.sh`, with the hq source-of-truth
  path noted alongside per ADR 0009's symlink convention.
