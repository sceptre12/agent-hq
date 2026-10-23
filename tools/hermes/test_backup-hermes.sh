#!/usr/bin/env bash
# tools/hermes/test_backup-hermes.sh — hermetic tests for backup-hermes.sh + restore-hermes.sh (Hermes row 6,
# architecture/hermes-agent-memory.md section 9). Everything runs on a SYNTHETIC tree under a fresh mktemp -d
# (realpath'd with cd -P). No Hermes, no live Hermes home, no network.
#
# Ledger/blob shape (MEASURED by reading the Hermes source at commit 908e4a4, tools/skill_ledger.py lines 6, 85,
# 89, 159-172, 310-313): a JSONL line per mutation {id, ts, actor, action, skill, evidence, before:[{path,sha256}],
# after:[{path,sha256}]}; blobs live content-addressed at HERMES_HOME/.curator_backups/blobs/<sha256>.
# UNVERIFIED: the command `hermes curator rollback <entry-id>` itself (no Hermes may be run here; the launcher
# admits only chat/-h/gateway). Test (j) proves only that a restored generation still holds a blob whose sha256
# equals the ledger entry's before-hash and that the blob reproduces the pre-mutation skill file.
# WAL choice: state.db is a real sqlite db in WAL mode; its -wal/-shm are REAL (a writer process holds the db open
# with autocheckpoint off, the three files are then used as they stand, the writer is killed with SIGKILL).
set -uo pipefail
unset HERMES_BACKUP_NOW HERMES_BACKUP_TEST_CORRUPT HERMES_BACKUP_TEST_MUTATE_SRC HERMES_BACKUP_TEST_MUTATE_SRC_AFTER \
  HERMES_BACKUP_TEST_EXTRA HERMES_BACKUP_TEST_MKGEN_RACE HERMES_RESTORE_TEST_CORRUPT_AFTER
export LC_ALL=C
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP="$HERE/backup-hermes.sh"; RESTORE="$HERE/restore-hermes.sh"
TMP="$(mktemp -d)"; TMP="$(cd -P "$TMP" && pwd)"
HOLDERS=""
cleanup() {
  for p in $HOLDERS; do kill -9 "$p" 2>/dev/null || true; done
  chmod -R u+w "$TMP" 2>/dev/null; rm -rf "$TMP"
}
trap cleanup EXIT
passed=0; failed=0; n=0
ok() { n=$((n + 1)); echo "ok $n - $1"; passed=$((passed + 1)); }
nok() { n=$((n + 1)); echo "not ok $n - $1"; failed=$((failed + 1)); }
eq() { if [ "$2" = "$3" ]; then ok "$1"; else nok "$1 (got '$2', want '$3')"; fi; }
has() { case "$2" in *"$3"*) ok "$1" ;; *) nok "$1 (no '$3' in output)" ;; esac; }
lsd() { find "$1" -mindepth 1 -maxdepth 1 -exec basename {} \; | sort; }   # ls without ls|grep
sha() { shasum -a 256 "$1" | cut -d' ' -f1; }
# tree_hash <dir>: one hash over every file's relative path + content (read-only proof).
tree_hash() { (cd "$1" && find . -type f -print | LC_ALL=C sort | while IFS= read -r f; do
  printf '%s  %s\n' "$(shasum -a 256 <"$f" | cut -d' ' -f1)" "$f"; done | shasum -a 256 | cut -d' ' -f1); }

# Real WAL state: a python writer keeps the db open (autocheckpoint off) until killed.
# hold_db <db> <ready-file>: starts the holder in the background; its pid is appended to HOLDERS and HOLD_PID.
hold_db() {
  python3 -c '
import sqlite3, sys, time
c = sqlite3.connect(sys.argv[1], isolation_level=None)
c.execute("PRAGMA journal_mode=WAL"); c.execute("PRAGMA wal_autocheckpoint=0")
c.execute("CREATE TABLE IF NOT EXISTS t(k INTEGER PRIMARY KEY, v TEXT)")
c.execute("INSERT INTO t(v) VALUES (?)", ("hot-row",))
open(sys.argv[2], "w").write("ready")
time.sleep(600)
' "$1" "$2" &
  HOLD_PID=$!; HOLDERS="$HOLDERS $HOLD_PID"
  local i=0; while [ ! -f "$2" ] && [ "$i" -lt 100 ]; do sleep 0.1; i=$((i + 1)); done
  [ -f "$2" ]
}
release_db() { kill -9 "$1" 2>/dev/null || true; wait "$1" 2>/dev/null || true; }

