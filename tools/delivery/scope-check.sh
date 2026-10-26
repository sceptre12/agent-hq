#!/usr/bin/env bash
# scope-check.sh <tasks-file> <worktree> <base-sha>
# Prints "CREEP <path>" for every path changed in <worktree> since <base-sha>
# (git diff base...HEAD) that matches none of the unit's scope globs.
# Globs: tasks file section "## 3" (until the next "## "), lines "- <glob>",
# matched with git pathspec :(glob) semantics.
# Exit: 0 clean, 1 creep found, 2 usage or invalid input (message on stderr).
# bash 3.2 / BSD userland; no stored state (the caller computes base-sha).

die() { printf 'scope-check: %s\n' "$1" >&2; exit 2; }

[ "$#" -eq 3 ] || die "usage: scope-check.sh <tasks-file> <worktree> <base-sha>"
tasks=$1; wt=$2; base=$3

[ -f "$tasks" ] && [ -r "$tasks" ] || die "tasks file unreadable: $tasks"
command grep -q '^## 3\([^0-9]\|$\)' "$tasks" || die "no '## 3' heading in $tasks"

# Collect globs from section 3 only.
globs=()
in3=0
while IFS= read -r line || [ -n "$line" ]; do
  line=${line%$'\r'}
  case $line in
    '## 3'|'## 3'[!0-9]*) in3=1; continue ;;
    '## '*) in3=0; continue ;;
  esac
  [ "$in3" -eq 1 ] || continue
  case $line in
    '- '*) ;;
    *) continue ;;
  esac
  g=${line#- }
  [ -n "$g" ] || continue
  if printf '%s' "$g" | LC_ALL=C command grep -q '[[:cntrl:]]'; then
    die "glob contains a control character: $g"
  fi
  case $g in
    :*) die "glob starts with ':' (pathspec magic): $g" ;;
  esac
  globs+=("$g")
done < "$tasks"
[ "${#globs[@]}" -gt 0 ] || die "no globs in section 3 of $tasks"

[ -d "$wt" ] || die "worktree is not a directory: $wt"
[ "$(git -C "$wt" rev-parse --is-inside-work-tree 2>/dev/null)" = "true" ] \
  || die "not a git work tree: $wt"
printf '%s' "$base" | command grep -Eq '^[0-9a-f]{40}$' \
  || die "base-sha must be 40 lowercase hex characters"
git -C "$wt" cat-file -e "${base}^{commit}" 2>/dev/null \
  || die "base-sha is not a commit in $wt"

tmp=$(mktemp -d "${TMPDIR:-/tmp}/scope-check.XXXXXX") || die "cannot create temp dir"
trap 'rm -rf "$tmp"' EXIT

git -C "$wt" diff --name-only -z --no-renames "${base}...HEAD" > "$tmp/all" 2>"$tmp/err" \
  || die "git diff failed: $(head -1 "$tmp/err")"

specs=()
for g in "${globs[@]}"; do specs+=(":(glob)$g"); done
git -C "$wt" diff --name-only -z --no-renames "${base}...HEAD" -- "${specs[@]}" > "$tmp/in" 2>"$tmp/err" \
  || die "git diff (scoped) failed: $(head -1 "$tmp/err")"

# Set of in-scope paths, delimited by \x01 (cannot occur in a path we print).
d=$'\x01'
inset=$d
while IFS= read -r -d '' p; do inset="$inset$p$d"; done < "$tmp/in"

out=""
rc=0
while IFS= read -r -d '' p; do
  case $inset in
    *"$d$p$d"*) continue ;;
  esac
  safe=$(printf '%s' "$p" | LC_ALL=C tr '\001-\037\177' '?')
  out="${out}CREEP ${safe}"$'\n'
  rc=1
done < "$tmp/all"

[ -z "$out" ] || printf '%s' "$out"
exit "$rc"
