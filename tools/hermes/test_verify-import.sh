#!/usr/bin/env bash
# tools/hermes/test_verify-import.sh — tests for verify-import (row 7a, Rule 10).
# Scratch under /private/tmp only; builds a SYNTHETIC hq repo, imports it with import-learnings, then breaks copies.
# The live-home tests use a FAKE h1-home via HERMES_IMPORT_TEST_LIVE_HOME; nothing touches the real Hermes home.
set -uo pipefail
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null LC_ALL=C
unset HERMES_HOME HERMES_IMPORT_TEST_LIVE_HOME HQ_REPO GIT_DIR GIT_WORK_TREE
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VER="$HERE/verify-import"; IMP="$HERE/import-learnings"
TMP="$(mktemp -d /private/tmp/vi-test.XXXXXX)"; trap 'chmod -R u+w "$TMP" 2>/dev/null; rm -rf "$TMP"' EXIT
passed=0; failed=0
ok() { echo "ok - $1"; passed=$((passed + 1)); }
nok() { echo "not ok - $1"; failed=$((failed + 1)); }
eq() { if [ "$2" = "$3" ]; then ok "$1"; else nok "$1 (got '$2', want '$3')"; fi; }
has() { case "$2" in *"$3"*) ok "$1" ;; *) nok "$1 (no '$3' in: $2)" ;; esac; }
hasnt() { case "$2" in *"$3"*) nok "$1 (found '$3')" ;; *) ok "$1" ;; esac; }

# synthetic hq repo: only notes.txt is not an input; README/METHODOLOGY/_TEMPLATE are imported as prefixed skills
FX="$TMP/fx"; mkdir -p "$FX/learnings/topic" "$FX/retros"; cd "$FX" || exit 1
git init -q -b main . && git config user.name t && git config user.email t@example.invalid
printf '# Readme\nx\n' >learnings/README.md; printf '# Method\nx\n' >learnings/METHODOLOGY.md
printf '# Retro readme\nx\n' >retros/README.md; printf '# Template\nx\n' >retros/_TEMPLATE.md; printf 'not md\n' >learnings/notes.txt
# shellcheck disable=SC2016
printf '### Alpha lesson   <!-- 2026-01-02 -->\n\n**Context:** the alpha thing broke.\n\n## Fix\n\nDo `x`.\n' >learnings/alpha-lesson.md
printf '# Beta topic lesson\n\nBeta body text.\n' >learnings/topic/2026-03-04-beta.md
printf '# Retro gamma  <!-- 2026-05-06 -->\n\n- **Period:** may\n' >retros/2026-05-06-gamma.md
for i in 1 2 3 4 5 6 7 8; do printf '# Lesson number %s\n\nBody %s here.\n\n## Part\n\nmore\n\n\n' "$i" "$i" >"learnings/more-$i.md"; done
git add -A && git commit -qm fx; SHA="$(git rev-parse HEAD)"; cd "$TMP" || exit 1
N=15
BASE="$TMP/base"; env -u HERMES_HOME bash "$IMP" "$BASE" --repo "$FX" --sha "$SHA" --apply >/dev/null 2>&1; eq "setup: import exit 0" "$?" 0
eq "setup: $N skills imported" "$(find "$BASE" -name SKILL.md | wc -l | tr -d ' ')" "$N"
digest() { (cd "$1" && find . | sort | while read -r f; do stat -f '%N %z %m %p' "$f"; done | shasum); }
vrun() { out="$(env -u HERMES_HOME bash "$VER" "$@" 2>&1)"; rc=$?; }   # sets $out, $rc
W=""; fresh() { W="$TMP/w$1"; rm -rf "$W"; cp -R "$BASE" "$W"; }
sk() { echo "$W/$1/SKILL.md"; }
sub() { sed "$2" "$1" >"$1.n" && mv "$1.n" "$1"; }   # sub FILE SEDEXPR
vw() { vrun "$W" --repo "$FX" --sha "$SHA" "$@"; }

# (a) clean
fresh a
vw; eq "(a) clean: exit 0" "$rc" 0
has "(a) final line PASS" "$out" "verify-import: PASS (8 checks, 0 failed)"
has "(a) counts equal ($N)" "$out" "$N skills in target, $N expected, missing=0 extra=0"
has "(a) seed printed" "$out" "seed="
vrun "$W" --repo "$FX" >/dev/null 2>&1; eq "(a) default --sha is origin/main: unreadable (no remote ref) -> 2" "$rc" 2
# (a2) the four housekeeping files are imported under category-prefixed names, verified by the same tool
for nm in learnings/learnings-readme learnings/learnings-methodology retros/retros-readme retros/retros-template; do
  [ -f "$W/$nm/SKILL.md" ] && ok "(a2) $nm present and verified" || nok "(a2) $nm missing"
