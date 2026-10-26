# Hook wiring (unmeasured, verify at move)

Goal: the Zephyr Cloud `execute` tool is callable only in the `pm` lead session and only through `scripts/zephyr-guard.sh`. Hook semantics: only exit code 2 blocks a tool call; this hook never asks (an ask stalls unattended runs) and makes no network call. It is a second, separate PreToolUse hook from the port hook (`tools/hooks/port-precheck.sh`, advisory, exit 0): they share no state or script.

## Guarantee (what the hook does and does not enforce)
- Enforced by wiring plus hook: `execute` runs only in the `pm` lead session, and only for operations in `zephyr.read_ops` that pass the second check (GET, no deploy/promote/rollback text).
- Not enforced: which skill inside the `pm` lead makes the call. The `pm` lead also runs `post-merge-verify` (A.2), and a PreToolUse hook cannot tell skills apart. "`release-track` alone" (owner R2-1) below the session rests on the skill text only. Owner ruling OQ-2 (2026-10-26): enforcement at the `pm` lead session level is accepted for the P1 pilot, and the claim is stated as "`pm` lead session, read ops only". Enforcing it below the session (for example a dedicated release session) is revisited only if the DEV2-to-DEMO step is ever ruled in.

## The command (fail closed on launch failure)
The guard's own trap covers a running script only. If the hook cannot start (wrong `<agent-hq>` path, no `bash`, script missing), the shell exits 127 or 126, which does not block. So the wired command always ends in `|| exit 2`:
```
bash <agent-hq>/skills/release-track/scripts/zephyr-guard.sh || exit 2
```
`<agent-hq>` is the absolute path of the agent-hq checkout; whoever writes the wiring (the launcher, item 29) substitutes it. A literal `<agent-hq>` left in settings fails closed through `|| exit 2`.
Contract status: the `ZEPHYR_*` variables and the positional arguments below are item-local, a proposed INTERFACES amendment (integrator, M21), not yet a contract. The guard reads `ZEPHYR_PROFILE`, `ZEPHYR_TOOL` and `ZEPHYR_REFUSAL_LOG` from the environment (or positional `<profile-path> <execute-tool-name> [<refusal-log>]`). The command line carries no secret. Hook timeout behaviour (whether a timed-out hook blocks): unmeasured, verify at P0.

## Per-run values (who sets them)
Wiring is static settings, but the profile, tool name and log are per run, and `RUN_HOME` is a skill input, not an exported variable. The launcher that starts the `pm` lead (item 29) must export into that process, before start (unmeasured, verify at move):
- `ZEPHYR_PROFILE`: the read-only profile snapshot below (never the working `repo-profile.md`).
- `ZEPHYR_TOOL`: `zephyr.execute_tool` from that snapshot. The guard reads `zephyr:` only in block form (a bare `zephyr:` line with indented `read_ops`, as the `delivery-intake` template writes it); a one-line `zephyr: {..}` map gives no `read_ops` and every call is refused.
- `ZEPHYR_REFUSAL_LOG`: `RUN_HOME/pm/zephyr-refusals.log` (and `RUN_HOME` itself).
With `ZEPHYR_PROFILE` or `ZEPHYR_TOOL` unset the guard refuses every call. With no `ZEPHYR_REFUSAL_LOG` (or log argument) the guard falls back to `${RUN_HOME}/pm/zephyr-refusals.log` when `RUN_HOME` is exported; with neither it still refuses but writes no line, so the positive control below must assert the line.

## Profile source (pinned, read-only)
`REPO_PROFILE` is `<abs path>@<sha>`, but the guard reads whatever file it is given. The profile the hook reads must be a read-only snapshot of the profile at the pinned `<sha>` (for example `git show <sha>:<path>` into a file outside every agent's writable paths, mode 0444), materialised by the launcher before the `pm` lead starts. The working profile is agent-writable, so pointing the hook at it lets an edit add an operation. The guard does not enforce the snapshot: given `<path>@<40-hex>` that is not itself a file it strips the suffix and reads `<path>`, and it reads any plain path it is given. The snapshot rule rests on the launcher. Whether the launcher change is in scope is the integrator's call; record the method used in the P0 record.

## Options (every option is unmeasured; verify at P0)
1. Hook in the `pm` lead's settings with matcher equal to the `execute` tool name, plus `disallowedTools` for that tool in every other agent definition and launcher. Unmeasured: whether `pm` leads load that settings file in their launcher profile.
2. Hook in the frontmatter `hooks:` of a dedicated `pm` agent definition. Unmeasured: whether frontmatter hooks fire for the tool in a `claude -p` lead and for subagents it spawns (they must not be able to bypass it).
3. A wrapper settings file passed by the launcher only to the `pm` lead. Unmeasured: precedence against other settings layers.
In every option the tool stays in `disallowedTools` for all other types (check with `check-zephyr-disallowed.sh`), and subagents spawned by `pm` inherit the same hook or the same disallow.

## Positive control (required at P0 before any `execute` call)
Run the wired session and record each result:
1. A deliberate non-read call. Expected: exit 2, the call blocked, one new line in `RUN_HOME/pm/zephyr-refusals.log` (assert the line, not only the block).
2. The same wiring with the script path deliberately broken. Expected: the call blocked (the `|| exit 2` form), not allowed.
3. The measured `execute` input shape (keys and types), so the guard's closed key set can replace its assumption.
4. The measured operation ids, and the keyword check narrowed against them (owner ruling OQ-1, `zephyr-leg.md`); until this is recorded the unnarrowed check stands.
Record the option used, the profile snapshot method, the date, and the log line here at the move. Until recorded, `release-track` makes no `execute` call (fail closed).

## Recorded wiring
None recorded. Status: unmeasured.
