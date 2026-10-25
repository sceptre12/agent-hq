#!/usr/bin/env bash
# tools/code-gate/test_pre-push.sh — tests for tools/git-hooks/pre-push. Real `git push` runs from NON-EMPTY
# fixture repos (core.hooksPath=tools/git-hooks) to a local bare origin, with a fake `gh` on PATH.
# Covers: wt/* gating, dispatch on the REMOTE ref (wt/x:main), exact-tree guard (HEAD != pushed sha,
# dirty tracked files; untracked tolerated), failing/unmapped blocks, main needing merge+trailer+marker,
# fail-closed internal error, pass-through of deletions/tags/other refs. --no-verify is exercised ONLY
# in fixtures, as a control proving the hook (not something else) did the blocking.
set -uo pipefail
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_PREFIX
REAL="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ROOT="$(mktemp -d "${TMPDIR:-/tmp}/test_pre-push.XXXXXX")"; trap 'rm -rf "$ROOT"' EXIT
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
mkdir -p "$ROOT/bin"; export FAKE_GH_LOG="$ROOT/gh.log" FAKE_GH_JSON="$ROOT/gh.json"
printf '#!/usr/bin/env bash\necho "$@" >>"$FAKE_GH_LOG"\ncat "$FAKE_GH_JSON"\n' >"$ROOT/bin/gh"
chmod +x "$ROOT/bin/gh"; export PATH="$ROOT/bin:$PATH"
good="CODE-GATE-REVIEW: PASS head=%s blocking=0 medium=0"
setjson() { jq -n --arg o "$1" --arg b "${PRBASE:-main}" --arg s "${PRSTATE:-OPEN}" '{headRefOid: $o, baseRefName: $b, state: $s, comments: ($ARGS.positional | map({body: .}))}' --args "${@:2}" >"$FAKE_GH_JSON"; }
# push <args...> — sets pout / rc (hook output included).
push() { : >"$FAKE_GH_LOG"; pout="$(git push "$@" 2>&1)"; rc=$?; }
remote_has() { git -C "$ORIGIN" rev-parse --verify -q "$1" >/dev/null && echo yes || echo no; }
blocked() { [ "$rc" != 0 ] && echo yes || echo no; }
newbranch() { mkfix; git checkout -q -b wt/x; }
# prmerge — wt/x (already committed) merged --no-ff into main with a trailer; sets SHA2.
prmerge() { git checkout -q main; git merge -q --no-ff wt/x -m $'merge wt/x\n\nCode-Gate-PR: #7'; SHA2="$(git rev-parse HEAD^2)"; }

newbranch; echo "# ok" >>tools/foo.sh; commit; push -u origin wt/x
eq "wt push of a mapped, passing change: rc 0" "$rc" 0; has "tests ran in the hook" "$pout" "CODE-GATE: PASS n_run=1"; eq "branch reached origin" "$(remote_has refs/heads/wt/x)" yes

newbranch; printf '#!/usr/bin/env bash\necho bar\n' >tools/foo.sh; commit; push origin wt/x
eq "wt push with a failing mapped test: blocked" "$(blocked)" yes; has "FAIL verdict shown" "$pout" "CODE-GATE: FAIL"
eq "blocked branch did not reach origin" "$(remote_has refs/heads/wt/x)" no
push --no-verify origin wt/x; eq "CONTROL: --no-verify skips the gate in a fixture (why Rule 10 forbids it)" "$rc" 0

newbranch; printf '#!/usr/bin/env bash\n:\n' >tools/new.sh; chmod +x tools/new.sh; commit; push origin wt/x
eq "wt push with an UNMAPPED file: blocked" "$(blocked)" yes; has "UNMAPPED shown" "$pout" "UNMAPPED:tools/new.sh"

