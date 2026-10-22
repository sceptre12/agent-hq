#!/usr/bin/env bash
# tools/git-hooks/test_pre-commit.sh — tests for tools/git-hooks/pre-commit. Real `git commit` runs in
# mktemp fixture repos (core.hooksPath -> a COPY of this checkout's hook). Regression focus: a large
# staged diff with an early token must still BLOCK (grep -q + pipefail SIGPIPE once let it through).
# Cases N/O/P/Q add a positive + near-miss per enforced pattern (Q10 asserts its seed landed); R drives the invariant-subset failure.
# Tokens are assembled at runtime so this file never contains a matching literal.
# --no-verify is exercised ONLY in a fixture, as a control proving the hook did the blocking.
set -uo pipefail
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_PREFIX
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null
REAL="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ROOT="$(mktemp -d)"; trap 'rm -rf "$ROOT"' EXIT
passed=0; failed=0; NFX=0
pass() { echo "PASS: $1"; passed=$((passed + 1)); }
fail() { echo "FAIL: $1"; failed=$((failed + 1)); }
eq() { if [ "$2" = "$3" ]; then pass "$1"; else fail "$1 (got '$2', want '$3')"; fi; }
has() { case "$2" in *"$3"*) pass "$1" ;; *) fail "$1 (missing '$3' in: $2)" ;; esac; }
mkfix() {
  NFX=$((NFX + 1)); FX="$ROOT/f$NFX"; git init -q -b main "$FX"; cd "$FX" || exit 1
  git config user.email t@t; git config user.name t; git config commit.gpgsign false
  mkdir -p tools/git-hooks; cp "$REAL/tools/git-hooks/pre-commit" tools/git-hooks/
  printf '#!/usr/bin/env bash\nexit 0\n' >tools/check-invariants.sh
  chmod +x tools/check-invariants.sh tools/git-hooks/pre-commit
  echo base >README.md; git add -A; git commit -qm base
  git config core.hooksPath tools/git-hooks
}
faketoken() { # assembled at runtime; never a literal in this file
  local pre='sk-ant-' fam='oat01-' body
  body=$(head -c 60 </dev/urandom | base64 | tr -dc 'A-Za-z0-9' | head -c 40)
  printf '%s%s%s' "$pre" "$fam" "$body"
}
# bigfile <out> <token-or-empty> — ~600 KB of random-letter lines; token (if any) on line 2.
bigfile() {
  head -c 900000 </dev/urandom | base64 | tr -dc 'A-Za-z' | head -c 600000 | fold -w 80 >"$1"
  if [ -n "$2" ]; then sed -i.bak "2s/^.*\$/$2/" "$1"; rm -f "$1.bak"; fi
}
cm() { git add -A; cout="$(git commit -qm "${1:-change}" 2>&1)"; rc=$?; }

mkfix; bigfile big.txt "$(faketoken)"; cm
[ "$(wc -c <big.txt)" -gt 500000 ] && pass "A fixture is ~600 KB" || fail "A fixture too small"
eq "A: 600 KB diff with early token: commit fails" "$([ $rc != 0 ] && echo yes || echo no)" yes
has "A: stderr says pre-commit BLOCK" "$cout" "pre-commit BLOCK"; has "A: stderr names Anthropic-token" "$cout" "Anthropic-token"

mkfix; printf 'x\n%s\n' "$(faketoken)" >small.txt; cm
eq "B: small diff with token: commit fails" "$([ $rc != 0 ] && echo yes || echo no)" yes
has "B: BLOCK message" "$cout" "pre-commit BLOCK"; has "B: Anthropic-token" "$cout" "Anthropic-token"
git commit -qm bypass --no-verify >/dev/null 2>&1; eq "F: same staged change with --no-verify succeeds (hook was the blocker)" "$?" 0

mkfix; bigfile clean.txt ""; cm
eq "C: 600 KB clean diff: commit succeeds" "$rc" 0

mkfix; echo ordinary >note.txt; cm
eq "ordinary small commit: exit 0" "$rc" 0

for f in secrets/x.txt foo.pem; do
  mkfix; mkdir -p "$(dirname "$f")"; echo v >"$f"; cm
  eq "D: staging $f fails" "$([ $rc != 0 ] && echo yes || echo no)" yes; has "D: $f message" "$cout" "secret-bearing filename"
done
mkfix; mkdir data; echo v >data/x.sqlite; cm
eq "E: staging data/x.sqlite fails" "$([ $rc != 0 ] && echo yes || echo no)" yes; has "E: message" "$cout" "runtime state"

