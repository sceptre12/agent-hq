#!/usr/bin/env bash
# tools/hooks/agent-spawn-notice.sh — PreToolUse(Agent) nesting notice (hq ADR 0043, layer L3).
#
# WHY THIS EXISTS: nested subagent spawns stay fully allowed; this hook only makes them visible.
# When the caller is itself a subagent (payload has `agent_id`), it adds a one-line notice to the
# caller's context. Design record: architecture/subagent-role-contract.md (component C2/C5).
# Owner ruling 2026-10-02: awareness only, nothing restricts a spawn.
#
# ALWAYS ALLOWS. There is no path that blocks, prompts, or explains a refusal: output is only
# additionalContext plus permissionDecision "allow" (the shape S0 measured as delivered), and
# every path ends in exit 0. A non-zero PreToolUse exit would block unconditionally (precedent:
# tools/hooks/port-precheck.sh header), so this script never uses errexit mode and never fails
# closed. Main-thread payloads (no `agent_id`), empty or malformed stdin, and any jq failure
# produce no output.
#
# DEPTH (best-effort): the caller's meta.json at
#   "${transcript_path%.jsonl}/subagents/agent-${agent_id}.meta.json"  (.spawnDepth, integer)
# If unreadable or not an integer, depth is omitted from the text and null in the log.
#
# C5 SPAWN LOG — S1: default off pending N4. The owner has not yet agreed to a new state file
# (ratification item N4; memory no-large-state-log-files), so NOTHING IS WRITTEN unless
# AGENT_SPAWN_NOTICE_LOG_DIR is set and non-empty. When set: one compact JSON line per nested
# spawn appended to "${AGENT_SPAWN_NOTICE_LOG_DIR}/<session_id>.jsonl" (session_id filtered to
# [A-Za-z0-9-], empty -> unknown-session), at most MAX_LINES lines per file, string fields cut
# to MAX_FIELD chars, files older than PRUNE_DAYS days pruned on append. Cap check is not atomic
# (benign overshoot by a few lines under concurrency).
#
# OUTPUT IS BUILT BY jq, NEVER printf. `command grep` is not needed here; no grep is used.
#
# ENV (test injection only)
#   JQ                          default: /usr/bin/jq
#   AGENT_SPAWN_NOTICE_LOG_DIR  unset/empty = no logging (the default)

JQ="${JQ:-/usr/bin/jq}"
MAX_LINES=100
MAX_FIELD=240
PRUNE_DAYS=14

# Caller's spawn depth from its meta.json; prints an integer or nothing.
caller_depth() {
  local tp="$1" id="$2" meta
  [ -n "${tp}" ] && [ -n "${id}" ] || return 0
  meta="${tp%.jsonl}/subagents/agent-${id}.meta.json"
  [ -r "${meta}" ] || return 0
  "${JQ}" -r 'if (.spawnDepth | type) == "number" and (.spawnDepth == (.spawnDepth | floor)) then (.spawnDepth | tostring) else empty end' "${meta}" 2>/dev/null
  return 0
}

# append_log <payload> <agent_id> <agent_type> <depth-or-empty>  (never fails the caller)
append_log() {
  local payload="$1" aid="$2" atype="$3" depth="$4"
  local dir="${AGENT_SPAWN_NOTICE_LOG_DIR}" sid file lines ts depth_json line
  sid="$(printf '%s' "${payload}" | "${JQ}" -r '.session_id // empty | tostring' 2>/dev/null | tr -cd 'A-Za-z0-9-')"
  [ -n "${sid}" ] || sid="unknown-session"
  mkdir -p "${dir}" 2>/dev/null || return 0
  file="${dir}/${sid}.jsonl"
  lines=0
  [ -f "${file}" ] && lines="$(wc -l < "${file}" 2>/dev/null | tr -d ' ')"
  case "${lines}" in ''|*[!0-9]*) lines=0 ;; esac
  [ "${lines}" -lt "${MAX_LINES}" ] || return 0
  ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  depth_json="null"
  [ -n "${depth}" ] && depth_json="${depth}"
  line="$(printf '%s' "${payload}" | "${JQ}" -c \
    --arg ts "${ts}" --arg sid "${sid}" --arg aid "${aid}" --arg atype "${atype}" \
    --argjson depth "${depth_json}" --argjson max "${MAX_FIELD}" '
    def cut: if . == null then null else tostring | .[0:$max] end;
    {ts: $ts, session_id: $sid, parent_agent_id: $aid, parent_agent_type: $atype,
     parent_spawn_depth: $depth,
     child_subagent_type: ((.tool_input.subagent_type // null) | cut),
     child_description: ((.tool_input.description // null) | cut),
     reason: (((.tool_input.prompt // "") | tostring | split("\n")
               | map(select(startswith("NESTING-REASON:"))) | first // null
               | if . == null then null else (ltrimstr("NESTING-REASON:") | gsub("^\\s+|\\s+$"; "")) end) | cut)}
    ' 2>/dev/null)" || return 0
  [ -n "${line}" ] || return 0
  printf '%s\n' "${line}" >> "${file}" 2>/dev/null || return 0
  find "${dir}" -name '*.jsonl' -mtime +"${PRUNE_DAYS}" -delete 2>/dev/null
  return 0
}

main() {
  local payload aid atype tp depth text out
  payload="$(cat)" || return 0
  [ -n "${payload}" ] || return 0

  aid="$(printf '%s' "${payload}" | "${JQ}" -r '.agent_id // empty | tostring' 2>/dev/null)" || return 0
  [ -n "${aid}" ] || return 0
  atype="$(printf '%s' "${payload}" | "${JQ}" -r '.agent_type // empty | tostring' 2>/dev/null)" || atype=""
  [ -n "${atype}" ] || atype="unknown"
  tp="$(printf '%s' "${payload}" | "${JQ}" -r '.transcript_path // empty | tostring' 2>/dev/null)" || tp=""
  depth="$(caller_depth "${tp}" "${aid}")"

  out="$("${JQ}" -nc --arg t "${atype}" --arg i "${aid}" --arg d "${depth}" '
    {hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "allow",
      additionalContext: ("agent-spawn-notice (hq ADR 0043): you are a subagent (type " + $t + ", id " + $i
        + (if $d == "" then "" else ", depth " + $d end)
        + ") spawning a nested child; the child will receive its own SUBAGENT ROLE banner.")
    }}' 2>/dev/null)" || return 0
  [ -n "${out}" ] || return 0
  printf '%s\n' "${out}"

  if [ -n "${AGENT_SPAWN_NOTICE_LOG_DIR:-}" ]; then
    append_log "${payload}" "${aid}" "${atype}" "${depth}"
  fi
  return 0
}

main
exit 0
