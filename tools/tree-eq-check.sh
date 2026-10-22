#!/usr/bin/env bash
# tree-eq-check.sh — mechanical "merged tree == gated tree" check.
#
# WHY THIS EXISTS: hq ADR 0033 says the merge-gate verifier "confirms the merged tree equals the
# gated tree" but today that confirmation is done by eye — the adjudicator reasons about diff/
# history to argue the commit now on the target branch is the same TREE the gate actually ran its
# checks against (see ~/projects/agent-hq/inbox/merge-gate-tree-equality-and-maestro-pin-20260913.md,
# finding #1, sourced from PR #126: the branch tip moved — rebase/amend/later push — between gate
# run and adjudication, with "no mechanical way to confirm the gate's result still applied"). This
# script replaces that per-adjudication argument with a one-line, deterministic tree-sha compare:
# record the tree sha at gate time (`record`), optionally check whether the target branch has
# moved in a way that would still fast-forward (`ff-check`), then after the merge lands, compare
# the recorded tree sha against the target branch's tree sha (`verify`). Equal trees ⇒ the gate's
# result carries over with no argument required; unequal ⇒ a clear, mechanical signal to re-run
# the gate. Not yet wired into the merge-gate tooling itself — this is the standalone check.
#
# `command grep` is used throughout (no bare `grep`), matching tools/port-check.sh and
# tools/sim-lease.sh convention, even though this script's only grep use is an exact-match remote
# lookup — never rely on a shell-aliased/shadowed `grep`.
#
# READ-ONLY: never modifies the repo except `git fetch`, which only updates remote-tracking refs —
# no checkout, no merge, no reset, no working-tree change, ever.
#
# USAGE
#   tree-eq-check.sh record --ref <ref> [--repo <path>]
#   tree-eq-check.sh ff-check --branch <ref> [--target origin/main] [--repo <path>]
#   tree-eq-check.sh verify --gated-tree <tree-sha> [--target origin/main] [--repo <path>]
#   --repo defaults to the current directory for every verb.
#
# OUTPUT CONTRACT: exactly one machine-token line, LAST line of stdout, per verb:
#   TREE-RECORD: <tree-sha> ref=<ref> commit=<commit-sha>
#   FF-CHECK: OK target=<target-sha>          | FF-CHECK: STALE target=<target-sha> merge-base=<sha>
#   TREE-EQ: MET tree=<sha> target=<commit>   | TREE-EQ: NOT MET gated=<sha> target-tree=<sha> target=<commit>
# Any usage/resolution error → `TREE-EQ: ERROR <reason>` on STDERR, exit 2 — no stdout token at all.
#
# EXIT CODES
#   0  record: always, once --ref resolves | ff-check: OK (target IS an ancestor of branch — merging
#      branch into target is a fast-forward, so the gated tree would be preserved) | verify: MET
#      (target branch's tree == the gated tree)
#   1  ff-check: STALE (target is NOT an ancestor of branch — target moved since gating) |
#      verify: NOT MET (target branch's tree != the gated tree)
#   2  usage error, or a ref/remote could not be resolved — fails closed, never prints a token
#
# TARGET PARSING: <target> is normally "<remote>/<branch>" (e.g. origin/main) — when its first
# path segment names a remote actually configured on the repo, this fetches that remote's branch
# quietly before resolving, then resolves it in this order: the remote-tracking ref
# refs/remotes/<target>, else a local branch refs/heads/<target>, else refs/remotes/<target> anyway
# (fails closed; never the raw name, so a tag called origin/main cannot shadow). A target NOT shaped like "<remote>/<branch>" (a bare ref, a sha, HEAD)
# is resolved as-is with NO fetch attempted — this lets ff-check/verify be pointed at a local ref
# (e.g. to simulate "what if the target were X" without a real push) instead of forcing a remote
# fetch on every call.
set -euo pipefail

REPO="."
EXIT_OK=0
EXIT_FAIL=1
EXIT_ERROR=2

err() {
  echo "TREE-EQ: ERROR $*" >&2
  exit "${EXIT_ERROR}"
}

# maybe_fetch_target <target> — fetch <remote>'s <branch> quietly iff <target> is shaped
# "<remote>/<branch>" AND <remote> is a remote actually configured on ${REPO}; else a silent no-op.
maybe_fetch_target() {
  local target="$1" remote branch
  case "${target}" in
    */*) ;;
    *) return 0 ;;
  esac
  remote="${target%%/*}"
  branch="${target#*/}"
  if git -C "${REPO}" remote 2>/dev/null | command grep -qxF -- "${remote}"; then
    git -C "${REPO}" fetch --quiet "${remote}" "${branch}" 2>/dev/null \
      || err "git fetch ${remote} ${branch} failed"
  fi
  return 0
}

