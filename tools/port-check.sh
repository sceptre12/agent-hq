#!/usr/bin/env bash
# tools/port-check.sh — check-before-bind against tools/ports.tsv (architecture/port-registry.md).
#
# WHY THIS EXISTS: a launch can bind a port another service already holds and knock it over. This script is the
# check-before-bind: one registry (tools/ports.tsv) plus live `lsof` truth, and a hard refusal to auto-pick on a hit
# (refuse on collision, never autopick). A docker healthcheck only proves the CONTAINER port answers (architecture
# SS5.2), so the registry is checked against host-side `lsof`, not against anything observed inside a container.
#
# Provenance: ported from hq tools/port-check.sh. Ported into agent-hq 2026-10-26 (delivery workflow, port guard). Mentions of plans/, inbox/ and survey files
# in this header and in architecture/port-registry.md point at hq-only records that are not mirrored here.
#
# `command grep`, never bare `grep`, throughout: this shell wraps `grep` in a function that can
# silently return nothing, turning a taken port into a false "free" — an unqualified `grep` call is
# banned on purpose, verified by an independent test (V2).
#
# NO -P ANYWHERE: `command grep` here resolves to BSD grep 2.6.0, which has no PCRE support. `-P` on
# the wrapped `grep` would silently route through the shell's ugrep-backed function instead of
# bypassing it — defeating the entire point. Every pattern below is POSIX ERE (`-E`), and a literal
# tab is written with bash ANSI-C quoting (`$'\t'`), never `\t` inside a regular string.
#
# RANGES ARE EXPANDED NUMERICALLY, NOT TEXT-MATCHED (architecture SS8 item 2): the biggest claims are
# ranges (`9000-9999`, `11100-11179`), and `command grep -E '^9500\b'` never matches a row whose port
# field is `9000-9999` — port_matches() below does an integer bounds comparison instead.
#
# FAILS CLOSED, AT FILE *AND* ROW LEVEL: an unreadable/empty registry, a malformed usage, an internal
# error, or ANY structurally invalid row is a loud non-zero exit — never a silent "must be free". The
# read carries a positive control (`command grep -c ""` > 0 lines, architecture SS5.3); validate_rows()
# then requires 9 tab-separated fields, a numeric port, and a status inside SS2.1's closed enum. A bad
# row exits 3 like the file-level failures, NOT 1: exit 1 means "registry and live truth disagree", a
# claim about the world, whereas an unparseable row supports no verdict about any port at all, so
# "free" must not be reachable. Skipping it is what this replaces — a blank port field used to
# `continue` silently out of both the check and the audit, and reached --audit's CONFLICT dedup.
# Live truth fails closed too: a missing or failing lsof exits 3, never FREE (tools/lib/port-check-lib.sh).
# --claim refuses (exit 3) any field holding a control character, an empty field, or a non-port
# container_port, before anything is written, so one bad claim cannot poison the shared registry.
#
# MODES
#   port-check.sh <port>                          registry + lsof lookup for one host port
#   port-check.sh --claim <port> <bind> <container_port> <service> <project> <status> <source> <note>
#                 [--force]                        re-check, then append exactly one TSV line; --force
#                                                  overrides exit 1/2 only, never 3; self-release needs none
#   port-check.sh --audit                          classify active rows against lsof: MATCH / GHOST
#                                                  (live rows), SQUATTER, CONFLICT
#
# EXIT CODES
#   0  check: free (no registry hit, nothing listening) | claim: appended | audit: no findings
#   1  check: taken (registry and/or lsof agree) | claim: refused on a non-forced conflict | audit:
#      at least one GHOST/SQUATTER/CONFLICT found
#   2  check/claim: registry vs lsof DISAGREE (staleness signal — hard stop, never a warning)
#   3  usage error, a refused --claim field, the registry is unusable (missing / empty / unreadable /
#      malformed row), lsof is missing or failed, or --audit could not create its temp file
#
# ENV (test injection only — never point this at the real registry from a test)
#   PORT_REGISTRY_FILE   default: <this script's dir>/ports.tsv
#
# CONCURRENCY: --claim appends exactly one line with `>>` (O_APPEND, single short write) and does NO
# read-modify-write — see architecture SS1's concurrency contract. Two concurrent --claim calls both
# land as two rows; a duplicate port is a CONFLICT for --audit to surface, not one it arbitrates.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REGISTRY_FILE="${PORT_REGISTRY_FILE:-${SCRIPT_DIR}/ports.tsv}"
# shellcheck source=lib/port-check-lib.sh
. "${SCRIPT_DIR}/lib/port-check-lib.sh" || { echo "FAIL: cannot load ${SCRIPT_DIR}/lib/port-check-lib.sh — failing closed." >&2; exit 3; }

