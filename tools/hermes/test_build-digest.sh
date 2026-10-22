#!/usr/bin/env bash
# tools/hermes/test_build-digest.sh — hermetic tests for build-digest.sh + verify-digest.sh (Hermes H3,
# architecture/hermes-agent.md §7, §13 D3/D8). Fixture git repo in mktemp -d with a fake origin/main ref; no
# network, no Hermes, no real hq paths, no token (secret-shaped fixtures are assembled at runtime from split parts).
set -uo pipefail
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null LC_ALL=C   # hermetic: no user hooks/config
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD="$HERE/build-digest.sh"; VERIFY="$HERE/verify-digest.sh"
TMP="$(mktemp -d)"; trap 'chmod -R u+w "$TMP" 2>/dev/null; rm -rf "$TMP"' EXIT
passed=0; failed=0
ok() { echo "ok - $1"; passed=$((passed + 1)); }
nok() { echo "not ok - $1"; failed=$((failed + 1)); }
eq() { if [ "$2" = "$3" ]; then ok "$1"; else nok "$1 (got '$2', want '$3')"; fi; }
has() { case "$2" in *"$3"*) ok "$1" ;; *) nok "$1 (no '$3' in: $2)" ;; esac; }
hasnt() { case "$2" in *"$3"*) nok "$1 (unexpected '$3')" ;; *) ok "$1" ;; esac; }

FX="$TMP/fx"; mkdir -p "$FX"; cd "$FX" || exit 1
git init -q -b main . && git config user.name t && git config user.email t@example.invalid
w() { mkdir -p "$(dirname "$1")"; printf '%s\n' "${@:2}" >"$1"; }
w CLAUDE.md '# Fixture hq' 'BODYMARKER rule text'
w config/CLAUDE.md '# Global rules'; w config/settings.json '{}'
for f in STANDARDS INVARIANTS STANDING-HOLDS README; do w "$f.md" "# $f"; done
w decisions/0002-second.md '# 0002. Second' 'BODYMARKER'; w decisions/0001-first.md 'intro line' '# 0001. First'
w architecture/a.md '# Arch A'; w architecture/sub/b.md 'no heading here'; w 'architecture/with space.md' '# Spaced'
w architecture/x.pem 'pem'; w architecture/notes.env 'E=1'; w architecture/.env 'E=1'; w architecture/SERVER.KEY 'k'
w architecture/secrets/s.md '# s'; w architecture/token 't'; w architecture/credentials.json '{}'
ln -s ../CLAUDE.md architecture/link.md
w learnings/l.md '# Learning'; w projects/p.md '# Project'; w retros/r.md '# Retro'
w skills/s1/SKILL.md '# Skill one'; w skills/s1/other.md '# other'; w skills/s1/deep/SKILL.md '# deep'
w tools/t.sh 'echo'; w tools/sub/doc.md '# Tool doc'; w tools/secrets/x.md '# x'; w tools/sub/run.py 'pass'
w plans/p1/00-overview.md '# Plan one'; w plans/p1/evidence/e.md '# ev'; w plans/p1/tasks/t.md '# task'
w references/ref.md '# ref'; w inbox/i.md '# i'; w memory/m.md '# m'; w notes/n.md '# not in set'
git add -A && git commit -qm fixture && git update-ref refs/remotes/origin/main HEAD
w architecture/untracked.md '# untracked'
SHA="$(git rev-parse HEAD)"
WANT='CLAUDE.md
INVARIANTS.md
README.md
STANDARDS.md
STANDING-HOLDS.md
architecture/a.md
architecture/sub/b.md
architecture/with space.md
config/CLAUDE.md
decisions/0001-first.md
decisions/0002-second.md
learnings/l.md
plans/p1/00-overview.md
projects/p.md
retros/r.md
skills/s1/SKILL.md
tools/sub/doc.md'
status0="$(git status --porcelain)"
files() { (cd "$1" && find . \( -path ./MANIFEST.tsv -o -path ./.index \) -prune -o ! -type d -print | sed 's|^\./||' | sort); }
copy() { rm -rf "$2"; cp -R "$1" "$2"; chmod -R u+w "$2"; }

