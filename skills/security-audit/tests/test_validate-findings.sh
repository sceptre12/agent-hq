#!/usr/bin/env bash
# Gate wrapper for the vendored skills/security-audit/validate-findings.test.cjs (vendored unmodified, see ../PROVENANCE.md; it
# has no shebang or exec bit, so the code gate cannot run it directly). Runs it with node from the repo root.
# Needs node on PATH (the tests spawn node and mkfifo in temp dirs under TMPDIR); fails closed without it.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
command -v node >/dev/null 2>&1 || { echo "FAIL: node not found on PATH"; exit 1; }
exec node "$HERE/../validate-findings.test.cjs"
