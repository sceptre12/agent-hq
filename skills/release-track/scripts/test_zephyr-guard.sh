#!/usr/bin/env bash
# skills/release-track/scripts/test_zephyr-guard.sh — tests for zephyr-guard.sh and check-zephyr-disallowed.sh.
# Hermetic: fixtures under a mktemp dir. Every tool name, operation name and input field below is a FIXTURE
# (assumption until P0: the real execute tool name, operation ids and input shape are unmeasured, verify at move).
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GUARD="${ZEPHYR_GUARD_UNDER_TEST:-${HERE}/zephyr-guard.sh}"
CHECK="${ZEPHYR_CHECK_UNDER_TEST:-${HERE}/check-zephyr-disallowed.sh}"
ROOT="$(mktemp -d "${TMPDIR:-/tmp}/test_zephyr-guard.XXXXXX")" || { echo "FAIL: mktemp -d"; exit 1; }
trap 'rm -rf "${ROOT}"' EXIT
passed=0; failed=0
pass() { echo "PASS: ${1}"; passed=$((passed + 1)); }
fail() { echo "FAIL: ${1}"; failed=$((failed + 1)); }
eq() { if [ "${2}" = "${3}" ]; then pass "${1}"; else fail "${1} (got '${2}', want '${3}')"; fi; }
has() { case "${2}" in *"${3}"*) pass "${1}" ;; *) fail "${1} (no '${3}' in: ${2})" ;; esac; }

TOOL="fixture__execute"   # FIXTURE tool name
LOG="${ROOT}/pm/zephyr-refusals.log"
P="${ROOT}/profile.md"
printf 'name: fixture\nzephyr:\n  execute_tool: %s\n  read_ops:\n    - get_versions   # fixture\n    - "get_history"\nnode:\n  x: 1\n' "${TOOL}" >"${P}"
call() { # call <profile> <json-on-stdin>; sets rc, err
  err="$(printf '%s' "${2}" | "${GUARD}" "${1}" "${TOOL}" "${LOG}" 2>&1 >/dev/null)"; rc=$?
}
j() { printf '{"tool_name":"%s","tool_input":{"operation":"%s","method":"%s"%s}}' "${TOOL}" "${1}" "${2}" "${3:-}"; }
loglines() { if [ -f "${LOG}" ]; then wc -l <"${LOG}" | tr -d ' '; else echo 0; fi; }

call "${P}" "$(j get_versions GET)"; eq "allowed read: exit 0" "${rc}" 0; eq "allowed read: no log line" "$(loglines)" 0
call "${P}" "$(j get_history get)"; eq "allowed read (quoted entry, lowercase method): exit 0" "${rc}" 0

call "${P}" "$(j list_secrets GET)"; eq "non-listed call: exit 2" "${rc}" 2; has "non-listed: reason on stderr" "${err}" "not in zephyr.read_ops"
eq "non-listed: one log line" "$(loglines)" 1
has "log line shape" "$(cat "${LOG}")" "${TOOL} list_secrets operation not in zephyr.read_ops"

call "${P}" "$(j get_versions POST)"; eq "allowlisted name with POST: exit 2" "${rc}" 2; has "POST reason" "${err}" "not GET"
call "${P}" "$(j get_versions GET ',"body":{"action":"promote"}')"; eq "allowlisted name with promote text: exit 2" "${rc}" 2
call "${P}" "$(j get_versions GET ',"path":"/x/Rollback"')"; eq "rollback text (case-insensitive): exit 2" "${rc}" 2
call "${P}" "$(j get_versions GET ',"path":"/x/DEPLOY"')"; eq "deploy text (case-insensitive): exit 2" "${rc}" 2
call "${P}" "$(j get_versions_then_promote GET)"; eq "lookalike op: exit 2" "${rc}" 2
call "${P}" "$(j get_version GET)"; eq "prefix of allowed op: exit 2" "${rc}" 2
call "${P}" "$(j 'Get_Versions' GET)"; eq "case-different op: exit 2" "${rc}" 2
call "${P}" "$(printf '{"tool_name":"other__tool","tool_input":{"operation":"get_versions","method":"GET"}}')"; eq "wrong tool name: exit 2" "${rc}" 2
call "${P}" "$(printf '{"tool_name":"%s","tool_input":{"operation":"get_versions"}}' "${TOOL}")"; eq "no method field: exit 2" "${rc}" 2
call "${P}" "$(printf '{"tool_name":"%s","tool_input":{"method":"GET"}}' "${TOOL}")"; eq "no operation field: exit 2" "${rc}" 2
call "${P}" "$(printf '{"tool_name":"%s","tool_input":{"operation":["get_versions"],"method":"GET"}}' "${TOOL}")"; eq "non-string operation: exit 2" "${rc}" 2
call "${P}" '{"tool_name":'; eq "malformed JSON: exit 2" "${rc}" 2
call "${P}" ''; eq "empty stdin: exit 2" "${rc}" 2; has "empty stdin reason" "${err}" "empty stdin"
call "${P}" '[1,2]'; eq "JSON array: exit 2" "${rc}" 2

