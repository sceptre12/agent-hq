# Hermes setup (templates and records)

Copied from the owner's working Hermes install so it can be rebuilt. Secrets and state are never copied: no auth.json,
.env files, API keys, token profile dir, pairing, memories, databases, logs or caches. Live sources are under
`~/claude-profiles/hermes` (checked byte-identical to the design-record copies in the hq source repo,
`plans/hermes-agent/evidence/h2a/`); `seed-hook-allowlist` and `config-edits.md` exist only in that record.

| File | Purpose | Source | Placeholders to fill |
|---|---|---|---|
| `hermes-gw` | LaunchAgent entry: checks the token file, then `hermes-up gateway run` with the token in the environment only | live `bin/hermes-gw` | `<auth-profile>` (3 places: auth profile dir name) |
| `hermes-up` | Fail-closed launcher: pin, env and argument whitelist, hook consent, gateway config checks, then `hermes` | live `bin/hermes-up` | none |
| `pre-tool-call.sh` | `pre_tool_call` hook: writes only under `HERMES_HOME/work`, read denylist, `search_files` roots | live `bin/pre-tool-call.sh` | none |
| `seed-hook-allowlist` | Owner-run once: records consent for the hook in `shell-hooks-allowlist.json`; pins the hook's sha256 | record `evidence/h2a/seed-hook-allowlist` | none (re-pin `HOOK_SHA256` after any hook change) |
| `hermes-up.plist.example` | gateway LaunchAgent | live `~/Library/LaunchAgents/` plist | `__LABEL__`, `__HOME__` |
| `SOUL.md` | Hermes charter; "hq" retargeted to "agent-hq" (skill name `hq-index` unchanged) | live `h1-home/SOUL.md` | none |
| `config.active.yaml` | Active lines of the live `config.yaml` (comments stripped; header says so) | live `h1-home/config.yaml` | `__HOME__` |
| `config-edits.md` | Key-to-value edits applied to the installer's `config.yaml` | record `evidence/h2a/config-edits.md` | none |

Facts the scripts enforce: `HERMES_HOME` must be `~/claude-profiles/hermes/h1-home` (mode 700); `hooks/` and `plugins/`
under it must be absent or empty; the hook sits in `hermes/bin`, outside `HERMES_HOME`, mode 555; the hook's sha256 must
equal `HOOK_SHA256` in `seed-hook-allowlist`.

Upstream installer (reference only, not vendored): it clones `https://github.com/NousResearch/hermes-agent.git`
(`--commit` selects the commit). Pinned commit `908e4a4b44480912ae3571833492c1aeac2d0eda` (`PIN=908e4a4` in `hermes-up`).
The owner's local copy is `~/claude-profiles/hermes/install/install.sh` (1049 lines, unmodified upstream).
Design: `architecture/hermes-agent.md`. Test: `tools/hermes/test_hermes-setup.sh`.
