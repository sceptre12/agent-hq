#!/usr/bin/env bash
# tools/hermes/test_hermes-setup.sh — tests for tools/hermes/setup/ (hermes-gw, hermes-up, pre-tool-call.sh, seed-hook-allowlist,
# the plist example and the file set). Hermetic: HOME points into a templated mktemp dir and every script runs under `env -i`; no
# network, no real HERMES_HOME, no Hermes process. hermes-up is only driven up to its first refusals (it dies before any git,
# python or hermes call can reach a real tree). The seed helper's success path needs `ps`; where /bin/ps is unusable that part is
# SKIPped (printed, not counted) and only its refusals are tested.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SETUP="$HERE/setup"
_tb="${TMPDIR:-/tmp}"; FX="$(mktemp -d "${_tb%/}/test_hermes-setup.XXXXXX")" || { echo "FAIL: mktemp -d"; exit 1; }
trap 'chmod -R u+rwx "$FX" 2>/dev/null; rm -rf "$FX"' EXIT
passed=0; failed=0
pass() { echo "PASS: $1"; passed=$((passed + 1)); }
fail() { echo "FAIL: $1"; failed=$((failed + 1)); }
eq() { if [ "$2" = "$3" ]; then pass "$1"; else fail "$1 (got '$2', want '$3')"; fi; }
has() { case "$2" in *"$3"*) pass "$1" ;; *) fail "$1 (no '$3' in: $2)" ;; esac; }
hasnt() { case "$2" in *"$3"*) fail "$1 (found '$3' in: $2)" ;; *) pass "$1" ;; esac; }
ENVI=(env -i PATH=/usr/bin:/bin)

# --- 1. syntax of every script (zsh scripts: zsh -n; the python helper: ast.parse)
for s in hermes-gw hermes-up pre-tool-call.sh; do
  if zsh -n "$SETUP/$s" 2>/dev/null; then pass "zsh -n $s"; else fail "zsh -n $s"; fi
  [ -x "$SETUP/$s" ] && pass "$s is executable" || fail "$s is not executable"
done
if /usr/bin/python3 -I -c 'import ast,sys; ast.parse(open(sys.argv[1]).read())' "$SETUP/seed-hook-allowlist" 2>/dev/null; then pass "ast.parse seed-hook-allowlist"; else fail "ast.parse seed-hook-allowlist"; fi
[ -x "$SETUP/seed-hook-allowlist" ] && pass "seed-hook-allowlist is executable" || fail "seed-hook-allowlist is not executable"

# --- 2. the pinned hook hash matches the copied hook
pin="$(sed -n 's/^HOOK_SHA256 = "\(.*\)"$/\1/p' "$SETUP/seed-hook-allowlist")"
eq "seed-hook-allowlist pins the sha256 of pre-tool-call.sh" "$pin" "$(shasum -a 256 <"$SETUP/pre-tool-call.sh" | cut -d' ' -f1)"

# --- 3. no secret-shaped strings or personal strings in any setup file (with a positive control for the scanner)
PERS="xav""ier|scep""tre12|hermes""Auth|/Us""ers/|/ho""me/[a-z]"   # built from pieces: the repo must hold no literal personal strings
scan() { # scan <file>: prints matching lines; rc 0 = at least one hit
  command grep -nE -e 'sk-ant-[A-Za-z0-9_-]{10,}' -e 'AKIA[0-9A-Z]{16}' -e 'gh[pousr]_[A-Za-z0-9]{20,}' -e 'github_pat_' \
    -e 'xox[abprs]-[A-Za-z0-9-]{10,}' -e '-----BEG''IN [A-Z ]*PRIV''ATE KEY-----' "$1"
  command grep -nEi -e '(API_?KEY|TOKEN|SECRET|PASSWORD)[A-Z_]*[[:space:]]*[:=][[:space:]]*["'"'"']?[A-Za-z0-9+/_.=-]{20,}' \
    -e "$PERS" "$1"
}
k=0; mkdir -p "$FX/scan"
for fake in "AK""IA""ABCDEFGHIJKLMNOP" "sk-""ant-api03-abcdefghijklmnop" "ghp""_abcdefghijklmnopqrstuvwxyz1234" "-----BE""GIN RSA PRIV""ATE KEY-----" \
            "API_KEY=abcdefghijklmnopqrstuvwxyz" "/Us""ers/someone/x" "hermes""Auth"; do
  k=$((k + 1)); printf '%s\n' "$fake" >"$FX/scan/c$k"
  if [ -n "$(scan "$FX/scan/c$k")" ]; then :; else fail "scanner positive control $k not flagged"; fi
