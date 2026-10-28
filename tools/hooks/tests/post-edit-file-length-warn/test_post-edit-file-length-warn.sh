#!/usr/bin/env bash
# tools/hooks/tests/post-edit-file-length-warn/test_post-edit-file-length-warn.sh — tests for
# tools/hooks/post-edit-file-length-warn.sh (PostToolUse(Write|Edit) global file-length warn).
# Hermetic: every fixture file lives under a mktemp scratch dir; nothing in this repo or on the
# real filesystem is read or written other than that scratch dir. The hook's contract is the
# oracle: it ALWAYS exits 0, it is silent unless the written/edited file is over its limit (200
# lines, or 1000 for SKILL.md / SKILL-*.md), and when it does warn it emits both systemMessage
# and hookSpecificOutput.additionalContext naming the file, line count, and limit.
# Provenance: written 2026-10-28 alongside the hook's relocation from a local-only,
# non-version-controlled copy at ~/.claude/hooks/check-file-length.sh into this repo.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK="${POST_EDIT_FILE_LENGTH_WARN_UNDER_TEST:-${HERE}/../../post-edit-file-length-warn.sh}"
_tb="${TMPDIR:-/tmp}"; FX="$(mktemp -d "${_tb%/}/test_post-edit-file-length-warn.XXXXXX")" || { echo "FAIL: mktemp -d"; exit 1; }
trap 'rm -rf "$FX"' EXIT
passed=0; failed=0
pass() { echo "PASS: $1"; passed=$((passed + 1)); }
fail() { echo "FAIL: $1"; failed=$((failed + 1)); }
eq() { if [ "$2" = "$3" ]; then pass "$1"; else fail "$1 (got '$2', want '$3')"; fi; }
has() { case "$2" in *"$3"*) pass "$1" ;; *) fail "$1 (no '$3' in: $2)" ;; esac; }
silent() { if [ -z "$2" ]; then pass "$1"; else fail "$1 (expected no output, got: $2)"; fi; }
command -v jq >/dev/null || { echo "FAIL: jq required (the hook is silent without it, so nothing could be tested)"; exit 1; }

# mkfile <path> <line-count>: writes a file with exactly N lines.
mkfile() { [ "$2" -gt 0 ] && seq 1 "$2" >"$1" || : >"$1"; }

payload() { jq -cn --arg t "${2:-Write}" --arg f "$1" '{tool_name:$t, tool_input:{file_path:$f}}'; }
# run <payload> [VAR=val ...]: out = stdout, rc = exit code
run() { local p="$1"; shift; out="$(printf '%s' "$p" | env "$@" bash "$HOOK" 2>/dev/null)"; rc=$?; }

# 1. ordinary file, 201 lines -> warns, both JSON fields present, names file/lines/limit
F1="$FX/plain-over.txt"; mkfile "$F1" 201
run "$(payload "$F1")"
eq "201-line plain file: exit 0" "$rc" 0
has "201-line plain file: systemMessage present" "$out" '"systemMessage"'
has "201-line plain file: names the file" "$out" "$F1"
has "201-line plain file: names the line count" "$out" "201 lines"
has "201-line plain file: names the limit" "$out" "limit 200"
has "201-line plain file: hookEventName PostToolUse" "$out" '"hookEventName": "PostToolUse"'
has "201-line plain file: additionalContext present" "$out" "additionalContext"
eq "201-line plain file: valid JSON" "$(printf '%s' "$out" | jq -e . >/dev/null 2>&1; echo $?)" 0

# 2. ordinary file, exactly 200 lines (at the boundary, not over it) -> silent
F2="$FX/plain-at-limit.txt"; mkfile "$F2" 200
run "$(payload "$F2")"
eq "200-line plain file (at limit): exit 0" "$rc" 0
silent "200-line plain file (at limit): silent" "$out"

# 3. ordinary file, under the limit -> silent
F3="$FX/plain-under.txt"; mkfile "$F3" 50
run "$(payload "$F3")"
eq "50-line plain file: exit 0" "$rc" 0
silent "50-line plain file: silent" "$out"

# 4. SKILL.md between 200 and 1000 lines -> silent (exception case)
F4="$FX/SKILL.md"; mkfile "$F4" 500
run "$(payload "$F4")"
eq "500-line SKILL.md: exit 0" "$rc" 0
silent "500-line SKILL.md (under skill limit): silent" "$out"

# 5. SKILL-foo.md between 200 and 1000 lines -> silent (exception case, SKILL-*.md pattern)
F5="$FX/SKILL-foo.md"; mkfile "$F5" 900
run "$(payload "$F5")"
eq "900-line SKILL-foo.md: exit 0" "$rc" 0
silent "900-line SKILL-foo.md (under skill limit): silent" "$out"

# 6. SKILL.md over 1000 lines -> still warns, with the 1000 limit
F6="$FX/SKILL.md"; mkfile "$F6" 1001
run "$(payload "$F6")"
eq "1001-line SKILL.md: exit 0" "$rc" 0
has "1001-line SKILL.md: names the line count" "$out" "1001 lines"
has "1001-line SKILL.md: names the skill limit (1000)" "$out" "limit 1000"

# 7. silent/edge cases: all exit 0 with no output
run "$(payload "$FX/does-not-exist.txt")"; eq "nonexistent file: exit 0" "$rc" 0; silent "nonexistent file: silent" "$out"
run '{}'; eq "no file_path in payload: exit 0" "$rc" 0; silent "no file_path in payload: silent" "$out"
run ''; eq "empty payload: exit 0" "$rc" 0; silent "empty payload: silent" "$out"
run 'not json at all'; eq "invalid JSON payload: exit 0" "$rc" 0; silent "invalid JSON payload: silent" "$out"
run "$(payload "$F1")" JQ=/nonexistent; eq "jq unavailable: exit 0" "$rc" 0; silent "jq unavailable: silent" "$out"

# 8. static properties of the script itself
if grep -nE '^[[:space:]]*set[[:space:]]+-[A-Za-z]*e' "$HOOK" >/dev/null; then fail "hook must never use set -e"; else pass "hook does not use set -e"; fi
bash -n "$HOOK" && pass "bash -n clean" || fail "bash -n failed"

echo "=== post-edit-file-length-warn: $passed passed, $failed failed ==="; [ "$failed" = 0 ]
