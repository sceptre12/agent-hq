#!/usr/bin/env bash
# tools/code-gate/test_scope.sh — tests for lib.sh: scope.conf classification (the REAL scope.conf is
# loaded), map glob/exact resolution, test-file detection, cg_check_map, and the runner's
# --inventory measurement that produces grandfathered.txt. Hermetic mktemp fixtures.
set -uo pipefail
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_PREFIX
REAL="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ROOT="$(mktemp -d "${TMPDIR:-/tmp}/test_scope.XXXXXX")"; trap 'rm -rf "$ROOT"' EXIT
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null   # hermetic: no user hooks/config
passed=0; failed=0; NFX=0
pass() { echo "PASS: $1"; passed=$((passed + 1)); }
fail() { echo "FAIL: $1"; failed=$((failed + 1)); }
eq() { if [ "$2" = "$3" ]; then pass "$1"; else fail "$1 (got '$2', want '$3')"; fi; }
has() { case "$2" in *"$3"*) pass "$1" ;; *) fail "$1 (missing '$3' in: $2)" ;; esac; }
hasnt() { case "$2" in *"$3"*) fail "$1 (unexpected '$3' in: $2)" ;; *) pass "$1" ;; esac; }
finish() { echo "=== $passed passed, $failed failed ==="; [ "$failed" = 0 ]; }
# The gate config files are in scope (scope.conf `include tools/code-gate/*`), so fixtures map them,
# as the real repo does.
CFGMAP=$'tools/code-gate/grandfathered.txt\ttools/test_foo.sh\ntools/code-gate/scope.conf\ttools/test_foo.sh\ntools/code-gate/test-map.tsv\ttools/test_foo.sh\n'
# mkfix — fresh NON-EMPTY fixture repo $FX on main (one base commit) with a bare origin. It holds a
# real mapped pair (tools/foo.sh + passing tools/test_foo.sh), a grandfathered legacy/old.sh, and
# the real gate scripts + pre-push copied from this checkout. cd's into $FX.
mkfix() {
  NFX=$((NFX + 1)); local d="$ROOT/f$NFX"; FX="$d/work"; ORIGIN="$d/origin.git"
  git init -q --bare -b main "$ORIGIN"; git init -q -b main "$FX"; cd "$FX" || exit 1
  git config user.email t@t; git config user.name t; git config commit.gpgsign false
  mkdir -p tools/code-gate tools/git-hooks legacy
  cp "$REAL"/tools/code-gate/{lib.sh,run-mapped-tests.sh,check-review.sh,gate-invariants.sh,scope.conf} tools/code-gate/
  cp "$REAL/tools/git-hooks/pre-push" tools/git-hooks/
  printf '#!/usr/bin/env bash\necho foo\n' >tools/foo.sh
  printf '#!/usr/bin/env bash\n[ "$(./tools/foo.sh)" = foo ]\n' >tools/test_foo.sh
  printf '#!/usr/bin/env bash\necho legacy\n' >legacy/old.sh
  printf '%stools/foo.sh\ttools/test_foo.sh\n' "$CFGMAP" >tools/code-gate/test-map.tsv
  printf 'legacy/old.sh\n' >tools/code-gate/grandfathered.txt
  echo readme >README.md
  chmod +x tools/*.sh tools/git-hooks/pre-push tools/code-gate/*.sh
  git add -A; git commit -qm base
  git remote add origin "$ORIGIN"; git push -q origin main 2>/dev/null
  git config core.hooksPath tools/git-hooks     # installed only after the bootstrap push
}
commit() { git add -A; git commit -qm "${1:-change}"; }
. "$REAL/tools/code-gate/lib.sh"
mkfix
cg_scope_load WORKTREE && pass "real scope.conf loads" || fail "real scope.conf loads"
inscope() { if cg_in_scope "$1" "$2"; then echo yes; else echo no; fi; }
for row in "a.sh 100644 yes" "x/y/b.py 100644 yes" "c.js 100644 yes" "d.zsh 100644 yes" "tools/hook 100755 yes" \
           "skills/s/bin/tool 100755 yes" "tools/hook 100644 no" "README.md 100644 no" "docs/a.md 100644 no" \
           "tools/data.json 100644 no" "plans/p/q.sh 100644 no" "plans/p/q.sh 100755 no" \
           "config/settings.json 100644 no" "config/settings.json 100755 no" "plans/deep/er/x.py 100644 no" \
           "tools/swarm-communication-layer/src/server.js 100644 no" "tools/swarm-communication-layer/ecosystem.config.cjs 100755 no" \
           "tools/code-gate/scope.conf 100644 yes" "tools/code-gate/test-map.tsv 100644 yes" \
           "tools/code-gate/grandfathered.txt 100644 yes"; do
  set -- $row; eq "scope $1 mode $2" "$(inscope "$1" "$2")" "$3"
done

printf 'tools/*.sh\ttools/test_foo.sh\nlegacy/old.sh\ttools/test_foo.sh\nlegacy/old.sh\tlegacy/t2.sh\n' | LC_ALL=C sort >tools/code-gate/test-map.tsv
eq "glob row resolves a file" "$(cg_tests_for WORKTREE tools/zzz.sh)" "tools/test_foo.sh"
eq "exact row with two tests resolves both" "$(cg_tests_for WORKTREE legacy/old.sh | tr '\n' ' ')" "legacy/t2.sh tools/test_foo.sh "
eq "unmapped path resolves nothing" "$(cg_tests_for WORKTREE other/x.sh)" ""
cg_is_test WORKTREE tools/test_anything.sh && pass "test_* is a test" || fail "test_* is a test"
cg_is_test WORKTREE web/a.test.js && pass "*.test.* is a test" || fail "*.test.* is a test"
cg_is_test WORKTREE legacy/t2.sh && pass "map test column is a test" || fail "map test column is a test"
cg_is_test WORKTREE tools/foo.sh && fail "source is not a test" || pass "source is not a test"

# cg_check_map on a non-empty good map, then each defect.
printf '#!/usr/bin/env bash\n:\n' >legacy/t2.sh; git add legacy/t2.sh   # map checks read tracked files
cg_check_map WORKTREE >/dev/null && pass "well-formed map passes" || fail "well-formed map passes"
printf 'tools/*.sh\ttools/test_foo.sh\nzzz/none/*\ttools/test_foo.sh\n' >tools/code-gate/test-map.tsv
out="$(cg_check_map WORKTREE)"; rc=$?; eq "glob matching nothing: rc 1" "$rc" 1; has "glob STALE-MAP" "$out" "STALE-MAP: source 'zzz/none/*'"
printf 'tools/foo.sh\ttools/gone.sh\n' >tools/code-gate/test-map.tsv
out="$(cg_check_map WORKTREE)"; rc=$?; eq "missing test: rc 1" "$rc" 1; has "test STALE-MAP" "$out" "STALE-MAP: test 'tools/gone.sh'"
printf 'tools/foo.sh\ttools/test_foo.sh\ntools/foo.sh\ttools/test_foo.sh\n' >tools/code-gate/test-map.tsv
out="$(cg_check_map WORKTREE)"; rc=$?; eq "duplicate row: rc 1" "$rc" 1; has "duplicate MALFORMED" "$out" "MALFORMED-MAP: rows not sorted"
printf 'tools/foo.sh\n' >tools/code-gate/test-map.tsv
out="$(cg_check_map WORKTREE)"; rc=$?; eq "one-field row: rc 1" "$rc" 1; has "one-field MALFORMED" "$out" "MALFORMED-MAP: bad row"
rm tools/code-gate/test-map.tsv
out="$(cg_check_map WORKTREE)"; rc=$?; eq "missing map: rc 1" "$rc" 1; has "missing map named" "$out" "test-map.tsv missing"

# --inventory: in-scope, non-test, unmapped files, measured from git (not hand-listed).
git checkout -q -- tools/code-gate/test-map.tsv
inv="$("$REAL/tools/code-gate/run-mapped-tests.sh" --inventory HEAD)"; rc=$?
eq "inventory: rc 0" "$rc" 0
has "inventory lists the unmapped legacy file" "$inv" "legacy/old.sh"
has "inventory lists the unmapped gate script" "$inv" "tools/code-gate/check-review.sh"
has "inventory lists the exec-bit hook" "$inv" "tools/git-hooks/pre-push"
hasnt "inventory omits the mapped source" "$inv" "tools/foo.sh"
hasnt "inventory omits test files" "$inv" "test_foo.sh"
eq "inventory is sorted" "$inv" "$(printf '%s\n' "$inv" | LC_ALL=C sort)"

# cg_changed parses `git diff --raw -z`: exact unicode/newline names; a deletion keeps its source mode.
mkfix; printf '#!/bin/sh\n' >"tools/é.sh"; printf '#!/bin/sh\n' >"tools/n
l.sh"; printf '#!/bin/sh\n' >tools/git-hooks/hk; chmod +x tools/git-hooks/hk; commit "names"
recs="$(cg_changed ACMRD HEAD~1 HEAD | tr '\0' '|')"
has "unicode name is raw, not quoted" "$recs" "100644	tools/é.sh|"
has "newline name is one record" "$recs" "100644	tools/n
l.sh|"
git rm -q tools/git-hooks/hk; commit "drop hook"
eq "deleted 100755 hook reported with its source mode" "$(cg_changed D HEAD~1 HEAD | tr '\0' '|')" "100755	tools/git-hooks/hk|"
cg_scope_load WORKTREE
eq "deleted extensionless hook is in scope" "$(cg_changed D HEAD~1 HEAD | cg_scoped | tr '\0' '|')" "100755	tools/git-hooks/hk|"
eq "cg_files is NUL-delimited and exact" "$(cg_files HEAD | tr '\0' '\n' | grep -c 'tools/n$')" 1

# Exact lookups are newline-safe: rows 'tools/n' and 'l.sh' must not match the one file 'tools/n<LF>l.sh'.
printf 'l.sh\ttools/test_foo.sh\ntools/n\ttools/test_foo.sh\n' >tools/code-gate/test-map.tsv
out="$(cg_check_map WORKTREE 2>/dev/null)"; eq "newline name fakes no exact match: rc 1" "$?" 1
has "row 'tools/n' is STALE" "$out" "STALE-MAP: source 'tools/n' matches"; has "row 'l.sh' is STALE" "$out" "STALE-MAP: source 'l.sh' matches"
# MALFORMED-MAP: a bare `*` or `**` source would map every file (H17).
for g in '*' '**'; do
  printf '%s\ttools/test_foo.sh\ntools/foo.sh\ttools/test_foo.sh\n' "$g" >tools/code-gate/test-map.tsv
  out="$(cg_check_map WORKTREE)"; rc=$?; eq "bare '$g' source: rc 1" "$rc" 1; has "bare '$g' named" "$out" "MALFORMED-MAP: source glob '$g'"
done
printf 'tools/*.sh\ttools/test_foo.sh\n' >tools/code-gate/test-map.tsv
cg_check_map WORKTREE >/dev/null && pass "a scoped glob (tools/*.sh) is allowed" || fail "a scoped glob (tools/*.sh) is allowed"

# LIST-FAIL (T-153): an in-process git() wrapper fails the first `ls-files`; cg_check_map WORKTREE must
# return 2 with one LIST-FAIL line (never STALE-MAP) and remove its temp file on every return path.
mkdir -p "$ROOT/tmpd"; GITN=0
git() { if [ "$1" = ls-files ] && [ "$GITN" = 0 ]; then GITN=1; echo "fatal: injected" >&2; return 128; fi; command git "$@"; }
TMPDIR="$ROOT/tmpd" cg_check_map WORKTREE >"$ROOT/o" 2>"$ROOT/e"; rc=$?; out="$(cat "$ROOT/o")"
eq "ls-files fails once: rc 2" "$rc" 2; eq "ls-files fails once: one LIST-FAIL line" "$out" "LIST-FAIL: cannot list tree WORKTREE (git rc 128, fail closed)"
hasnt "ls-files fails once: never STALE-MAP" "$out$(cat "$ROOT/e")" "STALE-MAP"; eq "LIST-FAIL path removed its temp file" "$(ls "$ROOT/tmpd")" ""
unset -f git
TMPDIR="$ROOT/tmpd" cg_check_map WORKTREE >/dev/null && pass "wrapper removed: same map passes" || fail "wrapper removed: same map passes"
eq "normal path removed its temp file" "$(ls "$ROOT/tmpd")" ""
# Encoded listing whose line count != the entry count (a short write): LIST-FAIL, never STALE-MAP, dir removed.
cg_enc() { CG_E="x"$'\n'"y"; }
TMPDIR="$ROOT/tmpd" cg_check_map WORKTREE >"$ROOT/o" 2>"$ROOT/e"; rc=$?; . "$REAL/tools/code-gate/lib.sh"
eq "enc lines != entries: rc 2" "$rc" 2; eq "enc mismatch: one LIST-FAIL line" "$(cat "$ROOT/o")" "LIST-FAIL: cannot list tree WORKTREE (encoded listing truncated, fail closed)"
hasnt "enc mismatch: never STALE-MAP" "$(cat "$ROOT/o" "$ROOT/e")" "STALE-MAP"; eq "enc mismatch removed its temp dir" "$(ls "$ROOT/tmpd")" ""
# 2,000-entry tree: one listing serves every row; glob and exact rows that match only late entries.
mkdir -p tools/many; i=0; while [ "$i" -lt 2000 ]; do i=$((i + 1)); : >"tools/many/f$(printf '%04d' "$i").txt"; done
git add tools/many; commit "2000 files"
{ printf 'tools/*.sh\ttools/test_foo.sh\ntools/many/f2000*\ttools/test_foo.sh\n'
  i=0; while [ "$i" -lt 2000 ]; do i=$((i + 40)); printf 'tools/many/f%04d.txt\ttools/many/f%04d.txt\n' "$i" "$((2001 - i))"; done; } |
  LC_ALL=C sort >tools/code-gate/test-map.tsv
eq "2000-entry tree listed in full" "$(cg_files WORKTREE | tr '\0' '\n' | grep -c '^tools/many/')" 2000
out="$(cg_check_map WORKTREE 2>"$ROOT/e")"; rc=$?; eq "2000-entry tree, 52 rows: rc 0" "$rc" 0; eq "2000-entry tree: no problems" "$out" ""
hasnt "2000-entry tree: no STALE-MAP-DIAG" "$(cat "$ROOT/e")" "STALE-MAP"
git add tools/code-gate/test-map.tsv; commit "many rows"; eq "2000-entry tree at HEAD (ls-tree): rc 0" "$(cg_check_map HEAD >/dev/null; echo $?)" 0
printf 'tools/many/f9999.txt\ttools/test_foo.sh\n' >>tools/code-gate/test-map.tsv
out="$(cg_check_map WORKTREE 2>"$ROOT/e")"; rc=$?; eq "2000-entry tree, one stale row: rc 1" "$rc" 1
eq "only the stale row is reported" "$out" "STALE-MAP: source 'tools/many/f9999.txt' matches no file"
eq "one STALE-MAP-DIAG line with the entry count" "$(grep -c '^STALE-MAP-DIAG: rev=WORKTREE rows=53 entries=20' "$ROOT/e")" 1

# L698: a map that exists but whose `git show` fails must not read as "no rows" (fail closed), while
# an absent map or a map of only comments stays an empty list; cg_tests_for / cg_is_test / cg_check_map propagate it.
mkfix; GITREAL="$(command -v git)"; mkdir -p "$ROOT/shim"
printf '#!/usr/bin/env bash\ncase "$*" in *"show HEAD:tools/code-gate/test-map.tsv"*) echo "fatal: injected" >&2; exit 128 ;; esac\nexec "%s" "$@"\n' "$GITREAL" >"$ROOT/shim/git"; chmod +x "$ROOT/shim/git"
(PATH="$ROOT/shim:$PATH"; cg_map_rows HEAD >/dev/null 2>&1); eq "cg_map_rows: failed git show returns non-zero" "$([ $? != 0 ] && echo yes || echo no)" yes
(PATH="$ROOT/shim:$PATH"; cg_tests_for HEAD tools/foo.sh >/dev/null 2>&1); eq "cg_tests_for: failed map read returns non-zero" "$([ $? != 0 ] && echo yes || echo no)" yes
(PATH="$ROOT/shim:$PATH"; cg_is_test HEAD tools/foo.sh >/dev/null 2>&1); eq "cg_is_test: failed map read is not a test" "$([ $? != 0 ] && echo yes || echo no)" yes
out="$(PATH="$ROOT/shim:$PATH" cg_check_map HEAD 2>/dev/null)"; rc=$?; eq "cg_check_map: failed map read: rc 2" "$rc" 2; has "cg_check_map: LIST-FAIL names the map" "$out" "LIST-FAIL: cannot read test-map.tsv"
eq "cg_map_rows: good map at HEAD still lists rows" "$(cg_map_rows HEAD | grep -c .)" 4
printf '# only a comment\n' >tools/code-gate/test-map.tsv; commit "comment-only map"
cg_map_rows HEAD >/dev/null; eq "cg_map_rows: comment-only map is an empty list, rc 0" "$?" 0
git rm -q tools/code-gate/test-map.tsv; commit "no map"
cg_map_rows HEAD >/dev/null; eq "cg_map_rows: absent map is an empty list, rc 0" "$?" 0
# scope.conf read goes through a here-string: a failed read of scope.conf fails scope load.
(PATH="$ROOT/shim:$PATH"; cg_scope_load nosuchrev >/dev/null 2>&1); eq "cg_scope_load: unreadable rev fails" "$([ $? != 0 ] && echo yes || echo no)" yes
eq "lib.sh has no process substitution and no dead cg_grandfathered" "$(grep -c '< <(\|^cg_grandfathered' "$REAL/tools/code-gate/lib.sh")" 0

# L715: cg_timeout_for reads the optional third column; the largest value on rows naming the test wins.
mkfix
printf 'tools/a.sh\ttools/test_foo.sh\ttimeout=300\ntools/b.sh\ttools/test_foo.sh\ttimeout=500\ntools/c.sh\ttools/test_foo.sh\ntools/foo.sh\ttools/t2.sh\n' | LC_ALL=C sort >tools/code-gate/test-map.tsv
eq "cg_timeout_for: largest declared value wins" "$(cg_timeout_for WORKTREE tools/test_foo.sh)" 500
eq "cg_timeout_for: no declaration prints nothing" "$(cg_timeout_for WORKTREE tools/t2.sh)" ""
eq "cg_tests_for ignores the third column" "$(cg_tests_for WORKTREE tools/a.sh)" "tools/test_foo.sh"
cg_is_test WORKTREE tools/t2.sh && pass "cg_is_test sees a test that has a third column" || fail "cg_is_test sees a test that has a third column"
printf 'tools/foo.sh\ttools/test_foo.sh\ttimeout=0\n' >tools/code-gate/test-map.tsv
out="$(cg_check_map WORKTREE)"; rc=$?; eq "timeout=0 rejected: rc 1" "$rc" 1; has "timeout=0 is MALFORMED-MAP" "$out" "MALFORMED-MAP: bad third column"

# The REAL map and grandfather list: well-formed, and grandfathered.txt == the measured inventory.
cd "$REAL" || exit 1
out="$(cg_check_map HEAD)"; eq "real test-map.tsv is well-formed at HEAD" "$?" 0
eq "real grandfathered.txt == --inventory HEAD" "$("$REAL/tools/code-gate/run-mapped-tests.sh" --inventory HEAD)" "$(git show HEAD:tools/code-gate/grandfathered.txt | grep -Ev '^[[:space:]]*(#|$)')"
finish
