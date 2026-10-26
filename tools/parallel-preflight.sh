#!/usr/bin/env bash
# parallel-preflight.sh — runtime preflight: "is this host safe to fan out
# concurrent simulator work right now?"
#
# Read-only. Boots/kills/modifies nothing and creates no files.
#
# GOVERNING RULE: UNKNOWN => NO-GO. Absent, unparseable, out-of-range, erroring
# or unvalidated input never yields OK and is never silently skipped. See
# lib/preflight-lib.sh for the numeric primitives that enforce it.
#
# Source of truth: plans/<project>/probe/parallel-ops-design.md
# §5 "Executable guardrails" (2026-08-24): the 8 checks plus 4b, same order and
# thresholds, except 8081 is INVERTED (must be free; §5 line 229 is falsified).
#
# Usage: parallel-preflight.sh --expect-sims N --devices "UDID,UDID,..." [--quiet]
#   --expect-sims N   REQUIRED, 0..64. Booted-sim count expected for THIS run.
#                     No default: "expected for this run" is per-run input, and
#                     a default would silently encode a host-state assumption.
#   --devices "..."   REQUIRED. Comma-separated UDID list the runner intends to
#                     shard across; checked against the production-sim deny list.
#   --quiet           Print only the VERDICT line (which names failing checks).
# Exit: 0 GO | 1 NO-GO | 2 usage error.
#
# DISK_FREE_GB = macOS "available for important usage" (decimal GB, as Finder shows);
# df fallback, else UNKNOWN. Ladder + PATH-only test seam: lib/preflight-lib.sh.
#
# Deliberate divergences from §5 (tightening, plus the 8081 inversion above):
#   * §5 says "exactly one listener"; we count distinct PIDs, because one
#     dual-stack process emits an IPv4 and an IPv6 line and is still 1 listener.
#   * §5 and §2 make JAVA_HOME mandatory. An unset JAVA_HOME is NO-GO with the
#     brew-resolved export line printed as remediation — never a bare OK.
#
# NOTE: in the Claude Code Bash-tool shell (a zsh snapshot) `grep` is a shell function that silently returns empty for
# some inputs — every grep below uses `command grep`, never bare `grep`.

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LIB="$SCRIPT_DIR/lib/preflight-lib.sh"
if [ ! -r "$LIB" ]; then
  printf 'parallel-preflight: cannot read %s — refusing to run a half-loaded gate\n' "$LIB" >&2
  exit 2
fi
# shellcheck source=lib/preflight-lib.sh
. "$LIB"
# A readability test is not a load test: an empty, truncated, syntactically
# broken or foreign lib passes [ -r ], gets sourced, and then dies mid-run on
# `command not found`. Check the contract explicitly rather than relying on
# set -u to trip somewhere downstream.
for _fn in usage die parse_args report cmp_num is_num num_check run_timeout disk_free_probe; do
  if ! declare -F "$_fn" >/dev/null 2>&1; then
    printf 'parallel-preflight: %s did not define %s() — refusing to run a half-loaded gate\n' "$LIB" "$_fn" >&2
    exit 2
  fi
done
unset _fn

# Thresholds (source: parallel-ops-design.md §5)
TIME_WAIT_ABORT=1000
MEM_FREE_FLOOR_PCT=35
DISK_NOGO_GB=60
LOCKFILE="/tmp/measurement.lock"
PROD_SIM_UDID="C543AEAE-714B-4AD5-B181-5D05123F1DF6"
# Local guards, not from §5:
EXPECT_SIMS_MAX=64          # range-validate --expect-sims, not just its shape
JAVA_TIMEOUT_SECS=10        # /usr/bin/java (the macOS stub) can block for minutes
DISK_PROBE_TIMEOUT_SECS=10  # bounds the important-usage probe (measured ~0.1s)
UDID_RE='[0-9A-Fa-f]{8}-([0-9A-Fa-f]{4}-){3}[0-9A-Fa-f]{12}'

parse_args "$@"

# --- 1. Ephemeral ports (TIME_WAIT) ------------------------------------------
T1="abort >${TIME_WAIT_ABORT}"
netstat_out="$(netstat -an 2>/dev/null)"
netstat_lines="$(printf '%s\n' "$netstat_out" | command grep -c .)"
# positive control: a healthy netstat emits far more than a handful of lines;
# fewer means the instrument broke, not that TIME_WAIT is genuinely absent.
if [ -z "$netstat_out" ] || ! is_num "$netstat_lines" 9 || ! cmp_num "$netstat_lines" -ge 5; then
  report TIME_WAIT "UNKNOWN" "$T1" "NO-GO(unknown)"
else
  num_check TIME_WAIT "$(printf '%s\n' "$netstat_out" | command grep -c TIME_WAIT)" \
    -gt "$TIME_WAIT_ABORT" "$T1"
