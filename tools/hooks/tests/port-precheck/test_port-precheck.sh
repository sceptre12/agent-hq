#!/usr/bin/env bash
# tools/hooks/tests/port-precheck/test_port-precheck.sh — tests for tools/hooks/port-precheck.sh (PreToolUse(Bash) port-clash check).
# Hermetic: the table, the port-check.sh helper and `lsof` are fixtures (PORT_PRECHECK_TABLE, PORT_PRECHECK_PORT_CHECK_SH, a stub
# lsof first on PATH), so no real listener, registry or network is read. The hook's contract is the oracle: it ALWAYS exits 0, it
# decides with lsof only (port-check.sh's exit code is discarded), and it is silent unless a resolved port is genuinely listening.
# No `ps`, no flock; bash 3.2 / BSD userland; every temp dir is a templated mktemp under TMPDIR.
# Provenance: written for the agent-hq port (the hq hook had no test). Ported into agent-hq 2026-10-26 (delivery workflow, port guard).
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK="${PORT_PRECHECK_UNDER_TEST:-${HERE}/../../port-precheck.sh}"
_tb="${TMPDIR:-/tmp}"; FX="$(mktemp -d "${_tb%/}/test_port-precheck.XXXXXX")" || { echo "FAIL: mktemp -d"; exit 1; }
trap 'rm -rf "$FX"' EXIT
passed=0; failed=0
pass() { echo "PASS: $1"; passed=$((passed + 1)); }
fail() { echo "FAIL: $1"; failed=$((failed + 1)); }
eq() { if [ "$2" = "$3" ]; then pass "$1"; else fail "$1 (got '$2', want '$3')"; fi; }
has() { case "$2" in *"$3"*) pass "$1" ;; *) fail "$1 (no '$3' in: $2)" ;; esac; }
silent() { if [ -z "$2" ]; then pass "$1"; else fail "$1 (expected no output, got: $2)"; fi; }
command -v jq >/dev/null || { echo "FAIL: jq required (the hook is silent without it, so nothing could be tested)"; exit 1; }

LIVE=58441                       # the port the stub lsof reports as LISTENING; every other port is free
mkdir -p "$FX/bin" "$FX/nolsof"
printf '#!/bin/sh\ncase "$*" in *"-iTCP:%s "*|*"-iTCP:%s") exit 0 ;; esac\nexit 1\n' "$LIVE" "$LIVE" >"$FX/bin/lsof"; chmod 755 "$FX/bin/lsof"
printf '#!/bin/sh\necho "port-check: $1"\necho "registry (host-side): HIT"\necho "  [claimed] port=$1 service=fixture-svc project=fixture"\nexit 2\n' >"$FX/pc.sh"; chmod 755 "$FX/pc.sh"
TAB="$(printf '\t')"
printf '#match_dir\tmatch_cmd\tports\tservice\tsource\n*\trun-fixture-app\t%s,60001\tfixture app\tfixture:1\n/fx/proj\tserve-it\t%s-%s\tfixture range\tfixture:2\n' "$LIVE" "$LIVE" "$((LIVE + 5))" >"$FX/table.tsv"

payload() { jq -cn --arg c "$1" --arg d "${2-}" --arg t "${3-Bash}" '{tool_name:$t, tool_input:{command:$c}, cwd:$d}'; }
# run <payload> [VAR=val ...]: out = stdout, rc = exit code
run() { local p="$1"; shift; out="$(printf '%s' "$p" | env PATH="$FX/bin:/usr/bin:/bin" HOME="$FX/home" PORT_PRECHECK_TABLE="$FX/table.tsv" PORT_PRECHECK_PORT_CHECK_SH="$FX/pc.sh" "$@" "$HOOK" 2>/dev/null)"; rc=$?; }

# 1. table match, port listening -> ask, naming the registry holder from port-check.sh (its exit code 2 is discarded)
run "$(payload 'run-fixture-app --foo' /anywhere)"
eq "table match + live port: exit 0" "$rc" 0
has "table match + live port: permissionDecision ask" "$out" '"permissionDecision": "ask"'
has "table match + live port: names the port" "$out" "port $LIVE"
has "table match + live port: holder named by port-check.sh output" "$out" "[claimed] port=$LIVE service=fixture-svc"
eq "table match + live port: hookEventName PreToolUse" "$(printf '%s' "$out" | jq -r '.hookSpecificOutput.hookEventName')" PreToolUse

# 2. silent cases: all exit 0 with no output
run "$(payload 'run-fixture-app --foo' /anywhere)" PORT_PRECHECK_PORT_CHECK_SH=/nonexistent; has "missing helper: falls back to the table service name" "$out" "fixture app"; eq "missing helper: exit 0" "$rc" 0
run "$(payload 'ls -la')"; eq "unrelated command: exit 0" "$rc" 0; silent "unrelated command: silent" "$out"
run "$(payload 'run-fixture-app' /anywhere Edit)"; eq "non-Bash tool: exit 0" "$rc" 0; silent "non-Bash tool: silent" "$out"
run ''; eq "empty payload: exit 0" "$rc" 0; silent "empty payload: silent" "$out"
run 'not json at all'; eq "invalid JSON payload: exit 0" "$rc" 0; silent "invalid JSON payload: silent" "$out"
run "$(payload 'run-fixture-app' /anywhere)" PORT_PRECHECK_TABLE="$FX/missing.tsv"; eq "unreadable table: exit 0" "$rc" 0; silent "unreadable table: silent" "$out"
printf '#match_dir\tmatch_cmd\tports\tservice\tsource\n*\tother-app\t%s\tx\ty\n' "$LIVE" >"$FX/t2.tsv"
run "$(payload 'run-fixture-app' /anywhere)" PORT_PRECHECK_TABLE="$FX/t2.tsv"; silent "table row whose command does not match: silent" "$out"
printf '#match_dir\tmatch_cmd\tports\tservice\tsource\n*\trun-fixture-app\t60002\tx\ty\n' >"$FX/t3.tsv"
run "$(payload 'run-fixture-app' /anywhere)" PORT_PRECHECK_TABLE="$FX/t3.tsv"; eq "matched row, port not listening: exit 0" "$rc" 0; silent "matched row, port not listening: silent" "$out"

