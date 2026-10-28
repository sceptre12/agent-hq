# Install Hermes and lock it down (a new machine)

How to install Hermes Agent (Nous Research) on a new machine and bring it to the same locked-down state the
owner runs. Every path below is fixed by `hermes-up`, which refuses to start if the layout or the config drifts.
Design: `architecture/hermes-agent.md`. Templates and what each script enforces: `setup/README.md` (this directory).
Upstream facts come from the Hermes docs (hermes-agent.nousresearch.com/docs, read 2026-10-26). Anything not
confirmed there or in this repo is marked **UNVERIFIED**.

The install is an owner-run step, never done by an agent unattended (`architecture/hermes-agent.md` §5).
Run the commands from a zsh shell at the root of an agent-hq checkout unless a step says otherwise.
Set two shell variables first and run every step in that same shell: `AP` is the name of your cprof profile
that holds the Claude OAuth token, `LBL` is the LaunchAgent label. Steps 3-7 also assume the
`export HERMES_HOME=...` and `HC=...` from step 3 are still set.

```sh
AP=your-profile-name
LBL=local.$USER.hermes-up
```

## 0. What this gives you

Hermes holds learnings (memory and skills) and reads a read-only digest of agent-hq `main`. It never writes
agent-hq: it has no repo, terminal or commit tools (`architecture/hermes-agent.md` §4). 25 toolsets are disabled,
among them `terminal`, `web`, `browser`, `code_execution`, `cronjob` and `delegation`. Approvals are `manual`, and
`cron_mode` and `unattended_mode` are `deny`. There are no MCP servers. A fail-closed `pre_tool_call` hook
confines writes to `HERMES_HOME/work`. Hermes is started only through `hermes-up`, which refuses to start when any
of this drifts (`architecture/hermes-agent.md` §9 Gates, §13 D1-D7).

Fixed layout:

| What | Where | Mode |
|---|---|---|
| `HERMES_HOME` (config, `.env`, memory, skills, sessions, logs) | `~/claude-profiles/hermes/h1-home` | 700 |
| Hermes code, pinned to `908e4a4` | `~/claude-profiles/hermes/hermes-agent` | installer's |
| Launchers and hook | `~/claude-profiles/hermes/bin` | 555 each |
| agent-hq digest | `~/claude-profiles/hermes/hq/<sha>/`, `current` symlink | read-only |
| Claude OAuth token | `~/claude-profiles/$AP/token` | 600 or 400 |

## 1. Prerequisites

- macOS on Apple silicon (arm64). `hermes-up` hard-codes the installer's bundled Python directory
  `python-3.14.7+20260901-darwin-arm64` (`GW_PY`). Other platforms are not covered: see step 9.
- zsh, git and `/usr/bin/python3` (the hook, `check-config` and `seed-hook-allowlist` run on it). On a fresh Mac
  `/usr/bin/python3` and `git` are stubs until the Xcode command line tools are installed (`xcode-select --install`).
- A Claude OAuth token in a cprof profile. `cprof` is a zsh function: load it with
  `source tools/claude-profile/cprof.zsh` from this checkout (`tools/claude-profile/README.md`). Get a token with
  `claude setup-token`, then create the profile (it prompts for the token, hidden; never pass it in argv):

```sh
source tools/claude-profile/cprof.zsh
cprof new "$AP"
```

- The Bedrock backend is supported by Hermes but is not part of this setup and is unmeasured.

Verify:

```sh
uname -m                                   # arm64
ls -l ~/claude-profiles/$AP/token             # a regular file, mode -rw------- or -r--------
```

## 2. Install Hermes at the pin

The upstream installer is a remote script. Per `architecture/hermes-agent.md` §3 (Hermes docs, fetched 2026-10-08)
it downloads its own uv pin and pinned Python, Node.js, npm, ripgrep, FFmpeg, agent-browser with Chromium, and
cua-driver, and names only `hermes-agent.nousresearch.com` as a host. That the bundled Python lands under
`HERMES_HOME/tools/` comes from `GW_PY` in `hermes-up`, not from the docs. `--skip-browser` and
`--skip-computer-use` are documented flags that target agent-browser/Chromium and cua-driver; exactly what each
skips is **UNVERIFIED**. Use them, since those toolsets are disabled anyway.

Download the script first so you can read it before running it, instead of piping it straight into bash
(the documented one-liner is `curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash`):

