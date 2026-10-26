#!/usr/bin/env bash
# tools/delivery/catalog.sh -- the only appender of RUN_HOME/catalog.tsv.
# Contract: architecture/delivery-workflow/INTERFACES.md (Script interfaces; part A.5, A.5.1, A.3 Break).
#   env RUN_HOME (required, absolute, last segment = run-id); optional env WORKTREE_BASE (absolute).
#   register <kind> <handle> <unit|-> <correlation_id> <source> <subtask|run> <owner_agent>
#   start|release|fail <kind> <handle>      keep <kind> <handle> <reason>
#   list --live [--subtask <st>]            (latest row of each pair is planned or live; INTERFACES 1.4.0 AM-4 row 20)
#   audit                                   (see catalog-audit.sh)
# Stdout: register/start/release/fail/keep the row_id; list the matching TSV rows; audit the verdict lines.
# Exit: 0 ok; 2 usage or rejected row; 3 lane-lease held; 4 lock timeout, or audit could not read live truth
#   (lsof missing or failed: fail closed, no verdict for that row).
# Test hooks: DL_LOCK_TIMEOUT (seconds, default 60), DL_LOCK_SLEEP (seconds, default 1).
# Runtime: /bin/bash 3.2, BSD userland, mkdir lock, no ps/pgrep.
set -u
export LC_ALL=C
T=$'\t'
KINDS=" worktree branch tag process pm2-app port bus tmpdir container image lane-lease db clone cron bgtask file workspace "

die() { echo "catalog.sh: $*" >&2; exit 2; }

# realp <abs-path>: physical path, component by component (plain readlink per link; works for paths that do not exist yet).
realp() {
  local rest=$1 res="" c t n=0
  while [ -n "$rest" ]; do
    rest=${rest#/}
    [ -z "$rest" ] && break
    c=${rest%%/*}
    if [ "$c" = "$rest" ]; then rest=""; else rest=${rest#*/}; fi
    case $c in ''|.) continue ;; ..) res=${res%/*}; continue ;; esac
    if [ -L "$res/$c" ]; then
      n=$((n + 1)); [ "$n" -gt 40 ] && return 1
      t=$(readlink "$res/$c") || return 1
      case $t in /*) res="" ;; esac
      rest="$t/$rest"
      continue
    fi
    res="$res/$c"
  done
  printf '%s\n' "${res:-/}"
}

SELF_DIR=$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd) || exit 2
# shellcheck source=catalog-audit.sh
. "$SELF_DIR/catalog-audit.sh" || exit 2

# ---- environment and argument checks -------------------------------------------------
[ $# -ge 1 ] || die "usage: catalog.sh register|start|release|fail|keep|list|audit ..."
for a in "$@"; do
  [[ $a == *[[:cntrl:]]* ]] && die "control character in an argument"
  [ -n "$a" ] || die "empty argument"
done
[ -n "${RUN_HOME:-}" ] || die "RUN_HOME is required"
case $RUN_HOME in /*) ;; *) die "RUN_HOME must be absolute" ;; esac
RUN_RAW=${RUN_HOME%/}
RUN_ID=${RUN_RAW##*/}
[[ $RUN_ID =~ ^[a-z0-9-]+$ ]] || die "RUN_HOME last segment must match [a-z0-9-]+"
[ -d "$RUN_RAW" ] || die "RUN_HOME is not a directory"
RH=$(realp "$RUN_RAW") || die "cannot resolve RUN_HOME"
CAT="$RH/catalog.tsv"
LOCK="$RH/catalog.lock"
WB=""
if [ -n "${WORKTREE_BASE:-}" ]; then
  case $WORKTREE_BASE in /*) ;; *) die "WORKTREE_BASE must be absolute" ;; esac
  [[ $WORKTREE_BASE == *[[:space:]]* ]] && die "WORKTREE_BASE must not contain whitespace"
  WB=$(realp "${WORKTREE_BASE%/}") || die "cannot resolve WORKTREE_BASE"
fi

# ---- validation ----------------------------------------------------------------------
under_roots() { # abs path -> 0 when its realpath is strictly under RUN_HOME or WORKTREE_BASE
  local p
  [[ $1 == */../* || $1 == */.. ]] && return 1
  p=$(realp "$1") || return 1
  case $p in "$RH"/*) return 0 ;; esac
  [ -n "$WB" ] && case $p in "$WB"/*) return 0 ;; esac
  return 1
}
abs_nodots() { case $1 in /*) ;; *) return 1 ;; esac; [[ $1 != */../* && $1 != */.. ]]; }

check_kind() { case $KINDS in *" $1 "*) ;; *) die "unknown kind: $1" ;; esac; }