fi

# --- 2. Free system memory ----------------------------------------------------
# Anchored to the label. An unanchored "first [0-9]+% anywhere in the output"
# can silently read the wrong number and still look perfectly well-formed.
T2="abort <${MEM_FREE_FLOOR_PCT}%"
mem_line="$(memory_pressure -Q 2>/dev/null | command grep -E '^System-wide memory free percentage: *[0-9]+%$')"
mem_line_n="$(printf '%s\n' "$mem_line" | command grep -c .)"
if [ "$mem_line_n" != "1" ]; then
  report MEM_FREE "UNKNOWN" "$T2" "NO-GO(unknown)"
else
  mem_free_pct="$(printf '%s\n' "$mem_line" | sed -E 's/^.*: *([0-9]+)%$/\1/')"
  if ! is_num "$mem_free_pct" 3 || ! cmp_num "$mem_free_pct" -le 100; then
    report MEM_FREE "UNKNOWN" "$T2" "NO-GO(unknown)"
  else
    num_check MEM_FREE "$mem_free_pct" -lt "$MEM_FREE_FLOOR_PCT" "$T2" "%"
  fi
fi

# --- 3. Booted simulator count must equal expected ---------------------------
T3="must equal ${EXPECTED_SIMS}"
if ! is_num "$EXPECTED_SIMS" 3 || ! cmp_num "$EXPECTED_SIMS" -le "$EXPECT_SIMS_MAX"; then
  report SIM_BOOTED "UNKNOWN" "$T3" "NO-GO(unknown)"
  NOTES+=("SIM_BOOTED: --expect-sims must be an integer 0..${EXPECT_SIMS_MAX}; got '${EXPECTED_SIMS}'.")
else
  sim_out="$(xcrun simctl list devices booted 2>/dev/null)"
  # positive control: a working simctl always prints the "== Devices ==" header
  if ! printf '%s\n' "$sim_out" | command grep -q '== Devices =='; then
    report SIM_BOOTED "UNKNOWN" "$T3" "NO-GO(unknown)"
  else
    num_check SIM_BOOTED "$(printf '%s\n' "$sim_out" | command grep -c '(Booted)')" \
      -ne "$EXPECTED_SIMS" "$T3"
  fi
fi

# --- 4/4b. Ports 8081 + 11001: free (lanes bind 11100-11179 via 11100 + (TICKET % 80); Expo default 11001) ---
# FALSIFIED 2026-08-26. lsof -nP -iTCP:8081 -sTCP:LISTEN returns no listener at all
# (control: 50 host-wide LISTEN rows); <project>-relay is <project>'s health port and only
# binds while <project> runs. 8081 free is the healthy state — lanes bind 11100+(TICKET%80).
# 11001 is the current Expo default (RCT_METRO_PORT): once committed, a fallen-back
# `expo start` lands there instead of 8081, so both ports need the same trap.
# Any listener on either = an expo start that skipped its assigned port. Deliberately
# inverts parallel-ops-design.md §5 line 229 (see header), which is falsified.
#
# port_trap_probe: shared body for both traps. Positive control reuses lsof_any
# (set once below); distinct PIDs, not lines, since a dual-stack listener emits
# IPv4 + IPv6 rows and is still one listener.
port_trap_probe() {
  local port="$1" check_id="$2" threshold="$3" body pids squatters
  if ! is_num "$lsof_any" 9 || ! cmp_num "$lsof_any" -ge 1; then
    report "$check_id" "UNKNOWN" "$threshold" "NO-GO(unknown)"
    return
  fi
  body="$(lsof -nP -iTCP:"$port" -sTCP:LISTEN +c 0 2>/dev/null | command grep '(LISTEN)')"
  pids="$(printf '%s\n' "$body" | awk '{print $2}' | sort -u | command grep -c .)"
  if [ "$pids" = "0" ]; then
    report "$check_id" "free(ctl=${lsof_any})" "$threshold" "OK"
  else
    squatters="$(printf '%s\n' "$body" | awk '{print $1}' | sort -u | tr '\n' ',')"
    report "$check_id" "$squatters" "$threshold" "NO-GO"
  fi
}

T4="0 listeners (lanes use 11100-11179; legacy Expo default, still hard-banned, must be free)"
T4B="0 listeners (current Expo default — any listener is a bare expo start that skipped its assigned port)"
# positive control: confirm lsof can see *some* TCP listener before trusting an
# empty result on 8081/11001.
lsof_any="$(lsof -nP -iTCP -sTCP:LISTEN +c 0 2>/dev/null | command grep -c '(LISTEN)')"
port_trap_probe 8081 RELAY_8081 "$T4"
port_trap_probe 11001 EXPO_DEFAULT_11001 "$T4B"