```sh
mkdir -p ~/claude-profiles/hermes/install ~/claude-profiles/hermes/h1-home
chmod 700 ~/claude-profiles/hermes/h1-home
curl -fsSL https://hermes-agent.nousresearch.com/install.sh -o ~/claude-profiles/hermes/install/install.sh
less ~/claude-profiles/hermes/install/install.sh
wc -l ~/claude-profiles/hermes/install/install.sh    # the reviewed copy is 1049 lines (setup/README.md)
```

If the line count differs, upstream changed the script since it was reviewed: read the whole diff against the
reviewed copy (or the whole script) before running it. Running it runs upstream code with your user's rights; reading it and
checking its line count is the only guard here. A pinned sha256 of the script is **UNVERIFIED**, because the installer
changes upstream.

Run it with the code dir, the commit pin and the data dir:

```sh
HERMES_HOME=~/claude-profiles/hermes/h1-home bash ~/claude-profiles/hermes/install/install.sh \
  --dir ~/claude-profiles/hermes/hermes-agent \
  --commit 908e4a4b44480912ae3571833492c1aeac2d0eda \
  --non-interactive --skip-browser --skip-computer-use
```

- `--dir`, `--non-interactive`, `--skip-browser`, `--skip-computer-use` and `HERMES_HOME` are in the docs.
  `--commit` comes from `setup/README.md` ("`--commit` selects the commit"); its exact value syntax is
  **UNVERIFIED**. If the installer rejects it, check out the pin in the code dir and confirm the verify line below.
- The installer log is `logs/install.log` under the data dir.
- By default the installer also puts an entry point at `~/.local/bin/hermes`. Never run that bare `hermes`:
  without `HERMES_HOME` it uses `~/.hermes`. Whether `--dir` changes that link is **UNVERIFIED**.

Verify:

```sh
git -C ~/claude-profiles/hermes/hermes-agent rev-parse HEAD          # starts with 908e4a4
git -C ~/claude-profiles/hermes/hermes-agent status --porcelain      # empty (hermes-up refuses a dirty code dir)
ls ~/claude-profiles/hermes/h1-home/config.yaml
stat -f %Lp ~/claude-profiles/hermes/h1-home                          # 700 (re-run chmod 700 if not)
ls -d ~/claude-profiles/hermes/h1-home/tools/python-3.14.7+20260901-darwin-arm64   # the dir hermes-up expects
```

Then verify that the installer started nothing, and turn off the update check before anything else runs. This is
the first use of Hermes's config CLI from the code dir: that this entry point accepts `config set` the way the
documented `hermes config set` does is **UNVERIFIED**. That the installer starts no process, gateway, LaunchAgent or cron job is **UNVERIFIED** (the docs mention
`hermes gateway install` but not whether `install.sh` runs it):

```sh
pgrep -fl hermes                                   # no Hermes process (ignore your own less/editor on a hermes path)
launchctl print gui/$(id -u) | grep -i hermes      # empty: no LaunchAgent loaded
ls ~/Library/LaunchAgents | grep -i hermes         # empty: no plist written
ls -A ~/claude-profiles/hermes/h1-home/cron 2>/dev/null   # empty or absent
HERMES_HOME=~/claude-profiles/hermes/h1-home ~/claude-profiles/hermes/hermes-agent/hermes config set updates.check false
```

If any process or job shows up, stop it (`kill <pid>`, `launchctl bootout gui/$(id -u)/<its label>`) before step 3.

## 3. Lock the config

Apply every key in `setup/config-edits.md` to the installer's `config.yaml`. Edit in place; never add a
second copy of a key. Run Hermes's own config CLI from the code dir with `HERMES_HOME` set (the entry point is
**UNVERIFIED**, step 2). The config CLI (`config set`, `get`, `unset`, `check`, `edit`) is the only thing ever run outside `hermes-up`; never run `chat` or
`gateway` through this entry point.

Scalar keys, with `hermes config set` (dotted keys go to `config.yaml`, values are type-checked: Hermes docs, config CLI, read 2026-10-26):

```sh
export HERMES_HOME=~/claude-profiles/hermes/h1-home
HC=~/claude-profiles/hermes/hermes-agent/hermes
$HC config set memory.memory_enabled true
$HC config set memory.user_profile_enabled true
$HC config set memory.write_approval false
$HC config set skills.write_approval false
$HC config set skills.guard_agent_created true
$HC config set security.allow_lazy_installs false
$HC config set updates.check false
$HC config set auth.adopt_external_logins false
$HC config set approvals.mode manual
$HC config set approvals.timeout 300
$HC config set approvals.cron_mode deny
$HC config set approvals.unattended_mode deny
$HC config set curator.enabled false
```