# canon_target <target> — echo the revision to resolve. When <target> is "<remote>/<branch>" and <remote> is
# configured on ${REPO}, resolution order is: refs/remotes/<target> if it verifies (so a local tag called
# "origin/main" cannot shadow it; git resolves refs/tags before refs/remotes); else refs/heads/<target> (a local
# branch literally named "<remote>/<x>" with no tracking ref); else refs/remotes/<target> anyway, which fails
# closed. Never the raw name: that would let a tag shadow again. Anything else passes through as-is.
canon_target() {
  case "$1" in
    */*) ;;
    *) printf '%s' "$1"; return 0 ;;
  esac
  if git -C "${REPO}" remote 2>/dev/null | command grep -qxF -- "${1%%/*}"; then
    if git -C "${REPO}" rev-parse -q --verify "refs/remotes/$1^{commit}" >/dev/null 2>&1; then
      printf 'refs/remotes/%s' "$1"
    elif git -C "${REPO}" rev-parse -q --verify "refs/heads/$1^{commit}" >/dev/null 2>&1; then
      printf 'refs/heads/%s' "$1"
    else
      printf 'refs/remotes/%s' "$1"
    fi
  else
    printf '%s' "$1"
  fi
}

resolve_commit() {
  git -C "${REPO}" rev-parse --verify "$1^{commit}" 2>/dev/null
}

resolve_tree() {
  git -C "${REPO}" rev-parse --verify "$1^{tree}" 2>/dev/null
}

cmd_record() {
  local ref=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --ref) ref="${2:-}"; shift 2 ;;
      *) err "record: unknown argument '$1'" ;;
    esac
  done
  [ -n "${ref}" ] || err "record: --ref is required"

  local commit tree
  commit="$(resolve_commit "${ref}")" || err "cannot resolve ref '${ref}' to a commit"
  tree="$(resolve_tree "${ref}")" || err "cannot resolve ref '${ref}' to a tree"

  echo "TREE-RECORD: ${tree} ref=${ref} commit=${commit}"
  return "${EXIT_OK}"
}

cmd_ff_check() {
  local branch="" target="origin/main"
  while [ $# -gt 0 ]; do
    case "$1" in
      --branch) branch="${2:-}"; shift 2 ;;
      --target) target="${2:-}"; shift 2 ;;
      *) err "ff-check: unknown argument '$1'" ;;
    esac
  done
  [ -n "${branch}" ] || err "ff-check: --branch is required"

  maybe_fetch_target "${target}"
  target="$(canon_target "${target}")"

  local branch_commit target_commit merge_base
  branch_commit="$(resolve_commit "${branch}")" || err "cannot resolve --branch '${branch}'"
  target_commit="$(resolve_commit "${target}")" || err "cannot resolve --target '${target}'"

  if git -C "${REPO}" merge-base --is-ancestor "${target_commit}" "${branch_commit}"; then
    echo "FF-CHECK: OK target=${target_commit}"
    return "${EXIT_OK}"
  fi
  merge_base="$(git -C "${REPO}" merge-base "${target_commit}" "${branch_commit}" 2>/dev/null || true)"
  echo "FF-CHECK: STALE target=${target_commit} merge-base=${merge_base:-none}"
  return "${EXIT_FAIL}"
}

cmd_verify() {
  local gated_tree="" target="origin/main"
  while [ $# -gt 0 ]; do
    case "$1" in
      --gated-tree) gated_tree="${2:-}"; shift 2 ;;
      --target) target="${2:-}"; shift 2 ;;
      *) err "verify: unknown argument '$1'" ;;
    esac
  done
  [ -n "${gated_tree}" ] || err "verify: --gated-tree is required"

  maybe_fetch_target "${target}"
  target="$(canon_target "${target}")"

  local target_commit target_tree
  target_commit="$(resolve_commit "${target}")" || err "cannot resolve --target '${target}'"
  target_tree="$(resolve_tree "${target}")" || err "cannot resolve --target '${target}' to a tree"

  if [ "${gated_tree}" = "${target_tree}" ]; then
    echo "TREE-EQ: MET tree=${target_tree} target=${target_commit}"
    return "${EXIT_OK}"
  fi
  echo "TREE-EQ: NOT MET gated=${gated_tree} target-tree=${target_tree} target=${target_commit}"
  return "${EXIT_FAIL}"
}

main() {
  local mode="${1:-}"
  [ $# -gt 0 ] && shift

  # Verb validation runs BEFORE any repo check, so an unknown/missing verb fails with
  # "unknown verb" rather than a misleading "not a git repository" (which would fire first
  # if --repo defaults to a non-repo cwd).
  case "${mode}" in
    record|ff-check|verify) ;;
    *) err "unknown verb '${mode}'" ;;
  esac

  local args=()
  while [ $# -gt 0 ]; do
    case "$1" in
      --repo) REPO="${2:-}"; shift 2 ;;
      *) args+=("$1"); shift ;;
    esac
  done

  if ! git -C "${REPO}" rev-parse --git-dir >/dev/null 2>&1; then
    err "'${REPO}' is not a git repository"
  fi

  case "${mode}" in
    record)   cmd_record "${args[@]+"${args[@]}"}" ;;
    ff-check) cmd_ff_check "${args[@]+"${args[@]}"}" ;;
    verify)   cmd_verify "${args[@]+"${args[@]}"}" ;;
  esac
}

main "$@"
exit $?
