#!/usr/bin/env bash
# tools/hermes/backup-hermes.sh — Hermes backup agent (architecture/hermes-agent-memory.md section 7, row 6).
# Writes ONE dated, hash-verified generation of the Hermes durable state under <dest>/gen-YYYYmmddTHHMMSSZ/.
# STRICTLY READ-ONLY on --src. Not a mirror: each run adds a generation; old ones are pruned by --keep.
#
# usage: backup-hermes.sh --src <HERMES_HOME> --dest <BACKUP_ROOT> [--keep N] [--allow-live] | --help
#   (no defaults for --src / --dest; --help prints this header and touches nothing)
# scope (relative to --src; brain default under R-q, owner may veto): memories/ ; skills/ incl. skills/.archive and
#   skills/.curator_ledger.jsonl ; .curator_backups/blobs/ ; state.db + state.db-wal + state.db-shm if present ;
#   pending/. Dotfiles included. Missing optional pieces are recorded in MANIFEST.txt; BOTH memories/ and skills/
#   missing is an error.
# retention: --keep N, default 7 (brain default under R-q, owner may veto). After a VERIFIED new generation the
#   oldest gen-* dirs beyond N are removed (never the new one; only real dirs named gen-<8 digits>T<6 digits>Z
#   directly under dest).
# quiesce: state.db / -wal / -shm must not be open by another process (lsof). Open, or lsof absent: exit 3 and
#   nothing is written, unless --allow-live (copy proceeds; MANIFEST.txt says "LIVE COPY: not guaranteed consistent").
#   If lsof is present but fails, the files count as not open (README "Known limits").
# exit codes: 0 ok | 2 usage / invalid source / no files in scope | 3 not quiesced (state.db open, or lsof absent) |
#   4 verify failed, source changed during backup, or state.db failed PRAGMA integrity_check |
#   5 refused path (.. component, forbidden live home, passwd home unreadable (no python3), dest inside src, dest is a
#   file or symlink), symlink in scope, or stamp collision | 1 any other failure (unreadable file, cp error): nothing is published
# TESTS-ONLY env (never set in production): HERMES_BACKUP_NOW=<UTC stamp>; HERMES_BACKUP_FORBID_PREFIX=<dir> (ADDS a
#   forbidden prefix; the real ~/claude-profiles/hermes guard is always on); --print-forbidden (print the guard list,
#   exit 0); HERMES_BACKUP_TEST_CORRUPT=1 (flip a byte in the staged copy before verify); HERMES_BACKUP_TEST_EXTRA=1
#   (add an extra file to the staged copy); HERMES_BACKUP_TEST_MUTATE_SRC=<rel path> (append a byte to that SOURCE file
#   after the manifest is computed); HERMES_BACKUP_TEST_MUTATE_SRC_AFTER=<rel path> (same, but AFTER the staged verify
#   and before the post-copy re-hash); HERMES_BACKUP_TEST_MKGEN_RACE=1 (create the target gen dir just before publish).
set -euo pipefail
export LC_ALL=C
umask 077   # staging, .tmp-* and gen-* dirs hold state.db and memories: dirs 700, new files 600

die() { echo "backup-hermes: $2" >&2; exit "$1"; }
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

# Forbidden live-home guard: the real ~/claude-profiles/hermes (from $HOME and from the passwd database) is ALWAYS
# in the list; HERMES_BACKUP_FORBID_PREFIX (TESTS ONLY) can only ADD an entry. The two live-path entries are compared
# lexically (never stat'ed) and ALSO resolved physically (in tests-only mode: parent only, see below).
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

SRC=""; DEST=""; KEEP=7; ALLOW_LIVE=0
while [ "$#" -gt 0 ]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --print-forbidden) printf '%s\n' "${FORBIDS[@]}"; exit 0 ;;
    --src) [ "$#" -ge 2 ] || die 2 "--src needs a value"; SRC="$2"; shift 2 ;;
    --dest) [ "$#" -ge 2 ] || die 2 "--dest needs a value"; DEST="$2"; shift 2 ;;
    --keep) [ "$#" -ge 2 ] || die 2 "--keep needs a value"; KEEP="$2"; shift 2 ;;
    --allow-live) ALLOW_LIVE=1; shift ;;
    *) die 2 "unknown argument: $1" ;;
  esac
