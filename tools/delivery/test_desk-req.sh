#!/usr/bin/env bash
# Hermetic tests for desk-req.sh. Run: bash tools/delivery/test_desk-req.sh
set -u
HERE=$(cd "$(dirname "$0")" && pwd -P)
SUT="$HERE/desk-req.sh"
T=$(mktemp -d "${TMPDIR:-/tmp}/dreq.XXXXXX") || exit 1
trap 'rm -rf "$T"' EXIT
export HOME="$T/home"; mkdir -p "$HOME"
export DELIVERY_ROOT="$T/root"
RID=run-20261026-1
RH="$DELIVERY_ROOT/$RID"
PASS=0; FAIL=0
ok() { PASS=$((PASS + 1)); }
no() { FAIL=$((FAIL + 1)); echo "FAIL: $1"; }
check() { if [ "$2" = "$3" ]; then ok; else no "$1 (got '$2', want '$3')"; fi; }
match() { if [[ "$2" =~ $3 ]]; then ok; else no "$1 (got '$2')"; fi; }

reset() { rm -rf "$DELIVERY_ROOT"; mkdir -p "$RH/review/st1" "$RH/review/run" "$RH/bodies" "$RH/st1/lanes"; }
SHA=$(printf 'a%.0s' $(seq 1 40))
REPO=/some/clone
fx() { printf '%s' "$2" > "$T/f-$1.json"; echo "$T/f-$1.json"; }
run() { OUT=$("$SUT" "$@" 2>"$T/err"); RC=$?; ERRT=$(cat "$T/err"); }
sch() { # name rc2 + schema message + no .req
  local n; n=$(ls "$RH/desk" 2>/dev/null | grep -c '\.req$')
  check "$1 rc" "$RC" 2
  match "$1 msg" "$ERRT" '^desk-req: schema: '
  check "$1 nofile" "$n" "${2:-0}"
}
ID_RE='^DESK ([a-z0-9-]+-(st[0-9]+|pm|run)-[0-9]{8}T[0-9]{6}Z-[0-9]+) \| ([a-z-]+) \| (/[^ ]+) \| sha256=([0-9a-f]{64})$'