E="${ROOT}/empty.md"; printf 'zephyr:\n  read_ops: []\n' >"${E}"
call "${E}" "$(j get_versions GET)"; eq "empty inline list: exit 2" "${rc}" 2
E2="${ROOT}/empty2.md"; printf 'zephyr:\n  read_ops:\nnode:\n  - get_versions\n' >"${E2}"
call "${E2}" "$(j get_versions GET)"; eq "empty block list (item belongs to another key): exit 2" "${rc}" 2
N="${ROOT}/nokey.md"; printf 'name: x\nread_ops:\n  - get_versions\n' >"${N}"
call "${N}" "$(j get_versions GET)"; eq "read_ops outside zephyr: exit 2" "${rc}" 2
call "${ROOT}/missing.md" "$(j get_versions GET)"; eq "missing profile: exit 2" "${rc}" 2; has "missing profile reason" "${err}" "profile missing"
I="${ROOT}/inline.md"; printf 'zephyr:\n  read_ops: [get_versions, "get_history"]\n' >"${I}"
call "${I}" "$(j get_history GET)"; eq "inline list: allowed" "${rc}" 0
call "${I}" "$(j get_other GET)"; eq "inline list: other refused" "${rc}" 2
call "${P}@0123456789012345678901234567890123456789" "$(j get_versions GET)"; eq "profile path with @sha suffix resolves" "${rc}" 0

out="$(printf '%s' "$(j get_versions GET)" | "${GUARD}" "${P}" 2>&1 >/dev/null)"; rc=$?; eq "no tool name: exit 2" "${rc}" 2
out="$(printf '%s' "$(j get_versions GET)" | "${GUARD}" 2>&1 >/dev/null)"; rc=$?; eq "no arguments: exit 2" "${rc}" 2
out="$(printf '%s' "$(j get_versions GET)" | ZEPHYR_PROFILE="${P}" ZEPHYR_TOOL="${TOOL}" "${GUARD}" 2>&1 >/dev/null)"; rc=$?; eq "env-provided profile and tool: exit 0" "${rc}" 0
n0="$(loglines)"
out="$(printf '%s' "$(j bad GET)" | RUN_HOME="${ROOT}/run" ZEPHYR_PROFILE="${P}" ZEPHYR_TOOL="${TOOL}" "${GUARD}" 2>&1 >/dev/null)"; rc=$?
eq "RUN_HOME default log: exit 2" "${rc}" 2; eq "RUN_HOME default log written" "$(wc -l <"${ROOT}/run/pm/zephyr-refusals.log" | tr -d ' ')" 1
eq "explicit log untouched by RUN_HOME run" "$(loglines)" "${n0}"
out="$(printf '%s' "$(j bad GET)" | "${GUARD}" "${P}" "${TOOL}" "${ROOT}/ro/dir/log" 2>&1 >/dev/null)"; rc=$?; eq "refusal log in new dir: exit 2" "${rc}" 2
mkdir -p "${ROOT}/rolog"; chmod 555 "${ROOT}/rolog"
out="$(printf '%s' "$(j bad GET)" | "${GUARD}" "${P}" "${TOOL}" "${ROOT}/rolog/sub/log" 2>&1 >/dev/null)"; rc=$?; eq "unwritable log still exit 2" "${rc}" 2; chmod 755 "${ROOT}/rolog"

# R1-1: closed tool_input key set (ASSUMPTION UNTIL P0, fixture keys); keyword scan still covers the whole input
call "${P}" "$(j get_versions GET ',"path":"/x","params":{"limit":5,"env":"dev2"}')"; eq "closed-set keys path+params: exit 0" "${rc}" 0
call "${P}" "$(j get_versions GET ',"operationId":"setFlag"')"; eq "extra tool_input key: exit 2" "${rc}" 2; has "extra key reason" "${err}" "outside the closed set"
call "${P}" "$(j get_versions GET ',"params":{"q":{"op":"x"}}')"; eq "non-scalar params value: exit 2" "${rc}" 2
call "${P}" "$(j get_versions GET ',"path":["/x"]')"; eq "non-string path: exit 2" "${rc}" 2
call "${P}" "$(j get_versions GET ',"params":{"action":"Promote"}')"; eq "keyword inside params: exit 2" "${rc}" 2; has "keyword reason" "${err}" "deploy, promote or rollback"
call "${P}" "$(j get_versions GET ',"path":"/x/ROLL\u0412ACK"')"; eq "non-ASCII lookalike: exit 2" "${rc}" 2; has "non-ASCII reason" "${err}" "non-ASCII"
# R1-12: read_ops anchored at the direct child of zephyr:; ambiguity refused
NE="${ROOT}/nested.md"; printf 'zephyr:\n  other:\n    read_ops: [setFlag]\n' >"${NE}"
call "${NE}" "$(j setFlag GET)"; eq "nested read_ops not honoured: exit 2" "${rc}" 2
NE2="${ROOT}/nested2.md"; printf 'zephyr:\n  read_ops: [get_versions]\n  other:\n    read_ops: [setFlag]\n' >"${NE2}"
call "${NE2}" "$(j setFlag GET)"; eq "nested read_ops beside direct one: exit 2" "${rc}" 2
call "${NE2}" "$(j get_versions GET)"; eq "direct read_ops beside nested one: exit 0" "${rc}" 0
DU="${ROOT}/dup.md"; printf 'zephyr:\n  read_ops: [get_versions]\n  read_ops: [setFlag]\n' >"${DU}"
call "${DU}" "$(j get_versions GET)"; eq "duplicate read_ops key: exit 2" "${rc}" 2; has "ambiguous reason" "${err}" "ambiguous"
DZ="${ROOT}/dupz.md"; printf 'zephyr:\n  read_ops: [get_versions]\nzephyr:\n  read_ops: [setFlag]\n' >"${DZ}"
call "${DZ}" "$(j get_versions GET)"; eq "duplicate zephyr key: exit 2" "${rc}" 2

