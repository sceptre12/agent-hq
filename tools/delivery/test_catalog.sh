#!/usr/bin/env bash
# tools/delivery/test_catalog.sh -- hermetic tests for catalog.sh and catalog-audit.sh.
# Run: /bin/bash tools/delivery/test_catalog.sh   (fixtures under $TMPDIR, scratch HOME, real git worktree)
set -u
HERE=$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CATSH="$HERE/catalog.sh"
TD=${TMPDIR:-/tmp}
ROOT=$(mktemp -d "$TD/x.XXXXXX") || exit 1
ROOT=$(cd -P "$ROOT" && pwd)
export HOME="$ROOT/home"; mkdir -p "$HOME"
export GIT_CONFIG_NOSYSTEM=1 GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t
BGPIDS=""
cleanup() { for p in $BGPIDS; do kill "$p" 2>/dev/null; done; rm -rf "$ROOT"; }
trap cleanup EXIT
P=0; F=0
T=$'\t'
pass() { P=$((P + 1)); }
fail() { F=$((F + 1)); echo "FAIL: $1"; }
eq() { if [ "$2" = "$3" ]; then pass; else fail "$1: got [$2] want [$3]"; fi; }
has() { case $2 in *"$3"*) pass ;; *) fail "$1: [$2] lacks [$3]" ;; esac; }

OUT=""; RC=0
cat_() { OUT=$(RUN_HOME="$RUN" /bin/bash "$CATSH" "$@" 2>/dev/null); RC=$?; }
lines() { [ -f "$RUN/catalog.tsv" ] && wc -l < "$RUN/catalog.tsv" | tr -d ' ' || echo 0; }
newrun() { RUN="$ROOT/runs/$1"; mkdir -p "$RUN"; }
reg() { cat_ register "$1" "$2" "${3:--}" "${4:-run}" "${5:-t-src}" "${6:-run}" "${7:-agent-a}"; }

WB="$ROOT/wt"; mkdir -p "$WB"
export WORKTREE_BASE="$WB"

# ---- basic lifecycle ----
newrun abc-1
reg tmpdir "$RUN/t1" u1 PROJ-12 s st1 agent-a
eq "register rc" "$RC" 0
has "row_id shape" "$OUT" "-agent-a-1"
[[ $OUT =~ ^[0-9]{8}T[0-9]{6}Z-agent-a-1$ ]] && pass || fail "row_id regex [$OUT]"
ROW=$(sed -n 1p "$RUN/catalog.tsv")
eq "12 fields" "$(printf '%s' "$ROW" | awk -F'\t' '{print NF}')" 12
eq "state planned" "$(printf '%s' "$ROW" | cut -f10)" planned
eq "keep col" "$(printf '%s' "$ROW" | cut -f11)" -
eq "run_id col" "$(printf '%s' "$ROW" | cut -f2)" abc-1
cat_ list --live; has "list shows planned (INTERFACES 1.4.0 A.5)" "$OUT" "$RUN/t1"; eq "planned is one row" "$(printf '%s\n' "$OUT" | wc -l | tr -d ' ')" 1
cat_ list --live --subtask st1; has "planned subtask filter" "$OUT" "$RUN/t1"
cat_ start tmpdir "$RUN/t1"; eq "start rc" "$RC" 0
L=$(sed -n 2p "$RUN/catalog.tsv")
eq "start state" "$(printf '%s' "$L" | cut -f10)" live
for c in 3 5 8 9 12; do eq "copied col $c" "$(printf '%s' "$L" | cut -f$c)" "$(printf '%s' "$ROW" | cut -f$c)"; done
cat_ list --live; eq "list rc" "$RC" 0; has "list shows live" "$OUT" "$RUN/t1"
cat_ list --live --subtask st2; eq "list filter empty" "$OUT" ""
cat_ list --live --subtask st1; has "list filter match" "$OUT" "$RUN/t1"
cat_ keep tmpdir "$RUN/t1" "needs review"
L=$(sed -n 3p "$RUN/catalog.tsv")
eq "keep state" "$(printf '%s' "$L" | cut -f10)" kept
eq "keep reason" "$(printf '%s' "$L" | cut -f11)" "needs review"
cat_ list --live; eq "kept not live" "$OUT" ""
cat_ fail tmpdir "$RUN/t1"
L=$(sed -n 4p "$RUN/catalog.tsv")
eq "fail state" "$(printf '%s' "$L" | cut -f10)" failed; eq "fail reason" "$(printf '%s' "$L" | cut -f11)" -
cat_ list --live; eq "failed not listed" "$OUT" ""
cat_ release tmpdir "$RUN/t1"
L=$(sed -n 5p "$RUN/catalog.tsv")
eq "release state" "$(printf '%s' "$L" | cut -f10)" released; eq "release reason" "$(printf '%s' "$L" | cut -f11)" -
cat_ list --live; eq "released not listed" "$OUT" ""
reg tmpdir "$RUN/t2" - run s run agent-b; reg tmpdir "$RUN/t3" - run s run agent-b
cat_ start tmpdir "$RUN/t3"; cat_ start tmpdir "$RUN/t2"
cat_ list --live
eq "first-seen order" "$(printf '%s\n' "$OUT" | cut -f7 | tr '\n' ' ')" "$RUN/t2 $RUN/t3 "
newrun abc-empty; cat_ list --live; eq "empty list rc" "$RC" 0; eq "empty list out" "$OUT" ""

