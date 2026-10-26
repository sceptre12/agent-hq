#!/usr/bin/env bash
# desk-req.sh <run-id> <subtask|run> <verb> <fields-json-file>
# Validates a desk request against the closed B4 schema, allocates the per-run
# counter under mkdir RUN_HOME/desk/.lock, writes RUN_HOME/desk/<id>.req (0600,
# temp file then mv) and prints the one DESK line (INTERFACES B2, B3).
# Exit: 0 ok; 2 usage or schema (stderr `desk-req: schema: <rule>`); 4 lock timeout.
# Env: DELIVERY_ROOT (required). Test hooks: DL_LOCK_TIMEOUT (60), DL_LOCK_INTERVAL (1).
set -u
umask 077
HERE=$(cd "$(dirname "$0")" && pwd -P)
# shellcheck source=desk-req-schema.sh
. "$HERE/desk-req-schema.sh"

die() { echo "desk-req: $*" >&2; exit 2; }
bad() { echo "desk-req: schema: $*" >&2; exit 2; }

[ $# -eq 4 ] || die "usage: desk-req.sh <run-id> <subtask|run> <verb> <fields-json-file>"
RUN_ID=$1; SUB=$2; VERB=$3; FFILE=$4

if [ -z "${DELIVERY_ROOT:-}" ]; then
  echo "INPUT-ERROR DELIVERY_ROOT unset" >&2; exit 2
fi
[[ "$DELIVERY_ROOT" =~ ^/[^[:space:]]+$ ]] || { echo "INPUT-ERROR DELIVERY_ROOT format" >&2; exit 2; }
[ -x /usr/bin/jq ] || die "jq missing"

[[ "$RUN_ID" =~ ^[a-z0-9-]+$ ]] || bad "run-id"
[[ "$SUB" =~ ^(st[0-9]+|pm|run)$ ]] || bad "subtask"
case " $DR_VERBS " in *" $VERB "*) ;; *) bad "verb" ;; esac
if [[ "$VERB" =~ $DR_CONDUCTOR_RE ]] && [ "$SUB" != run ]; then bad "conductor-only verb needs subtask run"; fi

RUN_HOME="$DELIVERY_ROOT/$RUN_ID"
[ -d "$RUN_HOME" ] || bad "RUN_HOME missing"
[ -f "$FFILE" ] && [ -r "$FFILE" ] || bad "fields file unreadable"
/usr/bin/jq -e . "$FFILE" >/dev/null 2>&1 || bad "fields file not json"

ERR=$(dr_validate "$VERB" "$FFILE")
[ -z "$ERR" ] || bad "$ERR"
ERR=$(dr_paths "$VERB" "$SUB" "$FFILE" "$RUN_HOME")
[ -z "$ERR" ] || bad "$ERR"

DESK="$RUN_HOME/desk"
LOCK="$DESK/.lock"
TIMEOUT=${DL_LOCK_TIMEOUT:-60}
INTERVAL=${DL_LOCK_INTERVAL:-1}
HELD=0
TMPF=""

utc() { date -u +%Y%m%dT%H%M%SZ; }

release() {
  [ -z "$TMPF" ] || rm -f "$TMPF"
  if [ "$HELD" = 1 ]; then
    rm -f "$LOCK/owner"
    rmdir "$LOCK" 2>/dev/null
    HELD=0
  fi
}
trap release EXIT
trap 'exit 130' INT TERM

# Take ownership of a freshly made lock: owner file by temp file then mv.
set_owner() {
  printf '%s %s\n' "$$" "$(utc)" > "$LOCK/.owner.$$" 2>/dev/null || return 1
  mv "$LOCK/.owner.$$" "$LOCK/owner" 2>/dev/null || return 1
}

# Stale test (A.3): owner pid fails kill -0, or owner missing/unparsable and
# the directory older than 120 s. Prints the owner text tested ("" if none).
stale_owner=""
is_stale() {
  local o="" pid age m
  stale_owner=""
  [ -d "$LOCK" ] || return 1
  [ ! -f "$LOCK/owner" ] || o=$(cat "$LOCK/owner" 2>/dev/null)
  if [[ "$o" =~ ^[0-9]+\ [0-9TZ:-]+$ ]]; then
    pid=${o%% *}
    kill -0 "$pid" 2>/dev/null && return 1
    stale_owner=$o
    return 0
  fi
  m=$(stat -f %m "$LOCK" 2>/dev/null) || return 1
  age=$(( $(date +%s) - m ))
  [ "$age" -gt 120 ] || return 1
  stale_owner=$o
  return 0
}

# Break (A.3): atomic rename aside, confirm what was moved is what was tested,
# else put it back and start over; on success take the lock and drop the old one.
break_lock() {
  local b="$LOCK.broken-$$-$(utc)" o=""
  mv "$LOCK" "$b" 2>/dev/null || return 1
  [ ! -f "$b/owner" ] || o=$(cat "$b/owner" 2>/dev/null)
  if [ "$o" != "$stale_owner" ]; then
    [ -e "$LOCK" ] || mv "$b" "$LOCK" 2>/dev/null
    return 1
  fi
  if mkdir "$LOCK" 2>/dev/null; then
    HELD=1
    set_owner || { HELD=0; rmdir "$LOCK" 2>/dev/null; rm -rf "$b"; return 1; }
    rm -rf "$b"
    return 0
  fi
  rm -rf "$b"
  return 1
}

acquire() {
  local deadline=$(( $(date +%s) + TIMEOUT ))
  while :; do
    if mkdir "$LOCK" 2>/dev/null; then
      HELD=1
      if set_owner; then return 0; fi
      HELD=0
    elif is_stale && break_lock; then
      return 0
    fi
    [ "$(date +%s)" -lt "$deadline" ] || return 4
    sleep "$INTERVAL"
  done
}

( umask 077; mkdir -p "$DESK" ) 2>/dev/null || die "cannot create $DESK"
acquire || { echo "desk-req: lock timeout on $LOCK" >&2; exit 4; }

# n = 1 + highest n among RUN_HOME/desk/<run-id>-<subtask>-<utc>-<n>* names.
N=0
for f in "$DESK/$RUN_ID"-*; do
  [ -e "$f" ] || continue
  name=${f##*/}
  rest=${name#"$RUN_ID"-}
  if [[ "$rest" =~ ^(st[0-9]+|pm|run)-[0-9]{8}T[0-9]{6}Z-([0-9]+)([^0-9].*)?$ ]]; then
    c=$((10#${BASH_REMATCH[2]}))
    [ "$c" -le "$N" ] || N=$c
  fi
done
N=$((N + 1))
ID="$RUN_ID-$SUB-$(utc)-$N"
REQ="$DESK/$ID.req"
[ ! -e "$REQ" ] || bad "id exists: $ID"

TMPF="$DESK/.tmp-$$"
/usr/bin/jq -S -c -n --arg id "$ID" --arg verb "$VERB" --arg sub "$SUB" --slurpfile f "$FFILE" \
  '{id: $id, verb: $verb, subtask: $sub, fields: $f[0]}' > "$TMPF" || bad "write failed"
chmod 600 "$TMPF"
mv "$TMPF" "$REQ" || bad "write failed"
TMPF=""
set -- $(shasum -a 256 "$REQ")
SHA=$1
release
printf 'DESK %s | %s | %s | sha256=%s\n' "$ID" "$VERB" "$REQ" "$SHA"
