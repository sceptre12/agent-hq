#!/usr/bin/env bash
# tools/hermes/test_check-config.sh — tests for tools/hermes/setup/check-config and required-config.tsv.
# Hermetic: the fixture is config.active.yaml with __HOME__ -> a mktemp fixture home, HOME points there, and check-config
# runs under `env -i`. No network, no real HERMES_HOME, no Hermes code. bash 3.2 compatible.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SETUP="$HERE/setup"
CC="$SETUP/check-config"; TSV="$SETUP/required-config.tsv"; ACTIVE="$SETUP/config.active.yaml"
_tb="${TMPDIR:-/tmp}"; FX="$(mktemp -d "${_tb%/}/test_check-config.XXXXXX")" || { echo "FAIL: mktemp -d"; exit 1; }
trap 'chmod -R u+rwx "$FX" 2>/dev/null; rm -rf "$FX"' EXIT
passed=0; failed=0
pass() { echo "PASS: $1"; passed=$((passed + 1)); }
fail() { echo "FAIL: $1"; failed=$((failed + 1)); }
eq() { if [ "$2" = "$3" ]; then pass "$1"; else fail "$1 (got '$2', want '$3')"; fi; }
has() { case "$2" in *"$3"*) pass "$1" ;; *) fail "$1 (no '$3' in: $2)" ;; esac; }

FH="$FX/home"; mkdir -p "$FH"
sed "s|__HOME__|$FH|g" "$ACTIVE" >"$FH/config.yaml"
# run <yaml> [extra args...]: sets $out and $rc
run() { local y="$1"; shift; out="$(env -i PATH=/usr/bin:/bin HOME="$FH" /usr/bin/python3 -I "$CC" --yaml "$y" "$@" 2>/dev/null)"; rc=$?; }
NROWS="$(grep -cv -e '^#' -e '^[[:space:]]*$' "$TSV" | tr -d ' ')"
NCHK=$((NROWS + 1))

# --- 1. the fixture passes every row
run "$FH/config.yaml"
eq "fixture: exit 0" "$rc" 0
eq "fixture: last line" "$(printf '%s\n' "$out" | tail -n 1)" "CHECK-CONFIG: PASS n=$NCHK"
eq "fixture: no FAIL lines" "$(printf '%s\n' "$out" | grep -c '^FAIL' | tr -d ' ')" 0
eq "fixture: one PASS per TSV row + no-always" "$(printf '%s\n' "$out" | grep -c '^PASS' | tr -d ' ')" "$NCHK"
has "fixture: hook file skipped without --home or HERMES_HOME" "$out" 'SKIP hook-file (no --home or $HERMES_HOME)'
run "$FH/config.yaml" --home "$FH"
has "fixture --home: hook file absent is skipped" "$out" "SKIP hook-file (not present)"
eq "fixture --home: exit 0" "$rc" 0

# --- hook file checks (--home and the hook present)
HP="$FH/claude-profiles/hermes/bin/pre-tool-call.sh"; mkdir -p "${HP%/*}"; printf '#!/bin/sh\n' >"$HP"
chmod 555 "$HP"; run "$FH/config.yaml" --home "$FH"
has "hook 555: PASS hook-mode" "$out" "PASS hook-mode"; eq "hook 555: exit 0" "$rc" 0
chmod 755 "$HP"; run "$FH/config.yaml" --home "$FH"
has "hook 755: FAIL hook-mode" "$out" "FAIL hook-mode"; eq "hook 755: exit 1" "$rc" 1
# M3: $HERMES_HOME alone (no --home, no --yaml) runs the hook checks too
chmod 555 "$HP"
out="$(env -i PATH=/usr/bin:/bin HOME="$FH" HERMES_HOME="$FH" /usr/bin/python3 -I "$CC" 2>/dev/null)"; rc=$?
eq "HERMES_HOME only: exit 0" "$rc" 0; has "HERMES_HOME only: PASS hook-mode" "$out" "PASS hook-mode"
eq "HERMES_HOME only: last line" "$(printf '%s\n' "$out" | tail -n 1)" "CHECK-CONFIG: PASS n=$((NCHK + 2))"
rm -f "$HP"