# L728 (PR #10 advisories): every alternative of the secret pattern blocks; binary files are scanned (--text);
# memory/ allows only README.md; a failing git diff or grep (rc >= 2) blocks instead of reading as "clean".
fakeakia() { printf 'AK''IA%s' "$(head -c 40 /dev/urandom | base64 | tr -dc 'A-Z0-9' | head -c 16)"; }
fakepem() { printf -- '-----BEGIN %s''PRIVATE KEY-----' 'RSA '; }
mkfix; printf 'x\n%s\n' "$(fakeakia)" >aws.txt; cm
eq "G: AWS key id in diff: commit fails" "$([ $rc != 0 ] && echo yes || echo no)" yes; has "G: message names AWS-key" "$cout" "AWS-key"
mkfix; printf 'x\n%s\n' "$(fakepem)" >pk.txt; cm
eq "H: private-key header in diff: commit fails" "$([ $rc != 0 ] && echo yes || echo no)" yes; has "H: message names private-key" "$cout" "private-key"
mkfix; { printf 'bin\000data\n'; faketoken; printf '\n'; } >blob.dat; cm
eq "I: token inside a BINARY file (NUL bytes): commit fails (--text)" "$([ $rc != 0 ] && echo yes || echo no)" yes; has "I: Anthropic-token named" "$cout" "Anthropic-token"
mkfix; mkdir memory; echo n >memory/notes.md; cm
eq "J: staging memory/notes.md fails" "$([ $rc != 0 ] && echo yes || echo no)" yes; has "J: message" "$cout" "only memory/README.md"
mkfix; mkdir memory; echo n >memory/README.md; cm
eq "K: staging memory/README.md alone succeeds" "$rc" 0
# fail-closed: a git diff that dies (a missing GIT_EXTERNAL_DIFF program kills the patch diff only; git puts its own
# exec-path ahead of PATH for hooks, so a git shim would not reach the hook) and a grep shim that errors on the pattern.
SHIM="$ROOT/shim"; mkdir -p "$SHIM"; GREPR="$(command -v grep)"
printf '#!/usr/bin/env bash\ncase "$*" in *AKIA*) echo "grep: injected" >&2; exit 2 ;; esac\nexec "%s" "$@"\n' "$GREPR" >"$SHIM/grep"; chmod +x "$SHIM/grep"
mkfix; echo ordinary >note.txt; export GIT_EXTERNAL_DIFF=/nonexistent/extdiff; cm; unset GIT_EXTERNAL_DIFF
eq "L: git diff dies in the secret scan: commit blocked" "$([ $rc != 0 ] && echo yes || echo no)" yes; has "L: fail-closed message" "$cout" "cannot read the staged diff"
mkfix; echo ordinary >note.txt; git add -A; cout="$(PATH="$SHIM:$PATH" git commit -qm shimmed-grep 2>&1)"; rc=$?
eq "M: grep errors (rc 2) in the secret scan: commit blocked" "$([ $rc != 0 ] && echo yes || echo no)" yes; has "M: fail-closed message" "$cout" "secret scan failed"

