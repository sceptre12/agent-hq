#!/usr/bin/env bash
# tools/hermes/test_backup-hermes-4.sh — full-review (PR #40 @ a373d11f) fix tests, part 2 (Hermes row 6): the live-home
# guard can only be ADDED to, dest/target refusals, --help, file modes, restore seams (M4), restore ancestors.
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
unset HERMES_BACKUP_NOW HERMES_BACKUP_TEST_CORRUPT HERMES_BACKUP_TEST_MUTATE_SRC HERMES_BACKUP_TEST_MUTATE_SRC_AFTER \
  HERMES_BACKUP_TEST_EXTRA HERMES_BACKUP_TEST_MKGEN_RACE HERMES_RESTORE_TEST_CORRUPT_AFTER
export HERMES_BACKUP_FORBID_PREFIX="$TMP/fake-live"
mk() { mkdir -p "$1/memories" "$1/skills/a" "$1/pending"; echo m >"$1/memories/M.md"; echo s >"$1/skills/a/S.md"; echo p >"$1/pending/p.json"; }
bk() { local d="$1"; shift; OUT="$(bash "$BACKUP" --src "$SRC" --dest "$d" "$@" 2>&1)"; RC=$?; }
rs() { OUT="$(bash "$RESTORE" --gen "$GEN" "$@" 2>&1)"; RC=$?; }
nogen() { [ ! -e "$1" ] || [ -z "$(find "$1" -mindepth 1 -maxdepth 1)" ]; }
firstgen() { find "$1" -mindepth 1 -maxdepth 1 -name 'gen-*' | sort | head -n 1; }

# --- the real live-home guard is always on; the env var can only ADD (reviewer: tests-only env replaced it) ---
PW="$(python3 -I -c 'import os,pwd;print(pwd.getpwuid(os.getuid()).pw_dir)')"
mkdir -p "$TMP/home"
OUT="$(HOME="$TMP/home" bash "$BACKUP" --print-forbidden 2>&1)"; eq "(G) backup --print-forbidden -> 0" "$?" "0"
has "(G) list has the HOME-derived live home" "$OUT" "$TMP/home/claude-profiles/hermes"
has "(G) list has the passwd-derived live home" "$OUT" "$PW/claude-profiles/hermes"
has "(G) list has the env-added prefix" "$OUT" "$TMP/fake-live"
OUT="$(HOME="$TMP/home" bash "$RESTORE" --print-forbidden 2>&1)"; has "(G) restore list has the HOME-derived live home" "$OUT" "$TMP/home/claude-profiles/hermes"
SRC="$TMP/src"; mk "$SRC"
OUT="$(HOME="$TMP/home" bash "$BACKUP" --src "$SRC" --dest "$TMP/home/claude-profiles/hermes/bk" 2>&1)"; eq "(G) backup dest under HOME live path, env prefix elsewhere -> 5" "$?" "5"
[ ! -e "$TMP/home/claude-profiles" ] && ok "(G) nothing created under the live path" || nok "(G) nothing created under the live path"
bk "$TMP/d-g"; GEN="$(firstgen "$TMP/d-g")"
OUT="$(HOME="$TMP/home" bash "$RESTORE" --gen "$GEN" --target "$TMP/home/claude-profiles/hermes/rst" 2>&1)"; eq "(G) restore target under HOME live path -> 5" "$?" "5"

# --- dest hygiene: a file, a symlink root, a file component -> clean exit 5 (was raw exit 1) ---
echo f >"$TMP/afile"; bk "$TMP/afile"; eq "(D) dest is a file -> 5" "$RC" "5"; has "(D) message" "$OUT" "not a directory"
bk "$TMP/afile/sub"; eq "(D) dest below a file -> 5" "$RC" "5"
mkdir -p "$TMP/realdest"; ln -s "$TMP/realdest" "$TMP/lnkdest"
bk "$TMP/lnkdest"; eq "(D) dest root is a symlink -> 5" "$RC" "5"; has "(D) message names the symlink" "$OUT" "symlink"
bk "$TMP/lnkdest/"; eq "(D) dest root symlink with trailing slash -> 5" "$RC" "5"
nogen "$TMP/realdest" && ok "(D) nothing written through the dest link" || nok "(D) nothing written through the dest link"
ln -s "$SRC" "$TMP/lnksrc"
OUT="$(bash "$BACKUP" --src "$TMP/lnksrc" --dest "$TMP/d-lnksrc" 2>&1)"; eq "(D) symlinked src root still works -> 0" "$?" "0"
has "(D) log line prints the resolved src realpath" "$OUT" "from $SRC "

