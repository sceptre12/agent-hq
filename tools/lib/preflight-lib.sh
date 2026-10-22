# preflight-lib.sh — shared primitives for tools/parallel-preflight.sh.
# Sourced, never executed. Split out of parallel-preflight.sh because the
# combined file crossed hq's 300-line source default (ADR 0016), whose stated
# remedy is to split rather than to compress.
#
# The whole point of these helpers is the UNKNOWN => NO-GO rule: a test that
# ERRORS is not a test that returned false. `[ 1 -ne 99999999999999999999 ]`
# exits rc=2, so a naive `if test; then NO-GO; else OK; fi` reports OK on an
# instrument failure. num_check() routes rc=2 to UNKNOWN instead.

# --- Verdict accumulation ----------------------------------------------------
NOGO=0
FAILED=""
declare -a LINES=()
declare -a NOTES=()

# report <name> <value> <threshold-desc> <status>
# Status is OK, NO-GO, or NO-GO(unknown); anything that is not exactly OK
# fails the run and gets its name recorded for the VERDICT line, so a --quiet
# caller still learns which check went bad.
report() {
  LINES+=("$(printf '%-16s %-16s %-36s %s' "$1" "$2" "($3)" "$4")")
  case "$4" in
    OK) ;;
    *) NOGO=1; FAILED="${FAILED:+$FAILED, }$1" ;;
  esac
}

# --- Numeric primitives ------------------------------------------------------
# cmp_num A OP B -> 0 true, 1 false, 2 the test itself errored (=> UNKNOWN).
cmp_num() {
  local rc
  [ "$1" "$2" "$3" ] 2>/dev/null
  rc=$?
  [ "$rc" -le 1 ] && return "$rc"
  return 2
}

# is_num VALUE MAXDIGITS -> plain decimal integer of at most MAXDIGITS digits.
# The digit cap is what keeps cmp_num's operands inside the shell's integer
# range; shape alone ("^[0-9]+$") admits values that overflow it.
is_num() { printf '%s' "$1" | command grep -Eq "^[0-9]{1,$2}\$"; }

# num_check NAME VALUE OP THRESHOLD THRESHDESC [SUFFIX]
#   OP true => NO-GO, OP false => OK, non-numeric or errored test => UNKNOWN.
num_check() {
  local name="$1" val="$2" op="$3" thr="$4" td="$5" sfx="${6:-}" rc
  if ! is_num "$val" 9; then report "$name" "UNKNOWN" "$td" "NO-GO(unknown)"; return; fi
  cmp_num "$val" "$op" "$thr"; rc=$?
  case "$rc" in
    0) report "$name" "${val}${sfx}" "$td" "NO-GO" ;;
    1) report "$name" "${val}${sfx}" "$td" "OK" ;;
    *) report "$name" "UNKNOWN" "$td" "NO-GO(unknown)" ;;
  esac
}

# --- Bounded execution -------------------------------------------------------
# run_timeout SECS CMD... -> the command's rc, or 124 if it had to be killed.
#
# Runs inside a subshell with job control on, so the command becomes its own
# process-group leader and the whole group is signalled: killing only the direct
# child leaves grandchildren reparented to pid 1 (a forking fake JDK left two
# orphaned sleeps that had to be reaped by hand). The subshell's own stderr goes
# to /dev/null because bash announces a killed job on ITS stderr ("Terminated:
# 15"), which would otherwise pollute the stderr of a gate a runner may parse —
# the command's own output is separately discarded. Nothing is written anywhere,
# so the script stays read-only. Needed because this host ships no
# timeout(1)/gtimeout(1).
run_timeout() {
  local secs="$1"; shift
  (
    exec 2>/dev/null
    set -m
    "$@" >/dev/null 2>&1 &
    rt_pid=$!
    rt_limit=$(( secs * 10 )); rt_waited=0
    while [ "$rt_waited" -lt "$rt_limit" ] && kill -0 "$rt_pid" 2>/dev/null; do
      sleep 0.1
      rt_waited=$(( rt_waited + 1 ))
    done
    if kill -0 "$rt_pid" 2>/dev/null; then
      # negative pid = the whole process group; fall back to the lone child if
      # job control did not give the job its own group.
      kill -TERM -"$rt_pid" 2>/dev/null || kill -TERM "$rt_pid" 2>/dev/null
      sleep 0.5
      kill -KILL -"$rt_pid" 2>/dev/null || kill -KILL "$rt_pid" 2>/dev/null
      wait "$rt_pid" 2>/dev/null
      exit 124
    fi
    wait "$rt_pid" 2>/dev/null
    exit $?
  )
  return $?
}

