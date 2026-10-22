#!/usr/bin/env bash
# tools/hermes/test_import-learnings.sh — tests for import-learnings (T-470 row 5, Rule 10).
# Scratch under /private/tmp only; the live-home tests use a FAKE h1-home via HERMES_IMPORT_TEST_LIVE_HOME;
# nothing here touches the real Hermes home, a token, or the network.
set -uo pipefail
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null LC_ALL=C
unset HERMES_HOME HERMES_IMPORT_TEST_LIVE_HOME HQ_REPO GIT_DIR GIT_WORK_TREE   # hermetic: tests set these explicitly
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMP="$HERE/import-learnings"
REAL_REPO="$(cd "$HERE/../.." && pwd)"
PIN=c7e2d56164f790d959b2eab563aabbe4d3b5cab7   # hq commit used for the real-repo trial
TMP="$(mktemp -d /private/tmp/il-test.XXXXXX)"; trap 'chmod -R u+w "$TMP" 2>/dev/null; rm -rf "$TMP"' EXIT
passed=0; failed=0; skipped=0
ok() { echo "ok - $1"; passed=$((passed + 1)); }
skip() { echo "SKIP - $1"; skipped=$((skipped + 1)); }
nok() { echo "not ok - $1"; failed=$((failed + 1)); }
eq() { if [ "$2" = "$3" ]; then ok "$1"; else nok "$1 (got '$2', want '$3')"; fi; }
has() { case "$2" in *"$3"*) ok "$1" ;; *) nok "$1 (no '$3' in: $2)" ;; esac; }

# fixture repo
FX="$TMP/fx"; mkdir -p "$FX/learnings/topic" "$FX/retros"; cd "$FX" || exit 1
git init -q -b main . && git config user.name t && git config user.email t@example.invalid
printf '# Readme\nx\n' >learnings/README.md; printf '# Method\nx\n' >learnings/METHODOLOGY.md
printf '### Alpha lesson   <!-- 2026-01-02 -->\n\n**Context:** the alpha thing broke.\n\n## Fix\n\nDo `x`.\n' >learnings/alpha-lesson.md
printf '# Beta topic lesson\n\nBeta body text.\n' >learnings/topic/2026-03-04-beta.md
printf '# Retro — gamma  <!-- 2026-05-06 -->\n\n- **Period:** may\n' >retros/2026-05-06-gamma.md
head -c 120000 /dev/zero | tr '\0' 'a' | sed 's/^/# Big\n\n/' >retros/big.md
printf 'not md\n' >learnings/notes.txt
printf '# Retro readme\nx\n' >retros/README.md; printf '# Template\nx\n' >retros/_TEMPLATE.md
git add -A && git commit -qm fx; SHA="$(git rev-parse HEAD)"; cd "$TMP" || exit 1
run() { HQ_REPO="$FX" "$IMP" "$@"; }

# dry run writes nothing; outputs plan
S1="$TMP/s1"; out="$(run "$S1" --sha "$SHA" 2>&1)"; rc=$?
eq "dry run: exit 6 (oversize reported)" "$rc" 6
has "dry run: plan lists alpha" "$out" "learnings/alpha-lesson"
[ ! -e "$S1" ] && ok "dry run: target not created" || nok "dry run: target created"
has "oversize reported" "$out" "OVERSIZE	retros/big.md"

