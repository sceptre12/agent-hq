#!/bin/sh
# check-network.sh — verify outbound network reachability without depending on DNS.
#
# Tests a TCP connection to a short list of well-known, DNS-free IP addresses.
# Because the targets are raw IPs, a broken or unreachable DNS resolver cannot
# produce a false negative here — this checks the network path itself.
#
# Usage:
#   check-network.sh        silent; exit code only
#   check-network.sh -v     verbose — prints each attempt to stderr
#
# Exit codes:
#   0 = at least one target reachable (network is up)
#   1 = no target reachable (network is down, or all paths blocked)

set -u

VERBOSE=0
if [ "${1:-}" = "-v" ]; then
  VERBOSE=1
fi

# DNS-free targets: Cloudflare primary, Google DNS secondary/fallback.
TARGETS="1.1.1.1 8.8.8.8 8.8.4.4"
PORT=443
TIMEOUT=2

log() {
  if [ "$VERBOSE" -eq 1 ]; then
    echo "$1" >&2
  fi
}

try_nc() {
  target="$1"
  if command -v nc >/dev/null 2>&1; then
    if nc -z -w "$TIMEOUT" "$target" "$PORT" >/dev/null 2>&1; then
      return 0
    fi
  fi
  return 1
}

try_curl() {
  target="$1"
  if command -v curl >/dev/null 2>&1; then
    if curl -s -o /dev/null --connect-timeout "$TIMEOUT" "https://${target}" >/dev/null 2>&1; then
      return 0
    fi
  fi
  return 1
}

for target in $TARGETS; do
  log "check-network: trying $target:$PORT via nc"
  if try_nc "$target"; then
    log "check-network: reachable via nc ($target)"
    exit 0
  fi
  log "check-network: trying $target via curl"
  if try_curl "$target"; then
    log "check-network: reachable via curl ($target)"
    exit 0
  fi
  log "check-network: $target unreachable"
done

log "check-network: no target reachable — network is down"
exit 1
