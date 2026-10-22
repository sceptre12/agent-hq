#!/usr/bin/env bash
# tools/hermes/test_backup-hermes-2.sh — review-fix tests for backup-hermes.sh + restore-hermes.sh (Hermes row 6):
# symlinks, empty tree, source-derived hashes, case-insensitive refusal, restore paths, perms, --force, plist.
# SYNTHETIC trees only under a fresh mktemp -d (cd -P). No Hermes, no live home, no network.
set -uo pipefail
unset HERMES_BACKUP_NOW HERMES_BACKUP_TEST_CORRUPT HERMES_BACKUP_TEST_MUTATE_SRC HERMES_BACKUP_TEST_MUTATE_SRC_AFTER \
  HERMES_BACKUP_TEST_EXTRA HERMES_BACKUP_TEST_MKGEN_RACE HERMES_RESTORE_TEST_CORRUPT_AFTER
export LC_ALL=C
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP="$HERE/backup-hermes.sh"; RESTORE="$HERE/restore-hermes.sh"
TMP="$(mktemp -d)"; TMP="$(cd -P "$TMP" && pwd)"
trap 'chmod -R u+w "$TMP" 2>/dev/null; rm -rf "$TMP"' EXIT
passed=0; failed=0; n=0
ok() { n=$((n + 1)); echo "ok $n - $1"; passed=$((passed + 1)); }
nok() { n=$((n + 1)); echo "not ok $n - $1"; failed=$((failed + 1)); }
eq() { if [ "$2" = "$3" ]; then ok "$1"; else nok "$1 (got '$2', want '$3')"; fi; }
has() { case "$2" in *"$3"*) ok "$1" ;; *) nok "$1 (no '$3' in output)" ;; esac; }
export HERMES_BACKUP_FORBID_PREFIX="$TMP/FakeLive"; mkdir -p "$TMP/FakeLive"
mk() { mkdir -p "$1/memories" "$1/skills/a" "$1/pending"; echo m >"$1/memories/M.md"; echo s >"$1/skills/a/S.md"; echo p >"$1/pending/p.json"; }
bk() { local d="$1"; shift; OUT="$(bash "$BACKUP" --src "$SRC" --dest "$d" "$@" 2>&1)"; RC=$?; }
nogen() { [ ! -e "$1" ] || [ -z "$(find "$1" -mindepth 1 -maxdepth 1)" ]; }

# --- M1: symlinks in scope are refused (exit 5), nothing written ---
mkdir -p "$TMP/elsewhere"; echo x >"$TMP/elsewhere/f"
SRC="$TMP/m1a"; mk "$SRC"; rm -rf "$SRC/memories"; ln -s "$TMP/elsewhere" "$SRC/memories"
bk "$TMP/d-m1a"; eq "(M1) top-level symlinked piece -> 5" "$RC" "5"; has "(M1) message names the piece" "$OUT" "memories"
nogen "$TMP/d-m1a" && ok "(M1) no generation for symlinked piece" || nok "(M1) no generation for symlinked piece"
SRC="$TMP/m1b"; mk "$SRC"; ln -s "$TMP/elsewhere/f" "$SRC/skills/a/link.md"
bk "$TMP/d-m1b"; eq "(M1) symlink inside skills/ -> 5" "$RC" "5"; has "(M1) message names the inner link" "$OUT" "skills/a/link.md"
nogen "$TMP/d-m1b" && ok "(M1) no generation for inner symlink" || nok "(M1) no generation for inner symlink"
SRC="$TMP/m1c"; mk "$SRC"; echo db >"$TMP/elsewhere/db"; ln -s "$TMP/elsewhere/db" "$SRC/state.db"
bk "$TMP/d-m1c"; eq "(M1) symlinked state.db -> 5" "$RC" "5"
nogen "$TMP/d-m1c" && ok "(M1) no generation for symlinked state.db" || nok "(M1) no generation for symlinked state.db"

# --- M2: no regular files in scope -> exit 2 before copying; retention does not run ---
SRC="$TMP/m2"; mkdir -p "$SRC/memories" "$SRC/skills/e"
D="$TMP/d-m2"; mkdir -p "$D/gen-20200101T000000Z" "$D/gen-20200102T000000Z"
bk "$D" --keep 1; eq "(M2) empty tree -> 2" "$RC" "2"; has "(M2) clear message" "$OUT" "no files in scope: nothing to back up"
eq "(M2) retention did not run; old generations intact" "$(find "$D" -mindepth 1 -maxdepth 1 | wc -l | tr -d ' ')" "2"
bk "$TMP/d-m2b"; [ ! -e "$TMP/d-m2b" ] && ok "(M2) nothing written for empty source" || nok "(M2) nothing written for empty source"

