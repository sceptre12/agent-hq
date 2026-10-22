#!/usr/bin/env bash
# tools/git-hooks/test_session-end-push-check.sh — tests for session-end-push-check.sh (T-20261007-335).
# Hermetic: a throwaway repo via SESSION_END_HQ_DIR. A local TAG named origin/main must not shadow refs/remotes/origin/main.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="${SESSION_END_UNDER_TEST:-${HERE}/session-end-push-check.sh}"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
passed=0; failed=0
pass() { echo "PASS: $1"; passed=$((passed + 1)); }
fail() { echo "FAIL: $1"; failed=$((failed + 1)); }
eq() { if [ "$2" = "$3" ]; then pass "$1"; else fail "$1 (got '$2', want '$3')"; fi; }
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t
git init -q -b main "$TMP/hq"; cd "$TMP/hq" || exit 1
c() { echo "$1" >f; git add f; git commit -qm "$1"; }
run() { out="$(SESSION_END_HQ_DIR="$TMP/hq" "$TARGET" 2>&1)"; rc=$?; }
c 1; C1="$(git rev-parse HEAD)"; c 2; c 3
run; eq "no origin/main ref: silent" "$out" ""; eq "no origin/main ref: rc 0" "$rc" 0
git update-ref refs/remotes/origin/main HEAD
run; eq "not ahead: silent" "$out" ""
git update-ref refs/remotes/origin/main "$C1"
run; eq "ahead by 2: names 2" "$out" "hq has 2 unpushed commit(s) — push is your only backup (ADR 0006/0007)"
git update-ref refs/remotes/origin/main HEAD; git tag origin/main "$C1"   # tag at older commit would say "ahead by 2"
run; eq "tag-shadow: tracking ref at HEAD, so silent" "$out" ""; eq "tag-shadow: rc 0" "$rc" 0
git tag -d origin/main >/dev/null; git update-ref refs/remotes/origin/main "$C1"; git tag origin/main HEAD   # tag at HEAD would say "not ahead"
run; eq "tag-shadow reversed: tracking ref behind, names 2" "${out%% unpushed*}" "hq has 2"
# SESSION_END_HQ_DIR is the override; a stray HQ_DIR pointing at another repo is ignored.
git init -q -b main "$TMP/other"; (cd "$TMP/other" && echo x >f && git add f && git commit -qm x && git update-ref refs/remotes/origin/main HEAD && echo y >f && git commit -qam y)
out="$(HQ_DIR="$TMP/other" SESSION_END_HQ_DIR="$TMP/hq" "$TARGET" 2>&1)"; eq "stray HQ_DIR ignored; SESSION_END_HQ_DIR used" "${out%% unpushed*}" "hq has 2"
out="$(HQ_DIR="$TMP/other" HOME="$TMP/nohome" "$TARGET" 2>&1)"; eq "HQ_DIR alone is not an override (default path, silent)" "$out" ""
echo "session-end-push-check: $passed passed, $failed failed"; [ "$failed" = 0 ]
