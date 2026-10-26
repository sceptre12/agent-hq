#!/usr/bin/env bash
# tools/test_check-invariants.sh — tests for the code-gate checks 27/28/29 in tools/check-invariants.sh
# (run via `check-invariants.sh --code-gate` with HQ pointing at a fixture repo) and for their wiring.
# Fixture = NON-EMPTY repo whose origin/main history is: a pre-gate commit that already contains code
# with no trailer (must be ignored), then a gate-introducing --no-ff merge carrying Code-Gate-PR.
# Hermetic: mktemp fixtures only; the real repo's hooks, worktrees and remotes are never read.
set -uo pipefail
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_PREFIX
REAL="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
_TMPBASE="${TMPDIR:-/tmp}"; ROOT="$(mktemp -d "${_TMPBASE%/}/test_check-invariants.XXXXXX")"; trap 'rm -rf "$ROOT"' EXIT
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
CI="$REAL/tools/check-invariants.sh"
ci() { out="$(HQ="$FX" "$CI" --code-gate 2>&1)"; rc=$?; }
# Fake gh (no network): `gh pr view N ...` prints $GHDIR/pr-N.json; FAKE_GH_RC!=0 simulates gh down.
GHDIR="$ROOT/gh"; mkdir -p "$GHDIR" "$ROOT/bin"; export GHDIR
cat >"$ROOT/bin/gh" <<'GH'
#!/usr/bin/env bash
[ "${FAKE_GH_RC:-0}" = 0 ] || { echo "gh: network down" >&2; exit "$FAKE_GH_RC"; }
[ "$1 $2" = "pr view" ] && [ -f "$GHDIR/pr-$3.json" ] || { echo "no PR $3" >&2; exit 1; }
cat "$GHDIR/pr-$3.json"
GH
chmod +x "$ROOT/bin/gh"; export PATH="$ROOT/bin:$PATH"
# setpr N <head-sha> — PR N (base main, OPEN) with a clean marker for that head.
setpr() { jq -n --arg o "$2" --arg m "CODE-GATE-REVIEW: PASS head=$2 blocking=0 medium=0" \
  '{headRefOid: $o, baseRefName: "main", state: "OPEN", comments: [{body: $m}]}' >"$GHDIR/pr-$1.json"; }
# prmerge <branch> <N> — merge --no-ff with the trailer, register PR N as reviewed, publish as origin/main.
prmerge() { git checkout -q main; git merge -q --no-ff "$1" -m "merge $1"$'\n\n'"Code-Gate-PR: #$2"
  setpr "$2" "$(git rev-parse HEAD^2)"; git update-ref refs/remotes/origin/main HEAD; }
land() { git update-ref refs/remotes/origin/main HEAD; LAND="$(git rev-parse HEAD)"; ci; }
# mkgate — mkfix, then rewrite history to: pre-gate root commit -> merge of wt/gate (adds the gate).
mkgate() {
  mkfix; git config --unset core.hooksPath
  git checkout -q --orphan pre; git reset -q; git add tools/foo.sh tools/test_foo.sh README.md; git commit -qm "pre-gate"
  PRE="$(git rev-parse HEAD)"; git branch -M main; git checkout -q -b wt/gate; git add -A; git commit -qm "add gate"
  rm -f "$GHDIR"/pr-*.json; prmerge wt/gate 1
  git push -q -f origin main 2>/dev/null; git config core.hooksPath tools/git-hooks
}

mkgate; ci
eq "baseline fixture: checks 27-29 pass, rc 0" "$rc" 0; has "baseline summary" "$out" "check-invariants: 3/3 OK"
eq "fixture is non-empty: pre-gate code commit is in history" "$(git ls-tree -r --name-only "$PRE" | grep -c 'tools/foo.sh')" 1
eq "fixture is non-empty: map has rows" "$(grep -c . tools/code-gate/test-map.tsv)" 4