Leave `memory.provider` unset. Never set `hooks_auto_accept`.

Model backend. The token reaches Hermes only through the environment: you (step 5) or `hermes-gw` (step 7) put
the token file's contents in `CLAUDE_CODE_OAUTH_TOKEN` by inline env assignment on the direct `hermes-up`
command. `hermes-up` refuses if that variable is empty, unsets `ANTHROPIC_API_KEY`, `ANTHROPIC_TOKEN`,
`OPENAI_API_KEY`, `OPENROUTER_API_KEY` and the other provider keys, then exports `HERMES_HOME` and
`CLAUDE_CODE_OAUTH_TOKEN` to Hermes. Point the model at Anthropic (the model id is the one in `config.active.yaml`):

```sh
$HC config set model.provider anthropic
$HC config set model.default claude-sonnet-5-5
$HC config unset model.base_url
```

The live extract (`config.active.yaml`) shows an OpenRouter `model.base_url` (`https://openrouter.ai/api/v1`); an
Anthropic-token backend needs none, and a gateway user sets it deliberately.
`check-config` enforces `model.provider` only, so confirm the rest by hand (verify below).

Non-scalar keys: `agent.disabled_toolsets`, `approvals.deny`, `mcp_servers` and `hooks.pre_tool_call`. The
docs do not confirm that `config set` can address a nested list. Edit `config.yaml` by hand (or with
`$HC config edit`) so each of these matches the block below, copied from `setup/config.active.yaml`. Replace
`__HOME__` with the absolute path of your home directory (`echo $HOME`): YAML does not expand `$HOME` or `~`.
Each block goes under its existing section; if the section already holds the key, replace that line.

```yaml
agent:
  disabled_toolsets: [terminal, code_execution, web, browser, browser-cdp, browser-use, computer_use, vision, image_gen, video_gen, video, tts, cronjob, delegation, x_search, kanban, project, start_chat, desktop_ui, feishu_doc, feishu_drive, hermes-yuanbao, connections, discord, discord_admin]
approvals:
  deny: ["git push*", "git commit*", "rm -rf*", "curl*", "wget*", "*| sh*", "*| bash*", "security *", "launchctl*"]
mcp_servers: {}
hooks:
  pre_tool_call:
    - command: "__HOME__/claude-profiles/hermes/bin/pre-tool-call.sh"
      matcher: "read_file|write_file|patch|search_files"
      timeout: 10
      fail_closed: true
```

No data line may contain the word `always` (comments are fine). Keep existing unrelated keys as they are
(`config-edits.md`: for example `terminal.backend`, which is moot while `terminal` is disabled).

Verify:

```sh
$HC config check
$HC config get model.provider                                         # anthropic
$HC config get model.base_url                                         # empty: no base_url
grep -v '^[[:space:]]*#' $HERMES_HOME/config.yaml | grep -c always    # 0
git -C ~/claude-profiles/hermes/hermes-agent status --porcelain        # still empty
```

The full check is step 5.

## 4. Install the launchers, the hook and the home files

Install the scripts into `~/claude-profiles/hermes/bin` with the modes from `setup/README.md` (Install layout).
`install -m 555` replaces a file that is already installed read-only (mode 555), so the same lines work for a
re-install; a plain `cp` onto it fails with `Permission denied`. `hermes-gw` has three `<auth-profile>`
placeholders. The `sed` fills them all with `$AP`; left unfilled it still fails closed.

```sh
mkdir -p ~/claude-profiles/hermes/bin
install -m 555 tools/hermes/setup/hermes-up ~/claude-profiles/hermes/bin/hermes-up
install -m 555 tools/hermes/setup/pre-tool-call.sh ~/claude-profiles/hermes/bin/pre-tool-call.sh
sed "s/<auth-profile>/$AP/g" tools/hermes/setup/hermes-gw > ~/claude-profiles/hermes/install/hermes-gw
install -m 555 ~/claude-profiles/hermes/install/hermes-gw ~/claude-profiles/hermes/bin/hermes-gw
```

The charter, the work dir and the `.env`. `.env` holds only `API_SERVER_KEY`: `hermes-up` refuses any other key.
`printf` is a zsh builtin, so the key never appears on a process argv:

```sh
cp tools/hermes/setup/SOUL.md $HERMES_HOME/SOUL.md && chmod 600 $HERMES_HOME/SOUL.md
mkdir -p $HERMES_HOME/work && chmod 700 $HERMES_HOME/work
printf 'API_SERVER_KEY=%s\n' "$(/usr/bin/openssl rand -hex 32)" > $HERMES_HOME/.env && chmod 600 $HERMES_HOME/.env
```