# mk_tree <root>: build the SYNTHETIC Hermes home (all pieces, dotfiles, nested files, real WAL, blobs, ledger).
mk_tree() {
  local r="$1" a b ha hb
  mkdir -p "$r/memories" "$r/skills/alpha/refs" "$r/skills/beta" "$r/skills/gamma" "$r/skills/.archive/old-skill" \
    "$r/.curator_backups/blobs" "$r/pending"
  printf 'user memory one\n' >"$r/memories/USER.md"; printf 'agent note\n' >"$r/memories/MEMORY.md"
  printf 'dot memory\n' >"$r/memories/.hidden-note"
  a='alpha version one'; b='alpha version two'
  printf '%s\n' "$a" >"$r/.blob-a"; printf '%s\n' "$b" >"$r/.blob-b"
  ha="$(sha "$r/.blob-a")"; hb="$(sha "$r/.blob-b")"
  cp "$r/.blob-a" "$r/.curator_backups/blobs/$ha"; cp "$r/.blob-b" "$r/.curator_backups/blobs/$hb"; rm "$r/.blob-a" "$r/.blob-b"
  printf '%s\n' "$b" >"$r/skills/alpha/SKILL.md"; printf 'nested ref\n' >"$r/skills/alpha/refs/ref.md"
  printf 'beta skill\n' >"$r/skills/beta/SKILL.md"; printf 'gamma skill\n' >"$r/skills/gamma/SKILL.md"
  printf 'archived skill\n' >"$r/skills/.archive/old-skill/SKILL.md"
  printf '{"id":"e0000000001a","ts":"2026-10-01T00:00:00+00:00","actor":"agent","action":"create","skill":"alpha","evidence":{},"before":[],"after":[{"path":"%s/skills/alpha/SKILL.md","sha256":"%s"}]}\n' "$r" "$ha" >"$r/skills/.curator_ledger.jsonl"
  printf '{"id":"e0000000002b","ts":"2026-10-02T00:00:00+00:00","actor":"agent","action":"patch","skill":"alpha","evidence":{},"before":[{"path":"%s/skills/alpha/SKILL.md","sha256":"%s"}],"after":[{"path":"%s/skills/alpha/SKILL.md","sha256":"%s"}]}\n' "$r" "$ha" "$r" "$hb" >>"$r/skills/.curator_ledger.jsonl"
  printf 'pending item\n' >"$r/pending/item-1.json"
  hold_db "$r/state.db" "$r/.ready" || return 1
  [ -f "$r/state.db-wal" ] && [ -f "$r/state.db-shm" ] || return 1
  release_db "$HOLD_PID"; rm -f "$r/.ready"
  LEDGER_BEFORE="$ha"; LEDGER_AFTER="$hb"
}

SRC="$TMP/src"; mkdir -p "$SRC"
if mk_tree "$SRC"; then ok "synthetic tree built (real state.db + -wal + -shm, 2 ledger entries, 2 blobs)"; else nok "synthetic tree build"; fi
eq "ledger has 2 JSON lines" "$(wc -l <"$SRC/skills/.curator_ledger.jsonl" | tr -d ' ')" "2"
eq "blob names equal their content sha256" "$(for f in "$SRC"/.curator_backups/blobs/*; do [ "$(basename "$f")" = "$(sha "$f")" ] && echo y; done | wc -l | tr -d ' ')" "2"
FP="$TMP/fake-live"   # TESTS-ONLY forbid prefix so tests never touch the real live path
export HERMES_BACKUP_FORBID_PREFIX="$FP"
run_backup() { # run_backup <dest> [args...]; sets OUT, RC (stdout+stderr merged)
  local d="$1"; shift
  OUT="$(bash "$BACKUP" --src "$SRC" --dest "$d" "$@" 2>&1)"; RC=$?
}