# --- 27 (a): hooksPath + executable pre-push here and in every linked worktree.
git config --unset core.hooksPath; ci
eq "27: hooksPath unset: rc 1" "$rc" 1; has "27 names the unset path" "$out" "core.hooksPath is '<unset>'"
git config core.hooksPath /dev/null; ci
eq "27: hooksPath overridden: rc 1" "$rc" 1; has "27 names the override" "$out" "core.hooksPath is '/dev/null'"
git config core.hooksPath tools/git-hooks; chmod -x tools/git-hooks/pre-push; ci
eq "27: pre-push not executable: rc 1" "$rc" 1; has "27 names the main checkout" "$out" "$FX lacks an executable"
chmod +x tools/git-hooks/pre-push; ci; eq "27: restored: rc 0" "$rc" 0
git worktree add -q "$ROOT/wt-two" -b wt/two; ci; eq "27: linked worktree with the hook: rc 0" "$rc" 0
rm "$ROOT/wt-two/tools/git-hooks/pre-push"; ci
eq "27: linked worktree lacking pre-push: rc 1" "$rc" 1; has "27 names the linked worktree" "$out" "$ROOT/wt-two lacks"
git worktree remove --force "$ROOT/wt-two"
git worktree add -q --detach "$ROOT/wt-old" "$PRE"; ci
eq "27: pre-gate worktree (no scope.conf, no hook): rc 0" "$rc" 0
has "27 prints the WARN line" "$out" "WARN 27 pre-gate branch, pre-push not yet present: "
has "27 WARN names the old worktree" "$out" "/wt-old"
eq "27: fixture worktree is non-empty and truly pre-gate" "$(ls "$ROOT/wt-old/tools/foo.sh" >/dev/null && test ! -e "$ROOT/wt-old/tools/code-gate/scope.conf" && echo ok)" ok
git worktree remove --force "$ROOT/wt-old"; ci; eq "27: removed: rc 0" "$rc" 0
eq "27: no WARN once only gated worktrees remain" "$(printf '%s' "$out" | grep -c '^WARN')" 0

# --- 28 (b): map well-formed.
git rm -q tools/test_foo.sh; ci
eq "28: map row's test deleted: rc 1" "$rc" 1; has "28 names the stale test" "$out" "STALE-MAP: test 'tools/test_foo.sh'"
git checkout -q HEAD -- tools/test_foo.sh; git rm -q tools/foo.sh; ci
eq "28: map row's source deleted: rc 1" "$rc" 1; has "28 names the stale source" "$out" "STALE-MAP: source 'tools/foo.sh'"
git checkout -q HEAD -- tools/foo.sh
printf 'tools/foo.sh\ttools/test_foo.sh\nREADME.md\ttools/test_foo.sh\n' >tools/code-gate/test-map.tsv; ci
eq "28: unsorted rows: rc 1" "$rc" 1; has "28 names the sort defect" "$out" "rows not sorted"
git rm -q -f tools/code-gate/test-map.tsv; ci
eq "28: map missing: rc 1" "$rc" 1; has "28 names the missing map" "$out" "test-map.tsv missing"
git checkout -q HEAD -- tools/code-gate/test-map.tsv; ci; eq "28: restored: rc 0" "$rc" 0