# apply + layout
run "$S1" --sha "$SHA" --apply >/dev/null 2>&1; rc=$?; eq "apply: exit 6 (oversize only)" "$rc" 6
[ -f "$S1/learnings/alpha-lesson/SKILL.md" ] && ok "category=learnings layout" || nok "alpha layout"
[ -f "$S1/topic/2026-03-04-beta/SKILL.md" ] && ok "topic folder is the category" || nok "topic layout"
[ -f "$S1/retros/2026-05-06-gamma/SKILL.md" ] && ok "retros category" || nok "retro layout"
[ ! -e "$S1/retros/big" ] && ok "oversize not written (not truncated)" || nok "oversize written"
# (e) every .md imported (no exclusions); non-md + oversize not imported
n="$(find "$S1" -name SKILL.md | wc -l | tr -d ' ')"; eq "all .md imported, non-md + oversize not (7 skills)" "$n" 7
[ -f "$S1/learnings/learnings-readme/SKILL.md" ] && [ -f "$S1/learnings/learnings-methodology/SKILL.md" ] && ok "README/METHODOLOGY present under prefixed names" || nok "README/METHODOLOGY missing"
[ ! -e "$S1/learnings/readme" ] && [ ! -e "$S1/learnings/methodology" ] && ok "no bare readme/methodology skill" || nok "bare names present"
A="$S1/learnings/alpha-lesson/SKILL.md"
desc="$(grep '^description:' "$A")"
case "$desc" in 'description: "Alpha lesson. '*) ok "description starts with the title (routing text first)" ;; *) nok "description start: $desc" ;; esac
case "${desc:14:57}" in *"Learning ("*|*"learnings,"*) nok "kind/category/date inside the first 57 chars" ;; *) ok "first 57 chars carry no kind/category/date prefix" ;; esac
has "description keeps the use-when sentence" "$desc" "Use when the task touches:"
has "kind/category/date moved to the end" "$desc" '(Learning, learnings, 2026-01-02)"'
[ -f "$S1/retros/retros-readme/SKILL.md" ] && [ -f "$S1/retros/retros-template/SKILL.md" ] && ok "L5: retros README/_TEMPLATE present as retros-readme/retros-template" || nok "L5 retros generic skills missing"
[ ! -e "$S1/retros/readme" ] && [ ! -e "$S1/retros/template" ] && ok "L5: no bare retros readme/template" || nok "L5 bare names present"
# name rule: both READMEs import without collision under distinct names; a non-listed file keeps its name
for nm in learnings/learnings-readme retros/retros-readme; do
  grep -q "^name: ${nm#*/}$" "$S1/$nm/SKILL.md" && ok "name rule: $nm front matter name" || nok "name rule: $nm front matter"
done
eq "name rule: two READMEs, distinct names, exit 6 not 1 (no collision)" "$(printf '%s\n' "$out" | grep -c 'collision')" 0
[ -f "$S1/learnings/alpha-lesson/SKILL.md" ] && [ -f "$S1/retros/2026-05-06-gamma/SKILL.md" ] && ok "name rule: non-listed files keep their name" || nok "name rule: non-listed renamed"
has "footer: date" "$(tail -2 "$A")" "Date: 2026-01-02"
has "footer: path@sha" "$(tail -2 "$A")" "learnings/alpha-lesson.md@$SHA"
has "body unchanged (original text present)" "$(cat "$A")" "**Context:** the alpha thing broke."
! grep -rq 'created_by' "$S1" && ok "no created_by anywhere" || nok "created_by present"

# (d) idempotent
h1="$(cd "$S1" && find . -name SKILL.md -exec shasum {} + | sort | shasum)"
out="$(run "$S1" --sha "$SHA" --apply 2>&1)"
h2="$(cd "$S1" && find . -name SKILL.md -exec shasum {} + | sort | shasum)"
eq "idempotent: hashes unchanged" "$h1" "$h2"; has "idempotent: unchanged=7 new=0" "$out" "new=0 unchanged=7"
eq "idempotent: no duplicate dirs" "$(find "$S1" -name SKILL.md | wc -l | tr -d ' ')" 7

# --limit / --files
S2="$TMP/s2"; run "$S2" --sha "$SHA" --limit 1 --apply >/dev/null 2>&1
eq "--limit 1" "$(find "$S2" -name SKILL.md | wc -l | tr -d ' ')" 1
S3="$TMP/s3"; out="$(run "$S3" --sha "$SHA" --files learnings/alpha-lesson.md learnings/notes.txt --apply 2>&1)"
eq "--files: only alpha" "$(find "$S3" -name SKILL.md | wc -l | tr -d ' ')" 1; has "--files: non-input skipped" "$out" "skip (not an input): learnings/notes.txt"
run "$TMP/abbr" --sha "$SHA" --i-am >/dev/null 2>&1; eq "L2: --i-am abbreviation rejected (usage exit 2)" "$?" 2
run >/dev/null 2>&1; eq "target is required (usage exit 2)" "$?" 2

