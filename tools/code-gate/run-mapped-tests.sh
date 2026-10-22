#!/usr/bin/env bash
# tools/code-gate/run-mapped-tests.sh <base> <head>   |   --inventory <rev>
# Resolves the in-scope files changed in base..head to their mapped tests, runs them, and prints
# the verdict line `CODE-GATE: PASS n_run=<k>` or `CODE-GATE: FAIL n_run=<k> failed=<list>`; when
# n_run != the mapped test count it first prints `CODE-GATE: BLOCK n_run=<k> mapped=<m>` (COUNT-MISMATCH).
# Exit 0 = PASS, 1 = FAIL (any error fails closed). Blocks: UNMAPPED, STALE-MAP / MALFORMED-MAP,
# DIFF-FAIL (git diff --raw died, so the changed-file list is untrustworthy; fails closed, never a PASS n_run=0),
# LIST-FAIL (the map check could not list head's tree; checked before GRANDFATHER-GROWTH),
# GRANDFATHER-GROWTH, GRANDFATHERED-TOUCHED, TEST-FAILED, TEST-TIMEOUT, TEST-NOT-RUNNABLE; an
# unreadable grandfather list dies (`cannot read grandfather list at <rev>`).
# Scope comes from <base> (head only while base predates the gate); the map and grandfather list
# come from <head>. pre-push runs THIS script from a trusted tree (git archive), never the pushed copy: base's tree for
# main pushes, the origin/main tip for wt/* pushes.
# Tests run inside a detached temp worktree of <head>, so they test the pushed blobs, not the
# working tree (assume-unchanged / skip-worktree / dirty files cannot change what is tested).
# A passing test's `skip …` lines (max 10) are echoed, indented, under its `ok` line, so a skipped case stays visible.
# Runner contract: each test is an executable file with a shebang, run from that worktree's root,
# hermetic, stdin = /dev/null, exit 0 = pass, killed after its timeout (no timeout(1)): $CODE_GATE_TIMEOUT if set,
# else the map's optional third column `timeout=<seconds>` on a row naming the test (largest wins), else 120.
# --inventory <rev|WORKTREE> prints every in-scope, non-test file with no map row (the grandfather
# measurement). See architecture/hq-code-gate.md.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/lib.sh"
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_PREFIX

FAILED=""; TESTS=""; N=0; TWT=""
block() { FAILED="$FAILED${FAILED:+,}$1"; echo "BLOCK $1" >&2; }
verdict() {
  if [ -z "$FAILED" ]; then echo "CODE-GATE: PASS n_run=$N"; exit 0; fi
  echo "CODE-GATE: FAIL n_run=$N failed=$FAILED"; exit 1
}
die() { echo "run-mapped-tests: $1" >&2; block "ERROR:$1"; verdict; }
# show_output <test> <file> — on a failing test: `not ok`/`FAIL` lines first (deduped, max 20), then the
# FULL output when it is <= 200 lines, else the last 60 lines (a 20-line tail lost the failing assertion).
show_output() {
  local fails n; fails="$(grep -E 'not ok|FAIL' "$2" | awk '!seen[$0]++' | head -n 20)"
  [ -z "$fails" ] || { echo "CODE-GATE: failing assertions in $1:" >&2; echo "$fails" >&2; }
  n="$(wc -l <"$2" | tr -d ' ')"
  if [ "$n" -le 200 ]; then cat "$2" >&2; else tail -n 60 "$2" >&2; fi
}
# gf_read <rev> — the grandfather list (sorted, unique), every rc checked: an absent file is an empty
# list; grep rc 1 (no rows) is an empty list; a failed git read, grep rc >= 2 or a failed sort returns
# non-zero (the caller dies), never an empty list read as growth or a pass.
gf_read() {
  local ent txt rows rc
  ent="$(git ls-tree "$1" "$CG_DIR/grandfathered.txt")" || return 1
  [ -n "$ent" ] || return 0
  txt="$(git show "$1:$CG_DIR/grandfathered.txt")" || return 1
  rows="$(printf '%s\n' "$txt" | grep -Ev '^[[:space:]]*(#|$)')"; rc=$?
  [ "$rc" -le 1 ] || return 1
  [ -n "$rows" ] || return 0
  printf '%s\n' "$rows" | sort -u      # pipefail: sort's status is the function's status
}
add_test() { case $'\n'"$TESTS" in *$'\n'"$1"$'\n'*) ;; *) TESTS="$TESTS$1"$'\n' ;; esac; }
cleanup() {
  [ -n "$TWT" ] || return 0
  git -C "$root" worktree remove --force "$TWT" >/dev/null 2>&1; rm -rf "$(dirname "$TWT")"
  git -C "$root" worktree prune >/dev/null 2>&1; return 0
}
trap cleanup EXIT