# Fable T2 item 4: no exact-tree/clean-tree guards; the tests run on the PUSHED blobs instead.
newbranch; echo "# ok" >>tools/foo.sh; commit; printf '#!/usr/bin/env bash\necho bar\n' >tools/foo.sh; echo scratch >untracked.txt; push origin wt/x
eq "dirty working tree, good commit: rc 0 (pushed blobs tested)" "$rc" 0; has "pushed foo.sh passed" "$pout" "CODE-GATE: PASS n_run=1"
newbranch; printf '#!/usr/bin/env bash\necho bar\n' >tools/foo.sh; commit; git checkout -q main; push origin wt/x
eq "push while HEAD is elsewhere: still gated, blocked" "$(blocked)" yes; has "unchecked-out branch tested" "$pout" "TEST-FAILED:tools/test_foo.sh"
# H7: commit a failing foo.sh, hide it with assume-unchanged + a passing working copy.
newbranch; printf '#!/usr/bin/env bash\necho bar\n' >tools/foo.sh; commit "broken"; git update-index --assume-unchanged tools/foo.sh
printf '#!/usr/bin/env bash\necho foo\n' >tools/foo.sh; eq "H7 fixture: status is clean" "$(git status --porcelain --untracked-files=no)" ""
push origin wt/x; eq "H7: assume-unchanged hides nothing: blocked" "$(blocked)" yes; has "H7: committed blob failed" "$pout" "TEST-FAILED:tools/test_foo.sh"
eq "H7: blocked branch did not reach origin" "$(remote_has refs/heads/wt/x)" no
eq "H7: no temp worktree left behind" "$(git worktree list | wc -l | tr -d ' ')" 1

# dispatch on the REMOTE ref: a wt branch pushed to main is gated as main (needs merge + trailer + marker).
newbranch; echo "# direct" >>tools/foo.sh; commit; push origin wt/x:main
eq "wt/x:main non-merge code push: blocked" "$(blocked)" yes; has "review gate named" "$pout" "not a 2-parent merge"
eq "main on origin unchanged" "$(git -C "$ORIGIN" rev-parse main)" "$(git rev-parse origin/main)"
push --no-verify origin wt/x:main; eq "CONTROL: same push passes with --no-verify" "$rc" 0

newbranch; echo "# ok" >>tools/foo.sh; commit; prmerge; setjson "$SHA2" "$(printf "$good" "$SHA2")"; push origin main
eq "main push: merge + trailer + marker: rc 0" "$rc" 0; has "both gates reported" "$pout" "CODE-REVIEW: PASS commits=1"
eq "origin main advanced to the merge" "$(git -C "$ORIGIN" rev-parse main)" "$(git rev-parse HEAD)"

newbranch; echo "# ok" >>tools/foo.sh; commit; prmerge; setjson "$SHA2"; push origin main
eq "main push without a marker: blocked" "$(blocked)" yes; has "marker missing named" "$pout" "no CODE-GATE-REVIEW marker"
newbranch; echo "# ok" >>tools/foo.sh; commit; prmerge; setjson "$SHA2" "$(printf "$good" "$SHA2" | sed 's/medium=0/medium=1/')"; push origin main
eq "main push with medium=1 marker: blocked" "$(blocked)" yes
newbranch; printf '#!/usr/bin/env bash\necho bar\n' >tools/foo.sh; commit; prmerge; setjson "$SHA2" "$(printf "$good" "$SHA2")"; push origin main
eq "main push whose merged tree fails its test: blocked" "$(blocked)" yes; has "runner verdict on main" "$pout" "CODE-GATE: FAIL"

mkfix; echo "# doc" >>README.md; commit "docs"; push origin main
eq "doc-only main push: rc 0" "$rc" 0; eq "doc-only main push never calls gh" "$(cat "$FAKE_GH_LOG")" ""

mkfix; git checkout -q -b wt/old; push origin wt/old; push origin :wt/old
eq "branch deletion passes: rc 0" "$rc" 0; eq "branch deleted on origin" "$(remote_has refs/heads/wt/old)" no
mkfix; git tag v1; push origin v1; eq "tag push passes: rc 0" "$rc" 0
newbranch; printf '#!/usr/bin/env bash\necho bar\n' >tools/foo.sh; commit; git checkout -q -b scratch; push origin scratch
eq "non-gated ref (scratch) with a failing test passes: rc 0" "$rc" 0