# ---- rejections: rc 2, nothing appended ----
newrun abc-rej
reg tmpdir "$RUN/ok" - run s run agent-a; eq "ok seed" "$RC" 0
N0=$(lines)
rej() { local d=$1; shift; cat_ "$@"; eq "reject rc: $d" "$RC" 2; eq "reject keeps file: $d" "$(lines)" "$N0"; }
rej "unknown kind" register bogus x - run s run a
rej "bad unit" register tmpdir "$RUN/a" x1 run s run a
rej "bad corr" register tmpdir "$RUN/a" - proj-1 s run a
rej "bad subtask" register tmpdir "$RUN/a" - run s st run a
rej "bad owner" register tmpdir "$RUN/a" - run s run Agent
rej "bad source" register tmpdir "$RUN/a" - run 'a b' run a
rej "tab in arg" register tmpdir "$RUN/a$T" - run s run a
rej "newline in arg" register tmpdir "$RUN/a"$'\n'b - run s run a
rej "DEL in arg" register tmpdir "$RUN/a"$'\177' - run s run a
rej "outside roots" register tmpdir "$ROOT/elsewhere" - run s run a
rej "dotdot" register tmpdir "$RUN/../x/a" - run s run a
rej "relative path" register tmpdir "rel/a" - run s run a
ln -s "$ROOT" "$RUN/esc"
rej "symlink escape" register tmpdir "$RUN/esc/a" - run s run a
rej "port 0" register port 0 - run s run a
rej "port 65536" register port 65536 - run s run a
rej "port text" register port 80a - run s run a
rej "branch grammar" register branch "nohash" - run s run a
rej "tag base" register tag "$ROOT#v1@main" - run s run a
rej "worktree grammar" register worktree "$WB/x" - run s run a
rej "lane grammar" register lane-lease "lane" - run s run a
rej "pm2 leading dash" register pm2-app -x - run s run a
rej "image leading dash" register image --rm - run s run a
rej "cron leading dash" register cron -x - run s run a
rej "bgtask leading dash" register bgtask --all - run s run a
rej "keep no reason" keep tmpdir "$RUN/ok" "  "
rej "transition no pair" start tmpdir "$RUN/none"
rej "arg count" register tmpdir "$RUN/a"
rej "unknown cmd" frobnicate
reg port 8080; eq "port ok" "$RC" 0
reg process 4242; eq "process ok" "$RC" 0
reg tag "$ROOT#v1@-"; eq "tag ok" "$RC" 0
reg lane-lease lane/e2e; eq "lane ok" "$RC" 0