# live-home refusal (FAKE h1-home)
export HERMES_IMPORT_TEST_LIVE_HOME="$TMP/fakeroot/hermes/h1-home"
mkdir -p "$HERMES_IMPORT_TEST_LIVE_HOME/skills"; ln -s "$HERMES_IMPORT_TEST_LIVE_HOME" "$TMP/link-to-live"
before="$(find "$HERMES_IMPORT_TEST_LIVE_HOME" | sort | shasum)"
run "$TMP/link-to-live/skills" --sha "$SHA" --apply >/dev/null 2>"$TMP/err"; eq "(a) symlink to h1-home refused: exit 3" "$?" 3
has "(a) message" "$(cat "$TMP/err")" "REFUSED"
has "(a) refused by the FIRST target check (not masked by the output check)" "$(cat "$TMP/err")" "target resolves into"
run "$HERMES_IMPORT_TEST_LIVE_HOME" --sha "$SHA" --apply >/dev/null 2>&1; eq "direct h1-home refused" "$?" 3
run "$TMP/link-to-live/nope/deeper" --sha "$SHA" --apply >/dev/null 2>&1; eq "nonexistent subpath via symlink refused" "$?" 3
run "$TMP/link-to-live" --sha "$SHA" >/dev/null 2>&1; eq "dry run also refused" "$?" 3
HERMES_HOME="$HERMES_IMPORT_TEST_LIVE_HOME" run "$TMP/scratch-ok" --sha "$SHA" --apply >/dev/null 2>&1
eq "(b) HERMES_HOME=h1-home with fine target refused" "$?" 3
[ ! -e "$TMP/scratch-ok" ] && ok "(b) nothing written" || nok "(b) wrote target"
HERMES_HOME="$TMP/link-to-live" run "$TMP/scratch-ok" --sha "$SHA" --apply >/dev/null 2>&1
eq "(b) HERMES_HOME symlink to h1-home refused" "$?" 3
HERMES_HOME="$TMP/other-home" run "$TMP/link-to-live/x" --sha "$SHA" --apply >/dev/null 2>&1
eq "(b) HERMES_HOME elsewhere but target in h1-home refused" "$?" 3
run "$TMP/fakeroot/hermes" --sha "$SHA" --apply >/dev/null 2>&1; eq "L4: parent of h1-home refused" "$?" 3
HERMES_HOME="$TMP/other-home" run "$TMP/fakeroot" --sha "$SHA" >/dev/null 2>&1; eq "L4: grandparent refused" "$?" 3
RLIVE="$(python3 -I -c 'import pwd,os;print(os.path.realpath(pwd.getpwuid(os.getuid()).pw_dir+"/claude-profiles/hermes/h1-home"))')"
run "$RLIVE/skills" --sha "$SHA" >/dev/null 2>&1; eq "L1: real h1-home refused although the test override is set (dry run)" "$?" 3
run "$(dirname "$RLIVE")" --sha "$SHA" >/dev/null 2>&1; eq "L4: real parent of h1-home refused (dry run)" "$?" 3
# L6: target outside live, but a category dir is a symlink into live -> the output-path check must refuse
mkdir -p "$TMP/t6" "$HERMES_IMPORT_TEST_LIVE_HOME/skills"; ln -s "$HERMES_IMPORT_TEST_LIVE_HOME/skills" "$TMP/t6/learnings"
before="$(find "$HERMES_IMPORT_TEST_LIVE_HOME" | sort | shasum)"
run "$TMP/t6" --sha "$SHA" --apply >/dev/null 2>"$TMP/err6"; eq "L6: output through symlinked category into h1-home refused" "$?" 3
eq "L6: live dir still untouched" "$(find "$HERMES_IMPORT_TEST_LIVE_HOME" | sort | shasum)" "$before"
eq "live dir untouched" "$(find "$HERMES_IMPORT_TEST_LIVE_HOME" | sort | shasum)" "$before"
HERMES_HOME="$TMP/other-home" run "$TMP/s4" --sha "$SHA" --apply >/dev/null 2>&1; rc=$?
eq "(c) scratch target with unrelated HERMES_HOME works (exit 6 oversize)" "$rc" 6
[ -f "$TMP/s4/learnings/alpha-lesson/SKILL.md" ] && ok "(c) written" || nok "(c) not written"
[ ! -e "$TMP/other-home" ] && ok "script never defaults to/uses HERMES_HOME" || nok "HERMES_HOME created"
run "$HERMES_IMPORT_TEST_LIVE_HOME/s5" --sha "$SHA" --limit 1 --apply --i-am-the-owner-live >/dev/null 2>&1
eq "owner flag allows (fake) live home" "$?" 0
unset HERMES_IMPORT_TEST_LIVE_HOME
eq "production default is the real h1-home path" "$(run x --show-live-home)" "$(python3 -I -c 'import pwd,os;print(os.path.realpath(pwd.getpwuid(os.getuid()).pw_dir+"/claude-profiles/hermes/h1-home"))')"
HERMES_HOME="$RLIVE" run "$TMP/s6" --sha "$SHA" >/dev/null 2>&1
eq "production default refuses HERMES_HOME=real h1-home (dry run, no write)" "$?" 3

