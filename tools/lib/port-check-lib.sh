# port-check-lib.sh — input validation and live-truth (lsof) helpers for tools/port-check.sh.
# Sourced, never executed. Split out of port-check.sh because the review-round-1 fixes pushed it over
# agent-hq's 300-line source default (ADR 0016), whose stated remedy is to split, not to compress.
# The functions read EXIT_FREE=0 / EXIT_ERROR=3 at call time; the caller defines them. Tests: tools/test_port-check.sh.
#
# LIVE TRUTH FAILS CLOSED: an lsof that is missing, cannot execute, or exits with anything other than
# "1 and no output" (lsof's "no match") supports no verdict about any port. It returns EXIT_ERROR, so
# a broken lsof can never read as "nothing listening" and turn into RESULT: FREE or a --claim append
# (cmd_claim refuses check exit 3 even with --force).

# Canonical decimal only: no leading zero (045010 would text-miss a 45010 row and read FREE) and at most
# 5 digits (a 20-digit value overflows the integer test), checked before the numeric range test.
validate_port() {
  if ! [[ "${1}" =~ ^[1-9][0-9]{0,4}$ ]] || [ "${1}" -gt 65535 ]; then
    echo "FAIL: '${1}' is not a valid TCP port (1-65535)." >&2
    return "${EXIT_ERROR}"
  fi
  return "${EXIT_FREE}"
}

# port_matches <candidate-port> <registry-port-field> — the field is an exact port ("9000") or a
# numeric range ("9000-9999"), expanded by integer comparison (architecture SS8 item 2), never text.
port_matches() {
  local candidate="$1" field="$2"
  case "${field}" in
    *-*)
      local lo="${field%%-*}" hi="${field##*-}"
      if [[ "${lo}" =~ ^[0-9]+$ ]] && [[ "${hi}" =~ ^[0-9]+$ ]]; then
        [ "${candidate}" -ge "${lo}" ] && [ "${candidate}" -le "${hi}" ]; return $?
      fi
      return 1
      ;;
    *)
      [ "${candidate}" = "${field}" ]
      ;;
  esac
}

# held_only_by <port> <project> < active-rows — 0 when at least one row on stdin covers <port> and every
# such row's project is <project> (cmd_claim's self-release test); 1 otherwise.
held_only_by() {
  local n=0 f_port f_project
  while IFS=$'\t' read -r f_port _ _ _ f_project _; do
    port_matches "$1" "${f_port}" || continue
    [ "${f_project}" = "$2" ] || return 1
    n=$((n + 1))
  done
  [ "${n}" -gt 0 ]
}

# validate_claim_fields <port> <bind> <container_port> <service> <project> <status> <source> <note>
# Runs before anything is written. A tab or newline in any field would change the row's field count
# (every later read then fails closed machine-wide) or forge an extra row, so every control character
# is refused. Empty fields are refused too (use "-"): `IFS=$'\t' read` collapses empty middle fields.
validate_claim_fields() {
  local names="port bind container_port service project status source note" name v
  for v in "$@"; do
    name="${names%% *}"; names="${names#* }"
    if [ -z "${v}" ]; then
      echo "FAIL: --claim field '${name}' is empty (use '-' for none)." >&2; return "${EXIT_ERROR}"
    fi
    if [[ "${v}" =~ [[:cntrl:]] ]]; then
      echo "FAIL: --claim field '${name}' contains a control character (tab, newline or other); refusing to write." >&2
      return "${EXIT_ERROR}"
    fi
  done
  if [ "$3" != "-" ]; then
    local lo="${3%%-*}" hi="${3##*-}"
    if ! [[ "$3" =~ ^[0-9]+(-[0-9]+)?$ ]] || ! validate_port "${lo}" 2>/dev/null || ! validate_port "${hi}" 2>/dev/null; then
      echo "FAIL: --claim container_port '$3' must be '-', a port (1-65535, no leading zero), or a range of two." >&2; return "${EXIT_ERROR}"
    fi
  fi
  return "${EXIT_FREE}"
}

# lsof_run <lsof args...> — sets LSOF_OUT. Returns EXIT_FREE (0) with output = something matched,
# 1 with empty output = nothing matched, EXIT_ERROR on a missing or failing lsof (with a FAIL line).
LSOF_OUT=""
lsof_run() {
  LSOF_OUT=""
  if ! command -v lsof >/dev/null 2>&1; then
    echo "FAIL: lsof not found on PATH — cannot read live truth; failing closed." >&2
    return "${EXIT_ERROR}"
  fi
  local rc=0
  LSOF_OUT="$(lsof "$@" 2>/dev/null)" || rc=$?
  if [ "${rc}" -eq 0 ] && [ -n "${LSOF_OUT}" ]; then return 0; fi
  if [ "${rc}" -eq 1 ] && [ -z "${LSOF_OUT}" ]; then return 1; fi
  echo "FAIL: lsof $* exited ${rc} (output $([ -n "${LSOF_OUT}" ] && echo present || echo empty)) — cannot read live truth; failing closed." >&2
  return "${EXIT_ERROR}"
}

# lsof_port <port> — 0 listening (LSOF_OUT holds the rows), 1 not listening, EXIT_ERROR on failure.
lsof_port() { lsof_run -nP -iTCP:"$1" -sTCP:LISTEN; }

# live_listen_ports — every host port currently in LISTEN state, one per line, deduped+sorted.
# Returns EXIT_ERROR (printing nothing) when lsof is missing or fails.
live_listen_ports() {
  local rc=0
  lsof_run -nP -iTCP -sTCP:LISTEN || rc=$?
  [ "${rc}" -eq 1 ] && return 0
  [ "${rc}" -ne 0 ] && return "${rc}"
  printf '%s\n' "${LSOF_OUT}" | tail -n +2 | awk '{print $9}' \
    | sed -E 's/.*:([0-9]+)$/\1/' | command grep -E '^[0-9]+$' | sort -un || true
}
