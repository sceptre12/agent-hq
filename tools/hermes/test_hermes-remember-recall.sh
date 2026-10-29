#!/usr/bin/env bash
# tools/hermes/test_hermes-remember-recall.sh — tests for tools/hermes/setup/hermes-remember and hermes-recall.
# Hermetic: HOME/HERMES_HOME point into a mktemp fixture, PATH is overridden to a stub `curl` (never the real
# gateway, never the network), and the scripts run via their own #!/bin/zsh shebang under env -i. The stub curl
# captures its own argv and snapshots the header-file path/mode/content it was handed via -H @"$file", so the
# tests can confirm the key only ever reaches curl through that 0600 temp file -- never as a literal argv string --
# and that the file is gone again once the script under test exits (EXIT/INT/TERM trap cleanup).
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SETUP="$HERE/setup"
_tb="${TMPDIR:-/tmp}"; FX="$(mktemp -d "${_tb%/}/test_hermes-remember-recall.XXXXXX")" || { echo "FAIL: mktemp -d"; exit 1; }
trap 'chmod -R u+rwx "$FX" 2>/dev/null; rm -rf "$FX"' EXIT
passed=0; failed=0
pass() { echo "PASS: $1"; passed=$((passed + 1)); }
fail() { echo "FAIL: $1"; failed=$((failed + 1)); }
eq() { if [ "$2" = "$3" ]; then pass "$1"; else fail "$1 (got '$2', want '$3')"; fi; }
has() { case "$2" in *"$3"*) pass "$1" ;; *) fail "$1 (no '$3' in: $2)" ;; esac; }
hasnt() { case "$2" in *"$3"*) fail "$1 (found '$3' in: $2)" ;; *) pass "$1" ;; esac; }

# --- 0. syntax + executable bit
for s in hermes-remember hermes-recall; do
  if zsh -n "$SETUP/$s" 2>/dev/null; then pass "zsh -n $s"; else fail "zsh -n $s"; fi
  [ -x "$SETUP/$s" ] && pass "$s is executable" || fail "$s is not executable"
done

# --- fixture HERMES_HOME with a fake key, and a stub curl on PATH
HH="$FX/hh"; mkdir -p "$HH"; printf 'API_SERVER_KEY=dummy-not-a-credential\n' >"$HH/.env"
KEY="dummy-not-a-credential"
BIN="$FX/bin"; mkdir -p "$BIN"
CAP="$FX/argv.cap"; SNAP="$FX/hdr.snap"
cat >"$BIN/curl" <<'STUB'
#!/bin/sh
# Stub curl: captures argv (one per line) to $STUB_CURL_CAPTURE, snapshots the file named by the
# "@<path>" value that follows -H (path/mode/content) to $STUB_CURL_HDR_SNAPSHOT, writes
# $STUB_CURL_BODY to the file named by -o, and prints $STUB_CURL_STATUS on stdout -- mimicking
# `curl -sS -o <file> -w '%{http_code}'`. A non-zero $STUB_CURL_RC exits with that code instead,
# simulating a connection failure before any body/status is produced.
: >"${STUB_CURL_CAPTURE:?}"
hdr_file=""; out_file=""
while [ $# -gt 0 ]; do
  arg="$1"; printf '%s\n' "$arg" >>"$STUB_CURL_CAPTURE"
  case "$arg" in
    -H) shift; printf '%s\n' "$1" >>"$STUB_CURL_CAPTURE"
        case "$1" in @*) hdr_file="${1#@}" ;; esac ;;
    -o) shift; printf '%s\n' "$1" >>"$STUB_CURL_CAPTURE"; out_file="$1" ;;
  esac
  shift
done
if [ -n "$hdr_file" ] && [ -n "${STUB_CURL_HDR_SNAPSHOT:-}" ]; then
  { printf 'path=%s\n' "$hdr_file"
    printf 'mode=%s\n' "$(stat -f %Lp "$hdr_file" 2>/dev/null || stat -c %a "$hdr_file" 2>/dev/null)"
    printf 'content=%s\n' "$(cat "$hdr_file" 2>/dev/null)"
  } >"$STUB_CURL_HDR_SNAPSHOT"
fi
[ -n "${STUB_CURL_RC:-0}" ] && [ "${STUB_CURL_RC:-0}" != "0" ] && exit "$STUB_CURL_RC"
BODY="${STUB_CURL_BODY:-}"; [ -n "$BODY" ] || BODY='{}'
[ -n "$out_file" ] && printf '%s' "$BODY" >"$out_file"
printf '%s' "${STUB_CURL_STATUS:-200}"
STUB
chmod 755 "$BIN/curl"

