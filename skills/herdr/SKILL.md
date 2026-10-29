---
name: herdr
description: Use when working in the Herdr terminal runtime — spawning panes, managing project workspaces, launching sub-agent sessions, using the CLI or socket API, or attaching to remote sessions. Triggers on any Herdr orchestration, workspace setup, or agent pane management task.
model: haiku
---

# Herdr

> **Model note:** This is pure reference material with no judgment-sensitive steps. The `model: haiku` frontmatter pins the cheap tier for direct invocations; if you are already running on another available model, apply this cheatsheet in place — no re-execution needed.

## Trigger

Use when working in the Herdr terminal runtime — spawning panes, managing project
workspaces, launching sub-agent sessions, using the CLI or socket API, or attaching to
remote sessions.

## Overview

Herdr is a terminal-native agent runtime and multiplexer. It sits between tmux and a desktop agent app — real PTY panes, persistent sessions, and semantic agent state tracking. Claude Code runs inside it.

## Steps

1. **Identify the task type** — session management, pane/workspace management, sub-agent
   pane orchestration, key-binding config, or socket-API scripting — and jump to the
   matching reference section below.
2. **Run the relevant `herdr` CLI command(s)** from the tables below.
3. **For orchestration scripts**, use `herdr wait agent-status`/`herdr wait output` to
   block on state rather than polling or guessing timing.

## Sessions

```sh
herdr                    # start or attach to the persistent background session
herdr --session my-proj  # use or create a named session
herdr session list       # list named sessions (also: attach/stop/delete <name>)
herdr server stop        # stop the server — kills all sessions and panes
herdr --remote workbox   # attach local terminal to a remote session over SSH
```

Detach (panes keep running): `Ctrl+B` then `q` — reattach by running `herdr` again.

Target a named session for one-off commands with the env var:
```sh
HERDR_SESSION=my-project herdr pane run 1-1 "npm run dev"
```

## Keyboard Shortcuts

Press `Ctrl+B` (the prefix) to enter prefix mode, then:

| Action | Key |
|---|---|
| Split pane right | `v` |
| Split pane down | `-` |
| New tab | `c` |
| New workspace | `Shift+n` |
| Rename workspace | `Shift+w` |
| Detach | `q` |
| Help overlay | `?` |

## Project Workspaces (CLI)

```sh
herdr workspace create --cwd ~/my-project --label my-project
herdr tab create --label logs
```

## Pane Management (CLI)

Canonical pane IDs come from `herdr pane list` (e.g. `w7:p1`); legacy ordinal IDs like `1-1` are still accepted.

```sh
herdr pane split w7:p1 --direction right    # or --direction down
herdr pane run 1-2 "npm test"               # sends command text plus Enter
herdr pane send-text 1-1 "partial input"    # literal text only, no Enter
herdr pane read 1-1 --source visible --lines 80
herdr pane read 1-1 --source recent --lines 120
herdr pane read 1-1 --source recent-unwrapped --lines 120
```

## Sub-Agent Panes

Agent `<target>` accepts terminal IDs, unique agent names, detected/reported agent labels, or legacy pane IDs.

```sh
herdr agent list                                # list all agent targets
herdr agent start <name> [--cwd PATH] [--workspace ID] -- <command...>
                                                # launch agent pane; argv after --
herdr agent attach <target>                     # attach to agent terminal (detach: Ctrl+B q)
herdr agent send <target> "text"                # literal text — use pane run for command + Enter
herdr agent rename <target> <name>              # customize sidebar label

herdr integration install claude                # also: codex, opencode, copilot, cursor, ...
herdr integration status                        # check installed integration versions
herdr integration status --outdated-only
```

**Wait for agent state or output** (orchestration scripts):
```sh
herdr wait agent-status 1-1 --status done       # statuses: idle|working|blocked|done|unknown
herdr wait agent-status 1-1 --status blocked --timeout 60000
herdr wait output 1-1 --match "compiled" --timeout 30000
```

## Custom Key Bindings (`~/.config/herdr/config.toml`)

```toml
[[keys.command]]
key = "prefix+alt+g"   # explicit syntax: "prefix+..." or a direct chord like "ctrl+alt+g"
type = "pane"          # "pane" = temp pane, closes on exit; "shell" = detached background; "popup" = modal terminal
command = "lazygit"
```

Apply without restarting: `herdr server reload-config`.

## Socket API

Newline-delimited JSON over a local socket. Useful for scripting and agent orchestration.

**Protocol:** `{"id":"req_1","method":"workspace.create","params":{}}`

Core methods by domain (not exhaustive — full schema: `herdr api schema --json`):

| Domain | Core methods |
|---|---|
| Workspace | `create` `list` `get` `focus` `rename` `close` |
| Tab | `create` `list` `get` `focus` `rename` `close` |
| Pane | `split` `list` `send_text` `read` `report_agent` `close` |
| Agent | `list` `start` `send` `focus` |
| Events | `subscribe` `wait` |

## Config Path

Default: `~/.config/herdr/config.toml`
Override: `HERDR_CONFIG_PATH=<path>`
Logs: `~/.config/herdr/herdr.log` (plus `herdr-client.log`, `herdr-server.log`)

## Red flags

| Rationalization | What to do instead |
|---|---|
| "I'll use the legacy ordinal pane ID in a new script." | Prefer canonical pane IDs from `herdr pane list` (e.g. `w7:p1`); legacy IDs like `1-1` are accepted but not canonical. |
| "I'll poll pane output in a sleep loop to detect completion." | Use `herdr wait agent-status`/`herdr wait output` to block on real state instead of polling. |
| "`pane send-text` will submit the command for me." | `send-text` sends literal text only, no Enter — use `pane run` for command + Enter. |

## Exit criteria

- [ ] The correct CLI surface (session/workspace/pane/agent/socket) was used for the task.
- [ ] Orchestration scripts block on `herdr wait` rather than polling/sleeping.

## Provenance

Provenance: Hermes skill `learnings/skill-sharing` (corpus-wide porting authorship
attestation: ADR 0010).
Lineage: X-context-docs skills/herdr@9d7143e
