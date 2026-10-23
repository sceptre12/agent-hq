#!/usr/bin/env bash
# tools/code-gate/test_check-review.sh — tests for check-review.sh against NON-EMPTY fixture repos with
# a fake `gh` on PATH (no network). Covers the §9.1 walk: 2-parent merge + Code-Gate-PR trailer,
# PR headRefOid == <c>^2, strict marker (head, blocking=0, medium=0; last marker wins), evil-merge
# detection, doc-only commits needing no review, and fail-closed behaviour when gh errors.
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
CR="$REAL/tools/code-gate/check-review.sh"
mkdir -p "$ROOT/bin"; export FAKE_GH_LOG="$ROOT/gh.log" FAKE_GH_JSON="$ROOT/gh.json"
cat >"$ROOT/bin/gh" <<'GH'
#!/usr/bin/env bash
echo "$@" >>"$FAKE_GH_LOG"
[ "${FAKE_GH_RC:-0}" = 0 ] || exit "$FAKE_GH_RC"
cat "$FAKE_GH_JSON"
GH
chmod +x "$ROOT/bin/gh"; export PATH="$ROOT/bin:$PATH"
cr() { : >"$FAKE_GH_LOG"; out="$("$CR" origin/main main 2>"$ROOT/err")"; rc=$?; err="$(cat "$ROOT/err")"; }
# setjson <headRefOid> [comment-body...]
setjson() { jq -n --arg o "$1" --arg b "${PRBASE:-main}" --arg s "${PRSTATE:-OPEN}" '{headRefOid: $o, baseRefName: $b, state: $s, comments: ($ARGS.positional | map({body: .}))}' --args "${@:2}" >"$FAKE_GH_JSON"; }
# setup <merge-message> — fixture whose main has one in-scope PR merge (wt/x merged --no-ff); sets SHA2.
setup() {
  mkfix; git checkout -q -b wt/x; echo "# change" >>tools/foo.sh; commit; git checkout -q main
  git merge -q --no-ff wt/x -m "$1"; SHA2="$(git rev-parse HEAD^2)"
}
TRAILER=$'merge wt/x\n\nCode-Gate-PR: #7'
good="CODE-GATE-REVIEW: PASS head=%s blocking=0 medium=0"

setup "$TRAILER"; setjson "$SHA2" "$(printf "$good" "$SHA2")"; cr
eq "clean merge + trailer + matching PR + marker: rc 0" "$rc" 0; has "PASS verdict counts the commit" "$out" "CODE-REVIEW: PASS commits=1"
has "gh was asked about PR 7 on the right repo" "$(cat "$FAKE_GH_LOG")" "pr view 7 --repo sceptre12/agent-hq"
setjson "$SHA2" "approved by someone" "$(printf "$good" "$SHA2")"; cr; eq "marker among other comments: rc 0" "$rc" 0

mkfix; echo "# doc" >>README.md; commit; cr
eq "doc-only commit needs no review: rc 0" "$rc" 0; has "doc-only: zero commits checked" "$out" "commits=0"
eq "doc-only: gh never called" "$(cat "$FAKE_GH_LOG")" ""

mkfix; echo "# direct" >>tools/foo.sh; commit "direct code commit"; cr
eq "non-merge code commit: rc 1" "$rc" 1; has "needs --no-ff named" "$err" "not a 2-parent merge"

setup $'merge wt/x\n\nno trailer here'; setjson "$SHA2" "$(printf "$good" "$SHA2")"; cr
eq "merge without trailer: rc 1" "$rc" 1; has "missing trailer named" "$err" "missing 'Code-Gate-PR: #N' trailer"

setup "$TRAILER"; setjson "$(git rev-parse HEAD)" "$(printf "$good" "$SHA2")"; cr
eq "PR head != merge parent 2: rc 1" "$rc" 1; has "head mismatch named" "$err" "!= merge parent 2"

