#!/usr/bin/env bash
# tools/check-invariants.sh — mechanical hq self-check (ADR 0007).
# WHAT is checked is owned by INVARIANTS.md; this script mirrors it.
# Usage: check-invariants.sh [--fast|--code-gate]   (--fast = subset {14,19,24,25} for pre-commit;
#   --code-gate = only the Rule 10 code-gate checks 27-29, used by tools/test_check-invariants.sh)
set -uo pipefail
export HQ="${HQ:-$HOME/projects/agent-hq}"
# ROOT_DIR = the parent of the MAIN checkout (where the root CLAUDE.md pointer file
# lives), resolved independent of which checkout ($HQ) is currently running.
# `dirname "$HQ"` is NOT safe for this: $HQ is deliberately worktree-relative (every
# other check wants the tree actually being worked on/committed — ADR 0017), so from
# a worktree `dirname "$HQ"` yields the worktree's parent (hq-worktrees/), which has
# no CLAUDE.md. `git rev-parse --path-format=absolute --git-common-dir` instead always
# resolves to the single shared .git dir that lives inside the MAIN checkout — that is
# a structural git invariant true from the main checkout, from any linked worktree, and
# regardless of the caller's cwd (queried via `-C "$HQ"`, not a bare relative call).
# Two dirnames off that: .git -> main checkout -> its parent (the root CLAUDE.md's dir).
HQ_GIT_COMMON="$(git -C "$HQ" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)"
ROOT_DIR="$(dirname "$(dirname "${HQ_GIT_COMMON:-$HQ/.git}")")"
FAST=0; [ "${1:-}" = "--fast" ] && FAST=1
pass=0; fail=0; warn=0
ok(){ pass=$((pass+1)); }                                   # quiet on pass
no(){ fail=$((fail+1)); printf 'FAIL  %-40s %s\n' "$1" "$2" >&2; }
wn(){ warn=$((warn+1)); printf 'WARN  %-40s %s\n' "$1" "$2" >&2; }
# run <id> <label> <bool-cmd...>  — PASS if bool-cmd exits 0
run(){ local id=$1 label=$2; shift 2; if "$@" >/dev/null 2>&1; then ok; \
       else no "$id $label" "see INVARIANTS.md / ADR 0007"; fi; }

# Code-gate checks 27-29 (Rule 10, architecture/hq-code-gate.md); logic lives in tools/code-gate/gate-invariants.sh.
gate_checks(){
  local out
  if out=$(bash "$HQ/tools/code-gate/gate-invariants.sh" a 2>&1); then ok; [ -z "$out" ] || wn "27 pre-gate worktree(s)" "$(printf '%s' "$out" | tr '\n' ' ')"; else no "27 pre-push hook installed everywhere" "$(printf '%s' "$out" | tr '\n' ' ')"; fi
  if out=$(bash "$HQ/tools/code-gate/gate-invariants.sh" b 2>&1); then ok; else no "28 code-gate test map well-formed" "$(printf '%s' "$out" | tr '\n' ' ')"; fi
  if out=$(bash "$HQ/tools/code-gate/gate-invariants.sh" c 2>&1); then ok; else no "29 main code commits are reviewed PR merges" "$(printf '%s' "$out" | tr '\n' ' ')"; fi
}
summary(){
  local total=$((pass+fail+warn))
  if [ "$fail" = 0 ]; then echo "check-invariants: $pass/$total OK ($warn warn)"; exit 0; \
  else echo "check-invariants: $fail FAIL, $pass OK, $warn warn" >&2; exit 1; fi
}
if [ "${1:-}" = "--code-gate" ]; then gate_checks; summary; fi

