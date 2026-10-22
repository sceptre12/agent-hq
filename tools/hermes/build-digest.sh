#!/usr/bin/env bash
# tools/hermes/build-digest.sh <sha> <out-root> — build the read-only Hermes snapshot of hq at <sha>
# (architecture/hermes-agent.md §7, §13 D3/D8; tools/hermes/README.md).
# Writes <out-root>/hq/<sha>/ (git archive of the digest-set.txt selection), MANIFEST.tsv, the staged index skill
# .index/hq-index/SKILL.md, then `chmod -R a-w`, runs verify-digest.sh and only on its pass flips
# <out-root>/hq/current with `ln -sfn`. Previous snapshots are kept. Any secret hit (tools/git-hooks/pre-commit
# check (c) regex) prints the PATH only, deletes the partial snapshot and exits 3.
# hq repo: $HQ_REPO, else the repo holding this script. Never runs Hermes, never fetches, never writes under hq.
# Exit: 0 ok, 1 error, 2 usage, 3 secret hit, 4 stale, 5 mismatch.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SET="${HERMES_DIGEST_SET:-$HERE/digest-set.txt}"
VERIFY="$HERE/verify-digest.sh"
# pre-commit check (c), reused verbatim without its `^\+.*` diff prefix (test_build-digest.sh guards drift).
SECRET_RE='(-----BEGIN [A-Z ]*PRIVATE KEY-----|AKIA[0-9A-Z]{16}|sk-ant-(oat|ort|api)[0-9]{2}-)'
usage() { echo "usage: build-digest.sh <sha> <out-root>   (hq repo: \$HQ_REPO or this script's repo)" >&2; exit 2; }
err() { echo "build-digest: $1" >&2; exit 1; }

[ $# = 2 ] && [ -n "$1" ] && [ -n "$2" ] || usage
hq="$(git -C "${HQ_REPO:-$HERE}" rev-parse --show-toplevel 2>/dev/null)" || { echo "build-digest: not a git repo: ${HQ_REPO:-$HERE}" >&2; usage; }
hq="$(cd -P "$hq" && pwd)"
sha="$(git -C "$hq" rev-parse --verify --quiet "$1^{commit}")" || { echo "build-digest: not a commit: $1" >&2; usage; }
mkdir -p "$2/hq" || err "cannot create $2/hq"
root="$(cd -P "$2" && pwd)" || usage
case "$root/" in "$hq"/*) echo "build-digest: out-root $root is inside the hq repo (no writes under hq)" >&2; usage ;; esac
base="$root/hq"; dest="$base/$sha"
[ ! -e "$dest" ] || err "snapshot exists: $dest (verify it with verify-digest.sh; it is never overwritten)"

work="$(mktemp -d "$base/.build-$sha.XXXXXX")" || err "mktemp failed"
sel="$(mktemp "$base/.sel-$sha.XXXXXX")" || err "mktemp failed"
cleanup() { [ -n "${work:-}" ] && [ -e "$work" ] && chmod -R u+w "$work" 2>/dev/null; [ -n "${work:-}" ] && rm -rf "$work"; rm -f "$sel"; }
trap cleanup EXIT
trap 'exit 130' INT; trap 'exit 143' TERM

HERMES_DIGEST_SET="$SET" "$VERIFY" --paths "$sha" "$hq" >"$sel" || err "cannot select the digest set at $sha"
[ -s "$sel" ] || err "digest set selects no file at $sha"
paths=(); while IFS=$'\t' read -r _ _ p _; do paths+=("$p"); done <"$sel"
chmod 755 "$work"
git --literal-pathspecs -C "$hq" archive --format=tar "$sha" -- "${paths[@]}" | tar -xf - -C "$work"
rc=("${PIPESTATUS[@]}"); [ "${rc[0]}" = 0 ] && [ "${rc[1]}" = 0 ] || err "git archive | tar failed (${rc[*]})"

# Secret abort: names only (grep -l), never the match. A scan error fails closed.
hits="$(cd "$work" && LC_ALL=C grep -rlaE -e "$SECRET_RE" .)"; grc=$?
if [ "$grc" = 0 ]; then
  printf '%s\n' "$hits" | sed 's|^\./||; s|^|SECRET-HIT: |' >&2
  echo "build-digest: secret-shaped content found; partial snapshot deleted, nothing built" >&2; exit 3
elif [ "$grc" != 1 ]; then
  echo "build-digest: secret scan failed (grep rc $grc; fail closed); partial snapshot deleted" >&2; exit 3
fi

{ printf '# hq %s built %s\n' "$sha" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  awk -F'\t' '{ printf "%s\t%s\n", $3, $4 }' "$sel" | LC_ALL=C sort; } >"$work/MANIFEST.tsv" || err "cannot write MANIFEST.tsv"

# Index skill (staged; the owner approves it into HERMES_HOME/skills/hq-index/ in H4): pointers, not content.
mkdir -p "$work/.index/hq-index" || err "cannot create .index"
{ printf -- '---\nname: hq-index\ndescription: Pointer index of the read-only hq snapshot at %s; grep first, read the matched slice, cite path:line@sha.\n---\n' "$sha"
  printf '# hq-index — hq %s\n\n' "$sha"
  printf 'Snapshot: hq main at %s (read-only; MANIFEST.tsv beside the files).\n' "$sha"
  printf 'Root: %s/current/ (this snapshot: %s/%s/). Pass ABSOLUTE paths to read_file and search_files — relative paths resolve against the tool cwd, not the snapshot; search roots outside %s are refused.\n' "$base" "$base" "$sha" "$base"
  printf 'Retrieval rule: grep first, read the matched slice, cite `path:line@%s`. This index is pointers only (path + first `#` heading), never a summary.\n' "$sha"
  printf 'Consult in this order: %s.\n' "$(awk '$1 == "group" { $1 = ""; sub(/^ /, ""); n = $1; $1 = ""; sub(/^ /, ""); printf "%s%s. %s", (c++ ? "; " : ""), n, $0 }' "$SET")"
  last=""
  while IFS=$'\t' read -r _ g p _; do
    if [ "$g" != "$last" ]; then
      printf '\n## %s. %s\n\n' "$g" "$(awk -v g="$g" '$1 == "group" && $2 == g { $1 = ""; $2 = ""; sub(/^  /, ""); print; exit }' "$SET")"
      last="$g"
    fi
    h="$(LC_ALL=C grep -m1 -aE '^# ' "$work/$p" | tr -d '\r' | sed 's/^# *//')"
    printf -- '- `%s` — %s\n' "$p" "${h:-(no heading)}"
  done <"$sel"
} >"$work/.index/hq-index/SKILL.md" || err "cannot write the index skill"

mv "$work" "$dest" || err "cannot move the snapshot into place"
work="$dest"                                          # from here on, a failure deletes the unflipped snapshot
chmod -R a-w "$dest" || err "chmod -R a-w failed"
"$VERIFY" "$dest" "$hq"; vrc=$?
[ "$vrc" = 0 ] || { echo "build-digest: verify failed (rc $vrc); snapshot deleted, current not flipped" >&2; exit "$vrc"; }
ln -sfn "$sha" "$base/current" || err "cannot flip $base/current"
work=""
n="$(($(wc -l <"$dest/MANIFEST.tsv") - 1))"
bytes="$(cut -f1 <(tail -n +2 "$dest/MANIFEST.tsv") | (cd "$dest" && tr '\n' '\0' | xargs -0 cat) | wc -c | tr -d ' ')"
echo "BUILT hq $sha files=$n bytes=$bytes current -> $sha"
