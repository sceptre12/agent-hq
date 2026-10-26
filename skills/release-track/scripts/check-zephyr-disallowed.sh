#!/usr/bin/env bash
# skills/release-track/scripts/check-zephyr-disallowed.sh — static check that agent definitions disallow a tool.
# Usage: check-zephyr-disallowed.sh <agents-dir> <tool-name> [--except <file-stem>]...
# Exit:  0 every *.md directly in <agents-dir> (except the named stems) lists <tool-name> in its frontmatter
#        disallowedTools (inline "a, b", "[a, b]" or a block list); 1 a definition lacks it, or no definition
#        found (fail closed); 2 usage error. The tool name is a parameter (unmeasured, verify at move).
# Run by item 33 as its gate on agents/ minus the release-track host; this script writes nothing.
set -u
DIR="${1:-}"; TOOL="${2:-}"
[ -n "${DIR}" ] && [ -n "${TOOL}" ] && [ -d "${DIR}" ] || { echo "usage: check-zephyr-disallowed.sh <agents-dir> <tool-name> [--except <stem>]..." >&2; exit 2; }
shift 2
EXCEPT=" "
while [ "$#" -gt 0 ]; do
  [ "${1}" = "--except" ] && [ -n "${2:-}" ] || { echo "usage: bad argument ${1}" >&2; exit 2; }
  EXCEPT="${EXCEPT}${2} "; shift 2
done

lists_tool() { # lists_tool <file> — 0 when frontmatter disallowedTools names the tool exactly
  awk -v tool="${TOOL}" '
    function tok(s,   n, a, i, v) { gsub(/[\[\]"\047]/, "", s); n = split(s, a, ","); 
      for (i = 1; i <= n; i++) { v = a[i]; gsub(/^[[:space:]]+|[[:space:]]+$/, "", v); if (v == tool) hit = 1 } }
    NR == 1 { if ($(0) != "---") exit; fm = 1; next }
    fm && $(0) == "---" { exit }
    fm && /^disallowedTools:/ { r = $(0); sub(/^disallowedTools:[[:space:]]*/, "", r); tok(r); lst = 1; next }
    fm && lst && /^[[:space:]]*-[[:space:]]+/ { r = $(0); sub(/^[[:space:]]*-[[:space:]]+/, "", r); tok(r); next }
    fm && lst && /^[[:space:]]*(#.*)?$/ { next }
    fm { lst = 0 }
    END { exit (hit ? 0 : 1) }
  ' "${1}"
}

n=0; bad=0
for f in "${DIR}"/*.md; do
  [ -f "${f}" ] || continue
  stem="$(basename "${f}" .md)"
  case "${EXCEPT}" in *" ${stem} "*) continue ;; esac
  n=$((n + 1))
  if ! lists_tool "${f}"; then echo "MISSING ${TOOL} in disallowedTools: ${f}" >&2; bad=$((bad + 1)); fi
done
[ "${n}" -gt 0 ] || { echo "no agent definitions checked in ${DIR}" >&2; exit 1; }
[ "${bad}" -eq 0 ] || { echo "${bad} of ${n} definitions do not disallow ${TOOL}" >&2; exit 1; }
echo "OK: ${n} definitions disallow ${TOOL}"
exit 0