check_handle() { # kind handle (full grammar, register only)
  local k=$1 h=$2 re
  case $k in
    tmpdir|file|clone|bus)
      abs_nodots "$h" || die "$k handle must be an absolute path without .."
      under_roots "$h" || die "$k handle is outside RUN_HOME and WORKTREE_BASE" ;;
    branch|tag)
      re='^(/[^#@]+)#([^#@[:space:]]+)@([^#@[:space:]]+)$'
      [[ $h =~ $re ]] || die "bad $k handle (<repo>#<ref>@<base>)"
      abs_nodots "${BASH_REMATCH[1]}" || die "bad $k repo path"
      if [ "$k" = tag ]; then [ "${BASH_REMATCH[3]}" = "-" ] || die "tag base must be -"
      else [ "${BASH_REMATCH[3]}" != "-" ] || die "branch base must not be -"; fi ;;
    worktree)
      re='^(/[^#]+)#(/[^#@]+)@([^#@[:space:]]+)$'
      [[ $h =~ $re ]] || die "bad worktree handle (<path>#<repo>@<base>)"
      abs_nodots "${BASH_REMATCH[2]}" || die "bad worktree repo path"
      abs_nodots "${BASH_REMATCH[1]}" || die "worktree path must be absolute without .."
      under_roots "${BASH_REMATCH[1]}" || die "worktree path is outside RUN_HOME and WORKTREE_BASE" ;;
    process) [[ $h =~ ^[1-9][0-9]*$ ]] || die "process handle must be a pid" ;;
    port)
      [[ $h =~ ^[1-9][0-9]{0,4}$ ]] && [ "$h" -le 65535 ] || die "port must be 1-65535" ;;
    pm2-app|container|image|workspace|db) # no leading "-": the handle reaches pm2/docker argv at cleanup
      [[ $h =~ ^[A-Za-z0-9._/:][A-Za-z0-9._/:-]*$ ]] || die "bad $k handle" ;;
    cron|bgtask) [[ $h != *[[:space:]]* && $h != -* ]] || die "bad $k handle" ;;
    lane-lease) [[ $h =~ ^(gate-runner/[0-9]+|lane/[A-Za-z0-9._-]+)$ ]] || die "bad lane-lease handle" ;;
  esac
}

# ---- lock (mkdir; A.3 Break) ---------------------------------------------------------
HELD=0
iso_now() { date -u +%Y-%m-%dT%H:%M:%SZ; }
compact() { printf '%s' "$1" | tr -d ':-'; }
mtime_of() {
  local m
  m=$(stat -f %m "$1" 2>/dev/null)
  case $m in ''|*[!0-9]*) m=$(stat -c %Y "$1" 2>/dev/null) ;; esac
  printf '%s' "$m"
}
write_owner() { # lock-dir
  printf '%s %s\n' "$$" "$(iso_now)" > "$1/owner.tmp.$$" && mv "$1/owner.tmp.$$" "$1/owner"
}
release_lock() { if [ "$HELD" = 1 ]; then rm -rf "$LOCK"; HELD=0; fi; }
trap release_lock EXIT
trap 'exit 130' INT TERM

owner_sig() { # lock-dir -> contents of owner (empty when missing)
  local s=""
  [ -f "$1/owner" ] && s=$(cat "$1/owner" 2>/dev/null)
  printf '%s' "$s"
}
owner_parse() { # sig -> 0 and sets OPID when "<pid> <ISO UTC>" parses
  local re='^([0-9]+) [0-9TZ:-]+$'
  [[ $1 =~ $re ]] || return 1
  OPID=${BASH_REMATCH[1]}
}
old_ownerless() { # dir -> 0 when older than 120 s
  local m now
  m=$(mtime_of "$1"); now=$(date +%s)
  case $m in ''|*[!0-9]*) return 1 ;; esac
  [ $((now - m)) -gt 120 ]
}
lock_is_stale() { # sets SIG (what was tested)
  SIG=$(owner_sig "$LOCK")
  if owner_parse "$SIG"; then ! kill -0 "$OPID" 2>/dev/null; else old_ownerless "$LOCK"; fi
}
break_lock() { # returns 0 when this process now holds the lock
  local b="$LOCK.broken-$$-$(compact "$(iso_now)")" sig2
  mv "$LOCK" "$b" 2>/dev/null || return 1
  sig2=$(owner_sig "$b")
  if [ "$sig2" != "$SIG" ] || { ! owner_parse "$sig2" && ! old_ownerless "$b"; }; then
    [ -e "$LOCK" ] || mv "$b" "$LOCK" 2>/dev/null || true
    [ -e "$b" ] && rm -rf "$b"
    return 1
  fi
  if mkdir "$LOCK" 2>/dev/null; then HELD=1; write_owner "$LOCK"; rm -rf "$b"; return 0; fi
  rm -rf "$b"; return 1
}
lock_acquire() {
  local limit=${DL_LOCK_TIMEOUT:-60} nap=${DL_LOCK_SLEEP:-1} t0=$SECONDS
  while :; do
    if mkdir "$LOCK" 2>/dev/null; then HELD=1; write_owner "$LOCK"; return 0; fi
    if lock_is_stale && break_lock; then return 0; fi
    [ $((SECONDS - t0)) -ge "$limit" ] && { echo "catalog.sh: lock timeout" >&2; exit 4; }
    sleep "$nap"
  done
}