# ---- RUN_HOME and WORKTREE_BASE ----
OUT=$(env -u RUN_HOME /bin/bash "$CATSH" list --live 2>/dev/null); eq "RUN_HOME unset" "$?" 2
OUT=$(RUN_HOME=relative/abc /bin/bash "$CATSH" list --live 2>/dev/null); eq "RUN_HOME relative" "$?" 2
mkdir -p "$ROOT/runs/BadName"
OUT=$(RUN_HOME="$ROOT/runs/BadName" /bin/bash "$CATSH" list --live 2>/dev/null); eq "RUN_HOME bad segment" "$?" 2
OUT=$(RUN_HOME="$ROOT/runs/missing" /bin/bash "$CATSH" list --live 2>/dev/null); eq "RUN_HOME missing" "$?" 2
mkdir -p "$WB/dir1"
OUT=$(RUN_HOME="$RUN" /bin/bash "$CATSH" register tmpdir "$WB/dir1" - run s run a 2>/dev/null); eq "WORKTREE_BASE root ok" "$?" 0
OUT=$(env -u WORKTREE_BASE RUN_HOME="$RUN" /bin/bash "$CATSH" register tmpdir "$WB/dir1" - run s run a 2>/dev/null); eq "unset base rejects" "$?" 2
OUT=$(WORKTREE_BASE=rel RUN_HOME="$RUN" /bin/bash "$CATSH" list --live 2>/dev/null); eq "relative base" "$?" 2
OUT=$(WORKTREE_BASE="/a b" RUN_HOME="$RUN" /bin/bash "$CATSH" list --live 2>/dev/null); eq "space base" "$?" 2

# ---- 400-byte cap (the newline counts) ----
newrun abc-cap
cat_ register tmpdir "$RUN/a" - run s run agent-a
BASE=$(wc -c < "$RUN/catalog.tsv" | tr -d ' '); rm -f "$RUN/catalog.tsv"
PAD=$(printf '%*s' $((400 - BASE)) '' | tr ' ' a)
cat_ register tmpdir "$RUN/a$PAD" - run s run agent-a; eq "400 passes" "$RC" 0
eq "row is 400 bytes" "$(wc -c < "$RUN/catalog.tsv" | tr -d ' ')" 400
rm -f "$RUN/catalog.tsv"
cat_ register tmpdir "$RUN/a${PAD}a" - run s run agent-a; eq "401 fails" "$RC" 2
eq "401 appends nothing" "$(lines)" 0

# ---- lane-lease ----
newrun abc-lane
reg lane-lease lane/x - run s run agent-a; eq "lease first rc" "$RC" 0
eq "lease writes live" "$(cut -f10 "$RUN/catalog.tsv" | sed -n 1p)" live
reg lane-lease lane/x - run s run agent-b; eq "lease second rc" "$RC" 3; eq "lease second no row" "$(lines)" 1
reg lane-lease lane/y; eq "other handle independent" "$RC" 0
cat_ release lane-lease lane/x
reg lane-lease lane/x - run s run agent-b; eq "reacquire after release" "$RC" 0
reg lane-lease gate-runner/1; eq "gate-runner lease" "$RC" 0

# ---- concurrency ----
newrun abc-con
PIDS=""
for i in 1 2 3 4 5 6 7 8 9 10; do
  RUN_HOME="$RUN" DL_LOCK_TIMEOUT=30 DL_LOCK_SLEEP=0.1 /bin/bash "$CATSH" register tmpdir "$RUN/c$i" - run s run w$i > /dev/null 2>&1 &
  PIDS="$PIDS $!"
done
BAD=0; for p in $PIDS; do wait "$p" || BAD=$((BAD + 1)); done
eq "all writers rc 0" "$BAD" 0
eq "10 rows" "$(lines)" 10
eq "all rows 12 fields" "$(awk -F'\t' 'NF != 12' "$RUN/catalog.tsv" | wc -l | tr -d ' ')" 0
eq "n is 1..10 once" "$(awk -F'\t' '{ n = $4; sub(/.*-/, "", n); print n }' "$RUN/catalog.tsv" | sort -n | tr '\n' ' ')" "1 2 3 4 5 6 7 8 9 10 "
[ -e "$RUN/catalog.lock" ] && fail "lock dir remains" || pass