# M1: parent-of-h1-home bypasses (all fake paths); M3: HOME override; M5: overwrite provenance
export HERMES_IMPORT_TEST_LIVE_HOME="$TMP/fh/hermes/h1-home"; mkdir -p "$HERMES_IMPORT_TEST_LIVE_HOME"; ln -s "$TMP/fh/hermes" "$TMP/par-link"
run "$HERMES_IMPORT_TEST_LIVE_HOME/.." --sha "$SHA" --apply >/dev/null 2>&1; eq "M1: h1-home/.. refused" "$?" 3
(cd "$TMP/fh/hermes" && run . --sha "$SHA" --apply >/dev/null 2>&1); eq "M1: '.' inside the parent refused" "$?" 3
(cd "$TMP/fh/hermes" && run .. --sha "$SHA" --apply >/dev/null 2>&1); eq "M1: '..' from the parent refused" "$?" 3
run "$TMP/par-link" --sha "$SHA" --apply >/dev/null 2>&1; eq "M1: symlink to the parent refused" "$?" 3
[ -z "$(ls "$TMP/fh/hermes")" ] || [ "$(ls "$TMP/fh/hermes")" = "h1-home" ] && ok "M1: nothing written beside h1-home" || nok "M1: wrote beside h1-home"
run "$TMP/fh/hermes/sibling" --sha "$SHA" --files learnings/alpha-lesson.md --apply >/dev/null 2>&1; eq "M1: a sibling of h1-home is allowed" "$?" 0
RLIVE="$(python3 -I -c 'import pwd,os;print(os.path.realpath(pwd.getpwuid(os.getuid()).pw_dir+"/claude-profiles/hermes/h1-home"))')"
HOME="$TMP/other-home-dir" run "$RLIVE/skills" --sha "$SHA" >/dev/null 2>&1; eq "M3: HOME overridden, real h1-home still refused (dry run)" "$?" 3
T5="$TMP/t5"; mkdir -p "$T5/learnings/alpha-lesson"; echo "hand written" >"$T5/learnings/alpha-lesson/SKILL.md"
run "$T5" --sha "$SHA" --files learnings/alpha-lesson.md learnings/topic/2026-03-04-beta.md --apply >/dev/null 2>"$TMP/e5"; eq "M5: hand-written SKILL.md refused: exit 4" "$?" 4
eq "M5: left byte-identical" "$(cat "$T5/learnings/alpha-lesson/SKILL.md")" "hand written"
has "M5: path printed" "$(cat "$TMP/e5")" "alpha-lesson/SKILL.md"
[ ! -e "$T5/topic" ] && ok "M5: nothing else written (all-or-nothing)" || nok "M5: partial write"
run "$TMP/s1" --sha "$SHA" --files learnings/alpha-lesson.md --apply >/dev/null 2>&1
sed -i.bak 's/the alpha thing broke/EDITED/' "$TMP/s1/learnings/alpha-lesson/SKILL.md"; rm "$TMP/s1/learnings/alpha-lesson/SKILL.md.bak"
out="$(run "$TMP/s1" --sha "$SHA" --files learnings/alpha-lesson.md --apply 2>&1)"; has "M5: imported file (with footer) is updated" "$out" "update=1"
has "M5: restored" "$(cat "$TMP/s1/learnings/alpha-lesson/SKILL.md")" "the alpha thing broke"
# M4: identifiers keep their underscores
q="$(python3 -I -c "import sys;sys.path.insert(0,'$HERE');from il_describe import clean;print(clean('see skill_manager_tool and HERMES_HOME and _emph_ text'))")"
eq "M4: underscores inside identifiers kept, emphasis stripped" "$q" "see skill_manager_tool and HERMES_HOME and emph text"
unset HERMES_IMPORT_TEST_LIVE_HOME
# name collisions: in one batch, and against an existing skill in another category
FX4="$TMP/fx4"; mkdir -p "$FX4/learnings" "$FX4/retros"; git -C "$TMP" init -q -b main "$FX4"
printf '# Dup l\nx\n' >"$FX4/learnings/dup.md"; printf '# Dup r\nx\n' >"$FX4/retros/dup.md"
git -C "$FX4" add -A; git -C "$FX4" -c user.name=t -c user.email=t@example.invalid commit -qm d; SHA4="$(git -C "$FX4" rev-parse HEAD)"
HQ_REPO="$FX4" "$IMP" "$TMP/s8" --sha "$SHA4" --apply >/dev/null 2>"$TMP/e8"; eq "collision in one batch: exit 1" "$?" 1; has "collision message" "$(cat "$TMP/e8")" "name collision"
[ ! -e "$TMP/s8" ] && ok "collision: nothing written" || nok "collision wrote"
mkdir -p "$TMP/s9/otherecat/alpha-lesson"; echo x >"$TMP/s9/otherecat/alpha-lesson/SKILL.md"
run "$TMP/s9" --sha "$SHA" --files learnings/alpha-lesson.md --apply >/dev/null 2>&1; eq "collision across batches (existing skill, other category): exit 1" "$?" 1
# hostile paths (A4): the prefix map is exact and case-sensitive; readme.md, _template.md and Readme.md are NOT the four listed files and must stay unprefixed
for hp in learnings/readme.md:learnings:readme retros/_template.md:retros:template retros/Readme.md:retros:readme; do
  hpath="${hp%%:*}"; hrest="${hp#*:}"; hcat="${hrest%%:*}"; hnm="${hrest#*:}"; hfx="$TMP/hfx-$hnm-$hcat"
  mkdir -p "$hfx/learnings" "$hfx/retros"; git -C "$TMP" init -q -b main "$hfx"
  printf '# Hostile\nx\n' >"$hfx/$hpath"; git -C "$hfx" add -A
  git -C "$hfx" -c user.name=t -c user.email=t@example.invalid commit -qm h; hsha="$(git -C "$hfx" rev-parse HEAD)"
  HQ_REPO="$hfx" "$IMP" "$TMP/hs-$hnm-$hcat" --sha "$hsha" --apply >/dev/null 2>&1; eq "hostile $hpath: exit 0" "$?" 0
  [ -f "$TMP/hs-$hnm-$hcat/$hcat/$hnm/SKILL.md" ] && ok "hostile $hpath: unprefixed name $hnm" || nok "hostile $hpath: not imported as $hcat/$hnm"
  [ ! -e "$TMP/hs-$hnm-$hcat/$hcat/$hcat-$hnm" ] && ok "hostile $hpath: never prefixed" || nok "hostile $hpath: prefixed"
