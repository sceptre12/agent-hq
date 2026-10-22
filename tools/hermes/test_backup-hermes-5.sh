#!/usr/bin/env bash
# tools/hermes/test_backup-hermes-5.sh — DELTA-review (PR #40 @ 43b40078) fix tests (Hermes row 6): fail closed when the
# passwd home cannot be read, passwd-home entry in restore, tampered/forged generations, symlinked live entries, rp()
# without basename/dirname, and the mutation seams found by the delta review.
# SYNTHETIC trees only under a fresh mktemp -d (cd -P). No Hermes, no live home, no network. The "live path" in these
# tests is a SCRATCH string: the guard must die before it looks at dest/target at all.
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
rs() { OUT="$(bash "$RESTORE" --gen "$GEN" "$@" 2>&1)"; RC=$?; }
nogen() { [ ! -e "$1" ] || [ -z "$(find "$1" -mindepth 1 -maxdepth 1)" ]; }
gens() { find "$1" -mindepth 1 -maxdepth 1 -name 'gen-*' -exec basename {} \; | sort | tr '\n' ' '; }
firstgen() { find "$1" -mindepth 1 -maxdepth 1 -name 'gen-*' | sort | head -n 1; }
# tooldir <dir> <tool...>: a PATH made only of symlinks to the named tools (so a tool can be left out on purpose)
tooldir() { local d="$1" t p; shift; mkdir -p "$d"; for t in "$@"; do p="$(command -v "$t" 2>/dev/null)" && ln -sf "$p" "$d/$t"; done; return 0; }
TOOLS=(basename dirname tr mkdir find sort shasum perl wc cut head dd cp chmod mv rm date mktemp grep sed cat touch ls id sleep)

SRC="$TMP/src"; mk "$SRC"
bk "$TMP/d-base"; GEN="$(firstgen "$TMP/d-base")"; eq "(base) normal backup -> 0" "$RC" "0"
mkdir -p "$TMP/h"

# --- MEDIUM: python3 absent -> the passwd home cannot be read -> fail closed (exit 5) BEFORE touching anything ---
tooldir "$TMP/nopy" "${TOOLS[@]}"
PWS="$TMP/pwlive/claude-profiles/hermes"   # a scratch STRING standing for the live path
OUT="$(HOME="$TMP/h" PATH="$TMP/nopy" /bin/bash "$BACKUP" --src "$SRC" --dest "$PWS/bk" 2>&1)"; RC=$?
eq "(PY) backup without python3, dest under the live path string -> 5" "$RC" "5"; has "(PY) backup message" "$OUT" "cannot read the passwd home"
OUT="$(HOME="$TMP/h" PATH="$TMP/nopy" /bin/bash "$BACKUP" --src "$SRC" --dest "$TMP/d-nopy" 2>&1)"; RC=$?
eq "(PY) backup without python3, ANY dest -> 5 (fails closed)" "$RC" "5"; nogen "$TMP/d-nopy" && ok "(PY) nothing written without python3" || nok "(PY) nothing written without python3"
OUT="$(HOME="$TMP/h" PATH="$TMP/nopy" /bin/bash "$RESTORE" --gen "$GEN" --target "$PWS/rs" 2>&1)"; RC=$?
eq "(PY) restore without python3, target under the live path string -> 5" "$RC" "5"; has "(PY) restore message" "$OUT" "cannot read the passwd home"
[ ! -e "$TMP/pwlive" ] && ok "(PY) nothing created at the live path string" || nok "(PY) nothing created at the live path string"
[ ! -e "$TMP/d-nopy" ] && ok "(PY) nothing created for the plain dest" || nok "(PY) nothing created for the plain dest"

