#!/usr/bin/env bash
# tools/code-gate/test_run-mapped-tests.sh — tests for run-mapped-tests.sh (and lib.sh) and the
# runner contract (shebang + executable, 120s watchdog timeout, exit code, CODE-GATE verdict line).
# Hermetic: every case builds a NON-EMPTY mktemp fixture repo (mapped pair, grandfathered file,
# real gate scripts); nothing touches the real repo, network, ports or a database.
# Each blocking path (UNMAPPED, STALE-MAP, LIST-FAIL, GRANDFATHER-GROWTH, GRANDFATHERED-TOUCHED, failing test,
# timeout, not-runnable test) has a case that must FAIL and a sibling case that must PASS.
set -uo pipefail
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_PREFIX
REAL="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ROOT="$(mktemp -d "${TMPDIR:-/tmp}/test_run-mapped-tests.XXXXXX")"; trap 'rm -rf "$ROOT"' EXIT
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

# PR #32 A10/A11: the real map carries timeout= for the slow suites (read via lib.sh from the checked-out files).
tmo() { (cd "$REAL" && . tools/code-gate/lib.sh && cg_timeout_for WORKTREE "$1"); }
eq "real map: test_run-mapped-tests.sh timeout 600" "$(tmo tools/code-gate/test_run-mapped-tests.sh)" 600
eq "real map: test_run-mapped-features.sh timeout 240" "$(tmo tools/code-gate/test_run-mapped-features.sh)" 240
eq "real map: a fast suite has no timeout (default 120)" "$(tmo tools/code-gate/test_scope.sh)" ""
eq "real map checks clean" "$(cd "$REAL" && . tools/code-gate/lib.sh && cg_check_map WORKTREE; echo rc=$?)" "rc=0"

mkfix; branch; echo "# doc" >>README.md; commit
rt main HEAD; eq "doc-only change: rc 0" "$rc" 0; eq "doc-only: n_run=0 verdict" "$verdict" "CODE-GATE: PASS n_run=0"

mkfix; branch; echo "# edit" >>tools/foo.sh; commit
rt main HEAD; eq "mapped source edit, test passes: rc 0" "$rc" 0; eq "mapped pass verdict" "$verdict" "CODE-GATE: PASS n_run=1"

mkfix; branch; printf '#!/usr/bin/env bash\necho bar\n' >tools/foo.sh; commit
rt main HEAD; eq "mapped test fails: rc 1" "$rc" 1; has "failing test named in verdict" "$out" "failed=TEST-FAILED:tools/test_foo.sh(rc=1)"

mkfix; branch; printf '#!/usr/bin/env bash\necho n\n' >tools/new.sh; chmod +x tools/new.sh; commit
rt main HEAD; eq "unmapped new source: rc 1" "$rc" 1; has "UNMAPPED named" "$out" "UNMAPPED:tools/new.sh"
echo "tools/new.sh	tools/test_foo.sh" >>tools/code-gate/test-map.tsv; commit "map it"
rt main HEAD; eq "same file once mapped: rc 0" "$rc" 0

mkfix; branch; git rm -q tools/test_foo.sh; commit
rt main HEAD; eq "deleted mapped test: rc 1" "$rc" 1; has "STALE-MAP for the missing test" "$out$err" "STALE-MAP"
mkfix; branch; git rm -q tools/foo.sh; commit
rt main HEAD; eq "deleted mapped source: rc 1" "$rc" 1; has "STALE-MAP for the missing source" "$err" "STALE-MAP:_source_'tools/foo.sh'"

