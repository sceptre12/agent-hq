#!/bin/bash
# tools/hooks/post-edit-file-length-warn.sh — PostToolUse(Write|Edit) global file-length warn.
#
# WHY THIS EXISTS: enforces the global CLAUDE.md file-length rule (~/.claude/CLAUDE.md, "Global
# File Rules") on every Write/Edit across every project, not just this repo: 200 lines normally,
# 1000 for SKILL.md / SKILL-*.md. WARNS ONLY, never blocks — a PostToolUse hook's exit code
# cannot un-write a file that already landed, so this script's only job is to surface the
# question (systemMessage + additionalContext); splitting or justifying an exception is left to
# the human/agent in the loop.
#
# NOT THE SAME SCRIPT AS tools/check-file-length.sh (ADR 0016's ~300-line hq *source*-file self-
# check, invoked from INVARIANTS.md). That script lints THIS repo's own source files against a
# repo-local convention and is run by hand/CI against a target dir. This one is a Claude Code
# hook wired globally in ~/.claude/settings.json, fires on every Write|Edit tool call in every
# project on this machine, and enforces the CLAUDE.md 200/1000-line rule instead. Deliberately
# named differently from that script so a grep for "check-file-length.sh" doesn't land on the
# wrong one.
#
# Provenance: relocated 2026-10-28 from a local-only, non-version-controlled copy at
# ~/.claude/hooks/check-file-length.sh (already built, tested, and proven to fire live before
# this move). Pure relocation — thresholds, warn-don't-block behavior, and the jq-built JSON
# shape are unchanged. ~/.claude/settings.json's hooks.PostToolUse entry (matcher "Write|Edit")
# must point its command at this path, not the old one — ~/.claude/settings.json is NOT a
# symlink into this repo on this machine (ADR 0027's symlink-install is not in effect here), so
# moving this file does not auto-wire it; the settings.json command has to be updated by hand.
#
# NEVER set -e. Every path that isn't the warning itself falls through to a 0 exit — a
# PostToolUse hook's exit code is not meant to gate anything here, and silence (no file_path, no
# such file, line count unavailable) is the correct response to anything this script can't read.
#
# ENV (test injection only)
#   JQ   default: jq (resolved via PATH)

JQ="${JQ:-jq}"

input=$(cat)
f=$(echo "$input" | "$JQ" -r '.tool_input.file_path // empty' 2>/dev/null)
[ -z "$f" ] && exit 0
[ -f "$f" ] || exit 0

base=$(basename "$f")
case "$base" in
  SKILL.md|SKILL-*.md) limit=1000 ;;
  *) limit=200 ;;
esac

lines=$(wc -l < "$f" 2>/dev/null | tr -d ' ')
[ -z "$lines" ] && exit 0

if [ "$lines" -gt "$limit" ]; then
  "$JQ" -n --arg f "$f" --arg lines "$lines" --arg limit "$limit" '
    {
      systemMessage: ("File " + $f + " now has " + $lines + " lines (limit " + $limit + "). Per the global file-length rule in CLAUDE.md, split it into sub-files, or state explicitly that this is a legitimate exception (test file, skill file, dashboard HTML, or a repo-specific ratified override)."),
      hookSpecificOutput: {
        hookEventName: "PostToolUse",
        additionalContext: ("REMINDER: " + $f + " is now " + $lines + " lines, over the " + $limit + "-line global file-length limit. Split it per CLAUDE.md instructions, or explicitly confirm and state why this specific case is an allowed exception before continuing.")
      }
    }'
fi

exit 0