newbranch; echo "# ok" >>tools/foo.sh; git rm -q tools/code-gate/scope.conf; commit; push origin wt/x
eq "scope.conf deleted in the push: blocked (base scope still applies)" "$(blocked)" yes; has "deletion orphans its row" "$pout" "STALE-MAP"

# Fable T2 item 1: the gate runs from BASE's tree. A push that neuters the gate scripts is judged by
# base's copies (H1-scripts) and base's scope (H2); H7b neuters check-review.sh via skip-worktree.
mkfix; printf '#!/bin/sh\necho "CODE-GATE: PASS n_run=0"\n' >tools/code-gate/run-mapped-tests.sh
printf '#!/bin/sh\necho "CODE-REVIEW: PASS"\n' >tools/code-gate/check-review.sh; printf '#!/bin/sh\necho evil\n' >tools/evil.sh; commit "neuter"
push origin main; eq "H1-scripts: neutered runner + check-review in the push: blocked" "$(blocked)" yes
has "H1-scripts: base runner found evil.sh" "$pout" "UNMAPPED:tools/evil.sh"; hasnt "H1-scripts: pushed runner never ran" "$pout" "CODE-GATE: PASS n_run=0"
mkfix; printf '%stools/code-gate/check-review.sh\ttools/test_foo.sh\ntools/foo.sh\ttools/test_foo.sh\n' "$CFGMAP" | LC_ALL=C sort >tools/code-gate/test-map.tsv; commit "map cr"
git push -q --no-verify origin main; printf '#!/bin/sh\necho "CODE-REVIEW: PASS"\n' >tools/code-gate/check-review.sh; echo '# direct' >>tools/foo.sh; commit "neuter cr"
push origin main; eq "H1-scripts: pushed check-review.sh says PASS: blocked" "$(blocked)" yes; has "H1-scripts: base check-review judged" "$pout" "not a 2-parent merge"
mkfix; printf 'exclude tools/evil*\nexclude tools/foo.sh\n' >>tools/code-gate/scope.conf; printf '#!/bin/sh\necho evil\n' >tools/evil.sh
echo '# unreviewed' >>tools/foo.sh; commit "cfg"; push origin main
eq "H2: scope.conf excludes in the same push: blocked" "$(blocked)" yes; has "H2: base scope sees evil.sh" "$pout" "UNMAPPED:tools/evil.sh"
newbranch; echo "# ok" >>tools/foo.sh; commit; prmerge; setjson "$SHA2" "$(printf "$good" "$SHA2")" "CODE-GATE-REVIEW: PASS head=$SHA2 blocking=1 medium=0"
git update-index --skip-worktree tools/code-gate/check-review.sh; printf '#!/bin/sh\necho "CODE-REVIEW: PASS"\n' >tools/code-gate/check-review.sh
push origin main; eq "H7b: skip-worktree neutered check-review.sh: blocked" "$(blocked)" yes; has "H7b: base check-review judged" "$pout" "not a clean pass"
# H3: unicode / newline names go through the hook too.
mkfix; printf '#!/bin/sh\necho evil\n' >"tools/évil.sh"; commit "u"; push origin main
eq "H3: tools/évil.sh 100644 pushed to main: blocked" "$(blocked)" yes; has "H3: named exactly" "$pout" "UNMAPPED:tools/évil.sh"
mkfix; printf '#!/bin/sh\n' >"tools/a
b.sh"; commit "nl"; push origin main; eq "H3b: newline name pushed to main: blocked" "$(blocked)" yes
# H17: a bare-glob map row pushed straight to main.
mkfix; printf '*\ttools/test_foo.sh\n%stools/foo.sh\ttools/test_foo.sh\n' "$CFGMAP" >tools/code-gate/test-map.tsv; commit "map"; push origin main
eq "H17: map row '*' direct to main: blocked" "$(blocked)" yes; has "H17: MALFORMED-MAP" "$pout" "MALFORMED-MAP"
mkfix; printf '%stools/*.sh\ttools/test_foo.sh\n' "$CFGMAP" | LC_ALL=C sort >tools/code-gate/test-map.tsv; commit "map glob"; push origin main
eq "H17: well-formed map change direct to main: blocked" "$(blocked)" yes; has "H17: map change needs a reviewed merge" "$pout" "not a 2-parent merge"
# Fable T2 item 7 (H10): unknown or absent remote main fails closed (no origin/main fallback).
mkfix; C2="$ROOT/c2-$NFX"; git clone -q "$ORIGIN" "$C2"; git -C "$C2" config user.email t@t; git -C "$C2" config user.name t
git checkout -q -b wt/x; echo '#ok' >>tools/foo.sh; commit; prmerge; setjson "$SHA2" "$(printf "$good" "$SHA2")"; push origin main
eq "H10 setup: reviewed merge lands" "$rc" 0; R="$(git rev-parse main)"
cd "$C2" || exit 1; git config core.hooksPath tools/git-hooks; printf '#!/bin/sh\necho evil\n' >tools/evil.sh; commit evil
git update-ref refs/remotes/origin/main HEAD; push -f origin main
eq "H10: stale clone, forged origin/main, force push: blocked" "$(blocked)" yes; has "H10: names the unknown remote sha" "$pout" "remote main $R not local; git fetch origin and retry"
eq "H10: origin main unchanged" "$(git -C "$ORIGIN" rev-parse main)" "$R"
mkfix; git init -q --bare -b main "$ROOT/empty-$NFX.git"; push "$ROOT/empty-$NFX.git" main
eq "absent remote main: blocked" "$(blocked)" yes; has "absent main named" "$pout" "remote main does not exist"
# Bootstrap: base has no gate yet -> the pushed head's copy runs and says so.
mkfix; git checkout -q --orphan pre; git rm -rqf .; echo r >pre.txt; git add pre.txt; git commit -qm pre; git push -q -f --no-verify origin pre:main
git checkout -q main; git merge -q --no-ff --allow-unrelated-histories pre -m m >/dev/null 2>&1
mkdir -p "$ROOT/tmpd"; TMPDIR="$ROOT/tmpd" push origin HEAD:refs/heads/wt/boot
has "bootstrap announced" "$pout" "CODE-GATE: BOOTSTRAP"
eq "hook leaves TMPDIR empty" "$(ls -A "$ROOT/tmpd" | wc -l | tr -d ' ')" 0
# g7 (Fable T3 §12): a non-fast-forward push to main (rewind to an ancestor) is blocked.
newbranch; echo "# ok" >>tools/foo.sh; commit; prmerge; setjson "$SHA2" "$(printf "$good" "$SHA2")"; push origin main
eq "rewind setup: reviewed merge lands" "$rc" 0; R="$(git rev-parse main)"
git reset -q --hard HEAD~1; push -f origin main
eq "force push of main to an ancestor: blocked" "$(blocked)" yes; has "rewind named" "$pout" "non-fast-forward push to main rewinds $R"
eq "rewind: origin main unchanged" "$(git -C "$ORIGIN" rev-parse main)" "$R"