root="$(git rev-parse --show-toplevel 2>/dev/null)" || die "not in a git repo"
cd "$root" || die "cannot cd to repo root"

if [ "${1:-}" = "--inventory" ]; then
  rev="${2:-HEAD}"
  cg_scope_load "$rev" || { echo "no usable $CG_DIR/scope.conf at $rev" >&2; exit 1; }
  { if [ "$rev" = WORKTREE ]; then git ls-files -s -z; else git ls-tree -r -z "$rev"; fi; } |
    while IFS= read -r -d '' rec; do printf '%s\t%s\0' "${rec%% *}" "${rec#*$'\t'}"; done | cg_scoped |
    while IFS= read -r -d '' rec; do
      p="${rec#*$'\t'}"
      cg_is_test "$rev" "$p" && continue
      [ -n "$(cg_tests_for "$rev" "$p")" ] || printf '%s\n' "$p"
    done | LC_ALL=C sort
  exit 0
fi

base="${1:-}"; head="${2:-}"
[ -n "$base" ] && [ -n "$head" ] || die "usage: run-mapped-tests.sh <base> <head>"
git rev-parse --verify -q "$base^{commit}" >/dev/null || die "unknown base $base"
git rev-parse --verify -q "$head^{commit}" >/dev/null || die "unknown head $head"
head="$(git rev-parse "$head^{commit}")"
cg_scope_from "$base" "$head" || die "no usable $CG_DIR/scope.conf at base or head"

# deletions count: they can orphan map rows. A dying git diff is DIFF-FAIL (pipefail carries cg_changed's rc 2), never zero records.
anydiff="$(cg_changed ACMRD "$base" "$head" | cg_scoped | tr '\0' '\n')" || { block "DIFF-FAIL"; verdict; }
cfg="$(git diff --name-only "$base" "$head" -- "$CG_DIR/scope.conf" "$CG_DIR/test-map.tsv" "$CG_DIR/grandfathered.txt")" || { block "DIFF-FAIL"; verdict; }
if [ -z "$anydiff" ] && [ -z "$cfg" ]; then verdict; fi   # nothing in scope changed: PASS n_run=0

# The map check lists head's tree first (its LIST-FAIL is the first ls-tree failure a run can hit).
if ! problems="$(cg_check_map "$head")"; then
  block "$(printf '%s' "$problems" | head -3 | tr '\n' ';' | tr ' ' '_')"
fi
# GRANDFATHER-GROWTH. Skipped only while base has no scope.conf (the gate does not exist yet, so
# the first grandfathered.txt is the one-time measurement, not growth).
GF="$(gf_read "$head")" || die "cannot read grandfather list at $head"
if cg_has "$base" "$CG_DIR/scope.conf"; then
  GB="$(gf_read "$base")" || die "cannot read grandfather list at $base"
  # Pure bash (no process substitution, no external command, so nothing can fail silently): every
  # head-side row that is not a base-side row is growth.
  grown=""; rest="$GF"
  while [ -n "$rest" ]; do
    g=${rest%%$'\n'*}
    case "$rest" in *$'\n'*) rest=${rest#*$'\n'} ;; *) rest="" ;; esac
    [ -n "$g" ] || continue
    case $'\n'"$GB"$'\n' in *$'\n'"$g"$'\n'*) ;; *) grown="$grown${grown:+ }$g" ;; esac
  done
  [ -z "$grown" ] || block "GRANDFATHER-GROWTH:$grown"
fi

