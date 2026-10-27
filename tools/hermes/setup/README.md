# Hermes setup (templates and records)

Install guide: `INSTALL.md` (install Hermes at the pin on a new machine, lock the config, verify it with `check-config`).

Copied from the owner's working Hermes install so it can be rebuilt. Secrets and state are never copied: no auth.json,
.env files, API keys, token profile dir, pairing, memories, databases, logs or caches. Live sources are under
`~/claude-profiles/hermes` (checked byte-identical to the design-record copies in the hq source repo,
`plans/hermes-agent/evidence/h2a/`); `seed-hook-allowlist` and `config-edits.md` exist only in that record.
`hermes-up` and `pre-tool-call.sh` are byte-identical to the live install and `seed-hook-allowlist` to the record copy; the other files are sanitized (`config.active.yaml` is an extract).

## Files

| File | Purpose | Source | Values to fill |
|---|---|---|---|
| `hermes-gw` | LaunchAgent entry: checks the token file, then `hermes-up gateway run` with the token in the environment only | live `bin/hermes-gw` | `<auth-profile>` (3 places: auth profile dir name) |
| `hermes-up` | Fail-closed launcher, see "What each script enforces" | live `bin/hermes-up` | none to fill; host-specific constant: the bundled Python dir `python-3.14.7+20260901-darwin-arm64` (`GW_PY`) |
| `pre-tool-call.sh` | `pre_tool_call` hook | live `bin/pre-tool-call.sh` | none |
| `seed-hook-allowlist` | Owner-run once: records consent for the hook in `shell-hooks-allowlist.json`; pins the hook's sha256 | record `evidence/h2a/seed-hook-allowlist` | none (re-pin `HOOK_SHA256` after any hook change) |
| `hermes-up.plist.example` | gateway LaunchAgent | live `~/Library/LaunchAgents/` plist | `__LABEL__`, `__HOME__`; host-specific: the bundled Python dir in `PATH` |
| `SOUL.md` | Hermes charter; "hq" retargeted to "agent-hq" (skill name `hq-index` unchanged) | live `h1-home/SOUL.md` | none |
| `config.active.yaml` | Active lines of the live `config.yaml` (comments stripped; header says so) | live `h1-home/config.yaml` | `__HOME__` |
| `config-edits.md` | Key-to-value edits applied to the installer's `config.yaml` | record `evidence/h2a/config-edits.md` | `__HOME__` |
| `INSTALL.md` | Install guide: install Hermes at the pin on a new machine, lock the config, verify it, keep it locked | this repo | none |
| `check-config` | Read-only pre-flight check of `HERMES_HOME/config.yaml` against `required-config.tsv` (no Hermes code, no network, no token); test `tools/hermes/test_check-config.sh` | this repo | none |
| `required-config.tsv` | The required config keys and values that `check-config` enforces, one row per key | this repo | none |

## Install layout

| File | Goes to on the host | Mode |
|---|---|---|
| `hermes-gw` (after filling `<auth-profile>`) | `~/claude-profiles/hermes/bin/hermes-gw` | 555 |
| `hermes-up` | `~/claude-profiles/hermes/bin/hermes-up` | 555 |
| `pre-tool-call.sh` | `~/claude-profiles/hermes/bin/pre-tool-call.sh` | 555: run `chmod 555` on it before `seed-hook-allowlist` (a git checkout gives 755 and the helper refuses any other mode) |
| `seed-hook-allowlist` | not installed: the owner runs it once from this checkout, `HERMES_HOME=~/claude-profiles/hermes/h1-home /usr/bin/python3 -I tools/hermes/setup/seed-hook-allowlist`, before the first start | as checked out (755) |
| `hermes-up.plist.example` (placeholders filled, `plutil -lint`) | `~/Library/LaunchAgents/<label>.plist` | 644 |
| `SOUL.md` | `~/claude-profiles/hermes/h1-home/SOUL.md` | 600, as the live file |
| `config.active.yaml`, `config-edits.md` | not installed: reference for the keys edited in the installer's `h1-home/config.yaml` | n/a |