done
pass "scanner flags all $k fake secret/personal strings"
hits=""; while IFS= read -r f; do h="$(scan "$f")"; [ -z "$h" ] || hits="$hits$f: $h"$'\n'; done < <(find "$SETUP" -type f)
if [ -z "$hits" ]; then pass "no secret-shaped or personal strings in tools/hermes/setup/"; else fail "setup hits: $hits"; fi
for bad in auth.json .env api-key pairing state.db; do
  [ -z "$(find "$SETUP" -iname "*$bad*")" ] && pass "no $bad file under setup/" || fail "setup/ holds a $bad file"
done

# --- 4. plist: only the two placeholders, no absolute home path, lints after substitution
P="$SETUP/hermes-up.plist.example"
eq "plist placeholders are exactly __HOME__ and __LABEL__" "$(command grep -o '__[A-Z_]*__' "$P" | sort -u | tr '\n' ' ')" "__HOME__ __LABEL__ "
hasnt "plist has no absolute home path" "$(cat "$P")" "/Us""ers/"
hasnt "plist has no /home/ path" "$(cat "$P")" "/home/"
if command -v plutil >/dev/null; then
  sed -e 's|__HOME__|/tmp/hermes-test-home|g' -e 's|__LABEL__|local.test.hermes-up|g' "$P" >"$FX/hermes-up.plist"
  if plutil -lint "$FX/hermes-up.plist" >/dev/null 2>&1; then pass "plist lints after placeholder substitution"; else fail "plist does not lint"; fi
else echo "SKIP (not counted): plutil unavailable"; fi

# --- 5. hermes-up refuses without the required env (never reaching git, python or hermes)
FH="$FX/home"; H="$FH/claude-profiles/hermes"; HH="$H/h1-home"; mkdir -p "$FH"
up() { out="$("${ENVI[@]}" HOME="$FH" "$@" 2>&1)"; rc=$?; }
up "$SETUP/hermes-up"; eq "up: no HERMES_HOME: rc 1" "$rc" 1; has "up: no HERMES_HOME: reason" "$out" "refused: HERMES_HOME not set"
up "$SETUP/hermes-up" gateway run; eq "up gateway: no HERMES_HOME: rc 0 (parks the LaunchAgent)" "$rc" 0; has "up gateway: reason" "$out" "gateway refused: HERMES_HOME not set"
up HERMES_HOME="$FX/elsewhere" "$SETUP/hermes-up"; eq "up: wrong HERMES_HOME: rc 1" "$rc" 1; has "up: wrong HERMES_HOME: reason" "$out" "HERMES_HOME is not $HH"
up HERMES_HOME="$HH" "$SETUP/hermes-up"; eq "up: missing dir: rc 1" "$rc" 1; has "up: missing dir: reason" "$out" "HERMES_HOME dir missing"
mkdir -p "$HH"; chmod 755 "$HH"; up HERMES_HOME="$HH" "$SETUP/hermes-up"; has "up: mode 755 refused" "$out" "HERMES_HOME mode not 700"
chmod 700 "$HH"; up HERMES_HOME="$HH" "$SETUP/hermes-up"; eq "up: no token in env: rc 1" "$rc" 1; has "up: no token: reason" "$out" "CLAUDE_CODE_OAUTH_TOKEN missing from env"
up HERMES_HOME="$HH" CLAUDE_CODE_OAUTH_TOKEN=dummy-not-a-credential "$SETUP/hermes-up"; eq "up: no code dir: rc 1, stops before hermes" "$rc" 1; has "up: no code dir: reason" "$out" "cannot read code sha"

