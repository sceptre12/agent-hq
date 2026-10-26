#!/usr/bin/env bash
# tools/hooks/port-precheck.sh — PreToolUse(Bash) port-clash pre-launch check.
#
# WHY THIS EXISTS (design: hq plans/port-clash-precheck.md, an hq-only record not mirrored here). A launch command (docker compose up, expo start,
# supabase start, ...) can silently collide with a port another app already holds. This hook
# looks the launch command up in tools/app-ports.tsv and, ONLY when something is genuinely
# listening on a resolved port right now, halts with permissionDecision "ask" naming the holder —
# the human then chooses to proceed or not. Silence in every other case.
#
# Provenance: ported from hq tools/hooks/port-precheck.sh. Ported into agent-hq 2026-10-26 (delivery workflow, port guard). plans/ and tools/app-ports.tsv citations name hq records.
#
# THE DECISION PATH IS `lsof` DIRECTLY — NEVER `port-check.sh`'s EXIT CODE (Fable ratification,
# ADR 0014 T5, binding change 1, 2026-09-05). Measured in hq against hq's own registry (not this
# repo's tools/ports.tsv): every row a launch would plausibly hit returned NON-ZERO from
# port-check.sh — exit 2 (GHOST: registry says live, lsof shows nothing) or exit 1 (the row records
# the LAUNCHING APP'S OWN claim, so restarting your own service always reads "taken"). A
# port-check.sh-driven decision would therefore fire on effectively every launch. `lsof -nP -iTCP:<port> -sTCP:LISTEN` is
# the one signal this hook trusts to decide; port-check.sh is called AFTER that decision is
# already made, only to name the holder for the human, and its exit code is discarded.
#
# NEVER `set -e`. ALWAYS `exit 0`. A PreToolUse hook exiting non-zero blocks the command
# UNCONDITIONALLY and overrides any JSON decision this script printed — so every failure path
# below, including ones this script's author did not think of, must still reach an `exit 0`.
# This hook runs on EVERY Bash call in EVERY session on this machine (including subagents); a
# fail-closed hook here bricks the machine. Deliberately inverted from tools/port-check.sh, which
# fails closed on purpose (it is the source of registry truth; this hook is only ever advisory).
#
# `command grep`, never bare `grep` (this shell wraps `grep` in a function that can silently
# return nothing — tools/port-check.sh's header documents the same hazard).
#
# ENV (test injection only — never point these at anything real from outside a test fixture)
#   PORT_PRECHECK_TABLE          default: <this script's dir>/../app-ports.tsv
#   PORT_PRECHECK_PORT_CHECK_SH  default: <this script's dir>/../port-check.sh

allow_silent() { exit 0; }