setup "$TRAILER"; setjson "$SHA2"; cr
eq "no marker comment: rc 1" "$rc" 1; has "no marker named" "$err" "no CODE-GATE-REVIEW marker"
setup "$TRAILER"; setjson "$SHA2" "CODE-GATE-REVIEW: PASS head=$(git rev-parse HEAD) blocking=0 medium=0"; cr
eq "marker for a different head: rc 1" "$rc" 1; has "different head means no marker" "$err" "no CODE-GATE-REVIEW marker"
for bad in "CODE-GATE-REVIEW: PASS head=%s" "CODE-GATE-REVIEW: PASS head=%s blocking=0" "CODE-GATE-REVIEW: PASS head=%s medium=0" \
           "CODE-GATE-REVIEW: PASS head=%s blocking=1 medium=0" "CODE-GATE-REVIEW: PASS head=%s blocking=0 medium=2" \
           "CODE-GATE-REVIEW: FAIL head=%s blocking=0 medium=0"; do
  setup "$TRAILER"; setjson "$SHA2" "$(printf "$bad" "$SHA2")"; cr
  eq "bad marker [$bad]: rc 1" "$rc" 1; has "bad marker not a clean pass" "$err" "not a clean pass"
done
setup "$TRAILER"; setjson "$SHA2" "$(printf "$good" "$SHA2")" "CODE-GATE-REVIEW: PASS head=$SHA2 blocking=0 medium=1"; cr
eq "last marker (medium=1) wins over an earlier clean one: rc 1" "$rc" 1
setup "$TRAILER"; setjson "$SHA2" "CODE-GATE-REVIEW: PASS head=$SHA2 blocking=1 medium=0" "$(printf "$good" "$SHA2")"; cr
eq "later clean marker supersedes an earlier failing one: rc 0" "$rc" 0

setup "$TRAILER"; setjson "$SHA2" "$(printf "$good" "$SHA2")"; FAKE_GH_RC=1; export FAKE_GH_RC; cr; unset FAKE_GH_RC
eq "gh failure fails closed: rc 1" "$rc" 1; has "gh failure named" "$err" "gh pr view 7 failed"

# evil merge: the merge commit edits an in-scope file after the reviewed PR head.
mkfix; git checkout -q -b wt/x; echo "# change" >>tools/foo.sh; commit; git checkout -q main
git merge -q --no-ff --no-commit wt/x >/dev/null 2>&1; echo "# smuggled" >>tools/foo.sh; git add -A; git commit -qm "$TRAILER"
SHA2="$(git rev-parse HEAD^2)"; setjson "$SHA2" "$(printf "$good" "$SHA2")"; cr
eq "evil merge editing a PR file: rc 1" "$rc" 1; has "evil merge named" "$err" "evil merge"
mkfix; git checkout -q -b wt/x; echo "# change" >>tools/foo.sh; commit; git checkout -q main
git merge -q --no-ff --no-commit wt/x >/dev/null 2>&1; printf '#!/usr/bin/env bash\necho hidden\n' >tools/hidden.sh; git add -A; git commit -qm "$TRAILER"
SHA2="$(git rev-parse HEAD^2)"; setjson "$SHA2" "$(printf "$good" "$SHA2")"; cr
eq "evil merge adding a new in-scope file: rc 1" "$rc" 1; has "smuggled file named evil" "$err" "evil merge"

# H8: no repo override. CODE_GATE_REPO is ignored; gh is always asked about sceptre12/agent-hq.
setup "$TRAILER"; setjson "$SHA2" "$(printf "$good" "$SHA2")"; CODE_GATE_REPO=attacker/fork cr
has "H8: CODE_GATE_REPO ignored, real repo queried" "$(cat "$FAKE_GH_LOG")" "--repo sceptre12/agent-hq"
hasnt "H8: attacker repo never queried" "$(cat "$FAKE_GH_LOG")" "attacker/fork"
eq "H8: no source mentions CODE_GATE_REPO" "$(grep -l CODE_GATE_REPO "$REAL"/tools/code-gate/{lib,check-review,run-mapped-tests,gate-invariants}.sh "$REAL/tools/git-hooks/pre-push" | wc -l | tr -d ' ')" 0
# H9: the PR must target main and be OPEN or MERGED.
setup "$TRAILER"; PRBASE=wt/base setjson "$SHA2" "$(printf "$good" "$SHA2")"; cr
eq "H9: PR base wt/base: rc 1" "$rc" 1; has "H9: base named" "$err" "base is 'wt/base', not main"
setup "$TRAILER"; PRSTATE=CLOSED setjson "$SHA2" "$(printf "$good" "$SHA2")"; cr
eq "H9: PR CLOSED: rc 1" "$rc" 1; has "H9: state named" "$err" "state is 'CLOSED'"
setup "$TRAILER"; PRSTATE=MERGED setjson "$SHA2" "$(printf "$good" "$SHA2")"; cr; eq "PR MERGED is accepted: rc 0" "$rc" 0
has "gh asked for base and state" "$(cat "$FAKE_GH_LOG")" "--json headRefOid,baseRefName,state,comments"
setup "$TRAILER"; echo 'not json' >"$FAKE_GH_JSON"; cr; eq "unparsable gh output fails closed: rc 1" "$rc" 1

