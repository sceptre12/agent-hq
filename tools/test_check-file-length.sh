#!/usr/bin/env bash
# tools/test_check-file-length.sh — tests for tools/check-file-length.sh (Rule 10: it is grandfathered; this
# writes its test with the mktemp-template change). Hermetic: fixture trees under a TMPDIR-template mktemp dir.
# Cases: pass, over-limit fail, allowlisted, malformed allowlist, exclusions, TMPDIR honoured, bad TMPDIR fails closed.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="${CHECK_FILE_LENGTH_UNDER_TEST:-${HERE}/check-file-length.sh}"
ROOT="$(mktemp -d "${TMPDIR:-/tmp}/test_check-file-length.XXXXXX")" || { echo "FAIL: mktemp -d"; exit 1; }
trap 'rm -rf "$ROOT"' EXIT
passed=0; failed=0
pass() { echo "PASS: $1"; passed=$((passed + 1)); }
fail() { echo "FAIL: $1"; failed=$((failed + 1)); }
eq() { if [ "$2" = "$3" ]; then pass "$1"; else fail "$1 (got '$2', want '$3')"; fi; }
has() { case "$2" in *"$3"*) pass "$1" ;; *) fail "$1 (no '$3' in: $2)" ;; esac; }
hasnt() { case "$2" in *"$3"*) fail "$1 (found '$3' in: $2)" ;; *) pass "$1" ;; esac; }
mk() { # mk <dir> <file> <lines> — a python-ish file with exactly <lines> lines
  mkdir -p "$1/$(dirname "$2")"; seq 1 "$3" | sed 's/^/x=/' >"$1/$2"
}
run() { out="$("$TARGET" "$@" 2>&1)"; rc=$?; }

# pass: every file within the limit (300 lines exactly is allowed)
P="$ROOT/pass"; mk "$P" src/ok.py 10; mk "$P" src/edge.py 300
run "$P"; eq "pass: rc 0" "$rc" 0; has "pass: summary 0 over 300" "$out" "0 file(s) over 300 lines"

# fail: one file at 301 lines is reported with count and path
F="$ROOT/fail"; mk "$F" src/ok.py 10; mk "$F" src/big.py 301
run "$F"; eq "over-limit: rc 1" "$rc" 1; has "over-limit: names file and count" "$out" "301  src/big.py"
has "over-limit: summary 1 over 300" "$out" "1 file(s) over 300 lines"; hasnt "over-limit: ok.py not listed" "$out" "src/ok.py"

# allowlisted: a path with a reason (em dash) is skipped
A="$ROOT/allow"; mk "$A" src/big.py 301
printf '# comment\n\nsrc/big.py — generated table, cannot split\n' >"$A/.file-length-allowlist"
run "$A"; eq "allowlisted: rc 0" "$rc" 0; has "allowlisted: summary 0 over 300" "$out" "0 file(s) over 300 lines"

# malformed allowlist: an entry with no reason fails closed
M="$ROOT/malformed"; mk "$M" src/ok.py 10; printf 'src/ok.py\n' >"$M/.file-length-allowlist"
run "$M"; eq "malformed allowlist: rc 1" "$rc" 1; has "malformed allowlist: says no reason given" "$out" "no reason given"

# exclusions: skills/, test dirs, *.test.* and lockfiles are not scanned; non-code extensions are ignored
X="$ROOT/excl"; mk "$X" skills/s/big.py 400; mk "$X" tests/big.py 400; mk "$X" src/big.test.js 400; mk "$X" pnpm-lock.yaml 400; mk "$X" notes.txt 400
run "$X"; eq "exclusions: rc 0" "$rc" 0; has "exclusions: summary 0 over 300" "$out" "0 file(s) over 300 lines"

# TMPDIR set to a writable dir: runs clean, and its temp files are removed on exit
W="$ROOT/work"; mkdir -p "$W/tmpd"
out="$(TMPDIR="$W/tmpd" "$TARGET" "$F" 2>&1)"; rc=$?
eq "TMPDIR writable: rc 1 (violation still found)" "$rc" 1; has "TMPDIR writable: names big.py" "$out" "301  src/big.py"
eq "TMPDIR writable: no leftover temp files" "$(find "$W/tmpd" -type f | wc -l | tr -d ' ')" 0
out="$(TMPDIR="$W/tmpd" "$TARGET" "$P" 2>&1)"; rc=$?; eq "TMPDIR writable: pass case rc 0" "$rc" 0

# TMPDIR pointing at a missing dir: mktemp fails and the check fails closed (never a silent pass)
out="$(TMPDIR="$ROOT/does-not-exist" "$TARGET" "$P" 2>&1)"; rc=$?
if [ "$rc" != 0 ]; then pass "TMPDIR missing: nonzero rc ($rc)"; else fail "TMPDIR missing: rc 0 (silent pass)"; fi
hasnt "TMPDIR missing: no pass summary" "$out" "0 file(s) over 300 lines"

# usage: a missing target dir is rc 1
run "$ROOT/nope"; eq "missing target dir: rc 1" "$rc" 1; has "missing target dir: message" "$out" "no such directory"

echo "check-file-length: $passed passed, $failed failed"; [ "$failed" = 0 ]