# --- --help touches nothing ---
mkdir -p "$TMP/emptycwd"
OUT="$(cd "$TMP/emptycwd" && bash "$BACKUP" --help 2>&1)"; eq "(H) backup --help -> 0" "$?" "0"; has "(H) backup help has the exit-code table" "$OUT" "exit codes:"
OUT="$(cd "$TMP/emptycwd" && bash "$RESTORE" -h 2>&1)"; eq "(H) restore -h -> 0" "$?" "0"; has "(H) restore help has the exit-code table" "$OUT" "exit codes:"
OUT="$(cd "$TMP/emptycwd" && bash "$BACKUP" --src "$SRC" --dest "$TMP/d-help" --help 2>&1)"
[ ! -e "$TMP/d-help" ] && [ -z "$(ls -A "$TMP/emptycwd")" ] && ok "(H) --help created nothing" || nok "(H) --help created nothing"

# --- file modes: staged tree is owner-only whatever the source modes; mtimes/exec bit kept (cp -p) ---
SRC="$TMP/modes"; mk "$SRC"; chmod 644 "$SRC/memories/M.md"; printf '#!/bin/sh\n' >"$SRC/skills/a/run.sh"; chmod 755 "$SRC/skills/a/run.sh"
touch -t 202001020304 "$SRC/memories/M.md"; chmod 755 "$SRC/skills"
bk "$TMP/d-modes"; eq "(P) backup -> 0" "$RC" "0"; GEN="$(firstgen "$TMP/d-modes")"
eq "(P) 644 source file is 600 in the generation" "$(stat -f %Lp "$GEN/data/memories/M.md")" "600"
eq "(P) 755 source file is 700 (owner exec kept)" "$(stat -f %Lp "$GEN/data/skills/a/run.sh")" "700"
eq "(P) 755 source dir is 700 in the generation" "$(stat -f %Lp "$GEN/data/skills")" "700"
eq "(P) source file mode untouched" "$(stat -f %Lp "$SRC/memories/M.md")" "644"
eq "(P) mtime preserved (cp -p)" "$(stat -f %m "$GEN/data/memories/M.md")" "$(stat -f %m "$SRC/memories/M.md")"

# --- restore refusals (M4 seams) ---
rs --target "$GEN/data/sub"; eq "(R) target inside the generation -> 5" "$RC" "5"; has "(R) message" "$OUT" "inside the generation"
[ ! -e "$GEN/data/sub" ] && ok "(R) nothing written into the generation" || nok "(R) nothing written into the generation"
rs --target "$TMP/afile"; eq "(R) target is a file -> 5" "$RC" "5"; has "(R) message" "$OUT" "not a directory"
mkdir -p "$TMP/cwdr/sub"; echo keep >"$TMP/cwdr/keep.txt"
rs --target "$(dirname "$GEN")" --force; eq "(R) --force into the generation's parent -> 5" "$RC" "5"
rs --target "$TMP" --force; eq "(R) --force into an ancestor of the generation -> 5" "$RC" "5"
OUT="$(cd "$TMP/cwdr" && bash "$RESTORE" --gen "$GEN" --target . --force 2>&1)"; eq "(R) --force into . (the cwd) -> 5" "$?" "5"
OUT="$(cd "$TMP/cwdr/sub" && bash "$RESTORE" --gen "$GEN" --target .. --force 2>&1)"; eq "(R) --force into a parent of the cwd -> 5" "$?" "5"
[ ! -e "$TMP/cwdr/memories" ] && ok "(R) nothing merged into the cwd" || nok "(R) nothing merged into the cwd"
OUT="$(HOME="$TMP/cwdr" bash "$RESTORE" --gen "$GEN" --target "$TMP/cwdr" --force 2>&1)"; eq "(R) --force into \$HOME -> 5" "$?" "5"
rs --target "$TMP/r-ok"; eq "(R) a fresh target still works -> 0" "$RC" "0"
HERMES_RESTORE_TEST_CORRUPT_AFTER=1 rs --target "$TMP/r-bad"; eq "(R) restored copy corrupted after the copy -> 4" "$RC" "4"; has "(R) message" "$OUT" "restored copy fails"
echo extra >"$GEN/data/extra.txt"
rs --target "$TMP/r-cnt"; eq "(R) generation with an extra file (count differs) -> 4" "$RC" "4"; has "(R) message" "$OUT" "file count differs"
[ ! -e "$TMP/r-cnt" ] && ok "(R) nothing restored for a count mismatch" || nok "(R) nothing restored for a count mismatch"
rm "$GEN/data/extra.txt"

mkdir -p "$TMP/r-ro"; chmod 500 "$TMP/r-ro"
rs --target "$TMP/r-ro"; eq "(R) cp failure (read-only empty target) stops with exit 1 (set -e)" "$RC" "1"
chmod 700 "$TMP/r-ro"

echo "# passed=$passed failed=$failed"
[ "$failed" -eq 0 ]
