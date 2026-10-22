#!/usr/bin/env bash
# TDD tests for install-sweep-launchd.sh
set -euo pipefail

SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/install-sweep-launchd.sh"
LABEL="space.devr.file-organizer-sweep"

passed=0
failed=0

assert_exit_code() {
  local expected=$1 actual=$2 desc=$3
  if [ "$actual" -eq "$expected" ]; then echo "PASS: $desc"; passed=$((passed+1))
  else echo "FAIL: $desc (expected $expected, got $actual)"; failed=$((failed+1)); fi
}
assert_file_contains() {
  local file=$1 pattern=$2 desc=$3
  if grep -qF "$pattern" "$file"; then echo "PASS: $desc"; passed=$((passed+1))
  else echo "FAIL: $desc (pattern not found: $pattern)"; failed=$((failed+1)); fi
}
assert_file_exists() {
  local file=$1 desc=$2
  if [ -f "$file" ]; then echo "PASS: $desc"; passed=$((passed+1))
  else echo "FAIL: $desc (file not found)"; failed=$((failed+1)); fi
}
assert_file_not_exists() {
  local file=$1 desc=$2
  if [ ! -f "$file" ]; then echo "PASS: $desc"; passed=$((passed+1))
  else echo "FAIL: $desc (file exists unexpectedly)"; failed=$((failed+1)); fi
}

echo "Running install-sweep-launchd.sh tests..."

# Test 1: syntax check
exit_code=0
(bash -n "$SCRIPT") || exit_code=$?
assert_exit_code 0 $exit_code "bash -n syntax check"

# Test 2: /usr/bin/python3 is present (absolute interpreter, Phase 1 §3.2)
exit_code=0
([ -x /usr/bin/python3 ]) || exit_code=$?
assert_exit_code 0 $exit_code "/usr/bin/python3 exists"

# Shared fixtures: a temp FILEORG_DIR holding a stub fileorg.py, a temp
# LAUNCHD_DIR, and a temp XDG_DATA_HOME so no real ~/.local/share is touched.
fileorg_dir=$(mktemp -d)
launchd_dir=$(mktemp -d)
xdg_dir=$(mktemp -d)
trap 'rm -rf "$fileorg_dir" "$launchd_dir" "$xdg_dir"' EXIT
echo "# stub fileorg.py for install test" > "$fileorg_dir/fileorg.py"
plist="$launchd_dir/${LABEL}.plist"

# Test 3: basic run
exit_code=0
(FILEORG_DIR="$fileorg_dir" LAUNCHD_DIR="$launchd_dir" XDG_DATA_HOME="$xdg_dir" \
  bash "$SCRIPT" > /dev/null 2>&1) || exit_code=$?
assert_exit_code 0 $exit_code "script exits 0"
assert_file_exists "$plist" "plist created"

# Test 4: plist content
assert_file_contains "$plist" "space.devr.file-organizer-sweep" "label correct"
assert_file_contains "$plist" "<string>/usr/bin/python3</string>" "absolute python in plist"
assert_file_contains "$plist" "<string>$fileorg_dir/fileorg.py</string>" "fileorg.py path in plist"
assert_file_contains "$plist" "<string>sweep</string>" "sweep argument in plist"
assert_file_contains "$plist" "<key>StartCalendarInterval</key>" "StartCalendarInterval key"
assert_file_contains "$plist" "<key>Hour</key><integer>7</integer>" "Hour is 7"
assert_file_contains "$plist" "<key>Minute</key><integer>30</integer>" "Minute is 30"
assert_file_contains "$plist" "<key>StandardOutPath</key>" "StandardOutPath configured"
assert_file_contains "$plist" "<key>StandardErrorPath</key>" "StandardErrorPath configured"
assert_file_contains "$plist" "$xdg_dir/file-organizer/logs" "logs routed to Layer-2 XDG dir"
assert_file_contains "$plist" "<key>WorkingDirectory</key><string>$fileorg_dir</string>" "WorkingDirectory is FILEORG_DIR"

# Test 5: idempotency (second run is a no-op success)
exit_code=0
(FILEORG_DIR="$fileorg_dir" LAUNCHD_DIR="$launchd_dir" XDG_DATA_HOME="$xdg_dir" \
  bash "$SCRIPT" > /dev/null 2>&1) || exit_code=$?
assert_exit_code 0 $exit_code "second run exits 0 (idempotent)"
assert_file_exists "$plist" "plist still present after second run"

# Test 6: refuse-to-overwrite a foreign plist (different program)
foreign_dir=$(mktemp -d)
trap 'rm -rf "$fileorg_dir" "$launchd_dir" "$xdg_dir" "$foreign_dir"' EXIT
foreign_plist="$foreign_dir/${LABEL}.plist"
cat > "$foreign_plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0">
<dict>
  <key>ProgramArguments</key>
  <array>
    <string>/usr/bin/python3</string>
    <string>/some/other/program.py</string>
    <string>sweep</string>
  </array>
</dict>
</plist>
EOF
exit_code=0
(FILEORG_DIR="$fileorg_dir" LAUNCHD_DIR="$foreign_dir" XDG_DATA_HOME="$xdg_dir" \
  bash "$SCRIPT" > /dev/null 2>&1) || exit_code=$?
assert_exit_code 1 $exit_code "exits 1 on foreign plist (different program)"
assert_file_contains "$foreign_plist" "/some/other/program.py" "foreign plist not overwritten"

# Test 7: missing fileorg.py refuses
empty_dir=$(mktemp -d)
missing_launchd=$(mktemp -d)
trap 'rm -rf "$fileorg_dir" "$launchd_dir" "$xdg_dir" "$foreign_dir" "$empty_dir" "$missing_launchd"' EXIT
exit_code=0
(FILEORG_DIR="$empty_dir" LAUNCHD_DIR="$missing_launchd" XDG_DATA_HOME="$xdg_dir" \
  bash "$SCRIPT" > /dev/null 2>&1) || exit_code=$?
assert_exit_code 1 $exit_code "exits 1 when fileorg.py is missing"
assert_file_not_exists "$missing_launchd/${LABEL}.plist" "no plist created when fileorg.py missing"

echo ""
echo "Passed: $passed  Failed: $failed"
[ "$failed" -eq 0 ]