# --- 2. mutations: each fails exactly its own row
# mutate <name> <want-failing-key> <sed-expression>
mutate() {
  local f="$FX/m.yaml" fl
  sed "$3" "$FH/config.yaml" >"$f"
  if cmp -s "$f" "$FH/config.yaml"; then fail "$1: mutation did not change the fixture"; return; fi
  run "$f"
  fl="$(printf '%s\n' "$out" | grep '^FAIL' | sed 's/^FAIL \([^:]*\):.*/\1/' | tr '\n' ' ')"
  eq "$1: fails exactly $2" "$fl" "$2 "
  eq "$1: exit 1" "$rc" 1
  has "$1: summary line" "$(printf '%s\n' "$out" | tail -n 1)" "CHECK-CONFIG: FAIL failed=1 of $NCHK"
}
mutate "drop terminal toolset" agent.disabled_toolsets 's/disabled_toolsets: \[terminal, /disabled_toolsets: [/'
mutate "extra toolset" agent.disabled_toolsets 's/discord_admin\]/discord_admin, memory]/'
mutate "memory.write_approval true" memory.write_approval '/^memory:/,/^[a-z]/s/  write_approval: false/  write_approval: true/'
mutate "unattended_mode allow" approvals.unattended_mode 's/unattended_mode: deny/unattended_mode: allow/'
mutate "mcp_servers with a server" mcp_servers 's/^mcp_servers: {}/mcp_servers:\
  extra:\
    command: "x"/'
mutate "hook fail_closed false" hooks.pre_tool_call 's/fail_closed: true/fail_closed: false/'
mutate "hook command path differs" hooks.pre_tool_call 's|bin/pre-tool-call.sh|bin/other.sh|'
mutate "always on a data line" no-always 's/busy_input_mode: interrupt/busy_input_mode: always/'
mutate "quoted true is not bool true" memory.memory_enabled 's/memory_enabled: true/memory_enabled: "true"/'
mutate "curator enabled true" curator.enabled '/^curator:/,/^[a-z]/s/  enabled: false/  enabled: true/'
mutate "curator block deleted (unset = curator on)" curator.enabled '/^curator:/{N;d;}'
mutate "curator: true (non-mapping parent)" curator.enabled '/^curator:/{N;s/.*/curator: true/;}'
has "non-mapping parent: shape scalar" "$out" "FAIL curator.enabled: want eq false, got scalar"
# A3: unset-or-eq also FAILs when the parent exists but is not a mapping
printf 'x.y\tunset-or-eq\tfalse\n' >"$FX/u.tsv"; printf 'x: true\n' >"$FX/u.yaml"; run "$FX/u.yaml" --tsv "$FX/u.tsv"
eq "unset-or-eq, scalar parent: exit 1" "$rc" 1; has "unset-or-eq, scalar parent: FAIL" "$out" "FAIL x.y: want unset-or-eq false, got scalar"
# M1: a live value is never echoed on FAIL (only its shape; set-eq names come from the expected set only)
mutate "secret as extra toolset" agent.disabled_toolsets 's/discord_admin\]/discord_admin, sk-ant-ZZZ]/'
eq "secret toolset: not echoed" "$(printf '%s\n' "$out" | grep -c 'sk-ant-ZZZ' | tr -d ' ')" 0
has "secret toolset: extra count" "$out" "missing [] extra n=1"
mutate "secret as model.provider" model.provider '/^model:/,/^[a-z]/s/  provider: "anthropic"/  provider: "sk-ant-ZZZ"/'
eq "secret provider: not echoed" "$(printf '%s\n' "$out" | grep -c 'sk-ant-ZZZ' | tr -d ' ')" 0
has "secret provider: shape only" "$out" "FAIL model.provider: want eq anthropic, got scalar"
# failClosed spelling is accepted
sed 's/fail_closed: true/failClosed: true/' "$FH/config.yaml" >"$FX/fc.yaml"; run "$FX/fc.yaml"
eq "failClosed spelling accepted: exit 0" "$rc" 0
# `always` inside a comment does not count
sed 's/busy_input_mode: interrupt/busy_input_mode: interrupt  # always ask/' "$FH/config.yaml" >"$FX/c.yaml"; run "$FX/c.yaml"
eq "always in a comment: exit 0" "$rc" 0; has "always in a comment: PASS no-always" "$out" "PASS no-always"
# secrets: a server's keys/values are never echoed
sed 's/^mcp_servers: {}/mcp_servers:\
  s1:\
    token: "SEKRETVALUE123"/' "$FH/config.yaml" >"$FX/s.yaml"; run "$FX/s.yaml"