Also required by the scripts: `~/claude-profiles/hermes/h1-home` (`HERMES_HOME`) mode 700; the token file
`~/claude-profiles/<auth-profile>/token` a regular file, not a symlink, mode 600 or 400; `hooks/` and `plugins/` under
`HERMES_HOME` absent or empty (the hook lives in `hermes/bin`, outside `HERMES_HOME`).

## What each script enforces

- `hermes-gw`: `HERMES_HOME` is `~/claude-profiles/hermes/h1-home`; the token file passes the checks above and is non-empty. Every refusal exits 0 (the plist's `KeepAlive/SuccessfulExit=false` then parks the job). It hands the token to `hermes-up` through the environment only.
- `hermes-up`: `HERMES_HOME` equals `~/claude-profiles/hermes/h1-home` and is mode 700; the token is in the environment; the code dir is at the pin `908e4a4` and clean; the forbidden env vars (`HERMES_YOLO_MODE` and the other four it lists) are unset; the argument whitelist (`chat [-q TEXT]`, `-h/--help`, exactly `gateway run`); the hook is approved in `shell-hooks-allowlist.json`. For `gateway run` it also checks `config.yaml` through Hermes's own loader (the 25-name `disabled_toolsets`, the hook, `approvals.unattended_mode: deny`, an `api_server` host of 127.0.0.1 if set), that `.env` holds only `API_SERVER_KEY`, and that `hooks/` and `plugins/` are absent or empty; it sets `API_SERVER_HOST=127.0.0.1`.
- `pre-tool-call.sh`: writes only under `HERMES_HOME/work`; a read denylist; `search_files` roots limited to `work/`, `sessions/` and the `hermes/hq` snapshot; any internal error blocks.
- `seed-hook-allowlist`: `HERMES_HOME` is the expected path; the hook is a regular file of mode 555 whose sha256 equals `HOOK_SHA256`; no Hermes process is running; an existing allowlist holds only that one hook.

## Known gaps (accepted 2026-10-25, owner)

- The hook guards reads with a denylist, so `read_file` can open host credential dirs such as `~/.ssh`, `~/.aws` and `~/.config/gh`. Mitigation: the web, terminal and browser toolsets are disabled (`agent.disabled_toolsets`). A fix would change the live hook and its sha256 pin.
- `hermes-up` checks chat and `API_SERVER_*` keys only in `.env`, not in the inherited environment.
- Memory and skills write without approval, by design (`architecture/hermes-agent.md`).
- The `seed-hook-allowlist` success path (writing the allowlist) is untested where `/bin/ps` is unavailable; its refusals are tested.
- The tests drive `hermes-up` against a fixture: a stub `git` on `PATH` reporting the pin sha, a stub `hermes`, and a stub config loader that reads JSON. Not exercised: Hermes's real config loader and dependency environment, plugin-platform env keys that Hermes reads dynamically, and that the toolset list in `hermes-up` matches `config-edits.md`.

## References in copied scripts

Comments in the copied files (`hermes-up`: "README H2c", T-411 and Hermes source line numbers; `hermes-gw`: H2c; `config-edits.md`: `h2b-install.md` and `plans/...` paths) point at hq-only design records that are not mirrored here. They are left as copied.

## Upstream installer (reference only, not vendored)

It clones `https://github.com/NousResearch/hermes-agent.git` (`--commit` selects the commit). Pinned commit
`908e4a4b44480912ae3571833492c1aeac2d0eda` (`PIN=908e4a4` in `hermes-up`). The owner's local copy is
`~/claude-profiles/hermes/install/install.sh` (1049 lines, unmodified upstream).
Design: `architecture/hermes-agent.md`. Test: `tools/hermes/test_hermes-setup.sh`.
