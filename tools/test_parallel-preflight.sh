#!/usr/bin/env bash
# tools/test_parallel-preflight.sh — hermetic tests for tools/parallel-preflight.sh and
# tools/lib/preflight-lib.sh (Rule 10; both left grandfathered.txt in the same change).
#
# Hermetic: every live probe the gate runs (osascript, df, netstat, memory_pressure, xcrun,
# lsof, java) is a stub in a mktemp -d bin dir prepended to PATH — the gate's only test seam
# (see the DISK header in lib/preflight-lib.sh). No simulator, port, network or real disk
# reading is used. The shipped script + lib are COPIED into the fixture verbatim except for
# one line: LOCKFILE is pointed into the fixture so a real /tmp/measurement.lock on
# this host cannot change a verdict (positive control: exactly one LOCKFILE= line replaced).
#
# Usage: tools/test_parallel-preflight.sh
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$SCRIPT_DIR/parallel-preflight.sh"
SRC_LIB="$SCRIPT_DIR/lib/preflight-lib.sh"
SCRATCH_UDID="E2B38623-291E-4E6C-8123-CABEEE8CBFFE"

passed=0; failed=0
pass() { echo "PASS: $1"; passed=$((passed + 1)); }
fail() { echo "FAIL: $1"; failed=$((failed + 1)); }
finish() { echo "=== ${passed} passed, ${failed} failed ==="; [ "$failed" -eq 0 ]; exit $?; }

[ -r "$SRC" ] && [ -r "$SRC_LIB" ] || { fail "target script/lib not readable"; finish; }

FX="$(mktemp -d "${TMPDIR:-/tmp}/test-preflight.XXXXXX")" || { fail "mktemp -d"; finish; }
trap 'rm -rf "$FX"' EXIT
mkdir -p "$FX/tools/lib" "$FX/bin" "$FX/jdk/bin" "$FX/lockdir"
cp "$SRC_LIB" "$FX/tools/lib/preflight-lib.sh"
n_lock="$(command grep -c '^LOCKFILE=' "$SRC")"
if [ "$n_lock" != "1" ]; then fail "expected exactly 1 LOCKFILE= line in target, found $n_lock"; finish; fi
sed "s|^LOCKFILE=.*|LOCKFILE=\"$FX/lockdir/measurement.lock\"|" "$SRC" >"$FX/tools/parallel-preflight.sh"
if [ "$(command grep -c "^LOCKFILE=\"$FX/lockdir/" "$FX/tools/parallel-preflight.sh")" = "1" ] \
   && [ "$(diff "$SRC" "$FX/tools/parallel-preflight.sh" | command grep -c '^[<>]')" = "2" ]; then
  pass "fixture copy differs from shipped script in the LOCKFILE line only"
else
  fail "fixture copy is not the shipped script with one LOCKFILE line replaced"; finish
fi
chmod +x "$FX/tools/parallel-preflight.sh"
TARGET="$FX/tools/parallel-preflight.sh"

# --- stubs (behaviour driven by STUB_* env vars) ----------------------------------------
stub() { printf '#!/bin/bash\n%s\n' "$2" >"$FX/bin/$1"; chmod +x "$FX/bin/$1"; }
stub osascript 'case "${STUB_OSA:-value}" in
  value) printf "%s\n" "${STUB_OSA_OUT}" ;;
  fail) echo "execution error: boom" >&2; exit 1 ;;
  hang) sleep 30 ;;
  *) printf "%b\n" "${STUB_OSA}" ;;
esac'
stub df 'case "${STUB_DF:-value}" in
  value) printf "Filesystem 1G-blocks Used Available Capacity Mounted\n/dev/disk3s1s1 926 15 ${STUB_DF_FREE} 25%% /\n" ;;
  fail) exit 1 ;;
  *) printf "Filesystem 1G-blocks Used Available Capacity Mounted\n/dev/x 926 15 %s 25%% /\n" "${STUB_DF}" ;;
esac'
stub netstat 'for i in 1 2 3 4 5 6 7 8; do echo "tcp4 0 0 127.0.0.1.$i *.* LISTEN"; done'
stub memory_pressure 'echo "System-wide memory free percentage: 80%"'
stub xcrun 'printf "== Devices ==\n-- iOS 18.0 --\n"'
stub lsof 'case "$*" in *-iTCP:*) exit 1 ;; esac
echo "COMMAND PID USER FD TYPE DEVICE SIZE/OFF NODE NAME"
echo "launchd 1 root 7u IPv4 0x1 0t0 TCP *:22 (LISTEN)"'
stub brew 'exit 1'
printf '#!/bin/bash\ncase "$*" in *-XX*) exit 1 ;; esac\nexit 0\n' >"$FX/jdk/bin/java"; chmod +x "$FX/jdk/bin/java"

# run [extra args...] — sets OUT, RC. Defaults: important probe 136 GB, df 46, GO elsewhere.
run() {
  OUT="$(env PATH="$FX/bin:/usr/bin:/bin" JAVA_HOME="${T_JAVA_HOME-$FX/jdk}" \
    STUB_OSA="${T_OSA:-value}" STUB_OSA_OUT="${T_OSA_OUT-136291374395}" \
    STUB_DF="${T_DF:-value}" STUB_DF_FREE="${T_DF_FREE:-46}" \
    "$TARGET" --expect-sims 0 --devices "${T_DEVICES:-$SCRATCH_UDID}" "$@" 2>&1)"; RC=$?
}
disk_row() { printf '%s\n' "$OUT" | command grep '^DISK_FREE_GB '; }
# expect_disk <label> <want-value-column> <want-status> <want-rc>
expect_disk() {
  local row val st
  row="$(disk_row)"
  val="$(printf '%s' "$row" | sed -E 's/^DISK_FREE_GB +(.*[^ ]) +\(abort <60\) +.*$/\1/')"
  st="${row##* }"
  if [ "$val" = "$2" ] && [ "$st" = "$3" ] && [ "$RC" = "$4" ]; then pass "$1 -> [$val] $st rc=$RC"
  else fail "$1: want [$2] $3 rc=$4, got row [$row] rc=$RC"; printf '%s\n' "$OUT" | sed 's/^/    | /'; fi
}

