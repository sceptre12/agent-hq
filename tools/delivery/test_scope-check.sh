#!/usr/bin/env bash
# Hermetic tests for scope-check.sh. Run: bash tools/delivery/test_scope-check.sh
here=$(cd "$(dirname "$0")" && pwd)
SC="$here/scope-check.sh"
pass=0; fail=0
root=$(mktemp -d "${TMPDIR:-/tmp}/t-scope.XXXXXX") || exit 1
trap 'rm -rf "$root"' EXIT
export HOME="$root/home"; mkdir -p "$HOME"
export GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null

ok()  { pass=$((pass+1)); }
bad() { fail=$((fail+1)); echo "FAIL: $1"; }
g() { git -C "$R" -c user.email=t@t -c user.name=t "$@"; }

# expect NAME RC STDOUT-EXACT -- args...
expect() {
  local name=$1 erc=$2 eout=$3; shift 3
  local o e rc
  o=$("$SC" "$@" 2>"$root/err"); rc=$?
  e=$(cat "$root/err")
  if [ "$rc" -ne "$erc" ]; then bad "$name: rc $rc want $erc ($e)"; return; fi
  if [ "$o" != "$eout" ]; then bad "$name: stdout [$o] want [$eout]"; return; fi
  if [ "$erc" -eq 2 ] && [ -z "$e" ]; then bad "$name: empty stderr"; return; fi
  ok
}

mktasks() { # file, globs...
  local f=$1; shift
  { echo "# T"; echo "- src/ignored-before.ts"; echo "## 2 x"; echo "## 3 Scope"; for x in "$@"; do echo "- $x"; done
    echo "not a glob"; echo "## 4 Out"; echo "- docs/**"; } > "$f"
}

newrepo() {
  R=$(mktemp -d "$root/r.XXXXXX")
  git init -q "$R" 2>/dev/null
  g checkout -q -b main 2>/dev/null
  mkdir -p "$R/src/a" "$R/docs"
  echo 0 > "$R/src/base.ts"; echo 0 > "$R/docs/d.md"
  g add -A; g commit -q -m base
  BASE=$(g rev-parse HEAD)
  g checkout -q -b feat
}
commitall() { g add -A; g commit -q -m "$1"; }

# --- clean and creep, star semantics
newrepo
echo 1 > "$R/src/x.ts"; echo 1 > "$R/src/a/b.ts"; commitall c
mktasks "$root/t1.md" 'src/*.ts'
expect "star one segment" 1 "CREEP src/a/b.ts" "$root/t1.md" "$R" "$BASE"
mktasks "$root/t2.md" 'src/**'
expect "doublestar covers both" 0 "" "$root/t2.md" "$R" "$BASE"
echo 1 > "$R/other.txt"; echo 1 > "$R/aaa.txt"; commitall c2
expect "several creeps" 1 "CREEP aaa.txt
CREEP other.txt" "$root/t2.md" "$R" "$BASE"

# --- ignore globs outside section 3
expect "glob after next heading ignored" 1 "CREEP aaa.txt
CREEP other.txt" "$root/t2.md" "$R" "$BASE"

# --- delete, modify, rename, space, control char
newrepo
echo 1 > "$R/src/base.ts"; git -C "$R" rm -q docs/d.md
echo n > "$R/src/new file.ts"; mkdir -p "$R/ren"; echo r > "$R/ren/old.txt"
commitall c1
BASE2=$(g rev-parse HEAD)
g mv ren/old.txt src/renamed.txt; commitall c2
mktasks "$root/t3.md" 'src/**'
expect "delete creep (net rename gone)" 1 "CREEP docs/d.md" "$root/t3.md" "$R" "$BASE"
expect "rename both sides" 1 "CREEP ren/old.txt" "$root/t3.md" "$R" "$BASE2"
cc=$(printf 'bad\001name.txt'); echo c > "$R/$cc"; commitall c3
expect "control char as ?" 1 "CREEP bad?name.txt" "$root/t3.md" "$R" "$(g rev-parse HEAD~1)"
mktasks "$root/t4.md" 'src/**' 'docs/**' 'ren/**' 'bad*'
expect "space path in scope" 0 "" "$root/t4.md" "$R" "$BASE"
mktasks "$root/t5.md" 'docs/**' 'ren/**' 'bad*'
expect "space path printed whole" 1 "CREEP src/base.ts
CREEP src/new file.ts
CREEP src/renamed.txt" "$root/t5.md" "$R" "$BASE"

# --- merge-base range: base-branch change after the fork is not reported
newrepo
g checkout -q main; echo m > "$R/main-only.txt"; commitall m
g checkout -q feat; echo f > "$R/src/f.ts"; commitall f
mktasks "$root/t6.md" 'src/**'
expect "three-dot range" 0 "" "$root/t6.md" "$R" "$BASE"
MB=$(g merge-base HEAD main); expect "merge-base sha" 0 "" "$root/t6.md" "$R" "$MB"

# --- exit 2 conditions
expect "no args" 2 ""
expect "two args" 2 "" "$root/t6.md" "$R"
expect "tasks unreadable" 2 "" "$root/nope.md" "$R" "$BASE"
printf '# x\n## 2 a\n- src/**\n' > "$root/n3.md"
expect "no heading" 2 "" "$root/n3.md" "$R" "$BASE"
printf '## 3 S\nprose only\n## 4\n- a\n' > "$root/z.md"
expect "zero globs" 2 "" "$root/z.md" "$R" "$BASE"
printf '## 3 S\n- :(top)x\n' > "$root/m.md"
expect "magic glob" 2 "" "$root/m.md" "$R" "$BASE"
printf '## 3 S\n- a\001b\n' > "$root/c.md"
expect "control glob" 2 "" "$root/c.md" "$R" "$BASE"
expect "not a worktree" 2 "" "$root/t6.md" "$root" "$BASE"
expect "short sha" 2 "" "$root/t6.md" "$R" "${BASE%????????}"
expect "upper sha" 2 "" "$root/t6.md" "$R" "$(echo "$BASE" | tr a-f A-F | sed 's/^\([0-9]\)/a/')"
expect "unknown commit" 2 "" "$root/t6.md" "$R" "0123456789012345678901234567890123456789"
expect "blob not commit" 2 "" "$root/t6.md" "$R" "$(g rev-parse HEAD:src/f.ts)"

echo "scope-check: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