# Producer/consumer: the delivery-intake template's exact zephyr: block (only the sentinels replaced) is read by the guard.
TPL="${ZEPHYR_TEMPLATE_UNDER_TEST:-${HERE}/../../delivery-intake/references/templates/repo-profile.md}"
TB="$(awk '/^zephyr:/ { z = 1; print; next } z && /^[[:space:]]/ { print; next } { z = 0 }' "${TPL}" 2>/dev/null)"
case "${TB}" in zephyr:*read_ops:*) pass "template has a zephyr: block with read_ops" ;; *) fail "template zephyr: block not found in ${TPL}" ;; esac
TP="${ROOT}/profile-from-template.md"
{ printf 'name: fixture
'; printf '%s\n' "${TB}" | sed -e 's/read_ops: \[FILL_IN_BEFORE_DISPATCH\]/read_ops: [get_versions, get_history]/' \
    -e "s/execute_tool: FILL_IN_BEFORE_DISPATCH/execute_tool: ${TOOL}/"; printf 'jira:\n  project_key: X\n'; } >"${TP}"
has "template fixture: read_ops sentinel replaced" "$(cat "${TP}")" "[get_versions, get_history]"
call "${TP}" "$(j get_history GET)"; eq "template-form profile, listed read: exit 0" "${rc}" 0
call "${TP}" "$(j list_secrets GET)"; eq "template-form profile, non-listed: exit 2" "${rc}" 2
# check-zephyr-disallowed.sh: one pass and one fail fixture, plus list forms and exceptions
A="${ROOT}/agents-pass"; mkdir -p "${A}"
printf -- '---\nname: a\ndisallowedTools: %s, Other\n---\nbody\n' "${TOOL}" >"${A}/a.md"
printf -- '---\nname: b\ndisallowedTools: [Other, "%s"]\n---\nbody\n' "${TOOL}" >"${A}/b.md"
printf -- '---\nname: c\ndisallowedTools:\n  - Other\n  - %s\nmodel: x\n---\n' "${TOOL}" >"${A}/c.md"
out="$("${CHECK}" "${A}" "${TOOL}" 2>&1)"; rc=$?; eq "check pass fixture: exit 0" "${rc}" 0; has "check pass: count" "${out}" "3 definitions"
F="${ROOT}/agents-fail"; mkdir -p "${F}"; cp "${A}/a.md" "${F}/a.md"
printf -- '---\nname: d\ntools: %s\n---\nbody mentions disallowedTools: %s\n' "${TOOL}" "${TOOL}" >"${F}/d.md"
out="$("${CHECK}" "${F}" "${TOOL}" 2>&1)"; rc=$?; eq "check fail fixture: exit 1" "${rc}" 1; has "check fail: names file" "${out}" "d.md"
out="$("${CHECK}" "${F}" "${TOOL}" --except d 2>&1)"; rc=$?; eq "check with --except: exit 0" "${rc}" 0
printf -- '---\nname: e\ndisallowedTools: %s_other\n---\n' "${TOOL}" >"${F}/e.md"
out="$("${CHECK}" "${F}" "${TOOL}" --except d 2>&1)"; rc=$?; eq "check: tool name must match exactly" "${rc}" 1
mkdir -p "${ROOT}/none"; out="$("${CHECK}" "${ROOT}/none" "${TOOL}" 2>&1)"; rc=$?; eq "check: empty dir fails closed" "${rc}" 1
out="$("${CHECK}" "${A}" 2>&1)"; rc=$?; eq "check: usage error exit 2" "${rc}" 2
out="$("${CHECK}" "${ROOT}/nonexistent" "${TOOL}" 2>&1)"; rc=$?; eq "check: missing dir exit 2" "${rc}" 2

echo "${passed} passed, ${failed} failed"
[ "${failed}" -eq 0 ]