# ---- rows ----------------------------------------------------------------------------
latest_row() { # kind handle -> latest row for the pair (may be empty)
  [ -f "$CAT" ] || return 0
  DL_K=$1 DL_H=$2 awk -F'\t' '$6 == ENVIRON["DL_K"] && $7 == ENVIRON["DL_H"] { r = $0 } END { if (r != "") print r }' "$CAT"
}
append_row() { # subtask corr kind handle owner unit state reason source
  local cnt ts rid row
  cnt=0; [ -f "$CAT" ] && cnt=$(wc -l < "$CAT"); cnt=${cnt// /}
  ts=$(iso_now); rid="$(compact "$ts")-$5-$((cnt + 1))"
  row="$ts$T$RUN_ID$T$1$T$rid$T$2$T$3$T$4$T$5$T$6$T$7$T$8$T$9"
  [ $((${#row} + 1)) -le 400 ] || die "row exceeds 400 bytes"
  printf '%s\n' "$row" >> "$CAT"
  printf '%s\n' "$rid"
}

cmd_register() {
  [ $# -eq 7 ] || die "usage: register <kind> <handle> <unit|-> <correlation_id> <source> <subtask|run> <owner_agent>"
  local kind=$1 handle=$2 unit=$3 corr=$4 src=$5 st=$6 owner=$7 state=planned last
  check_kind "$kind"; check_handle "$kind" "$handle"
  [[ $unit =~ ^([ui][0-9]+|-)$ ]] || die "bad unit"
  [[ $corr =~ ^([A-Z][A-Z0-9]*-[0-9]+|PR-[0-9]+|run)$ ]] || die "bad correlation_id"
  [[ $src =~ ^[A-Za-z0-9._/:-]+$ ]] || die "bad source"
  [[ $st =~ ^(st[0-9]+|pm|run)$ ]] || die "bad subtask"
  [[ $owner =~ ^[a-z0-9-]+$ ]] || die "bad owner_agent"
  lock_acquire
  if [ "$kind" = lane-lease ]; then
    last=$(latest_row "$kind" "$handle" | cut -f10)
    case $last in planned|live) echo "catalog.sh: lane-lease held: $handle" >&2; exit 3 ;; esac
    state=live
  fi
  append_row "$st" "$corr" "$kind" "$handle" "$owner" "$unit" "$state" "-" "$src"
}

cmd_move() { # state kind handle [reason]
  local state=$1 kind=$2 handle=$3 reason=${4:--} row
  local f1 f2 f3 f4 f5 f6 f7 f8 f9 f10 f11 f12
  check_kind "$kind"
  lock_acquire
  row=$(latest_row "$kind" "$handle")
  [ -n "$row" ] || die "no row for $kind:$handle"
  IFS=$'\t' read -r f1 f2 f3 f4 f5 f6 f7 f8 f9 f10 f11 f12 <<< "$row"
  append_row "$f3" "$f5" "$kind" "$handle" "$f8" "$f9" "$state" "$reason" "$f12"
}

cmd_list() {
  local st=""
  [ "${1:-}" = "--live" ] || die "usage: list --live [--subtask <st>]"
  shift
  if [ $# -gt 0 ]; then
    [ $# -eq 2 ] && [ "$1" = "--subtask" ] || die "usage: list --live [--subtask <st>]"
    [[ $2 =~ ^(st[0-9]+|pm|run)$ ]] || die "bad subtask"
    st=$2
  fi
  [ -f "$CAT" ] || return 0
  DL_ST=$st awk -F'\t' '
    { k = $6 "\034" $7; if (!(k in last)) order[++n] = k; last[k] = $0; state[k] = $10; sub_[k] = $3 }
    END { for (i = 1; i <= n; i++) { k = order[i]
      if ((state[k] == "planned" || state[k] == "live") && (ENVIRON["DL_ST"] == "" || sub_[k] == ENVIRON["DL_ST"])) print last[k] } }' "$CAT"
}

cmd=$1; shift
case $cmd in
  register) cmd_register "$@" ;;
  start)   [ $# -eq 2 ] || die "usage: start <kind> <handle>"; cmd_move live "$@" ;;
  release) [ $# -eq 2 ] || die "usage: release <kind> <handle>"; cmd_move released "$@" ;;
  fail)    [ $# -eq 2 ] || die "usage: fail <kind> <handle>"; cmd_move failed "$@" ;;
  keep)
    [ $# -eq 3 ] || die "usage: keep <kind> <handle> <reason>"
    [[ $3 =~ ^[[:space:]]*$ ]] && die "keep needs a reason"
    cmd_move kept "$@" ;;
  list)  cmd_list "$@" ;;
  audit) [ $# -eq 0 ] || die "usage: audit"; cmd_audit; exit $? ;;
  *) die "unknown subcommand: $cmd" ;;
esac
