#!/usr/bin/env bash
# tools/hermes/test_verify-import-bundled.sh — tests for verify-import --bundled-source (Rule 10).
# Scratch under /private/tmp only; SYNTHETIC hq repo + import, SYNTHETIC "bundled" trees. The live-home cases use a FAKE
# h1-home via HERMES_IMPORT_TEST_LIVE_HOME; nothing touches the real Hermes home.
set -uo pipefail
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null LC_ALL=C
unset HERMES_HOME HERMES_IMPORT_TEST_LIVE_HOME HQ_REPO GIT_DIR GIT_WORK_TREE
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VER="$HERE/verify-import"; IMP="$HERE/import-learnings"
TMP="$(cd -P "$(mktemp -d /private/tmp/vib-test.XXXXXX)" && pwd -P)"; trap 'chmod -R u+w "$TMP" 2>/dev/null; rm -rf "$TMP"' EXIT
passed=0; failed=0
ok() { echo "ok - $1"; passed=$((passed + 1)); }
nok() { echo "not ok - $1"; failed=$((failed + 1)); }
eq() { if [ "$2" = "$3" ]; then ok "$1"; else nok "$1 (got '$2', want '$3')"; fi; }
has() { case "$2" in *"$3"*) ok "$1" ;; *) nok "$1 (no '$3' in: $2)" ;; esac; }
hasnt() { case "$2" in *"$3"*) nok "$1 (found '$3')" ;; *) ok "$1" ;; esac; }

FX="$TMP/fx"; mkdir -p "$FX/learnings" "$FX/retros"; cd "$FX" || exit 1
git init -q -b main . && git config user.name t && git config user.email t@example.invalid
printf '# Readme\nx\n' >learnings/README.md; printf '# Alpha lesson\n\nBody alpha.\n' >learnings/alpha.md
printf '# Retro readme\nx\n' >retros/README.md
git add -A && git commit -qm fx; SHA="$(git rev-parse HEAD)"; cd "$TMP" || exit 1
BASE="$TMP/base"; env -u HERMES_HOME bash "$IMP" "$BASE" --repo "$FX" --sha "$SHA" --apply >/dev/null 2>&1; eq "setup: import exit 0" "$?" 0
# placeholder matching SECRET_RES, built at runtime so this file holds no token-shaped literal
SECRET="gh""p_$(printf 'x%.0s' $(seq 1 36))"
# SYNTHETIC bundled source: two category dirs, one doc holds the placeholder
SRC="$TMP/src"; mkdir -p "$SRC/webhooks/sub" "$SRC/media"
printf 'doc one\n' >"$SRC/webhooks/a.md"; printf 'example: %s\n' "$SECRET" >"$SRC/webhooks/sub/b.md"; printf 'm\n' >"$SRC/media/m.md"
W=""; fresh() { W="$TMP/w$1"; rm -rf "$W"; cp -R "$BASE" "$W"; cp -R "$SRC/webhooks" "$SRC/media" "$W/"; }
vrun() { out="$(env -u HERMES_HOME bash "$VER" "$@" 2>&1)"; rc=$?; }
vw() { vrun "$W" --repo "$FX" --sha "$SHA" --allow-extra webhooks --allow-extra media "$@"; }
vb() { vw --bundled-source "$SRC" "$@"; }

