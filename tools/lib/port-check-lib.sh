# port-check-lib.sh — input validation and live-truth (lsof) helpers for tools/port-check.sh.
# Sourced, never executed. Split out of port-check.sh because the review-round-1 fixes pushed it over
# agent-hq's 300-line source default (ADR 0016), whose stated remedy is to split, not to compress.
# Callers define EXIT_FREE=0, EXIT_TAKEN=1, EXIT_ERROR=3 before sourcing. Tests: tools/test_port-check.sh.
#
# LIVE TRUTH FAILS CLOSED: an lsof that is missing, cannot execute, or exits with anything other than
# "1 and no output" (lsof's "no match") supports no verdict about any port. It returns EXIT_ERROR, so
# a broken lsof can never read as "nothing listening" and turn into RESULT: FREE or a --claim append.

validate_port() {
  if ! [[ "${1}" =~ ^[0-9]+$ ]] || [ "${1}" -lt 1 ] || [ "${1}" -gt 65535 ]; then
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
  if [ "$3" != "-" ] && ! [[ "$3" =~ ^[0-9]+(-[0-9]+)?$ ]]; then
    echo "FAIL: --claim container_port '$3' must be '-', a port, or a numeric range." >&2; return "${EXIT_ERROR}"
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