done
[ -n "$SRC" ] || die 2 "--src is required"
[ -n "$DEST" ] || die 2 "--dest is required"
case "$KEEP" in ''|*[!0-9]*|0|0[0-9]*) die 2 "--keep must be an integer >= 1" ;; esac
[ -d "$SRC" ] || die 2 "--src is not a directory"
[ ! -L "${DEST%/}" ] || die 5 "refused: --dest is a symlink (point --dest at the real directory)"

SRC_RP="$(rp "$SRC")"; DEST_RP="$(rp "$DEST")"
if within "$SRC_RP" "$DEST_RP"; then die 5 "refused: dest is inside src"; fi
if within "$DEST_RP" "$SRC_RP"; then die 5 "refused: src is inside dest"; fi
for fb in "${FORBIDS[@]}"; do
  if within "$fb" "$DEST_RP"; then die 5 "refused: dest is under the forbidden live-home prefix"; fi
done
if [ -e "$DEST_RP" ] && [ ! -d "$DEST_RP" ]; then die 5 "refused: dest exists and is not a directory"; fi

STAMP="${HERMES_BACKUP_NOW:-$(date -u +%Y%m%dT%H%M%SZ)}"
case "$STAMP" in [0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]T[0-9][0-9][0-9][0-9][0-9][0-9]Z) ;; *) die 2 "bad stamp" ;; esac

# Pieces: name relative to src, kind (d = directory, f = file), required-ness handled below.
PIECES="memories:d skills:d .curator_backups/blobs:d state.db:f state.db-wal:f state.db-shm:f pending:d"
PRESENT=""; ABSENT=""
for pc in $PIECES; do
  name="${pc%:*}"; kind="${pc#*:}"
  if { [ "$kind" = d ] && [ -d "$SRC_RP/$name" ]; } || { [ "$kind" = f ] && [ -f "$SRC_RP/$name" ]; }; then
    PRESENT="$PRESENT $name"
  else ABSENT="$ABSENT $name"; fi
done
# Symlinks in scope are refused (fail closed, never followed): cp would copy a bare link and hash nothing behind it.
for pc in $PIECES; do
  name="${pc%:*}"
  if [ -L "$SRC_RP/$name" ] || [ -L "$SRC_RP/$(dirname "$name")" ]; then
    die 5 "refused: $name (or its parent) is a symlink; a Hermes home with symlinks in scope is refused (ask the owner)"
  fi
done
for name in $PRESENT; do
  if [ -d "$SRC_RP/$name" ]; then
    LNK="$(find "$SRC_RP/$name" -type l -print -quit)"
    [ -z "$LNK" ] || die 5 "refused: symlink inside scope: ${LNK#"$SRC_RP"/} (a Hermes home with symlinks in scope is refused; ask the owner)"
  fi
done
case " $PRESENT " in *" memories "*|*" skills "*) ;; *) die 2 "neither memories/ nor skills/ exists in src" ;; esac

# --- quiesce: no other process may hold the sqlite files open ---
LIVE_NOTE=""
DBFILES=()
for f in state.db state.db-wal state.db-shm; do if [ -f "$SRC_RP/$f" ]; then DBFILES+=("$SRC_RP/$f"); fi; done
if [ "${#DBFILES[@]}" -gt 0 ]; then
  if ! command -v lsof >/dev/null 2>&1; then
    echo "backup-hermes: lsof is absent: cannot prove state.db is quiesced" >&2
    [ "$ALLOW_LIVE" -eq 1 ] || die 3 "treated as not quiesced (use --allow-live to override)"
    LIVE_NOTE="LIVE COPY: not guaranteed consistent (lsof absent)"
  else
    OPEN="$(lsof -t -- "${DBFILES[@]}" 2>/dev/null || true)"
    if [ -n "$OPEN" ]; then
      echo "backup-hermes: state.db is open by another process" >&2
      [ "$ALLOW_LIVE" -eq 1 ] || die 3 "not quiesced; stop the gateway or use --allow-live"
      LIVE_NOTE="LIVE COPY: not guaranteed consistent"
    fi
  fi