recs="$(mktemp)" || die "cannot create a temp file"
cg_changed ACMR "$base" "$head" | cg_scoped >"$recs" || { rm -f "$recs"; block "DIFF-FAIL"; verdict; }
while IFS= read -r -d '' rec; do
  p="${rec#*$'\t'}"; [ -z "$p" ] && continue
  if cg_is_test "$head" "$p"; then add_test "$(cg_show "$p")"; continue; fi
  tests="$(cg_tests_for "$head" "$p")"
  # Bash match, no pipe: `printf | grep -q` under pipefail exits 141 (SIGPIPE) once the list is larger than a pipe buffer.
  listed=0; case $'\n'"$GF"$'\n' in *$'\n'"$p"$'\n'*) listed=1 ;; esac
  if [ -z "$tests" ]; then
    if [ "$listed" = 1 ]; then block "GRANDFATHERED-TOUCHED:$p"; else block "UNMAPPED:$(cg_show "$p")"; fi
  else
    [ "$listed" = 0 ] || block "GRANDFATHERED-TOUCHED:$p(still_listed)"
    while IFS= read -r t; do add_test "$t"; done <<<"$tests"
  fi
done <"$recs"
rm -f "$recs"

[ -n "$TESTS" ] || verdict
# Detached temp worktree of the pushed commit: the tests see exactly the pushed blobs.
TWT="$(mktemp -d)/w"
git worktree add -q --detach "$TWT" "$head" >/dev/null 2>&1 || { TWT=""; die "cannot create a temp worktree of $head"; }
cd "$TWT" || die "cannot cd to temp worktree"

# run_one <test> — runs with a watchdog; rc 124 means timed out.
run_one() {
  local t=$1 limit out pid wd rc flag
  limit="${CODE_GATE_TIMEOUT:-}"
  # rc 2 = the map could not be read for the timeout lookup: a malformed map blocks, never a silent 120 s fallback.
  [ -n "$limit" ] || limit="$(cg_timeout_for "$head" "$t")" || { block "MALFORMED-MAP:timeout_lookup($t)"; return; }
  limit="${limit:-120}"
  out="$(mktemp)"; flag="$out.timeout"
  [ -f "$t" ] && [ -x "$t" ] || { block "TEST-NOT-RUNNABLE:$t(not_executable_or_missing)"; rm -f "$out"; return; }
  [ "$(head -c2 "$t")" = '#!' ] || { block "TEST-NOT-RUNNABLE:$t(no_shebang)"; rm -f "$out"; return; }
  N=$((N + 1))
  ( exec "./$t" ) </dev/null >"$out" 2>&1 &   # stdin = /dev/null: a test that reads stdin must not eat the test list
  pid=$!
  ( i=0
    while [ "$i" -lt "$limit" ]; do sleep 1; kill -0 "$pid" 2>/dev/null || exit 0; i=$((i + 1)); done
    : >"$flag"; pkill -TERM -P "$pid" 2>/dev/null; kill -TERM "$pid" 2>/dev/null
    sleep 2; pkill -KILL -P "$pid" 2>/dev/null; kill -KILL "$pid" 2>/dev/null ) >/dev/null 2>&1 &
  wd=$!
  wait "$pid"; rc=$?
  kill "$wd" 2>/dev/null; wait "$wd" 2>/dev/null
  if [ -f "$flag" ]; then block "TEST-TIMEOUT:$t(${limit}s)"; show_output "$t" "$out"
  elif [ "$rc" -ne 0 ]; then block "TEST-FAILED:$t(rc=$rc)"; show_output "$t" "$out"
  else echo "ok   $t"; grep -E '^skip( |$)' "$out" | head -n 10 | sed 's/^/     /'; fi   # a passing test's skips stay visible
  rm -f "$out" "$flag"
}
# Fail closed on a short run: the expected count comes from the map up front; any test not run
# (a truncated loop, a not-runnable test) makes n_run != mapped, which never PASSes.
M="$(printf '%s' "$TESTS" | grep -c .)" || die "cannot count the mapped tests"
while IFS= read -r t; do [ -n "$t" ] && run_one "$t"; done <<<"$TESTS"
cd "$root" || true
if [ "$N" != "$M" ]; then echo "CODE-GATE: BLOCK n_run=$N mapped=$M"; block "COUNT-MISMATCH:n_run=$N,mapped=$M"; fi
verdict
