#!/usr/bin/env bash
# tools/code-gate/lib.sh — shared helpers for the hq code gate (architecture/hq-code-gate.md).
# SOURCED by run-mapped-tests.sh, check-review.sh and gate-invariants.sh; never run directly.
# <rev> arguments accept any git rev, or the literal WORKTREE (read the checked-out files).
# Path lists are NUL-delimited end to end (git -z), so unicode, space and newline names are exact.
# Written for bash 3.2 (macOS): no associative arrays, no mapfile.
CG_ZERO=0000000000000000000000000000000000000000
CG_DIR=tools/code-gate
CG_EMPTY_TREE=4b825dc642cb6eb9a060e54bf8d69288fbee4904
CG_REPO="<owner>/hq"   # hardcoded on purpose: no env override (Fable T2 ruling, item 5)

cg_cat() { if [ "$1" = WORKTREE ]; then cat -- "$2" 2>/dev/null; else git show "$1:$2" 2>/dev/null; fi; }
cg_has() { if [ "$1" = WORKTREE ]; then [ -f "$2" ]; else git cat-file -e "$1:$2" 2>/dev/null; fi; }
# cg_files <rev> — every tracked path, NUL-terminated. Returns git's rc (callers must check it).
cg_files() {
  local rc
  if [ "$1" = WORKTREE ]; then git ls-files -z; else git ls-tree -r -z --name-only "$1"; fi
  rc=$?; return $rc
}
# cg_show <path> — a printable one-line form of a path (control characters become '?').
cg_show() { printf '%s' "$1" | tr '\n\t\r' '???'; }

# cg_scope_load <rev> — fills CG_INC / CG_EXC (newline lists) and CG_MODEX. Fails closed when
# scope.conf is absent or declares no include rule (an empty scope would pass everything).
cg_scope_load() {
  CG_INC=""; CG_EXC=""; CG_MODEX=0
  cg_has "$1" "$CG_DIR/scope.conf" || return 1
  local kind val conf
  conf="$(cg_cat "$1" "$CG_DIR/scope.conf")" || return 1   # read first (here-string below): a failed read is seen
  while read -r kind val; do
    case "$kind" in
      include) if [ "$val" = mode:100755 ]; then CG_MODEX=1; else CG_INC="$CG_INC$val"$'\n'; fi ;;
      exclude) CG_EXC="$CG_EXC$val"$'\n' ;;
    esac
  done <<<"$conf"
  [ -n "$CG_INC" ] || [ "$CG_MODEX" = 1 ]
}
# cg_scope_from <base> <head> — load scope from base; only when base predates the gate (no
# scope.conf: the one-time bootstrap) fall back to head. Sets CG_SCOPE_REV.
cg_scope_from() {
  CG_SCOPE_REV=$1; cg_has "$1" "$CG_DIR/scope.conf" || CG_SCOPE_REV=$2
  cg_scope_load "$CG_SCOPE_REV"
}

# cg_in_scope <path> <git-mode> — 0 when the path is an in-scope executable file.
cg_in_scope() {
  local p=$1 m=$2 pat
  while IFS= read -r pat; do
    [ -z "$pat" ] && continue
    case "$p" in $pat) return 1 ;; esac
  done <<<"$CG_EXC"
  if [ "$m" = 100755 ] && [ "$CG_MODEX" = 1 ]; then return 0; fi
  while IFS= read -r pat; do
    [ -z "$pat" ] && continue
    case "$p" in $pat) return 0 ;; esac
  done <<<"$CG_INC"
  return 1
}

