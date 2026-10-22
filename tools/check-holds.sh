#!/usr/bin/env bash
# tools/check-holds.sh — enforce the STANDING-HOLDS register (ADR 0036).
#
# WHAT is checked is owned by INVARIANTS.md check 26; this script mirrors it.
#
# Default mode (invariant 26): every path listed under "## Bound planning surfaces" in
# STANDING-HOLDS.md must exist, be readable, and contain the string STANDING-HOLDS.
# That is the whole mechanical claim — deliberately narrow and obviously correct. It does
# NOT try to decide from a document's prose whether a hold was obeyed; only a reader can do
# that (see --scan, and the per-wave audit step in STANDING-HOLDS.md).
#
#   check-holds.sh [HQ_ROOT]                  full check (what pre-commit runs)
#   check-holds.sh --scan <file> [file...]    advisory: which held tickets does this file name?
#
# FAILS CLOSED. A parse that yields no holds or no surfaces is a FAIL, never a pass: the
# recurring hq lesson is that "a passing check is indistinguishable from a check that never
# ran" (learnings/enforcement-gates.md; INVARIANTS.md check 10's false-pass history).
set -uo pipefail

fail=0
err(){ printf 'check-holds: FAIL  %s\n' "$1" >&2; fail=1; }

# ---------------------------------------------------------------- --scan mode
if [ "${1:-}" = "--scan" ]; then
  shift
  [ "$#" -gt 0 ] || { echo "check-holds: --scan needs at least one file" >&2; exit 1; }
  HQ="${HQ:-$HOME/projects/agent-hq}"
  REG="$HQ/STANDING-HOLDS.md"
  [ -r "$REG" ] || { err "register not readable: $REG"; exit 1; }
  # Held ticket ids = the leading bolded id of each HELD table row.
  ids="$(grep -oE '^\| \*\*TOU-[0-9]+\*\*' "$REG" | grep -oE 'TOU-[0-9]+' | sort -u)"
  [ -n "$ids" ] || { err "no held ticket ids parsed from $REG (parse broken or table empty)"; exit 1; }
  pat="$(printf '%s' "$ids" | paste -sd'|' -)"
  for f in "$@"; do
    if [ ! -r "$f" ]; then err "--scan target not readable: $f"; continue; fi
    hits="$(grep -oE "\b($pat)\b" "$f" | sort -u | paste -sd' ' -)"
    if [ -n "$hits" ]; then
      printf 'HOLD  %s names held ticket(s): %s\n' "$f" "$hits"
      printf '      -> cite STANDING-HOLDS.md in this file, or drop the ticket from the plan.\n'
    else
      printf 'ok    %s names no held ticket\n' "$f"
    fi
  done
  exit "$fail"
fi

# ---------------------------------------------------------------- full check
HQ="${1:-${HQ:-$HOME/projects/agent-hq}}"
REG="$HQ/STANDING-HOLDS.md"

[ -r "$REG" ] || { err "STANDING-HOLDS.md missing or unreadable at $REG"; exit 1; }

# Positive control on the HELD table: at least one hold row must parse.
held="$(grep -cE '^\| \*\*(TOU-[0-9]+|branch )' "$REG")"
if [ "$held" -lt 1 ]; then
  err "no HELD rows parsed from STANDING-HOLDS.md — parse broken, or every hold was deleted"
fi

# Bound planning surfaces: backticked repo-relative paths in that section only.
surfaces="$(awk '
  /^## Bound planning surfaces/ { inblock=1; next }
  /^## / { inblock=0 }
  inblock && /^- `/ { gsub(/^- `/,""); gsub(/`.*$/,""); print }
' "$REG")"

if [ -z "$surfaces" ]; then
  err "no bound planning surfaces parsed from STANDING-HOLDS.md — parse broken, or the list is empty"
  echo "check-holds: 0 surfaces checked, $held hold row(s) — FAILED" >&2
  exit 1
fi

n=0
while IFS= read -r rel; do
  [ -n "$rel" ] || continue
  n=$((n+1))
  abs="$HQ/$rel"
  if [ ! -f "$abs" ] || [ ! -r "$abs" ]; then
    err "bound planning surface listed but missing/unreadable: $rel"
    continue
  fi
  grep -q 'STANDING-HOLDS' "$abs" \
    || err "bound planning surface does not cite STANDING-HOLDS: $rel"
done <<EOF
$surfaces
EOF

if [ "$fail" = 0 ]; then
  echo "check-holds: $n surface(s) OK, $held hold row(s)"
  exit 0
fi
echo "check-holds: FAILED ($n surface(s) checked, $held hold row(s))" >&2
exit 1
