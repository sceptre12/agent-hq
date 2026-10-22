#!/usr/bin/env bash
# tools/code-gate/test_run-mapped-features.sh — feature tests for run-mapped-tests.sh and lib.sh: the passing-test
# skip-line echo (L719), the grandfather check on a list larger than a pipe buffer (L728) and the per-test timeout
# from the map's optional third column (L715). Kept apart from test_run-mapped-tests.sh, which already sits near the
# gate's default 120 s per-test limit. Hermetic: every case builds a NON-EMPTY mktemp fixture repo.
set -uo pipefail
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_PREFIX
REAL="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ROOT="$(mktemp -d)"; trap 'rm -rf "$ROOT"' EXIT
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
RT="$REAL/tools/code-gate/run-mapped-tests.sh"
# rt <base> <head> — sets out / err / rc.
rt() { out="$("$RT" "$@" 2>"$ROOT/err")"; rc=$?; err="$(cat "$ROOT/err")"; verdict="${out##*$'\n'}"; }
branch() { git checkout -q -b wt/x; }
# A passing test's `skip` lines are shown under its ok line (re-added; was dropped when #24 superseded the gate hunk).
mkfix; branch; printf '#!/usr/bin/env bash\necho "skip smoke: no docker"\necho "skipped-not-shown"\n[ "$(./tools/foo.sh)" = foo ]\n' >tools/test_foo.sh; commit
rt main HEAD; eq "skip line, passing test: rc 0" "$rc" 0; has "skip line echoed under ok" "$out" $'ok   tools/test_foo.sh\n     skip smoke: no docker'
hasnt "skip line, passing test: non-skip output not echoed" "$out" "skipped-not-shown"
# L719: skip lines are capped at 10 and only `skip` / `skip <text>` lines count (not `skipping`).
mkfix; branch; { echo '#!/usr/bin/env bash'; for i in $(seq 1 12); do echo "echo \"skip case-$i\""; done; echo 'echo "skipping-not-a-skip"'; echo '[ "$(./tools/foo.sh)" = foo ]'; } >tools/test_foo.sh; commit
rt main HEAD; eq "12 skip lines, passing test: rc 0" "$rc" 0; has "skip 10 shown" "$out" "     skip case-10"
hasnt "skip 11 capped" "$out" "case-11"; hasnt "'skipping' is not a skip line" "$out" "skipping-not-a-skip"

# L728: the grandfather-list membership test must not use `printf | grep -q` (SIGPIPE 141 under pipefail on a
# list bigger than a pipe buffer made a listed file read as unlisted). A ~370 KB list with the touched file sorts first (gf_read sorts the list).
mkfix
PAD="$(printf 'x%.0s' $(seq 1 560))"   # 600 long rows (~370 KB): fast to process, still larger than a pipe buffer
{ echo tools/foo.sh; i=0; while [ "$i" -lt 600 ]; do i=$((i + 1)); printf 'zzz/pad-%04d-%s.sh\n' "$i" "$PAD"; done; echo legacy/old.sh; } >tools/code-gate/grandfathered.txt
git add -A; git commit -qm "big list"; branch; echo "# e" >>tools/foo.sh; commit
rt main HEAD; eq "big list, mapped file still listed: rc 1" "$rc" 1
has "big list: listed file detected (still_listed)" "$out" "GRANDFATHERED-TOUCHED:tools/foo.sh(still_listed)"

# L715: per-test timeout from the map's optional third column `timeout=<seconds>`.
tmap() { # tmap <third-column-or-empty>  — rewrite the map's foo row; test_foo.sh sleeps 4 s then passes
  { printf '%s' "$CFGMAP"; printf 'tools/foo.sh\ttools/test_foo.sh%s\n' "${1:+$'\t'$1}"; } >tools/code-gate/test-map.tsv
  printf '#!/usr/bin/env bash\nsleep 4\n[ "$(./tools/foo.sh)" = foo ]\n' >tools/test_foo.sh; commit "timeout col"
}
mkfix; branch; tmap "timeout=1"; rt main HEAD
eq "map timeout=1, 4 s test: rc 1" "$rc" 1; has "TEST-TIMEOUT uses the map value" "$out" "TEST-TIMEOUT:tools/test_foo.sh(1s)"
mkfix; branch; tmap "timeout=30"; rt main HEAD
eq "map timeout=30, 4 s test: rc 0" "$rc" 0; eq "map timeout=30: PASS" "$verdict" "CODE-GATE: PASS n_run=1"
mkfix; branch; tmap "timeout=30"; CODE_GATE_TIMEOUT=1 rt main HEAD
eq "CODE_GATE_TIMEOUT env overrides the map column: rc 1" "$rc" 1; has "env value reported" "$out" "TEST-TIMEOUT:tools/test_foo.sh(1s)"
mkfix; branch; tmap "timeout=abc"; rt main HEAD
eq "bad third column: rc 1" "$rc" 1; has "bad third column is MALFORMED-MAP" "$out" "MALFORMED-MAP"
mkfix; branch; tmap "timeout=5	extra"; rt main HEAD
eq "four-column row: rc 1" "$rc" 1; has "four-column row is MALFORMED-MAP" "$out" "MALFORMED-MAP"
mkfix; branch; tmap ""; rt main HEAD
eq "two-column row still valid (default 120 s): rc 0" "$rc" 0

finish