The `.env` mode is our choice: `hermes-up` reads only key names from `.env`, not its mode. How the Hermes API
server is enabled (the docs name `API_SERVER_ENABLED=true` too) is not covered by this guide and is
**UNVERIFIED**: `hermes-up` refuses any `.env` key other than `API_SERVER_KEY`. `hooks/` and `plugins/` under
`HERMES_HOME` must be absent or empty. The hook lives in `hermes/bin`, outside `HERMES_HOME`.

Record your consent for the hook before the first start, and again after any change to `pre-tool-call.sh`. `seed-hook-allowlist` checks that no Hermes
process is running and that the hook is mode 555 with the pinned sha256. It then writes
`shell-hooks-allowlist.json`. Never use `hooks_auto_accept`, `--accept-hooks` or `HERMES_ACCEPT_HOOKS` instead.

```sh
HERMES_HOME=~/claude-profiles/hermes/h1-home /usr/bin/python3 -I tools/hermes/setup/seed-hook-allowlist
```

Verify:

```sh
grep -c '<auth-profile>' ~/claude-profiles/hermes/bin/hermes-gw         # 0
shasum -a 256 ~/claude-profiles/hermes/bin/pre-tool-call.sh             # edd56ad2... = HOOK_SHA256 in seed-hook-allowlist
stat -f '%Lp %N' ~/claude-profiles/hermes/bin/*                          # 555 each
ls -l $HERMES_HOME/shell-hooks-allowlist.json                           # present, mode 600
cut -d= -f1 $HERMES_HOME/.env                                           # API_SERVER_KEY only
ls -A $HERMES_HOME/hooks $HERMES_HOME/plugins 2>/dev/null               # empty or absent
ls $HERMES_HOME/installs                                                # the installer's dependency dir
```

`hermes-up` gateway mode also needs `$HERMES_HOME/installs/<key>/facts.json` from the installer. If it is missing,
the hand-run gateway start in step 5 refuses with `dependency selector missing...`.

## 5. Verify the locked state before the first launch

`check-config` reads files only. It never runs Hermes, never touches the network and never reads a token.
It checks every row of `setup/required-config.tsv`, then that no data line contains `always`, then the hook
file (regular file, mode 555).

```sh
/usr/bin/python3 -I tools/hermes/setup/check-config --home ~/claude-profiles/hermes/h1-home
```

Pass: one `PASS <key>` line per check, and the last line is `CHECK-CONFIG: PASS n=23` (20 TSV rows, `no-always`,
`hook-file`, `hook-mode`; measured on a fixture of `config.active.yaml`, which passes only after its `__HOME__`
is replaced with the absolute home path). Without the hook installed, the hook lines print
`SKIP hook-file (not present)` and are not counted; with neither `--home` nor `$HERMES_HOME` set they print
`SKIP hook-file (no --home or $HERMES_HOME)`. Exit codes: 0 pass, 1 fail, 2 usage or parse
error, 3 unreadable.

Failure lines, and what they mean:

| Line | Meaning |
|---|---|
| `FAIL <key>: want eq <value>, got <shape>` | the key differs from `<value>`; `<shape>` is `absent`, `scalar`, `list(n=<k>)` or `map(n=<k>)`, never the live value (it could be a secret) |
| `FAIL <key>: want set-eq [...], got list(n=<k>), missing [...] extra n=<k>` | a list (`disabled_toolsets`, `approvals.deny`) differs; order is ignored; `missing` names expected items only, extras are only counted |
| `FAIL mcp_servers: want empty-map {}, got map(n=<k>)` | an MCP server is configured (names are never printed) |
| `FAIL hooks.pre_tool_call: want has-hook ..., got no matching entry among <n>` | no entry with this command, matcher, `fail_closed: true` |
| `FAIL <key>: want unset-or-eq <value>, got <shape>` | `memory.provider` or `hooks_auto_accept` is set to something else |
| `FAIL no-always: <n> line(s)` | a data line contains `always` |
| `FAIL hook-file: not a regular file` / `FAIL hook-mode: mode <m>, want 555` | the installed hook is a symlink or has the wrong mode |
| `UNPARSEABLE line <n>: <reason>` (exit 2) | the file uses YAML outside the subset `check-config` reads (header of `check-config`) |
| `CHECK-CONFIG: FAIL failed=<k> of <N>` | summary; exit 1 |