# --- 6. hermes-gw: refusals exit 0; the token reaches hermes-up through the environment only
mkdir -p "$H/bin" "$FH/claude-profiles/<auth-profile>"; TOK="$FH/claude-profiles/<auth-profile>/token"
printf '#!/bin/sh\nprintf "stub-up args=%%s token_set=%%s\\n" "$*" "${CLAUDE_CODE_OAUTH_TOKEN:+1}"\n' >"$H/bin/hermes-up"; chmod 755 "$H/bin/hermes-up"
eq "gw: the placeholder appears exactly 3 times in code lines" "$(command grep -v '^#' "$SETUP/hermes-gw" | command grep -o '<auth-profile>' | wc -l | tr -d ' ')" 3
up "$SETUP/hermes-gw"; eq "gw: no HERMES_HOME: rc 0" "$rc" 0; has "gw: no HERMES_HOME: reason" "$out" "hermes-gw: HERMES_HOME is not $HH"
up HERMES_HOME="$HH" "$SETUP/hermes-gw"; eq "gw: no token file: rc 0" "$rc" 0; has "gw: no token file: reason" "$out" "TOKFILE missing or not a regular file"
printf 'dummy-not-a-credential\n' >"$TOK"; chmod 644 "$TOK"; up HERMES_HOME="$HH" "$SETUP/hermes-gw"; has "gw: mode 644 refused" "$out" "TOKFILE mode is not 600 or 400"
: >"$TOK"; chmod 600 "$TOK"; up HERMES_HOME="$HH" "$SETUP/hermes-gw"; has "gw: empty token refused" "$out" "TOKFILE empty"
printf 'dummy-not-a-credential\n' >"$TOK"; chmod 600 "$TOK"; up HERMES_HOME="$HH" "$SETUP/hermes-gw"
eq "gw: valid token file: rc 0" "$rc" 0; has "gw: execs hermes-up with exactly 'gateway run' and the token in env" "$out" "stub-up args=gateway run token_set=1"
hasnt "gw: the token value is never printed" "$out" "dummy-not-a-credential"

# --- 7. pre-tool-call.sh decisions (python3 -I, fixture HERMES_HOME only)
HK="$FX/hook"; mkdir -p "$HK/hh/work" "$HK/home"; chmod 700 "$HK/hh"
hook() { out="$(printf '%s' "$1" | "${ENVI[@]}" HOME="$HK/home" ${2-HERMES_HOME="$HK/hh"} "$SETUP/pre-tool-call.sh" 2>&1)"; rc=$?; }
hook '{"tool_name":"write_file","tool_input":{"path":"work/a.txt"},"cwd":"'"$HK/hh"'"}'; eq "hook: write under work/: allowed (rc 0)" "$rc" 0
hook '{"tool_name":"write_file","tool_input":{"path":"'"$FX"'/other.txt"},"cwd":"'"$HK/hh"'"}'; eq "hook: write outside work/: blocked (rc 2)" "$rc" 2; has "hook: write outside: reason" "$out" "write outside HERMES_HOME/work"
hook '{"tool_name":"read_file","tool_input":{"path":".env"},"cwd":"'"$HK/hh"'"}'; eq "hook: read .env: blocked (rc 2)" "$rc" 2; has "hook: read .env: reason" "$out" "denied path"
hook '{"tool_name":"search_files","tool_input":{"path":"'"$HK"'"},"cwd":"'"$HK/hh"'"}'; eq "hook: search root outside work/sessions/snapshot: blocked" "$rc" 2; has "hook: search root: reason" "$out" "search root not allowed"
hook '{"tool_name":"read_file","tool_input":{"path":"x"},"cwd":"/"}' HERMES_UNSET=1; eq "hook: HERMES_HOME unset: blocked (fail closed)" "$rc" 2; has "hook: unset: reason" "$out" "HERMES_HOME unset"