main() {
  command -v jq   >/dev/null 2>&1 || allow_silent
  command -v lsof >/dev/null 2>&1 || allow_silent   # binding change 1: lsof cannot execute -> silent allow

  local script_dir tools_dir table_file port_check_sh
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)" || allow_silent
  [ -n "${script_dir}" ] || allow_silent
  tools_dir="$(dirname "${script_dir}")"
  table_file="${PORT_PRECHECK_TABLE:-${tools_dir}/app-ports.tsv}"
  port_check_sh="${PORT_PRECHECK_PORT_CHECK_SH:-${tools_dir}/port-check.sh}"
  [ -r "${table_file}" ] || allow_silent

  local payload
  payload="$(cat)" || allow_silent
  [ -n "${payload}" ] || allow_silent

  local tool_name cmd cwd
  tool_name="$(printf '%s' "${payload}" | jq -r '.tool_name // empty' 2>/dev/null)" || allow_silent
  [ "${tool_name}" = "Bash" ] || allow_silent
  cmd="$(printf '%s' "${payload}" | jq -r '.tool_input.command // empty' 2>/dev/null)" || allow_silent
  [ -n "${cmd}" ] || allow_silent
  cwd="$(printf '%s' "${payload}" | jq -r '.cwd // empty' 2>/dev/null)" || allow_silent

  local home_dir="${HOME:-}"

  # dir_matches <match_dir> — binding change 3: cwd under match_dir, OR under
  # "<match_dir>-worktrees/", OR the command contains "cd <path>" resolving under either.
  dir_matches() {
    local m="$1" expanded lit
    [ "${m}" = "*" ] && return 0
    expanded="${m/#\~/${home_dir}}"
    [ -n "${cwd}" ] && case "${cwd}" in
      "${expanded}"|"${expanded}"/*) return 0 ;;
      "${expanded}"-worktrees/*) return 0 ;;
    esac
    for lit in "${m}" "${expanded}"; do
      case "${cmd}" in
        *"cd ${lit} "*|*"cd ${lit}"|*"cd ${lit}/"*) return 0 ;;
        *"cd ${lit}-worktrees/"*) return 0 ;;
      esac
    done
    return 1
  }

  # first_port <field> — a single port, or a range's FIRST port only (binding change 2).
  first_port() { printf '%s' "${1%%-*}"; }

  local -a candidates=()      # resolved ports to check
  local -a holder_hint=()     # per-candidate fallback holder name (table row's service field)

  # 1. Table match: tools/app-ports.tsv, TAB-separated, comment/blank lines skipped.
  while IFS=$'\t' read -r m_dir m_cmd m_ports m_service m_source; do
    [ -z "${m_dir}" ] && continue
    case "${cmd}" in *"${m_cmd}"*) ;; *) continue ;; esac
    dir_matches "${m_dir}" || continue
    local tok
    IFS=',' read -ra _toks <<<"${m_ports}"
    for tok in "${_toks[@]}"; do
      tok="$(first_port "${tok}")"
      [[ "${tok}" =~ ^[0-9]+$ ]] || continue
      candidates+=("${tok}")
      holder_hint+=("${m_service}")
    done
  done < <(command grep -v '^#' "${table_file}" 2>/dev/null | command grep -vE '^[[:space:]]*$')

  # 2. Literal ports on the command line. --port N / --port=N / PORT=N are generic. Bare -p N and
  # -p HOST:CONTAINER only parse inside a docker run/create/compose-run gate (binding change 4) —
  # otherwise `ssh -p 9000`, `psql -p 5433`, etc. would false-positive.
  local lit
  for lit in $(printf '%s' "${cmd}" | command grep -oE -- '--port[= ]([0-9]+)' 2>/dev/null | command grep -oE '[0-9]+'); do
    candidates+=("${lit}"); holder_hint+=("(--port on command line)")
  done
  for lit in $(printf '%s' "${cmd}" | command grep -oE '(^|[[:space:]])PORT=[0-9]+' 2>/dev/null | command grep -oE '[0-9]+'); do
    candidates+=("${lit}"); holder_hint+=("(PORT= on command line)")
  done
  # NO -P ANYWHERE (BSD grep here has no PCRE support — same hazard tools/port-check.sh's header
  # documents): extract the whole "-p<sep><n>[:<n>]" token with plain ERE, then strip with bash
  # parameter expansion instead of a lookahead.
  if printf '%s' "${cmd}" | command grep -qE '^[[:space:]]*(docker run|docker create|docker compose run)([[:space:]]|$)' 2>/dev/null; then
    while IFS= read -r lit; do
      [ -z "${lit}" ] && continue
      lit="${lit#-p}"; lit="${lit# }"; lit="${lit#=}"; lit="${lit%%:*}"
      [[ "${lit}" =~ ^[0-9]+$ ]] && { candidates+=("${lit}"); holder_hint+=("(-p on command line)"); }
    done < <(printf '%s' "${cmd}" | command grep -oE -- '-p[= ]?[0-9]+(:[0-9]+)?' 2>/dev/null)
  fi

  [ "${#candidates[@]}" -eq 0 ] && allow_silent

  # 3. Live-listener decision — lsof directly, per port, deduped. First live hit wins the name;
  # every live hit is reported.
  local i seen="," reasons="" any_live=0
  for i in "${!candidates[@]}"; do
    local p="${candidates[$i]}"
    case "${seen}" in *",${p},"*) continue ;; esac
    seen="${seen}${p},"
    lsof -nP -iTCP:"${p}" -sTCP:LISTEN >/dev/null 2>&1 || continue
    any_live=1

    # Name the holder via port-check.sh — exit code captured, NEVER read again (binding change 1).
    local holder="${holder_hint[$i]}" ec=0 out=""
    if [ -x "${port_check_sh}" ]; then
      out="$("${port_check_sh}" "${p}" 2>/dev/null)" || ec=$?
      # ec captured, never read again below — port-check.sh's exit code names nothing about the
      # decision (binding change 1). Grab the registry-hit line verbatim (service/project may
      # legitimately contain spaces, e.g. "agent-topology MCP server"); no lookahead, plain ERE.
      local named
      named="$(printf '%s' "${out}" | command grep -m1 -oE '\[(live|claimed|reserved|unmerged|released|UNVERIFIED)\].*' 2>/dev/null)"
      [ -n "${named}" ] && holder="${named}"
    fi
    reasons="${reasons}
  - port ${p}: held by ${holder}"
  done

  [ "${any_live}" -eq 1 ] || allow_silent

  local reason
  reason="$(printf 'port-clash-precheck: this launch command matches a port this machine already has bound.%s\nProceeding may collide with the running service above. Confirm before continuing.' "${reasons}")"
  jq -n --arg reason "${reason}" \
    '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "ask", permissionDecisionReason: $reason}}' \
    2>/dev/null || allow_silent
}

main
exit 0