# backlog row L697: a wt/* push runs the gate scripts from the origin/main TIP, not from the merge-base. The fixture
# forks wt/x from the base commit, then moves origin/main to a tip whose run-mapped-tests.sh prints a marker.
newbranch; echo "# ok" >>tools/foo.sh; commit; git checkout -q main
sed -i.bak '/^set -uo pipefail/a\
echo "GATE-TIP-MARKER" >&2' tools/code-gate/run-mapped-tests.sh; rm -f tools/code-gate/run-mapped-tests.sh.bak; commit "gate tip"
git update-ref refs/remotes/origin/main "$(git rev-parse HEAD)"; git checkout -q wt/x
push origin wt/x
eq "tip-gate: wt push still passes" "$rc" 0; has "tip-gate: gate script came from the origin/main tip" "$pout" "GATE-TIP-MARKER"
has "tip-gate: verdict" "$pout" "CODE-GATE: PASS n_run=1"
# Control: origin/main absent from the gate (bootstrap) falls back to the merge-base copy, no marker.
newbranch; echo "# ok" >>tools/foo.sh; commit; push origin wt/x
hasnt "tip-gate control: no marker when origin/main has no moved gate" "$pout" "GATE-TIP-MARKER"; eq "tip-gate control: rc 0" "$rc" 0

