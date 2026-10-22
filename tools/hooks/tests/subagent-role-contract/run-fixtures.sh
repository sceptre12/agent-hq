#!/usr/bin/env bash
# tools/hooks/tests/subagent-role-contract/run-fixtures.sh — fixture runner for the ADR 0043 hooks
# (architecture/subagent-role-contract.md, "Verification protocol" V1). Pipes each fixture (stdin
# JSON derived from the real S0 payloads) into the real scripts and asserts the documented
# expectation. Prints PASS/FAIL per check and a final line `FIXTURES: PASS` or `FIXTURES: FAIL`.
#
# Safe to run anywhere: logging is pointed at a mktemp scratch dir and HOME is redirected, so
# neither the real ~/.claude/logs nor any live config is touched.
#
# Divergence from the architecture text (ratification A7): the banner omits depth, so F8 checks
# depth on the NOTICE script (the caller's meta.json) and asserts the banner never carries depth.
#
# Usage: tools/hooks/tests/subagent-role-contract/run-fixtures.sh
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOKS="$(cd "${HERE}/../.." && pwd)"
BANNER="${HOOKS}/subagent-role-banner.sh"
NOTICE="${HOOKS}/agent-spawn-notice.sh"
JQ=/usr/bin/jq

WORK="$(mktemp -d "${TMPDIR:-/tmp}/role-contract-fixtures.XXXXXX")" || exit 1
trap 'rm -rf "${WORK}"' EXIT

passed=0
failed=0
pass() { echo "PASS: $1"; passed=$((passed + 1)); }
fail() { echo "FAIL: $1"; failed=$((failed + 1)); }
check() { # check <desc> <command...> — PASS when the command exits 0
  local d="$1"; shift
  if "$@" >/dev/null 2>&1; then pass "${d}"; else fail "${d}"; fi
}

ALL_STDOUT="${WORK}/all-stdout.txt"; : > "${ALL_STDOUT}"
SLOW=""