# --- happy path ---
out="$(HQ_REPO="$FX" "$BUILD" "$SHA" "$TMP/o1" 2>&1)"; rc=$?
eq "happy: build exit 0" "$rc" 0; has "happy: DIGEST == MAIN printed" "$out" "DIGEST == MAIN $SHA"
S="$TMP/o1/hq/$SHA"
eq "happy: current -> sha" "$(readlink "$TMP/o1/hq/current")" "$SHA"
eq "happy: snapshot holds exactly the set (exclusions applied, symlink/untracked absent)" "$(files "$S")" "$WANT"
eq "excluded: config/ holds CLAUDE.md only" "$(ls "$S/config")" "CLAUDE.md"
eq "excluded: no evidence path" "$(find "$S" -path '*evidence*' | wc -l | tr -d ' ')" 0
for p in config/settings.json architecture/x.pem architecture/notes.env architecture/.env architecture/SERVER.KEY \
  architecture/secrets architecture/token architecture/credentials.json architecture/link.md tools/t.sh tools/sub/run.py \
  tools/secrets plans/p1/tasks references inbox memory notes skills/s1/other.md skills/s1/deep architecture/untracked.md; do
  [ -e "$S/$p" ] || [ -L "$S/$p" ] && nok "excluded: $p absent" || ok "excluded: $p absent"