done
# secrets: token-shaped content refused (built from split parts at runtime); bare prefix mention is fine
FX5="$TMP/fx5"; mkdir -p "$FX5/learnings"; git -C "$TMP" init -q -b main "$FX5"
tk="sk-ant""-api03-""abcdefghijklmnop1234567890"; printf '# Leak\nkey %s here\n' "$tk" >"$FX5/learnings/leak.md"
printf '# Ok\nprefixes like sk-ant- and ghp_ are mentioned only\n' >"$FX5/learnings/ok.md"
git -C "$FX5" add -A; git -C "$FX5" -c user.name=t -c user.email=t@example.invalid commit -qm s; SHA5="$(git -C "$FX5" rev-parse HEAD)"
HQ_REPO="$FX5" "$IMP" "$TMP/s10" --sha "$SHA5" --apply >"$TMP/o10" 2>&1; eq "secret-shaped file: exit 7 at the end" "$?" 7
[ -f "$TMP/s10/learnings/ok/SKILL.md" ] && [ ! -e "$TMP/s10/learnings/leak" ] && ok "secret: leak refused, other file imported" || nok "secret handling"
case "$(cat "$TMP/o10")" in *abcdefghijklmnop*) nok "secret value printed" ;; *) ok "secret value never printed" ;; esac

