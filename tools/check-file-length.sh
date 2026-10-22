#!/usr/bin/env bash
# tools/check-file-length.sh — enforce the hq source-file-length default (~300 lines).
#
# Flags every non-exempt source file over LIMIT lines that isn't recorded in a
# .file-length-allowlist (at the target dir root) with a mandatory one-line reason.
# See decisions/0016-source-file-length-limit.md for the full rationale: 300 is a
# convention default with a justified escape hatch, NOT a hard cap. When a file is
# over the limit, the fix is to SPLIT it into multiple files — never to compress,
# delete, or reword content just to dodge this check.
#
# Usage: check-file-length.sh [target-dir]   (default: current directory)
set -euo pipefail

# --- Tunables -----------------------------------------------------------
LIMIT=300

# Code file extensions to scan. Edit this list to add/remove languages.
EXTENSIONS=(ts tsx js jsx mjs cjs py go rs java rb c h hpp cpp cc swift kt scala php sh bash zsh lua)

# Path segments excluded wholesale (matched as "*/name/*"). "skills" is the
# blanket skills exemption (ADR 0016).
EXCLUDE_DIR_NAMES=(.git node_modules vendor dist build out target .next coverage skills)

# Exact lockfile basenames excluded regardless of extension.
EXCLUDE_LOCKFILES=(package-lock.json yarn.lock pnpm-lock.yaml npm-shrinkwrap.json Cargo.lock Gemfile.lock composer.lock poetry.lock)

# Test-file path segments excluded wholesale (matched as "*/name/*"), same
# treatment as skills — blanket exemption, no allowlist entry needed
# (ADR 0016 amendment). Test files are low-risk for agent editing.
EXCLUDE_TEST_DIR_NAMES=(__tests__ test tests)

# Test-file basename patterns excluded regardless of directory (ADR 0016
# amendment). Matched as glob patterns against the basename.
EXCLUDE_TEST_NAME_PATTERNS=('*.test.*' '*.spec.*')
# -------------------------------------------------------------------------

TARGET_DIR="${1:-.}"
if [ ! -d "$TARGET_DIR" ]; then
  echo "check-file-length.sh: no such directory: $TARGET_DIR" >&2
  exit 1
fi
TARGET_DIR="$(cd "$TARGET_DIR" && pwd)"

ALLOWLIST_FILE="$TARGET_DIR/.file-length-allowlist"
ALLOWLIST_TMP="$(mktemp)"
VIOLATIONS_TMP="$(mktemp)"
trap 'rm -f "$ALLOWLIST_TMP" "$VIOLATIONS_TMP"' EXIT

# --- Parse the allowlist (fail closed on a path with no reason) ---------
# Format: <relative-path><ws>—<ws><reason>   (em dash separator)
# Also accepts blank lines and full-line "#" comments.
if [ -f "$ALLOWLIST_FILE" ]; then
  while IFS= read -r line || [ -n "$line" ]; do
    # trim leading/trailing whitespace
    trimmed="$(echo "$line" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
    [ -z "$trimmed" ] && continue
    case "$trimmed" in
      \#*) continue ;;
    esac
    if [[ "$trimmed" != *"—"* ]]; then
      echo "check-file-length.sh: malformed .file-length-allowlist entry (no reason given): $trimmed" >&2
      exit 1
    fi
    path_part="${trimmed%%—*}"
    reason_part="${trimmed#*—}"
    path_part="$(echo "$path_part" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
    reason_part="$(echo "$reason_part" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
    if [ -z "$path_part" ] || [ -z "$reason_part" ]; then
      echo "check-file-length.sh: malformed .file-length-allowlist entry (no reason given): $trimmed" >&2
      exit 1
    fi
    echo "$path_part" >> "$ALLOWLIST_TMP"
  done < "$ALLOWLIST_FILE"
fi

# --- Build the find(1) invocation ----------------------------------------
find_ext_args=()
first=1
for ext in "${EXTENSIONS[@]}"; do
  if [ "$first" -eq 1 ]; then
    find_ext_args+=(-name "*.$ext")
    first=0
  else
    find_ext_args+=(-o -name "*.$ext")
  fi
done

find_prune_args=()
for d in "${EXCLUDE_DIR_NAMES[@]}"; do
  find_prune_args+=(-not -path "*/$d/*")
done

find_lockfile_args=()
for lf in "${EXCLUDE_LOCKFILES[@]}"; do
  find_lockfile_args+=(-not -name "$lf")
done

for d in "${EXCLUDE_TEST_DIR_NAMES[@]}"; do
  find_prune_args+=(-not -path "*/$d/*")
done

find_test_name_args=()
for pat in "${EXCLUDE_TEST_NAME_PATTERNS[@]}"; do
  find_test_name_args+=(-not -name "$pat")
done

# --- Scan ------------------------------------------------------------------
violation_count=0
while IFS= read -r -d '' file; do
  relpath="${file#"$TARGET_DIR"/}"

  # allowlisted?
  if [ -s "$ALLOWLIST_TMP" ] && grep -Fxq "$relpath" "$ALLOWLIST_TMP"; then
    continue
  fi

  lines="$(wc -l < "$file" | tr -d '[:space:]')"
  if [ "$lines" -gt "$LIMIT" ]; then
    printf '%s\t%s\n' "$lines" "$relpath" >> "$VIOLATIONS_TMP"
    violation_count=$((violation_count + 1))
  fi
done < <(find "$TARGET_DIR" -type f \
            \( "${find_ext_args[@]}" \) \
            "${find_prune_args[@]}" \
            "${find_lockfile_args[@]}" \
            "${find_test_name_args[@]}" \
            -not -name '*.min.js' \
            -print0)

# --- Report ------------------------------------------------------------------
if [ "$violation_count" -gt 0 ]; then
  sort -t "$(printf '\t')" -k1,1nr "$VIOLATIONS_TMP" | while IFS="$(printf '\t')" read -r lines relpath; do
    printf '%s  %s\n' "$lines" "$relpath"
  done
fi
echo "check-file-length.sh: $violation_count file(s) over $LIMIT lines"

if [ "$violation_count" -gt 0 ]; then
  exit 1
fi
exit 0