fi

# --- manifest from the SOURCE (relative paths, sorted) BEFORE copying; nothing is written yet ---
SUMS="$(cd "$SRC_RP" && for name in $PRESENT; do find "$name" -type f -print; done | sort | while IFS= read -r f; do
  shasum -a 256 -- "$f"; done)"
NFILES=0; [ -z "$SUMS" ] || NFILES="$(printf '%s\n' "$SUMS" | wc -l | tr -d ' ')"
[ "$NFILES" -gt 0 ] || die 2 "no files in scope: nothing to back up"   # loud on purpose: an empty source must not rotate good generations out
if [ -n "${HERMES_BACKUP_TEST_MUTATE_SRC:-}" ]; then printf 'M' >>"$SRC_RP/$HERMES_BACKUP_TEST_MUTATE_SRC"; fi   # TESTS ONLY

# --- stage: <dest>/.tmp-<stamp>-<pid>/data, verify against the source-derived hashes, then rename to gen-<stamp> ---
GEN="$DEST_RP/gen-$STAMP"
[ ! -e "$GEN" ] && [ ! -L "$GEN" ] || die 5 "generation $STAMP already exists (same-second collision)"
mkdir -p "$DEST_RP" 2>/dev/null || die 5 "cannot create dest (a path component is a file?)"
TMPD="$DEST_RP/.tmp-$STAMP-$$"
cleanup() {
  local rc=$?
  case "$TMPD" in "$DEST_RP"/.tmp-*) [ -d "$TMPD" ] && rm -rf "$TMPD" ;; esac
  exit "$rc"
}
trap cleanup EXIT
mkdir "$TMPD" "$TMPD/data"
for name in $PRESENT; do
  mkdir -p "$TMPD/data/$(dirname "$name")"
  cp -Rp "$SRC_RP/$name" "$TMPD/data/$name"
done
chmod -R go-rwx "$TMPD/data"   # cp -p keeps the source modes (often 644): the staged copy is owner-only
printf '%s\n' "$SUMS" >"$TMPD/SHA256SUMS"
{
  echo "hermes backup generation"
  echo "stamp: $STAMP"
  echo "src: $SRC_RP"
  echo "present:${PRESENT:- (none)}"
  echo "absent (optional, recorded not an error):${ABSENT:- (none)}"
  echo "files: $NFILES"
  echo "hashes: taken from the source before copying; the copy is verified against them"
  for name in $PRESENT; do
    echo "count $name: $(find "$TMPD/data/$name" -type f | wc -l | tr -d ' ')"
  done
  [ -z "$LIVE_NOTE" ] || echo "$LIVE_NOTE"
  if [ "$ALLOW_LIVE" -eq 1 ]; then
    echo "LIVE COPY: source not re-hashed after the copy (--allow-live)"
  else echo "source re-hashed after the copy: unchanged"; fi
} >"$TMPD/MANIFEST.txt"

if [ "${HERMES_BACKUP_TEST_CORRUPT:-0}" = 1 ]; then
  first="$(head -n 1 "$TMPD/SHA256SUMS" | cut -c 67-)"
  printf 'X' | dd of="$TMPD/data/$first" bs=1 count=1 conv=notrunc 2>/dev/null
fi
if [ "${HERMES_BACKUP_TEST_EXTRA:-0}" = 1 ]; then echo x >"$TMPD/data/extra.txt"; fi   # TESTS ONLY

# --- verify the staged copy against the source-derived SHA256SUMS (and that no extra file appeared) ---
ACTUAL="$(cd "$TMPD/data" && find . -type f | wc -l | tr -d ' ')"
if [ "$ACTUAL" != "$NFILES" ] || ! ( cd "$TMPD/data" && shasum -a 256 -c "../SHA256SUMS" >/dev/null 2>&1 ); then
  die 4 "verification of the staged copy failed; nothing published"
