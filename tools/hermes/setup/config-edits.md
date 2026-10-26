# H2a config edit list (in-place on installer config.yaml; key -> value). NOT a replacement file.
# Key-existence check: names only, vs ~/claude-profiles/hermes/h1-home/config.yaml (H1 install, code 908e4a4).
# Target state. Live file (after H2b, h2b-install.md:25-28) already has every key below except curator.enabled (last line, presence not in h2b-install.md); memory.memory_enabled, memory.user_profile_enabled, memory.write_approval, skills.write_approval (rows 5, 6, 7, 9) differ: edit those four, and set curator.enabled false (five lines in all), never add a duplicate key. E = key present in the live file.
agent.disabled_toolsets  -> [terminal, code_execution, web, browser, browser-cdp, browser-use, computer_use, vision, image_gen, video_gen, video, tts, cronjob, delegation, x_search, kanban, project, start_chat, desktop_ui, feishu_doc, feishu_drive, hermes-yuanbao, connections, discord, discord_admin]   # E (live after H2b, h2b-install.md:26; unchanged). Registry names measured from tools/*.py; see stale list
memory.memory_enabled        -> true    # E (live false after H2b, h2b-install.md:25; set to true). Default: hermes_cli/config_defaults.py:1312; read: tools/memory_tool.py:298-300
memory.user_profile_enabled  -> true    # E (live false after H2b, h2b-install.md:25; set to true). Default: hermes_cli/config_defaults.py:1313; read: tools/memory_tool.py:298-300
memory.write_approval        -> false   # E (live true after H2b, h2b-install.md:26; set to false). Default: hermes_cli/config_defaults.py:1317; gate read: tools/write_approval.py:38,50 (subsystem MEMORY, :32)
memory.provider              -> (leave unset)  # not added. Default "": hermes_cli/config_defaults.py:1325; read: hermes_cli/doctor_state.py:622
skills.write_approval        -> false   # E (live true after H2b, h2b-install.md:26; set to false). Default: hermes_cli/config_defaults.py:1482; gate read: tools/write_approval.py:38,50 (subsystem SKILLS, :33)
skills.guard_agent_created   -> true    # E (live true after H2b, h2b-install.md:26; unchanged). Source default False
security.allow_lazy_installs -> false   # E (live after H2b, h2b-install.md:27; unchanged). Source: pm/install.py:191 reads it, default True
updates.check                -> false   # E (live false after H2b, h2b-install.md:25; unchanged)
auth.adopt_external_logins   -> false   # E (live false, h2b-install.md:28; unchanged)
approvals.mode               -> manual  # E (live after H2b, h2b-install.md:27; unchanged)
approvals.timeout            -> 300     # E (live after H2b, h2b-install.md:27; unchanged)
approvals.cron_mode          -> deny    # E (live after H2b, h2b-install.md:27; unchanged). Spec wrote top-level "cron_mode"; source reads approvals.cron_mode, tools/approval.py:1104)
approvals.unattended_mode    -> deny    # E (live after H2b, h2b-install.md:27; unchanged). Same: approvals.unattended_mode, approval.py:923)
approvals.deny               -> ["git push*","git commit*","rm -rf*","curl*","wget*","*| sh*","*| bash*","security *","launchctl*"]   # E (live after H2b, h2b-install.md:27; unchanged)
mcp_servers                  -> {}      # E (live after H2b, h2b-install.md:27; unchanged)
hooks.pre_tool_call          -> [{command: "<HOME>/claude-profiles/hermes/bin/pre-tool-call.sh", matcher: "read_file|write_file|patch|search_files", timeout: 10, fail_closed: true}]   # E (live after H2b, h2b-install.md:27; unchanged)
hooks_auto_accept            -> (leave unset/false; never set)   # not added
# Also: `grep -v '^[[:space:]]*#' $HERMES_HOME/config.yaml | grep -c always` must stay 0 (data lines only; plain `grep -c always` counts 18 pre-existing comment lines on h1-home, so it can never be 0).
# Existing but unrelated keys left alone (e.g. cron.catch_up_missed, terminal.backend: untouched; terminal toolset is off via disabled_toolsets).
# REWORK notes
# $HERMES_HOME/work (mode 700): work/ created in H2b (T-409); the only path the hook lets write_file/patch write; hook 555 live. All other HERMES_HOME paths (config.yaml, allowlist, SOUL.md, hooks/, skills/, memories/) are write-denied; skill writes and foreground memory writes apply directly (write_approval false; the hook does not cover skill_manage/memory); the exception is the automatic background reviewer's memory replace/remove, which tools/memory_tool.py:171-189 still stages regardless of write_approval (approve with /memory approve).
# Unhooked tools (matcher does not cover): skill_view, skill_manage, memory, session_search, todo, clarify. Their safety rests on the memory guard scanner (memory_tool_store.py:28-31; skills: skills.guard_agent_created), SOUL.md, the skills ledger and the dated backups (planned, not yet built), not on write_approval (false).
# Hook path-consistency (cwd-relative paths) assumes the terminal toolset stays off (terminal could change effective cwd/paths).
# hermes-up refuses unless the hook is in shell-hooks-allowlist.json (owner's one-time consent: running evidence/h2a/seed-hook-allowlist).
# HERMES_HOME = ~/claude-profiles/hermes/h1-home (owner 2026-10-12: no reinstall). The hook command path above is unchanged: the hook lives in hermes/bin, outside HERMES_HOME by design (hooks/ stays empty, R5).
curator.enabled           -> false   # ADD or edit (owner decision A, 2026-10-13): h2b-install.md has no curator line, so presence in the live file is UNVERIFIED; if a `curator:` section exists set `enabled: false`, else add `curator:` with `  enabled: false`; never a second copy. Default True: hermes_cli/config_defaults.py:1499; read: agent/curator.py:106-107. Owner applies it (mem M1), no agent does