# --- M3: manifest from the source; change between manifest and copy -> exit 4 ---
SRC="$TMP/m3"; mk "$SRC"
HERMES_BACKUP_TEST_MUTATE_SRC=memories/M.md bk "$TMP/d-m3"; eq "(M3) source changed after manifest -> 4" "$RC" "4"
has "(M3) failed closed, nothing published" "$OUT" "nothing published"
nogen "$TMP/d-m3" && ok "(M3) no generation, no .tmp-*" || nok "(M3) no generation, no .tmp-*"
SRC="$TMP/m3b"; mk "$SRC"
HERMES_BACKUP_TEST_MUTATE_SRC=memories/M.md bk "$TMP/d-m3b" --allow-live; eq "(M3) --allow-live skips only the source re-hash, copy mismatch still -> 4" "$RC" "4"
SRC="$TMP/m3c"; mk "$SRC"; bk "$TMP/d-m3c" --allow-live; eq "(M3) --allow-live quiet source -> 0" "$RC" "0"
has "(M3) MANIFEST says LIVE COPY" "$(cat "$TMP"/d-m3c/gen-*/MANIFEST.txt)" "LIVE COPY: source not re-hashed"
bk "$TMP/d-m3d"; has "(M3) normal MANIFEST says source re-hashed" "$(cat "$TMP"/d-m3d/gen-*/MANIFEST.txt)" "source re-hashed after the copy: unchanged"
eq "(M3) SHA256SUMS equals the source hashes" "$(cat "$TMP"/d-m3d/gen-*/SHA256SUMS)" "$(cd "$SRC" && find memories skills pending -type f | sort | while IFS= read -r f; do shasum -a 256 "$f"; done)"

# --- A1: generation and staging dirs are mode 700 ---
G="$(find "$TMP/d-m3d" -mindepth 1 -maxdepth 1 -name 'gen-*')"
eq "(A1) gen dir mode 700" "$(stat -f %Lp "$G")" "700"
eq "(A1) SHA256SUMS not world/group readable" "$(stat -f %Lp "$G/SHA256SUMS")" "600"
eq "(A1) new dest dir mode 700" "$(stat -f %Lp "$TMP/d-m3d")" "700"

# --- M4: forbid-prefix refusal is case-insensitive (reviewer-reproduced bypass: dest spelled with other case) ---
SRC="$TMP/m4"; mk "$SRC"; mkdir -p "$TMP/FakeLive"
bk "$TMP/fakelive/sub"; eq "(M4) backup dest in other case of forbid prefix -> 5" "$RC" "5"
[ -z "$(ls -A "$TMP/FakeLive")" ] && ok "(M4) nothing written under the forbid prefix" || nok "(M4) nothing written under the forbid prefix"
bk "$TMP/m4/inner"; eq "(M4) dest inside src (same case) still -> 5" "$RC" "5"
bk "$TMP/M4/Inner2"; eq "(M4) dest inside src (other case) -> 5" "$RC" "5"
bk "$TMP/d-m4"; G4="$(find "$TMP/d-m4" -mindepth 1 -maxdepth 1 -name 'gen-*')"
OUT="$(bash "$RESTORE" --gen "$G4" --target "$TMP/fakelive/r" 2>&1)"; eq "(M4) restore target in other case of forbid prefix -> 5" "$?" "5"
bk "$TMP/d-m4ok"; eq "(M4) unrelated dest still works" "$RC" "0"

# --- M5: restore target paths (top-level system links resolved; deeper symlinks refused) ---
SRC="$TMP/m5"; mk "$SRC"; bk "$TMP/d-m5"; G5="$(find "$TMP/d-m5" -mindepth 1 -maxdepth 1 -name 'gen-*')"
rs() { OUT="$(bash "$RESTORE" --gen "$G5" "$@" 2>&1)"; RC=$?; }
case "$TMP" in
  /private/var/*|/private/tmp/*) VIA="${TMP#/private}/m5-via"
    if [ -L "/${VIA#/}" ] || [ -L "/$(printf '%s' "${VIA#/}" | cut -d/ -f1)" ]; then
      rs --target "$VIA"; eq "(M5) target reached through top-level /var|/tmp link -> 0" "$RC" "0"
      [ -f "$TMP/m5-via/memories/M.md" ] && ok "(M5) files landed at the canonical path" || nok "(M5) files landed at the canonical path"
    else echo "ok - (M5) SKIP no top-level system link on this host"; fi ;;
  *) echo "ok - (M5) SKIP scratch is not under /private" ;;
esac
mkdir -p "$TMP/m5real"; ln -s "$TMP/m5real" "$TMP/m5lnk"
rs --target "$TMP/m5lnk"; eq "(M5) target that is itself a symlink -> 5" "$RC" "5"
rs --target "$TMP/m5lnk/new"; eq "(M5) symlink below the top level -> 5" "$RC" "5"
[ -z "$(ls -A "$TMP/m5real")" ] && ok "(M5) nothing written through the link" || nok "(M5) nothing written through the link"

# --- A2: --force refuses stale sqlite sidecars the generation lacks; reports extra files ---
SRC="$TMP/a2"; mk "$SRC"; bk "$TMP/d-a2"; G5="$(find "$TMP/d-a2" -mindepth 1 -maxdepth 1 -name 'gen-*')"
T="$TMP/a2t"; mkdir -p "$T"; echo stale >"$T/state.db-wal"
rs --target "$T" --force; eq "(A2) stale state.db-wal with --force -> 5" "$RC" "5"
[ ! -e "$T/memories" ] && ok "(A2) nothing restored over a stale wal" || nok "(A2) nothing restored over a stale wal"
rm "$T/state.db-wal"; echo extra >"$T/extra.txt"
rs --target "$T" --force; eq "(A2) --force with only an extra file -> 0" "$RC" "0"
has "(A2) message reports extra files" "$OUT" "target had 1 extra files not in the generation"

# --- A3: plist comment has no double hyphen; xmllint ---
if command -v xmllint >/dev/null 2>&1; then
  xmllint --noout "$HERE/hermes-backup.plist.example" >/dev/null 2>&1 && ok "(A3) xmllint --noout passes" || nok "(A3) xmllint --noout passes"
else echo "ok - (A3) SKIP xmllint absent"; fi

echo "# passed=$passed failed=$failed"
[ "$failed" -eq 0 ]