# --- 8. seed-hook-allowlist: refusals always; the write only where ps works
SH="$FX/seedhome"; SHH="$SH/claude-profiles/hermes"; mkdir -p "$SHH/bin" "$SHH/h1-home"; chmod 700 "$SHH/h1-home"
cp "$SETUP/pre-tool-call.sh" "$SHH/bin/pre-tool-call.sh"; chmod 555 "$SHH/bin/pre-tool-call.sh"
seed() { out="$("${ENVI[@]}" HOME="$SH" ${1-HERMES_HOME="$SHH/h1-home"} /usr/bin/python3 -I "$SETUP/seed-hook-allowlist" 2>&1)"; rc=$?; }
seed HERMES_UNSET=1; eq "seed: no HERMES_HOME: rc 1" "$rc" 1; has "seed: no HERMES_HOME: reason" "$out" "HERMES_HOME not set"
seed HERMES_HOME="$FX/elsewhere"; has "seed: wrong HERMES_HOME refused" "$out" "HERMES_HOME is not $SHH/h1-home"
chmod 755 "$SHH/bin/pre-tool-call.sh"; seed; has "seed: hook mode 755 refused" "$out" "hook mode is 755, not 555"
chmod 555 "$SHH/bin/pre-tool-call.sh"; cp "$SHH/bin/pre-tool-call.sh" "$FX/hook.orig"
chmod 755 "$SHH/bin/pre-tool-call.sh"; echo '# tampered' >>"$SHH/bin/pre-tool-call.sh"; chmod 555 "$SHH/bin/pre-tool-call.sh"
seed; eq "seed: tampered hook: rc 1" "$rc" 1; has "seed: tampered hook: sha256 differs" "$out" "hook sha256 differs from the evidence sha"
chmod 755 "$SHH/bin/pre-tool-call.sh"; cp "$FX/hook.orig" "$SHH/bin/pre-tool-call.sh"; chmod 555 "$SHH/bin/pre-tool-call.sh"
if /bin/ps -axww -o pid=,ppid=,command= >/dev/null 2>&1; then
  seed; eq "seed: genuine hook: rc 0" "$rc" 0; has "seed: says seeded" "$out" "seeded"
  AL="$SHH/h1-home/shell-hooks-allowlist.json"
  eq "seed: allowlist mode 600" "$(stat -f %Lp "$AL" 2>/dev/null)" 600
  eq "seed: one pre_tool_call approval for the hook path" "$(/usr/bin/python3 -I -c 'import json,sys; a=json.load(open(sys.argv[1]))["approvals"]; print(len(a), a[0]["event"], a[0]["command"])' "$AL")" "1 pre_tool_call $SHH/bin/pre-tool-call.sh"
else echo "SKIP (not counted): /bin/ps unusable here; the seed success path was not exercised (refusals above were)"; fi

