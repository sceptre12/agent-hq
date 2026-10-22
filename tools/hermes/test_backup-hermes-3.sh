#!/usr/bin/env bash
# tools/hermes/test_backup-hermes-3.sh — full-review (PR #40 @ a373d11f) fix tests for backup-hermes.sh (Hermes row 6):
# M1 ".." bypass, M2 source health, M3 post-copy source-change path, M4 mutation seams (backup side).
# SYNTHETIC trees only under a fresh mktemp -d (cd -P). No Hermes, no live home, no network. Never the real live path.
# Mutation runs: copy backup-hermes.sh + restore-hermes.sh + this file into one scratch dir, apply ONE change to the
# copy, run the copy of this file (it finds the scripts next to itself).
# shellcheck disable=SC2015,SC2030,SC2031  # test idiom: `[ cond ] && ok || nok`; OUT is set in helper/subshell on purpose
set -uo pipefail
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
hasnt() { case "$2" in *"$3"*) nok "$1 (unexpected '$3')" ;; *) ok "$1" ;; esac; }
unset HERMES_BACKUP_NOW HERMES_BACKUP_TEST_CORRUPT HERMES_BACKUP_TEST_MUTATE_SRC HERMES_BACKUP_TEST_MUTATE_SRC_AFTER \
  HERMES_BACKUP_TEST_EXTRA HERMES_BACKUP_TEST_MKGEN_RACE HERMES_RESTORE_TEST_CORRUPT_AFTER
