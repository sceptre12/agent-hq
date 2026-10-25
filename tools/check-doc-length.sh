#!/usr/bin/env bash
# tools/check-doc-length.sh — enforce the hq non-skill doc-length default (~500 lines).
#
# Flags every non-exempt markdown doc over LIMIT lines that isn't recorded in a
# .doc-length-allowlist (at the target dir root) with a mandatory one-line reason.
# See decisions/0021-doc-length-non-skill.md for the full rationale: 500 is a
# convention default (the existing STANDARDS §4 number, now enforced) with a
# justified escape hatch, NOT a hard cap. When a doc is over the limit, the fix is
# to SPLIT it — plans split by task into the §3 directory form, narrative docs
# split into numbered parts per §4 — never to compress, delete, or reword content
# just to dodge this check.
#
# ADR 0029 (amends 0021): crossing the cap requires the OWNER'S EXPLICIT APPROVAL for
# every file, regardless of whether it is newly-authored. Precedent, existing allowlist
# entries, and "campaign convention" are explicitly NOT justifications. Allowlisted
# files that are over the cap are therefore REPORTED here by name and line count —
# forward-only debt, visible on every run — but they do NOT fail the check (visibility,
# not blocking; owner's 2026-08-17 selection). Only non-allowlisted violations exit 1.
#
# This check is in the pre-commit fast subset (ADR 0007 Gate 2), so it must stay
# cheap: line counting is BATCHED through one xargs/wc pass, not one wc fork per
# file. Measured on hq (599 docs): 1.05s per-file vs 0.04s batched. Keep it batched.
#
# SECOND MEASUREMENT DIMENSION (byte count) — informational only, NOT a gate.
# `wc -l` can be satisfied by making lines longer instead of by reducing content:
# the line cap is a poor proxy for the thing ADR 0029 actually cares about, in the
# owner's own words — "Context conservation is more important than having all the
# info in one file." Bytes are a closer proxy for the context an agent burns
# reading a doc than a line count is. This script therefore also reports a byte
# count per file and flags anything over BYTE_LIMIT below, purely for visibility.
# It is explicitly NOT wired into the pass/fail decision, does NOT gate commits,
# and does NOT change ADR 0021's or ADR 0029's stated ~500-line threshold or
# approval-gate semantics — those remain line-count-only per the ADRs as ratified.
# Making this dimension blocking would be a policy change requiring the owner's
# approval the same way crossing the line cap does; this script does not have it.
# Cost: `wc -lc` reports both numbers from the same batched pass as `wc -l` did —
# no extra fork, no extra file read.
#
# Usage: check-doc-length.sh [target-dir]   (default: current directory)
set -euo pipefail

# --- Tunables -----------------------------------------------------------
LIMIT=500

# BYTE_LIMIT is an INFORMATIONAL default for the second measurement dimension
# above — it is not an ADR-ratified threshold and carries no owner approval; it
# exists only so the report below has a cutoff to flag against. Derivation
# (measured 2026-08-18, live on hq): the 566 currently non-allowlisted docs
# ≤500 lines average 70.65 bytes/line (median 69.25, p95 122.5). 500 lines *
# ~80 bytes/line, rounded, gives 40000 — comfortably above normal prose density
# so it does not drown the report in ordinary docs, while still catching dense
# long-line content a line-only cap misses. Re-derive if hq's doc mix changes
# a lot; the owner may pick a different number entirely (see the ADR/task that
# added this dimension for the full derivation and a proposed value).
BYTE_LIMIT=40000

# Markdown-family extensions to scan, matched CASE-INSENSITIVELY (so UPPER.MD and
# Mixed.Md are in scope — they were silently missed while this was a case-exact
# '*.md'). Scope is deliberately the markdown family and nothing else: hq's other
# bulk extensions (.txt/.log/.exit/.timeline under plans/*/results/) are generated
# agent run output, and flagging them against a *doc* cap would be a false positive.
# Extensionless files are also deliberately OUT of scope — see the note below.
DOC_EXTENSIONS=(md markdown mdx)

# Path segments excluded wholesale (matched as "*/name/*"). "skills" is the
# blanket skills exemption (ADR 0016's clause 2, extended to docs by ADR 0021):
# SKILL.md + every skill references/* file. "x-context-docs" is the
# third-party/generated-docs-we-don't-author exclusion (ADR 0021 scope clause;
# references/x-context-docs/CATALOG.md is a generated index over a third-party
# mirror, already grep-only per STANDARDS §11).
EXCLUDE_DIR_NAMES=(.git node_modules vendor dist build out target .next coverage skills x-context-docs)

