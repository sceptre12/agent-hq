#!/usr/bin/env bash
# tools/hermes/restore-hermes.sh — restore one backup generation made by backup-hermes.sh into a target directory.
# usage: restore-hermes.sh --gen <dest>/gen-YYYYmmddTHHMMSSZ --target <EMPTY-OR-NEW-DIR> [--force] | --help
# Order: (1) verify the generation's SHA256SUMS FIRST (fail closed, nothing is written on failure), (2) copy data/
# into the target, (3) re-verify the target by hash, (4) print "restored N files, hashes OK".
# Refuses: a non-empty target without --force; a target under ~/claude-profiles/hermes (the live home); a target
# path with a .. component or with a symlink component below the top level (/tmp, /var -> /private are resolved);
# a target that is not a directory, is inside the generation, or is the generation / the cwd / $HOME or an ancestor of
# one of them; with --force, a stale state.db-wal/-shm the generation lacks. --force MERGES into the target; it does
# not replace it. The generation is only read. Restoring into the LIVE home is an owner-only act done by the owner
# with the gateway down (see README); this script never targets it by default.
# exit codes: 0 ok | 2 usage | 4 verify failed (generation, symlink in it, or restored copy) | 5 refused target (or passwd home
#   unreadable: no python3) | 1 other failure (e.g. a read-only file in the target: may leave it PARTIALLY merged)
# TESTS-ONLY env: HERMES_BACKUP_FORBID_PREFIX=<dir> ADDS a forbidden prefix (the real ~/claude-profiles/hermes guard
#   is always on); --print-forbidden prints the guard list and exits 0; HERMES_RESTORE_TEST_CORRUPT_AFTER=1 flips a
#   byte in the restored copy after the copy, before the re-verify.
set -euo pipefail
export LC_ALL=C

die() { echo "restore-hermes: $2" >&2; exit "$1"; }
usage() { sed -n '2,/^set -euo/{/^set -euo/d;s/^# \{0,1\}//;p;}' "$0"; }

# rp <path>: physical absolute path; a not-yet-existing tail is appended to its resolved nearest ancestor.
rp() {
  local p="$1" tail="" base
  case "/$1/" in */../*) die 5 "refused: path contains a .. component" ;; esac   # a .. after a missing component would bypass every guard
  while [ ! -d "$p" ]; do
    base="$(basename -- "$p")" || die 5 "refused: cannot resolve path (basename unavailable)"
    p="$(dirname -- "$p")" || die 5 "refused: cannot resolve path (dirname unavailable)"
    [ -n "$base" ] && [ -n "$p" ] || die 5 "refused: cannot resolve path (empty component)"   # never loop on an empty path
    tail="/$base$tail"
  done
  p="$(cd -P -- "$p" && pwd)"
  [ "$p" = "/" ] && p=""
  printf '%s%s\n' "$p" "$tail"
}
# within <outer> <inner>: inner == outer or below. Compared case-INSENSITIVELY (macOS APFS is case-insensitive by
# default and cd -P keeps the spelling it was given); conservative, so on a case-sensitive volume two paths differing
# only in case are also treated as the same.
within() { local o i; o="$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')"; i="$(printf '%s/' "$2" | tr '[:upper:]' '[:lower:]')"
  case "$i" in "$o"/*) return 0 ;; *) return 1 ;; esac; }
# Forbidden live-home guard: always the real ~/claude-profiles/hermes ($HOME and passwd database, compared lexically,
# never stat'ed; also resolved physically, see below); the TESTS-ONLY env var can only ADD an entry.
PW_HOME="$(python3 -I -c 'import os,pwd;print(pwd.getpwuid(os.getuid()).pw_dir)' 2>/dev/null || true)"
[ -n "${PW_HOME%/}" ] || die 5 "cannot read the passwd home (python3 missing or failing); refusing"
FORBIDS=()
for h in "${HOME:-}" "$PW_HOME"; do if [ -n "${h%/}" ]; then FORBIDS+=("${h%/}/claude-profiles/hermes"); fi; done
[ "${#FORBIDS[@]}" -gt 0 ] || die 5 "cannot derive the live-home path to protect"
# The live entries are ALWAYS resolved physically (a symlinked claude-profiles must not hide them). With the TESTS-ONLY
# env var set only the parent is resolved and the leaf (the live home itself) is appended unresolved, so tests never stat it.
for h in "${FORBIDS[@]}"; do
  if [ -n "${HERMES_BACKUP_FORBID_PREFIX:-}" ]; then { lp="$(rp "${h%/*}")"; FORBIDS+=("$lp/${h##*/}"); }
  else FORBIDS+=("$(rp "$h")"); fi
done
[ -z "${HERMES_BACKUP_FORBID_PREFIX:-}" ] || FORBIDS+=("$(rp "$HERMES_BACKUP_FORBID_PREFIX")")