EXIT_FREE=0; EXIT_TAKEN=1        # see EXIT CODES in the header
EXIT_DISAGREE=2; EXIT_ERROR=3
STATUS_ENUM_RE='^(live|claimed|reserved|unmerged|released|UNVERIFIED)$'   # architecture SS2.1, closed

AUDIT_TMP=""
# Trap body must always evaluate to 0: an EXIT trap's own status otherwise overwrites the script's
# real exit code (verified — it reproduced during authoring when AUDIT_TMP was empty and
# `[ -n "" ]` made the trap "fail").
cleanup() { rm -f "${AUDIT_TMP}" 2>/dev/null; return 0; }
trap cleanup EXIT

usage() {
  printf '%s\n' "USAGE:" "  port-check.sh <port>" \
    "  port-check.sh --claim <port> <bind> <container_port> <service> <project> <status> <source> <note> [--force]" \
    "  port-check.sh --audit" >&2
}

# load_registry — existence + positive-control read + validate_rows. Fails closed rather than
# treating an unreadable, empty or malformed file as "no claims exist".
load_registry() {
  if [ ! -f "${REGISTRY_FILE}" ]; then
    echo "FAIL: registry not found: ${REGISTRY_FILE} — failing closed." >&2
    return "${EXIT_ERROR}"
  fi
  local total_lines
  total_lines="$(command grep -c "" "${REGISTRY_FILE}" 2>/dev/null || true)"
  if [ -z "${total_lines}" ] || [ "${total_lines}" -eq 0 ]; then
    echo "FAIL: ${REGISTRY_FILE} read as empty by 'command grep -c \"\"' — failing closed rather than treating an empty read as an empty registry." >&2
    return "${EXIT_ERROR}"
  fi
  validate_rows || return $?
  return "${EXIT_FREE}"
}

# validate_rows — structural gate over every non-comment row, run by load_registry so every mode gets
# it. See "FAILS CLOSED, AT FILE *AND* ROW LEVEL" above for why a bad row is exit 3, never a skip; a
# numeric field 1 is also what keeps a non-port token out of cmd_audit's raw-port-field dedup.
validate_rows() {
  local bad; bad="$(registry_rows | awk -F'\t' -v sre="${STATUS_ENUM_RE}" '
    NF != 9 { printf "  row %d: %d fields, expected 9\n", NR, NF; next }
    $1 !~ /^[0-9]+(-[0-9]+)?$/ { printf "  row %d: port \"%s\" is not a port or a numeric range\n", NR, $1; next }
    $6 !~ sre { printf "  row %d: status \"%s\" is not in the closed enum (architecture SS2.1)\n", NR, $6 }')"
  if [ -n "${bad}" ]; then
    echo "FAIL: ${REGISTRY_FILE} has malformed row(s) — failing closed (row N = Nth non-comment row):" >&2
    echo "${bad}" >&2
    return "${EXIT_ERROR}"
  fi
  return "${EXIT_FREE}"
}

# registry_rows — every non-header, non-blank line, raw (still may include released rows).
registry_rows() {
  command grep -v '^#' "${REGISTRY_FILE}" | command grep -vE '^[[:space:]]*$' || true
}

# active_rows — registry_rows minus released rows (SS2.1) and rows superseded by a LATER released row (same port field AND source; file order).
active_rows() {
  registry_rows | awk -F'\t' '{ k[NR]=$1 "\t" $7; l[NR]=$0; s[NR]=$6; if ($6=="released") r[k[NR]]=NR }
    END { for (i=1;i<=NR;i++) if (s[i]!="released" && !(k[i] in r && r[k[i]]>i)) print l[i] }' || true
}

