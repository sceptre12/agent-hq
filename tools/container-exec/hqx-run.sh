#!/usr/bin/env bash
# hqx-run.sh — host runner for the ADR-0008 container execution lane.
# Usage: hqx-run.sh --repo <path> --task <spec.md> --out <dir> [options]
set -uo pipefail

IMAGE="hqx-claude:latest"
MODEL="opus"
MODE="clone"                       # clone | rw
KC_SERVICE="hqx-claude-oauth"      # Keychain service (D2)
KC_ACCOUNT="${USER}"
MAX_CONCURRENT="${HQX_MAX_CONCURRENT:-2}"
REPO="" TASK="" OUT="" NAME=""

die(){ echo "hqx-run: $1" >&2; exit "${2:-2}"; }

while [ $# -gt 0 ]; do
  case "$1" in
    --repo)  REPO="$2"; shift 2;;
    --task)  TASK="$2"; shift 2;;
    --out)   OUT="$2";  shift 2;;
    --image) IMAGE="$2"; shift 2;;
    --model) MODEL="$2"; shift 2;;
    --rw)    MODE="rw"; shift;;
    --name)  NAME="$2"; shift 2;;
    -h|--help) echo "Usage: hqx-run.sh --repo <path> --task <spec.md> --out <dir> [--rw] [--image T] [--model M] [--name N]"; exit 0;;
    *) die "unknown arg: $1" 2;;
  esac
done

# --- preflight (exit codes are contractual) ---
[ -n "$REPO" ] && [ -n "$TASK" ] && [ -n "$OUT" ] || die "need --repo, --task, --out" 2
docker version >/dev/null 2>&1 || die "docker unreachable" 3
docker image inspect "$IMAGE" >/dev/null 2>&1 || die "image $IMAGE missing (docker build tools/container-exec/)" 4
TOKEN="$(security find-generic-password -w -s "$KC_SERVICE" -a "$KC_ACCOUNT" 2>/dev/null)" \
  || die "token not in Keychain ($KC_SERVICE). Add: security add-generic-password -U -s $KC_SERVICE -a $KC_ACCOUNT -w" 5
running="$(docker ps -q --filter label=hq.lane=container-exec | wc -l | tr -d ' ')"
[ "$running" -lt "$MAX_CONCURRENT" ] || die "concurrency cap reached ($running >= $MAX_CONCURRENT); shared subscription quota" 6
git -C "$REPO" rev-parse --git-dir >/dev/null 2>&1 || die "not a git repo: $REPO" 7
mkdir -p "$OUT" 2>/dev/null && [ -w "$OUT" ] || die "out dir not writable: $OUT" 7
[ -f "$TASK" ] || die "task spec not found: $TASK" 7

REPO="$(cd "$REPO" && pwd)"; OUT="$(cd "$OUT" && pwd)"; TASK="$(cd "$(dirname "$TASK")" && pwd)/$(basename "$TASK")"
SLUG="$(basename "$REPO" | tr -c 'a-zA-Z0-9_.-' '-')"
NAME="${NAME:-hqx-${SLUG}-$(date +%s)}"

# Token rides the runner's ENV (never the docker argv → invisible to ps).
export CLAUDE_CODE_OAUTH_TOKEN="$TOKEN"; unset TOKEN

# Mount surface: /src-ro (RO source) OR /work (RW), /task (RO spec), /out (writable).
mounts=( --mount "type=bind,src=${TASK},dst=/task/spec.md,readonly"
         --mount "type=bind,src=${OUT},dst=/out" )
if [ "$MODE" = rw ]; then
  mounts+=( --mount "type=bind,src=${REPO},dst=/work" )
else
  mounts+=( --mount "type=bind,src=${REPO},dst=/src-ro,readonly" )
fi

docker run --rm --name "$NAME" \
  --label hq.lane=container-exec --label "hq.repo=${SLUG}" --label "hq.task=$(basename "$TASK" .md)" \
  -e CLAUDE_CODE_OAUTH_TOKEN \
  -e "HQX_MODE=${MODE}" -e "HQX_MODEL=${MODEL}" -e "HQX_TASK_SLUG=$(basename "$TASK" .md)" \
  "${mounts[@]}" \
  "$IMAGE"
rc=$?

unset CLAUDE_CODE_OAUTH_TOKEN
echo "hqx-run: done (rc=$rc). Results in $OUT (review result.diff, fetch result.bundle, then push from host)." >&2
exit "$rc"