# ---- lock staleness ----
newrun abc-lock
LK="$RUN/catalog.lock"
mkdir "$LK"; echo "$$ 2026-10-26T00:00:00Z" > "$LK/owner"
OUT=$(RUN_HOME="$RUN" DL_LOCK_TIMEOUT=2 /bin/bash "$CATSH" register tmpdir "$RUN/l1" - run s run a 2>/dev/null); eq "live holder -> 4" "$?" 4
[ -d "$LK" ] && pass || fail "live lock was broken"
rm -rf "$LK"
DEAD=$(/bin/bash -c 'echo $$')
mkdir "$LK"; echo "$DEAD 2026-10-26T00:00:00Z" > "$LK/owner"
OUT=$(RUN_HOME="$RUN" DL_LOCK_TIMEOUT=5 /bin/bash "$CATSH" register tmpdir "$RUN/l2" - run s run a 2>/dev/null); eq "dead pid broken" "$?" 0
eq "no broken dirs (dead)" "$(ls -d "$RUN"/catalog.lock* 2>/dev/null | wc -l | tr -d ' ')" 0
mkdir "$LK"; touch -t 202001010000 "$LK"
OUT=$(RUN_HOME="$RUN" DL_LOCK_TIMEOUT=5 /bin/bash "$CATSH" register tmpdir "$RUN/l3" - run s run a 2>/dev/null); eq "old ownerless broken" "$?" 0
eq "no broken dirs (ownerless)" "$(ls -d "$RUN"/catalog.lock* 2>/dev/null | wc -l | tr -d ' ')" 0
mkdir "$LK"
OUT=$(RUN_HOME="$RUN" DL_LOCK_TIMEOUT=2 /bin/bash "$CATSH" register tmpdir "$RUN/l4" - run s run a 2>/dev/null); eq "fresh ownerless -> 4" "$?" 4
[ -d "$LK" ] && pass || fail "fresh ownerless lock was broken"
rmdir "$LK"

# ---- audit ----
newrun aud-1
REPO="$ROOT/repo"; mkdir -p "$REPO"
( cd "$REPO" && git init -q . && echo x > f && git add f && git commit -q -m init && git branch -M main && git branch feat ) > /dev/null 2>&1
WT="$WB/aud-1-st0"; STRAY="$WB/aud-1-st9"
git -C "$REPO" worktree add -q "$WT" -b wt-open > /dev/null 2>&1 && pass || fail "git worktree add blocked in this sandbox"
git -C "$REPO" worktree add -q "$STRAY" -b wt-stray > /dev/null 2>&1 && pass || fail "stray git worktree add blocked"
sleep 60 & ALIVE=$!; BGPIDS="$ALIVE"; disown "$ALIVE"
sleep 0 & DEADP=$!; wait "$DEADP"
mkdir -p "$RUN/st0/bus" "$RUN/live-dir"
printf 'port=1\ndata_dir=%s\npm2_app=x\npid=%s\nsession_id=s\ntopic=t\n' "$RUN/st0/bus" "$ALIVE" > "$RUN/st0/bus.endpoint"
r() { reg "$@"; RID=$OUT; }
r process "$ALIVE"; A_PROC=$RID
r process "$DEADP"; G_PROC=$RID
r tmpdir "$RUN/live-dir"; A_TMP=$RID
r tmpdir "$RUN/gone-dir"; G_TMP=$RID
r worktree "$WT#$REPO@main" - run s st0 agent-a; A_WT=$RID
r worktree "$WB/aud-1-st5#$REPO@main" - run s st0 agent-a; G_WT=$RID
r branch "$REPO#feat@main"; A_BR=$RID
r branch "$REPO#nope@main"; G_BR=$RID
r bus "$RUN/st0/bus" - run s st0 agent-a; A_BUS=$RID
mkdir -p "$RUN/st1/bus"
r bus "$RUN/st1/bus" - run s st1 agent-a; G_BUS=$RID
# in-run review buses (D5): bus.endpoint sits beside the review's own data dir, not at the sub-task root
RV="$RUN/review/st2/pr-review-aaaa1111"; mkdir -p "$RV/bus"
printf 'port=2\ndata_dir=%s\npm2_app=y\npid=%s\nsession_id=s\ntopic=t\n' "$RV/bus" "$ALIVE" > "$RV/bus.endpoint"
r bus "$RV/bus" - run s st2 agent-a; A_RBUS=$RID
RD="$RUN/review/st0/pr-review-bbbb2222"; mkdir -p "$RD/bus"
printf 'port=3\ndata_dir=%s\npm2_app=z\npid=%s\nsession_id=s\ntopic=t\n' "$RD/bus" "$DEADP" > "$RD/bus.endpoint"
r bus "$RD/bus" - run s st0 agent-a; G_RBUS=$RID
RN="$RUN/review/st0/pr-review-cccc3333"; mkdir -p "$RN/bus"
r bus "$RN/bus" - run s st0 agent-a; G_RBUS2=$RID
r lane-lease lane/z; A_LL=$RID
r container web:1; C_ID=$RID
r tmpdir "$RUN/rel-dir"; R_ID=$RID; mkdir -p "$RUN/rel-dir"
cat_ release tmpdir "$RUN/rel-dir"
# rowin <audit-output> <row_id>: exact match of field 2 (a plain substring test confuses row id ...-1 with ...-10)
rowin() { printf '%s\n' "$1" | cut -f2 | command grep -qxF -- "$2"; }
cat_ audit; AUD=$OUT; eq "audit rc" "$RC" 0
for id in "$A_PROC" "$A_TMP" "$A_WT" "$A_BR" "$A_BUS" "$A_RBUS" "$A_LL"; do has "MATCH $id" "$AUD" "MATCH$T$id"; done
for id in "$G_PROC" "$G_TMP" "$G_WT" "$G_BR" "$G_BUS" "$G_RBUS" "$G_RBUS2"; do has "GHOST $id" "$AUD" "GHOST$T$id"; done
has "SQUATTER stray" "$AUD" "SQUATTER$T-${T}worktree:$STRAY"
if rowin "$AUD" "$C_ID"; then fail "container printed"; else pass; fi
if rowin "$AUD" "$R_ID"; then fail "released printed"; else pass; fi
case $AUD in *"worktree:$WT"*) fail "open worktree reported as squatter" ;; *) pass ;; esac
BADL=0
while IFS= read -r line; do
  [ -n "$line" ] || continue
  if [[ $line =~ ^(MATCH|GHOST)$'\t'[0-9]{8}T[0-9]{6}Z-[a-z0-9-]+-[0-9]+$ ]] || [[ $line =~ ^SQUATTER$'\t'-$'\t'[a-z0-9-]+:.+$ ]]; then :; else BADL=$((BADL + 1)); echo "bad audit line: $line"; fi