# H23 (rule 8): a reviewed PR merge must not revert a main-side change the PR never touched.
mkfix; git branch wt/y; git checkout -q -b wt/x; echo '# security fix' >>tools/foo.sh; commit fix; git checkout -q main
git merge -q --no-ff wt/x -m "$TRAILER"; git update-ref refs/remotes/origin/main HEAD
git checkout -q wt/y; printf '#!/usr/bin/env bash\necho y\n' >tools/y.sh; printf '%stools/foo.sh\ttools/test_foo.sh\ntools/y.sh\ttools/test_foo.sh\n' "$CFGMAP" >tools/code-gate/test-map.tsv; commit y
git checkout -q main; git merge -q --no-ff --no-commit wt/y >/dev/null 2>&1; git checkout wt/y -- tools/foo.sh; git add -A
git commit -qm $'merge wt/y\n\nCode-Gate-PR: #8'; SHA2="$(git rev-parse HEAD^2)"; setjson "$SHA2" "$(printf "$good" "$SHA2")"
eq "H23 fixture: the fix is gone from the merge" "$(grep -c 'security fix' tools/foo.sh)" 0
cr; eq "H23: merge reverting main-side foo.sh: rc 1" "$rc" 1; has "H23: path outside the PR's diff named" "$err" "'tools/foo.sh' changed by the merge is not in PR #8's diff"
# rule 8 control: a merge whose main moved on in OTHER files (PR leaves them alone) passes.
mkfix; git checkout -q -b wt/x; echo "# x" >>tools/foo.sh; commit; git checkout -q main; echo "# m" >>legacy/old.sh; commit "main moved"
git update-ref refs/remotes/origin/main HEAD; git merge -q --no-ff wt/x -m "$TRAILER"; SHA2="$(git rev-parse HEAD^2)"
setjson "$SHA2" "$(printf "$good" "$SHA2")"; cr; eq "rule 8 control: main moved elsewhere, clean merge: rc 0" "$rc" 0
# evil merge deleting an extensionless 100755 hook (deletions keep their source mode, so it is in scope).
mkfix; printf '#!/bin/sh\n' >tools/git-hooks/hk; chmod +x tools/git-hooks/hk; printf '%stools/foo.sh\ttools/test_foo.sh\ntools/git-hooks/hk\ttools/test_foo.sh\n' "$CFGMAP" >tools/code-gate/test-map.tsv
commit hk; git update-ref refs/remotes/origin/main HEAD; git checkout -q -b wt/x; echo "# x" >>tools/foo.sh; commit; git checkout -q main
git merge -q --no-ff --no-commit wt/x >/dev/null 2>&1; git rm -q tools/git-hooks/hk; git commit -qm "$TRAILER"
SHA2="$(git rev-parse HEAD^2)"; setjson "$SHA2" "$(printf "$good" "$SHA2")"; cr
eq "evil merge deleting a 100755 hook: rc 1" "$rc" 1; has "deleted hook named" "$err" "'tools/git-hooks/hk' changed by the merge is not in PR #7's diff"