case "$out" in *SEKRET*|*s1*) fail "mcp_servers contents echoed";; *) pass "mcp_servers contents not echoed";; esac

# --- 3. parse and read errors
printf 'agent:\n\tdisabled_toolsets: []\n' >"$FX/tab.yaml"; run "$FX/tab.yaml"
eq "tab indent: exit 2" "$rc" 2; has "tab indent: UNPARSEABLE" "$out" "UNPARSEABLE line 2:"
printf 'a: 1\na: 2\n' >"$FX/dup.yaml"; run "$FX/dup.yaml"
eq "duplicate key: exit 2" "$rc" 2; has "duplicate key: UNPARSEABLE" "$out" "UNPARSEABLE line 2:"
printf 'a: &x 1\n' >"$FX/anc.yaml"; run "$FX/anc.yaml"; eq "anchor: exit 2" "$rc" 2
printf 'a: [x,\n  y]\n' >"$FX/ml.yaml"; run "$FX/ml.yaml"; eq "multi-line flow list: exit 2" "$rc" 2
run "$FX/nope.yaml"; eq "missing yaml: exit 3" "$rc" 3
run "$FH/config.yaml" --tsv "$FX/nope.tsv"; eq "missing tsv: exit 3" "$rc" 3
out="$(env -i PATH=/usr/bin:/bin HOME="$FH" /usr/bin/python3 -I "$CC" 2>&1)"; rc=$?; eq "no home/yaml: exit 2" "$rc" 2

# --- 4. --help
out="$(env -i PATH=/usr/bin:/bin /usr/bin/python3 -I "$CC" --help 2>&1)"; rc=$?
eq "--help: exit 0" "$rc" 0; has "--help: shows the invocation" "$out" "/usr/bin/python3 -I tools/hermes/setup/check-config"

# --- 5. consistency: TSV toolsets == hermes-up GW_TOOLSETS == config.active.yaml:86
norm() { tr -d '[]' | tr ', ' '\n\n' | grep -v '^$' | LC_ALL=C sort; }
t_tsv="$(awk -F'\t' '$1=="agent.disabled_toolsets"{print $3}' "$TSV" | norm)"
t_gw="$(sed -n 's/^GW_TOOLSETS="\(.*\)"$/\1/p' "$SETUP/hermes-up" | norm)"
t_yaml="$(sed -n '86s/^  disabled_toolsets: //p' "$ACTIVE" | norm)"
eq "toolsets: 25 names in the TSV" "$(printf '%s\n' "$t_tsv" | grep -c . | tr -d ' ')" 25
eq "toolsets: TSV == hermes-up GW_TOOLSETS" "$t_tsv" "$t_gw"
eq "toolsets: TSV == config.active.yaml:86" "$t_tsv" "$t_yaml"

# --- 6. file length
for f in "$CC" "$TSV" "$HERE/test_check-config.sh"; do
  n="$(wc -l <"$f" | tr -d ' ')"
  if [ "$n" -le 300 ]; then pass "${f##*/} is $n <= 300 lines"; else fail "${f##*/} is $n > 300 lines"; fi
done

echo "=== check-config: $passed passed, $failed failed ==="; [ "$failed" = 0 ]
