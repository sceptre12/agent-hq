#!/usr/bin/env bash
# tools/hermes/verify-digest.sh — prove a Hermes hq snapshot equals hq main (architecture/hermes-agent.md §7 "Verify the digest matches main";
# tools/hermes/README.md).
#   verify-digest.sh <snapshot-dir> [<hq-repo>]   checks (1)-(4), prints `DIGEST == MAIN <sha>`
#   verify-digest.sh --paths <sha> [<hq-repo>]    prints the selected set: <include-idx>\t<group>\t<path>\t<blob>
# (1) manifest sha == `git -C <hq> rev-parse origin/main`, else STALE (exit 4); (2) every file's `git hash-object`
# == its manifest blob; (3) manifest paths == the digest-set selection of `git ls-tree -r <sha>`; (4) no file outside
# the manifest. (2)-(4) ignore exactly MANIFEST.tsv and .index/** at the snapshot root.
# Exit: 0 ok, 1 error, 2 usage, 4 stale, 5 mismatch. Read-only: never writes, never fetches.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SET="${HERMES_DIGEST_SET:-$HERE/digest-set.txt}"
usage() { echo "usage: verify-digest.sh <snapshot-dir> [<hq-repo>] | --paths <sha> [<hq-repo>]" >&2; exit 2; }
err() { echo "verify-digest: $1" >&2; exit 1; }
hq_root() { git -C "${1:-$HERE}" rev-parse --show-toplevel 2>/dev/null || { echo "verify-digest: not a git repo: ${1:-$HERE}" >&2; exit 2; }; }