# --- (a) SHA256SUMS hashes equal the source files' hashes ---
D1="$TMP/dest1"; before="$(tree_hash "$SRC")"
HERMES_BACKUP_NOW=20261001T010101Z run_backup "$D1"
eq "(a0) backup exits 0" "$RC" "0"
G1="$D1/gen-20261001T010101Z"; bad=0; cnt=0
while IFS= read -r line; do
  h="${line%% *}"; f="${line#*  }"; cnt=$((cnt + 1))
  [ "$h" = "$(sha "$SRC/$f")" ] || bad=$((bad + 1))
done <"$G1/SHA256SUMS"
eq "(a) every SHA256SUMS hash equals the source file hash (none bad)" "$bad" "0"
eq "(a) SHA256SUMS covers every source file" "$cnt" "$(cd "$SRC" && find . -type f | wc -l | tr -d ' ')"
eq "(a) SHA256SUMS is sorted" "$(cut -c 67- "$G1/SHA256SUMS")" "$(cut -c 67- "$G1/SHA256SUMS" | sort)"

# --- (b) scope pieces, dotfiles, sqlite trio ---
for p in memories/USER.md memories/.hidden-note skills/alpha/refs/ref.md skills/.archive/old-skill/SKILL.md \
  skills/.curator_ledger.jsonl state.db state.db-wal state.db-shm pending/item-1.json; do
  [ -f "$G1/data/$p" ] && ok "(b) present: $p" || nok "(b) present: $p"
done
eq "(b) blobs copied" "$(ls "$G1/data/.curator_backups/blobs" | wc -l | tr -d ' ')" "2"
eq "(b) -wal copied bit-for-bit" "$(sha "$G1/data/state.db-wal")" "$(sha "$SRC/state.db-wal")"
has "(b) MANIFEST lists src and stamp" "$(cat "$G1/MANIFEST.txt")" "stamp: 20261001T010101Z"
has "(b) MANIFEST records src realpath" "$(cat "$G1/MANIFEST.txt")" "src: $SRC"

# --- (c) source tree identical before/after (read-only proof) ---
eq "(c) source tree hash unchanged by backup" "$(tree_hash "$SRC")" "$before"

# --- (d) injected corruption -> exit 4, no gen-* and no .tmp-* ---
D2="$TMP/dest2"; HERMES_BACKUP_NOW=20261001T020202Z HERMES_BACKUP_TEST_CORRUPT=1 run_backup "$D2"
eq "(d) corrupted staged copy exits 4" "$RC" "4"
eq "(d) nothing left under dest" "$(ls -A "$D2" | wc -l | tr -d ' ')" "0"
eq "(c) source still unchanged after failed run" "$(tree_hash "$SRC")" "$before"

# --- (e) retention ---
D3="$TMP/dest3"; mkdir -p "$D3/other-dir" "$D3/gen-bad" "$D3/gen-20260101T000000Zx"; echo x >"$D3/file.txt"
mkdir -p "$TMP/linktarget"; ln -s "$TMP/linktarget" "$D3/gen-20200101T000000Z"
for s in 20261002T000001Z 20261002T000002Z 20261002T000003Z 20261002T000004Z 20261002T000005Z; do
  HERMES_BACKUP_NOW=$s run_backup "$D3" --keep 3
  [ "$RC" = 0 ] || nok "(e) backup $s rc=$RC"
done
eq "(e) exactly the 3 newest generations remain" "$(lsd "$D3" | grep -E '^gen-[0-9]{8}T[0-9]{6}Z$' | grep -v '^gen-20200101' | tr '\n' ' ')" \
  "gen-20261002T000003Z gen-20261002T000004Z gen-20261002T000005Z "
eq "(e) non-matching dirs/files untouched" "$(lsd "$D3" | grep -v -E '^gen-2026100' | tr '\n' ' ')" \
  "file.txt gen-20200101T000000Z gen-20260101T000000Zx gen-bad other-dir "
[ -L "$D3/gen-20200101T000000Z" ] && [ -d "$TMP/linktarget" ] && ok "(e) gen-named symlink untouched" || nok "(e) gen-named symlink untouched"
for k in 0 x -1 ""; do
  run_backup "$TMP/dest-keep" --keep "$k"; eq "(e) --keep '$k' refused with exit 2" "$RC" "2"