mkfix; branch; echo "legacy/other.sh" >>tools/code-gate/grandfathered.txt; commit
rt main HEAD; eq "grandfather growth: rc 1" "$rc" 1; has "GRANDFATHER-GROWTH named" "$out" "GRANDFATHER-GROWTH:legacy/other.sh"
mkfix; branch; : >tools/code-gate/grandfathered.txt; commit
rt main HEAD; eq "grandfather shrink: rc 0" "$rc" 0
# Growth check (pure bash, no comm/process substitution): every added row is named, also next to a shrink.
mkfix; branch; printf 'a/x.sh\nlegacy/old.sh\nzz/y.sh\n' >tools/code-gate/grandfathered.txt; commit
rt main HEAD; eq "two rows grown: rc 1" "$rc" 1; has "both grown rows named" "$out" "GRANDFATHER-GROWTH:a/x.sh zz/y.sh"
mkfix; branch; printf 'legacy/new.sh\n' >tools/code-gate/grandfathered.txt; commit
rt main HEAD; eq "shrink + growth: rc 1" "$rc" 1; has "swapped row is growth" "$out" "GRANDFATHER-GROWTH:legacy/new.sh"
mkfix; branch; printf '# only a comment\n' >tools/code-gate/grandfathered.txt; commit
rt main HEAD; eq "comment-only list (grep rc 1) is an empty list, not a failure: rc 0" "$rc" 0
# A grandfather comparison input that cannot be built (sort -u fails) dies; it is never an empty list.
mkfix; branch; echo "# e" >>tools/foo.sh; commit; mkdir -p "$ROOT/sbin"; SORTBIN="$(command -v sort)"
printf '#!/usr/bin/env bash\n[ "$*" = -u ] && { echo "sort: injected" >&2; exit 2; }\nexec "%s" "$@"\n' "$SORTBIN" >"$ROOT/sbin/sort"; chmod +x "$ROOT/sbin/sort"
PATH="$ROOT/sbin:$PATH" rt main HEAD; eq "sort fails: rc 1" "$rc" 1; has "sort failure dies" "$err" "run-mapped-tests: cannot read grandfather list at"
hasnt "sort failure: no PASS" "$verdict" "PASS"

mkfix; branch; echo "# edit" >>legacy/old.sh; commit
rt main HEAD; eq "touched grandfathered file: rc 1" "$rc" 1; has "GRANDFATHERED-TOUCHED named" "$out" "GRANDFATHERED-TOUCHED:legacy/old.sh"
printf '%slegacy/old.sh\ttools/test_foo.sh\ntools/foo.sh\ttools/test_foo.sh\n' "$CFGMAP" | LC_ALL=C sort >tools/code-gate/test-map.tsv; commit "map only"
rt main HEAD; eq "row added but still listed: rc 1" "$rc" 1; has "still_listed named" "$out" "still_listed"
: >tools/code-gate/grandfathered.txt; commit "unlist"
rt main HEAD; eq "row added and unlisted: rc 0" "$rc" 0; eq "its mapped test ran" "$verdict" "CODE-GATE: PASS n_run=1"

mkfix; branch; printf '#!/usr/bin/env bash\nsleep 30\n' >tools/test_foo.sh; commit
t0=$(date +%s); CODE_GATE_TIMEOUT=1 rt main HEAD; t1=$(date +%s)
eq "hung test: rc 1" "$rc" 1; has "TEST-TIMEOUT named" "$out" "TEST-TIMEOUT:tools/test_foo.sh(1s)"
[ $((t1 - t0)) -lt 15 ] && pass "watchdog killed the test within 15s" || fail "watchdog too slow ($((t1 - t0))s)"

mkfix; branch; chmod -x tools/test_foo.sh; echo "# e" >>tools/foo.sh; commit
rt main HEAD; eq "non-executable test: rc 1" "$rc" 1; has "not_executable named" "$out" "TEST-NOT-RUNNABLE:tools/test_foo.sh(not_executable"
has "not-runnable test: n_run != mapped BLOCK line" "$out" "CODE-GATE: BLOCK n_run=0 mapped=1"
mkfix; branch; printf 'echo noshebang\n' >tools/test_foo.sh; chmod +x tools/test_foo.sh; commit
rt main HEAD; eq "test without shebang: rc 1" "$rc" 1; has "no_shebang named" "$out" "(no_shebang)"

mkfix; branch; echo "# e" >>tools/test_foo.sh; commit
rt main HEAD; eq "changed test file runs itself: rc 0" "$rc" 0; eq "test file counted" "$verdict" "CODE-GATE: PASS n_run=1"