# select_paths <hq> <sha> — the digest set at <sha>, in index order (include line, then path LC_ALL=C).
select_paths() {
  local tree
  [ -r "$SET" ] || err "cannot read digest set $SET"
  tree="$(git -c core.quotePath=false -C "$1" ls-tree -r --full-tree "$2")" || err "cannot list tree $2"
  printf '%s\n' "$tree" | LC_ALL=C awk -F'\t' -v setfile="$SET" '
    function g2re(g,   r, i, c) {
      r = ""
      for (i = 1; i <= length(g); i++) {
        c = substr(g, i, 1)
        if (substr(g, i, 3) == "**/") { r = r "(.*/)?"; i += 2 }
        else if (substr(g, i, 2) == "**") { r = r ".*"; i++ }
        else if (c == "*") r = r "[^/]*"
        else if (c == "?") r = r "[^/]"
        else if (c == "\\") r = r "[\\\\]"
        else if (c == "^") r = r "\\^"
        else if (index(".[]()+{}|$", c)) r = r "[" c "]"
        else r = r c
      }
      return "^" r "$"
    }
    BEGIN {
      while ((getline line < setfile) > 0) {
        if (line ~ /^[ \t]*(#|$)/) continue
        n = split(line, w, " ")
        if (w[1] == "group" && n >= 3) continue
        else if (w[1] == "include" && n == 3) { ni++; inc[ni] = g2re(w[3]); grp[ni] = w[2] }
        else if (w[1] == "exclude" && (n == 2 || (n == 4 && w[3] == "unless"))) {
          ne++; exc[ne] = tolower(g2re(w[2])); unl[ne] = (n == 4) ? tolower(g2re(w[4])) : ""
        } else { print "verify-digest: bad digest-set line: " line > "/dev/stderr"; bad = 1; exit 1 }
      }
      if (!ni) { print "verify-digest: digest set has no include lines" > "/dev/stderr"; bad = 1; exit 1 }
    }
    {
      split($1, m, " "); p = $2
      if (substr(p, 1, 1) == "\"") { print "verify-digest: unsupported path (quoted by git): " p > "/dev/stderr"; bad = 1; exit 1 }
      if (m[2] != "blob" || (m[1] != "100644" && m[1] != "100755")) next
      for (i = 1; i <= ni; i++) if (p ~ inc[i]) break
      if (i > ni) next
      lp = tolower(p)
      for (j = 1; j <= ne; j++) if (lp ~ exc[j] && !(unl[j] != "" && lp ~ unl[j])) next
      printf "%d\t%s\t%s\t%s\n", i, grp[i], p, m[3]
    }
    END { exit bad }' | LC_ALL=C sort -t "$(printf '\t')" -k1,1n -k3,3
  local rc=("${PIPESTATUS[@]}")
  [ "${rc[1]}" = 0 ] && [ "${rc[2]}" = 0 ] || err "digest-set selection failed"
}

if [ "${1:-}" = "--paths" ]; then
  [ $# -ge 2 ] && [ $# -le 3 ] || usage
  hq="$(hq_root "${3:-}")" || exit 2
  sha="$(git -C "$hq" rev-parse --verify --quiet "$2^{commit}")" || usage
  select_paths "$hq" "$sha"; exit $?
fi
[ $# -ge 1 ] && [ $# -le 2 ] || usage
[ -d "$1" ] || usage
hq="$(hq_root "${2:-}")" || exit 2
snap="$(cd -P "$1" && pwd)" || usage
man="$snap/MANIFEST.tsv"
[ -f "$man" ] || { echo "MISMATCH: MANIFEST.tsv missing in $snap"; exit 5; }
head1="$(head -n 1 "$man")"
[[ "$head1" =~ ^#\ hq\ ([0-9a-f]{40})\ built\ [0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]] ||
  { echo "MISMATCH: malformed MANIFEST.tsv header"; exit 5; }
sha="${BASH_REMATCH[1]}"
# (1) freshness
main="$(git -C "$hq" rev-parse --verify --quiet origin/main)" || { echo "STALE: cannot resolve origin/main in hq"; exit 4; }
[ "$sha" = "$main" ] || { echo "STALE: manifest $sha != origin/main $main"; exit 4; }

work="$(mktemp -d "${TMPDIR:-/tmp}/verify-digest.XXXXXX")" || err "mktemp failed"
trap 'rm -rf "$work"' EXIT
miss=0
mm() { echo "MISMATCH: $1"; miss=$((miss + 1)); }
tail -n +2 "$man" >"$work/rows" || err "cannot read manifest"
awk -F'\t' 'NF != 2 || $1 == "" || $2 !~ /^[0-9a-f]{40}$/ { exit 1 }' "$work/rows" || mm "malformed MANIFEST.tsv row"
cut -f1 "$work/rows" >"$work/man.paths"
LC_ALL=C sort -cu "$work/man.paths" 2>/dev/null || mm "MANIFEST.tsv paths not LC_ALL=C sorted and unique"
# (2) content: every manifest file is a regular file whose blob sha matches
: >"$work/present"
while IFS=$'\t' read -r p b; do
  case "/$p/" in */../*|*/./*|//*) mm "unsafe manifest path $p"; continue ;; esac
  case "$p" in MANIFEST.tsv|.index/*) mm "manifest lists reserved path $p"; continue ;; esac
  if [ -L "$snap/$p" ] || [ ! -f "$snap/$p" ]; then mm "missing or not a regular file: $p"; continue; fi
  printf '%s\t%s\n' "$p" "$b" >>"$work/present"
done <"$work/rows"
if [ -s "$work/present" ]; then
  (cd "$snap" && cut -f1 "$work/present" | git hash-object --no-filters --stdin-paths) >"$work/got" || err "git hash-object failed"
  paste "$work/present" "$work/got" >"$work/cmp"
  while IFS=$'\t' read -r p want got; do [ "$want" = "$got" ] || mm "content differs: $p"; done <"$work/cmp"
fi
# (3) path list == the selection at <sha>
select_paths "$hq" "$sha" >"$work/sel" || exit 1
cut -f3 "$work/sel" | LC_ALL=C sort >"$work/want.paths"
LC_ALL=C sort "$work/man.paths" >"$work/man.sorted"
while IFS= read -r p; do mm "not in manifest but in main: $p"; done < <(LC_ALL=C comm -23 "$work/want.paths" "$work/man.sorted")
while IFS= read -r p; do mm "in manifest but not in main's set: $p"; done < <(LC_ALL=C comm -13 "$work/want.paths" "$work/man.sorted")
# (4) nothing outside the manifest (ignoring exactly MANIFEST.tsv and .index/**)
(cd "$snap" && find . \( -path ./MANIFEST.tsv -o -path './.index/*' \) -prune -o ! -type d -print) |
  sed 's|^\./||' | LC_ALL=C sort >"$work/have.paths" || err "cannot list snapshot"
while IFS= read -r p; do mm "extra file in snapshot: $p"; done < <(LC_ALL=C comm -23 "$work/have.paths" "$work/man.sorted")
if [ "$miss" = 0 ]; then echo "DIGEST == MAIN $sha"; exit 0; fi
echo "DIGEST != MAIN $sha ($miss mismatches)"; exit 5