# 3. directory matching (cwd under the dir, under <dir>-worktrees, or `cd <dir>` in the command)
run "$(payload 'serve-it' /fx/proj/sub)"; has "cwd under match_dir: ask" "$out" '"permissionDecision": "ask"'
run "$(payload 'serve-it' /fx/proj-worktrees/wt1)"; has "cwd under <match_dir>-worktrees: ask" "$out" '"permissionDecision": "ask"'
run "$(payload 'cd /fx/proj && serve-it' /elsewhere)"; has "cd <match_dir> in the command: ask" "$out" '"permissionDecision": "ask"'
run "$(payload 'serve-it' /elsewhere)"; silent "cwd outside match_dir: silent" "$out"
run "$(payload 'serve-it' /fx/projx)"; silent "sibling dir sharing the prefix: silent" "$out"

# 4. ranges check the FIRST port only
printf '#match_dir\tmatch_cmd\tports\tservice\tsource\n*\trange-app\t%s-%s\trange svc\ty\n' "$((LIVE + 1))" "$((LIVE + 9))" >"$FX/t4.tsv"
run "$(payload 'range-app' /x)" PORT_PRECHECK_TABLE="$FX/t4.tsv"; silent "range whose first port is free (a later port is live): silent" "$out"

# 5. literal ports on the command line (empty table so only the command line matters)
printf '#match_dir\tmatch_cmd\tports\tservice\tsource\n' >"$FX/empty.tsv"
lit() { run "$(payload "$1" /x)" PORT_PRECHECK_TABLE="$FX/empty.tsv" PORT_PRECHECK_PORT_CHECK_SH=/nonexistent; }   # no helper: the hint names the source
lit "npm run dev --port $LIVE"; has "--port N: ask" "$out" "--port on command line"
lit "npm run dev --port=$LIVE"; has "--port=N: ask" "$out" "--port on command line"
lit "PORT=$LIVE node server.js"; has "PORT=N: ask" "$out" "PORT= on command line"
lit "docker run -p $LIVE:80 img"; has "docker run -p HOST:CONTAINER (host side): ask" "$out" "-p on command line"
lit "docker run -p 80:$LIVE img"; silent "docker run -p: the container side is not checked" "$out"
lit "ssh -p $LIVE host"; silent "bare -p outside a docker run gate (ssh): silent" "$out"
lit "psql -p $LIVE db"; silent "bare -p outside a docker run gate (psql): silent" "$out"
lit "npm run dev --port 60003"; eq "--port N on a free port: exit 0" "$rc" 0; silent "--port N on a free port: silent" "$out"

# 6. no jq / no lsof / no tools -> silent allow, still exit 0 (a failing hook would block every Bash call)
mkdir -p "$FX/onlylsof"; cp "$FX/bin/lsof" "$FX/onlylsof/lsof"
out="$(payload 'run-fixture-app' /x | env PATH="$FX/onlylsof" HOME="$FX/home" PORT_PRECHECK_TABLE="$FX/table.tsv" /bin/bash "$HOOK" 2>/dev/null)"; rc=$?
eq "no jq on PATH: exit 0" "$rc" 0; silent "no jq on PATH: silent" "$out"
mkdir -p "$FX/nojq"; for b in cat dirname jq; do [ -x "/usr/bin/$b" ] && cp "/usr/bin/$b" "$FX/nojq/$b" 2>/dev/null; done
out="$(payload 'run-fixture-app' /x | env PATH="$FX/nojq" HOME="$FX/home" PORT_PRECHECK_TABLE="$FX/table.tsv" /bin/bash "$HOOK" 2>/dev/null)"; rc=$?
eq "no lsof on PATH: exit 0" "$rc" 0; silent "no lsof on PATH: silent" "$out"

# 7. static properties of the script itself
SRC="$(cat "$HOOK")"
if grep -nE '^[[:space:]]*set[[:space:]]+-[A-Za-z]*e' "$HOOK" >/dev/null; then fail "hook must never use set -e"; else pass "hook does not use set -e"; fi
if grep -nE 'grep[^|]* -[A-Za-z]*P' "$HOOK" | grep -v '^[0-9]*:[[:space:]]*#' >/dev/null; then fail "hook uses grep -P"; else pass "hook uses no grep -P"; fi
if grep -nE '(^|[^a-z.])grep ' "$HOOK" | grep -v 'command grep' | grep -v '^[0-9]*:[[:space:]]*#' >/dev/null; then fail "hook has a bare grep"; else pass "hook uses only 'command grep'"; fi
bash -n "$HOOK" && pass "bash -n clean" || fail "bash -n failed"

echo "=== port-precheck: $passed passed, $failed failed ==="; [ "$failed" = 0 ]
