# Hook wiring (unmeasured, verify at move)

Goal: the Zephyr `execute` tool is callable only by `release-track` (in the `pm` lead session), and only through `scripts/zephyr-guard.sh`. Hook semantics: only exit code 2 blocks a tool call; this hook never asks (an ask stalls unattended runs) and makes no network call. It is a second, separate PreToolUse hook from the port hook (`tools/hooks/port-precheck.sh`, advisory, exit 0): they share no state or script.

## The command
```
bash <agent-hq>/skills/release-track/scripts/zephyr-guard.sh <profile-path> <execute-tool-name> [<refusal-log>]
```
Environment alternative: `ZEPHYR_PROFILE`, `ZEPHYR_TOOL`, `ZEPHYR_REFUSAL_LOG`; the log defaults to `$RUN_HOME/pm/zephyr-refusals.log`. The tool name is `zephyr.execute_tool` from the profile, passed by the wiring.

## Options (every option is unmeasured; verify at P0)
1. Hook in the `pm` lead's settings with matcher equal to the `execute` tool name, plus `disallowedTools` for that tool in every other agent definition and launcher. Unmeasured: whether `pm` leads load that settings file in their launcher profile.
2. Hook in the frontmatter `hooks:` of a dedicated `pm` agent definition. Unmeasured: whether frontmatter hooks fire for the tool in a `claude -p` lead and for subagents it spawns (they must not be able to bypass it).
3. A wrapper settings file passed by the launcher only to the `pm` lead. Unmeasured: precedence against other settings layers.
In every option the tool stays in `disallowedTools` for all other types (check with `check-zephyr-disallowed.sh`), and subagents spawned by `pm` inherit the same hook or the same disallow.

## Positive control (required at P0 before any `execute` call)
Run the wired session with a deliberate non-read call. Expected: exit 2, the call blocked, one line in `zephyr-refusals.log`. Record the option used, the date, and the log line here at the move. Until recorded, `release-track` makes no `execute` call (fail closed).

## Recorded wiring
None recorded. Status: unmeasured.