# --- 29 (c): origin/main audited from the first commit with scope.conf; every in-scope commit is a
# reviewed PR merge (checked via gh); gate config may never disappear; gh down fails closed.
mkgate; echo "# direct" >>tools/foo.sh; commit "ff code commit, no trailer"; BADC="$(git rev-parse HEAD)"; land
eq "29: trailer-less code commit on origin/main: rc 1" "$rc" 1; has "29 names the commit" "$out" "$BADC touches in-scope code"
has "29: non-merge named" "$out" "not a 2-parent merge"
mkgate; echo "# doc" >>README.md; commit "docs only, no trailer"; land
eq "29: doc-only commit without trailer: rc 0" "$rc" 0
git checkout -q -b wt/y; echo "# y" >>tools/foo.sh; commit; prmerge wt/y 2; ci
eq "29: reviewed --no-ff merge with trailer: rc 0" "$rc" 0
git checkout -q -b wt/z; echo "# z" >>tools/foo.sh; commit; git checkout -q main
git merge -q --no-ff wt/z -m "merge z with no trailer"; land
eq "29: merge without trailer: rc 1" "$rc" 1; has "29 names the defect" "$out" "missing 'Code-Gate-PR: #N' trailer"
mkgate; git checkout -q -b wt/m; echo "# m" >>tools/foo.sh; commit; git checkout -q main
git merge -q --no-ff wt/m -m $'merge m\n\nCode-Gate-PR: #3'; land
eq "29: trailer but PR has no marker/record: rc 1" "$rc" 1; has "29: cannot audit an unknown PR" "$out" "gh pr view 3 failed"
mkgate; git checkout -q -b wt/g; echo "# g" >>tools/foo.sh; commit; prmerge wt/g 4; FAKE_GH_RC=1 ci
eq "29: gh down fails closed: rc 1" "$rc" 1; has "29: says cannot audit" "$out" "cannot audit"
mkgate; rm -f "$GHDIR/pr-1.json"; ci; eq "29: the gate-introducing merge itself is audited: rc 1" "$rc" 1
has "29: names the gate merge" "$out" "$(git rev-parse HEAD) touches in-scope code"
mkgate; git update-ref -d refs/remotes/origin/main; ci
eq "29: no origin/main ref fails closed: rc 1" "$rc" 1; has "29 names the missing ref" "$out" "no origin/main ref"
# K2: a forged trailer on a non-merge commit.
mkgate; printf '#!/bin/sh\necho evil\n' >tools/evil.sh; commit $'evil\n\nCode-Gate-PR: #1'; land
eq "K2: forged trailer on a non-merge: rc 1" "$rc" 1; has "K2: flagged" "$out" "$LAND touches in-scope code"
# K3: deleting scope.conf (and later commits) FAILs "gate config removed"; nothing is skipped after.
mkgate; git rm -q tools/code-gate/scope.conf; printf '#!/bin/sh\necho evil\n' >tools/evil.sh; commit "drop scope"; land
eq "K3: scope.conf deleted: rc 1" "$rc" 1; has "K3: gate config removed" "$out" "$LAND: gate config removed"
printf '#!/bin/sh\necho evil2\n' >tools/evil2.sh; commit "more"; land
eq "K3b: later commit, gate gone: rc 1" "$rc" 1; has "K3b: later commit also flagged" "$out" "$LAND: gate config removed"
# K4: scope comes from the FIRST PARENT, so excluding a file in the same commit does not hide it.
# `exclude tools/*` also hides scope.conf itself, so only first-parent scope can flag this commit.
mkgate; echo 'exclude tools/*' >>tools/code-gate/scope.conf; printf '#!/bin/sh\n' >tools/evil.sh; commit "excl"; land
eq "K4: self-excluding commit (exclude tools/*): rc 1" "$rc" 1; has "K4: flagged" "$out" "$LAND touches in-scope code"
mkgate; git checkout -q -b wt/e; echo 'exclude tools/evil*' >>tools/code-gate/scope.conf; commit; prmerge wt/e 5
printf '#!/bin/sh\n' >tools/evil.sh; commit "after a reviewed exclude"; land
eq "K4 control: exclusion that landed via a reviewed merge applies to later commits: rc 0" "$rc" 0
# K5: unicode names are parsed exactly (-z).
mkgate; printf '#!/bin/sh\n' >"tools/évil.sh"; commit "uni"; land
eq "K5: tools/évil.sh direct commit: rc 1" "$rc" 1; has "K5: flagged" "$out" "$LAND touches in-scope code"
# Evil merge on main (rule 8) is caught by 29 as well.
mkgate; git checkout -q -b wt/v; echo "# v" >>tools/foo.sh; commit; git checkout -q main
git merge -q --no-ff --no-commit wt/v >/dev/null 2>&1; echo "# smuggled" >>tools/foo.sh; git add -A; git commit -qm $'merge v\n\nCode-Gate-PR: #6'
setpr 6 "$(git rev-parse HEAD^2)"; land; eq "29: evil merge on main: rc 1" "$rc" 1; has "29: evil merge named" "$out" "evil merge"