# --- 5. Disk headroom on / ---------------------------------------------------
T5="abort <${DISK_NOGO_GB}"
disk_free_probe "$DISK_PROBE_TIMEOUT_SECS"
num_check DISK_FREE_GB "$DISK_GB" -lt "$DISK_NOGO_GB" "$T5" " (${DISK_SRC})"
[ "$DISK_SRC" = "important" ] || NOTES+=("DISK_FREE_GB: important-usage probe unusable (rc ${DISK_PROBE_RC}, or non-integer output); source=${DISK_SRC}.")

# --- 6. Java reachable (the false blocker, made unskippable) ----------------
T6="java -version must succeed <${JAVA_TIMEOUT_SECS}s"
if [ -z "${JAVA_HOME:-}" ]; then
  # §5's command is literally "$JAVA_HOME/bin/java" and §2 calls JAVA_HOME
  # mandatory. Silently substituting a brew-resolved path hands back a bare OK
  # and then lets the runner hit the exact false blocker this check exists to
  # prevent, so an unset JAVA_HOME is NO-GO. The brew resolution is kept, but
  # demoted to remediation the caller can act on.
  report JAVA "unset-JAVA_HOME" "$T6" "NO-GO"
  brew_prefix="$(brew --prefix openjdk 2>/dev/null)"
  if [ -n "$brew_prefix" ]; then
    NOTES+=("JAVA: JAVA_HOME is unset and is mandatory (design §2, §5). Remediation:")
    NOTES+=("        export JAVA_HOME=\"${brew_prefix}/libexec/openjdk.jdk/Contents/Home\"")
  else
    NOTES+=("JAVA: JAVA_HOME unset and 'brew --prefix openjdk' resolved nothing.")
  fi
else
  run_timeout "$JAVA_TIMEOUT_SECS" "$JAVA_HOME/bin/java" -version; java_rc=$?
  if [ "$java_rc" -eq 124 ]; then
    # a wait that never returns is an unknown — not a pass, not a clean fail
    report JAVA "TIMEOUT" "$T6" "NO-GO(unknown)"
    NOTES+=("JAVA: \"\$JAVA_HOME/bin/java\" -version did not return within ${JAVA_TIMEOUT_SECS}s")
    NOTES+=("        (JAVA_HOME=${JAVA_HOME}). The macOS /usr/bin/java stub blocks like this.")
  elif [ "$java_rc" -ne 0 ]; then
    report JAVA "exit-${java_rc}" "$T6" "NO-GO"
    NOTES+=("JAVA: \"\$JAVA_HOME/bin/java\" -version exited ${java_rc} (JAVA_HOME=${JAVA_HOME}).")
  else
    # positive control: prove a FAILING java is observable as failing before
    # trusting the rc=0 above. An unrecognized -XX option must exit non-zero;
    # if it does not, this check cannot tell a pass from a fail at all. This
    # control is reachable on exactly the path §5 describes (JAVA_HOME set).
    run_timeout "$JAVA_TIMEOUT_SECS" "$JAVA_HOME/bin/java" -XXpreflightControlInvalid -version
    ctl_rc=$?
    if [ "$ctl_rc" -eq 124 ]; then
      # 124 is non-zero, so testing only "rc != 0" would read a HUNG control as
      # a passed control and hand back OK — the same fail-open shape this file
      # exists to remove. A control that did not return proves nothing.
      report JAVA "CONTROL-TIMEOUT" "$T6" "NO-GO(unknown)"
      NOTES+=("JAVA: the positive control did not return within ${JAVA_TIMEOUT_SECS}s, so")
      NOTES+=("        nothing vouches for the java -version success above.")
    elif [ "$ctl_rc" -eq 0 ]; then
      report JAVA "UNKNOWN" "$T6" "NO-GO(unknown)"
      NOTES+=("JAVA: positive control failed — a deliberately invalid java flag exited 0,")
      NOTES+=("        so a real java failure would not have been detected either.")
    else
      report JAVA "exec-ok" "$T6" "OK"
    fi
  fi
fi

# --- 7. No measurement running (quiescence lockfile) -------------------------
T7="abort if lockfile exists"
lock_dir="$(dirname "$LOCKFILE")"
lock_probe="${lock_dir}/.parallel-preflight-absent-probe-$$"
# positive control, both arms: the very -e/-L test used below must report an
# entry that certainly EXISTS (the lock's own directory) as present, and one
# that certainly does NOT (a pid-unique name this script never creates) as
# absent. `[ ! -d /tmp ]` alone can never be false, so it proved nothing.
if [ ! -d "$lock_dir" ] || [ ! -r "$lock_dir" ] || [ ! -e "$lock_dir" ] \
   || [ -e "$lock_probe" ] || [ -L "$lock_probe" ]; then
  report MEASURE_LOCK "UNKNOWN" "$T7" "NO-GO(unknown)"