# NOT scanned, deliberately: extensionless files. A name carries the only cheap
# signal of "is this a doc we authored", and hq's extensionless files are
# tools/git-hooks/pre-commit, tools/git-hooks/post-commit and a Dockerfile — source,
# not docs, and owned by ADR 0016's 300-line source cap via check-file-length.sh.
# Matching them here would flag LICENSE/Makefile/Dockerfile-class files (and any
# binary blob) against a prose cap. The residual evasion — authoring a doc under an
# extensionless name — is left open knowingly: every hq doc convention (STANDARDS §3
# plans, §4 narrative parts, decisions/, learnings/, projects/) names files `.md`, so
# such a file would be conspicuously off-convention rather than quietly compliant.
# -------------------------------------------------------------------------

TARGET_DIR="${1:-.}"
if [ ! -d "$TARGET_DIR" ]; then
  echo "check-doc-length.sh: no such directory: $TARGET_DIR" >&2
  exit 1
fi
TARGET_DIR="$(cd "$TARGET_DIR" && pwd)"

ALLOWLIST_FILE="$TARGET_DIR/.doc-length-allowlist"
ALLOWLIST_TMP="$(mktemp "${TMPDIR:-/tmp}/check-doc-length.XXXXXX")"
VIOLATIONS_TMP="$(mktemp "${TMPDIR:-/tmp}/check-doc-length.XXXXXX")"
ALLOWED_OVER_TMP="$(mktemp "${TMPDIR:-/tmp}/check-doc-length.XXXXXX")"
FILELIST_TMP="$(mktemp "${TMPDIR:-/tmp}/check-doc-length.XXXXXX")"
WC_TMP="$(mktemp "${TMPDIR:-/tmp}/check-doc-length.XXXXXX")"
BYTES_OVER_TMP="$(mktemp "${TMPDIR:-/tmp}/check-doc-length.XXXXXX")"
trap 'rm -f "$ALLOWLIST_TMP" "$VIOLATIONS_TMP" "$ALLOWED_OVER_TMP" "$FILELIST_TMP" "$WC_TMP" "$BYTES_OVER_TMP"' EXIT

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
      echo "check-doc-length.sh: malformed .doc-length-allowlist entry (no reason given): $trimmed" >&2
      exit 1
    fi
    path_part="${trimmed%%—*}"
    reason_part="${trimmed#*—}"
    path_part="$(echo "$path_part" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
    reason_part="$(echo "$reason_part" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
    if [ -z "$path_part" ] || [ -z "$reason_part" ]; then
      echo "check-doc-length.sh: malformed .doc-length-allowlist entry (no reason given): $trimmed" >&2
      exit 1
    fi
    echo "$path_part" >> "$ALLOWLIST_TMP"
  done < "$ALLOWLIST_FILE"
fi

# --- Build the find(1) invocation ----------------------------------------
find_ext_args=()
first=1
for ext in "${DOC_EXTENSIONS[@]}"; do
  if [ "$first" -eq 1 ]; then
    find_ext_args+=(-iname "*.$ext")
    first=0
  else
    find_ext_args+=(-o -iname "*.$ext")
  fi
done

find_prune_args=()
for d in "${EXCLUDE_DIR_NAMES[@]}"; do
  find_prune_args+=(-not -path "*/$d/*")
done

# --- Scan ------------------------------------------------------------------
# Every matching file is MEASURED, allowlisted or not (ADR 0029 Clause 5): allowlisted
# files used to be skipped before measurement, which is why the summary could print
# "0 file(s) over 500 lines" while 14 allowlisted files were over — one at 3,571.
# Allowlisting changes which bucket a violation lands in, never whether it is seen.
# The byte dimension below follows the same rule for the same reason: it is measured
# for every file first, and only branches (flag / don't flag) after — there is no
# byte allowlist, so "measured" and "reported" are the same set for that dimension.
violation_count=0
allowlisted_over_count=0
bytes_over_count=0

find "$TARGET_DIR" -type f \( "${find_ext_args[@]}" \) \
     "${find_prune_args[@]}" \
     -print0 > "$FILELIST_TMP"
file_count="$(tr -dc '\0' < "$FILELIST_TMP" | wc -c | tr -d '[:space:]')"