export HERMES_BACKUP_FORBID_PREFIX="$TMP/fake-live"
mk() { mkdir -p "$1/memories" "$1/skills/a" "$1/pending"; echo m >"$1/memories/M.md"; echo s >"$1/skills/a/S.md"; echo p >"$1/pending/p.json"; }
bk() { local d="$1"; shift; OUT="$(bash "$BACKUP" --src "$SRC" --dest "$d" "$@" 2>&1)"; RC=$?; }
nogen() { [ ! -e "$1" ] || [ -z "$(find "$1" -mindepth 1 -maxdepth 1)" ]; }
gens() { find "$1" -mindepth 1 -maxdepth 1 -name 'gen-*' -exec basename {} \; | sort | tr '\n' ' '; }
mkdb() { python3 -c '
import sqlite3, sys
c = sqlite3.connect(sys.argv[1]); c.execute("create table t(k integer primary key, v text)")
c.executemany("insert into t(v) values (?)", [("row%d" % i * 20,) for i in range(1500)]); c.commit(); c.close()' "$1"; }

# --- M1: ".." after a not-yet-existing component bypassed both guards (reviewer-reproduced) ---
SRC="$TMP/src"; mk "$SRC"
bk "$TMP/newdir/../fake-live/bk"; eq "(M1) backup dest newdir/../fake-live/bk -> 5" "$RC" "5"; has "(M1) message names the .. component" "$OUT" ".. component"
[ ! -e "$TMP/fake-live" ] && [ ! -e "$TMP/newdir" ] && ok "(M1) nothing created under the forbidden prefix" || nok "(M1) nothing created under the forbidden prefix"
bk "$TMP/other/nope/../../src/bk"; eq "(M1) dest inside src via missing/../.. -> 5" "$RC" "5"
bk "$TMP/src/nonexistent/../x"; eq "(M1) dest src/nonexistent/../x -> 5" "$RC" "5"
[ -z "$(find "$SRC" -mindepth 1 -maxdepth 1 -name 'gen-*' -o -name 'bk' -o -name x)" ] && ok "(M1) nothing written inside src" || nok "(M1) nothing written inside src"
bk "$TMP/src/../d-existing"; eq "(M1) .. after an existing component also refused -> 5" "$RC" "5"
OUT="$(bash "$BACKUP" --src "$TMP/src/../src" --dest "$TMP/d-m1s" 2>&1)"; eq "(M1) --src with a .. component -> 5" "$?" "5"
mkdir -p "$TMP/cwd"; ( cd "$TMP/cwd" && OUT="$(bash "$BACKUP" --src "$SRC" --dest -dd 2>&1)"; echo "$?" >"$TMP/dash.rc"; echo "$OUT" >"$TMP/dash.out" )
eq "(M1) dest path starting with - works -> 0" "$(cat "$TMP/dash.rc")" "0"
[ -d "$TMP/cwd/-dd" ] && ok "(M1) generation landed in ./-dd" || nok "(M1) generation landed in ./-dd (out: $(cat "$TMP/dash.out"))"
bk "$TMP/d-m1ok"; eq "(M1) normal dest still works" "$RC" "0"
G1="$(find "$TMP/d-m1ok" -mindepth 1 -maxdepth 1 -name 'gen-*')"
OUT="$(bash "$RESTORE" --gen "$G1" --target "$TMP/nonex/../fake-live/rst" 2>&1)"; eq "(M1) restore target nonex/../fake-live/rst -> 5" "$?" "5"
[ ! -e "$TMP/fake-live" ] && ok "(M1) restore wrote nothing under the forbidden prefix" || nok "(M1) restore wrote nothing under the forbidden prefix"
OUT="$(bash "$RESTORE" --gen "$G1" --target "$TMP/nonex/../rst2" 2>&1)"; eq "(M1) restore target with .. -> 5" "$?" "5"
( cd "$TMP/cwd" && OUT="$(bash "$RESTORE" --gen "$G1" --target -rr 2>&1)"; echo "$?" >"$TMP/dash.rc" )
eq "(M1) restore target starting with - works -> 0" "$(cat "$TMP/dash.rc")" "0"

# --- M2: source health. A damaged state.db must not publish (hash check proves copy == source, not health) ---
SRC="$TMP/h1"; mk "$SRC"; mkdb "$SRC/state.db"
D="$TMP/d-h1"; HERMES_BACKUP_NOW=20260101T000001Z bk "$D"; HERMES_BACKUP_NOW=20260101T000002Z bk "$D"; eq "(H) healthy state.db -> 0" "$RC" "0"
eq "(H) healthy db published byte-identical" "$(shasum -a 256 <"$D/gen-20260101T000002Z/data/state.db")" "$(shasum -a 256 <"$SRC/state.db")"
BEFORE="$(gens "$D")"
dd if=/dev/zero of="$SRC/state.db" bs=4096 seek=2 count=1 conv=notrunc 2>/dev/null
IC="$(python3 -I -c 'import sqlite3,sys
try: print(sqlite3.connect(sys.argv[1]).execute("PRAGMA integrity_check").fetchone()[0])
except Exception as e: print("error")' "$SRC/state.db")"
[ "$IC" != ok ] && ok "(H) fixture: zeroed page makes integrity_check fail ($IC)" || nok "(H) fixture: zeroed page makes integrity_check fail"
HERMES_BACKUP_NOW=20260101T000003Z bk "$D" --keep 2; eq "(H) zeroed-page state.db -> 4" "$RC" "4"; has "(H) message" "$OUT" "state.db failed integrity_check"
eq "(H) no new generation, older generations intact" "$(gens "$D")" "$BEFORE"
[ -z "$(find "$D" -name '.tmp-*')" ] && ok "(H) no .tmp-* left" || nok "(H) no .tmp-* left"
HERMES_BACKUP_NOW=20260101T000004Z bk "$D" --keep 2 --allow-live; eq "(H) --allow-live does not skip the health check -> 4" "$RC" "4"
HERMES_BACKUP_NOW=20260101T000005Z bk "$D" --keep 2; HERMES_BACKUP_NOW=20260101T000006Z bk "$D" --keep 2
eq "(H) repeated damaged runs never rotate clean generations out" "$(gens "$D")" "$BEFORE"
# shrink guard: a new generation under 50% of the previous one is kept but retention is skipped (loud warning)
SRC="$TMP/big"; mk "$SRC"; for i in 1 2 3 4 5 6 7 8; do echo "$i" >"$SRC/memories/f$i.md"; done
D="$TMP/d-shr"; HERMES_BACKUP_NOW=20260102T000001Z bk "$D" --keep 1; eq "(S) big generation -> 0" "$RC" "0"
SRC="$TMP/small"; mk "$SRC"; rm "$SRC/pending/p.json" "$SRC/skills/a/S.md"
HERMES_BACKUP_NOW=20260102T000002Z bk "$D" --keep 1; eq "(S) shrunken source still publishes -> 0" "$RC" "0"; has "(S) loud warning" "$OUT" "retention SKIPPED"
eq "(S) shrink: nothing pruned" "$(gens "$D")" "gen-20260102T000001Z gen-20260102T000002Z "
HERMES_BACKUP_NOW=20260102T000003Z bk "$D" --keep 1; eq "(S) normal run -> 0" "$RC" "0"; hasnt "(S) no warning for a normal run" "$OUT" "SKIPPED"
eq "(S) normal case prunes down to --keep" "$(gens "$D")" "gen-20260102T000003Z "
# pools: --allow-live gens never evict clean ones; a decoy gen-* name takes no keep slot
SRC="$TMP/pool"; mk "$SRC"; D="$TMP/d-pool"
HERMES_BACKUP_NOW=20260103T000001Z bk "$D" --keep 2; HERMES_BACKUP_NOW=20260103T000002Z bk "$D" --keep 2
for i in 3 4 5; do HERMES_BACKUP_NOW=20260103T00000${i}Z bk "$D" --keep 1 --allow-live; done
eq "(L) clean gens kept, only 1 live gen kept" "$(gens "$D")" "gen-20260103T000001Z gen-20260103T000002Z gen-20260103T000005Z "
D="$TMP/d-decoy"; HERMES_BACKUP_NOW=20260104T000001Z bk "$D" --keep 2; mkdir "$D/gen-20991231T235959Z"
HERMES_BACKUP_NOW=20260104T000002Z bk "$D" --keep 2
eq "(L) decoy gen-* dir takes no keep slot; real gens kept" "$(gens "$D")" "gen-20260104T000001Z gen-20260104T000002Z gen-20991231T235959Z "

# --- M3: the post-copy "source changed during backup" path (hook fires AFTER the staged verify) ---
SRC="$TMP/m3"; mk "$SRC"; D="$TMP/d-m3"; HERMES_BACKUP_NOW=20260105T000001Z bk "$D"
HERMES_BACKUP_NOW=20260105T000002Z HERMES_BACKUP_TEST_MUTATE_SRC_AFTER=memories/M.md bk "$D"
eq "(M3) source changed after the staged verify -> exactly 4" "$RC" "4"; has "(M3) distinct message" "$OUT" "source changed during backup; nothing published"
eq "(M3) no new generation, prior kept" "$(gens "$D")" "gen-20260105T000001Z "
[ -z "$(find "$D" -name '.tmp-*')" ] && ok "(M3) no .tmp-* left" || nok "(M3) no .tmp-* left"
SRC="$TMP/m3l"; mk "$SRC"; D="$TMP/d-m3l"
HERMES_BACKUP_TEST_MUTATE_SRC_AFTER=memories/M.md bk "$D" --allow-live; eq "(M3) --allow-live variant -> 0" "$RC" "0"
has "(M3) MANIFEST says LIVE COPY" "$(cat "$D"/gen-*/MANIFEST.txt)" "LIVE COPY"

# --- M4 seams (backup side): each guard is reached by its own test ---
SRC="$TMP/m4"; mk "$SRC"
HERMES_BACKUP_TEST_CORRUPT=1 bk "$TMP/d-m4a" --allow-live; eq "(M4) --allow-live does NOT skip the staged verify -> 4" "$RC" "4"
HERMES_BACKUP_TEST_EXTRA=1 bk "$TMP/d-m4b"; eq "(M4) extra file in the staged copy (count check) -> 4" "$RC" "4"; has "(M4) message" "$OUT" "verification of the staged copy failed"
nogen "$TMP/d-m4b" && ok "(M4) no generation for the count mismatch" || nok "(M4) no generation for the count mismatch"
D="$TMP/d-col"; HERMES_BACKUP_NOW=20260106T000001Z bk "$D"; HERMES_BACKUP_NOW=20260106T000001Z bk "$D"
eq "(M4) same-second collision -> 5" "$RC" "5"; has "(M4) pre-check message" "$OUT" "already exists (same-second collision)"
eq "(M4) first generation intact" "$(gens "$D")" "gen-20260106T000001Z "
mkdir "$D/gen-20260106T000009Z"; HERMES_BACKUP_NOW=20260106T000009Z bk "$D"; eq "(M4) existing generation dir -> 5" "$RC" "5"; has "(M4) message" "$OUT" "already exists"
ln -s "$TMP/m4" "$D/gen-20260106T000008Z"; HERMES_BACKUP_NOW=20260106T000008Z bk "$D"; eq "(M4) existing symlink named like a generation -> 5" "$RC" "5"
HERMES_BACKUP_NOW=20260106T000007Z HERMES_BACKUP_TEST_MKGEN_RACE=1 bk "$D"; eq "(M4) generation appears just before publish -> 5" "$RC" "5"; has "(M4) race message" "$OUT" "appeared meanwhile"
[ -z "$(find "$D" -name '.tmp-*')" ] && ok "(M4) no .tmp-* after the race" || nok "(M4) no .tmp-* after the race"
# unreadable file: hard failure (exit 1), nothing published (set -e / pipefail)
SRC="$TMP/unr"; mk "$SRC"; echo "a" >"$SRC/memories/A.md"; chmod 000 "$SRC/memories/A.md"
bk "$TMP/d-unr"; eq "(M4) unreadable source file -> 1" "$RC" "1"; nogen "$TMP/d-unr" && ok "(M4) no generation for an unreadable file" || nok "(M4) no generation for an unreadable file"
chmod 600 "$SRC/memories/A.md"
# lsof absent: state.db present -> 3; --allow-live -> 0 with a LIVE COPY note
FB="$TMP/nolsof"; mkdir -p "$FB"
for t in basename dirname python3 tr mkdir find sort shasum perl wc cut head dd cp chmod mv rm date mktemp grep sed cat touch ls; do
  p="$(command -v "$t" 2>/dev/null)" && ln -sf "$p" "$FB/$t"; done
[ ! -x /usr/bin/python3 ] || ln -sf /usr/bin/python3 "$FB/python3"   # a version-manager shim needs its own PATH
SRC="$TMP/nl"; mk "$SRC"; mkdb "$SRC/state.db"
OUT="$(PATH="$FB" /bin/bash "$BACKUP" --src "$SRC" --dest "$TMP/d-nl" 2>&1)"; RC=$?
eq "(M4) lsof absent with state.db -> 3" "$RC" "3"; has "(M4) message" "$OUT" "lsof is absent"; nogen "$TMP/d-nl" && ok "(M4) nothing written when lsof is absent" || nok "(M4) nothing written when lsof is absent"
OUT="$(PATH="$FB" /bin/bash "$BACKUP" --src "$SRC" --dest "$TMP/d-nl2" --allow-live 2>&1)"; RC=$?
eq "(M4) lsof absent + --allow-live -> 0" "$RC" "0"; has "(M4) MANIFEST notes lsof absent" "$(cat "$TMP"/d-nl2/gen-*/MANIFEST.txt)" "lsof absent"

echo "# passed=$passed failed=$failed"
[ "$failed" -eq 0 ]