elif [ -e "$LOCKFILE" ] || [ -L "$LOCKFILE" ]; then
  # -L as well: `[ -e ]` alone reports a DANGLING lock symlink as absent.
  report MEASURE_LOCK "PRESENT" "$T7" "NO-GO"
  # Provenance (read-only): the lock is a plain file claimed and removed by hand (this repo
  # has no claim/release script). Surfacing its first lines here shows the operator what is
  # in the lock and whether it is plausibly stale.
  if [ -f "$LOCKFILE" ] && [ -r "$LOCKFILE" ]; then
    while IFS= read -r _lockline; do
      NOTES+=("MEASURE_LOCK: ${_lockline}")
    done < <(head -3 "$LOCKFILE" | tr -cd '[:print:]\n')
    unset _lockline
  else
    NOTES+=("MEASURE_LOCK: lockfile present but unreadable/non-regular — inspect $LOCKFILE manually.")
  fi
  NOTES+=("MEASURE_LOCK: after confirming no measurement is running, release by removing the lockfile: rm -- $LOCKFILE")
else
  report MEASURE_LOCK "absent" "$T7" "OK"
fi

# --- 8. Production sim untargeted (shard device list) -----------------------
T8="must exclude prod UDID"
# TWO gates, because `grep -q` validates LINE-AT-A-TIME, not the whole value:
# "$SCRATCH\n$PROD" satisfies "^UDID(,UDID)*$" on its first line while the prod
# UDID rides along on the second, and an IFS=',' split then keeps that newline
# INSIDE one element, so the exact compare below could never match it. A
# newline-separated list is exactly what `simctl list ... | grep -Eo "$UDID_RE"`
# produces, so this is a plausible first-try runner bug, not an exotic input.
#   Gate 1 - no byte outside [0-9A-Fa-f,-] anywhere in the value. Counted in
#     BYTES on purpose: holding the residue in "$(...)" lets command
#     substitution strip a trailing newline, and the gate then fails open.
#   Gate 2 - the shape match, which Gate 1 has now guaranteed sees one line.
dev_residue="$(printf '%s' "$DEVICES" | LC_ALL=C tr -d '0-9A-Fa-f,-' | wc -c | tr -d ' ')"
if ! is_num "$dev_residue" 9 || [ "$dev_residue" -ne 0 ] \
   || ! printf '%s' "$DEVICES" | command grep -Eq "^${UDID_RE}(,${UDID_RE})*\$"; then
  report PROD_SIM_DENY "UNKNOWN" "$T8" "NO-GO(unknown)"
  NOTES+=("PROD_SIM_DENY: --devices is empty, is not a comma-separated UDID list,")
  NOTES+=("        or carries a byte outside [0-9A-Fa-f,-] (newline, CR and space")
  NOTES+=("        included). An unvalidated device list cannot clear the deny.")
else
  # Case-insensitive, per-element, EXACT compare. simctl resolves a lowercase
  # UDID to the same device, and a substring grep over the raw list is neither
  # case-correct nor element-bounded.
  prod_uc="$(printf '%s' "$PROD_SIM_UDID" | tr '[:lower:]' '[:upper:]')"
  found_prod=0
  # split on newline as well as comma: defence in depth, so that even if Gate 1
  # is ever weakened a newline still bounds an element instead of hiding in one.
  saved_ifs="$IFS"; IFS=$',\n'; set -f; dev_arr=( $DEVICES ); set +f; IFS="$saved_ifs"
  for d in "${dev_arr[@]}"; do
    if [ "$(printf '%s' "$d" | tr '[:lower:]' '[:upper:]')" = "$prod_uc" ]; then found_prod=1; fi
  done
  if [ "$found_prod" -eq 1 ]; then
    report PROD_SIM_DENY "FOUND" "$T8" "NO-GO"
  else
    report PROD_SIM_DENY "excluded" "$T8" "OK"
  fi
fi

# --- Output ------------------------------------------------------------------
# No check can be SKIPPED any more, so "a check did not run" always reaches a
# NO-GO verdict — and --quiet names the failing checks, so even a single-line
# consumer learns which instrument was blind.
if [ "$NOGO" -eq 0 ]; then
  VERDICT="GO"
else
  VERDICT="NO-GO (${FAILED})"
fi

if [ "$QUIET" -eq 0 ]; then
  for l in "${LINES[@]}"; do printf '%s\n' "$l"; done
  if [ "${#NOTES[@]}" -gt 0 ]; then
    printf '\n'
    for n in "${NOTES[@]}"; do printf '%s\n' "$n"; done
  fi
  printf '\nVERDICT: %s\n' "$VERDICT"
else
  printf 'VERDICT: %s\n' "$VERDICT"
fi

if [ "$NOGO" -eq 0 ]; then exit 0; fi
exit 1
