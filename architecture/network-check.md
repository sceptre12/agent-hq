# network-check — design record (ADR 0011)

One-line summary: a single-purpose skill + companion POSIX shell script that verifies
outbound internet reachability against three DNS-free IP targets before a network-dependent
operation runs, and establishes that a "network unavailable" skip is a healthy outcome, not
an error.

## What This Is

A guard skill: it exists so any script or skill about to make an outbound call (or a
scheduled background job) can cheaply answer "is the network even up?" before attempting
the real call and misattributing a connectivity failure to a bug in its own logic. The
DNS-free design (raw IPs, not hostnames) means a broken resolver can never produce a false
negative — this checks the network path itself, not DNS.

## Components

- **`skills/network-check/SKILL.md`** (109 lines) — frontmatter (`description` with the
  "Use when..." trigger), `## Trigger`, `## Steps` (read the script's exit code, branch on
  script vs. interactive context, the bash guard pattern, the targets table), `## Red
  flags` (4-row rationalization table), `## Exit criteria` (3 checks), `## Provenance`
  (lineage + a full refit-notes declaration).
- **`skills/network-check/scripts/check-network.sh`** (POSIX `sh`, authored during this
  port — see Settled decisions) — tries each of three DNS-free IP targets in turn, `nc`
  first (TCP connect to port 443) then `curl` as fallback per target, exits `0` on first
  success, `1` if every target/method fails. `-v` prints attempts to stderr; stdout stays
  silent by default so callers can rely purely on the exit code.

## Interfaces

- **Trigger surface:** frontmatter `description` fires on "about to make an outbound
  call" (curl/gh/package installs/API calls) or "diagnosing why a scheduled job did
  nothing."
- **Inputs:** none beyond the optional `-v` flag to the script.
- **Outputs:** exit code 0 (reachable) / 1 (not reachable); with `-v`, per-target attempt
  lines on stderr.
- **Consumers:** the skill body's own bash guard pattern is the primary consumer pattern —
  any script sourcing/calling `~/.claude/skills/network-check/scripts/check-network.sh` at
  its top, logging `[SKIPPED] network unavailable` and exiting 0 on failure so a
  scheduler's last-exit-status health signal stays green. No other hq skill currently
  calls this one; it is infrastructure available to be called, not yet wired into a
  specific consumer on this machine (see Settled decisions — the source's employer
  consumer list did not carry over).

## Constraints

- **Runtime dependency:** none beyond POSIX `sh` plus `nc` and/or `curl` — both verified
  present and functional on this machine (Gate 3; live-tested during the port, exit 0
  against `1.1.1.1:443` via `nc`).
- **No DNS dependence by design:** all three targets (`1.1.1.1`, `8.8.8.8`, `8.8.4.4`) are
  raw IPs; a DNS outage cannot cause a false negative here — this is the whole reason the
  script exists rather than a plain `ping <hostname>`.
- **Exit-code contract is the interface.** stdout is intentionally silent by default;
  callers must not parse stdout, only the exit code (and, with `-v`, stderr for humans
  debugging interactively).

## Settled decisions (port-time rulings — record, do not reopen)

- **Companion script authored, not ported.** The source `SKILL.md` pointed at
  `~/projects/network-check/check-network.sh`, which does not exist in the X-context-docs
  transfer or on this machine (user ruling 2026-07-05,
  `plans/dev-workspace-base-skills.md` triage table: "source ships SKILL.md only —
  companion script absent, must be authored as declared refit"). The script was written
  fresh for this port and placed inside the skill directory
  (`skills/network-check/scripts/check-network.sh`) rather than at the source's external
  path, so the ADR 0009 symlink install carries the script along with the skill
  automatically — no second install step needed.
- **Employer consumer list dropped.** The source's `## Integration` section named two
  employer-specific launchd apps and half a dozen employer-specific skills as consumers.
  All were independently SKIPped at Gate 0 (`plans/dev-workspace-base-skills.md` triage
  table) and none exist on this machine; replaced with a generic "scheduled job"
  (cron/launchd/CronCreate) framing rather than re-naming absent, employer-specific
  consumers.
- **Leak-scan false-positive caught and reworded.** An early draft's refit-notes prose
  used a common English word for "this runtime" that happens to also be an employer CI/CD
  tool's proper name, which collided with the fragment-assembled employer-tool-name scan
  (Gate 2). Reworded to "Claude Code"/"runtime" throughout to remove the ambiguous
  collision rather than argue the hit was a false positive and move on — cheaper to
  defuse than to litigate.

## Source lineage

Provenance: Hermes skill `learnings/skill-sharing` (was learnings/skill-sharing.md) (the recorded port friction this whole pipeline
traces to).
Lineage: X-context-docs `skills/network-check@87ed5a6`.
Port pipeline: `tools/skill-porting.md` Gates 0-3 only (this record); tracked as
`plans/dev-workspace-base-skills.md` row P8 (wave 4 of the ratified port order).