# --- Disk headroom probe -----------------------------------------------------
# Check 5 measures what macOS itself reports as available on "/": Foundation's
# volumeAvailableCapacityForImportantUsage (free space PLUS purgeable caches and
# snapshots the OS reclaims on demand for important writes) — the "available"
# figure Finder and System Settings show. `df` counts strict free blocks only and
# read ~85 GB low on 2026-10-14 (df 46-49 GiB vs 132 GB important-usage, owner's
# Storage pane ~133 GB), turning a host with ample room into a false NO-GO.
#
# Fail-closed ladder:
#   1. important-usage probe (osascript JXA, ~0.1s; bounded by run_timeout)
#      -> DISK_SRC=important, DISK_GB = bytes / 10^9 (decimal GB, floored);
#   2. probe failed / timed out / printed anything but one integer
#      -> DISK_SRC="df fallback", DISK_GB = `df -g /` free GiB (strict free
#         blocks in 2^30 units: a real, conservative lower bound);
#   3. both failed -> DISK_SRC=unknown, DISK_GB="" (num_check => UNKNOWN => NO-GO).
#
# TEST SEAM: none beyond PATH. `osascript` and `df` resolve through PATH exactly
# like every other probe in this gate (netstat, lsof, xcrun, memory_pressure), so
# tests stub them by prepending a fixture bin dir. There is deliberately NO env
# override: whoever controls PATH already controls every check, so this adds no
# new way to loosen the gate.
#
# Validation is a whole-string bash regex, not is_num: is_num's grep matches
# line-at-a-time, so "136291374395\njunk" would pass it.
DISK_JXA='ObjC.import("Foundation"); var v = Ref(), e = Ref(); $.NSURL.fileURLWithPath("/").getResourceValueForKeyError(v, "NSURLVolumeAvailableCapacityForImportantUsageKey", e); ObjC.unwrap(v[0]).toString()'
DISK_BYTES_RE='^[0-9]{1,18}$'
DISK_DF_RE='^[0-9]{1,9}$'

# The probe writes to fd 3 because run_timeout discards the command's stdout;
# disk_free_probe binds fd 3 to its command substitution. Nothing touches disk.
_disk_important_probe() { osascript -l JavaScript -e "$DISK_JXA" >&3 2>/dev/null; }

# disk_free_probe SECS -> sets DISK_GB, DISK_SRC and DISK_PROBE_RC (rc of step 1).
disk_free_probe() {
  local secs="$1" out
  DISK_GB=""; DISK_SRC="unknown"
  out="$(run_timeout "$secs" _disk_important_probe 3>&1)"; DISK_PROBE_RC=$?
  if [ "$DISK_PROBE_RC" -eq 0 ] && [[ "$out" =~ $DISK_BYTES_RE ]]; then
    DISK_GB=$(( 10#$out / 1000000000 )); DISK_SRC="important"; return 0
  fi
  out="$(df -g / 2>/dev/null | awk 'NR==2{print $4}')"
  if [[ "$out" =~ $DISK_DF_RE ]]; then
    DISK_GB="$out"; DISK_SRC="df fallback"
  fi
  return 0
}

# --- CLI surface -------------------------------------------------------------
usage() {
  cat >&2 <<'USAGE'
usage: parallel-preflight.sh --expect-sims N --devices "UDID,UDID,..." [--quiet]
  --expect-sims N   REQUIRED, 0..64. Booted-sim count expected for this run.
  --devices LIST    REQUIRED. Comma-separated UDIDs the run will shard across.
  --quiet           Print only the VERDICT line.
Both value flags accept "--flag value" and "--flag=value", and may appear once.
exit: 0 GO | 1 NO-GO | 2 usage error
USAGE
}
die() { printf 'parallel-preflight: %s\n' "$*" >&2; usage; exit 2; }

# parse_args "$@" -- sets QUIET, EXPECTED_SIMS and DEVICES, or exits 2.
# Every branch validates before it consumes: `shift 2` with $# < 2 neither
# shifts nor fails the loop, which spins it forever with no output. An
# unrecognized argument is a hard error, never a silent skip -- a `--device`
# typo must not quietly turn the production-sim deny into a no-op. A repeated
# value flag is rejected rather than silently last-winning, because which
# occurrence wins would otherwise decide whether the deny fires.
parse_args() {
  QUIET=0
  EXPECTED_SIMS=""; SIMS_SET=0
  DEVICES=""; DEVICES_SET=0

  while [ $# -gt 0 ]; do
    case "$1" in
      --quiet) QUIET=1; shift ;;
      --expect-sims)
        [ "$SIMS_SET" -eq 0 ] || die "--expect-sims given more than once"
        [ $# -ge 2 ] || die "--expect-sims requires a value"
        EXPECTED_SIMS="$2"; SIMS_SET=1; shift; shift ;;
      --expect-sims=*)
        [ "$SIMS_SET" -eq 0 ] || die "--expect-sims given more than once"
        EXPECTED_SIMS="${1#*=}"; SIMS_SET=1; shift ;;
      --devices)
        [ "$DEVICES_SET" -eq 0 ] || die "--devices given more than once"
        [ $# -ge 2 ] || die "--devices requires a value"
        DEVICES="$2"; DEVICES_SET=1; shift; shift ;;
      --devices=*)
        [ "$DEVICES_SET" -eq 0 ] || die "--devices given more than once"
        DEVICES="${1#*=}"; DEVICES_SET=1; shift ;;
      *) die "unrecognized argument: $1" ;;
    esac
  done
  [ "$SIMS_SET" -eq 1 ] || die "--expect-sims is required (no default — a default would encode a host-state assumption)"
  [ "$DEVICES_SET" -eq 1 ] || die "--devices is required (an absent device list is UNKNOWN => NO-GO, never a skipped check)"
}