# (l) without --bundled-source: old behaviour, the placeholder FAILs the secret scan
fresh l; vw; eq "(l) no --bundled-source: placeholder FAILs (exit 1)" "$rc" 1; has "(l) FAIL secrets" "$out" "FAIL secrets"; has "(l) names the file" "$out" "webhooks/sub/b.md"
hasnt "(l) no bundled line" "$out" "identical to source"; hasnt "(l) no bundled check" "$out" "bundled:"
# (a) identical tree: PASS, scan skipped
fresh a; vb; eq "(a) identical: exit 0" "$rc" 0; has "(a) ALLOWED identical line webhooks" "$out" "ALLOWED extra (identical to source): webhooks"
has "(a) ALLOWED identical line media" "$out" "ALLOWED extra (identical to source): media"; has "(a) PASS bundled" "$out" "PASS bundled: 2 extras"; has "(a) PASS secrets" "$out" "PASS secrets"
has "(a) final PASS" "$out" "verify-import: PASS (9 checks, 0 failed)"; hasnt "(a) secret never printed" "$out" "$SECRET"
# (b) one byte differs
fresh b; printf 'doc onE\n' >"$W/webhooks/a.md"; vb
eq "(b) byte differs: exit 1" "$rc" 1; has "(b) FAIL bundled" "$out" "FAIL bundled"; has "(b) names the path" "$out" "webhooks/a.md(bytes-differ)"
hasnt "(b) not marked identical" "$out" "identical to source): webhooks"; has "(b) other extra still identical" "$out" "identical to source): media"
# (c) extra file in target
fresh c; printf 'new\n' >"$W/webhooks/sub/zzz.md"; vb; eq "(c) extra file: exit 1" "$rc" 1; has "(c) names it" "$out" "webhooks/sub/zzz.md(extra-in-target)"
fresh c2; mkdir "$W/media/emptydir"; vb; eq "(c) extra empty dir: exit 1" "$rc" 1; has "(c) names it" "$out" "media/emptydir(extra-in-target)"
# (d) missing file in target
fresh d; rm "$W/webhooks/a.md"; vb; eq "(d) missing file: exit 1" "$rc" 1; has "(d) names it" "$out" "webhooks/a.md(missing-in-target)"
fresh d2; rm -rf "$W/media"; vb; eq "(d) missing whole extra dir: exit 1" "$rc" 1; has "(d) names it" "$out" "media(missing-in-target)"
# (e) symlink in target (byte-identical content behind the link)
fresh e; rm "$W/media/m.md"; ln -s "$SRC/media/m.md" "$W/media/m.md"; vb
eq "(e) symlink in target: exit 1" "$rc" 1; has "(e) names it" "$out" "media/m.md(symlink-in-target)"
# (f) symlink in source
fresh f; SRC2="$TMP/src2"; rm -rf "$SRC2"; cp -R "$SRC" "$SRC2"; rm "$SRC2/media/m.md"; ln -s "$W/media/m.md" "$SRC2/media/m.md"
vw --bundled-source "$SRC2"; eq "(f) symlink in source: exit 1" "$rc" 1; has "(f) names it" "$out" "media/m.md(symlink-in-source)"
# (g) allowed extra with no source counterpart is still scanned
fresh g; mkdir "$W/hq-index"; printf 'k: %s\n' "$SECRET" >"$W/hq-index/n.txt"; vb --allow-extra hq-index
eq "(g) unmatched extra with a hit: exit 1" "$rc" 1; has "(g) FAIL secrets" "$out" "FAIL secrets"; has "(g) names it" "$out" "hq-index/n.txt"; has "(g) bundled still PASS" "$out" "PASS bundled"
hasnt "(g) hq-index not claimed identical" "$out" "identical to source): hq-index"
fresh g2; mkdir "$W/hq-index"; printf 'clean\n' >"$W/hq-index/n.txt"; vb --allow-extra hq-index; eq "(g) unmatched clean extra: PASS" "$rc" 0
# (m) no content in the difference list
fresh m; printf 'example: %s CHANGED\n' "$SECRET" >"$W/webhooks/sub/b.md"; vb; eq "(m) changed secret-bearing doc: exit 1" "$rc" 1
has "(m) names it" "$out" "webhooks/sub/b.md(bytes-differ)"; has "(m) FAIL bundled" "$out" "FAIL bundled"; has "(m) AND FAIL secrets (scan not skipped when compare failed)" "$out" "FAIL secrets"; hasnt "(m) planted string absent from output" "$out" "$SECRET"; hasnt "(m) prefix absent" "$out" "gh""p_xxx"
# (h)-(k) refusals
fresh h; vw --bundled-source "$W/media"; eq "(h) source inside target: exit 2" "$rc" 2; has "(h) reason" "$out" "inside the target"
vw --bundled-source "$W"; eq "(h) source equals target: exit 2" "$rc" 2
ln -s "$W" "$TMP/wlink"; vw --bundled-source "$TMP/wlink"; eq "(h) source symlink to target: exit 2" "$rc" 2
vw --bundled-source "src"; eq "(i) relative source: exit 2" "$rc" 2; has "(i) reason" "$out" "absolute"
vw --bundled-source "$TMP/nope"; eq "(k) missing source dir: exit 2" "$rc" 2; has "(k) reason" "$out" "not an existing directory"
printf 'f\n' >"$TMP/afile"; vw --bundled-source "$TMP/afile"; eq "(k) source is a file: exit 2" "$rc" 2
ln -s "$SRC" "$TMP/srclink"; vw --bundled-source "$TMP/srclink"; eq "(k) source is a symlink: exit 2" "$rc" 2; has "(k) reason" "$out" "symlink"
vw --bundled-source "$SRC" --bundled-source "$SRC2"; eq "(k) given twice: exit 2" "$rc" 2
export HERMES_IMPORT_TEST_LIVE_HOME="$TMP/fakelive/hermes/h1-home"; mkdir -p "$HERMES_IMPORT_TEST_LIVE_HOME/skills" "$TMP/fakelive/hermes/h1-home-sibling"
vw --bundled-source "$HERMES_IMPORT_TEST_LIVE_HOME"; eq "(j) source is the live home: exit 3" "$rc" 3; has "(j) REFUSED" "$out" "REFUSED"; has "(j) labelled source dir" "$out" "source dir resolves into"
vw --bundled-source "$HERMES_IMPORT_TEST_LIVE_HOME/skills"; eq "(j) source inside the live home: exit 3" "$rc" 3
vw --bundled-source "$TMP/fakelive/hermes"; eq "(j) source contains the live home: exit 3" "$rc" 3
vw --bundled-source "$TMP/fakelive/hermes/h1-home/skills/../skills"; eq "(j) '..' path into the live home: exit 3" "$rc" 3
ln -s "$HERMES_IMPORT_TEST_LIVE_HOME" "$TMP/livelink"; vw --bundled-source "$TMP/livelink"; eq "(j) symlink to the live home: exit 3" "$rc" 3
vw --bundled-source "$HERMES_IMPORT_TEST_LIVE_HOME" --i-am-the-owner-live; eq "(j) owner flag does NOT relax the source guard: exit 3" "$rc" 3
vw --bundled-source "$TMP/fakelive/hermes/h1-home-sibling"; eq "(j) sibling dir with a live-like name is not refused as live (exit 1 = ordinary scan FAIL, not 3)" "$rc" 1
unset HERMES_IMPORT_TEST_LIVE_HOME
# the default (pwd-derived) live home is guarded through the same function: dry check, nothing created or read there
DL="$(python3 -B -I -c 'import sys;sys.path.insert(0,sys.argv[1]);import il_guard as g;print(g.DEFAULT_LIVE)' "$HERE")"
chk="$(python3 -B -I -c 'import sys;sys.path.insert(0,sys.argv[1]);import verify_bundled as v;print(v.check_dir(sys.argv[2],sys.argv[3])[0])' "$HERE" "$DL" "$W")"
eq "(j) pwd-form live home path is refused by check_dir (exit 3), no filesystem access to it" "$chk" 3
# (p) symlinked PARENT of REL (M1): fake live home via HERMES_IMPORT_TEST_LIVE_HOME holds a secret-shaped file; links point into it
export HERMES_IMPORT_TEST_LIVE_HOME="$TMP/fl/hermes/h1-home"; FL="$HERMES_IMPORT_TEST_LIVE_HOME"; mkdir -p "$FL/x"; printf 'k: %s\n' "$SECRET" >"$FL/x/f"
vp() { vrun "$W" --repo "$FX" --sha "$SHA" --allow-extra cat/x --bundled-source "$1"; }
cleanw() { W="$TMP/w$1"; rm -rf "$W"; cp -R "$BASE" "$W"; }
cleanw p; mkdir "$W/cat"; cp -R "$FL/x" "$W/cat/x"; PS="$TMP/ps"; rm -rf "$PS"; mkdir "$PS"; ln -s "$FL" "$PS/cat"; vp "$PS"
eq "(p) source-only symlinked parent: exit 1" "$rc" 1; has "(p) FAIL bundled names it" "$out" "cat/x(symlinked-parent)"; hasnt "(p) no identical line" "$out" "identical to source): cat/x"
hasnt "(p) no PASS bundled" "$out" "PASS bundled"
cleanw p2; ln -s "$FL" "$W/cat"; PS2="$TMP/ps2"; rm -rf "$PS2"; mkdir -p "$PS2/cat"; cp -R "$FL/x" "$PS2/cat/x"; vp "$PS2"
eq "(p) target-only symlinked parent: exit 1" "$rc" 1; has "(p) FAIL bundled names it" "$out" "cat/x(symlinked-parent)"; hasnt "(p) no identical line" "$out" "identical to source): cat/x"
cleanw p3; mkdir "$W/cat"; cp -R "$FL/x" "$W/cat/x"; rm -rf "$PS2"; mkdir -p "$PS2/cat"; cp -R "$FL/x" "$PS2/cat/x"; vp "$PS2"
eq "(p) both sides real: exit 0" "$rc" 0; has "(p) identical line" "$out" "identical to source): cat/x"; has "(p) PASS bundled" "$out" "PASS bundled"
unset HERMES_IMPORT_TEST_LIVE_HOME
# (r) (target-side symlinks are never followed by the scan, so those cases assert the layout FAIL stray-symlink instead of FAIL secrets)
# (r) multi-level REL cat/sub/x: EVERY parent component is lstat-checked, not just the immediate parent; x holds the placeholder so a skipped scan shows
RL="$TMP/rl"; rm -rf "$RL"; mkdir -p "$RL/c/sub" "$RL/a/b/c"; printf 'k: %s\n' "$SECRET" >"$RL/c/sub/x"; printf 'k: %s\n' "$SECRET" >"$RL/a/b/c/x"
vr() { vrun "$W" --repo "$FX" --sha "$SHA" --allow-extra "$1" --bundled-source "$2"; }
rchk() { eq "($1) exit 1" "$rc" 1; has "($1) FAIL bundled names it" "$out" "$2(symlinked-parent)"; hasnt "($1) no identical line" "$out" "identical to source): $2"; hasnt "($1) no PASS bundled" "$out" "PASS bundled"; has "($1) scan ran (${3:-FAIL secrets})" "$out" "${3:-FAIL secrets}"; }
rsrc() { rm -rf "$TMP/rs"; mkdir "$TMP/rs"; cp -R "$RL/c" "$TMP/rs/real-c"; mkdir -p "$TMP/rs/a-real"; cp -R "$RL/a/b" "$TMP/rs/a-real/b"; }
cleanw r0; mkdir -p "$W/cat"; cp -R "$RL/c/sub" "$W/cat/sub"; rm -rf "$TMP/rs0"; mkdir -p "$TMP/rs0/cat"; cp -R "$RL/c/sub" "$TMP/rs0/cat/sub"; vr cat/sub/x "$TMP/rs0"
has "(r) control real/real multi-level: PASS bundled" "$out" "PASS bundled"; has "(r) control identical line" "$out" "identical to source): cat/sub/x"; hasnt "(r) control: no symlinked-parent" "$out" "symlinked-parent"
# (a depth-3 REL is always a layout FAIL, rc 1, so the control asserts the bundled lines, not rc 0)
cleanw r1; mkdir -p "$W/cat"; cp -R "$RL/c/sub" "$W/cat/sub"; rsrc; mkdir "$TMP/rs/s1"; ln -s "$TMP/rs/real-c" "$TMP/rs/s1/cat"; vr cat/sub/x "$TMP/rs/s1"; rchk "r1 source-side symlinked cat" cat/sub/x
cleanw r2; rsrc; ln -s "$TMP/rs/real-c" "$W/cat"; mkdir -p "$TMP/rs/s2/cat"; cp -R "$RL/c/sub" "$TMP/rs/s2/cat/sub"; vr cat/sub/x "$TMP/rs/s2"; rchk "r2 target-side symlinked cat" cat/sub/x stray-symlink
cleanw r3; rsrc; ln -s "$TMP/rs/real-c" "$W/cat"; mkdir "$TMP/rs/s3"; ln -s "$TMP/rs/real-c" "$TMP/rs/s3/cat"; vr cat/sub/x "$TMP/rs/s3"; rchk "r3 both sides symlinked cat" cat/sub/x stray-symlink
cleanw r4; mkdir -p "$W/a"; cp -R "$RL/a/b" "$W/a/b"; rsrc; mkdir "$TMP/rs/s4"; ln -s "$TMP/rs/a-real" "$TMP/rs/s4/a"; vr a/b/c/x "$TMP/rs/s4"; rchk "r4 source-side symlinked GRANDparent a, real parent c" a/b/c/x
cleanw r4b; rsrc; ln -s "$TMP/rs/a-real" "$W/a"; mkdir -p "$TMP/rs/s4b/a"; cp -R "$RL/a/b" "$TMP/rs/s4b/a/b"; vr a/b/c/x "$TMP/rs/s4b"; rchk "r4b target-side symlinked GRANDparent a, real parent c" a/b/c/x stray-symlink
cleanw r5; mkdir -p "$W/cat"; cp -R "$RL/c/sub" "$W/cat/sub"; rm -rf "$TMP/rs5"; mkdir -p "$TMP/rs5/cat-real"; cp -R "$RL/c/sub" "$TMP/rs5/cat-real/sub"; ln -s cat-real "$TMP/rs5/cat"; vr cat/sub/x "$TMP/rs5"; rchk "r5 source cat -> in-root sibling cat-real (realpath stays in root)" cat/sub/x
# (q) FILE-type extra with a source counterpart (M3): used to crash rc 2 NotADirectoryError
printf 'top\n' >"$SRC/top.md"
fresh q; printf 'top\n' >"$W/top.md"; vw --bundled-source "$SRC" --allow-extra top.md
eq "(q) identical file extra: exit 0" "$rc" 0; has "(q) identical line" "$out" "identical to source): top.md"
fresh q2; printf 'tOp\n' >"$W/top.md"; vw --bundled-source "$SRC" --allow-extra top.md
eq "(q) differing file extra: exit 1" "$rc" 1; has "(q) names it" "$out" "FAIL bundled"; has "(q) reason" "$out" "top.md(bytes-differ)"
rm -f "$SRC/top.md"
# (n) --help documents it
vrun --help; has "(n) help names the option" "$out" "--bundled-source DIR"; has "(n) help: owner flag never relaxes" "$(echo "$out" | tr -s ' \n' '  ')" "never relaxes this"
echo "# passed=$passed failed=$failed"; [ "$failed" -eq 0 ]
