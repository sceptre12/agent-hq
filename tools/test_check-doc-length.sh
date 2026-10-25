#!/usr/bin/env bash
# tools/test_check-doc-length.sh — tests for tools/check-doc-length.sh (Rule 10: it is grandfathered; this
# writes its test with the mktemp-template change). Hermetic: fixture trees under a TMPDIR-template mktemp dir.
# Cases: pass, over-limit fail, allowlisted (visible, non-blocking), malformed allowlist, case-insensitive
# extensions, exclusions, byte dimension (informational), TMPDIR honoured, bad TMPDIR fails closed.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="${CHECK_DOC_LENGTH_UNDER_TEST:-${HERE}/check-doc-length.sh}"
ROOT="$(mktemp -d "${TMPDIR:-/tmp}/test_check-doc-length.XXXXXX")" || { echo "FAIL: mktemp -d"; exit 1; }
trap 'rm -rf "$ROOT"' EXIT
passed=0; failed=0
pass() { echo "PASS: $1"; passed=$((passed + 1)); }
fail() { echo "FAIL: $1"; failed=$((failed + 1)); }
eq() { if [ "$2" = "$3" ]; then pass "$1"; else fail "$1 (got '$2', want '$3')"; fi; }
has() { case "$2" in *"$3"*) pass "$1" ;; *) fail "$1 (no '$3' in: $2)" ;; esac; }
hasnt() { case "$2" in *"$3"*) fail "$1 (found '$3' in: $2)" ;; *) pass "$1" ;; esac; }
mk() { # mk <dir> <file> <lines> — a markdown file with exactly <lines> lines
  mkdir -p "$1/$(dirname "$2")"; seq 1 "$3" | sed 's/^/line /' >"$1/$2"
}
run() { out="$("$TARGET" "$@" 2>&1)"; rc=$?; }

# pass: every doc within the limit (500 lines exactly is allowed)
P="$ROOT/pass"; mk "$P" docs/ok.md 10; mk "$P" docs/edge.md 500
run "$P"; eq "pass: rc 0" "$rc" 0; has "pass: 0 blocking" "$out" "0 blocking file(s) over 500 lines"

# fail: 501 lines is a blocking violation with count and path
F="$ROOT/fail"; mk "$F" docs/ok.md 10; mk "$F" docs/big.md 501
run "$F"; eq "over-limit: rc 1" "$rc" 1; has "over-limit: BLOCKING header" "$out" "NOT allowlisted (BLOCKING)"
has "over-limit: names file and count" "$out" "501  docs/big.md"; has "over-limit: summary 1 blocking" "$out" "1 blocking file(s) over 500 lines"

# allowlisted: over the cap but reported as visible, non-blocking debt (ADR 0029 Clause 5)
A="$ROOT/allow"; mk "$A" docs/big.md 501
printf '# comment\n\ndocs/big.md — owner-approved monolith\n' >"$A/.doc-length-allowlist"
run "$A"; eq "allowlisted: rc 0" "$rc" 0; has "allowlisted: reported as debt" "$out" "501  docs/big.md"
has "allowlisted: NON-BLOCKING" "$out" "NON-BLOCKING"; has "allowlisted: summary 0 blocking, 1 allowlisted" "$out" "0 blocking file(s) over 500 lines; 1 allowlisted"

# malformed allowlist: an entry with no reason fails closed
M="$ROOT/malformed"; mk "$M" docs/ok.md 10; printf 'docs/ok.md\n' >"$M/.doc-length-allowlist"
run "$M"; eq "malformed allowlist: rc 1" "$rc" 1; has "malformed allowlist: says no reason given" "$out" "no reason given"

# extensions are matched case-insensitively; other extensions are out of scope
C="$ROOT/case"; mk "$C" UPPER.MD 501; mk "$C" notes.txt 600; mk "$C" run.log 600
run "$C"; eq "case-insensitive: UPPER.MD blocks (rc 1)" "$rc" 1; has "case-insensitive: names UPPER.MD" "$out" "501  UPPER.MD"
hasnt "case-insensitive: .txt/.log not scanned" "$out" "notes.txt"

# exclusions: skills/ and x-context-docs/ are not scanned
X="$ROOT/excl"; mk "$X" skills/s/SKILL.md 600; mk "$X" references/x-context-docs/CATALOG.md 600
run "$X"; eq "exclusions: rc 0" "$rc" 0; has "exclusions: 0 blocking" "$out" "0 blocking file(s) over 500 lines"

# byte dimension: a short doc with very long lines is flagged for bytes only (informational, rc stays 0)
B="$ROOT/bytes"; mkdir -p "$B/docs"; for i in 1 2 3 4 5; do head -c 10000 /dev/zero | tr '\0' 'a'; echo; done >"$B/docs/dense.md"
run "$B"; eq "bytes: informational only, rc 0" "$rc" 0; has "bytes: flagged" "$out" "docs/dense.md"; has "bytes: 0 blocking" "$out" "0 blocking file(s) over 500 lines"

# TMPDIR set to a writable dir: runs clean, six temp files are created and removed on exit
W="$ROOT/work"; mkdir -p "$W/tmpd"
out="$(TMPDIR="$W/tmpd" "$TARGET" "$F" 2>&1)"; rc=$?
eq "TMPDIR writable: rc 1 (violation still found)" "$rc" 1; has "TMPDIR writable: names big.md" "$out" "501  docs/big.md"
eq "TMPDIR writable: no leftover temp files" "$(find "$W/tmpd" -type f | wc -l | tr -d ' ')" 0
out="$(TMPDIR="$W/tmpd" "$TARGET" "$P" 2>&1)"; rc=$?; eq "TMPDIR writable: pass case rc 0" "$rc" 0

# TMPDIR pointing at a missing dir: mktemp fails and the check fails closed (never a silent pass)
out="$(TMPDIR="$ROOT/does-not-exist" "$TARGET" "$P" 2>&1)"; rc=$?
if [ "$rc" != 0 ]; then pass "TMPDIR missing: nonzero rc ($rc)"; else fail "TMPDIR missing: rc 0 (silent pass)"; fi
hasnt "TMPDIR missing: no pass summary" "$out" "0 blocking file(s)"

# usage: a missing target dir is rc 1
run "$ROOT/nope"; eq "missing target dir: rc 1" "$rc" 1; has "missing target dir: message" "$out" "no such directory"

echo "check-doc-length: $passed passed, $failed failed"; [ "$failed" = 0 ]