# --- SHIM python3 printing a fake passwd home: both guards use it (kills "passwd entry dropped in restore only") ---
mkdir -p "$TMP/shim"; printf '#!/bin/sh\necho "%s"\n' "$TMP/fakepw" >"$TMP/shim/python3"; chmod 755 "$TMP/shim/python3"
OUT="$(HOME="$TMP/h" PATH="$TMP/shim:$TMP/nopy" /bin/bash "$RESTORE" --gen "$GEN" --target "$TMP/fakepw/claude-profiles/hermes/rs" 2>&1)"; RC=$?
eq "(SH) restore target under the passwd-derived live path (shim) -> 5" "$RC" "5"; has "(SH) message" "$OUT" "forbidden live-home prefix"
OUT="$(HOME="$TMP/h" PATH="$TMP/shim:$TMP/nopy" /bin/bash "$BACKUP" --src "$SRC" --dest "$TMP/fakepw/claude-profiles/hermes/bk" 2>&1)"; RC=$?
eq "(SH) backup dest under the passwd-derived live path (shim) -> 5" "$RC" "5"; has "(SH) message" "$OUT" "forbidden live-home prefix"
OUT="$(HOME="$TMP/h" PATH="$TMP/shim:$TMP/nopy" /bin/bash "$RESTORE" --gen "$GEN" --target "$TMP/ok-sh" 2>&1)"; RC=$?
eq "(SH) restore elsewhere with the shim still works -> 0" "$RC" "0"
[ ! -e "$TMP/fakepw" ] && ok "(SH) nothing created at the fake live path" || nok "(SH) nothing created at the fake live path"

# --- (b) a symlink planted in a tampered generation's data/ is refused (hashes stay consistent: links are not files) ---
SRC="$TMP/src"; bk "$TMP/d-lnk" ; GEN="$(firstgen "$TMP/d-lnk")"
mkdir -p "$TMP/elsewhere"; echo x >"$TMP/elsewhere/f"; ln -s "$TMP/elsewhere/f" "$GEN/data/memories/planted.md"
rs --target "$TMP/r-lnk"; eq "(B) symlink in the generation's data/ -> 4" "$RC" "4"; has "(B) message" "$OUT" "contains a symlink"; hasnt "(B) never says hashes OK" "$OUT" "hashes OK"
[ ! -e "$TMP/r-lnk" ] && ok "(B) nothing restored" || nok "(B) nothing restored"
rm "$GEN/data/memories/planted.md"; ln -s "$TMP/elsewhere" "$GEN/data/skills/planted-dir"
rs --target "$TMP/r-lnk2"; eq "(B) directory symlink in data/ -> 4" "$RC" "4"; [ ! -e "$TMP/r-lnk2" ] && ok "(B) nothing restored (dir link)" || nok "(B) nothing restored (dir link)"
rm "$GEN/data/skills/planted-dir"; rs --target "$TMP/r-lnk3"; eq "(B) same generation without the link restores -> 0" "$RC" "0"

# --- (c) a generation = gen-<stamp> dir with SHA256SUMS + MANIFEST.txt + data/; a forged bare one is ignored everywhere ---
SRC="$TMP/src"; D="$TMP/d-forge"
HERMES_BACKUP_NOW=20260201T000001Z bk "$D" --keep 2; HERMES_BACKUP_NOW=20260201T000002Z bk "$D" --keep 2
mkdir "$D/gen-29991231T000000Z"; for i in $(seq 1 100); do echo "0000  f$i"; done >"$D/gen-29991231T000000Z/SHA256SUMS"
HERMES_BACKUP_NOW=20260201T000003Z bk "$D" --keep 2; eq "(C) run next to a forged future-dated gen -> 0" "$RC" "0"
hasnt "(C) forged 100-line SHA256SUMS is not the shrink-guard 'previous generation'" "$OUT" "SKIPPED"
eq "(C) real oldest pruned, forged neither counted nor evicting" "$(gens "$D")" "gen-20260201T000002Z gen-20260201T000003Z gen-29991231T000000Z "
mkdir "$D/gen-29991231T000001Z"; echo x >"$D/gen-29991231T000001Z/SHA256SUMS"; echo m >"$D/gen-29991231T000001Z/MANIFEST.txt"
HERMES_BACKUP_NOW=20260201T000004Z bk "$D" --keep 2; eq "(C) SHA256SUMS+MANIFEST but no data/ is not a generation either (takes no keep slot)" "$(gens "$D")" "gen-20260201T000003Z gen-20260201T000004Z gen-29991231T000000Z gen-29991231T000001Z "
# decoy names are neither counted nor pruned (even when otherwise complete)
D="$TMP/d-decoy2"; HERMES_BACKUP_NOW=20260202T000001Z bk "$D" --keep 2; HERMES_BACKUP_NOW=20260202T000002Z bk "$D" --keep 2
for dn in gen-FOO gen-2026 gen-20260101T000000Z.bak; do mkdir -p "$D/$dn/data"; echo x >"$D/$dn/SHA256SUMS"; echo m >"$D/$dn/MANIFEST.txt"; done
HERMES_BACKUP_NOW=20260202T000003Z bk "$D" --keep 2
eq "(C) decoys survive; real gens pruned to --keep 2" "$(gens "$D")" "gen-2026 gen-20260101T000000Z.bak gen-20260202T000002Z gen-20260202T000003Z gen-FOO "

