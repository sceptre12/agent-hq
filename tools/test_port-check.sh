#!/usr/bin/env bash
# tools/test_port-check.sh — tests for tools/port-check.sh: active_rows supersede semantics (a later `released` row for the
# same port + source supersedes an earlier claimed row), --audit over superseded rows, the --claim release round trip and
# its warning, self-release without --force (r2 M2), strict port validation (r2 M3), a TMPDIR-templated temp file for --audit (rc 3 on failure), lsof missing/failing -> exit 3 even with --force (M1),
# --claim field validation (M2) and tools/lib/port-check-lib.sh unit checks. Hermetic: every case uses a mktemp registry via
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
claim() { PORT_REGISTRY_FILE="$TMP/reg.tsv" "$TARGET" --claim "$P" 127.0.0.1 - svc proj "$1" "$2" - "${@:3}" 2>&1 >/dev/null; }   # self-release: no --force
echo "$HDR" >"$TMP/reg.tsv"
claim claimed srcA >/dev/null; claim released srcA >"$TMP/err1"
PORT_REGISTRY_FILE="$TMP/reg.tsv" "$TARGET" "$P" >/dev/null 2>&1; rc=$?
if [ "$rc" = 0 ] && ! command grep -q WARNING "$TMP/err1"; then pass "--claim round trip: claim+release same source -> free, no warning"; else fail "--claim round trip (exit $rc, stderr: $(cat "$TMP/err1"))"; fi
echo "$HDR" >"$TMP/reg.tsv"
claim claimed srcA >/dev/null; claim released srcB >"$TMP/err2"
if command grep -q 'WARNING.*supersedes no claim' "$TMP/err2"; then pass "--claim release with different source -> WARNING on stderr"; else fail "--claim mismatched release gave no WARNING: $(cat "$TMP/err2")"; fi
# M2 (r2): self-release needs no --force and keeps the caller's note; another project's row needs --force
reln() { PORT_REGISTRY_FILE="$TMP/reg.tsv" "$TARGET" --claim "$P" 127.0.0.1 - svc "$1" released srcA "$2" "${@:3}" >/dev/null 2>&1; }
echo "$HDR" >"$TMP/reg.tsv"; claim claimed srcA >/dev/null
reln proj "released 2026-10-09 (stopped)"; rc=$?
if [ "$rc" = 0 ] && [ "$(tail -n 1 "$TMP/reg.tsv" | cut -f9)" = "released 2026-10-09 (stopped)" ]; then pass "self-release without --force keeps the caller's note"; else fail "self-release: exit $rc, last row: $(tail -n 1 "$TMP/reg.tsv")"; fi
echo "$HDR" >"$TMP/reg.tsv"; claim claimed srcA >/dev/null; cp "$TMP/reg.tsv" "$TMP/reg.held"
reln other "takeover"; rc=$?
if [ "$rc" = 1 ] && cmp -s "$TMP/reg.tsv" "$TMP/reg.held"; then pass "release of another project's row without --force refused (exit 1)"; else fail "foreign release: exit $rc, want 1 and no row"; fi
reln other "takeover" --force; rc=$?
if [ "$rc" = 0 ] && [ "$(tail -n 1 "$TMP/reg.tsv" | cut -f9)" = "forced: takeover" ]; then pass "release of another project's row with --force -> appended, note 'forced: takeover'"; else fail "forced foreign release: exit $rc, last row: $(tail -n 1 "$TMP/reg.tsv")"; fi
{ echo "$HDR"; row "$P" claimed srcA; printf '%s\t127.0.0.1\t-\tsvc\tother\tclaimed\tsrcB\t2026-10-08\t-\n' "$P"; } >"$TMP/reg.tsv"; cp "$TMP/reg.tsv" "$TMP/reg.held"
reln proj "mine"; rc=$?
if [ "$rc" = 1 ] && cmp -s "$TMP/reg.tsv" "$TMP/reg.held"; then pass "self-release refused when another project also holds the port (exit 1)"; else fail "shared-port release: exit $rc, want 1"; fi
# TMPDIR: --audit puts its temp file under TMPDIR (templated mktemp) and removes it on exit; a missing TMPDIR dir fails closed
mkdir -p "$TMP/td"; echo "$HDR" >"$TMP/reg.tsv"; printf '%s\n' "$(row $P live srcA)" >>"$TMP/reg.tsv"
TMPDIR="$TMP/td" PORT_REGISTRY_FILE="$TMP/reg.tsv" "$TARGET" --audit >/dev/null 2>&1
if [ -z "$(ls -A "$TMP/td")" ]; then pass "--audit under a writable TMPDIR leaves no temp file"; else fail "--audit left files in TMPDIR: $(ls "$TMP/td")"; fi
TMPDIR="$TMP/nope" PORT_REGISTRY_FILE="$TMP/reg.tsv" "$TARGET" --audit >/dev/null 2>&1; rc=$?
if [ "$rc" = 3 ]; then pass "--audit with an unusable TMPDIR fails closed (exit 3)"; else fail "--audit with an unusable TMPDIR: exit $rc, want 3"; fi
# M1: lsof missing (PATH without /usr/sbin) or failing (stub) -> exit 3, never FREE, never a --claim append
mkdir -p "$TMP/badbin" "$TMP/partbin"
printf '#!/bin/sh\necho "lsof: boom" >&2\nexit 2\n' >"$TMP/badbin/lsof"
printf '#!/bin/sh\necho "COMMAND PID"\nexit 1\n' >"$TMP/partbin/lsof"; chmod +x "$TMP/badbin/lsof" "$TMP/partbin/lsof"
echo "$HDR" >"$TMP/reg.tsv"; cp "$TMP/reg.tsv" "$TMP/reg.orig"
# lsof_case <name> <PATH> <args...>: want exit 3, no FREE, registry byte-identical
lsof_case() {
  local name="$1" path="$2" out rc; shift 2
  out="$(PATH="$path" PORT_REGISTRY_FILE="$TMP/reg.tsv" "$BASH" "$TARGET" "$@" 2>&1)"; rc=$?
  if [ "$rc" = 3 ] && ! printf '%s' "$out" | command grep -q 'FREE' && cmp -s "$TMP/reg.tsv" "$TMP/reg.orig"; then pass "$name (exit 3)"
  else fail "$name (exit $rc, want 3): $out"; fi
}
for m in missing failing partial; do
  case $m in missing) pth=/usr/bin:/bin ;; failing) pth="$TMP/badbin:$PATH" ;; partial) pth="$TMP/partbin:$PATH" ;; esac
  lsof_case "lsof $m: check" "$pth" "$P"
  lsof_case "lsof $m: --claim refuses" "$pth" --claim "$P" 127.0.0.1 - svc proj claimed srcA -
  lsof_case "lsof $m: --claim --force still refuses" "$pth" --claim "$P" 127.0.0.1 - svc proj claimed srcA - --force
  lsof_case "lsof $m: --audit" "$pth" --audit