# --- 9. hermes-up gateway and CLI branches, hermetic. A fixture HOME holds a fake code dir (stub `hermes`, a stub hermes_cli loader that
# reads JSON), a stub `git` on PATH (the only seam: it reports the README pin sha, clean tree), a python wrapper at the path hermes-up
# expects, and a facts.json selector. hermes-up itself is run unmodified; no real HERMES_HOME, network or Hermes ever runs.
GH="$FX/gw"; GHH="$GH/claude-profiles/hermes"; GHOME="$GHH/h1-home"; CODE="$GHH/hermes-agent"; HKP="$GHH/bin/pre-tool-call.sh"
mkdir -p "$GHH/bin" "$GHOME/work" "$CODE/hermes_cli" "$FX/gbin" "$GHOME/tools/python-3.14.7+20260901-darwin-arm64/bin"; chmod 700 "$GHOME"
cp "$SETUP/pre-tool-call.sh" "$HKP"; chmod 555 "$HKP"
printf '#!/bin/sh\nprintf "stub-hermes args=%%s host=%%s token_set=%%s\\n" "$*" "${API_SERVER_HOST:-}" "${CLAUDE_CODE_OAUTH_TOKEN:+1}"\n' >"$CODE/hermes"; chmod 755 "$CODE/hermes"
: >"$CODE/hermes_cli/__init__.py"
printf 'import os\ndef backup_config(*a, **k):\n    open(os.path.join(os.path.dirname(__file__), "..", "BACKUP_RAN"), "w").write("x")\n' >"$CODE/hermes_cli/config_backups.py"
printf 'import json\nimport hermes_cli.config_backups as b\ndef load_user_config_effective(path, fail_closed=False):\n    b.backup_config()\n    return json.load(open(path))\n' >"$CODE/hermes_cli/config_effective.py"
printf '#!/bin/sh\nexec /usr/bin/python3 "$@"\n' >"$GHOME/tools/python-3.14.7+20260901-darwin-arm64/bin/python3"; chmod 755 "$GHOME/tools/python-3.14.7+20260901-darwin-arm64/bin/python3"
printf '#!/bin/sh\ncase "$*" in\n *"rev-parse HEAD"*) echo "${STUB_GIT_SHA:-908e4a4b44480912ae3571833492c1aeac2d0eda}" ;;\n *"status --porcelain"*) [ -n "${STUB_GIT_DIRTY:-}" ] && echo " M x" ;;\n *) exit 1 ;;\nesac\n' >"$FX/gbin/git"; chmod 755 "$FX/gbin/git"
h16="$(printf '%s' "$(cd "$CODE" && pwd -P)" | shasum -a 256 | cut -c1-16)"; ST="$GHOME/installs/$h16"; mkdir -p "$ST/environments/e1/lib/python3.12/site-packages"
printf 'version = 3.12.0\n' >"$ST/environments/e1/pyvenv.cfg"; printf '{"packages":{"venv":{"environment":"%s"}}}' "$ST/environments/e1" >"$ST/facts.json"
TS="$(sed -n 's/^GW_TOOLSETS="\(.*\)"$/\1/p' "$SETUP/hermes-up")"
cfg() { # cfg <host|-> [unattended] [dropped-toolset]: JSON is valid YAML; the fixture loader reads it with json
  /usr/bin/python3 -I -c 'import json,sys
h,u,drop,hook,ts=sys.argv[1:6]; t=[x for x in ts.split() if x!=drop]
c={"agent":{"disabled_toolsets":t},"hooks":{"pre_tool_call":[{"command":hook}]},"approvals":{"unattended_mode":u}}
if h!="-": c["platforms"]={"api_server":{"extra":{"host":h}}}
json.dump(c,open(sys.argv[6],"w"))' "$1" "${2-deny}" "${3-}" "$HKP" "$TS" "$GHOME/config.yaml"; }
allow() { printf '{"approvals":[{"event":"pre_tool_call","command":"%s"}]}' "$HKP" >"$GHOME/shell-hooks-allowlist.json"; }
envf() { printf '%s\n' "$@" >"$GHOME/.env"; }
gup() { out="$(env -i PATH="$FX/gbin:/usr/bin:/bin" HOME="$GH" HERMES_HOME="$GHOME" "$@" 2>&1)"; rc=$?; }
reset_gw() { cfg 127.0.0.1; allow; envf "API_SERVER_KEY=dummy-not-a-credential"; rm -rf "$GHOME/hooks" "$GHOME/plugins" "$CODE/BACKUP_RAN"; }
TOKV=CLAUDE_CODE_OAUTH_TOKEN=dummy-not-a-credential
reset_gw; gup $TOKV "$SETUP/hermes-up" gateway run
eq "gw branch: all checks pass: rc 0" "$rc" 0; has "gw branch: execs the stub hermes with 'gateway run' and API_SERVER_HOST=127.0.0.1" "$out" "stub-hermes args=gateway run host=127.0.0.1 token_set=1"
[ ! -e "$CODE/BACKUP_RAN" ] && pass "gw branch: the loader's backup_config is neutralised" || fail "gw branch: backup_config ran"
hasnt "gw branch: the token value is never printed" "$out" "dummy-not-a-credential"
reset_gw; cfg 0.0.0.0; gup $TOKV "$SETUP/hermes-up" gateway run
eq "gw: non-loopback api_server host refused (rc 0 parks the job)" "$rc" 0; has "gw: host refusal reason" "$out" "gateway refused: platforms.api_server.extra.host is not 127.0.0.1"; hasnt "gw: refused run never reaches hermes" "$out" "stub-hermes"
reset_gw; cfg -; gup $TOKV "$SETUP/hermes-up" gateway run; has "gw: no api_server section is allowed (host defaults to loopback)" "$out" "stub-hermes args=gateway run host=127.0.0.1"
for d in hooks plugins; do
  reset_gw; mkdir -p "$GHOME/$d"; gup $TOKV "$SETUP/hermes-up" gateway run; has "gw: empty $d/ dir is allowed" "$out" "stub-hermes"
  touch "$GHOME/$d/x"; gup $TOKV "$SETUP/hermes-up" gateway run; has "gw: non-empty $d/ refused" "$out" "gateway refused: $d/ exists and is not an empty dir"
done
reset_gw; cfg 127.0.0.1 allow; gup $TOKV "$SETUP/hermes-up" gateway run; has "gw: approvals.unattended_mode other than deny refused" "$out" "approvals.unattended_mode is not deny"
reset_gw; cfg 127.0.0.1 deny "${TS%% *}"; gup $TOKV "$SETUP/hermes-up" gateway run; has "gw: a changed disabled_toolsets list refused" "$out" "agent.disabled_toolsets differs from expected list"
reset_gw; envf "API_SERVER_KEY=x" "TELEGRAM_BOT_TOKEN=x"; gup $TOKV "$SETUP/hermes-up" gateway run; has "gw: .env with a chat credential key refused" "$out" ".env sets forbidden key TELEGRAM_BOT_TOKEN"
reset_gw; envf "API_SERVER_KEY=x" "FOO=1"; gup $TOKV "$SETUP/hermes-up" gateway run; has "gw: .env with any other key refused" "$out" "unexpected key: FOO"
reset_gw; envf "# no keys at all"; gup $TOKV "$SETUP/hermes-up" gateway run; has "gw: .env without API_SERVER_KEY refused" "$out" ".env lacks API_SERVER_KEY"
reset_gw; rm -f "$GHOME/shell-hooks-allowlist.json"; gup $TOKV "$SETUP/hermes-up" gateway run; has "gw: hook consent missing refused" "$out" "hook not approved in shell-hooks-allowlist.json"
reset_gw; gup $TOKV STUB_GIT_SHA=deadbeefdeadbeefdeadbeefdeadbeefdeadbeef "$SETUP/hermes-up" gateway run; has "gw: code sha other than the pin refused" "$out" "code sha deadbee != pin 908e4a4"
reset_gw; gup $TOKV STUB_GIT_DIRTY=1 "$SETUP/hermes-up" gateway run; has "gw: dirty code dir refused" "$out" "code dir dirty"
reset_gw; gup $TOKV HERMES_YOLO_MODE=1 "$SETUP/hermes-up" gateway run; has "gw: HERMES_YOLO_MODE in env refused" "$out" "HERMES_YOLO_MODE set"
reset_gw; gup "$SETUP/hermes-up" gateway run; has "gw: missing token refused" "$out" "CLAUDE_CODE_OAUTH_TOKEN missing from env"
# CLI mode: the argument whitelist (refusals are rc 1; accepted forms exec the stub)
reset_gw; gup $TOKV "$SETUP/hermes-up" chat -q hello; eq "cli: chat -q <text> accepted: rc 0" "$rc" 0; has "cli: stub gets exactly the whitelisted args" "$out" "stub-hermes args=chat -q hello"
gup $TOKV "$SETUP/hermes-up" --yolo; eq "cli: unknown arg refused: rc 1" "$rc" 1; has "cli: unknown arg reason" "$out" "arg not whitelisted: --yolo"
gup $TOKV "$SETUP/hermes-up" gateway start; eq "cli: 'gateway start' is not the gateway form: refused" "$rc" 1; has "cli: gateway start reason" "$out" "arg not whitelisted: gateway"
gup $TOKV "$SETUP/hermes-up" chat -q; has "cli: -q without a value refused" "$out" "-q needs a value"
gup $TOKV "$SETUP/hermes-up" -q hello; has "cli: -q without chat refused" "$out" "-q needs chat"

echo "=== hermes-setup: $passed passed, $failed failed ==="; [ "$failed" = 0 ]