GEN=""; TARGET=""; FORCE=0
while [ "$#" -gt 0 ]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --print-forbidden) printf '%s\n' "${FORBIDS[@]}"; exit 0 ;;
    --gen) [ "$#" -ge 2 ] || die 2 "--gen needs a value"; GEN="$2"; shift 2 ;;
    --target) [ "$#" -ge 2 ] || die 2 "--target needs a value"; TARGET="$2"; shift 2 ;;
    --force) FORCE=1; shift ;;
    *) die 2 "unknown argument: $1" ;;
  esac
done
[ -n "$GEN" ] || die 2 "--gen is required"
[ -n "$TARGET" ] || die 2 "--target is required"
[ -d "$GEN" ] && [ -d "$GEN/data" ] && [ -f "$GEN/SHA256SUMS" ] || die 2 "--gen is not a backup generation"

# --- target checks (before touching anything) ---
case "$TARGET" in /*) ABS="$TARGET" ;; *) ABS="$PWD/$TARGET" ;; esac
walk=""; depth=0; rest="${ABS#/}"
while [ -n "$rest" ]; do
  comp="${rest%%/*}"; case "$rest" in */*) rest="${rest#*/}" ;; *) rest="" ;; esac
  [ -z "$comp" ] && continue
  walk="$walk/$comp"; depth=$((depth + 1))
  # A top-level system link (macOS /tmp, /var, /etc -> /private/...) is resolved by rp below, not refused.
  # Any deeper symlink component, including the target itself, is refused (never followed).
  if [ -L "$walk" ] && [ "$depth" -gt 1 ]; then die 5 "refused: target path has a symlink component below the top level: $walk"; fi
done
TARGET_RP="$(rp "$ABS")"
for fb in "${FORBIDS[@]}"; do
  if within "$fb" "$TARGET_RP"; then die 5 "refused: target is under the forbidden live-home prefix"; fi
done
GEN_RP="$(cd -P -- "$GEN" && pwd)"
if within "$GEN_RP" "$TARGET_RP"; then die 5 "refused: target is inside the generation"; fi
# --force MERGES: never into the generation itself, the cwd, $HOME, or any ancestor of those (a parent or "." would be overwritten).
for anc in "$GEN_RP" "$(pwd -P)" "$(rp "${HOME:-/}")"; do
  if within "$TARGET_RP" "$anc"; then die 5 "refused: target is, or contains, the generation, the cwd or \$HOME"; fi
done
if [ -e "$TARGET_RP" ] && [ ! -d "$TARGET_RP" ]; then die 5 "refused: target exists and is not a directory"; fi
if [ -d "$TARGET_RP" ] && [ -n "$(ls -A "$TARGET_RP")" ] && [ "$FORCE" -ne 1 ]; then
  die 5 "refused: target is not empty (use --force)"
fi

# --force MERGES into the target. Stale sqlite sidecar files that the generation lacks would corrupt state.db.
for sc in state.db-wal state.db-shm; do
  if [ -d "$TARGET_RP" ] && { [ -e "$TARGET_RP/$sc" ] || [ -L "$TARGET_RP/$sc" ]; } && [ ! -f "$GEN_RP/data/$sc" ]; then
    die 5 "refused: target has a stale $sc that the generation does not contain (move it aside)"
  fi
done

# --- (1) verify the generation first: fail closed ---
NSUMS="$(wc -l <"$GEN_RP/SHA256SUMS" | tr -d ' ')"
NDATA="$(cd "$GEN_RP/data" && find . -type f | wc -l | tr -d ' ')"
[ "$NSUMS" = "$NDATA" ] || die 4 "generation file count differs from SHA256SUMS ($NDATA vs $NSUMS)"
( cd "$GEN_RP/data" && shasum -a 256 -c "$GEN_RP/SHA256SUMS" >/dev/null 2>&1 ) || die 4 "generation fails SHA256SUMS; nothing restored"
# A symlink is not a regular file: neither counted nor hashed above, and cp -Rp would restore it as a link. Refuse.
[ -z "$(find "$GEN_RP/data" -type l -print -quit)" ] || die 4 "generation contains a symlink; nothing restored"

# --- (2) copy, (3) re-verify the restored files by hash ---
mkdir -p "$TARGET_RP"
cp -Rp "$GEN_RP/data/." "$TARGET_RP/"
if [ "${HERMES_RESTORE_TEST_CORRUPT_AFTER:-0}" = 1 ]; then   # TESTS ONLY
  first="$(head -n 1 "$GEN_RP/SHA256SUMS" | cut -c 67-)"; printf 'X' | dd of="$TARGET_RP/$first" bs=1 count=1 conv=notrunc 2>/dev/null
fi
( cd "$TARGET_RP" && shasum -a 256 -c "$GEN_RP/SHA256SUMS" >/dev/null 2>&1 ) || die 4 "restored copy fails SHA256SUMS"
echo "restore-hermes: restored $NSUMS files, hashes OK"
EXTRA=$(( $(find "$TARGET_RP" -type f | wc -l | tr -d ' ') - NSUMS ))
if [ "$EXTRA" -gt 0 ]; then echo "restore-hermes: target had $EXTRA extra files not in the generation (--force merges, it does not replace)"; fi
