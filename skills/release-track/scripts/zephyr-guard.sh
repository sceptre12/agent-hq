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
#          tool_input.method (string), optional tool_input.path (string) and tool_input.params (flat object of
#          scalars). An input without operation/method, with any other tool_input key, with a non-scalar value
#          or with a non-ASCII character is refused (fail closed). P0 replaces the key set with the measured one.
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
# ASSUMPTION UNTIL P0: the closed tool_input key set KEYS below (operation, method required; path, params
# optional). Until P0 measures the real shape, any key outside KEYS is an open bypass, so it is refused.
# Exit: 0 ok; 1 unparsable or wrong tool / missing field; 3 key outside KEYS or non-scalar value; 4 non-ASCII.
extract_call() {
  python3 -I -c '
import json, sys
tool = sys.argv[1]
KEYS = {"operation", "method", "path", "params"}   # ASSUMPTION UNTIL P0 (closed set)
SCALAR = (str, int, float, bool, type(None))
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
    if set(ti) - KEYS:
        sys.exit(3)
    if "path" in ti and not isinstance(ti["path"], str):
        sys.exit(3)
    if "params" in ti and (not isinstance(ti["params"], dict)
                           or not all(isinstance(v, SCALAR) for v in ti["params"].values())):
        sys.exit(3)
    if any(ord(c) > 127 for c in json.dumps(ti, ensure_ascii=False)):
        sys.exit(4)
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
# read_ops counts only as a direct child of the top-level zephyr: key (the first child line's indent);
# a nested read_ops is ignored. Ambiguity (two top-level zephyr: keys or two direct read_ops keys) exits 3.
read_ops_list() {
  awk '
    function clean(s) { sub(/[[:space:]]+#.*$/, "", s); gsub(/^[[:space:]]+|[[:space:]]+$/, "", s)
      gsub(/^["\047]|["\047]$/, "", s); return s }
    function ind(s) { match(s, /[^ \t]/); return RSTART - 1 }
    BEGIN { zc = 0; rc = 0 }
    /^[^[:space:]#]/ { inz = ($(0) ~ /^zephyr:[[:space:]]*(#.*)?$/); if (inz) zc++; inl = 0; cind = -1; next }
    !inz { next }
    /^[[:space:]]*(#.*)?$/ { next }
    cind < 0 { cind = ind($(0)) }
    ind($(0)) == cind && /^[[:space:]]+read_ops:/ {
      rc++; inl = 0; r = $(0); sub(/^[[:space:]]+read_ops:[[:space:]]*/, "", r)
      if (r ~ /^\[/) { sub(/^\[/, "", r); sub(/\].*$/, "", r); n = split(r, a, ",")
        for (i = 1; i <= n; i++) { v = clean(a[i]); if (v != "") print v } }
      else { inl = 1 }
      next }
    inl && /^[[:space:]]*-[[:space:]]+/ { r = $(0); sub(/^[[:space:]]*-[[:space:]]+/, "", r); v = clean(r); if (v != "") print v; next }
    inl { inl = 0 }
    END { if (zc > 1 || rc > 1) exit 3 }
  ' "${1}"
}

[ -n "${TOOL}" ] || refuse "no execute-tool name given"
[ -n "${PROFILE}" ] || refuse "no profile path given"
case "${PROFILE}" in *@????????????????????????????????????????) [ -f "${PROFILE}" ] || PROFILE="${PROFILE%@*}" ;; esac
[ -f "${PROFILE}" ] && [ -r "${PROFILE}" ] || refuse "profile missing or unreadable"
command -v python3 >/dev/null 2>&1 || refuse "python3 unavailable"

INPUT="$(cat 2>/dev/null)" || refuse "stdin unreadable"
[ -n "${INPUT}" ] || refuse "empty stdin"
CALL="$(printf '%s' "${INPUT}" | extract_call)"; XRC=$?
case "${XRC}" in
  0) ;;
  3) refuse "tool_input key outside the closed set or non-scalar value (assumption until P0)" ;;
  4) refuse "non-ASCII character in tool_input" ;;
  *) refuse "unparsable input or unknown tool shape" ;;
esac
OP="$(printf '%s\n' "${CALL}" | sed -n 1p)"
METHOD="$(printf '%s\n' "${CALL}" | sed -n 2p)"
TEXT="$(printf '%s\n' "${CALL}" | sed -n 3p)"
[ -n "${OP}" ] || refuse "empty operation"

OPS="$(read_ops_list "${PROFILE}")" || refuse "profile unparsable or zephyr.read_ops ambiguous"
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