# cmd_check <port> — registry lookup (host-side and, informationally, container-side) + lsof.
cmd_check() {
  local port="$1"
  validate_port "${port}" || return $?
  load_registry || return $?

  local host_hit=0 has_live_row=0 host_report="" container_report=""
  while IFS=$'\t' read -r f_port f_bind f_cport f_service f_project f_status f_source f_verified f_note; do
    if port_matches "${port}" "${f_port}"; then
      host_hit=1
      host_report="${host_report}
  [${f_status}] port=${f_port} bind=${f_bind} service=${f_service} project=${f_project} source=${f_source}"
      [ "${f_status}" = "live" ] && has_live_row=1
    fi
    if [ "${f_cport}" != "-" ] && port_matches "${port}" "${f_cport}"; then
      container_report="${container_report}
  [${f_status}] container_port=${f_cport} host_port=${f_port} service=${f_service} project=${f_project}"
    fi
  done < <(active_rows)

  local live_hit=0 lsof_rc=0
  lsof_port "${port}" || lsof_rc=$?
  case "${lsof_rc}" in
    0) live_hit=1 ;;
    1) ;;
    *) return "${EXIT_ERROR}" ;;   # lsof missing/failed: no verdict, never FREE (lib FAIL line on stderr)
  esac

  echo "port-check: ${port}"
  if [ "${host_hit}" -eq 1 ]; then echo "registry (host-side): HIT${host_report}"; else echo "registry (host-side): no row"; fi
  if [ -n "${container_report}" ]; then echo "registry (container-side, informational only):${container_report}"; fi
  if [ "${live_hit}" -eq 1 ]; then echo "lsof: LISTENING"; echo "${LSOF_OUT}"; else echo "lsof: nothing listening"; fi

  if [ "${live_hit}" -eq 1 ] && [ "${host_hit}" -eq 1 ]; then
    echo "RESULT: TAKEN (registry and lsof agree)"; return "${EXIT_TAKEN}"
  elif [ "${live_hit}" -eq 1 ] && [ "${host_hit}" -eq 0 ]; then
    echo "RESULT: DISAGREEMENT — listening, but no registry row accounts for it."; return "${EXIT_DISAGREE}"
  elif [ "${live_hit}" -eq 0 ] && [ "${host_hit}" -eq 1 ] && [ "${has_live_row}" -eq 1 ]; then
    echo "RESULT: DISAGREEMENT — registry says live, nothing is listening (stale row)."; return "${EXIT_DISAGREE}"
  elif [ "${live_hit}" -eq 0 ] && [ "${host_hit}" -eq 1 ]; then
    echo "RESULT: TAKEN (registry claims/reserves this port; not currently bound)"; return "${EXIT_TAKEN}"
  else
    echo "RESULT: FREE"; return "${EXIT_FREE}"
  fi
}

# cmd_claim <port> <bind> <container_port> <service> <project> <status> <source> <note> [--force]
cmd_claim() {
  local force=0
  if [ "$#" -gt 0 ]; then
    local last="${*: -1}"
    if [ "${last}" = "--force" ]; then
      force=1
      set -- "${@:1:$(($#-1))}"
    fi
  fi
  if [ "$#" -ne 8 ]; then usage; return "${EXIT_ERROR}"; fi
  local c_port="$1" c_bind="$2" c_cport="$3" c_service="$4" c_project="$5" c_status="$6" c_source="$7" c_note="$8"

  validate_port "${c_port}" || return $?
  validate_claim_fields "$@" || return $?
  if ! [[ "${c_status}" =~ ${STATUS_ENUM_RE} ]]; then
    echo "FAIL: status '${c_status}' is not in architecture SS2.1's closed enum — refusing to append a row that would fail every later read closed." >&2
    return "${EXIT_ERROR}"
  fi
  load_registry || return $?

  local check_ec=0
  cmd_check "${c_port}" >/dev/null 2>&1 || check_ec=$?
  # Exit 3 is "no verdict" (lsof or registry broken): nothing overrides it, not even --force.
  if [ "${check_ec}" -ne 0 ] && [ "${check_ec}" -ne "${EXIT_TAKEN}" ] && [ "${check_ec}" -ne "${EXIT_DISAGREE}" ]; then
    echo "FAIL: refusing --claim on ${c_port} — check exited ${check_ec} (no verdict); --force cannot override this." >&2
    return "${check_ec}"
  fi
  # Self-release: a `released` claim for a port whose every active row is held by the same project
  # needs no --force (architecture SS4); --force is only for taking over another holder's row.
  if [ "${check_ec}" -ne 0 ] && [ "${force}" -ne 1 ] && ! { [ "${c_status}" = "released" ] && active_rows | held_only_by "${c_port}" "${c_project}"; }; then
    echo "FAIL: refusing --claim on ${c_port} — check reports exit ${check_ec} (not free). Pass --force to override (note gets a 'forced' prefix)." >&2
    return "${check_ec}"
  fi
  if [ "${check_ec}" -ne 0 ] && [ "${force}" -eq 1 ]; then
    if [ "${c_note}" = "-" ]; then c_note="forced"; else c_note="forced: ${c_note}"; fi
  fi
  [ "${c_status}" = "released" ] && ! registry_rows | awk -F'\t' -v p="${c_port}" -v s="${c_source}" '$1==p && $7==s && $6!="released" {f=1} END {exit !f}' && echo "WARNING: this release supersedes no claim — no earlier non-released row has port ${c_port} and source '${c_source}' (release must repeat the claim's exact source); appending anyway." >&2

  local verified row
  verified="$(date +%F)"
  row="$(printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s' \
    "${c_port}" "${c_bind}" "${c_cport}" "${c_service}" "${c_project}" "${c_status}" "${c_source}" "${verified}" "${c_note}")"

  if ! printf '%s\n' "${row}" >> "${REGISTRY_FILE}"; then
    echo "FAIL: could not append to ${REGISTRY_FILE}." >&2
    return "${EXIT_ERROR}"
  fi
  echo "CLAIMED: ${row}"
  return "${EXIT_FREE}"
}