done
[ ! -e "$TMP/dest-keep" ] && ok "(e) refused --keep wrote nothing" || nok "(e) refused --keep wrote nothing"

# --- (f) refusals ---
run_backup "$SRC/inside"; eq "(f) dest inside src -> 5" "$RC" "5"
[ ! -e "$SRC/inside" ] && ok "(f) dest inside src not created" || nok "(f) dest inside src not created"
OUT="$(bash "$BACKUP" --src "$TMP/dest1" --dest "$TMP" 2>&1)"; RC=$?; eq "(f) src inside dest -> 5" "$RC" "5"
mkdir -p "$FP"; run_backup "$FP/sub"; eq "(f) dest under forbid prefix -> 5" "$RC" "5"
ln -s "$FP" "$TMP/sneaky"; run_backup "$TMP/sneaky/new"; eq "(f) dest via symlink into forbid prefix -> 5" "$RC" "5"
[ -z "$(ls -A "$FP")" ] && ok "(f) forbid prefix untouched" || nok "(f) forbid prefix untouched"
ln -s "$SRC" "$TMP/srclink"; run_backup "$TMP/srclink/x"; eq "(f) dest via symlink into src -> 5" "$RC" "5"
HERMES_BACKUP_NOW=20261002T000005Z run_backup "$D3"; eq "(f) same-second collision -> 5" "$RC" "5"
run_backup "$TMP/d-nosrc" --src; eq "(f) missing option value -> 2" "$RC" "2"
OUT="$(bash "$BACKUP" --dest "$TMP/x" 2>&1)"; eq "(f) missing --src -> 2" "$?" "2"
mkdir "$TMP/emptysrc"; OUT="$(bash "$BACKUP" --src "$TMP/emptysrc" --dest "$TMP/x" 2>&1)"; eq "(f) no memories/ nor skills/ -> 2" "$?" "2"

# --- (g) quiesce ---
D4="$TMP/dest4"; hold_db "$SRC/state.db" "$TMP/.hold-ready" && ok "(g) holder process started" || nok "(g) holder started"
HOLDER="$HOLD_PID"
HERMES_BACKUP_NOW=20261003T000001Z run_backup "$D4"
eq "(g) open state.db -> exit 3" "$RC" "3"
[ ! -e "$D4" ] && ok "(g) nothing written when not quiesced" || nok "(g) nothing written when not quiesced"
HERMES_BACKUP_NOW=20261003T000002Z run_backup "$D4" --allow-live
eq "(g) --allow-live proceeds" "$RC" "0"
has "(g) MANIFEST carries LIVE COPY" "$(cat "$D4/gen-20261003T000002Z/MANIFEST.txt")" "LIVE COPY: not guaranteed consistent"
release_db "$HOLDER"

# --- (h) restore ---
D5="$TMP/dest5"; HERMES_BACKUP_NOW=20261004T000001Z run_backup "$D5"; eq "(h0) fresh backup for restore" "$RC" "0"
G5="$D5/gen-20261004T000001Z"; T1="$TMP/restore1"
OUT="$(bash "$RESTORE" --gen "$G5" --target "$T1" 2>&1)"; RC=$?
eq "(h) restore exits 0" "$RC" "0"
has "(h) restore prints the summary" "$OUT" "restored $(cd "$SRC" && find . -type f | wc -l | tr -d ' ') files, hashes OK"
bad=0; while IFS= read -r f; do [ "$(sha "$SRC/$f")" = "$(sha "$T1/$f")" ] || bad=$((bad + 1)); done \
  < <(cd "$SRC" && find . -type f | sed 's|^\./||')