# --- Structural + memory-safety (INVARIANTS.md 1–15). Fast subset = 14,19,24,25 ---
# ck14 no nested git repos
run 14 "no nested .git" bash -c '[ -z "$(find "$HQ" -mindepth 2 -name .git)" ]'
# ck19 no runtime dirs physically present
run 19 "no data//.serena/ in hq" bash -c '[ -z "$(find "$HQ" -maxdepth 1 \( -name data -o -name .serena \) 2>/dev/null)" ]'
# ck24 source file length (ADR 0016). IN THE FAST SUBSET for the same commit-time-gap
# reason as ck25 below: pre-commit is hq's only automatic trigger, so an over-cap
# source file could be committed with the gate green while ck24 only ran in the full
# path. Cost measured 2026-08-18: check-file-length.sh isolated ~0.20s (92 files,
# one wc fork per file — NOT batched like check-doc-length.sh, but still cheap at
# hq's current size). --fast total 0.29s -> 0.53-0.59s. Re-measure before adding
# anything else here; if hq's source-file count grows a lot, batch this the way
# check-doc-length.sh's wc calls were batched before assuming the cost still holds.
run 24 "no file exceeds 300 lines" bash -c 'bash "$1/tools/check-file-length.sh" "$1"' _ "$HQ"
# ck25 doc length, non-skill (ADR 0021, gated by ADR 0029). IN THE FAST SUBSET on
# purpose: ADR 0029's approval gate applies "before the change is committed", and
# pre-commit is hq's only automatic trigger (there is no CI). While 25 ran only in
# the full path, an over-cap doc could be committed with the commit-time gate green
# — the ADR's own premise, unenforced. Cost measured 2026-08-17: --fast 0.05s ->
# 0.29s, after check-doc-length.sh batched its line counting (1.29s -> 0.29s).
# Re-measure before adding anything else here.
run 25 "no doc exceeds 500 lines" bash -c 'bash "$1/tools/check-doc-length.sh" "$1"' _ "$HQ"
if [ "$FAST" = 0 ]; then
  run 4 "STANDARDS >=11 sections" bash -c '[ "$(grep -c "^## [0-9]\+\." "$1")" -ge 11 ]' _ "$HQ/STANDARDS.md"
  run 6 "INVARIANTS.md exists" test -f "$HQ/INVARIANTS.md"
  # ck10 retired 2026-10-21 (agentmemory removed by owner): no store left to dump from; numbering kept stable.
  run 10 "retired 2026-10-21 (agentmemory removed by owner)" true
  # --- Environment (post-stack) 16–19 ---
  run 16 "retired 2026-10-21 (agentmemory removed by owner)" true
  if [ -f ~/.serena/serena_config.yml ]; then
    run 17 "serena excludes hq" bash -c '! grep -qE "^- .*/projects/agent-hq(/|$)" ~/.serena/serena_config.yml'
  else wn "17 serena excludes hq" "serena config absent"; fi
  # ck18 agentmemory service retired 2026-10-21 (agentmemory removed by owner); the headroom service warn below stays.
  launchctl list 2>/dev/null | grep -q com.headroom.default   || wn "18 headroom svc"   "not loaded"
  # ck19 already run above (also in fast set)
  # --- Container execution lane (ADR 0008) 20–23 ---
  run 20 "no anthropic token in hq" bash -c '! git -C "$1" grep -qE "sk-ant-(oat|ort|api)[0-9]{2}-"' _ "$HQ"
  run 21 "hqx-run.sh executable"     test -x "$HQ/tools/container-exec/hqx-run.sh"
  run 22 "hqx Dockerfile present"    test -f "$HQ/tools/container-exec/Dockerfile"
  run 23 "image never bakes token"   bash -c '! grep -qE "CLAUDE_CODE_OAUTH_TOKEN" "$1/tools/container-exec/Dockerfile"' _ "$HQ"
  # ck24 (source file length) already run above — it is in the fast set, like ck19.
  # ck25 (doc length) already run above — it is in the fast set, like ck19.
  gate_checks   # ck27-29 (Rule 10 code gate)
  # --- meta: count parity vs INVARIANTS.md (ADR 0003 one-owner guard) ---
  defined=$(grep -cE '^\*\*[0-9]+\.' "$HQ/INVARIANTS.md")   # count of "**N." check headers
  implemented=17
  [ "$defined" = "$implemented" ] && ok || no "meta count-parity" "INVARIANTS=$defined script=$implemented"
  # --- meta: documented-vs-wired guard (prevents "documented≠wired" recurring —
  # this exact bug happened twice: check 24 on 2026-07-12, check 25 on 2026-07-19).
  # Derivation: the SET of "**N." check numbers documented in INVARIANTS.md vs the
  # SET of numbers actually invoked in THIS running script's own source ($0, not
  # $HQ's copy, so it's correct even mid-edit in a worktree before merge). Checks
  # are wired two ways here: via the "run N ..." helper (most checks), or via a
  # direct "no \"N ...\"" / "wn \"N ...\"" call with the number embedded in the
  # label (checks 15, 18, which are inline comparisons/WARNs, not bool-cmds) — so
  # both call shapes must be matched or real checks would misreport as unwired.
  # Deliberately simple grep+comm over a static, obviously-correct pattern rather
  # than anything cleverer — a fragile derivation here would be worse than none.
  defined_nums=$(grep -oE '^\*\*[0-9]+\.' "$HQ/INVARIANTS.md" | grep -oE '[0-9]+' | sort -nu)
  wired_nums=$(grep -v '^[[:space:]]*#' "$0" | grep -oE '\b(run|no|wn)[[:space:]]"?[0-9]+' | grep -oE '[0-9]+' | sort -nu)
  unwired=$(comm -23 <(printf '%s\n' "$defined_nums") <(printf '%s\n' "$wired_nums"))
  if [ -z "$unwired" ]; then ok; \
  else no "meta documented-vs-wired" "unwired: $(printf '%s' "$unwired" | tr '\n' ' ' | sed 's/ *$//')"; fi
fi
summary