# cmd_audit — active rows vs live truth (architecture SS5.1): live rows MATCH/GHOST, unaccounted
# listeners SQUATTER, duplicate active ports CONFLICT.
cmd_audit() {
  load_registry || return $?
  AUDIT_TMP="$(mktemp "${TMPDIR:-/tmp}/port-check.XXXXXX")" || {
    echo "FAIL: --audit could not create a temp file under ${TMPDIR:-/tmp} — failing closed." >&2; return "${EXIT_ERROR}"; }
  live_listen_ports > "${AUDIT_TMP}" || return "${EXIT_ERROR}"

  local problems=0

  while IFS=$'\t' read -r f_port f_bind f_cport f_service f_project f_status f_source f_verified f_note; do
    [ "${f_status}" != "live" ] && continue
    local hit=0 lp
    while IFS= read -r lp; do
      [ -z "${lp}" ] && continue
      if port_matches "${lp}" "${f_port}"; then hit=1; break; fi
    done < "${AUDIT_TMP}"
    if [ "${hit}" -eq 1 ]; then
      echo "MATCH    port=${f_port} service=${f_service} project=${f_project}"
    else
      echo "GHOST    port=${f_port} service=${f_service} project=${f_project} (registry says live, nothing listening)"
      problems=1
    fi
  done < <(active_rows)

  local lp
  while IFS= read -r lp; do
    [ -z "${lp}" ] && continue
    local accounted=0 f_port f_bind f_cport f_service f_project f_status f_source f_verified f_note
    while IFS=$'\t' read -r f_port f_bind f_cport f_service f_project f_status f_source f_verified f_note; do
      if port_matches "${lp}" "${f_port}"; then accounted=1; break; fi
      if [ "${f_cport}" != "-" ] && port_matches "${lp}" "${f_cport}"; then accounted=1; break; fi
    done < <(active_rows)
    if [ "${accounted}" -eq 0 ]; then
      echo "SQUATTER port=${lp} (listening, no registry row accounts for it)"
      problems=1
    fi
  done < "${AUDIT_TMP}"

  local dupes; dupes="$(active_rows | awk -F'\t' '{print $1}' | sort | uniq -d || true)"
  if [ -n "${dupes}" ]; then
    local dp
    while IFS= read -r dp; do
      [ -z "${dp}" ] && continue
      echo "CONFLICT port=${dp} — multiple non-released rows claim this exact port:"
      active_rows | awk -F'\t' -v p="${dp}" '$1==p {print "  " $0}'
      problems=1
    done <<< "${dupes}"
  fi

  if [ "${problems}" -eq 0 ]; then echo "AUDIT: clean"; return "${EXIT_FREE}"; fi
  echo "AUDIT: findings reported above"
  return "${EXIT_TAKEN}"
}

main() {
  local mode="${1:-}"
  case "${mode}" in
    --claim)        shift; cmd_claim "$@" ;;
    --audit)        cmd_audit ;;
    -h|--help|"")   usage; return "${EXIT_ERROR}" ;;
    *)              cmd_check "${mode}" ;;
  esac
}

main "$@"