# 1. important-usage above floor -> OK, whole gate GO
run; expect_disk "important 136291374395 B" "136 (important)" OK 0
case "$OUT" in *"VERDICT: GO"*) pass "all checks stubbed healthy -> VERDICT: GO" ;; *) fail "expected VERDICT: GO"; esac
case "$OUT" in *"probe unusable"*) fail "no fallback note expected on the important path" ;; *) pass "no fallback note on important path" ;; esac
# df is NOT consulted when the important probe works: df=1 would be NO-GO if it were
T_DF_FREE=1 run; expect_disk "important wins over a low df" "136 (important)" OK 0
# 2. below floor -> NO-GO; boundary 60 GB (decimal) -> OK
T_OSA_OUT=59999999999 run; expect_disk "important 59.99e9 B" "59 (important)" NO-GO 1
case "$OUT" in *"VERDICT: NO-GO (DISK_FREE_GB)"*) pass "verdict names DISK_FREE_GB only" ;; *) fail "verdict should be NO-GO (DISK_FREE_GB)"; esac
T_OSA_OUT=60000000000 run; expect_disk "important exactly 60e9 B" "60 (important)" OK 0
# 3. probe failure -> df fallback used and labelled (both directions)
T_OSA=fail run; expect_disk "probe exit 1, df 46" "46 (df fallback)" NO-GO 1
case "$OUT" in *"important-usage probe unusable (rc 1"*"source=df fallback"*) pass "fallback note names rc and source" ;; *) fail "fallback note missing"; esac
T_OSA=fail T_DF_FREE=80 run; expect_disk "probe exit 1, df 80" "80 (df fallback)" OK 0
T_OSA='1.36e+11' run; expect_disk "probe non-integer output" "46 (df fallback)" NO-GO 1
T_OSA='136291374395\njunk' run; expect_disk "probe multi-line output (line-at-a-time trap)" "46 (df fallback)" NO-GO 1
T_OSA_OUT=1234567890123456789 run; expect_disk "probe 19-digit output (overflow guard)" "46 (df fallback)" NO-GO 1
T_OSA_OUT='' T_DF_FREE=70 run; expect_disk "probe empty output" "70 (df fallback)" OK 0
start=$SECONDS; T_OSA=hang T_DF_FREE=70 run; took=$((SECONDS - start))
expect_disk "probe hangs -> killed by run_timeout" "70 (df fallback)" OK 0
case "$OUT" in *"(rc 124"*) pass "hung probe reported as rc 124" ;; *) fail "expected rc 124 in note"; esac
if [ "$took" -le 20 ]; then pass "hung probe bounded (${took}s)"; else fail "hung probe took ${took}s"; fi
# 4. both fail -> UNKNOWN => NO-GO
T_OSA=fail T_DF=fail run; expect_disk "probe + df both fail" "UNKNOWN" "NO-GO(unknown)" 1
case "$OUT" in *"source=unknown"*) pass "both-fail note says source=unknown" ;; *) fail "both-fail note missing"; esac
T_OSA=junk T_DF='4x6' run; expect_disk "probe junk + df junk" "UNKNOWN" "NO-GO(unknown)" 1
# 5. the rest of the verdict logic still works with disk healthy
T_DEVICES="$SCRATCH_UDID,C543AEAE-714B-4AD5-B181-5D05123F1DF6" run
case "$OUT" in *"VERDICT: NO-GO (PROD_SIM_DENY)"*) pass "prod UDID still denied" ;; *) fail "prod UDID not denied"; esac
: >"$FX/lockdir/measurement.lock"; run; rm -f "$FX/lockdir/measurement.lock"
case "$OUT" in *"VERDICT: NO-GO (MEASURE_LOCK)"*) pass "measurement lock still blocks" ;; *) fail "lock not detected"; esac
T_JAVA_HOME="" run
case "$OUT" in *"VERDICT: NO-GO (JAVA)"*) pass "unset JAVA_HOME still NO-GO" ;; *) fail "JAVA_HOME check broken"; esac
run --quiet
if [ "$OUT" = "VERDICT: GO" ] && [ "$RC" = 0 ]; then pass "--quiet prints only the verdict"; else fail "--quiet output [$OUT] rc=$RC"; fi
T_OSA=fail T_DF=fail run --quiet
if [ "$OUT" = "VERDICT: NO-GO (DISK_FREE_GB)" ] && [ "$RC" = 1 ]; then pass "--quiet names DISK_FREE_GB on both-fail"; else fail "--quiet both-fail [$OUT] rc=$RC"; fi
# 6. a lib without disk_free_probe is refused (contract list includes it)
sed '/^disk_free_probe()/,/^}/d' "$SRC_LIB" >"$FX/tools/lib/preflight-lib.sh"; run
cp "$SRC_LIB" "$FX/tools/lib/preflight-lib.sh"
case "$OUT" in *"did not define disk_free_probe()"*) [ "$RC" = 2 ] && pass "half-loaded lib refused (rc 2)" || fail "half-loaded lib rc=$RC" ;; *) fail "lib contract does not cover disk_free_probe"; esac

finish
