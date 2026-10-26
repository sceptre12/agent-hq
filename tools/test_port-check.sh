#!/usr/bin/env bash
# tools/test_port-check.sh — tests for tools/port-check.sh: active_rows supersede semantics (a later `released` row for the
# same port + source supersedes an earlier claimed row), --audit over superseded rows, the --claim release round trip and
# its warning, and a TMPDIR-templated temp file for --audit. Hermetic: every case uses a mktemp registry via
# PORT_REGISTRY_FILE and an unlikely-to-be-bound high port; never touches the real ports.tsv.
# Provenance: ported from hq tools/test_port-check.sh. Ported into agent-hq 2026-10-26 (delivery workflow, port guard).
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="${HERE}/port-check.sh"
_tb="${TMPDIR:-/tmp}"; TMP="$(mktemp -d "${_tb%/}/test_port-check.XXXXXX")"; trap 'rm -rf "$TMP"' EXIT
passed=0; failed=0
pass() { echo "PASS: $1"; passed=$((passed + 1)); }
fail() { echo "FAIL: $1"; failed=$((failed + 1)); }
P=58231
while lsof -nP -iTCP:"$P" -sTCP:LISTEN >/dev/null 2>&1; do P=$((P + 2)); done   # pick a port nothing listens on
HDR=$'#port\tbind\tcontainer_port\tservice\tproject\tstatus\tsource\tverified\tnote'
row() { printf '%s\t127.0.0.1\t-\tsvc\tproj\t%s\t%s\t2026-10-08\t-\n' "$1" "$2" "$3"; }
# run_case <name> <want_exit> <rows...>
run_case() {
  local name="$1" want="$2"; shift 2
  { echo "$HDR"; for r in "$@"; do printf '%s\n' "$r"; done; } >"$TMP/reg.tsv"
  local out rc
  out="$(PORT_REGISTRY_FILE="$TMP/reg.tsv" "$TARGET" "$P" 2>&1)"; rc=$?
  if [ "$rc" = "$want" ]; then pass "$name (exit $rc)"; else fail "$name (got exit $rc, want $want): $out"; fi
}
run_case "claimed then later released -> free" 0 "$(row $P claimed srcA)" "$(row $P released srcA)"
run_case "claimed only -> taken" 1 "$(row $P claimed srcA)"
run_case "released then later claimed -> taken" 1 "$(row $P released srcA)" "$(row $P claimed srcA)"
run_case "claimed, released, claimed again -> taken" 1 "$(row $P claimed srcA)" "$(row $P released srcA)" "$(row $P claimed srcA)"
run_case "release from a different source does not supersede" 1 "$(row $P claimed srcA)" "$(row $P released srcB)"
run_case "release of another port does not supersede" 1 "$(row $P claimed srcA)" "$(row 58232 released srcA)"
# audit_case <name> <want-regex-count-of-lines-naming-port> <pattern> <rows...> — audit lines for port $P only
audit_case() {
  local name="$1" want="$2" pat="$3"; shift 3
  { echo "$HDR"; for r in "$@"; do printf '%s\n' "$r"; done; } >"$TMP/reg.tsv"
  local n; n="$(PORT_REGISTRY_FILE="$TMP/reg.tsv" "$TARGET" --audit 2>&1 | command grep -E "$pat" | command grep -c "$P" || true)"
  if [ "$n" = "$want" ]; then pass "$name"; else fail "$name (got $n, want $want)"; fi
}
audit_case "audit: live then released (same source) -> no GHOST" 0 '^(GHOST|MATCH|CONFLICT)' "$(row $P live srcA)" "$(row $P released srcA)"
audit_case "audit: released then live -> still active (GHOST)" 1 '^GHOST' "$(row $P released srcA)" "$(row $P live srcA)"
audit_case "audit: live only -> GHOST" 1 '^GHOST' "$(row $P live srcA)"
audit_case "audit: two claims, one released -> no CONFLICT" 0 '^CONFLICT' "$(row $P claimed srcA)" "$(row $P claimed srcB)" "$(row $P released srcA)"
audit_case "audit: two unreleased claims -> CONFLICT" 1 '^CONFLICT' "$(row $P claimed srcA)" "$(row $P claimed srcB)"
# --claim round trip via the CLI: claim, then release with the same source -> check reports free
claim() { PORT_REGISTRY_FILE="$TMP/reg.tsv" "$TARGET" --claim "$P" 127.0.0.1 - svc proj "$1" "$2" - "${@:3}" 2>&1 >/dev/null; }   # releasing a held port needs --force
echo "$HDR" >"$TMP/reg.tsv"
claim claimed srcA >/dev/null; claim released srcA --force >"$TMP/err1"
PORT_REGISTRY_FILE="$TMP/reg.tsv" "$TARGET" "$P" >/dev/null 2>&1; rc=$?
if [ "$rc" = 0 ] && ! command grep -q WARNING "$TMP/err1"; then pass "--claim round trip: claim+release same source -> free, no warning"; else fail "--claim round trip (exit $rc, stderr: $(cat "$TMP/err1"))"; fi
echo "$HDR" >"$TMP/reg.tsv"
claim claimed srcA >/dev/null; claim released srcB --force >"$TMP/err2"
if command grep -q 'WARNING.*supersedes no claim' "$TMP/err2"; then pass "--claim release with different source -> WARNING on stderr"; else fail "--claim mismatched release gave no WARNING: $(cat "$TMP/err2")"; fi
# TMPDIR: --audit puts its temp file under TMPDIR (templated mktemp) and removes it on exit; a missing TMPDIR dir fails closed
mkdir -p "$TMP/td"; echo "$HDR" >"$TMP/reg.tsv"; printf '%s\n' "$(row $P live srcA)" >>"$TMP/reg.tsv"
TMPDIR="$TMP/td" PORT_REGISTRY_FILE="$TMP/reg.tsv" "$TARGET" --audit >/dev/null 2>&1
if [ -z "$(ls -A "$TMP/td")" ]; then pass "--audit under a writable TMPDIR leaves no temp file"; else fail "--audit left files in TMPDIR: $(ls "$TMP/td")"; fi
TMPDIR="$TMP/nope" PORT_REGISTRY_FILE="$TMP/reg.tsv" "$TARGET" --audit >/dev/null 2>&1; rc=$?
if [ "$rc" != 0 ]; then pass "--audit with an unusable TMPDIR fails closed (exit $rc)"; else fail "--audit with an unusable TMPDIR exited 0"; fi
echo "=== $passed passed, $failed failed ==="
[ "$failed" = 0 ]