mkfix; branch; mkdir -p plans/p config
printf '#!/usr/bin/env bash\necho evidence\n' >plans/p/ev.sh; echo '{}' >config/settings.json; commit
rt main HEAD; eq "plans/** script and settings.json are out of scope: rc 0" "$rc" 0; eq "excluded: n_run=0" "$verdict" "CODE-GATE: PASS n_run=0"
printf '#!/usr/bin/env bash\necho x\n' >tools/hookx; chmod 755 tools/hookx; commit "exec no ext"
rt main HEAD; eq "extensionless 100755 file is in scope (UNMAPPED): rc 1" "$rc" 1; has "UNMAPPED hookx" "$out" "UNMAPPED:tools/hookx"
chmod 644 tools/hookx; commit "plain mode"
rt main HEAD; eq "same file at 100644 is out of scope: rc 0" "$rc" 0

mkfix; branch; printf 'tools/foo.sh\ttools/test_foo.sh\ntools/aaa.sh\ttools/test_foo.sh\n' >tools/code-gate/test-map.tsv
printf '#!/usr/bin/env bash\n:\n' >tools/aaa.sh; chmod +x tools/aaa.sh; commit
rt main HEAD; eq "unsorted map: rc 1" "$rc" 1; has "MALFORMED-MAP named" "$out" "MALFORMED-MAP"

mkfix; branch; echo "# e" >>tools/foo.sh; commit
rt main nosuchref; eq "unknown head fails closed: rc 1" "$rc" 1; has "unknown head verdict" "$out" "CODE-GATE: FAIL"
git rm -q tools/code-gate/scope.conf; commit "no scope"
rt main HEAD; eq "scope.conf deleted at head: still blocked (base scope applies): rc 1" "$rc" 1
has "deleting gate config orphans its map row" "$out" "STALE-MAP:_source_'tools/code-gate/scope.conf'"
git checkout -q --orphan bare; git rm -rqf .; echo x >x.txt; git add x.txt; git commit -qm "no gate anywhere"
rt bare bare; eq "no scope.conf at base nor head fails closed: rc 1" "$rc" 1
has "scope error named" "$out" "ERROR:no usable tools/code-gate/scope.conf at base or head"

# --- Fable T2 item 1: scope comes from BASE. A head that excludes its own new file is still gated (H2).
mkfix; branch; printf 'exclude tools/evil*\nexclude tools/foo.sh\n' >>tools/code-gate/scope.conf
printf '#!/usr/bin/env bash\necho evil\n' >tools/evil.sh; echo '# unreviewed' >>tools/foo.sh; commit
rt main HEAD; eq "H2: head scope.conf excluding evil.sh: rc 1" "$rc" 1; has "H2: base scope still sees evil.sh" "$out" "UNMAPPED:tools/evil.sh"
has "H2: foo.sh's test still ran (n_run=1)" "$verdict" "n_run=1"
# bootstrap: base predates the gate (no scope.conf) -> head's scope is used.
mkfix; git checkout -q --orphan pre; git rm -rqf .; echo r >README.md; git add README.md; git commit -qm pre; PRE=$(git rev-parse HEAD)
git checkout -q main; rt "$PRE" main; eq "bootstrap (base has no scope.conf): rc 1" "$rc" 1
has "bootstrap uses head's scope (gate scripts in scope, unmapped in this fixture)" "$out" "UNMAPPED:tools/code-gate/lib.sh"
has "bootstrap ran the mapped test" "$out" "ok   tools/test_foo.sh"