done
[ ! -e "$W/learnings/readme" ] && [ ! -e "$W/retros/readme" ] && [ ! -e "$W/retros/template" ] && ok "(a2) no bare readme/template skill" || nok "(a2) bare name present"
fresh a2; rm -rf "$W/retros/retros-readme"; vw
eq "(a2) removed retros-readme: exit 1" "$rc" 1; has "(a2) names the missing prefixed skill" "$out" "missing:retros/retros-readme"
# (b) removed folder
fresh b; rm -rf "$W/learnings/alpha-lesson"; vw
eq "(b) removed folder: exit 1" "$rc" 1; has "(b) FAIL count" "$out" "FAIL count"; has "(b) names the missing skill" "$out" "missing:learnings/alpha-lesson"
fresh b2; rm "$(sk learnings/alpha-lesson)"; vw
has "(b) folder without SKILL.md: count" "$out" "missing:learnings/alpha-lesson"; has "(b) folder without SKILL.md: frontmatter" "$out" "alpha-lesson(no-SKILL.md)"
# (c) extra folder
fresh c; mkdir "$W/learnings/zzz-extra"; cp "$(sk learnings/alpha-lesson)" "$W/learnings/zzz-extra/SKILL.md"; vw
eq "(c) extra folder: exit 1" "$rc" 1; has "(c) FAIL count" "$out" "FAIL count"; has "(c) names the extra" "$out" "extra:learnings/zzz-extra"
# (d) edited body
fresh d; sub "$(sk learnings/alpha-lesson)" 's/\*\*Context:\*\* the alpha thing broke/**Context:** the alpha thing BROKE/'; vw
eq "(d) edited body: exit 1" "$rc" 1; has "(d) FAIL body" "$out" "FAIL body: sha256"; has "(d) names the file" "$out" "learnings/alpha-lesson"; has "(d) frontmatter still PASS" "$out" "PASS frontmatter"
# (e) created_by
fresh e; sub "$(sk retros/2026-05-06-gamma)" 's/^name: .*/&\
created_by: agent/'; vw
eq "(e) created_by: exit 1" "$rc" 1; has "(e) FAIL frontmatter" "$out" "FAIL frontmatter"; has "(e) says created_by" "$out" "(created_by)"
# (f) name != folder
fresh f; sub "$(sk learnings/more-3)" 's/^name: .*/name: other-name/'; vw
eq "(f) name!=folder: exit 1" "$rc" 1; has "(f) reported" "$out" "learnings/more-3(name!=folder)"
fresh f2; sub "$(sk learnings/more-3)" 's/^name: .*/name: Bad Name/'; vw; has "(f) invalid name reported" "$out" "(name-invalid)"
# (g) description > 1024
fresh g; python3 -I -c 'import sys,json,re;p=sys.argv[1];t=open(p).read();open(p,"w").write(re.sub(r"(?m)^description: .*$","description: "+json.dumps("x"*1100),t,count=1))' "$(sk learnings/more-4)"; vw
eq "(g) long description: exit 1" "$rc" 1; has "(g) reported" "$out" "learnings/more-4(description-length)"
# (h) footer sha mismatch
fresh h; sub "$(sk learnings/more-5)" "s/@$SHA/@0000000000000000000000000000000000000000/"; vw
eq "(h) footer sha: exit 1" "$rc" 1; has "(h) reported" "$out" "learnings/more-5(footer-sha)"
# (i) secret-shaped content, built at RUNTIME so this file holds no token-shaped literal
SECRET="gh""p_$(printf 'a%.0s' $(seq 1 36))"
fresh i; sub "$(sk topic/2026-03-04-beta)" "s/Beta body text./Beta body text. $SECRET/"; vw
eq "(i) secret: exit 1" "$rc" 1; has "(i) FAIL secrets" "$out" "FAIL secrets"; hasnt "(i) match not printed (full)" "$out" "$SECRET"; hasnt "(i) match not printed (prefix)" "$out" "gh""p_aaa"
# (j) spot sampling
fresh j; vw --spot 4 --seed 7; s1="$(echo "$out" | grep '^seed=')"; vw --spot 4 --seed 7; s2="$(echo "$out" | grep '^seed=')"
smp() { echo "$out" | sed -n 's/^seed=.*sample=//p'; }   # only the sample= field (seed=N differs by construction)
eq "(j) same seed -> same sample" "$s1" "$s2"; has "(j) seed printed" "$s1" "seed=7 spot=4 sample="
vw --spot 4 --seed 7; s7="$(smp)"; diff=0; for sd in 1 2 3 4 5 6 8 9; do vw --spot 4 --seed "$sd"; [ "$(smp)" != "$s7" ] && diff=1; done; eq "(j) different seeds give a different sample" "$diff" 1
vw --spot 3 --seed 1; eq "(j) N respected (3 names)" "$(echo "$out" | sed -n 's/^seed=.*sample=//p' | tr ',' '\n' | wc -l | tr -d ' ')" 3
vw --spot 99 --seed 1; has "(j) N capped at pool ($N)" "$out" "spot=$N "
vw; has "(j) default 10" "$out" "spot=10 "
vw --spot 0; has "(j) --spot 0" "$out" "spot=0 "
# (k) live-home refusal and exit 2 cases (FAKE h1-home)
export HERMES_IMPORT_TEST_LIVE_HOME="$TMP/fakelive/hermes/h1-home"; mkdir -p "$HERMES_IMPORT_TEST_LIVE_HOME/skills"; ln -s "$HERMES_IMPORT_TEST_LIVE_HOME" "$TMP/link"
vrun "$HERMES_IMPORT_TEST_LIVE_HOME/skills" --repo "$FX" --sha "$SHA"; eq "(k) fake h1-home refused: exit 3" "$rc" 3; has "(k) REFUSED message" "$out" "REFUSED"
vrun "$TMP/link/skills" --repo "$FX" --sha "$SHA"; eq "(k) symlink into h1-home refused" "$rc" 3
vrun "$TMP/fakelive/hermes" --repo "$FX" --sha "$SHA"; eq "(k) parent of h1-home refused" "$rc" 3
out="$(HERMES_HOME="$HERMES_IMPORT_TEST_LIVE_HOME" bash "$VER" "$BASE" --repo "$FX" --sha "$SHA" 2>&1)"; eq "(k) HERMES_HOME=h1-home refused" "$?" 3
vrun "$HERMES_IMPORT_TEST_LIVE_HOME/skills" --repo "$FX" --sha "$SHA" --i-am-the-owner-live; eq "(k) owner flag skips the guard (empty skills dir -> FAIL 1, not 3)" "$rc" 1
unset HERMES_IMPORT_TEST_LIVE_HOME
vrun "$BASE" --repo "$FX" --sha deadbeef; eq "(k) bad sha: exit 2" "$rc" 2
vrun "$BASE" --repo "$TMP/nonrepo" --sha "$SHA"; eq "(k) unreadable repo: exit 2" "$rc" 2
vrun "$TMP/does-not-exist" --repo "$FX" --sha "$SHA"; eq "(k) missing target: exit 2" "$rc" 2
vrun; eq "(k) no target arg: exit 2" "$rc" 2
vrun "$BASE" --repo "$FX" --sha "$SHA" --i-am-the-owner-live; eq "(k) full flag with --repo/--sha accepted: exit 0" "$rc" 0
vrun "$BASE" --repo "$FX" --sha "$SHA" --i-am; eq "(k) abbreviated flag rejected (allow_abbrev=False): exit 2" "$rc" 2; has "(k) abbreviation is the reason" "$out" "unrecognized arguments"
# (l) read-only: target listing digest (path size mtime mode) identical before/after, pass and fail runs
fresh l; d1="$(digest "$W")"; vw >/dev/null 2>&1; eq "(l) digest unchanged after PASS run" "$(digest "$W")" "$d1"
rm -rf "$W/learnings/alpha-lesson"; d1="$(digest "$W")"; vw >/dev/null 2>&1; eq "(l) digest unchanged after FAIL run" "$(digest "$W")" "$d1"
has "(l) in-run readonly check reported" "$out" "PASS readonly"
# (m) --help
d1="$(digest "$TMP")"; vrun --help; eq "(m) --help exit 0" "$rc" 0; has "(m) usage" "$out" "usage: verify-import"
has "(m) exit table" "$out" "Exit: 0 PASS, 1 FAIL"; has "(m) exit 3" "$out" "3 live Hermes home refused"; has "(m) owner flag" "$out" "--i-am-the-owner-live"
eq "(m) --help touches nothing" "$(digest "$TMP")" "$d1"
# (n) --allow-extra (M1): hq-index and .archive in the target, as the owner flow leaves them
mkx() { mkdir -p "$W/$1"; printf -- '---\nname: x\ndescription: "x"\n---\n\nextra body\n' >"$W/$1/SKILL.md"; }
fresh n1; mkx hq-index; vw; eq "(n) hq-index without flag: exit 1" "$rc" 1; has "(n) hq-index named" "$out" "hq-index/SKILL.md"
vw --allow-extra hq-index; eq "(n) hq-index with --allow-extra: PASS" "$rc" 0; has "(n) ALLOWED line" "$out" "ALLOWED extra: hq-index"; has "(n) allowed counted" "$out" "allowed=1"
fresh n2; mkx .archive/old-skill; vw; eq "(n) .archive without flag: exit 1" "$rc" 1
vw --allow-extra .archive; eq "(n) .archive with --allow-extra: PASS" "$rc" 0; has "(n) ALLOWED .archive" "$out" "ALLOWED extra: .archive"
mkx hq-index; vw --allow-extra .archive --allow-extra hq-index; eq "(n) both flags (repeatable): PASS" "$rc" 0
mkx zzz-unknown; vw --allow-extra .archive --allow-extra hq-index; eq "(n) unlisted extra still FAILs" "$rc" 1; has "(n) unlisted named" "$out" "zzz-unknown"
vw --allow-extra 'hq-*' --allow-extra .archive; eq "(n) glob entry rejected: exit 2" "$rc" 2
vw --allow-extra learnings/alpha-lesson; eq "(n) allow-extra naming an expected skill: exit 2" "$rc" 2; has "(n) expected skill named" "$out" "expected skill learnings/alpha-lesson"
vw --allow-extra learnings; eq "(n) allow-extra of a category holding expected skills: exit 2" "$rc" 2
vw --allow-extra ../x; eq "(n) allow-extra with '..': exit 2" "$rc" 2
fresh n3; mkx hq-index; printf 'k: %s\n' "$SECRET" >"$W/hq-index/notes.txt"; vw --allow-extra hq-index
eq "(n) secret inside an allowed extra: exit 1" "$rc" 1; has "(n) FAIL secrets" "$out" "FAIL secrets"; has "(n) names the extra file" "$out" "hq-index/notes.txt"; hasnt "(n) match not printed" "$out" "$SECRET"
fresh n4; mkx hq-index; mkdir "$TMP/outside"; printf 'k: %s\n' "$SECRET" >"$TMP/outside/s.txt"; ln -s "$TMP/outside" "$W/hq-index/link"; vw --allow-extra hq-index
eq "(n) symlink dir inside an allowed extra FAILs (N1)" "$rc" 1; has "(n) reported" "$out" "hq-index/link(symlink)"; hasnt "(n) linked secret not printed" "$out" "$SECRET"
hasnt "(n) nothing below the link is read or reported" "$out" "link/s.txt"; hasnt "(n) outside file not scanned (no secrets FAIL)" "$out" "FAIL secrets"
# (o) unsafe SKILL.md (M2)
fresh o1; cp "$(sk learnings/more-1)" "$TMP/outside/copy.md"; rm "$(sk learnings/more-1)"; ln -s "$TMP/outside/copy.md" "$(sk learnings/more-1)"; vw
eq "(o) symlinked SKILL.md (byte-identical): exit 1" "$rc" 1; has "(o) reported" "$out" "learnings/more-1(SKILL.md-symlink)"
fresh o2; rm "$(sk learnings/more-2)"; mkfifo "$(sk learnings/more-2)"
tvrun() { out="$(python3 -I -c 'import subprocess,sys;a=sys.argv[1:]
try:
    r=subprocess.run(a,capture_output=True,text=True,timeout=30,stdin=subprocess.DEVNULL);print(r.stdout+r.stderr);sys.exit(r.returncode)
except subprocess.TimeoutExpired:
    print("TIMEOUT");sys.exit(124)' env -u HERMES_HOME bash "$VER" "$@" 2>&1)"; rc=$?; }
tvrun "$W" --repo "$FX" --sha "$SHA"; eq "(o) FIFO named SKILL.md: exit 1 without hanging" "$rc" 1; has "(o) reported" "$out" "learnings/more-2(SKILL.md-not-regular-file)"
fresh o3; python3 -I -c 'import sys;open(sys.argv[1],"wb").write(b"x"*500000)' "$(sk learnings/more-3)"; vw
eq "(o) oversize SKILL.md: exit 1" "$rc" 1; has "(o) reported" "$out" "learnings/more-3(SKILL.md-oversize)"
fresh o4; rm -rf "$W/learnings/more-4"; ln -s "$W/learnings/more-5" "$W/learnings/more-4"; vw; has "(o) symlinked skill dir" "$out" "learnings/more-4(stray-symlink)"
# (p) layout and frontmatter strictness (M3)
fresh p1; mkdir "$W/learnings/more-1/scripts"; printf '#!/bin/sh\n' >"$W/learnings/more-1/scripts/e.sh"; chmod +x "$W/learnings/more-1/scripts/e.sh"; vw
eq "(p) extra file in a skill folder: exit 1" "$rc" 1; has "(p) reported" "$out" "learnings/more-1(extra-files:scripts)"
fresh p2; sub "$(sk learnings/more-2)" 's/^name: .*/&\
allowed-tools: Bash/'; vw; eq "(p) extra frontmatter key: exit 1" "$rc" 1; has "(p) reported" "$out" "learnings/more-2(frontmatter-keys:"
fresh p3; echo hi >"$W/stray.txt"; vw; eq "(p) stray root file: exit 1" "$rc" 1; has "(p) reported" "$out" "stray.txt(stray-file)"
fresh p4; mkdir "$W/emptycat"; vw; eq "(p) empty category dir: exit 1" "$rc" 1; has "(p) reported" "$out" "emptycat(empty-category)"
fresh p5; echo x >"$W/.SKILL.md.import-tmp"; vw; eq "(p) stale temp at root: exit 1" "$rc" 1; has "(p) reported" "$out" "(stale-import-tmp)"
fresh p6; echo x >"$W/learnings/more-3/.SKILL.md.import-tmp"; vw; eq "(p) stale temp in a skill folder: exit 1" "$rc" 1; has "(p) reported" "$out" "learnings/more-3(extra-files:.SKILL.md.import-tmp)"
# (q) description / name types (M4) and the catch-all
dset() { python3 -I -c 'import sys,re;p,v=sys.argv[1:];t=open(p).read();open(p,"w").write(re.sub(r"(?m)^description: .*$","description: "+v,t,count=1))' "$(sk "$1")" "$2"; }
fresh q1; dset learnings/more-1 '["a","b"]'; vw; eq "(q) list description: exit 1" "$rc" 1; has "(q) reported" "$out" "learnings/more-1(description-type:list)"
fresh q2; dset learnings/more-1 '5'; vw; eq "(q) int description: exit 1 (no crash)" "$rc" 1; has "(q) reported" "$out" "description-type:int"; hasnt "(q) no traceback" "$out" "Traceback"
fresh q3; dset learnings/more-1 '""'; vw; has "(q) empty description" "$out" "learnings/more-1(description-length)"
HARN="import sys;sys.path.insert(0,sys.argv[1]);import verify_import as v"
out="$(python3 -B -I -c "$HARN
def boom(*a): raise TypeError('boom')
v.expected_set=boom
sys.exit(v.main([sys.argv[2],'--repo',sys.argv[3],'--sha',sys.argv[4]]))" "$HERE" "$BASE" "$FX" "$SHA" 2>&1)"; rc=$?
eq "(q) unexpected exception: exit 2" "$rc" 2; has "(q) one-line error" "$out" "error: TypeError: boom"; hasnt "(q) no traceback" "$out" "Traceback"
# (r) importer-skipped inputs (M5) and --expect
FX2="$TMP/fx2"; git clone -q "$FX" "$FX2"; (cd "$FX2" && git config user.name t && git config user.email t@example.invalid
  printf '# Leaky\n\nk: %s\n' "$SECRET" >learnings/leaky.md; python3 -I -c 'print("# Big\n\n"+("word "*30000))' >learnings/big.md
  git add -A && git commit -qm skip2); SHA2="$(git -C "$FX2" rev-parse HEAD)"
B2="$TMP/base2"; env -u HERMES_HOME bash "$IMP" "$B2" --repo "$FX2" --sha "$SHA2" --apply >/dev/null 2>&1; eq "(r) setup: importer skips secret-shaped (7 beats 6)" "$?" 7
eq "(r) setup: importer still wrote $N skills" "$(find "$B2" -name SKILL.md | wc -l | tr -d ' ')" "$N"
vrun "$B2" --repo "$FX2" --sha "$SHA2"; eq "(r) short import is not PASS: exit 1" "$rc" 1
has "(r) FAIL expected" "$out" "FAIL expected: inputs=17 expected=$N skipped=2"; has "(r) names the secret-shaped input" "$out" "learnings/leaky.md(secret-shaped, importer exit 7)"
has "(r) names the oversize input" "$out" "learnings/big.md(oversize, importer exit 6)"; hasnt "(r) secret not printed" "$out" "$SECRET"
fresh r; vw --expect "$N"; eq "(r) --expect matching count: PASS" "$rc" 0
vw --expect 12; eq "(r) --expect mismatch: exit 1" "$rc" 1; has "(r) reported" "$out" "expected $N != --expect 12"
# (s) each check can fail on its own (kills the surviving mutations of the tester B report)
fresh s1; python3 -I -c 'import sys;p=sys.argv[1];t=open(p).read();open(p,"w").write(t[:t.index("\n\n---\n_Imported")]+"\n")' "$(sk learnings/more-1)"; vw
has "(s) footer removed -> no-footer" "$out" "learnings/more-1(no-footer)"
fresh s2; sub "$(sk learnings/more-2)" 's#Origin: `learnings/more-2.md@#Origin: `learnings/other.md@#'; vw; has "(s) footer path changed" "$out" "learnings/more-2(footer-path)"
fresh s3; sed 1d "$(sk learnings/more-3)" >"$TMP/x.n" && mv "$TMP/x.n" "$(sk learnings/more-3)"; vw; has "(s) frontmatter delimiter removed" "$out" "learnings/more-3(no-frontmatter)"
L65="$(printf 'a%.0s' $(seq 1 65))"; L64="$(printf 'b%.0s' $(seq 1 64))"
fresh s4; mv "$W/learnings/more-4" "$W/learnings/$L65"; sub "$W/learnings/$L65/SKILL.md" "s/^name: .*/name: $L65/"; vw; has "(s) 65-char name invalid" "$out" "learnings/$L65(name-invalid)"
fresh s5; mv "$W/learnings/more-5" "$W/learnings/$L64"; sub "$W/learnings/$L64/SKILL.md" "s/^name: .*/name: $L64/"; vw; hasnt "(s) 64-char name is not name-invalid" "$out" "(name-invalid)"
fresh s6; sub "$(sk learnings/alpha-lesson)" 's/\*\*Context:\*\* the alpha thing broke/**Context:** the alpha thing BROKE/'; vw --spot 99 --seed 1; has "(s) spot read-back catches the edited body" "$out" "FAIL spot"
fresh s7; vw --spot 4 --seed 1; a1="$(smp)"; vw --spot 4 --seed 2; a2="$(smp)"; vw --spot 4 --seed 3; a3="$(smp)"; vw --spot 4 --seed 4; a4="$(smp)"
eq "(s) four seeds give more than one distinct sample" "$([ "$a1" = "$a2" ] && [ "$a2" = "$a3" ] && [ "$a3" = "$a4" ] && echo same || echo varied)" varied
out="$(python3 -B -I -c "$HARN
orig=v.expected_set
def touch(*a):
    r=orig(*a); open(sys.argv[2]+'/learnings/touched','w').write('x'); return r
v.expected_set=touch
sys.exit(v.main([sys.argv[2],'--repo',sys.argv[3],'--sha',sys.argv[4],'--allow-extra','learnings/touched']))" "$HERE" "$W" "$FX" "$SHA" 2>&1)"; rc=$?
has "(s) in-run read-only self-check fires when the target changes" "$out" "FAIL readonly: find+stat digest"; eq "(s) ... and the run fails" "$rc" 1
# unresolved target refusal: '..' segments and relative paths into the fake live home
export HERMES_IMPORT_TEST_LIVE_HOME="$TMP/fakelive/hermes/h1-home"
vrun "$HERMES_IMPORT_TEST_LIVE_HOME/skills/../skills" --repo "$FX" --sha "$SHA"; eq "(s) '..' path into h1-home refused" "$rc" 3
out="$(cd "$HERMES_IMPORT_TEST_LIVE_HOME" && env -u HERMES_HOME bash "$VER" skills --repo "$FX" --sha "$SHA" 2>&1)"; eq "(s) relative path into h1-home refused" "$?" 3
out="$(cd "$HERMES_IMPORT_TEST_LIVE_HOME/skills" && env -u HERMES_HOME bash "$VER" . --repo "$FX" --sha "$SHA" 2>&1)"; eq "(s) '.' inside h1-home refused" "$?" 3
unset HERMES_IMPORT_TEST_LIVE_HOME
# (u) N1: symlinks at or under an allowed extra FAIL; (a) exact matching; (b) absent entry
OUT2="$TMP/outside2"; mkdir -p "$OUT2/d"; cp "$(sk learnings/more-1)" "$OUT2/d/SKILL.md" 2>/dev/null || cp "$BASE/learnings/more-1/SKILL.md" "$OUT2/d/SKILL.md"
fresh u1; ln -s "$OUT2/d" "$W/hq-index"; vw --allow-extra hq-index; eq "(u) allowed extra that is a symlink to an outside dir: FAIL" "$rc" 1; has "(u) reported" "$out" "hq-index(symlink)"
fresh u2; ln -s "$OUT2/d/SKILL.md" "$W/hq-index"; vw --allow-extra hq-index; eq "(u) allowed extra that is a symlink to a file: FAIL" "$rc" 1; has "(u) reported" "$out" "hq-index(symlink)"
fresh u3; ln -s "$W/learnings/more-1" "$W/hq-index"; vw --allow-extra hq-index; eq "(u) allowed extra symlinked to an expected skill: FAIL" "$rc" 1
fresh u4; mkdir "$W/hq-index"; ln -s "$OUT2/d/SKILL.md" "$W/hq-index/SKILL.md"; vw --allow-extra hq-index; eq "(u) symlinked SKILL.md inside an allowed extra: FAIL" "$rc" 1; has "(u) reported" "$out" "hq-index/SKILL.md(symlink)"
fresh u5; ln -s "$OUT2" "$W/par"; vw --allow-extra par; eq "(u) allowed extra naming a symlinked parent: FAIL" "$rc" 1; has "(u) reported" "$out" "par(symlink)"
fresh u6; ln -s "$OUT2" "$W/par"; vw --allow-extra par/d; eq "(u) allow-extra BELOW a symlinked parent: FAIL" "$rc" 1; has "(u) reported" "$out" "par/d(symlinked-parent)"
fresh u7; mkx hq-index; mkx hq-index-evil; vw --allow-extra hq-index; eq "(u) sibling hq-index-evil next to --allow-extra hq-index: FAIL (exact match)" "$rc" 1; has "(u) sibling named" "$out" "hq-index-evil"
fresh u8; mkx .archive-evil; vw --allow-extra .archive; eq "(u) .archive-evil next to --allow-extra .archive: FAIL" "$rc" 1
fresh u9; vw --allow-extra hq-index; has "(u) absent entry says so" "$out" "ALLOWED extra: hq-index (not present)"; eq "(u) absent entry is not an error" "$rc" 0
# (v) N2: the description line must be what render() writes
dsetraw() { python3 -I -c 'import sys,re;p,v=sys.argv[1:];t=open(p).read();open(p,"w").write(re.sub(r"(?m)^description: .*$",lambda m:"description: "+v,t,count=1))' "$(sk "$1")" "$2"; }
i=0; for v in '{a: 1}' '"unterminated' '[a, b]' 'hello world'; do i=$((i+1)); fresh v$i; dsetraw learnings/more-1 "$v"; vw
  eq "(v) non-JSON description '$v': exit 1" "$rc" 1; has "(v) '$v' reported" "$out" "learnings/more-1(description-not-json)"; done
fresh v5; dsetraw learnings/more-1 '"a different but valid description"'; vw; eq "(v) hand-edited valid-JSON description: exit 1" "$rc" 1; has "(v) reported" "$out" "learnings/more-1(description-mismatch)"
fresh v6; mkx hq-index; sub "$W/hq-index/SKILL.md" 's/^description: .*/description: hello world/'; vw --allow-extra hq-index; eq "(v) allowed extras are exempt from the description rule" "$rc" 0
# (w) shim: -I isolation, symlink invocation, read cap memory, digest does not follow symlinks
PL="$TMP/planted"; mkdir -p "$PL/pp"; printf 'raise SystemExit(99)\n' >"$PL/json.py"; cp "$PL/json.py" "$PL/pp/json.py"; fresh w1
out="$(cd "$PL" && env -u HERMES_HOME PYTHONPATH="$PL/pp" bash "$VER" "$W" --repo "$FX" --sha "$SHA" 2>&1)"; eq "(w) planted json.py in cwd and PYTHONPATH ignored (-I): exit 0" "$?" 0
ln -s "$VER" "$TMP/verlink"; out="$(env -u HERMES_HOME bash "$TMP/verlink" "$W" --repo "$FX" --sha "$SHA" 2>&1)"; eq "(w) shim invoked through a symlink works" "$?" 0; has "(w) ... and PASSes" "$out" "verify-import: PASS"
fresh w2; rm "$(sk learnings/more-3)"; truncate -s 600M "$(sk learnings/more-3)"
rss="$(python3 -B -I -c "$HARN
import resource,io,contextlib
with contextlib.redirect_stdout(io.StringIO()): rc=v.main([sys.argv[2],'--repo',sys.argv[3],'--sha',sys.argv[4]])
print(rc, resource.getrusage(resource.RUSAGE_SELF).ru_maxrss)" "$HERE" "$W" "$FX" "$SHA" 2>&1)"
eq "(w) 600MB SKILL.md: exit 1" "${rss%% *}" 1; [ "${rss##* }" -lt 200000000 ] 2>/dev/null && ok "(w) peak memory under 200MB (read is capped)" || nok "(w) peak memory under 200MB (got '$rss')"
fresh w3; mkx hq-index; mkdir -p "$TMP/outside3"; echo a >"$TMP/outside3/f"; ln -s "$TMP/outside3" "$W/hq-index/link"
out="$(python3 -B -I -c "$HARN
orig=v.expected_set
def touch(*a):
    r=orig(*a); open('$TMP/outside3/f','w').write('changed longer'); return r
v.expected_set=touch
sys.exit(v.main([sys.argv[2],'--repo',sys.argv[3],'--sha',sys.argv[4],'--allow-extra','hq-index']))" "$HERE" "$W" "$FX" "$SHA" 2>&1)"
has "(w) tree digest does not follow symlinks (outside change ignored)" "$out" "PASS readonly"
# (x) T-498c: null description, deeper symlinked parent, extra file next to SKILL.md, exact description compare, two-level extra
fresh v7; dsetraw learnings/more-1 'null'; vw; eq "(v) JSON null description: exit 1" "$rc" 1; has "(v) reported as NoneType" "$out" "learnings/more-1(description-type:NoneType)"
fresh x1; mkdir -p "$TMP/outside4/x/y"; cp "$OUT2/d/SKILL.md" "$TMP/outside4/x/y/SKILL.md"; ln -s "$TMP/outside4" "$W/par"; vw --allow-extra par/x/y
eq "(x) allow-extra par/x/y below a symlinked grandparent: FAIL" "$rc" 1; has "(x) reported" "$out" "par/x/y(symlinked-parent)"
fresh x2; ln -s "$OUT2/d/SKILL.md" "$W/learnings/more-1/link"; vw; eq "(x) symlink next to SKILL.md in an expected skill: FAIL" "$rc" 1; has "(x) reported" "$out" "learnings/more-1(extra-files:link)"
fresh x3; python3 -I -c 'import sys;p=sys.argv[1];L=open(p).read().split("\n");i=[k for k,l in enumerate(L) if l.startswith("description: ")][0];L[i]="description: "+L[i][13:].swapcase();open(p,"w").write("\n".join(L))' "$(sk learnings/more-1)"; vw
eq "(x) case-only change of the description: exit 1" "$rc" 1; has "(x) reported" "$out" "learnings/more-1(description-mismatch)"
fresh x4; python3 -I -c 'import sys;p=sys.argv[1];L=open(p).read().split("\n");i=[k for k,l in enumerate(L) if l.startswith("description: ")][0];L[i]=L[i]+" ";open(p,"w").write("\n".join(L))' "$(sk learnings/more-1)"; vw
eq "(x) trailing space on the description line: exit 1" "$rc" 1; has "(x) reported" "$out" "learnings/more-1(description-mismatch)"
fresh x5; mkdir "$W/learnings/stash"; echo "plain notes" >"$W/learnings/stash/notes.txt"; vw
eq "(x) two-level dir without --allow-extra: FAIL" "$rc" 1; has "(x) reported" "$out" "learnings/stash(no-SKILL.md)"
vw --allow-extra learnings/stash; eq "(x) two-level allowed extra (no SKILL.md): PASS" "$rc" 0; has "(x) listed" "$out" "ALLOWED extra: learnings/stash"; has "(x) no skill counted" "$out" "allowed=0"
printf 'k: %s\n' "$SECRET" >"$W/learnings/stash/leak.txt"; vw --allow-extra learnings/stash; eq "(x) secret in a two-level allowed extra: FAIL" "$rc" 1; has "(x) names the file" "$out" "learnings/stash/leak.txt"
fresh x6; vw --allow-extra learnings/alpha-lesson/sub; eq "(x) allow-extra BELOW an expected skill: exit 2" "$rc" 2; has "(x) names the overlap" "$out" "expected skill learnings/alpha-lesson"
# (t) the shim writes no bytecode (copy of the tools so the check is not polluted by other runs)
mkdir "$TMP/hcopy"; cp "$HERE"/*.py "$HERE/verify-import" "$TMP/hcopy/"; fresh t; env -u HERMES_HOME bash "$TMP/hcopy/verify-import" "$W" --repo "$FX" --sha "$SHA" >/dev/null 2>&1
find "$TMP/hcopy" -name __pycache__ | grep -q . && nok "(t) no __pycache__ after a run" || ok "(t) no __pycache__ after a run"
echo "# passed=$passed failed=$failed"; [ "$failed" -eq 0 ]