The fix for any `FAIL` is to re-apply step 3 (or step 4 for the hook lines), then re-run this step.

**Stop the line on a FAIL.** Run nothing below, neither the chat nor the gateway, unless the last line is
`CHECK-CONFIG: PASS`. Chat mode skips `hermes-up`'s config check (that check runs only in gateway mode), so
`check-config` is the only config check before a chat.
`check-config` was tested only against `config.active.yaml`, the 158 active lines of the live file. Whether it parses the
installer's full commented `config.yaml` (about 2,350 lines) without an `UNPARSEABLE` line is **UNVERIFIED**.
`UNPARSEABLE` is a parser limit, not a config failure. Report it rather than reshaping the file to suit.

First smoke test, in chat mode. Give the token by inline env assignment on the direct command. Never use
`$(cat token)`, and never put a token inside a `bash -c` or `sh -c` string:

```sh
HERMES_HOME=~/claude-profiles/hermes/h1-home CLAUDE_CODE_OAUTH_TOKEN="$(<~/claude-profiles/$AP/token)" ~/claude-profiles/hermes/bin/hermes-up chat -q "hello"
```

Chat mode checks the home, the token, the pin, the forbidden env vars, the argument whitelist and the hook
consent. The config, `.env` and `hooks/`/`plugins/` checks run only in gateway mode. Start the gateway once by
hand the same way; any refusal prints `hermes-up: gateway refused: <reason>`:

```sh
HERMES_HOME=~/claude-profiles/hermes/h1-home CLAUDE_CODE_OAUTH_TOKEN="$(<~/claude-profiles/$AP/token)" ~/claude-profiles/hermes/bin/hermes-up gateway run
```

Verify: the chat answers; the gateway does not print `gateway refused` (stop it with Ctrl-C).

## 6. Build the agent-hq digest

Hermes reads a read-only `git archive` snapshot of the digest set at an agent-hq `main` sha (`tools/hermes/README.md`).
The out-root is `~/claude-profiles/hermes`. The builder writes `<out-root>/hq/<sha>/` and flips
`<out-root>/hq/current`. The hook allows `search_files` only under `~/claude-profiles/hermes/hq` (header of
`pre-tool-call.sh`), and `architecture/hermes-agent.md` §5 places the digest at `~/claude-profiles/hermes/hq/<sha>/`.
`SOUL.md` names no path; it points Hermes at the `hq-index` skill.

From a clone of agent-hq, with Hermes stopped:

```sh
git fetch origin main
bash tools/hermes/build-digest.sh "$(git rev-parse origin/main)" ~/claude-profiles/hermes
bash tools/hermes/verify-digest.sh ~/claude-profiles/hermes/hq/current .
```

The index skill is staged only. Review it, then copy it in yourself:

```sh
less ~/claude-profiles/hermes/hq/current/.index/hq-index/SKILL.md
mkdir -p $HERMES_HOME/skills/hq-index
cp ~/claude-profiles/hermes/hq/current/.index/hq-index/SKILL.md $HERMES_HOME/skills/hq-index/
```

Verify: `verify-digest.sh` prints `DIGEST == MAIN <sha>`. STALE (exit 4) or a mismatch (exit 5) means do not use
the snapshot. A `SECRET-HIT: <path>` (exit 3) means the build was aborted and deleted. Refresh the digest the same
way whenever `main` moves (`tools/hermes/README.md`, "Refresh when hq main moves").

## 7. Run it always-on (LaunchAgent)

`setup/hermes-up.plist.example` runs `hermes-gw`. `hermes-gw` checks the token file, then execs
`hermes-up gateway run` with the token in the environment only. Run this step only after step 5 ended in
`CHECK-CONFIG: PASS`. The `sed` fills `__LABEL__` with `$LBL`
and `__HOME__` (absolute home path; launchd expands neither `$HOME` nor `~`). Check the bundled Python dir in
`PATH` against step 2.

```sh
sed -e "s|__LABEL__|$LBL|g" -e "s|__HOME__|$HOME|g" tools/hermes/setup/hermes-up.plist.example > ~/Library/LaunchAgents/$LBL.plist
chmod 644 ~/Library/LaunchAgents/$LBL.plist
plutil -lint ~/Library/LaunchAgents/$LBL.plist
mkdir -p $HERMES_HOME/logs                     # launchd does not create the log dir
: > $HERMES_HOME/logs/gateway.err.log          # start from an empty log, so old refusals do not show
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/$LBL.plist
launchctl print gui/$(id -u)/$LBL
```