reset
# --- valid fixture per verb ------------------------------------------------
declare_fixtures() {
  V_push="st1 {\"repo\":\"$REPO\",\"branch\":\"ABC-12-fix-it\",\"expect_head\":\"$SHA\"}"
  V_pr_create="st1 {\"repo\":\"$REPO\",\"branch\":\"ABC-12\",\"base\":\"main\",\"body_path\":\"$RH/review/st1/pr-body.md\",\"labels\":[\"a\",\"b:c\"],\"record_path\":\"$RH/review/st1/record-$SHA.md\",\"expect_head\":\"$SHA\"}"
  V_pr_attach="st1 {\"repo\":\"$REPO\",\"pr\":7,\"paths\":[\"$RH/st1/lanes/a.png\"]}"
  V_pr_comment="st1 {\"repo\":\"$REPO\",\"pr\":7,\"body_path\":\"$RH/bodies/c.md\"}"
  V_pr_comments_read="st1 {\"repo\":\"$REPO\",\"pr\":7}"
  V_pr_approval_state="run {\"repo\":\"$REPO\",\"pr\":7}"
  V_pr_merge="run {\"repo\":\"$REPO\",\"pr\":7,\"subtask\":\"st1\",\"method\":\"squash\",\"expect_head\":\"$SHA\",\"predecessors\":[3,4],\"record_path\":\"$RH/review/st1/record-$SHA.md\"}"
  V_branch_delete="st1 {\"repo\":\"$REPO\",\"branch\":\"ABC-12\",\"merged_into\":\"main\",\"merge_sha\":\"$SHA\"}"
  V_ci_status="st1 {\"repo\":\"$REPO\",\"pr\":7}"
  V_ci_logs="st1 {\"repo\":\"$REPO\",\"ci_run_id\":99,\"job\":\"build (node 20)\"}"
  V_ci_rerun="st1 {\"repo\":\"$REPO\",\"ci_run_id\":99}"
  V_ci_status_main="pm {\"repo\":\"$REPO\",\"merge_sha\":\"$SHA\"}"
  V_fetch="st1 {\"repo\":\"$REPO\",\"ref\":\"origin/main\"}"
  V_tag_push="run {\"repo\":\"$REPO\",\"tag\":\"v1.2.3\",\"sha\":\"$SHA\",\"step_id\":\"rel-1\"}"
  V_publish="run {\"repo\":\"$REPO\",\"package\":\"@acme/pkg\",\"version\":\"1.2.3\",\"step_id\":\"rel-1\"}"
  V_test_report_push="run {\"tool\":\"zephyr\",\"payload_path\":\"$RH/bodies/p.json\",\"dry_run\":true}"
  V_jira_get="run {\"key\":\"ABC-1\",\"fields\":[\"summary\",\"status\"]}"
  V_jira_create="run {\"parent\":\"ABC-1\",\"fields\":{\"summary\":\"s\",\"issuetype\":\"Task\",\"labels\":[\"x\"]}}"
  V_jira_update="run {\"key\":\"ABC-2\",\"fields\":{\"description\":\"d\"}}"
  V_jira_transition="run {\"key\":\"ABC-2\",\"to\":\"In Progress\"}"
}
declare_fixtures
VERBS="push pr-create pr-attach pr-comment pr-comments-read pr-approval-state pr-merge branch-delete ci-status ci-logs ci-rerun ci-status-main fetch tag-push publish test-report-push jira-get jira-create jira-update jira-transition"
for v in $VERBS; do
  reset
  var="V_$(printf '%s' "$v" | tr - _)"; spec=${!var}; sub=${spec%% *}; js=${spec#* }
  run "$RID" "$sub" "$v" "$(fx ok "$js")"
  check "$v rc" "$RC" 0
  if [[ "$OUT" =~ $ID_RE ]]; then
    ok
    id=${BASH_REMATCH[1]}; path=${BASH_REMATCH[4]}; sha=${BASH_REMATCH[5]}
    check "$v path" "$path" "$RH/desk/$id.req"
    check "$v sha" "$sha" "$(shasum -a 256 "$path" | cut -d' ' -f1)"
    check "$v mode" "$(stat -f %Lp "$path")" 600
    check "$v keys" "$(/usr/bin/jq -c 'keys' "$path")" '["fields","id","subtask","verb"]'
    check "$v verb" "$(/usr/bin/jq -r .verb "$path")" "$v"
    check "$v lock gone" "$([ -e "$RH/desk/.lock" ] && echo y || echo n)" n
  else no "$v line ($OUT / $ERRT)"; fi
done

# --- counter ---------------------------------------------------------------
reset
f=$(fx c "{\"repo\":\"$REPO\",\"pr\":1}")
run "$RID" st1 ci-status "$f"; match "n=1" "$OUT" '-1 \| ci-status'
run "$RID" st1 ci-status "$f"; match "n=2" "$OUT" '-2 \| ci-status'
run "$RID" pm ci-status "$f"; match "n=3 any subtask" "$OUT" '-pm-[0-9T]+Z-3 \| '
: > "$RH/desk/$RID-st1-20261026T000000Z-9.out"
run "$RID" st1 ci-status "$f"; match "n after .out" "$OUT" '-10 \| '
run "$RID" st1 ci-status "$(fx bad '{"repo":"/x"}')"; sch "fail no consume" 4
run "$RID" st1 ci-status "$f"; match "n not consumed" "$OUT" '-11 \| '
# 10 concurrent writers
reset
for i in 1 2 3 4 5 6 7 8 9 10; do
  ( DL_LOCK_TIMEOUT=60 DL_LOCK_INTERVAL=0.1 "$SUT" "$RID" st1 ci-status "$f" > "$T/par.$i" 2>/dev/null ) &
done
wait
ns=$(cat "$T"/par.* | sed -E 's/.*-([0-9]+) \| ci-status.*/\1/' | sort -n | uniq | wc -l | tr -d ' ')
check "10 distinct n" "$ns" 10
check "10 reqs" "$(ls "$RH/desk" | grep -c '\.req$')" 10
check "lock gone after 10" "$([ -e "$RH/desk/.lock" ] && echo y || echo n)" n
check "no temp left" "$(ls -a "$RH/desk" | grep -c '^\.tmp')" 0

# --- rejections ------------------------------------------------------------
reset
G="\"repo\":\"$REPO\""
rej() { run "$RID" "${4:-st1}" "$2" "$(fx r "$3")"; sch "$1"; }
rej unknown-verb nope '{}'
rej unknown-key ci-status "{$G,\"pr\":1,\"x\":1}"
rej missing-key ci-status "{$G}"
rej mistyped-int ci-status "{$G,\"pr\":\"1\"}"
rej neg-int ci-status "{$G,\"pr\":-1}"
rej float-int ci-status "{$G,\"pr\":1.5}"
rej relative-repo ci-status '{"repo":"rel","pr":1}'
rej string-array pr-attach "{$G,\"pr\":1,\"paths\":\"$RH/st1/lanes/a\"}"
rej string-labels pr-create "{$G,\"branch\":\"ABC-1\",\"base\":\"main\",\"body_path\":\"$RH/bodies/b\",\"labels\":\"x\",\"record_path\":\"$RH/review/st1/record-$SHA.md\",\"expect_head\":\"$SHA\"}"
rej force push "{$G,\"branch\":\"ABC-1\",\"expect_head\":\"$SHA\",\"force\":true}"
rej raw-flag push "{$G,\"branch\":\"ABC-1\",\"expect_head\":\"$SHA\",\"flags\":\"--force\"}"
rej bad-branch push "{$G,\"branch\":\"abc-1\",\"expect_head\":\"$SHA\"}"
rej bad-branch2 push "{$G,\"branch\":\"ABC-1-Bad\",\"expect_head\":\"$SHA\"}"
rej short-sha push "{$G,\"branch\":\"ABC-1\",\"expect_head\":\"abc\"}"
rej upper-sha push "{$G,\"branch\":\"ABC-1\",\"expect_head\":\"$(printf 'A%.0s' $(seq 1 40))\"}"
rej bad-ref fetch "{$G,\"ref\":\"a b\"}"
rej flag-ref fetch "{$G,\"ref\":\"--upload-pack=x\"}"
rej bad-method pr-merge "{$G,\"pr\":1,\"subtask\":\"st1\",\"method\":\"fast\",\"expect_head\":\"$SHA\",\"predecessors\":[],\"record_path\":\"$RH/review/st1/record-$SHA.md\"}" run
rej merge-bad-fsub pr-merge "{$G,\"pr\":1,\"subtask\":\"run\",\"method\":\"squash\",\"expect_head\":\"$SHA\",\"predecessors\":[],\"record_path\":\"$RH/review/st1/record-$SHA.md\"}" run
rej merge-preds-str pr-merge "{$G,\"pr\":1,\"subtask\":\"st1\",\"method\":\"squash\",\"expect_head\":\"$SHA\",\"predecessors\":\"1\",\"record_path\":\"$RH/review/st1/record-$SHA.md\"}" run
rej jira-epic-parent jira-create '{"parent":"ABC-1","fields":{"summary":"s","issuetype":"Epic"}}' run
rej jira-task-noparent jira-create '{"fields":{"summary":"s","issuetype":"Task"}}' run
rej jira-badkey jira-update '{"key":"ABC-1","fields":{"assignee":"x"}}' run
rej jira-badval jira-update '{"key":"ABC-1","fields":{"summary":5}}' run
rej jira-get-field jira-get '{"key":"ABC-1","fields":["assignee"]}' run
rej jira-get-str jira-get '{"key":"ABC-1","fields":"summary"}' run
rej jira-to jira-transition '{"key":"ABC-1","to":"Shipped"}' run
rej bad-tool test-report-push "{\"tool\":\"xray\",\"payload_path\":\"$RH/bodies/p\",\"dry_run\":true}" run
rej dry-str test-report-push "{\"tool\":\"zephyr\",\"payload_path\":\"$RH/bodies/p\",\"dry_run\":\"true\"}" run
rej bad-semver publish "{$G,\"package\":\"p\",\"version\":\"1.2\",\"step_id\":\"s\"}" run
# M3 jira-create: fields.parent refused, summary and issuetype required, parent iff not Epic
rej jc-fields-empty jira-create '{"parent":"ABC-1","fields":{}}' run
rej jc-fields-parent jira-create '{"parent":"ABC-1","fields":{"summary":"s","issuetype":"Task","parent":"ABC-2"}}' run
rej jc-epic-nosummary jira-create '{"fields":{"issuetype":"Epic"}}' run
rej jc-no-issuetype jira-create '{"parent":"ABC-1","fields":{"summary":"s"}}' run
rej jc-summary-num jira-create '{"parent":"ABC-1","fields":{"summary":1,"issuetype":"Task"}}' run
rej jc-epic-fparent jira-create '{"fields":{"summary":"s","issuetype":"Epic","parent":"ABC-2"}}' run
check "jc-msg fields.parent" "$(run "$RID" run jira-create "$(fx r '{"parent":"ABC-1","fields":{"summary":"s","issuetype":"Task","parent":"ABC-2"}}')"; echo "$ERRT")" "desk-req: schema: fields.parent not allowed"
reset; run "$RID" run jira-create "$(fx r '{"fields":{"summary":"s","issuetype":"Epic"}}')"; check "jc epic ok" "$RC" 0
reset; run "$RID" run jira-update "$(fx r '{"key":"ABC-1","fields":{"parent":"ABC-2"}}')"; check "jira-update partial ok" "$RC" 0
reset
# desk panel: semver as part B (no leading zeros), no leading - in package
rej semver-lead0 publish "{$G,\"package\":\"p\",\"version\":\"01.2.3\",\"step_id\":\"s\"}" run
rej semver-empty-pre publish "{$G,\"package\":\"p\",\"version\":\"1.2.3-\",\"step_id\":\"s\"}" run
rej semver-dotdot publish "{$G,\"package\":\"p\",\"version\":\"1.2.3-a..b\",\"step_id\":\"s\"}" run
rej package-dash publish "{$G,\"package\":\"-x\",\"version\":\"1.2.3\",\"step_id\":\"s\"}" run
rej package-scope-dash publish "{$G,\"package\":\"@a/-x\",\"version\":\"1.2.3\",\"step_id\":\"s\"}" run
reset; f=$(fx sv "{$G,\"package\":\"p\",\"version\":\"0.10.0-rc.1+b.7\",\"step_id\":\"s\"}")
run "$RID" run publish "$f"; check "semver full ok" "$RC" 0
reset
# M2: a trailing LF, CR, TAB or DEL in any regex-checked field is schema (jq "$" matches before a final LF)
B="\"branch\":\"ABC-1\""; E="\"expect_head\":\"$SHA\""
for c in '\n' '\r' '\t' '\u007f'; do
  rej "lf-repo $c" fetch "{\"repo\":\"$REPO$c\",\"ref\":\"main\"}"
  rej "lf-ref $c" fetch "{$G,\"ref\":\"main$c\"}"
  rej "lf-branch $c" push "{$G,\"branch\":\"ABC-1$c\",$E}"
  rej "lf-sha $c" push "{$G,$B,\"expect_head\":\"$SHA$c\"}"
  rej "lf-tag $c" tag-push "{$G,\"tag\":\"v1$c\",\"sha\":\"$SHA\",\"step_id\":\"s\"}" run
  rej "lf-step $c" tag-push "{$G,\"tag\":\"v1\",\"sha\":\"$SHA\",\"step_id\":\"s$c\"}" run
  rej "lf-key $c" jira-get "{\"key\":\"ABC-1$c\",\"fields\":[\"summary\"]}" run
  rej "lf-parent $c" jira-create "{\"parent\":\"ABC-1$c\",\"fields\":{\"summary\":\"s\",\"issuetype\":\"Task\"}}" run
  rej "lf-package $c" publish "{$G,\"package\":\"p$c\",\"version\":\"1.2.3\",\"step_id\":\"s\"}" run
  rej "lf-semver $c" publish "{$G,\"package\":\"p\",\"version\":\"1.2.3$c\",\"step_id\":\"s\"}" run
  rej "lf-label $c" pr-create "{$G,$B,\"base\":\"main\",\"body_path\":\"$RH/bodies/b\",\"labels\":[\"x$c\"],\"record_path\":\"$RH/review/st1/record-$SHA.md\",$E}"
  rej "lf-base $c" pr-create "{$G,$B,\"base\":\"main$c\",\"body_path\":\"$RH/bodies/b\",\"labels\":[],\"record_path\":\"$RH/review/st1/record-$SHA.md\",$E}"
  rej "lf-fsub $c" pr-merge "{$G,\"pr\":1,\"subtask\":\"st1$c\",\"method\":\"squash\",$E,\"predecessors\":[],\"record_path\":\"$RH/review/st1/record-$SHA.md\"}" run
  rej "lf-job $c" ci-logs "{$G,\"ci_run_id\":1,\"job\":\"build$c\"}"
  rej "lf-body $c" pr-comment "{$G,\"pr\":1,\"body_path\":\"$RH/bodies/c.md$c\"}"
done
rej conductor-st1 tag-push "{$G,\"tag\":\"v1\",\"sha\":\"$SHA\",\"step_id\":\"s\"}" st1
rej conductor-merge pr-merge "{$G,\"pr\":1,\"subtask\":\"st1\",\"method\":\"squash\",\"expect_head\":\"$SHA\",\"predecessors\":[],\"record_path\":\"$RH/review/st1/record-$SHA.md\"}" st1
rej body-outside pr-comment "{$G,\"pr\":1,\"body_path\":\"/etc/passwd\"}"
rej body-dotdot pr-comment "{$G,\"pr\":1,\"body_path\":\"$RH/bodies/../../x\"}"
rej body-relative pr-comment "{$G,\"pr\":1,\"body_path\":\"bodies/x\"}"
rej payload-review test-report-push "{\"tool\":\"zephyr\",\"payload_path\":\"$RH/review/p\",\"dry_run\":true}" run
rej record-name pr-merge "{$G,\"pr\":1,\"subtask\":\"st1\",\"method\":\"squash\",\"expect_head\":\"$SHA\",\"predecessors\":[],\"record_path\":\"$RH/review/st1/record-other.md\"}" run
rej record-dir pr-merge "{$G,\"pr\":1,\"subtask\":\"st1\",\"method\":\"squash\",\"expect_head\":\"$SHA\",\"predecessors\":[],\"record_path\":\"$RH/review/run/record-$SHA.md\"}" run
rej attach-outside pr-attach "{$G,\"pr\":1,\"paths\":[\"$RH/bodies/a.png\"]}"
rej attach-other-sub pr-attach "{$G,\"pr\":1,\"paths\":[\"$RH/st2/lanes/a.png\"]}"
mkdir -p "$T/out"; ln -s "$T/out" "$RH/bodies/link"
rej symlink-escape pr-comment "{$G,\"pr\":1,\"body_path\":\"$RH/bodies/link/x\"}"
ok1=$(fx ok1 "{$G,\"pr\":1}")
run bad_RUN st1 ci-status "$ok1"; sch run-id-upper
run "$RID" st1x ci-status "$ok1"; sch subtask-bad
run "$RID" st1 ci-status "$T/missing.json"; sch unreadable
run "$RID" st1 ci-status "$(fx nj 'not json')"; sch nonjson
run "$RID" st1 ci-status "$(fx arr '[1]')"; sch notobject
run nosuchrun st1 ci-status "$ok1"; sch no-run-home
run "$RID" st1 ci-status; check "usage rc" "$RC" 2
match "usage msg" "$ERRT" '^desk-req: usage'
OUT=$(env -u DELIVERY_ROOT "$SUT" "$RID" st1 ci-status "$ok1" 2>&1); check "unset rc" "$?" 2
check "unset msg" "$OUT" "INPUT-ERROR DELIVERY_ROOT unset"
OUT=$(DELIVERY_ROOT="rel/x" "$SUT" "$RID" st1 ci-status "$ok1" 2>&1); check "format rc" "$?" 2
check "format msg" "$OUT" "INPUT-ERROR DELIVERY_ROOT format"
OUT=$(RUN_HOME=/nonexistent DELIVERY_ROOT="$DELIVERY_ROOT" "$SUT" "$RID" st1 ci-status "$ok1" 2>/dev/null); check "RUN_HOME ignored" "$?" 0

# --- path-root canonicalization: a desk TMPDIR is /var/folders/.../T/ (trailing slash, /var -> /private/var) -------
mkdir -p "$T/real"; ln -s "$T/real" "$T/lnk"
canon() { # name delivery-root body-path-prefix want-rc (the run dir is $T/real/root/$RID)
  rm -rf "$T/real/root"; mkdir -p "$T/real/root/$RID/review/st1" "$T/real/root/$RID/bodies"
  local f; f=$(fx "$1" "{\"repo\":\"$REPO\",\"pr\":7,\"body_path\":\"$3/bodies/c.md\"}")
  OUT=$(DELIVERY_ROOT="$2" "$SUT" "$RID" st1 pr-comment "$f" 2>"$T/err"); RC=$?; ERRT=$(cat "$T/err")
  check "canon $1 rc" "$RC" "$4"
  [ "$4" = 0 ] || match "canon $1 msg" "$ERRT" 'desk-req: schema: body_path root'
}
canon doubled-slash   "$T//real/root"   "$T//real/root/$RID" 0
canon trailing-root   "$T/real/root/"   "$T/real/root/$RID"  0
canon trailing-both   "$T/real/root//"  "$T/real/root/$RID/" 0
canon symlink-root    "$T/lnk/root"     "$T/real/root/$RID"  0
canon symlink-cand    "$T/real/root"    "$T/lnk/root/$RID"   0
canon symlink-both    "$T/lnk/root/"    "$T/lnk//root/$RID"  0
canon outside-via-lnk "$T/lnk/root"     "$T/lnk/other"       2
canon dotdot-via-lnk  "$T/lnk/root"     "$T/lnk/root/$RID/../x" 2
rm -f "$T/lnk"
# --- lock ------------------------------------------------------------------
reset; mkdir -p "$RH/desk/.lock"
export DL_LOCK_TIMEOUT=2 DL_LOCK_INTERVAL=0.2
printf '%s 20261026T000000Z\n' "$$" > "$RH/desk/.lock/owner"
run "$RID" st1 ci-status "$ok1"; check "live holder rc" "$RC" 4
check "live holder kept" "$(cat "$RH/desk/.lock/owner")" "$$ 20261026T000000Z"
sleep 0 & dead=$!; wait $dead
printf '%s 20261026T000000Z\n' "$dead" > "$RH/desk/.lock/owner"
run "$RID" st1 ci-status "$ok1"; check "dead pid broken rc" "$RC" 0
check "dead lock gone" "$([ -e "$RH/desk/.lock" ] && echo y || echo n)" n
check "broken dir removed" "$(ls -a "$RH/desk" | grep -c 'broken')" 0
rm -rf "$RH/desk/.lock"; mkdir "$RH/desk/.lock"
run "$RID" st1 ci-status "$ok1"; check "fresh ownerless rc" "$RC" 4
touch -t 202001010000 "$RH/desk/.lock"
run "$RID" st1 ci-status "$ok1"; check "old ownerless broken" "$RC" 0
rm -rf "$RH/desk/.lock"; mkdir "$RH/desk/.lock"; echo garbage > "$RH/desk/.lock/owner"
touch -t 202001010000 "$RH/desk/.lock"
run "$RID" st1 ci-status "$ok1"; check "old unparsable broken" "$RC" 0
unset DL_LOCK_TIMEOUT DL_LOCK_INTERVAL

# --- existing name never overwritten; no banned builtins ---------------------
reset
run "$RID" st1 ci-status "$ok1"
req=$(printf '%s' "$OUT" | cut -d'|' -f3 | tr -d ' ')
before=$(shasum -a 256 "$req")
run "$RID" st1 ci-status "$ok1"
check "second differs" "$([ "$OUT" = "" ] && echo empty || echo ok)" ok
check "first intact" "$(shasum -a 256 "$req")" "$before"
if /usr/bin/grep -nE '(^|[^a-zA-Z_-])(flock|mapfile|readarray|gtimeout|sha256sum)([^a-zA-Z_-]|$)|readlink -f|sed -i|date -d|du -b|declare -A' "$HERE/desk-req.sh" "$HERE/desk-req-schema.sh" >/dev/null; then no "banned builtin"; else ok; fi

echo "desk-req tests: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