# A4 (PR #32 advisory): the hook names refs/remotes/origin/main, so a local TAG called origin/main (git resolves tags
# before remote-tracking refs) cannot shadow the gate source or the merge-base. Same fixture as backlog row L697 plus the tag.
newbranch; echo "# ok" >>tools/foo.sh; commit; OLDB="$(git rev-parse HEAD~1)"; git checkout -q main
sed -i.bak '/^set -uo pipefail/a\
echo "GATE-TIP-MARKER" >&2' tools/code-gate/run-mapped-tests.sh; rm -f tools/code-gate/run-mapped-tests.sh.bak; commit "gate tip"
git update-ref refs/remotes/origin/main "$(git rev-parse HEAD)"; git tag origin/main "$OLDB"; git checkout -q wt/x
push origin wt/x
eq "tag-shadow: wt push passes" "$rc" 0; has "tag-shadow: gate came from refs/remotes/origin/main, not the tag" "$pout" "GATE-TIP-MARKER"
has "tag-shadow: verdict" "$pout" "CODE-GATE: PASS n_run=1"

# SIGPIPE class: `git archive | tar -x` under pipefail can return 141 after a complete extraction (bsdtar stops
# at the end-of-archive marker). The hook extracts without a pipe; pin the text and run the hook's own lines.
HOOK="$REAL/tools/git-hooks/pre-push"
EXTRACT="$(sed -n '/gate="\$(mktemp -d /,/\[ -f "\$gate\/\$G\/run-mapped-tests.sh" \]/p' "$HOOK" | sed '1d;$d' | grep -v '^ *#')"
hasnt "extract-no-pipe: no | in the extraction block" "${EXTRACT//||/}" "|"; has "extract-no-pipe: uses --output" "$EXTRACT" "--output"
SB="$(git -C "$REAL" merge-base HEAD origin/main 2>/dev/null || git -C "$REAL" rev-parse HEAD)"
runext() { # runext <iterations> — the hook's extraction lines under pipefail, counted by rc
  local i n=0; for ((i = 0; i < $1; i++)); do
    bash -c 'set -uo pipefail; cd "$1"; src="$2"; G=tools/code-gate; gate="$(mktemp -d "${TMPDIR:-/tmp}/test_pre-push.XXXXXX")"; block() { echo "BLOCK: $1" >&2; rm -rf "$gate"; exit 1; }
      '"$EXTRACT"'
      r=0; [ -f "$gate/$G/run-mapped-tests.sh" ] && [ -f "$gate/$G/check-review.sh" ] || r=2; rm -rf "$gate"; exit $r' _ "$REAL" "$SB" 2>/dev/null || n=$((n + 1))
  done; echo "$n"
}
eq "extract-under-pipefail-real-base: rc 0, gate scripts present" "$(runext 1)" 0
# NON-DETERMINISTIC old-form count: informational only (printed, not asserted) because the SIGPIPE race
# depends on scheduling and the tar implementation; the assertion is that the new form never fails.
old=0; for ((i = 0; i < 20; i++)); do
  d="$(mktemp -d "${TMPDIR:-/tmp}/test_pre-push.XXXXXX")"; (set -uo pipefail; git -C "$REAL" archive "$SB" tools/code-gate | tar -x -C "$d") 2>/dev/null || old=$((old + 1)); rm -rf "$d"
done
echo "INFO: old-pipe-form-flake-class (NON-DETERMINISTIC): old form returned nonzero in $old/20 runs"
eq "old-pipe-form-flake-class: new form fails 0/20 times" "$(runext 20)" 0
finish
