#!/usr/bin/env bash
# skills/release-track/scripts/zephyr-guard.sh — PreToolUse hook for the Zephyr MCP `execute` tool.
# Allows exactly the operations listed in the repo profile's zephyr.read_ops; every other call exits 2.
# Only exit code 2 blocks a tool call; this hook never asks (ask stalls unattended runs) and never calls
# the network. It shares no state or script with the port-precheck hook.
#
# Usage:   zephyr-guard.sh <profile-path> <execute-tool-name> [refusal-log]   (PreToolUse JSON on stdin)
# Env:     ZEPHYR_PROFILE, ZEPHYR_TOOL, ZEPHYR_REFUSAL_LOG stand in for the arguments;
#          the log defaults to ${RUN_HOME}/pm/zephyr-refusals.log. The tool name is a parameter,
#          never hard-coded (profile key zephyr.execute_tool, unmeasured, verify at move).
# Input shape: ASSUMPTION UNTIL P0 (one function, extract_call): tool_name, tool_input.operation (string),
#          tool_input.method (string). An input without those fields is refused (fail closed).
# Exit:    0 allow; 2 refuse (one reason line on stderr, one line appended to the refusal log).
set -u

DONE=refuse
trap '[ "${DONE}" = ok ] || exit 2' EXIT   # any unexpected exit path (error, signal-free abort) blocks

PROFILE="${1:-${ZEPHYR_PROFILE:-}}"
TOOL="${2:-${ZEPHYR_TOOL:-}}"
LOG="${3:-${ZEPHYR_REFUSAL_LOG:-}}"
if [ -z "${LOG}" ] && [ -n "${RUN_HOME:-}" ]; then LOG="${RUN_HOME}/pm/zephyr-refusals.log"; fi

OP="-"
refuse() { # refuse <reason> — log (best effort), one stderr line, exit 2
  local reason="${1}" ts t o
  ts="$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo unknown-time)"
  t="$(printf '%s' "${TOOL:--}" | tr -c 'A-Za-z0-9_.:-' '_' | cut -c1-120)"
  o="$(printf '%s' "${OP}" | tr -c 'A-Za-z0-9_.:/{}-' '_' | cut -c1-120)"
  [ -n "${o}" ] || o="-"
  if [ -n "${LOG}" ]; then
    { mkdir -p "$(dirname "${LOG}")" && printf '%s %s %s %s\n' "${ts}" "${t:--}" "${o}" "${reason}" >>"${LOG}"; } 2>/dev/null || true
  fi
  echo "zephyr-guard: refused ${o}: ${reason}" >&2
  exit 2
}

# extract_call: stdin JSON -> three lines: operation, method, lowercase flattened tool_input text.
# ASSUMPTION UNTIL P0: field names operation/method. Non-string fields or a wrong tool_name print nothing.
extract_call() {
  python3 -I -c '
import json, sys
tool = sys.argv[1]
try:
    d = json.loads(sys.stdin.read())
    if not isinstance(d, dict) or d.get("tool_name") != tool:
        sys.exit(1)
    ti = d.get("tool_input")
    if not isinstance(ti, dict):
        sys.exit(1)
    op, me = ti.get("operation"), ti.get("method")
    if not isinstance(op, str) or not isinstance(me, str):
        sys.exit(1)
    flat = json.dumps(ti, sort_keys=True).lower()
    for s in (op, me, flat):
        print(s.replace("\n", " ").replace("\r", " "))
except SystemExit:
    raise
except Exception:
    sys.exit(1)
' "${TOOL}" 2>/dev/null
}

# read_ops_list: print zephyr.read_ops entries one per line (block list or inline [a, b]).
read_ops_list() {
  awk '
    function clean(s) { sub(/[[:space:]]+#.*$/, "", s); gsub(/^[[:space:]]+|[[:space:]]+$/, "", s)
      gsub(/^["\047]|["\047]$/, "", s); return s }
    /^[^[:space:]#]/ { inz = ($(0) ~ /^zephyr:[[:space:]]*(#.*)?$/); inl = 0; next }
    inz && /^[[:space:]]+read_ops:/ {
      r = $(0); sub(/^[[:space:]]+read_ops:[[:space:]]*/, "", r)
      if (r ~ /^\[/) { sub(/^\[/, "", r); sub(/\].*$/, "", r); n = split(r, a, ",")
        for (i = 1; i <= n; i++) { v = clean(a[i]); if (v != "") print v } }
      else { inl = 1 }
      next }
    inz && inl && /^[[:space:]]*-[[:space:]]+/ { r = $(0); sub(/^[[:space:]]*-[[:space:]]+/, "", r); v = clean(r); if (v != "") print v; next }
    inz && inl && /^[[:space:]]*(#.*)?$/ { next }
    inz && inl { inl = 0 }
  ' "${1}"
}

[ -n "${TOOL}" ] || refuse "no execute-tool name given"
[ -n "${PROFILE}" ] || refuse "no profile path given"
case "${PROFILE}" in *@????????????????????????????????????????) [ -f "${PROFILE}" ] || PROFILE="${PROFILE%@*}" ;; esac
[ -f "${PROFILE}" ] && [ -r "${PROFILE}" ] || refuse "profile missing or unreadable"
command -v python3 >/dev/null 2>&1 || refuse "python3 unavailable"

INPUT="$(cat 2>/dev/null)" || refuse "stdin unreadable"
[ -n "${INPUT}" ] || refuse "empty stdin"
CALL="$(printf '%s' "${INPUT}" | extract_call)" || refuse "unparsable input or unknown tool shape"
OP="$(printf '%s\n' "${CALL}" | sed -n 1p)"
METHOD="$(printf '%s\n' "${CALL}" | sed -n 2p)"
TEXT="$(printf '%s\n' "${CALL}" | sed -n 3p)"
[ -n "${OP}" ] || refuse "empty operation"

OPS="$(read_ops_list "${PROFILE}")" || refuse "profile unparsable"
[ -n "${OPS}" ] || refuse "zephyr.read_ops missing or empty"

# Second check first: non-GET, or any mention of deploy/promote/rollback, is refused even if allowlisted.
METHOD_UC="$(printf '%s' "${METHOD}" | tr '[:lower:]' '[:upper:]')"
[ "${METHOD_UC}" = "GET" ] || refuse "method is not GET"
case "${TEXT}" in *deploy*|*promote*|*rollback*) refuse "call names deploy, promote or rollback" ;; esac

FOUND=no
while IFS= read -r entry; do
  if [ "${entry}" = "${OP}" ]; then FOUND=yes; break; fi
done <<EOT
${OPS}
EOT
[ "${FOUND}" = yes ] || refuse "operation not in zephyr.read_ops"

DONE=ok
exit 0
