#!/usr/bin/env bash
# tools/code-gate/gate-invariants.sh <a|b|c> — the three code-gate invariants run by
# tools/check-invariants.sh as checks 27/28/29 (INVARIANTS.md). HQ = the checkout under test.
#   a  core.hooksPath == tools/git-hooks; every worktree (git worktree list --porcelain) that has
#      tools/code-gate/scope.conf needs an executable tools/git-hooks/pre-push (FAIL), else WARN. Fresh-clone residual: hooksPath is unset
#      in a new clone, and no check can run inside a clone that never installed the hook.
#   b  the test map is well-formed (rows sorted, unique, no bare `*`/`**` source, every source and test exists).
#   c  audits origin/main's first-parent history from the FIRST commit whose tree has
#      tools/code-gate/scope.conf, never skipping after it: a later commit without scope.conf
#      (or with an unusable one) FAILs "gate config removed". Scope comes from each commit's FIRST
#      PARENT (the gate-introducing commit uses its own). Each commit touching in-scope files must
#      pass cg_review_commit (lib.sh: 2-parent merge, trailer, PR head == ^2, clean marker, no evil
#      merge), checked via gh; a gh failure FAILs "cannot audit" (fails closed, owner 2026-10-02).
#      DIFF-FAIL = cannot audit (a dying `git diff --raw`), fails.
# Exit 0 = pass; 1 = fail (reasons on stderr).
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/lib.sh"
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_PREFIX
HQ="${HQ:-$HOME/projects/agent-hq}"
cd "$HQ" || { echo "gate-invariants: cannot cd to HQ=$HQ" >&2; exit 1; }
bad=0
no() { echo "$1" >&2; bad=1; }

case "${1:-}" in
  a)
    hp="$(git config --get core.hooksPath || true)"
    [ "$hp" = tools/git-hooks ] || no "core.hooksPath is '${hp:-<unset>}', expected tools/git-hooks"
    wts="$(git worktree list --porcelain | sed -n 's/^worktree //p')"
    [ -n "$wts" ] || no "git worktree list returned nothing"
    # Fable T3 ruling: a worktree WITH scope.conf must have an executable pre-push (FAIL); one
    # WITHOUT scope.conf is a pre-gate branch (WARN, exit stays 0; invariant 29 audits its pushes).
    while IFS= read -r w; do
      [ -z "$w" ] && continue
      [ -x "$w/tools/git-hooks/pre-push" ] && continue
      if [ -f "$w/tools/code-gate/scope.conf" ]; then
        no "worktree $w lacks an executable tools/git-hooks/pre-push"
      else
        echo "WARN 27 pre-gate branch, pre-push not yet present: $w" >&2
      fi
    done <<<"$wts"
    ;;
  b)
    out="$(cg_check_map WORKTREE)" || no "$out"
    ;;
  c)
    if ! git rev-parse --verify -q refs/remotes/origin/main >/dev/null; then no "no origin/main ref to audit"; exit 1; fi
    # A shallow clone cuts the history at a boundary commit that looks parentless: fail closed rather than exempt it.
    if [ "$(git rev-parse --is-shallow-repository 2>/dev/null)" = true ]; then no "origin/main: shallow clone, cannot audit history"; exit 1; fi
    # The first first-parent commit that brought scope.conf in (cheap path-limited log); the walk
    # starts there and never skips afterwards.
    first="$(git log --first-parent --reverse --format=%H refs/remotes/origin/main -- "$CG_DIR/scope.conf")" ||
      { no "origin/main: git log failed (cannot audit)"; exit 1; }
    first="${first%%$'\n'*}"
    revs="$(git rev-list --reverse --first-parent refs/remotes/origin/main --)" ||
      { no "origin/main: git rev-list failed (cannot audit)"; exit 1; }
    started=0
    for c in $revs; do
      if [ "$started" = 0 ]; then [ "$c" = "$first" ] || continue; started=1; fi
      git cat-file -e "$c:$CG_DIR/scope.conf" 2>/dev/null ||
        { no "origin/main commit $c: gate config removed ($CG_DIR/scope.conf absent)"; continue; }
      par="$(git rev-list --parents -n1 "$c" 2>/dev/null)" && case "$par" in "$c"|"$c "*) ;; *) false ;; esac ||
        { no "origin/main commit $c: cannot determine parents (cannot audit)"; continue; }
      # Exempt only a commit with zero parents per `git rev-list --parents` (the repository bootstrap root, nothing to
      # merge from), and only in a non-shallow repository (checked above). Every other commit is audited.
      [ "$par" != "$c" ] || continue
      p1="${par#* }"; p1="${p1%% *}"
      srev="$c"; cg_has "$p1" "$CG_DIR/scope.conf" && srev="$p1"
      cg_scope_load "$srev" || { no "origin/main commit $c: gate config removed (unusable scope.conf at $srev)"; continue; }
      chg="$(cg_changed ACMRD "$p1" "$c" | cg_scoped | tr '\0' '\n')" ||
        { no "origin/main commit $c: DIFF-FAIL (git diff failed, cannot audit)"; continue; }
      [ -n "$chg" ] || continue
      why="$(cg_review_commit "$c")"; r=$?
      case "$r" in
        0) ;;
        2) no "origin/main commit $c touches in-scope code: cannot audit: $why" ;;
        *) no "origin/main commit $c touches in-scope code: $why" ;;
      esac
    done
    ;;
  *) no "usage: gate-invariants.sh a|b|c" ;;
esac
exit "$bad"