# T-488 lows: shim via symlink, rollback/cleanup, O_NOFOLLOW, case variants, GIT_DIR isolation, file mode
ALL3="learnings/alpha-lesson.md learnings/topic/2026-03-04-beta.md retros/2026-05-06-gamma.md"
ln -s "$IMP" "$TMP/imp-link"; HQ_REPO="$FX" "$TMP/imp-link" "$TMP/sl" --sha "$SHA" --files learnings/alpha-lesson.md >/dev/null 2>&1
eq "T488-1: shim run through a symlink works (dry run rc 0)" "$?" 0
T2="$TMP/t2"; mkdir -p "$T2/retros"; chmod 555 "$T2/retros"
run "$T2" --sha "$SHA" --files $ALL3 --apply >/dev/null 2>"$TMP/e-t2"; rc=$?; chmod 755 "$T2/retros"
eq "T488-2: failed write exits 1" "$rc" 1
eq "T488-2: no temp file left anywhere" "$(find "$T2" -name '.SKILL.md.import-tmp*' | wc -l | tr -d ' ')" 0
[ ! -e "$T2/learnings" ] && [ ! -e "$T2/topic" ] && ok "T488-5: directories created by the failed run removed" || nok "T488-5: stray dirs"
export HERMES_IMPORT_TEST_LIVE_HOME="$TMP/fh2/hermes/h1-home"; mkdir -p "$HERMES_IMPORT_TEST_LIVE_HOME"
UP="$(printf %s "$HERMES_IMPORT_TEST_LIVE_HOME/skills" | tr a-z A-Z)"
if [ -d "$(dirname "$UP")" ]; then run "$UP" --sha "$SHA" >/dev/null 2>&1; eq "T488-3: case-variant path of h1-home refused" "$?" 3
else skip "T488-3: case-sensitive filesystem, case-variant test not applicable"; fi
unset HERMES_IMPORT_TEST_LIVE_HOME
T4="$TMP/t4"; mkdir -p "$T4/learnings/alpha-lesson"; echo victim >"$TMP/victim"; ln -s "$TMP/victim" "$T4/learnings/alpha-lesson/.SKILL.md.import-tmp"
run "$T4" --sha "$SHA" --files $ALL3 --apply >/dev/null 2>&1; eq "T488-4: planted symlink at the temp name: rc 1" "$?" 1
eq "T488-4: symlink target untouched" "$(cat "$TMP/victim")" victim
T5="$TMP/t5r"; mkdir -p "$T5/topic/2026-03-04-beta/SKILL.md"   # second rename fails: SKILL.md is a directory
run "$T5" --sha "$SHA" --files $ALL3 --apply >/dev/null 2>"$TMP/e-t5"; eq "T488-5: rename failure exits 1" "$?" 1
[ ! -e "$T5/learnings" ] && ok "T488-5: first (already renamed) file rolled back, its dirs removed" || nok "T488-5: not rolled back"
has "T488-5: report names the files already renamed" "$(cat "$TMP/e-t5")" "already renamed before the failure: ['"
has "T488-5: rollback status reported" "$(cat "$TMP/e-t5")" "rollback complete"
[ -d "$T5/topic/2026-03-04-beta/SKILL.md" ] && ok "T488-5: pre-existing directory kept" || nok "T488-5: pre-existing dir lost"
git init -q -b main "$TMP/decoy"; GIT_DIR="$TMP/decoy/.git" GIT_WORK_TREE="$TMP/decoy" run "$TMP/gd" --sha "$SHA" --files learnings/alpha-lesson.md >/dev/null 2>&1
eq "T488-7: GIT_DIR pointing at a decoy repo does not redirect the reader" "$?" 0
[ ! -x "$HERE/import_learnings.py" ] && ok "T488-8: import_learnings.py stays mode 644 (shim 755 starts it)" || nok "T488-8: mode changed"