# --- Fable T2 item 2: gate config is in scope; bare `*`/`**` source globs are MALFORMED-MAP (H17).
mkfix; branch; printf 'legacy/old.sh\n' >tools/code-gate/grandfathered.txt; echo '# c' >>tools/code-gate/grandfathered.txt; commit
rt main HEAD; eq "config-only change runs the config's mapped test: rc 0" "$rc" 0; eq "config change counted" "$verdict" "CODE-GATE: PASS n_run=1"
mkfix; branch; printf 'tools/code-gate/grandfathered.txt\ttools/test_foo.sh\ntools/code-gate/scope.conf\ttools/test_foo.sh\ntools/foo.sh\ttools/test_foo.sh\n' >tools/code-gate/test-map.tsv; commit
rt main HEAD; eq "config file dropped from the map: rc 1" "$rc" 1; has "unmapped config named" "$out" "UNMAPPED:tools/code-gate/test-map.tsv"
for g in '*' '**'; do
  mkfix; branch; { printf '%s\ttools/test_foo.sh\n' "$g"; printf '%s' "$CFGMAP"; printf 'tools/foo.sh\ttools/test_foo.sh\n'; } | LC_ALL=C sort >tools/code-gate/test-map.tsv
  printf '#!/usr/bin/env bash\necho any\n' >tools/anything.sh; commit
  rt main HEAD; eq "H17: bare '$g' source glob: rc 1" "$rc" 1; has "H17: MALFORMED-MAP for '$g'" "$out" "MALFORMED-MAP:_source_glob_'$g'"
done

# --- Fable T2 item 3: NUL-delimited paths (H3): unicode, newline and space names are classified exactly.
for n in "tools/évil.sh" "tools/a
b.sh" "tools/a b.sh"; do
  mkfix; branch; printf '#!/bin/sh\necho evil\n' >"$n"; commit
  rt main HEAD; eq "H3: unmapped '$(printf '%s' "$n" | tr '\n' '?')' (100644): rc 1" "$rc" 1; has "H3: UNMAPPED named" "$out" "UNMAPPED:$(printf '%s' "$n" | tr '\n' '?')"
done
mkfix; branch; printf '#!/bin/sh\necho u\n' >"tools/é.sh"; printf '%stools/foo.sh\ttools/test_foo.sh\ntools/é.sh\ttools/test_foo.sh\n' "$CFGMAP" >tools/code-gate/test-map.tsv; commit
rt main HEAD; eq "unicode name with an exact map row: rc 0" "$rc" 0

# --- Fable T2 item 4: tests run on the pushed blobs (temp worktree of head), not the working tree (H7).
mkfix; branch; printf '#!/usr/bin/env bash\necho bar\n' >tools/foo.sh; commit "broken"
git update-index --assume-unchanged tools/foo.sh; printf '#!/usr/bin/env bash\necho foo\n' >tools/foo.sh
eq "H7 fixture: working tree hides the change" "$(git status --porcelain --untracked-files=no)" ""
rt main HEAD; eq "H7: committed failing foo.sh, fixed working copy: rc 1" "$rc" 1; has "H7: committed blob tested" "$out" "TEST-FAILED:tools/test_foo.sh"
eq "temp worktree removed afterwards" "$(git worktree list | wc -l | tr -d ' ')" 1
git update-index --no-assume-unchanged tools/foo.sh; git checkout -q -f main
rt main wt/x; eq "head need not be checked out: rc 1" "$rc" 1; has "unchecked-out head tested" "$out" "TEST-FAILED:tools/test_foo.sh"

# --- Silent ls-tree failure (T-153): a fake `git` first on PATH fails the FIRST call matching a pattern
# (rc 128 + stderr) and execs the real git otherwise. The map check must say LIST-FAIL, never STALE-MAP.
# fakegit <case-pattern over " $* "> — (re)writes $ROOT/bin/git and resets its counter $ROOT/gitn.
GITBIN="$(command -v git)"
fakegit() {
  mkdir -p "$ROOT/bin"; rm -f "$ROOT/gitn"
  cat >"$ROOT/bin/git" <<EOF
#!/usr/bin/env bash
case " \$* " in $1)
  n=\$(cat "$ROOT/gitn" 2>/dev/null || echo 0); echo \$((n + 1)) >"$ROOT/gitn"
  [ "\$n" != 0 ] || { echo "fatal: injected failure (\$*)" >&2; exit 128; } ;;