# T-20261014-177: one positive (blocked, rc 1, message) + one near-miss negative (allowed) per enforced pattern.
# All secret-shaped fixtures are built at run time from pieces, with an obviously synthetic repeated-letter body.
rep() { printf "%${2}s" '' | tr ' ' "$1"; } # rep <char> <count>
blocked() { eq "$1: commit blocked (rc 1)" "$rc" 1; has "$1: message" "$cout" "$2"; }
allowed() { eq "$1: near-miss allowed (rc 0)" "$rc" 0; }
stage() { # stage <path>... : create each path with ordinary content, then commit
  local p; for p in "$@"; do mkdir -p "$(dirname "$p")"; echo v >"$p"; done; cm
}
# FNAME/RUNT: substrings of the hook's block messages for rules (a) and (b).
# Content-scan (c) emits ONE shared message for all 3 patterns: Q cases assert rc 1 + single-pattern fixtures.
FNAME="secret-bearing filename"; RUNT="runtime state"
# hook rule (a) secret filenames (its -i makes every alternative case-insensitive: Secrets/, CERT.PEM, .ENV all block): .env / .env.* / *.pem / *.key / secrets/ (case-insensitive); D covers secrets/x.txt and foo.pem
mkfix; stage .env; blocked "N1 .env" "$FNAME"
mkfix; stage cfg/.env.local; blocked "N2 .env.local" "$FNAME"
mkfix; stage id.key; blocked "N3 id.key" "$FNAME"
mkfix; stage Secrets/a.txt; blocked "N4 Secrets/ (case-insensitive)" "$FNAME"
mkfix; stage CERT.PEM; blocked "N5 CERT.PEM (case-insensitive)" "$FNAME"
mkfix; stage env.md .environment notes.keys.md foo.pem.md secrets.md; allowed "N6 env.md/.environment/notes.keys.md/foo.pem.md/secrets.md"
# hook rule (b) runtime state: data/ .serena/ *.sqlite *.db *.db-wal *.db-shm; E covers data/x.sqlite
mkfix; stage .serena/cache.txt; blocked "O1 .serena/" "$RUNT"
mkfix; stage app/data/x.txt; blocked "O2 nested data/" "$RUNT"
mkfix; stage a.db; blocked "O3 a.db" "$RUNT"
mkfix; stage a.db-wal; blocked "O4 a.db-wal" "$RUNT"
mkfix; stage a.db-shm; blocked "O5 a.db-shm" "$RUNT"
mkfix; stage x.sqlite; blocked "O6 x.sqlite" "$RUNT"
mkfix; stage database.md mydata/x.txt dbfile.txt data.md; allowed "O7 database.md/mydata/dbfile.txt/data.md"
mkfix; stage x.sqlite3; allowed "O8 x.sqlite3 (regex anchors on .sqlite\$)"
mkfix; stage DATA/x.txt; blocked "O9 uppercase DATA/ (runtime-state grep is case-insensitive, -i)" "$RUNT"
mkfix; stage myserena/x; allowed "O10 myserena/x (near-miss vs .serena/)"
mkfix; stage x.sqlite.md; allowed "O11 x.sqlite.md (near-miss vs *.sqlite)"
mkfix; stage a.db-wal.txt; allowed "O12 a.db-wal.txt (near-miss vs *.db-wal)"
mkfix; stage a.db-shm.md; allowed "O13 a.db-shm.md (near-miss vs *.db-shm)"
# hook memory/ rule: only README.md; J and K cover notes.md and README.md. Near-misses: path outside the prefix.
mkfix; stage memory/sub/README.md; blocked "P1 memory/sub/README.md" "only memory/README.md"
mkfix; stage docs/memory/notes.md memory.md; allowed "P2 docs/memory/notes.md + memory.md (not a top-level memory/ path)"
# hook rule (c) content scan of added lines; token regex is sk-ant-(oat|ort|api)[0-9]{2}- (any two digits)
mkfix; printf 'x\n%s\n' "AK""IA$(rep Z 16)" >a.txt; cm; blocked "Q1 AKIA+16 chars" "AWS-key"
mkfix; printf 'x\n%s\n' "AK""IA$(rep Z 15)" >a.txt; cm; allowed "Q2 AKIA+15 chars"
mkfix; printf 'x\n%s\n' "ak""ia$(rep Z 16)" >a.txt; cm; allowed "Q3 lowercase akia+16"
mkfix; printf 'x\n%s\n' "-----BEGIN ""EC PRIVATE KEY-----" >a.txt; cm; blocked "Q4 BEGIN EC PRIVATE KEY" "private-key"
mkfix; printf 'x\n%s\n' "-----BEGIN ""PRIVATE KEY-----" >a.txt; cm; blocked "Q5 BEGIN PRIVATE KEY (no algo)" "private-key"
mkfix; printf 'x\n%s\n' "-----BEGIN ""PUBLIC KEY-----" >a.txt; cm; allowed "Q6 BEGIN PUBLIC KEY"
for fam in oat01 ort02 api03; do
  mkfix; printf 'x\n%s\n' "sk-""ant-$fam-$(rep Z 20)" >a.txt; cm; blocked "Q7 sk-ant-$fam" "Anthropic-token"
done
mkfix; printf 'x\n%s\n' "sk-""ant-xyz99-$(rep Z 20)" >a.txt; cm; allowed "Q8 sk-ant-xyz99- (unknown family)"
mkfix; printf 'x\n%s\n' "sk-""ant-api3-$(rep Z 20)" >a.txt; cm; allowed "Q9 sk-ant-api3- (one digit)"
# a REMOVED line carrying a key is not an added line: deleting a leaked key must not be blocked
mkfix; printf 'x\n%s\n' "AK""IA$(rep Z 16)" >a.txt; git add -A; git commit -qm seed --no-verify >/dev/null 2>&1
has "Q10 seed landed in HEAD (control is not vacuous)" "$(git show HEAD:a.txt)" "AK""IA$(rep Z 16)"
printf 'x\n' >a.txt; cm; allowed "Q10 removing a line that holds a key"
# hook rule (d): a failing invariant subset blocks (stub overridden in this fixture only)
mkfix; printf '#!/usr/bin/env bash\nexit 1\n' >tools/check-invariants.sh; echo ordinary >note.txt; cm
blocked "R1 invariant subset exits 1" "invariant subset failed"

echo "=== $passed passed, $failed failed ==="; [ "$failed" = 0 ]