# --- (d) the live entries are resolved physically EVEN with the tests-only prefix set (symlinked claude-profiles) ---
SRC="$TMP/src"; mkdir -p "$TMP/hd" "$TMP/realprof"; ln -s "$TMP/realprof" "$TMP/hd/claude-profiles"
OUT="$(HOME="$TMP/hd" bash "$BACKUP" --src "$SRC" --dest "$TMP/realprof/hermes/bk" 2>&1)"; RC=$?
eq "(D) backup dest reached via a symlinked claude-profiles, env prefix set -> 5" "$RC" "5"; has "(D) message" "$OUT" "forbidden live-home prefix"
OUT="$(HOME="$TMP/hd" bash "$RESTORE" --gen "$GEN" --target "$TMP/realprof/hermes/rs" 2>&1)"; RC=$?
eq "(D) restore target via a symlinked claude-profiles, env prefix set -> 5" "$RC" "5"
[ -z "$(ls -A "$TMP/realprof")" ] && ok "(D) nothing created behind the link" || nok "(D) nothing created behind the link"
OUT="$(HOME="$TMP/hd" bash "$BACKUP" --src "$SRC" --dest "$TMP/realprof/other/bk" 2>&1)"; eq "(D) a sibling of the live home is still allowed -> 0" "$?" "0"

# --- (e) rp() must not loop forever when basename/dirname are not on PATH (watchdog-bounded) ---
tooldir "$TMP/nobase" "${TOOLS[@]}"; rm -f "$TMP/nobase/basename" "$TMP/nobase/dirname"
timed() { # timed <cmd...>: run with a 10 s watchdog; sets RC (137 = killed by the watchdog)
  "$@" >"$TMP/timed.out" 2>&1 & local pid=$!
  ( sleep 10; kill -9 "$pid" 2>/dev/null ) >/dev/null 2>&1 & local w=$!
  wait "$pid" 2>/dev/null; RC=$?; kill "$w" 2>/dev/null; wait "$w" 2>/dev/null; OUT="$(cat "$TMP/timed.out")"; return 0
}
HERMES_BACKUP_FORBID_PREFIX="$TMP/nx/fl" HOME="$TMP/h" PATH="$TMP/shim:$TMP/nobase" timed /bin/bash "$BACKUP" --src "$SRC" --dest "$TMP/d-nobase"
eq "(E) backup without basename/dirname exits 5 (no hang)" "$RC" "5"; has "(E) message" "$OUT" "cannot resolve path"
HERMES_BACKUP_FORBID_PREFIX="$TMP/nx/fl" HOME="$TMP/h" PATH="$TMP/shim:$TMP/nobase" timed /bin/bash "$RESTORE" --gen "$GEN" --target "$TMP/r-nobase"
eq "(E) restore without basename/dirname exits 5 (no hang)" "$RC" "5"
[ ! -e "$TMP/d-nobase" ] && [ ! -e "$TMP/r-nobase" ] && ok "(E) nothing written" || nok "(E) nothing written"