esac
exec "$GITBIN" "\$@"
EOF
  chmod +x "$ROOT/bin/git"
}
mkfix; branch; echo "# e" >>tools/foo.sh; commit
fakegit '*" ls-tree "*'; PATH="$ROOT/bin:$PATH" rt main HEAD
eq "ls-tree-fails-once-blocks-LIST-FAIL-never-STALE-MAP: rc 1" "$rc" 1
[ "$(cat "$ROOT/gitn" 2>/dev/null || echo 0)" -ge 1 ] && pass "ls-tree-fails-once: injected failure fired" || fail "ls-tree-fails-once: injected failure fired"
has "ls-tree-fails-once: LIST-FAIL block" "$err" "BLOCK LIST-FAIL:_cannot_list_tree_"
has "ls-tree-fails-once: LIST-FAIL in verdict" "$verdict" "failed=LIST-FAIL:_cannot_list_tree_$(git rev-parse HEAD)_(git_rc_128,_fail_closed)"
hasnt "ls-tree-fails-once: never STALE-MAP (stderr)" "$err" "STALE-MAP"; hasnt "ls-tree-fails-once: never STALE-MAP (stdout)" "$out" "STALE-MAP"
rt main HEAD; eq "same fixture, real git: rc 0" "$rc" 0; hasnt "real git: no LIST-FAIL" "$out$err" "LIST-FAIL"
mkfix; branch; git rm -q tools/foo.sh; commit
rt main HEAD; has "normal path: deleted mapped source still STALE-MAP" "$err" "STALE-MAP:_source_'tools/foo.sh'"
has "STALE-MAP-DIAG on stderr" "$err" "STALE-MAP-DIAG: rev=$(git rev-parse HEAD) rows=4 entries="; hasnt "DIAG never in the verdict" "$verdict" "DIAG"
mkfix; branch; echo "# e" >>tools/foo.sh; commit
fakegit '*" show "*grandfathered.txt*'; PATH="$ROOT/bin:$PATH" rt main HEAD
eq "grandfather read fails: rc 1" "$rc" 1; eq "grandfather read failure fired once" "$(cat "$ROOT/gitn" 2>/dev/null)" 1
has "grandfather read fails closed (die)" "$err" "run-mapped-tests: cannot read grandfather list at $(git rev-parse HEAD)"
hasnt "grandfather read failure is not a false growth block" "$out$err" "GRANDFATHER-GROWTH"
fakegit '*" ls-tree main "*grandfathered.txt*'; PATH="$ROOT/bin:$PATH" rt main HEAD
eq "base-side grandfather read fails: rc 1" "$rc" 1; has "base read fails closed" "$err" "cannot read grandfather list at main"