eq "(h) every restored file's sha256 equals the source's" "$bad" "0"
OUT="$(bash "$RESTORE" --gen "$G5" --target "$T1" 2>&1)"; eq "(h) non-empty target without --force -> 5" "$?" "5"
OUT="$(bash "$RESTORE" --gen "$G5" --target "$T1" --force 2>&1)"; eq "(h) non-empty target with --force -> 0" "$?" "0"
mkdir -p "$TMP/bad-gen"; cp -Rp "$G5/." "$TMP/bad-gen/"
printf 'X' | dd of="$TMP/bad-gen/data/memories/USER.md" bs=1 count=1 conv=notrunc 2>/dev/null
OUT="$(bash "$RESTORE" --gen "$TMP/bad-gen" --target "$TMP/restore-bad" 2>&1)"; eq "(h) corrupted generation refused -> 4" "$?" "4"
[ ! -e "$TMP/restore-bad" ] && ok "(h) corrupted generation wrote nothing" || nok "(h) corrupted generation wrote nothing"
OUT="$(bash "$RESTORE" --gen "$G5" --target "$FP/r" 2>&1)"; eq "(h) target under forbid prefix -> 5" "$?" "5"
OUT="$(bash "$RESTORE" --gen "$G5" --target "$TMP/sneaky/r" 2>&1)"; eq "(h) target via symlink -> 5" "$?" "5"
OUT="$(bash "$RESTORE" --gen "$G5" 2>&1)"; eq "(h) missing --target -> 2" "$?" "2"

# --- (j) rollback-by-hash: the restored generation can reproduce the pre-mutation skill from the blob ---
# (the real `hermes curator rollback <entry-id>` is UNVERIFIED: not runnable here; this proves the hash chain.)
D6="$TMP/dest6"; HERMES_BACKUP_NOW=20261005T000001Z run_backup "$D6"; eq "(j0) backup before damage" "$RC" "0"
BEFORE_HASH="$(python3 -c 'import json,sys
for l in open(sys.argv[1]):
    e = json.loads(l)
    if e["id"] == "e0000000002b": print(e["before"][0]["sha256"])' "$SRC/skills/.curator_ledger.jsonl")"
eq "(j) ledger entry before-hash read" "$BEFORE_HASH" "$LEDGER_BEFORE"
printf 'DAMAGED\n' >"$SRC/skills/alpha/SKILL.md"; rm -f "$SRC/.curator_backups/blobs/$BEFORE_HASH"
[ ! -e "$SRC/.curator_backups/blobs/$BEFORE_HASH" ] && ok "(j) live blob deleted, live skill damaged (premise)" || nok "(j) premise"
T2="$TMP/restore-j"; OUT="$(bash "$RESTORE" --gen "$D6/gen-20261005T000001Z" --target "$T2" 2>&1)"; eq "(j) restore exits 0" "$?" "0"
RB="$T2/.curator_backups/blobs/$BEFORE_HASH"
[ -f "$RB" ] && ok "(j) restored generation holds the before-blob" || nok "(j) restored generation holds the before-blob"
eq "(j) sha256(restored blob) == ledger before-hash" "$(sha "$RB")" "$BEFORE_HASH"
cp "$RB" "$TMP/rolled-back-SKILL.md"
eq "(j) skill reproduced from the blob is the pre-mutation content" "$(cat "$TMP/rolled-back-SKILL.md")" "alpha version one"
eq "(j) restored skill is the post-mutation (after) version" "$(sha "$T2/skills/alpha/SKILL.md")" "$LEDGER_AFTER"

# --- (i) LaunchAgent plist draft ---
PL="$HERE/hermes-backup.plist.example"; ME="$(id -un)"
if command -v plutil >/dev/null 2>&1; then
  plutil -lint "$PL" >/dev/null 2>&1 && ok "(i) plutil -lint passes" || nok "(i) plutil -lint passes"
else echo "ok - (i) SKIP plutil absent"; fi
PLT="$(cat "$PL")"
has "(i) Label" "$PLT" "<string>com.hq.hermes-backup</string>"
has "(i) placeholders" "$PLT" "__BACKUP_ROOT__"
case "$PLT" in *"<key>RunAtLoad</key>"*"<false/>"*) ok "(i) RunAtLoad false" ;; *) nok "(i) RunAtLoad false" ;; esac
case "$PLT" in *"/Users/"*) nok "(i) no hard-coded /Users path" ;; *) ok "(i) no hard-coded /Users path" ;; esac
if [ "${#ME}" -ge 3 ]; then case "$PLT" in *"$ME"*) nok "(i) no login name" ;; *) ok "(i) no login name" ;; esac; fi

echo "# passed=$passed failed=$failed"
[ "$failed" -eq 0 ]