# T-490: pre-existing temp name is never deleted; symlink outputs refused; rollback-incomplete and non-OSError paths
A1="--files learnings/alpha-lesson.md --apply"
T6="$TMP/p1"; mkdir -p "$T6/learnings/alpha-lesson"; echo precious >"$T6/learnings/alpha-lesson/.SKILL.md.import-tmp"
run "$T6" --sha "$SHA" $A1 >/dev/null 2>&1; r1=$?; run "$T6" --sha "$SHA" $A1 >/dev/null 2>&1; r2=$?
eq "T490-1: stale temp file: rc 1 on both runs" "$r1$r2" 11
eq "T490-1: stale temp file byte-identical" "$(cat "$T6/learnings/alpha-lesson/.SKILL.md.import-tmp")" precious
T6b="$TMP/p1b"; mkdir -p "$T6b/learnings/alpha-lesson"; echo victim2 >"$TMP/victim2"; ln -s "$TMP/victim2" "$T6b/learnings/alpha-lesson/.SKILL.md.import-tmp"
run "$T6b" --sha "$SHA" $A1 >/dev/null 2>&1; r1=$?; run "$T6b" --sha "$SHA" $A1 >/dev/null 2>&1; r2=$?
eq "T490-1: planted temp symlink: rc 1 on both runs" "$r1$r2" 11
[ -L "$T6b/learnings/alpha-lesson/.SKILL.md.import-tmp" ] && eq "T490-1: symlink still there, target untouched" "$(cat "$TMP/victim2")" victim2 || nok "T490-1: planted symlink was removed"
T7="$TMP/p3"; mkdir -p "$T7/learnings/alpha-lesson"; ln -s "$TMP/no-such-target" "$T7/learnings/alpha-lesson/SKILL.md"
run "$T7" --sha "$SHA" --files $ALL3 --apply >/dev/null 2>"$TMP/e-p3"; eq "T490-3: broken symlink at output: rc 4" "$?" 4
[ -L "$T7/learnings/alpha-lesson/SKILL.md" ] && [ ! -e "$TMP/no-such-target" ] && [ ! -e "$T7/topic" ] && ok "T490-3: link kept, nothing created" || nok "T490-3: link changed or files written"
has "T490-3: path printed" "$(cat "$TMP/e-p3")" "alpha-lesson/SKILL.md"
T8="$TMP/p3b"; mkdir -p "$T8/learnings/alpha-lesson"; echo tgt >"$TMP/tgt-file"; ln -s "$TMP/tgt-file" "$T8/learnings/alpha-lesson/SKILL.md"
run "$T8" --sha "$SHA" $A1 >/dev/null 2>&1; eq "T490-3: symlink to a file at output: rc 4" "$?" 4
[ -L "$T8/learnings/alpha-lesson/SKILL.md" ] && eq "T490-3: link and its target untouched" "$(cat "$TMP/tgt-file")" tgt || nok "T490-3: link replaced"
PYH='import sys, os; sys.path.insert(0, sys.argv[1]); import il_write as w; d = sys.argv[2]; orig_put = w._put; orig_rep = os.replace'
out="$(python3 -I - "$HERE" "$TMP/n1" 2>/dev/null <<PY
$PYH
n = [0]
def bad(p, c, t):
    n[0] += 1
    if n[0] == 2: raise ValueError("boom")
    return orig_put(p, c, t)
w._put = bad
rc = w.write_all([("new", d + "/a/x/SKILL.md", "A", None), ("new", d + "/b/y/SKILL.md", "B", None)])
left = [r for r, _, fs in os.walk(d) for f in fs if "import-tmp" in f]
print(rc, len(left), os.path.exists(d + "/a"))
PY
)" ; eq "T490-3: non-OSError while writing: rc 1, no temp left, dirs removed" "$out" "1 0 False"
mkdir -p "$TMP/n2/c/u" "$TMP/n2/d/v/SKILL.md"; echo old1 >"$TMP/n2/c/u/SKILL.md"
PL='plan = [("update", d + "/c/u/SKILL.md", "new1", "old1"), ("new", d + "/d/v/SKILL.md", "N", None)]'
out="$(python3 -I - "$HERE" "$TMP/n2" 2>&1 <<PY
$PYH
$PL
def bad(p, c, t):
    if p.endswith(".rb"): raise OSError("restore blocked")
    return orig_put(p, c, t)
w._put = bad
print(w.write_all(plan))
PY
)"; has "T490-2: failed restore reports 'rollback incomplete, check by hand'" "$out" "rollback incomplete, check by hand: ['$TMP/n2/c/u/SKILL.md']"
out="$(python3 -I - "$HERE" "$TMP/n2" 2>&1 <<PY
$PYH
$PL
def bad_rep(src, dst):
    if src.endswith(".rb"): raise OSError("replace blocked")
    return orig_rep(src, dst)
