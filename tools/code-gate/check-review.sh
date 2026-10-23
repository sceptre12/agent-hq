#!/usr/bin/env bash
# tools/code-gate/check-review.sh <base> <head> — main pushes only (architecture/hq-code-gate.md).
# Walks `git rev-list --first-parent <base>..<head>`. Every commit whose diff vs its first parent
# touches in-scope files (scope from <base>; head only while base predates the gate) must pass
# cg_review_commit (lib.sh): a 2-parent merge with a `Code-Gate-PR: #N` trailer; no evil merge (every
# in-scope path the merge brings in is in the PR's diff and equals <c>^2); PR N on sceptre12/agent-hq
# with base main, state OPEN|MERGED, headRefOid == <c>^2; and a last marker
#   CODE-GATE-REVIEW: PASS head=<c>^2 blocking=0 medium=0
# pre-push runs THIS script from base's tree (git archive; main pushes only), never the pushed copy. The repo is
# hardcoded (no override). Needs gh + jq; any gh/jq failure fails closed.
# A dying `git diff --raw` is reported as `DIFF-FAIL` and FAILs (rc 1); it is never read as "no changes".
# Prints `CODE-REVIEW: PASS|FAIL`; exit 0 / 1.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/lib.sh"
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_PREFIX
bad=0; checked=0
note() { echo "CODE-REVIEW BLOCK $1" >&2; bad=1; }
finish() { if [ "$bad" = 0 ]; then echo "CODE-REVIEW: PASS commits=$checked"; exit 0; fi; echo "CODE-REVIEW: FAIL"; exit 1; }

base="${1:-}"; head="${2:-}"
[ -n "$base" ] && [ -n "$head" ] || { note "usage: check-review.sh <base> <head>"; finish; }
cd "$(git rev-parse --show-toplevel)" || { note "not in a git repo"; finish; }
git rev-parse --verify -q "$base^{commit}" >/dev/null || { note "unknown base $base"; finish; }
git rev-parse --verify -q "$head^{commit}" >/dev/null || { note "unknown head $head"; finish; }
cg_scope_from "$base" "$head" || { note "no usable $CG_DIR/scope.conf at base or head"; finish; }

revs="$(git rev-list --first-parent "$base..$head" --)" || { note "DIFF-FAIL: git rev-list $base..$head failed, cannot enumerate commits"; finish; }
for c in $revs; do
  parent="$(git rev-parse -q --verify "$c^1" || echo "$CG_EMPTY_TREE")"
  chg="$(cg_changed ACMRD "$parent" "$c" | cg_scoped | tr '\0' '\n')" || { note "DIFF-FAIL $c: git diff failed, cannot tell whether it touches in-scope code"; continue; }
  [ -n "$chg" ] || continue
  checked=$((checked + 1))
  why="$(cg_review_commit "$c")" || note "$why"
done
finish