# cg_changed <diff-filter> <git-diff-args...> — prints "<mode>\t<path>\0" for every changed file,
# parsed from `git diff --raw -z`. <mode> is the destination mode, or the source mode for a
# deletion (so deleting an extensionless 100755 hook is still in scope). The diff goes to a temp file
# first, so its status is visible: rc 2 if the diff (or mktemp) dies, never an empty list read as "no changes"; rc 0 on success.
cg_changed() {
  local f=$1 meta path m t
  shift
  t="$(mktemp)" || return 2
  trap 'rm -f "$t"; trap - RETURN' RETURN   # temp removed on every return path (it lives in $TMPDIR)
  git diff --raw -z --no-abbrev --no-renames --diff-filter="$f" "$@" -- >"$t" || return 2
  while IFS= read -r -d '' meta && IFS= read -r -d '' path; do
    set -- $meta      # ":<src-mode> <dst-mode> <src-sha> <dst-sha> <status>"
    m=$2; [ "$5" = D ] && m=${1#:}
    printf '%s\t%s\0' "$m" "$path"
  done <"$t"
  return 0
}

# cg_scoped — filters "<mode>\t<path>\0" records on stdin down to in-scope ones (cg_scope_load first).
cg_scoped() {
  local rec
  while IFS= read -r -d '' rec; do
    [ -n "$rec" ] && cg_in_scope "${rec#*$'\t'}" "${rec%%$'\t'*}" && printf '%s\0' "$rec"
  done
  return 0
}

# cg_map_rows <rev> — the map rows (comments and blanks removed), "<source-or-glob>\t<test>[\ttimeout=<seconds>]".
# An absent map is an empty list (cg_check_map reports it); a map that exists but cannot be read, or a
# grep failure (rc >= 2), returns non-zero instead of reading as "no rows". grep rc 1 (no rows) is fine.
cg_map_rows() {
  local c rc
  cg_has "$1" "$CG_DIR/test-map.tsv" || return 0
  c="$(cg_cat "$1" "$CG_DIR/test-map.tsv")" || return 2
  printf '%s\n' "$c" | grep -Ev '^[[:space:]]*(#|$)'; rc=$?
  [ "$rc" -le 1 ] || return "$rc"
  return 0
}

# cg_tests_for <rev> <path> — every test mapped to the path (exact row or glob row).
cg_tests_for() {
  local s t rows
  rows="$(cg_map_rows "$1")" || return 2   # one read per call; no per-file git inside a process substitution
  while IFS=$'\t' read -r s t _; do
    [ -z "$s" ] && continue
    case "$2" in $s) printf '%s\n' "$t" ;; esac
  done <<<"$rows"
}

# cg_timeout_for <rev> <test> — the per-test timeout in seconds declared by the map's optional third
# column (`timeout=<seconds>`) on any row naming <test>; the largest wins. Prints nothing when none is
# declared (the runner then uses CODE_GATE_TIMEOUT or 120). Non-zero when the map cannot be read.
cg_timeout_for() {
  local s t x rows best=""
  rows="$(cg_map_rows "$1")" || return 2
  while IFS=$'\t' read -r s t x; do
    [ "$t" = "$2" ] || continue
    [[ "$x" =~ ^timeout=[1-9][0-9]*$ ]] || continue
    x=${x#timeout=}
    if [ -z "$best" ] || [ "$x" -gt "$best" ]; then best=$x; fi
  done <<<"$rows"
  [ -z "$best" ] || printf '%s\n' "$best"
  return 0
}

# cg_is_test <rev> <path> — 0 when the path is a test file: test_* / *.test.* or a map test column.
cg_is_test() {
  case "${2##*/}" in test_*|*.test.*) return 0 ;; esac
  local s t rows
  rows="$(cg_map_rows "$1")" || return 2
  while IFS=$'\t' read -r s t _; do [ -n "$t" ] && [ "$t" = "$2" ] && return 0; done <<<"$rows"
  return 1
}