os.replace = bad_rep
rc = w.write_all(plan)
print(rc, os.path.lexists(d + "/c/u/SKILL.md.rb"))
PY
)"; has "T490-2: no leftover .rb after a failed restore replace" "$out" "1 False"

# L3: non-UTF-8 input -> clean error and NOTHING written (a good file sorts before the bad one)
FX3="$TMP/fx3"; mkdir -p "$FX3/learnings"; git -C "$TMP" init -q -b main "$FX3"
printf '# Aaa\nok\n' >"$FX3/learnings/aaa.md"; printf '# Bad\n\377\376 bytes\n' >"$FX3/learnings/bad.md"
git -C "$FX3" add -A; git -C "$FX3" -c user.name=t -c user.email=t@example.invalid commit -qm bad; SHA3="$(git -C "$FX3" rev-parse HEAD)"
HQ_REPO="$FX3" "$IMP" "$TMP/s7" --sha "$SHA3" --apply >"$TMP/o7" 2>"$TMP/e7"; eq "L3: non-UTF-8 input exits 1" "$?" 1
has "L3: clean error (no traceback)" "$(cat "$TMP/e7")" "cannot read learnings/bad.md"
[ ! -e "$TMP/s7" ] && ok "L3: nothing written (no partial apply)" || nok "L3: partial write"

# (f) trials from the real repo at a pinned sha; M2: all 116 descriptions keep their trailer and use-when text
if git -C "$REAL_REPO" cat-file -e "$PIN^{commit}" 2>/dev/null; then
  T="$TMP/trial"; HQ_REPO="$REAL_REPO" "$IMP" "$T" --sha "$PIN" --limit 10 --apply >"$TMP/trial.out" 2>&1; rc=$?
  eq "(f) trial exit 0" "$rc" 0
  eq "(f) 10 skills" "$(find "$T" -name SKILL.md | wc -l | tr -d ' ')" 10
  has "(f) footer cites pinned sha" "$(tail -2 "$(find "$T" -name SKILL.md | sort | head -1)")" "@$PIN"
  F="$TMP/full"; HQ_REPO="$REAL_REPO" "$IMP" "$F" --sha "$PIN" --apply >"$TMP/full.out" 2>&1; eq "(f) full import exit 0" "$?" 0
  eq "(f) 116 skills" "$(find "$F" -name SKILL.md | wc -l | tr -d ' ')" 116
  for nm in learnings/learnings-readme learnings/learnings-methodology retros/retros-readme retros/retros-template; do
    [ -f "$F/$nm/SKILL.md" ] && ok "(f) real repo: $nm imported" || nok "(f) real repo: $nm missing"
  done
  eq "(f) 116 unique names (no collision across categories)" "$(find "$F" -name SKILL.md | sed 's|.*/\([^/]*\)/SKILL.md|\1|' | sort -u | wc -l | tr -d ' ')" 116
  bad="$(python3 -I - "$F" <<'PY'
import sys, os, re, json
bad = 0
for d, _, fs in os.walk(sys.argv[1]):
    for f in fs:
        t = open(os.path.join(d, f), encoding="utf-8").read()
        m = re.match(r"---\nname: (.+)\ndescription: (.+)\n---\n", t)
        if not m or m.group(1) != os.path.basename(d) or not re.match(r"^[a-z0-9][a-z0-9._-]*$", m.group(1)) \
           or len(m.group(1)) > 64 or "created_by" in t or len(t) > 100000:
            bad += 1; continue
        ds = json.loads(m.group(2))
        if len(ds) > 1024 or "Use when the task touches:" not in ds or not re.search(r"\((Learning|Retro), [^,()]+, [0-9-]+\)$", ds) \
           or ds.startswith(("Learning (", "Retro (")):
            bad += 1
print(bad)
PY
)"
  eq "(f)/M2 all 116: valid names, <= 1024, use-when + trailer present, no created_by" "$bad" 0
  ! grep -rq 'skillmanagertool\|HERMESHOME' "$F" && ok "(f)/M4 no mangled identifiers" || nok "(f)/M4 mangled identifiers"
else
  skip "(f)/M2/M4 real-repo trials: pinned sha $PIN is not in this clone (fetch it to run them)"
fi
echo "passed=$passed failed=$failed skipped=$skipped"; [ "$failed" -eq 0 ]