fi
if [ -n "${HERMES_BACKUP_TEST_MUTATE_SRC_AFTER:-}" ]; then printf 'M' >>"$SRC_RP/$HERMES_BACKUP_TEST_MUTATE_SRC_AFTER"; fi   # TESTS ONLY
if [ "$ALLOW_LIVE" -ne 1 ]; then
  AFTER="$(cd "$SRC_RP" && for name in $PRESENT; do find "$name" -type f -print; done | sort | while IFS= read -r f; do
    shasum -a 256 -- "$f"; done)"
  [ "$AFTER" = "$SUMS" ] || die 4 "source changed during backup; nothing published"
fi
# Source health (NOT proved by the hash check, which only shows copy == source): PRAGMA integrity_check on a scratch COPY of
# the staged state.db (+ -wal/-shm), so nothing in the staged dir is modified. It must be exactly "ok". Covers state.db only.
if [ -f "$TMPD/data/state.db" ]; then
  HC="$(mktemp -d)"
  for f in state.db state.db-wal state.db-shm; do if [ -f "$TMPD/data/$f" ]; then cp "$TMPD/data/$f" "$HC/$f"; fi; done
  IC="$(python3 -I -c 'import sqlite3,sys
try:
    r = [x[0] for x in sqlite3.connect(sys.argv[1]).execute("PRAGMA integrity_check")]
    print(r[0] if len(r) == 1 else "several problems")
except Exception as e:
    print("error: " + type(e).__name__)' "$HC/state.db" 2>/dev/null || echo "python3 failed")"
  rm -rf "$HC"
  [ "$IC" = ok ] || die 4 "source state.db failed integrity_check ($IC); nothing published"
fi
# Generation pools: --allow-live generations are not safe recovery points, so they are retained in their own pool and
# never evict clean generations. gens_of <clean|live>: valid generation names (real dir with SHA256SUMS + MANIFEST.txt + data/), newest first.
gens_of() {
  find "$DEST_RP" -mindepth 1 -maxdepth 1 -type d -print | while IFS= read -r d; do basename -- "$d"; done \
    | { grep -E '^gen-[0-9]{8}T[0-9]{6}Z$' || true; } | sort -r | while IFS= read -r g; do
    if [ -f "$DEST_RP/$g/SHA256SUMS" ] && [ -f "$DEST_RP/$g/MANIFEST.txt" ] && [ -d "$DEST_RP/$g/data" ] && [ ! -L "$DEST_RP/$g/data" ]; then
      if grep -q '^LIVE COPY' "$DEST_RP/$g/MANIFEST.txt" 2>/dev/null; then k=live; else k=clean; fi
      if [ "$k" = "$1" ]; then echo "$g"; fi
    fi
  done
}
KIND=clean; [ "$ALLOW_LIVE" -ne 1 ] || KIND=live
PREV="$(gens_of "$KIND" | sed -n 1p)"; PREV_N=0
if [ -n "$PREV" ]; then PREV_N="$(wc -l <"$DEST_RP/$PREV/SHA256SUMS" | tr -d ' ')"; fi
SHRINK=0; [ $((NFILES * 2)) -ge "$PREV_N" ] || SHRINK=1
[ -z "${HERMES_BACKUP_TEST_MKGEN_RACE:-}" ] || mkdir "$GEN"   # TESTS ONLY
[ ! -e "$GEN" ] || die 5 "generation $STAMP appeared meanwhile"
mv "$TMPD" "$GEN"
echo "backup-hermes: wrote $GEN from $SRC_RP ($NFILES files, copy verified against the source hashes)"

# --- retention: keep the newest KEEP generations of this run's pool; never the one just written ---
if [ "$SHRINK" -eq 1 ]; then
  echo "backup-hermes: WARNING: this generation has $NFILES files, under 50% of the previous one ($PREV_N); retention SKIPPED, nothing pruned. Check the source." >&2
  exit 0
fi
IDX=0
for g in $(gens_of "$KIND"); do
  IDX=$((IDX + 1))
  if [ "$IDX" -gt "$KEEP" ] && [ "$g" != "gen-$STAMP" ]; then rm -rf "${DEST_RP:?}/$g"; echo "backup-hermes: pruned $g"; fi
done
exit 0