`bootstrap` fails on a label that is already loaded. To re-install, run `launchctl bootout gui/$(id -u)/$LBL`
first, then the `bootstrap` line.

Every refusal by `hermes-gw` or `hermes-up` exits 0. With `KeepAlive/SuccessfulExit=false`, launchd then parks
the job instead of respawning it. A parked job shows in `launchctl print` as not running, and the reason is the last line of
`$HERMES_HOME/logs/gateway.err.log`. To stop it: `launchctl bootout gui/$(id -u)/$LBL` (the
`bootout` form used in `tools/hermes/README.md`). The `bootstrap` and `print` invocations were not exercised
from this repo.

Verify: `plutil -lint` prints `OK`; `launchctl print` shows the job; after this fresh bootstrap,
`tail -n 3 $HERMES_HOME/logs/gateway.err.log` shows no `gateway refused` line.

## 8. Keeping it locked

- `hermes-up` re-checks the config, `.env`, `hooks/` and `plugins/` at every gateway start. A respawn after drift
  parks the job instead of running unlocked.
- Run step 5 (`check-config`) after any `hermes update`, after any config edit, and after `hermes doctor --fix`.
  Whether `doctor --fix` rewrites keys this setup depends on is **UNVERIFIED**, so assume it may.
- Never set `HERMES_YOLO_MODE`, `HERMES_ACCEPT_HOOKS`, `HERMES_SAFE_MODE`, `HERMES_IGNORE_USER_CONFIG` or
  `HERMES_IGNORE_RULES`, even to an empty value. `hermes-up` refuses when any is set; safe-mode and ignore-config
  skip config, hooks and `SOUL.md`.
- `updates.check` is false, so updates happen only when you choose. An update moves the code off the pin and
  `hermes-up` refuses (`code sha ... != pin 908e4a4`). Moving the pin is a design change: edit `PIN` in `hermes-up`
  through an agent-hq design record, then repeat steps 2-5.
- Any change to `pre-tool-call.sh` changes its sha256. Re-pin `HOOK_SHA256` in `seed-hook-allowlist`, re-install
  the hook with the `install -m 555` line from step 4 (a `cp` onto the mode-555 file fails), then re-run
  `seed-hook-allowlist` (`setup/README.md`).
- Re-installing `hermes-up` or `hermes-gw` (for example after a re-pin, steps 2-5) uses the same `install -m 555`
  lines from step 4.
- The 25-name toolset list lives in three places that must agree: `required-config.tsv`, `config-edits.md` and
  `GW_TOOLSETS` in `hermes-up`. `bash tools/hermes/test_check-config.sh` checks the TSV against `hermes-up` and
  against `config.active.yaml`, not against `config-edits.md`. Compare that file by eye when the list changes.

## 9. Known gaps

From `setup/README.md` ("Known gaps", accepted 2026-10-25 by the owner), verbatim:

- The hook guards reads with a denylist, so `read_file` can open host credential dirs such as `~/.ssh`, `~/.aws` and `~/.config/gh`. Mitigation: the web, terminal and browser toolsets are disabled (`agent.disabled_toolsets`). A fix would change the live hook and its sha256 pin.
- `hermes-up` checks chat and `API_SERVER_*` keys only in `.env`, not in the inherited environment.
- Memory and skills write without approval, by design (`architecture/hermes-agent.md`).
- The `seed-hook-allowlist` success path (writing the allowlist) is untested where `/bin/ps` is unavailable; its refusals are tested.
- The tests drive `hermes-up` against a fixture: a stub `git` on `PATH` reporting the pin sha, a stub `hermes`, and a stub config loader that reads JSON. Not exercised: Hermes's real config loader and dependency environment, plugin-platform env keys that Hermes reads dynamically, and that the toolset list in `hermes-up` matches `config-edits.md`.

Unmeasured on a new machine:

- The bundled Python dir `python-3.14.7+20260901-darwin-arm64` is a constant in `hermes-up` (`GW_PY`) and in the
  plist `PATH`. If the installer at the pin creates a different dir, which is likely on another OS or CPU, the
  gateway refuses with `code-dir interpreter missing`. Changing the constant is a change to `hermes-up`.
- The `--commit` flag syntax, and whether `config set` handles nested lists are not
  confirmed by the docs (steps 2-3).
- Whether `check-config` parses a full installer `config.yaml` (step 5).
- The Bedrock backend, and the egress hosts (Anthropic model and OAuth endpoints; `architecture/hermes-agent.md` §9).