# two PR merges in one push: the second lacks a marker -> the whole push fails.
setup "$TRAILER"; git checkout -q -b wt/y; echo "# y" >>tools/foo.sh; commit; git checkout -q main
git merge -q --no-ff wt/y -m $'merge wt/y\n\nCode-Gate-PR: #8'
setjson "$SHA2" "$(printf "$good" "$SHA2")"; cr
eq "second merge unreviewed: rc 1" "$rc" 1; has "second merge's head is reported" "$err" "!= merge parent 2"
# diff-dies-fails-closed: a dying `git diff --raw` must not read as "no in-scope change" (PASS commits=0).
setup "$TRAILER"; setjson "$SHA2" "$(printf "$good" "$SHA2")"; mkdir -p "$ROOT/dbin"
printf '#!/usr/bin/env bash\ncase " $* " in *" diff --raw "*) echo "fatal: injected failure" >&2; exit 128 ;; esac\nexec "%s" "$@"\n' "$(command -v git)" >"$ROOT/dbin/git"; chmod +x "$ROOT/dbin/git"
PATH="$ROOT/dbin:$PATH" cr
eq "diff-dies-fails-closed: rc 1" "$rc" 1; has "diff-dies-fails-closed: FAIL verdict" "$out" "CODE-REVIEW: FAIL"; has "diff-dies-fails-closed: DIFF-FAIL named" "$err" "DIFF-FAIL"
cr; eq "diff-dies: same fixture, real git: rc 0" "$rc" 0
# rev-list-dies-fails-closed: a dying commit walk (`git rev-list --first-parent`) must not read as "no commits" (PASS commits=0).
printf '#!/usr/bin/env bash\ncase " $* " in *" rev-list --first-parent "*) echo "fatal: injected failure" >&2; exit 128 ;; esac\nexec "%s" "$@"\n' "$(command -v git)" >"$ROOT/dbin/git"
PATH="$ROOT/dbin:$PATH" cr
eq "rev-list-dies-fails-closed: rc 1" "$rc" 1; has "rev-list-dies-fails-closed: FAIL verdict" "$out" "CODE-REVIEW: FAIL"; has "rev-list-dies-fails-closed: DIFF-FAIL named" "$err" "DIFF-FAIL"
hasnt "rev-list-dies-fails-closed: never PASS" "$out" "PASS"
cr; eq "rev-list-dies: same fixture, real git: rc 0" "$rc" 0
# M1: an unreadable changed-file list (`exec 9<` failing) must fail closed (rc 2), never skip the evil-merge loop.
# Simulated hermetically by shadowing `exec` with a function that fails (bash lets functions shadow it).
mkdir -p "$ROOT/tmp-m1"; LIBSRC='. tools/code-gate/lib.sh; cg_scope_from origin/main main'
m1=$(cd "$FX" && TMPDIR="$ROOT/tmp-m1" bash -c "$LIBSRC"'; exec() { return 1; }; why="$(cg_review_commit main)"; echo "rc=$? $why"')
has "M1: unreadable changed-file list fails closed (rc 2)" "$m1" "rc=2 "; has "M1: reason says fail closed" "$m1" "cannot read the changed-file list (fail closed)"
eq "M1: no temp file is left behind" "$(ls "$ROOT/tmp-m1" | wc -l | tr -d ' ')" 0
m1b=$(cd "$FX" && TMPDIR="$ROOT/tmp-m1" bash -c "$LIBSRC"'; cg_review_commit main >/dev/null; echo "rc=$?"')
eq "M1: normal path rc 0" "$m1b" "rc=0"; eq "M1: normal path leaves no temp file" "$(ls "$ROOT/tmp-m1" | wc -l | tr -d ' ')" 0
# M1 (mktemp): a failing mktemp makes cg_review_commit fail closed too (stub mktemp first on PATH).
mkdir -p "$ROOT/mbin"; printf '#!/bin/sh\nexit 1\n' >"$ROOT/mbin/mktemp"; chmod +x "$ROOT/mbin/mktemp"
m1c=$(cd "$FX" && PATH="$ROOT/mbin:$PATH" bash -c "$LIBSRC"'; why="$(cg_review_commit main 2>/dev/null)"; echo "rc=$? $why"')
has "M1: failing mktemp fails closed (rc 2)" "$m1c" "rc=2 "; has "M1: failing mktemp says fail closed" "$m1c" "(fail closed)"
finish
