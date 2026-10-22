#!/usr/bin/env bash
# tools/test_tree-eq-check.sh — tests for tools/tree-eq-check.sh target resolution (T-20261007-335).
# Hermetic: a throwaway origin + clone under mktemp. A local TAG named origin/main (git resolves refs/tags before
# refs/remotes) must not shadow the remote-tracking ref, for the default target AND an explicit --target origin/main.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="${TREE_EQ_UNDER_TEST:-${HERE}/tree-eq-check.sh}"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
passed=0; failed=0
pass() { echo "PASS: $1"; passed=$((passed + 1)); }
fail() { echo "FAIL: $1"; failed=$((failed + 1)); }
eq() { if [ "$2" = "$3" ]; then pass "$1"; else fail "$1 (got '$2', want '$3')"; fi; }
has() { case "$2" in *"$3"*) pass "$1" ;; *) fail "$1 (no '$3' in: $2)" ;; esac; }
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t
git init -q --bare -b main "$TMP/origin.git"
git init -q -b main "$TMP/w"; cd "$TMP/w" || exit 1
git remote add origin "$TMP/origin.git"
echo 1 >f; git add f; git commit -qm c1; C1="$(git rev-parse HEAD)"; T1="$(git rev-parse 'HEAD^{tree}')"
echo 2 >f; git commit -qam c2; C2="$(git rev-parse HEAD)"; T2="$(git rev-parse 'HEAD^{tree}')"
git push -q origin main; git fetch -q origin
eq "setup: tracking ref is c2" "$(git rev-parse refs/remotes/origin/main)" "$C2"
run() { out="$("$TARGET" "$@" --repo "$TMP/w" 2>&1)"; rc=$?; }

run ff-check --branch HEAD;                    eq "ff-check default target: rc 0" "$rc" 0; has "ff-check default: c2" "$out" "FF-CHECK: OK target=$C2"
run verify --gated-tree "$T2";                 eq "verify default target: rc 0" "$rc" 0; has "verify default: MET" "$out" "TREE-EQ: MET tree=$T2 target=$C2"

git tag origin/main "$C1"   # shadow: local tag at an OLDER commit than the remote-tracking ref
eq "setup: bare origin/main now names the tag" "$(git rev-parse --verify -q 'origin/main^{commit}' 2>/dev/null)" "$C1"
run ff-check --branch HEAD;                    eq "tag-shadow ff-check default: rc 0" "$rc" 0; has "tag-shadow ff-check default uses tracking ref" "$out" "target=$C2"
run ff-check --branch HEAD --target origin/main; has "tag-shadow ff-check explicit uses tracking ref" "$out" "target=$C2"
run verify --gated-tree "$T2";                 eq "tag-shadow verify default: rc 0" "$rc" 0; has "tag-shadow verify default: MET against c2" "$out" "TREE-EQ: MET tree=$T2 target=$C2"
run verify --gated-tree "$T2" --target origin/main; eq "tag-shadow verify explicit: rc 0" "$rc" 0
run verify --gated-tree "$T1";                 eq "tag-shadow verify: tag's tree is NOT accepted: rc 1" "$rc" 1

git remote remove origin; git tag -d origin/main >/dev/null; git branch -q local-x "$C1"
run verify --gated-tree "$T1" --target local-x; eq "no-remote bare local ref still resolves as-is: rc 0" "$rc" 0

# A1: remote configured, no tracking ref. Local branch origin/x resolves; a TAG origin/x must not; fails closed.
# Remote has branch x (fetch succeeds) but no fetch refspec, so no tracking ref gets created.
git push -q "$TMP/origin.git" "$C2:refs/heads/x"; git remote add origin "$TMP/origin.git"; git config --unset-all remote.origin.fetch
git branch -q origin/x "$C1"
run verify --gated-tree "$T1" --target origin/x; eq "A1 local branch origin/x, no tracking ref: rc 0" "$rc" 0
git branch -q -D origin/x; git tag origin/x "$C1"
run verify --gated-tree "$T1" --target origin/x; eq "A1 tag-only origin/x does NOT resolve: rc 2" "$rc" 2
run ff-check --branch HEAD --target origin/x;    eq "A1 tag-only origin/x ff-check: rc 2" "$rc" 2
git tag -d origin/x >/dev/null; git remote remove origin
# A3: remote "origin" configured; target "o.igin/x" must not match it as a regex (grep -F), so it passes through as-is.
git remote add origin "$TMP/origin.git"; git tag o.igin/x "$C1"
run verify --gated-tree "$T1" --target o.igin/x; eq "A3 o.igin/x not treated as configured remote origin: rc 0" "$rc" 0
git tag -d o.igin/x >/dev/null; git remote remove origin
echo "tree-eq-check: $passed passed, $failed failed"; [ "$failed" = 0 ]