if [ "$file_count" -gt 0 ]; then
  # ONE wc invocation per xargs batch instead of one per file. `wc -lc` reports
  # lines AND bytes from the same pass at no extra fork cost (the second measurement
  # dimension above rides along for free). wc emits a "<n> <n> total" line per
  # batch, which is NOT a file: real paths are absolute (find was given an absolute
  # TARGET_DIR), so "starts with $TARGET_DIR/" separates files from totals without
  # misreading a genuine file called total.md. Anything else is unparseable and
  # fails closed rather than being silently skipped.
  if ! xargs -0 wc -lc < "$FILELIST_TMP" > "$WC_TMP"; then
    echo "check-doc-length.sh: line/byte counting failed (unreadable file?) — refusing to report a partial scan" >&2
    exit 1
  fi

  measured=0
  while IFS= read -r wcline; do
    trimmed="${wcline#"${wcline%%[![:space:]]*}"}"     # strip leading whitespace
    lines="${trimmed%%[[:space:]]*}"                   # 1st leading integer (lines)
    rest="${trimmed#"$lines"}"
    rest="${rest#"${rest%%[![:space:]]*}"}"            # strip whitespace before 2nd integer
    bytes="${rest%%[[:space:]]*}"                      # 2nd leading integer (bytes)
    path="${rest#"$bytes"}"
    path="${path#"${path%%[![:space:]]*}"}"            # remainder = the path
    case "$path" in
      "$TARGET_DIR"/*) ;;                              # a scanned file
      total) continue ;;                               # wc per-batch total, skip
      *) echo "check-doc-length.sh: unparseable wc output line: $wcline" >&2; exit 1 ;;
    esac
    case "$lines" in
      ''|*[!0-9]*) echo "check-doc-length.sh: unparseable line count: $wcline" >&2; exit 1 ;;
    esac
    case "$bytes" in
      ''|*[!0-9]*) echo "check-doc-length.sh: unparseable byte count: $wcline" >&2; exit 1 ;;
    esac
    measured=$((measured + 1))
    relpath="${path#"$TARGET_DIR"/}"

    # --- second dimension: byte count (informational, non-blocking) ---
    # Runs unconditionally, ahead of and independent from the line-based branch
    # below, so a file under the 500-line cap can still surface here if its bytes
    # give it away (the line-packing loophole this dimension exists to close).
    if [ "$bytes" -gt "$BYTE_LIMIT" ]; then
      printf '%s\t%s\t%s\n' "$bytes" "$lines" "$relpath" >> "$BYTES_OVER_TMP"
      bytes_over_count=$((bytes_over_count + 1))
    fi

    # --- primary dimension: line count (blocking, ADR 0021/0029) ---
    if [ "$lines" -gt "$LIMIT" ]; then
      # allowlisted? -> visible, non-blocking debt. otherwise -> blocking violation.
      if [ -s "$ALLOWLIST_TMP" ] && grep -Fxq "$relpath" "$ALLOWLIST_TMP"; then
        printf '%s\t%s\n' "$lines" "$relpath" >> "$ALLOWED_OVER_TMP"
        allowlisted_over_count=$((allowlisted_over_count + 1))
      else
        printf '%s\t%s\n' "$lines" "$relpath" >> "$VIOLATIONS_TMP"
        violation_count=$((violation_count + 1))
      fi
    fi
  done < "$WC_TMP"

  # Parity guard: every file find produced must have been measured. Catches any
  # wc-output shape this parser would otherwise drop on the floor (a dropped file
  # is an invisible over-cap doc — the exact failure ADR 0029 exists to end).
  if [ "$measured" != "$file_count" ]; then
    echo "check-doc-length.sh: measured $measured of $file_count file(s) — refusing to report a partial scan" >&2
    exit 1
  fi
fi

# --- Report ------------------------------------------------------------------
if [ "$allowlisted_over_count" -gt 0 ]; then
  echo "allowlisted but over $LIMIT lines — forward-only debt, split on next substantive touch (ADR 0029 Clause 5; NON-BLOCKING):"
  sort -t "$(printf '\t')" -k1,1nr "$ALLOWED_OVER_TMP" | while IFS="$(printf '\t')" read -r lines relpath; do
    printf '  %s  %s\n' "$lines" "$relpath"
  done
fi

if [ "$violation_count" -gt 0 ]; then
  echo "over $LIMIT lines and NOT allowlisted (BLOCKING) — split it; crossing the cap needs the owner's explicit approval (ADR 0029):"
  sort -t "$(printf '\t')" -k1,1nr "$VIOLATIONS_TMP" | while IFS="$(printf '\t')" read -r lines relpath; do
    printf '  %s  %s\n' "$lines" "$relpath"
  done
fi

if [ "$bytes_over_count" -gt 0 ]; then
  echo "over $BYTE_LIMIT bytes — SECOND MEASUREMENT DIMENSION (informational, NON-BLOCKING; not an ADR 0021/0029 threshold, does not affect exit status; a file can appear here whether or not it is also over the $LIMIT-line cap above — that is the line-packing gap this dimension exists to make visible):"
  sort -t "$(printf '\t')" -k1,1nr "$BYTES_OVER_TMP" | while IFS="$(printf '\t')" read -r bytes lines relpath; do
    printf '  %s bytes (%s lines)  %s\n' "$bytes" "$lines" "$relpath"
  done
fi

echo "check-doc-length.sh: $violation_count blocking file(s) over $LIMIT lines; $allowlisted_over_count allowlisted file(s) over $LIMIT lines (visible debt, not blocking); $bytes_over_count file(s) over $BYTE_LIMIT bytes (second dimension, informational only, not blocking)"

if [ "$violation_count" -gt 0 ]; then
  exit 1
fi
exit 0