done
# M2: --claim field validation — refused (exit 3) before anything is written
claim_bad() {
  local name="$1" out rc; shift
  out="$(PORT_REGISTRY_FILE="$TMP/reg.tsv" "$TARGET" --claim "$@" 2>&1)"; rc=$?
  if [ "$rc" = 3 ] && cmp -s "$TMP/reg.tsv" "$TMP/reg.orig"; then pass "--claim rejects $name (exit 3, nothing written)"
  else fail "--claim $name: exit $rc, want 3 and an unchanged registry: $out"; fi
}
claim_bad "tab in service" "$P" 127.0.0.1 - $'svc\tx' proj claimed srcA -
claim_bad "newline in note (forged row)" "$P" 127.0.0.1 - svc proj claimed srcA $'n\n58233\t*\t-\tx\ty\tlive\tz\t2026-10-26\t-'
claim_bad "newline in source" "$P" 127.0.0.1 - svc proj claimed $'srcA\nB' -
claim_bad "control char (0x01) in project" "$P" 127.0.0.1 - svc $'pr\001oj' claimed srcA -
claim_bad "carriage return in bind" "$P" $'127.0.0.1\r' - svc proj claimed srcA -
claim_bad "empty bind" "$P" "" - svc proj claimed srcA -
claim_bad "non-numeric container_port" "$P" 127.0.0.1 abc svc proj claimed srcA -
claim_bad "leading-zero port 045010" 045010 127.0.0.1 - svc proj claimed srcA -
claim_bad "20-digit port" 12345678901234567890 127.0.0.1 - svc proj claimed srcA -
claim_bad "leading-zero container_port" "$P" 127.0.0.1 08080 svc proj claimed srcA -
claim_bad "out-of-range container_port 99999" "$P" 127.0.0.1 99999 svc proj claimed srcA -
# M3 (r2): check refuses non-canonical ports (exit 3) instead of reading FREE against a canonical row
{ echo "$HDR"; row 45010 claimed srcA; row 9000 claimed srcA; } >"$TMP/reg.tsv"
for bad in 045010 09000 12345678901234567890 00 65536; do
  out="$(PORT_REGISTRY_FILE="$TMP/reg.tsv" "$TARGET" "$bad" 2>&1)"; rc=$?
  if [ "$rc" = 3 ] && ! printf '%s' "$out" | command grep -q FREE; then pass "check rejects port '$bad' (exit 3)"; else fail "check '$bad': exit $rc: $out"; fi
done
echo "$HDR" >"$TMP/reg.tsv"
out="$(PORT_REGISTRY_FILE="$TMP/reg.tsv" "$TARGET" --claim "$P" 127.0.0.1 8080-8081 svc proj claimed srcA - 2>&1)"; rc=$?
if [ "$rc" = 0 ] && [ "$(command grep -vc '^#' "$TMP/reg.tsv")" = 1 ]; then pass "--claim accepts a clean row with a container_port range"; else fail "--claim clean row: exit $rc: $out"; fi
# tools/lib/port-check-lib.sh unit checks (sourced in a subshell)
lib() { ( EXIT_FREE=0; EXIT_TAKEN=1; EXIT_ERROR=3; . "$HERE/lib/port-check-lib.sh"; "$@" ) >/dev/null 2>&1; }
lib port_matches 9500 9000-9999 && pass "lib: range hit" || fail "lib: range hit"
lib port_matches 10000 9000-9999 && fail "lib: range miss" || pass "lib: range miss"
lib validate_port 0 && fail "lib: port 0 rejected" || pass "lib: port 0 rejected"
lib validate_port 65535 && pass "lib: port 65535 accepted" || fail "lib: port 65535 accepted"
lib validate_port 045010 && fail "lib: 045010 rejected" || pass "lib: 045010 rejected"
lib validate_port 12345678901234567890 && fail "lib: 20-digit port rejected" || pass "lib: 20-digit port rejected"
lib validate_claim_fields 1 b - s p claimed src - && pass "lib: clean claim fields accepted" || fail "lib: clean claim fields accepted"
lib validate_claim_fields 1 b - s p claimed src $'a\tb'; [ $? = 3 ] && pass "lib: tab in note -> 3" || fail "lib: tab in note -> 3"
PATH=/usr/bin:/bin lib lsof_port "$P"; [ $? = 3 ] && pass "lib: lsof_port without lsof -> 3" || fail "lib: lsof_port without lsof -> 3"
echo "=== $passed passed, $failed failed ==="
[ "$failed" = 0 ]