# --- seams found by the delta review (each one has a mutation in the report) ---
# unreadable subdirectory in scope: hard failure (pipefail), nothing published
SRC="$TMP/unrd"; mk "$SRC"; mkdir "$SRC/memories/locked"; echo z >"$SRC/memories/locked/z.md"; chmod 000 "$SRC/memories/locked"
bk "$TMP/d-unrd"; eq "(U) unreadable data subdirectory -> 1" "$RC" "1"; nogen "$TMP/d-unrd" && ok "(U) no generation, no .tmp-*" || nok "(U) no generation, no .tmp-*"
chmod 755 "$SRC/memories/locked"
# restore keeps mtime (cp -p) and the generation's owner-only modes; the staged chmod made the 640 source file 600
SRC="$TMP/mt"; mk "$SRC"; echo old >"$SRC/memories/old.md"; chmod 640 "$SRC/memories/old.md"; touch -t 202001020304 "$SRC/memories/old.md"
bk "$TMP/d-mt"; GEN="$(firstgen "$TMP/d-mt")"; rs --target "$TMP/r-mt"; eq "(T) restore -> 0" "$RC" "0"
eq "(T) restored file keeps the old mtime (cp -Rp)" "$(stat -f %m "$TMP/r-mt/memories/old.md")" "$(stat -f %m "$SRC/memories/old.md")"
eq "(T) 640 source file is 600 after backup+restore" "$(stat -f %Lp "$TMP/r-mt/memories/old.md")" "600"
eq "(T) restored dirs are 700" "$(stat -f %Lp "$TMP/r-mt/memories")" "700"
eq "(T) restore target dir is 700" "$(stat -f %Lp "$TMP/r-mt")" "700"
# paths starting with - (dirname -- / basename -- / cd -P --)
SRC="$TMP/src"; mkdir -p "$TMP/cwd2/-ex" "$TMP/cwd2/-ex2"; GEN="$(firstgen "$TMP/d-base")"
OUT="$(cd "$TMP/cwd2" && bash "$BACKUP" --src "$SRC" --dest -nope/sub 2>&1)"; RC=$?
eq "(M) backup dest -nope/sub (missing, dash-leading) -> 0" "$RC" "0"; [ -d "$TMP/cwd2/-nope/sub" ] && ok "(M) landed in ./-nope/sub" || nok "(M) landed in ./-nope/sub ($OUT)"
OUT="$(cd "$TMP/cwd2" && bash "$BACKUP" --src "$SRC" --dest -ex/sub 2>&1)"; RC=$?
eq "(M) backup dest -ex/sub (existing dash-leading dir) -> 0" "$RC" "0"; [ -d "$TMP/cwd2/-ex/sub" ] && ok "(M) landed in ./-ex/sub" || nok "(M) landed in ./-ex/sub ($OUT)"
OUT="$(cd "$TMP/cwd2" && bash "$RESTORE" --gen "$GEN" --target -ex2/sub 2>&1)"; RC=$?
eq "(M) restore target -ex2/sub (existing dash-leading dir) -> 0" "$RC" "0"; [ -f "$TMP/cwd2/-ex2/sub/memories/M.md" ] && ok "(M) restored into ./-ex2/sub" || nok "(M) restored into ./-ex2/sub ($OUT)"
# the post-copy hook is the SOURCE-CHANGED path, not the staged-verify path
SRC="$TMP/ms"; mk "$SRC"; HERMES_BACKUP_TEST_MUTATE_SRC_AFTER=memories/M.md bk "$TMP/d-ms"
eq "(A) source changed after the staged verify -> 4" "$RC" "4"; has "(A) message says source changed" "$OUT" "source changed during backup"; hasnt "(A) message is not the staged-verify one" "$OUT" "verification"

echo "# passed=$passed failed=$failed"
[ "$failed" -eq 0 ]