done <<< "$AUD"
eq "audit lines match regexes" "$BADL" 0
cat_ release process "$ALIVE"
cat_ audit; if rowin "$OUT" "$A_PROC"; then fail "released process still audited"; else pass; fi
# port live truth fails closed (M4): no lsof or a failing lsof is exit 5 and no verdict, never GHOST
newrun aud-port
r port 48731; P_ID=$RID
r tmpdir "$RUN/gone2"; G2_ID=$RID
FB="$ROOT/fakebin"; mkdir -p "$FB/none" "$FB/fail" "$FB/empty" "$FB/hit"
printf '#!/bin/sh\nexit 2\n' > "$FB/fail/lsof"
printf '#!/bin/sh\nexit 1\n' > "$FB/empty/lsof"
printf '#!/bin/sh\necho "x 1 u 3u IPv4 0 0t0 TCP *:48731 (LISTEN)"\n' > "$FB/hit/lsof"
chmod +x "$FB"/*/lsof
aud() { OUT=$(PATH="$FB/$1:/usr/bin:/bin" RUN_HOME="$RUN" /bin/bash "$CATSH" audit 2>"$ROOT/aud.err"); RC=$?; }
aud none; eq "no lsof rc 5" "$RC" 5
if rowin "$OUT" "$P_ID"; then fail "no lsof printed a port verdict"; else pass; fi
has "no lsof other rows still audited" "$OUT" "GHOST$T$G2_ID"
has "no lsof stderr" "$(cat "$ROOT/aud.err")" "failing closed"
aud fail; eq "failing lsof rc 5" "$RC" 5
if rowin "$OUT" "$P_ID"; then fail "failing lsof printed a port verdict"; else pass; fi
aud empty; eq "lsof no match rc 0" "$RC" 0; has "lsof no match GHOST" "$OUT" "GHOST$T$P_ID"
aud hit; eq "lsof hit rc 0" "$RC" 0; has "lsof hit MATCH" "$OUT" "MATCH$T$P_ID"
newrun aud-empty; cat_ audit; eq "audit no catalog" "$RC$OUT" 0

echo "test_catalog: $P passed, $F failed"
[ "$F" -eq 0 ]
