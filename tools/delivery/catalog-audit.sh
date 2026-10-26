#!/usr/bin/env bash
# tools/delivery/catalog-audit.sh -- sourced by catalog.sh (uses its RH, CAT, WB, RUN_ID, T, realp).
# Classification (A.5, A.5.1 verify column): open = latest row planned|live; alive MATCH, gone GHOST.
# container|image|workspace|db|cron|bgtask are not checkable from a shell and print no line.
# port: live truth fails closed like tools/port-check.sh (tools/lib/port-check-lib.sh lsof_run): an lsof that
#   is missing, or exits other than 0-with-output / 1-without, gives no verdict for the row and audit exits 4.
# SQUATTER = git worktree under WORKTREE_BASE named <run-id>-* with no open row (repos from the catalog's worktree rows).

audit_latest() { # the latest row of every kind+handle pair, in first-seen order
  [ -f "$CAT" ] || return 0
  awk -F'\t' '{ k = $6 "\034" $7; if (!(k in last)) order[++n] = k; last[k] = $0 }
    END { for (i = 1; i <= n; i++) print last[order[i]] }' "$CAT"
}

audit_wt_has() { # repo path -> 0 when git lists the worktree
  local p
  p=$(realp "$2") || return 1
  git -C "$1" worktree list --porcelain 2>/dev/null < /dev/null | command grep -Fxq "worktree $p"
}

audit_port() { # port -> 0 listening, 1 not listening, 4 lsof missing or failed
  local out lrc=0
  command -v lsof > /dev/null 2>&1 || return 4
  out=$(lsof -nP -iTCP:"$1" -sTCP:LISTEN 2>/dev/null < /dev/null) || lrc=$?
  [ "$lrc" -eq 0 ] && [ -n "$out" ] && return 0
  [ "$lrc" -eq 1 ] && [ -z "$out" ] && return 1
  return 4
}

audit_check() { # kind handle subtask -> 0 alive, 1 gone, 2 unverifiable (no output), 4 live truth unreadable
  local k=$1 h=$2 st=$3 path rest repo ref pid ep
  case $k in
    process) kill -0 "$h" 2>/dev/null ;;
    port) audit_port "$h" ;;
    tmpdir|file|clone) [ -e "$h" ] ;;
    lane-lease) return 0 ;;
    worktree)
      path=${h%%#*}; rest=${h#*#}; repo=${rest%@*}
      audit_wt_has "$repo" "$path" ;;
    branch|tag)
      repo=${h%%#*}; rest=${h#*#}; ref=${rest%@*}
      [ "$k" = tag ] && ref="refs/tags/$ref" || ref="refs/heads/$ref"
      git -C "$repo" show-ref --verify --quiet "$ref" 2>/dev/null < /dev/null ;;
    bus)
      ep="$RH/$st/bus.endpoint"
      [ -f "$ep" ] || return 1
      pid=$(sed -n 's/^pid=//p' "$ep" | head -1)
      [[ $pid =~ ^[0-9]+$ ]] && kill -0 "$pid" 2>/dev/null ;;
    pm2-app)
      command -v pm2 > /dev/null 2>&1 && command -v jq > /dev/null 2>&1 || return 2
      pm2 jlist 2>/dev/null < /dev/null | jq -e --arg n "$h" 'map(.name) | index($n) != null' > /dev/null 2>&1 ;;
    *) return 2 ;;
  esac
}

cmd_audit() {
  local rows rc arc=0 open="" repos=""
  local f1 f2 f3 f4 f5 f6 f7 f8 f9 f10 f11 f12 p r wt
  [ -f "$CAT" ] || return 0
  rows=$(audit_latest)
  [ -n "$rows" ] || return 0
  while IFS=$'\t' read -r f1 f2 f3 f4 f5 f6 f7 f8 f9 f10 f11 f12; do
    [ -n "$f6" ] || continue
    if [ "$f6" = worktree ]; then
      r=${f7#*#}; r=${r%@*}
      case " $repos " in *" $r "*) ;; *) repos="$repos $r" ;; esac
    fi
    case $f10 in planned|live) ;; *) continue ;; esac
    [ "$f6" = worktree ] && { p=$(realp "${f7%%#*}") && open="$open$p"$'\n'; }
    audit_check "$f6" "$f7" "$f3"; rc=$?
    case $rc in
      0) printf 'MATCH\t%s\n' "$f4" ;;
      1) printf 'GHOST\t%s\n' "$f4" ;;
      4) echo "catalog.sh: audit: lsof missing or failed for $f6 $f7 (row $f4); failing closed, no verdict" >&2; arc=4 ;;
    esac
  done <<< "$rows"
  [ -n "$WB" ] || return "$arc"
  for r in $repos; do
    git -C "$r" worktree list --porcelain 2>/dev/null < /dev/null | sed -n 's/^worktree //p' | while IFS= read -r wt; do
      case $wt in "$WB/$RUN_ID"-*) ;; *) continue ;; esac
      printf '%s' "$open" | command grep -Fxq "$wt" || printf 'SQUATTER\t-\tworktree:%s\n' "$wt"
    done
  done | awk '!seen[$0]++'
  return "$arc"
}
