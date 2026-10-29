---
name: app-status
description: Use when checking health of pr-auto-updater or automate-pr-reviews launchd apps on macOS.
model: haiku
---

# App Status Skill

## Trigger

Use when checking the health of the `pr-auto-updater` or `automate-pr-reviews` launchd
apps on this machine.

Check the health of two long-running macOS launchd applications and report status in ≤6 bullets ending with GOOD or HALT: reason.

This is a read-only health check. Never run restart or fix commands automatically — report HALT with the recommended fix and wait for an explicit instruction. The restart/fix commands below are reference material for that follow-up, not part of the check.

## Steps

1. **Check `pr-auto-updater`** — launchd label `com.xavier.pr-auto-updater`.

   ```bash
   launchctl list com.xavier.pr-auto-updater
   tail -30 ~/logs/pr-auto-update.log
   [ -f ~/logs/pr-auto-update.lock ] && echo "LOCK EXISTS, age: $(( $(date +%s) - $(stat -f %m ~/logs/pr-auto-update.lock) ))s" || echo "no lock"
   ```

   Cadence: every 5 minutes. **Healthy:** `LastExitStatus = 0`; no PID between runs is
   normal; recent `RUN_END` within 10 min; no lock file, or one < 5 min old; a
   `[SKIPPED] network unavailable` entry is healthy (clean exit, no network). **Unhealthy:**
   non-zero `LastExitStatus`; no log entries in 10 min; a lock file older than 10 min
   (stuck run); no launchd entry at all (service not loaded).

2. **Check `automate-pr-reviews`** — launchd label `com.xavier.automate-pr-reviews`.

   ```bash
   launchctl list com.xavier.automate-pr-reviews
   tail -30 ~/Library/Logs/automate-pr-reviews/cron.log
   tail -20 ~/Library/Logs/automate-pr-reviews/cron-error.log 2>/dev/null
   ls -lt ~/Library/Logs/automate-pr-reviews/ | head -10
   ```

   Cadence: every 30 minutes. **Healthy:** `LastExitStatus = 0`; no PID between runs is
   normal; recent `cron.log` entry within 35 min; `cron-error.log` empty/absent; active
   `claude` processes for in-flight PRs are OK; a `[SKIPPED] network unavailable` entry is
   healthy. **Unhealthy:** non-zero `LastExitStatus`; entries in `cron-error.log`; no
   activity for 35+ min; no launchd entry at all.

3. **Diagnose against the Common Issues table** (below) if either app is unhealthy.

4. **Report** in the Output Format below — ≤6 bullets, ending `GOOD` or `HALT: reason`.
   Do not run the restart command yourself; name it in the HALT line and wait for
   confirmation.

## Common Issues

| Issue | Diagnosis | Fix |
|---|---|---|
| Stuck lock file | Lock file exists, older than 10 min, no active process | `rm ~/logs/pr-auto-update.lock` then restart app |
| Missing `SERVICE_ACCOUNT_LOGIN` | Auth error in logs, 401/403 responses | Check plist `EnvironmentVariables`; re-export and reload plist |
| Missing `GH_TOKEN` | `gh` CLI commands fail in logs | Check plist `EnvironmentVariables`; re-export and reload plist |
| launchd not loaded | `launchctl list` returns nothing for the label | Run the load command for the affected app |
| Expired gh token | `gh auth status` returns expired or revoked | Run `gh auth login` then reload plist |
| Missing plist file | `launchctl load` fails, plist path not found | Reinstall the service: check the project README for the correct plist and copy it to `~/Library/LaunchAgents/` |

## Restart commands (reference only — do not run without explicit instruction)

```bash
launchctl unload ~/Library/LaunchAgents/com.xavier.pr-auto-updater.plist
launchctl load ~/Library/LaunchAgents/com.xavier.pr-auto-updater.plist
```

```bash
launchctl unload ~/Library/LaunchAgents/com.xavier.automate-pr-reviews.plist
launchctl load ~/Library/LaunchAgents/com.xavier.automate-pr-reviews.plist
```

## Output Format

```
- pr-auto-updater: LastExitStatus=0, RUN_END 3min ago, no lock
- automate-pr-reviews: LastExitStatus=0, cron.log entry 12min ago, no errors
- Both services loaded and active
GOOD
```

Or if unhealthy:

```
- pr-auto-updater: LastExitStatus=1, last log entry 22min ago
- Lock file present, 18min old — possible stuck run
HALT: pr-auto-updater stuck; remove lock and restart
```

## Red flags

| Rationalization | What to do instead |
|---|---|
| "It's unhealthy, I'll just restart it myself." | This is read-only. Report HALT with the recommended fix and wait for explicit instruction. |
| "No PID in `launchctl list`, that must mean it's down." | No PID between scheduled runs is normal — the process only appears while actively executing. |
| "There's a `[SKIPPED] network unavailable` log line, that's a failure." | That is a healthy outcome — the service ran, detected no network, and exited 0. |

## Exit criteria

- [ ] Both apps' launchd status, logs, and lock state were checked.
- [ ] Report is ≤6 bullets and ends with `GOOD` or `HALT: <reason>`.
- [ ] No restart/fix command was executed without explicit follow-up instruction.

## Provenance

Provenance: Hermes skill `learnings/skill-sharing` (corpus-wide porting authorship
attestation: ADR 0010).
Lineage: X-context-docs skills/app-status@9d7143e