# cg_check_map <rev> — prints one line per problem; rc 0 clean, 1 problems, 2 LIST-FAIL. Checks that
# the map exists, every row has two fields (plus an optional third `timeout=<seconds>`), rows are sorted and unique, no source is a bare `*`/`**`
# (MALFORMED-MAP: it would map every file), and every row's source (or glob) and test exist
# (STALE-MAP otherwise). The tree is listed ONCE into ONE `mktemp -d` dir (files lst + lst.enc),
# removed on every return path. LIST-FAIL is one stdout line, rc 2, never STALE-MAP:
#   LIST-FAIL: cannot list tree <rev> (mktemp failed, fail closed)          — no temp dir
#   LIST-FAIL: cannot list tree <rev> (git rc N, fail closed)               — the listing failed
#   LIST-FAIL: cannot list tree <rev> (temp file unreadable, fail closed)   — lst/lst.enc write or read failed
#   LIST-FAIL: cannot list tree <rev> (encoded listing truncated, fail closed) — lst.enc lines != entries
#   LIST-FAIL: cannot list tree <rev> (listing step rc N, fail closed)      — the listing subshell died (signal)
# Signals: listing + encoding run in a subshell whose INT/TERM trap removes the dir. No trap is set
# in the function's own shell: lib.sh is sourced in-process, and bash 3.2 cannot add to a caller's trap.
# Before the first STALE-MAP line, one STALE-MAP-DIAG line goes to stderr only (cg_map_diag).
cg_check_map() {
  local bad=0 s t x raw hit f dir rc n=0 ne diag=0 enc
  local -a cgf
  cg_has "$1" "$CG_DIR/test-map.tsv" || { echo "MALFORMED-MAP: $CG_DIR/test-map.tsv missing"; return 1; }
  dir="$(mktemp -d "${TMPDIR:-/tmp}/cg-tree.XXXXXX")" || { echo "LIST-FAIL: cannot list tree $1 (mktemp failed, fail closed)"; return 2; }
  # lst.enc is the newline-joined injective encoding (\ -> \\, newline -> \n) for exact lookups, so a
  # newline in a name can never fake a match; cgf[] keeps every raw path for glob rows.
  ( trap 'rm -rf "$dir"; exit 130' INT; trap 'rm -rf "$dir"; exit 143' TERM
    cg_files "$1" >"$dir/lst"; rc=$?
    [ "$rc" = 0 ] || { echo "LIST-FAIL: cannot list tree $1 (git rc $rc, fail closed)"; exit 2; }
    while IFS= read -r -d '' f; do cg_enc "$f"; printf '%s\n' "$CG_E"; done <"$dir/lst" >"$dir/lst.enc" ||
      { echo "LIST-FAIL: cannot list tree $1 (temp file unreadable, fail closed)"; exit 2; }
  ); rc=$?
  if [ "$rc" != 0 ]; then
    [ "$rc" = 2 ] || echo "LIST-FAIL: cannot list tree $1 (listing step rc $rc, fail closed)"
    rm -rf "$dir"; return 2
  fi
  if ! { while IFS= read -r -d '' f; do cgf[n]=$f; n=$((n + 1)); done <"$dir/lst" &&
    enc=$'\n'"$(cat "$dir/lst.enc")"$'\n' && ne="$(wc -l <"$dir/lst.enc")"; }; then
    rm -rf "$dir"; echo "LIST-FAIL: cannot list tree $1 (temp file unreadable, fail closed)"; return 2
  fi
  rm -rf "$dir"
  ne=${ne//[[:space:]]/}
  [ "$ne" = "$n" ] || { echo "LIST-FAIL: cannot list tree $1 (encoded listing truncated, fail closed)"; return 2; }
  raw=$(cg_map_rows "$1") || { echo "LIST-FAIL: cannot read test-map.tsv at $1 (fail closed)"; return 2; }
  if [ -n "$raw" ] && ! printf '%s\n' "$raw" | LC_ALL=C sort -cu 2>/dev/null; then
    echo "MALFORMED-MAP: rows not sorted (LC_ALL=C) or duplicated"; bad=1
  fi
  while IFS=$'\t' read -r s t x; do
    [ -z "$s$t" ] && continue
    if [ -z "$s" ] || [ -z "$t" ] || [[ "$x" == *$'\t'* ]]; then echo "MALFORMED-MAP: bad row '$s' '$t'"; bad=1; continue; fi
    if [ -n "$x" ] && ! [[ "$x" =~ ^timeout=[1-9][0-9]*$ ]]; then
      echo "MALFORMED-MAP: bad third column '$(cg_show "$x")' (row '$s'; want timeout=<seconds>)"; bad=1; continue
    fi
    case "$s" in '*'|'**') echo "MALFORMED-MAP: source glob '$s' matches every file"; bad=1; continue ;; esac
    hit=0
    case "$s" in
      *[][*?\\]*) [ "$n" = 0 ] || for f in "${cgf[@]}"; do case "$f" in $s) hit=1; break ;; esac; done ;;
      *) cg_enc "$s"; case "$enc" in *$'\n'"$CG_E"$'\n'*) hit=1 ;; esac ;;
    esac
    if [ "$hit" != 1 ]; then
      [ "$diag" = 1 ] || { cg_map_diag "$1" "$raw" "$n"; diag=1; }
      echo "STALE-MAP: source '$s' matches no file"; bad=1
    fi
    hit=0
    cg_enc "$t"; case "$enc" in *$'\n'"$CG_E"$'\n'*) hit=1 ;; esac
    if [ "$hit" != 1 ]; then
      [ "$diag" = 1 ] || { cg_map_diag "$1" "$raw" "$n"; diag=1; }
      echo "STALE-MAP: test '$t' (for '$s') missing"; bad=1
    fi
  done <<<"$raw"
  return $bad
}
# cg_enc <path> — sets CG_E to the path with \ doubled and newline as \n (injective, no newline; no fork).
cg_enc() { CG_E=${1//\\/\\\\}; CG_E=${CG_E//$'\n'/\\n}; }
# cg_map_diag <rev> <map-rows-text> <entries> — prints the STALE-MAP-DIAG line (rows = map row count)
# to stderr only. Stateless: the caller (cg_check_map, its own local `diag` flag) runs it once per call.
# Rows are counted here, off the clean path (a bash 3.2 ${var//pattern} count is quadratic).
cg_map_diag() {
  local rows; rows="$(printf '%s\n' "$2" | grep -c .)"
  echo "STALE-MAP-DIAG: rev=$1 rows=$rows entries=$3 ulimit_n=$(ulimit -n) ulimit_u=$(ulimit -u)" >&2
}

# cg_review_commit <c> — for a commit already known to touch in-scope files (scope loaded), checks
# it is a reviewed PR merge: (a) 2 parents + `Code-Gate-PR: #N` trailer; (rule 8) every in-scope
# path changed in <c>^1..<c> is in the PR's diff <c>^1...<c>^2 AND identical to <c>^2;
# (b) PR N on $CG_REPO has base main, state OPEN|MERGED, headRefOid == <c>^2; (c) the LAST marker
# for that head reads `CODE-GATE-REVIEW: PASS head=<c>^2 blocking=0 medium=0`.
# Prints the reason on failure. rc 0 reviewed; 1 not reviewed; 2 cannot audit (gh/jq failed, or a git/temp-file failure: DIFF-FAIL).
cg_review_commit() {
  local c=$1 short pr sha2 rec recs p r out oid prbase state marker re
  short="$(git rev-parse --short "$c")"
  if [ "$(git rev-list --parents -n1 "$c" -- | wc -w | tr -d ' ')" != 3 ]; then
    echo "$short: in-scope change is not a 2-parent merge (use git merge --no-ff)"; return 1
  fi
  pr="$(git log -1 --format=%B "$c" -- | sed -nE 's/^Code-Gate-PR: #([0-9]+)[[:space:]]*$/\1/p' | tail -1)"
  [ -n "$pr" ] || { echo "$short: missing 'Code-Gate-PR: #N' trailer"; return 1; }
  sha2="$(git rev-parse "$c^2")"
  recs="$(mktemp)" || { echo "$short: cannot create a temp file (fail closed)"; return 2; }
  cg_changed ACMRD "$c^1" "$c" | cg_scoped >"$recs" || { rm -f "$recs"; echo "$short: DIFF-FAIL listing the changed files (git diff failed, fail closed)"; return 2; }
  # Read via fd 9; the cleanup trap closes fd 9 and removes $recs on EVERY return path.
  trap 'exec 9<&-; rm -f "$recs"; trap - RETURN' RETURN
  exec 9<"$recs" || { rm -f "$recs"; echo "$short: cannot read the changed-file list (fail closed)"; return 2; }
  while IFS= read -r -d '' rec; do
    p="${rec#*$'\t'}"
    git diff --quiet "$c^1...$c^2" -- ":(literal)$p"; r=$?
    case "$r" in
      1) ;;
      0) echo "$short: evil merge, in-scope '$(cg_show "$p")' changed by the merge is not in PR #$pr's diff"; return 1 ;;
      *) echo "$short: evil-merge check failed for '$(cg_show "$p")' (git rc $r, fail closed)"; return 1 ;;
    esac
    git diff --quiet "$c^2" "$c" -- ":(literal)$p"; r=$?
    [ "$r" = 0 ] || { echo "$short: evil merge, in-scope '$(cg_show "$p")' differs from PR head $sha2"; return 1; }
  done <&9
  out="$(gh pr view "$pr" --repo "$CG_REPO" --json headRefOid,baseRefName,state,comments 2>/dev/null)" ||
    { echo "$short: gh pr view $pr failed (fail closed)"; return 2; }
  oid="$(printf '%s' "$out" | jq -r '.headRefOid // empty' 2>/dev/null)" &&
    prbase="$(printf '%s' "$out" | jq -r '.baseRefName // empty' 2>/dev/null)" &&
    state="$(printf '%s' "$out" | jq -r '.state // empty' 2>/dev/null)" ||
    { echo "$short: cannot parse gh output for PR $pr (fail closed)"; return 2; }
  [ "$prbase" = main ] || { echo "$short: PR #$pr base is '$prbase', not main"; return 1; }
  case "$state" in OPEN|MERGED) ;; *) echo "$short: PR #$pr state is '$state', not OPEN or MERGED"; return 1 ;; esac
  [ "$oid" = "$sha2" ] || { echo "$short: PR #$pr head '$oid' != merge parent 2 $sha2"; return 1; }
  marker="$(printf '%s' "$out" | jq -r '.comments[]?.body // empty' 2>/dev/null | tr -d '\r' |
    grep -E "^CODE-GATE-REVIEW:.*head=$sha2( |\$)" | tail -1 | sed -E 's/[[:space:]]+$//')"
  [ -n "$marker" ] || { echo "$short: PR #$pr has no CODE-GATE-REVIEW marker for head $sha2"; return 1; }
  re="^CODE-GATE-REVIEW: PASS head=$sha2 blocking=0 medium=0\$"
  [[ "$marker" =~ $re ]] || { echo "$short: PR #$pr marker not a clean pass: '$marker'"; return 1; }
  return 0
}