# --- wiring: the checks are in full mode, counted, and documented.
eq "full run invokes gate_checks" "$(grep -c '^  gate_checks ' "$CI")" 1
has "implemented count covers 17" "$(grep -n '^  implemented=' "$CI")" "implemented=17"
for n in 27 28 29; do has "INVARIANTS.md documents check $n" "$(grep -E "^\*\*$n\." "$REAL/INVARIANTS.md")" "**$n."; done
# diff-dies-fails-closed (check 29/c): a dying `git diff --raw` is DIFF-FAIL, never "commit touches no in-scope code".
mkgate; git checkout -q -b wt/d; echo "# d" >>tools/foo.sh; commit; prmerge wt/d 8; git update-ref refs/remotes/origin/main HEAD
printf '#!/usr/bin/env bash\ncase " $* " in *" diff --raw "*) echo "fatal: injected failure" >&2; exit 128 ;; esac\nexec "%s" "$@"\n' "$(command -v git)" >"$ROOT/bin/git"; chmod +x "$ROOT/bin/git"
ci; eq "diff-dies-fails-closed: rc 1" "$rc" 1; has "diff-dies-fails-closed: DIFF-FAIL named" "$out" "DIFF-FAIL"
rm -f "$ROOT/bin/git"; ci; eq "diff-dies: same fixture, real git: rc 0" "$rc" 0
# rev-list-dies-fails-closed / log-dies-fails-closed (check 29/c): a dying origin/main walk or scope.conf log is "cannot audit", never an empty audit.
printf '#!/usr/bin/env bash\ncase " $* " in *" rev-list --reverse --first-parent "*) echo "fatal: injected failure" >&2; exit 128 ;; esac\nexec "%s" "$@"\n' "$(command -v git)" >"$ROOT/bin/git"; chmod +x "$ROOT/bin/git"
ci; eq "rev-list-dies-fails-closed: rc 1" "$rc" 1; has "rev-list-dies-fails-closed: cannot audit" "$out" "cannot audit"
printf '#!/usr/bin/env bash\ncase " $* " in *" log --first-parent --reverse "*) echo "fatal: injected failure" >&2; exit 128 ;; esac\nexec "%s" "$@"\n' "$(command -v git)" >"$ROOT/bin/git"
ci; eq "log-dies-fails-closed: rc 1" "$rc" 1; has "log-dies-fails-closed: cannot audit" "$out" "cannot audit"
rm -f "$ROOT/bin/git"; ci; eq "rev-list/log-dies: same fixture, real git: rc 0" "$rc" 0
# tag-shadow (PR #33 advisory): check 29/c names refs/remotes/origin/main, so a local TAG called origin/main (git resolves tags
# before remote-tracking refs) cannot make the audit walk a different history. Tag points at the pre-gate commit; the audited ref carries a trailer-less code commit.
mkgate; echo "# direct" >>tools/foo.sh; commit "ff code commit, no trailer"; BADT="$(git rev-parse HEAD)"; git update-ref refs/remotes/origin/main HEAD; git tag origin/main "$(git rev-parse HEAD~1)"
ci; eq "tag-shadow: audit uses refs/remotes/origin/main, bad commit still found: rc 1" "$rc" 1; has "tag-shadow: bad commit named" "$out" "$BADT touches in-scope code"
git tag -d origin/main >/dev/null
# root-exempt (check 29/c, wt/inv29-root): the parentless root commit (repository bootstrap) carries scope.conf and in-scope
# code yet is exempt; a LATER plain commit touching in-scope files is still audited and named, never the root.
mkfix; ROOTC="$(git rev-parse HEAD)"; git update-ref refs/remotes/origin/main HEAD; ci
eq "29 root: parentless root with scope.conf + in-scope code: rc 0" "$rc" 0; has "29 root: all code-gate checks OK" "$out" "check-invariants: 3/3 OK"
echo "# later" >>tools/foo.sh; commit "plain code commit after the root"; LATER="$(git rev-parse HEAD)"; land
eq "29 root: later plain code commit: rc 1" "$rc" 1; has "29 root: names the later commit" "$out" "$LATER touches in-scope code"
hasnt "29 root: the root commit is not named" "$out" "$ROOTC"
# agentmemory retired (owner removal 2026-10-21): with no ~/.agentmemory and no launchd job, checks 16/18 must not
# FAIL or WARN about it, and the script must not name agentmemory in any output. Full-mode run, real checkout, empty HOME.
FH="$ROOT/fakehome"; mkdir -p "$FH"
out="$(HOME="$FH" HQ="$REAL" "$CI" 2>&1)"
hasnt "agentmemory retired: no 16 FAIL" "$out" "FAIL  16"
hasnt "agentmemory retired: no agentmemory text in output" "$out" "agentmemory"
finish