# run <script> [args...]: honors STUB_CURL_{STATUS,BODY,RC} from the environment; sets $out/$rc.
# STDIN is /dev/null by default so the scripts' stdin-fallback branch sees a non-tty, empty read.
runw() {
  out="$(env -i PATH="$BIN:/usr/bin:/bin" HERMES_HOME="$HH" \
      STUB_CURL_CAPTURE="$CAP" STUB_CURL_HDR_SNAPSHOT="$SNAP" \
      STUB_CURL_STATUS="${STUB_CURL_STATUS:-200}" STUB_CURL_BODY="${STUB_CURL_BODY:-}" \
      STUB_CURL_RC="${STUB_CURL_RC:-0}" \
      "$@" </dev/null 2>&1)"
  rc=$?
}

# --- 1. successful call: hermes-remember
STUB_CURL_STATUS=200 STUB_CURL_BODY='{}' runw "$SETUP/hermes-remember" "a fact worth keeping"
eq "remember: success rc 0" "$rc" 0
eq "remember: success output" "$out" "hermes-remember: stored (HTTP 200)"

# --- 2. successful call: hermes-recall, expected output shape (prints choices[0].message.content only)
STUB_CURL_STATUS=200 STUB_CURL_BODY='{"choices":[{"message":{"content":"the answer"}}]}' \
  runw "$SETUP/hermes-recall" "what do we know"
eq "recall: success rc 0" "$rc" 0
eq "recall: success output is exactly the message content" "$out" "the answer"

# --- 3. unreachable gateway: curl exit 7 ("Failed to connect")
for pair in "hermes-remember:a fact" "hermes-recall:a query"; do
  s="${pair%%:*}"; arg="${pair#*:}"
  STUB_CURL_RC=7 runw "$SETUP/$s" "$arg"
  eq "$s: unreachable gateway rc 1" "$rc" 1
  has "$s: unreachable gateway reason" "$out" "connection error (curl exit 7)"
  hasnt "$s: unreachable gateway never echoes the key" "$out" "$KEY"
done

# --- 4. empty input (no positional arg, empty stdin -- the stdin-fallback branch reads nothing)
STUB_CURL_RC=0 runw "$SETUP/hermes-remember"
eq "remember: empty content rc 1" "$rc" 1
has "remember: empty content reason" "$out" "empty content: nothing to remember"
STUB_CURL_RC=0 runw "$SETUP/hermes-recall"
eq "recall: empty query rc 1" "$rc" 1
has "recall: empty query reason" "$out" "empty query: nothing to recall"

# --- 5. the key reaches curl only via a 0600 header file, never as a literal argv string, and that
#        file is gone again once the script exits (trap cleanup on the normal success path too).
STUB_CURL_STATUS=200 STUB_CURL_BODY='{}' runw "$SETUP/hermes-remember" "a fact worth keeping"
hasnt "remember: key never appears in curl's argv" "$(cat "$CAP")" "$KEY"
hasnt "remember: no literal Authorization argv string" "$(cat "$CAP")" "Authorization:"
eq "remember: exactly one @header -H value" "$(grep -c '^@' "$CAP")" 1
hdr_path="$(sed -n 's/^path=//p' "$SNAP")"
eq "remember: header file mode 600" "$(sed -n 's/^mode=//p' "$SNAP")" "600"
eq "remember: header file held exactly the bearer header" "$(sed -n 's/^content=//p' "$SNAP")" "Authorization: Bearer $KEY"
[ -e "$hdr_path" ] && fail "remember: header temp file still exists after exit" || pass "remember: header temp file removed on exit (trap cleanup)"

STUB_CURL_STATUS=200 STUB_CURL_BODY='{"choices":[{"message":{"content":"x"}}]}' runw "$SETUP/hermes-recall" "q"
hasnt "recall: key never appears in curl's argv" "$(cat "$CAP")" "$KEY"
eq "recall: header file mode 600" "$(sed -n 's/^mode=//p' "$SNAP")" "600"
hdr_path="$(sed -n 's/^path=//p' "$SNAP")"
[ -e "$hdr_path" ] && fail "recall: header temp file still exists after exit" || pass "recall: header temp file removed on exit (trap cleanup)"

# --- 6. file length (same convention as the other hermes test files; exempt from the repo's
#        normal 200-line cap per the project's test-file exception)
for f in "$SETUP/hermes-remember" "$SETUP/hermes-recall" "$HERE/test_hermes-remember-recall.sh"; do
  n="$(wc -l <"$f" | tr -d ' ')"
  if [ "$n" -le 300 ]; then pass "${f##*/} is $n <= 300 lines"; else fail "${f##*/} is $n > 300 lines"; fi
done

echo "=== hermes-remember-recall: $passed passed, $failed failed ==="; [ "$failed" = 0 ]