done
[ -w "$S/CLAUDE.md" ] || [ -w "$S" ] && nok "read-only: chmod -R a-w applied" || ok "read-only: chmod -R a-w applied"
hdr="$(head -n 1 "$S/MANIFEST.tsv")"
[[ "$hdr" =~ ^#\ hq\ $SHA\ built\ [0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]] && ok "manifest: header" || nok "manifest: header ($hdr)"
eq "manifest: rows = ls-tree blobs, LC_ALL=C sorted" "$(tail -n +2 "$S/MANIFEST.tsv")" \
  "$(while IFS= read -r p; do printf '%s\t%s\n' "$p" "$(git rev-parse "$SHA:$p")"; done <<<"$WANT" | sort)"
eq "no writes under hq: fixture status unchanged" "$(git status --porcelain)" "$status0"
# --- index skill ---
K="$S/.index/hq-index/SKILL.md"; idx="$(cat "$K")"
eq "index: frontmatter name" "$(sed -n 2p "$K")" "name: hq-index"
eq "index: description is one line" "$(sed -n 3p "$K" | grep -c '^description: .')$(sed -n 4p "$K")" "1---"
eq "index: one line per file" "$(grep -c '^- `' "$K")" "$(($(wc -l <"$S/MANIFEST.tsv") - 1))"
while IFS= read -r p; do [ "$(grep -cF -- "- \`$p\` — " "$K")" = 1 ] || nok "index: line for $p"; done <<<"$WANT"
RB="$(cd -P "$TMP/o1/hq" && pwd)"
eq "index: Root line present exactly once" "$(grep -c '^Root: ' "$K")" 1
has "index: Root names current/" "$idx" "Root: $RB/current/ (this snapshot: $RB/$SHA/)."
has "index: Root says absolute paths" "$idx" "Pass ABSOLUTE paths to read_file and search_files"
eq "index: no home path beyond out-root" "$(grep -cF -- "$HOME" "$K")$(grep -F -- "$HOME" "$K" | grep -vcF -- "$RB")" "00"
has "index: sha present" "$idx" "$SHA"; has "index: retrieval rule" "$idx" "grep first, read the matched slice, cite \`path:line@$SHA\`"
has "index: first # heading (not first line)" "$idx" '- `decisions/0001-first.md` — 0001. First'
has "index: no-heading marker" "$idx" '- `architecture/sub/b.md` — (no heading)'
hasnt "index: no body content" "$idx" "BODYMARKER"
order="$(grep '^- `' "$K" | cut -d'`' -f2 | tr '\n' ' ')"
eq "index: §7 order (rules listed order, then groups, C-sorted within)" "$order" \
  "CLAUDE.md config/CLAUDE.md STANDARDS.md INVARIANTS.md STANDING-HOLDS.md README.md decisions/0001-first.md decisions/0002-second.md architecture/a.md architecture/sub/b.md architecture/with space.md learnings/l.md projects/p.md retros/r.md skills/s1/SKILL.md tools/sub/doc.md plans/p1/00-overview.md "
# --- determinism ---
HQ_REPO="$FX" "$BUILD" "$SHA" "$TMP/o2" >/dev/null 2>&1
d="$(diff -r -x MANIFEST.tsv -x SKILL.md "$S" "$TMP/o2/hq/$SHA" 2>&1; diff "$K" <(sed "s|/o2/hq|/o1/hq|g" "$TMP/o2/hq/$SHA/.index/hq-index/SKILL.md") 2>&1; diff <(tail -n +2 "$S/MANIFEST.tsv") <(tail -n +2 "$TMP/o2/hq/$SHA/MANIFEST.tsv") 2>&1)"
eq "determinism: second build identical (bar the built timestamp)" "$d" ""
# --- verify ---
eq "verify: clean snapshot passes" "$("$VERIFY" "$TMP/o1/hq/current" "$FX"; echo "rc=$?")" "DIGEST == MAIN $SHA
rc=0"
C="$TMP/c"; copy "$S" "$C"; echo tamper >>"$C/learnings/l.md"
out="$("$VERIFY" "$C" "$FX")"; eq "modified file: exit 5" "$?" 5; has "modified file: named" "$out" "content differs: learnings/l.md"
copy "$S" "$C"; rm "$C/retros/r.md"; out="$("$VERIFY" "$C" "$FX")"; eq "missing file: exit 5" "$?" 5; has "missing file: named" "$out" "retros/r.md"
copy "$S" "$C"; rm "$C/projects/p.md"; ln -s ../CLAUDE.md "$C/projects/p.md"; "$VERIFY" "$C" "$FX" >/dev/null; eq "symlink in place of file: exit 5" "$?" 5
copy "$S" "$C"; printf 'learnings/zz.md\t%040d\n' 0 >>"$C/MANIFEST.tsv"; "$VERIFY" "$C" "$FX" >/dev/null; eq "manifest path not in main: exit 5" "$?" 5
copy "$S" "$C"; sed -i.b '/^projects\/p.md/d' "$C/MANIFEST.tsv"; rm "$C/MANIFEST.tsv.b" "$C/projects/p.md"
out="$("$VERIFY" "$C" "$FX")"; eq "path in main missing from manifest: exit 5" "$?" 5; has "path list mismatch named" "$out" "not in manifest but in main: projects/p.md"
# verify_ignores_manifest_and_index: MANIFEST.tsv and .index/** are ignored, nothing else is.
copy "$S" "$C"; mkdir -p "$C/.index/other"; echo x >"$C/.index/other/y"
"$VERIFY" "$C" "$FX" >/dev/null; eq "verify_ignores_manifest_and_index: clean (+.index/** extra) passes" "$?" 0
for extra in MANIFEST.tsv.bak index/x .index-x notes/n.md; do
  copy "$S" "$C"; mkdir -p "$(dirname "$C/$extra")"; echo x >"$C/$extra"
  out="$("$VERIFY" "$C" "$FX")"; rc=$?
  eq "verify_ignores_manifest_and_index: planted $extra -> exit 5" "$rc" 5; has "planted $extra named" "$out" "extra file in snapshot: $extra"
done
# --- stale ---
git commit -q --allow-empty -m next && git update-ref refs/remotes/origin/main HEAD; SHA2="$(git rev-parse HEAD)"
out="$("$VERIFY" "$S" "$FX")"; eq "stale: manifest sha != origin/main -> exit 4" "$?" 4; has "stale: STALE printed" "$out" "STALE"
out="$(HQ_REPO="$FX" "$BUILD" "$SHA" "$TMP/o3" 2>&1)"; eq "stale build: exit 4" "$?" 4
[ -e "$TMP/o3/hq/$SHA" ] || [ -L "$TMP/o3/hq/current" ] && nok "stale build: snapshot deleted, current not flipped" || ok "stale build: snapshot deleted, current not flipped"
# --- refresh: new sha flips current, previous kept ---
out="$(HQ_REPO="$FX" "$BUILD" "$SHA2" "$TMP/o1" 2>&1)"; eq "refresh: build new sha exit 0" "$?" 0
eq "refresh: current flipped" "$(readlink "$TMP/o1/hq/current")" "$SHA2"
[ -f "$S/MANIFEST.tsv" ] && ok "refresh: previous snapshot kept" || nok "refresh: previous snapshot kept"
HQ_REPO="$FX" "$BUILD" "$SHA2" "$TMP/o1" >/dev/null 2>&1; eq "existing snapshot never overwritten: exit 1" "$?" 1
# --- secret abort ---
a="sk"; tok="${a}-ant-oat01-$(printf 'Q%.0s' {1..24})"; k="AK"; aws="${k}IAQWERTYUIOPASDFGH"; b="PRIV"; pem="-----BEGIN RSA ${b}ATE KEY-----"
secret_case() { # <name> <path> <content>
  w "$2" '# leak' "$3"; git add -A && git commit -qm "leak $1" && git update-ref refs/remotes/origin/main HEAD
  local s; s="$(git rev-parse HEAD)"
  out="$(HQ_REPO="$FX" "$BUILD" "$s" "$TMP/o1" 2>&1)"; rc=$?
  eq "secret $1: exit 3" "$rc" 3; has "secret $1: PATH printed" "$out" "SECRET-HIT: $2"
  hasnt "secret $1: match text not printed" "$out" "${3:3:12}"
  [ -e "$TMP/o1/hq/$s" ] && nok "secret $1: no snapshot left" || ok "secret $1: no snapshot left"
  eq "secret $1: no partial build dir left" "$(find "$TMP/o1/hq" -maxdepth 1 -name '.*' ! -name . | wc -l | tr -d ' ')" 0
  eq "secret $1: current unchanged" "$(readlink "$TMP/o1/hq/current")" "$SHA2"
  git rm -q "$2" && git commit -qm "unleak $1"
}
secret_case anthropic learnings/leak.md "token=$tok"
secret_case aws 'retros/with space.md' "key $aws"
secret_case pem architecture/k.md "$pem"
w plans/p1/evidence/tok.md "$tok"; git add -A && git commit -qm "evidence" && git update-ref refs/remotes/origin/main HEAD
HQ_REPO="$FX" "$BUILD" "$(git rev-parse HEAD)" "$TMP/o4" >/dev/null 2>&1; eq "secret in an excluded path: excluded before the scan, exit 0" "$?" 0
# --- usage ---
"$BUILD" >/dev/null 2>&1; eq "usage: build no args -> 2" "$?" 2
HQ_REPO="$FX" "$BUILD" nosuchref "$TMP/o5" >/dev/null 2>&1; eq "usage: build bad sha -> 2" "$?" 2
HQ_REPO="$FX" "$BUILD" HEAD "$FX/out" >/dev/null 2>&1; eq "usage: out-root inside hq -> 2" "$?" 2
"$VERIFY" "$TMP/nope" "$FX" >/dev/null 2>&1; eq "usage: verify missing dir -> 2" "$?" 2
"$VERIFY" >/dev/null 2>&1; eq "usage: verify no args -> 2" "$?" 2
# --- regex drift guard: build-digest.sh uses pre-commit check (c) verbatim, minus the `^\+.*` diff prefix ---
pc="$(grep -F "grep -E '^\\+.*(" "$HERE/../git-hooks/pre-commit")"; pc="${pc#*"'^\\+.*"}"; pc="${pc%%"'"*}"
bd="$(grep -F "SECRET_RE='" "$BUILD")"; bd="${bd#*"SECRET_RE='"}"; bd="${bd%%"'"*}"
[ -n "$pc" ] && eq "secret regex == pre-commit check (c)" "$bd" "$pc" || nok "secret regex: pre-commit check (c) line not found"
echo "=== $passed passed, $failed failed ==="
[ "$failed" = 0 ]