# stdin (T-159, generic): N mapped tests, the FIRST reads stdin to EOF; the gate gets a sentinel on its own
# stdin. Every test must still run (n_run == N) and the reader must see neither the sentinel nor the test list.
stdin_fix() {
  mkfix; branch
  printf '#!/usr/bin/env bash\necho a\n' >tools/aaa.sh; printf '#!/usr/bin/env bash\necho b\n' >tools/bbb.sh
  printf '#!/usr/bin/env bash\ncat >"%s/seen"\n[ "$(./tools/aaa.sh)" = a ]\n' "$ROOT" >tools/test_aaa.sh
  printf '#!/usr/bin/env bash\n[ "$(./tools/bbb.sh)" = b ]\n' >tools/test_bbb.sh
  echo "# e" >>tools/foo.sh; chmod +x tools/*.sh
  printf '%stools/aaa.sh\ttools/test_aaa.sh\ntools/bbb.sh\ttools/test_bbb.sh\ntools/foo.sh\ttools/test_foo.sh\n' "$CFGMAP" |
    LC_ALL=C sort >tools/code-gate/test-map.tsv; commit; rm -f "$ROOT/seen"
}
stdin_fix; rt main HEAD <<<'SENTINEL'
eq "stdin-reading test first: rc 0" "$rc" 0; eq "stdin-reading test: all 3 mapped tests ran" "$verdict" "CODE-GATE: PASS n_run=3"
has "the stdin-reading test ran" "$out" "ok   tools/test_aaa.sh"; has "a later test ran" "$out" "ok   tools/test_foo.sh"
eq "the reader saw an empty stdin (no sentinel, no test list)" "$(cat "$ROOT/seen" 2>/dev/null || echo MISSING)" ""
# Fail-closed count: a gate whose loop is cut short (the pre-T-159 inherited stdin, re-created by
# deleting the </dev/null) must BLOCK, never PASS with n_run < mapped.
mkdir -p "$ROOT/mut"; cp "$REAL/tools/code-gate/lib.sh" "$ROOT/mut/"
sed 's#( exec "./$t" ) </dev/null >#( exec "./$t" ) >#' "$RT" >"$ROOT/mut/run-mapped-tests.sh"; chmod +x "$ROOT/mut/run-mapped-tests.sh"
eq "mutant differs from the gate in exactly one line" "$(diff "$RT" "$ROOT/mut/run-mapped-tests.sh" | grep -c '^<')" 1
stdin_fix; RT_SAVE=$RT; RT="$ROOT/mut/run-mapped-tests.sh"; rt main HEAD <<<'SENTINEL'; RT=$RT_SAVE
eq "truncated run: rc 1" "$rc" 1; has "truncated run: BLOCK line" "$out" "CODE-GATE: BLOCK n_run=1 mapped=3"
has "truncated run: FAIL verdict names the mismatch" "$verdict" "COUNT-MISMATCH:n_run=1,mapped=3"; hasnt "truncated run: no PASS" "$out" "PASS"

# Failure output: assertions first, short output in full, long output tailed to 60 lines.
mkfix; branch
{ echo '#!/usr/bin/env bash'; echo 'for i in $(seq 1 30); do echo "body-line-$i"; done'; echo 'echo "not ok 7-something"'; echo 'exit 1'; } >tools/test_foo.sh; commit "fail short"
rt main HEAD; eq "failing 30-line stub: rc 1" "$rc" 1; has "failing assertions header names the test" "$err" "CODE-GATE: failing assertions in tools/test_foo.sh:"
has "header is followed by the not-ok line" "$err" $'tools/test_foo.sh:\nnot ok 7-something'; has "full body kept (first line)" "$err" "body-line-1"$'\n'; has "full body kept (line 30)" "$err" "body-line-30"
has "TEST-FAILED summary unchanged" "$err" "BLOCK TEST-FAILED:tools/test_foo.sh(rc=1)"; has "FAIL verdict unchanged" "$verdict" "CODE-GATE: FAIL n_run=1 failed=TEST-FAILED:tools/test_foo.sh(rc=1)"
mkfix; branch
{ echo '#!/usr/bin/env bash'; echo 'for i in $(seq 1 250); do echo "long-line-$i"; done'; echo 'exit 1'; } >tools/test_foo.sh; commit "fail long"
rt main HEAD; hasnt "250-line stub: no header without not-ok/FAIL lines" "$err" "failing assertions"
{ echo '#!/usr/bin/env bash'; echo 'echo "FAIL: early-assertion"'; echo 'for i in $(seq 1 250); do echo "long-line-$i"; done'; echo 'exit 1'; } >tools/test_foo.sh; commit "fail long2"
rt main HEAD; has "250-line stub: header shows the early FAIL line" "$err" $'failing assertions in tools/test_foo.sh:\nFAIL: early-assertion'
has "last line shown" "$err" "long-line-250"; has "line 191 shown (last 60)" "$err" "long-line-191"$'\n'; hasnt "line 190 not shown" "$err" "long-line-190"$'\n'
eq "output is header+assertion plus 60 lines" "$(printf '%s\n' "$err" | grep -c 'long-line-')" 60

# diff-dies-fails-closed: a dying `git diff --raw` must be DIFF-FAIL, never "nothing in scope changed" (PASS n_run=0).
mkfix; branch; echo "# e" >>tools/foo.sh; commit
fakegit '*" diff --raw "*'; PATH="$ROOT/bin:$PATH" rt main HEAD
eq "diff-dies-fails-closed: rc 1" "$rc" 1; eq "diff-dies-fails-closed: verdict" "$verdict" "CODE-GATE: FAIL n_run=0 failed=DIFF-FAIL"
has "diff-dies-fails-closed: BLOCK DIFF-FAIL on stderr" "$err" "BLOCK DIFF-FAIL"; hasnt "diff-dies-fails-closed: never PASS" "$out" "PASS"
rt main HEAD; eq "diff-dies: same fixture, real git: rc 0" "$rc" 0
# diff-dies-on-file-list-fails-closed: the SECOND `git diff --raw` (the per-file list) dies; the first succeeds.
cat >"$ROOT/bin/git" <<FAKE
#!/usr/bin/env bash
case " \$* " in *" diff --raw "*)
  n=\$(cat "$ROOT/gitn" 2>/dev/null || echo 0); echo \$((n + 1)) >"$ROOT/gitn"
  [ "\$n" != 1 ] || { echo "fatal: injected failure (\$*)" >&2; exit 128; } ;;
esac
exec "$GITBIN" "\$@"
FAKE
chmod +x "$ROOT/bin/git"; rm -f "$ROOT/gitn"; PATH="$ROOT/bin:$PATH" rt main HEAD
eq "diff-dies-on-file-list-fails-closed: rc 1" "$rc" 1; eq "diff-dies-on-file-list-fails-closed: second call fired" "$(cat "$ROOT/gitn")" 2
has "diff-dies-on-file-list-fails-closed: verdict" "$verdict" "CODE-GATE: FAIL n_run=0 failed=DIFF-FAIL"; has "diff-dies-on-file-list-fails-closed: BLOCK" "$err" "BLOCK DIFF-FAIL"
# cfg-diff-dies-fails-closed: the `git diff --name-only` (gate config files) dies; the --raw diffs succeed.
mkfix; branch; echo "# c" >>tools/foo.sh; commit
fakegit '*" diff --name-only "*'; PATH="$ROOT/bin:$PATH" rt main HEAD
eq "cfg-diff-dies-fails-closed: rc 1" "$rc" 1; has "cfg-diff-dies-fails-closed: verdict" "$verdict" "CODE-GATE: FAIL n_run=0 failed=DIFF-FAIL"
has "cfg-diff-dies-fails-closed: BLOCK DIFF-FAIL" "$err" "BLOCK DIFF-FAIL"; hasnt "cfg-diff-dies-fails-closed: never PASS" "$out" "PASS"
rt main HEAD; eq "cfg-diff-dies: same fixture, real git: rc 0" "$rc" 0
# PR #32 A5: cg_timeout_for rc 2 (map unreadable for the timeout lookup) is a BLOCK, not a silent 120 s fallback.
# The runner is run from a copy of the gate whose cg_timeout_for always returns 2 (check_map still passes).
mkfix; branch; echo "# edit" >>tools/foo.sh; commit
GC="$ROOT/gate-rc2"; mkdir -p "$GC"; cp "$REAL"/tools/code-gate/{lib.sh,run-mapped-tests.sh,scope.conf} "$GC/"
printf '\ncg_timeout_for() { return 2; }\n' >>"$GC/lib.sh"
out="$(bash "$GC/run-mapped-tests.sh" main HEAD 2>"$ROOT/err")"; rc=$?; err="$(cat "$ROOT/err")"
eq "timeout lookup rc 2: rc 1 (blocked)" "$rc" 1; has "timeout lookup rc 2: named" "$err" "BLOCK MALFORMED-MAP:timeout_lookup(tools/test_foo.sh)"
hasnt "timeout lookup rc 2: the test did not run on a 120s fallback" "$out" "ok   tools/test_foo.sh"
out="$(env CODE_GATE_TIMEOUT=30 bash "$GC/run-mapped-tests.sh" main HEAD 2>/dev/null)"; rc=$?
eq "sibling: CODE_GATE_TIMEOUT set skips the lookup, passes" "$rc" 0

finish