# run <script> <stdin-file> [VAR=val ...] -> sets RC, OUT (stdout file), SECS
run() {
  local script="$1" in="$2"; shift 2
  OUT="$(mktemp "${WORK}/out.XXXXXX")"
  local tfile="${WORK}/time.txt"
  env "$@" /usr/bin/time -p -o "${tfile}" "${script}" < "${in}" > "${OUT}" 2>/dev/null
  RC=$?
  SECS="$(awk '/^real/ {print $2}' "${tfile}")"
  cat "${OUT}" >> "${ALL_STDOUT}"
  if awk -v s="${SECS:-9}" 'BEGIN { exit !(s >= 1.0) }'; then SLOW="${SLOW} $(basename "${script}"):${SECS}"; fi
}
empty_out() { [ ! -s "$1" ]; }
loglines() { cat "$1"/*.jsonl 2>/dev/null | wc -l | tr -d ' '; }
newlog() { mktemp -d "${WORK}/log.XXXXXX"; }

# isolate <fixture> -> path of a copy whose transcript_path is nonexistent, so depth lookup never
# depends on this host (the real S0 session dir may still exist on disk).
isolate() { local o="${WORK}/iso-$(basename "$1")"; "${JQ}" --arg tp "${WORK}/none/session.jsonl" '.transcript_path = $tp' "$1" > "$o"; echo "$o"; }
# Placeholder-free HOME so the default log location can be observed without touching the real one.
FAKEHOME="${WORK}/home"; mkdir -p "${FAKEHOME}"

# ---- F1: main-thread PreToolUse (no agent_id) -> silent; nothing logged ----
LOG="$(newlog)"
run "${NOTICE}" "${HERE}/F1-main-pretooluse.json" AGENT_SPAWN_NOTICE_LOG_DIR="${LOG}" HOME="${FAKEHOME}"
[ "${RC}" -eq 0 ] && pass "F1 exit 0" || fail "F1 exit ${RC}"
empty_out "${OUT}" && pass "F1 empty stdout" || fail "F1 stdout not empty"
[ "$(loglines "${LOG}")" -eq 0 ] && pass "F1 log dir unchanged" || fail "F1 wrote a log line"

# ---- F2: subagent, no marker -> notice, +1 log line, reason null ----
LOG="$(newlog)"
run "${NOTICE}" "$(isolate "${HERE}/F2-sub-pretooluse-no-marker.json")" AGENT_SPAWN_NOTICE_LOG_DIR="${LOG}" HOME="${FAKEHOME}"
[ "${RC}" -eq 0 ] && pass "F2 exit 0" || fail "F2 exit ${RC}"
check "F2 hookEventName PreToolUse" "${JQ}" -e '.hookSpecificOutput.hookEventName == "PreToolUse"' "${OUT}"
check "F2 notice names caller type and id" "${JQ}" -e '.hookSpecificOutput.additionalContext | contains("type general-purpose, id a2126c93e3eb73613")' "${OUT}"
check "F2 notice has no depth (meta.json unreadable)" "${JQ}" -e '.hookSpecificOutput.additionalContext | contains("depth") | not' "${OUT}"
check "F2 permissionDecision allow only" "${JQ}" -e '.hookSpecificOutput.permissionDecision == "allow" and (.hookSpecificOutput | has("permissionDecisionReason") | not)' "${OUT}"
[ "$(loglines "${LOG}")" -eq 1 ] && pass "F2 log +1 line" || fail "F2 log lines = $(loglines "${LOG}")"
check "F2 log schema: reason/subagent_type/depth null, ids set" "${JQ}" -se '
  length == 1 and (.[0] | .reason == null and .child_subagent_type == null and .parent_spawn_depth == null
  and .parent_agent_id == "a2126c93e3eb73613" and .parent_agent_type == "general-purpose"
  and .session_id == "34f87b6f-c3f7-4bdd-b0b6-7b227cc15917" and (.child_description | length > 0)
  and (.ts | test("^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:]{8}Z$")))' "${LOG}"/*.jsonl
F2LOG="${LOG}"

# ---- default off: unset and empty AGENT_SPAWN_NOTICE_LOG_DIR write nothing anywhere ----
run "${NOTICE}" "$(isolate "${HERE}/F2-sub-pretooluse-no-marker.json")" HOME="${FAKEHOME}"
check "DEFAULT-OFF (unset) notice still emitted" "${JQ}" -e '.hookSpecificOutput.hookEventName == "PreToolUse"' "${OUT}"
run "${NOTICE}" "$(isolate "${HERE}/F2-sub-pretooluse-no-marker.json")" AGENT_SPAWN_NOTICE_LOG_DIR= HOME="${FAKEHOME}"
check "DEFAULT-OFF (empty) notice still emitted" "${JQ}" -e '.hookSpecificOutput.hookEventName == "PreToolUse"' "${OUT}"
[ ! -e "${FAKEHOME}/.claude" ] && pass "DEFAULT-OFF no ~/.claude/logs created" || fail "DEFAULT-OFF created ${FAKEHOME}/.claude"

# ---- F3: indented / lower-case / mid-line marker -> reason null ----
LOG="$(newlog)"
run "${NOTICE}" "$(isolate "${HERE}/F3-sub-pretooluse-bad-marker.json")" AGENT_SPAWN_NOTICE_LOG_DIR="${LOG}"
check "F3 notice emitted" "${JQ}" -e '.hookSpecificOutput.hookEventName == "PreToolUse"' "${OUT}"
[ "$(loglines "${LOG}")" -eq 1 ] && pass "F3 log +1 line" || fail "F3 log lines"
check "F3 reason null" "${JQ}" -se '.[0].reason == null' "${LOG}"/*.jsonl

# ---- F4: valid marker -> trimmed reason; subagent_type present ----
LOG="$(newlog)"
run "${NOTICE}" "$(isolate "${HERE}/F4-sub-pretooluse-valid-marker.json")" AGENT_SPAWN_NOTICE_LOG_DIR="${LOG}"
check "F4 notice emitted" "${JQ}" -e '.hookSpecificOutput.hookEventName == "PreToolUse"' "${OUT}"
check "F4 reason trimmed, subagent_type recorded" "${JQ}" -se '.[0].reason == "needs a separate context window" and .[0].child_subagent_type == "general-purpose"' "${LOG}"/*.jsonl
# (child_subagent_type null when absent is asserted in F2)

# ---- F5: empty and malformed stdin -> exit 0, empty stdout (both scripts) ----
for s in "${BANNER}" "${NOTICE}"; do
  for f in F5-empty.txt F5-malformed.txt; do
    LOG="$(newlog)"
    run "${s}" "${HERE}/${f}" AGENT_SPAWN_NOTICE_LOG_DIR="${LOG}"
    if [ "${RC}" -eq 0 ] && empty_out "${OUT}" && [ "$(loglines "${LOG}")" -eq 0 ]; then pass "F5 $(basename "${s}") ${f}"; else fail "F5 $(basename "${s}") ${f} (rc=${RC})"; fi
  done
done

# ---- F6: jq unavailable -> exit 0, empty stdout (both scripts, real payloads) ----
run "${BANNER}" "${HERE}/B1-subagentstart.json" JQ=/nonexistent
[ "${RC}" -eq 0 ] && empty_out "${OUT}" && pass "F6 banner JQ=/nonexistent" || fail "F6 banner JQ=/nonexistent"
LOG="$(newlog)"
run "${NOTICE}" "$(isolate "${HERE}/F2-sub-pretooluse-no-marker.json")" JQ=/nonexistent AGENT_SPAWN_NOTICE_LOG_DIR="${LOG}"
[ "${RC}" -eq 0 ] && empty_out "${OUT}" && [ "$(loglines "${LOG}")" -eq 0 ] && pass "F6 notice JQ=/nonexistent" || fail "F6 notice JQ=/nonexistent"

# ---- F7: seeded 100-line log -> no append, notice still emitted ----
LOG="$(newlog)"
for i in $(seq 1 100); do echo "{\"seed\":${i}}"; done > "${LOG}/34f87b6f-c3f7-4bdd-b0b6-7b227cc15917.jsonl"
run "${NOTICE}" "$(isolate "${HERE}/F2-sub-pretooluse-no-marker.json")" AGENT_SPAWN_NOTICE_LOG_DIR="${LOG}"
check "F7 notice emitted at cap" "${JQ}" -e '.hookSpecificOutput.hookEventName == "PreToolUse"' "${OUT}"
[ "$(loglines "${LOG}")" -eq 100 ] && pass "F7 no append at 100 lines" || fail "F7 lines = $(loglines "${LOG}")"
LOG="$(newlog)"
for i in $(seq 1 99); do echo "{\"seed\":${i}}"; done > "${LOG}/34f87b6f-c3f7-4bdd-b0b6-7b227cc15917.jsonl"
run "${NOTICE}" "$(isolate "${HERE}/F2-sub-pretooluse-no-marker.json")" AGENT_SPAWN_NOTICE_LOG_DIR="${LOG}"
[ "$(loglines "${LOG}")" -eq 100 ] && pass "F7 control: append at 99 lines" || fail "F7 control lines = $(loglines "${LOG}")"

# ---- F8: depth. Notice reads the CALLER's meta.json; banner never carries depth (A7) ----
TD="${WORK}/transcripts"; mkdir -p "${TD}/sess/subagents"
cp "${HERE}/F8-meta-caller-depth1.json" "${TD}/sess/subagents/agent-a2126c93e3eb73613.meta.json"
"${JQ}" --arg tp "${TD}/sess.jsonl" '.transcript_path = $tp' "${HERE}/F2-sub-pretooluse-no-marker.json" > "${WORK}/F8-notice.json"
"${JQ}" --arg tp "${TD}/sess.jsonl" '.transcript_path = $tp' "${HERE}/B1-subagentstart.json" > "${WORK}/F8-banner.json"
LOG="$(newlog)"
run "${NOTICE}" "${WORK}/F8-notice.json" AGENT_SPAWN_NOTICE_LOG_DIR="${LOG}"
check "F8 notice with meta.json contains depth 1" "${JQ}" -e '.hookSpecificOutput.additionalContext | contains("id a2126c93e3eb73613, depth 1)")' "${OUT}"
check "F8 log parent_spawn_depth = 1" "${JQ}" -se '.[0].parent_spawn_depth == 1' "${LOG}"/*.jsonl
run "${BANNER}" "${WORK}/F8-banner.json"
check "F8 banner with meta.json present still omits depth (A7)" "${JQ}" -e '.hookSpecificOutput.additionalContext | contains("depth") | not' "${OUT}"
echo '{"spawnDepth":"x"}' > "${TD}/sess/subagents/agent-a2126c93e3eb73613.meta.json"
run "${NOTICE}" "${WORK}/F8-notice.json"
check "F8 non-integer spawnDepth -> depth omitted" "${JQ}" -e '.hookSpecificOutput.additionalContext | contains("depth") | not' "${OUT}"

# ---- Banner fixtures ----
run "${BANNER}" "${HERE}/B1-subagentstart.json"
[ "${RC}" -eq 0 ] && pass "B1 banner exit 0" || fail "B1 exit ${RC}"
check "B1 hookEventName SubagentStart" "${JQ}" -e '.hookSpecificOutput.hookEventName == "SubagentStart"' "${OUT}"
check "B1 banner names type and id, starts SUBAGENT ROLE (hq ADR 0043)" "${JQ}" -e '.hookSpecificOutput.additionalContext | startswith("SUBAGENT ROLE (hq ADR 0043): You are a subagent") and contains("type `general-purpose`, id `a2126c93e3eb73613`")' "${OUT}"
check "B1 banner has orchestrator/worker text, no depth" "${JQ}" -e '.hookSpecificOutput.additionalContext | contains("the worker, not the orchestrator") and contains("Rules 1, 3 and 4 still apply to you.") and (contains("depth") | not)' "${OUT}"
check "B1 stdout is exactly one JSON object" "${JQ}" -se 'length == 1' "${OUT}"
run "${BANNER}" "${HERE}/B2-subagentstart-no-agent-id.json"
[ "${RC}" -eq 0 ] && empty_out "${OUT}" && pass "B2 no agent_id -> silent" || fail "B2 no agent_id"
run "${BANNER}" "${HERE}/B3-subagentstart-no-agent-type.json"
check "B3 missing agent_type -> unknown, banner emitted" "${JQ}" -e '.hookSpecificOutput.additionalContext | contains("type `unknown`")' "${OUT}"
run "${BANNER}" "${HERE}/B4-subagentstart-weird-type.json"
check "B4 quotes/backticks/backslash in agent_type -> valid JSON, round-trips" "${JQ}" -e --arg t 'we"ird`type\x' '.hookSpecificOutput.additionalContext | contains("type `" + $t + "`")' "${OUT}"

# ---- F9: runtime under 1 s for every run above ----
[ -z "${SLOW}" ] && pass "F9 every run under 1 s" || fail "F9 slow runs:${SLOW}"

# ---- F10: no stdout anywhere contains deny/ask, or a permissionDecision other than allow ----
[ -s "${ALL_STDOUT}" ] || fail "F10 observed no stdout at all (vacuous)"
if command grep -Eq 'deny|"ask"|permissionDecisionReason' "${ALL_STDOUT}"; then fail "F10 deny/ask/reason found in stdout"; else pass "F10 no deny/ask/permissionDecisionReason in any stdout"; fi
bad="$("${JQ}" -c 'select(.hookSpecificOutput.permissionDecision != null and .hookSpecificOutput.permissionDecision != "allow")' "${ALL_STDOUT}" 2>/dev/null | wc -l | tr -d ' ')"
[ "${bad}" -eq 0 ] && pass "F10 every permissionDecision is allow" || fail "F10 ${bad} non-allow decisions"
[ -n "$(ls "${F2LOG}")" ] && pass "F10 control: positive log observed (F2)" || fail "F10 F2 wrote no log (vacuous)"
# Script-text invariants (V0): no errexit, no deny/ask path in either script.
if command grep -Eq 'set -e|"deny"|"ask"|permissionDecisionReason' "${BANNER}" "${NOTICE}"; then fail "V0 forbidden token in a script"; else pass "V0 no errexit / deny / ask / reason token in either script"; fi

echo "passed=${passed} failed=${failed}"
if [ "${failed}" -eq 0 ]; then echo "FIXTURES: PASS"; exit 0; else echo "FIXTURES: FAIL"; exit 1; fi
