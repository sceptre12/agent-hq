#!/usr/bin/env bash
# tests/run.sh — static checker of the wave-execution bundle rules over example-spec/ and
# tests/fixtures/{valid,invalid-<rule>-<case>}/. Hermetic, bash 3.2 / BSD awk, no network.
# Covers rules 4, 5, 9, 11, 13, 14, 15 (the rules new or amended by ADR 0054); rules 1-3, 6-8 and 10
# need the caller's filesystem or judgement and are not checked here. Option B bundles only
# (bundle.md plus waves/NN-<name>.md). A wave enumerates its work_items when its work_items value
# is empty or starts with "enumerated below" and each item is a "  - **<id>**" entry; any other
# value is a runtime rule. Last line: WAVE-EXEC-TESTS: PASS <n>/<n>
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SPEC="$(cd "$HERE/.." && pwd)"
ROOT="$(mktemp -d "${TMPDIR:-/tmp}/wave-exec-tests.XXXXXX")" || { echo "FAIL: mktemp -d"; exit 1; }
trap 'rm -rf "$ROOT"' EXIT

# check_bundle <dir>: prints "RULE <n>: wave <w>: <message>" lines; exit 1 if any.
check_bundle() {
  local files=()
  [ -f "$1/bundle.md" ] && files+=("$1/bundle.md")
  local f; for f in "$1"/waves/[0-9]*.md; do [ -f "$f" ] && files+=("$f"); done
  [ "${#files[@]}" -gt 0 ] || { echo "RULE 2: wave 0: no bundle.md or waves/ files in $1"; return 1; }
  awk '
  function trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s }
  function first(s,   a) { split(s, a, /[ \t]+/); return a[1] }
  function bad(rule, w, msg) { print "RULE " rule ": wave " w ": " msg; fails++ }
  function isnum(s) { return s ~ /^[0-9]+$/ }
  function enumerated(w) { return wval[w, "work_items"] == "" || wval[w, "work_items"] ~ /^enumerated below/ }
  function done_ok(v,   t, n, c) {   # {"token": "<str>", "command": "<str>"}, nothing else
    if (v !~ /^\{.*\}$/) return 0
    t = v; n = gsub(/"[A-Za-z_]+"[ \t]*:/, "&", t)
    if (n != 2) return 0
    if (v !~ /"token"[ \t]*:[ \t]*"[^"]+"/ || v !~ /"command"[ \t]*:[ \t]*"[^"]+"/) return 0
    return 1
  }
  FNR == 1 { inwi = 0; cur = ""; n = split(FILENAME, p, "/"); b = p[n]
    if (b == "bundle.md") w = 0; else { match(b, /^[0-9]+/); w = substr(b, 1, RLENGTH) + 0; seen[w] = 1; if (w > maxw) maxw = w } }
  /^- \*\*[a-z_]+(:\*\*|\*\*)/ {
    match($0, /^- \*\*[a-z_]+(:\*\*|\*\*)/); key = substr($0, 5, RLENGTH - 4); sub(/:?\*\*$/, "", key); v = substr($0, RLENGTH + 1)
    gsub(/`/, "", v); v = trim(v); wset[w, key] = 1; wval[w, key] = v
    inwi = (key == "work_items"); cur = ""; next }
  /^- \*\*/ { inwi = 0; cur = ""; next }
  inwi && /^  - \*\*[^*:]+\*\*[ \t]*$/ {
    nm = $0; sub(/^  - \*\*/, "", nm); sub(/\*\*[ \t]*$/, "", nm); cur = nm
    icount[w]++; iname[w, icount[w]] = nm; isitem[w, nm] = 1; next }
  inwi && cur != "" && /^    - \*\*[a-z_]+:\*\*/ {
    match($0, /^    - \*\*[a-z_]+:\*\*/); k = substr($0, 9, RLENGTH - 11); v = substr($0, RLENGTH + 1)
    gsub(/`/, "", v); v = trim(v); iset[w, cur, k] = 1; ival[w, cur, k] = v; next }
  END {
    split("goal inputs work_items agents exit_criteria outputs", req, " ")
    for (w = 1; w <= maxw; w++) if (!seen[w]) bad(4, w, "waves are not numbered contiguously from 1")
    for (w = 1; w <= maxw; w++) if (seen[w]) for (r = 1; r <= 6; r++) if (!wset[w, req[r]]) bad(5, w, "missing required field " req[r])
    for (w = 1; w <= maxw; w++) {
      if (!seen[w]) continue
      gt = wset[w, "gate_type"] ? first(wval[w, "gate_type"]) : "exit_criteria"
      if (gt !~ /^(exit_criteria|adversarial_verify|judge_panel|step_complete)$/) bad(9, w, "gate_type " gt " is not in the enum")
      if (gt == "adversarial_verify" && !(isnum(first(wval[w, "skeptics"])) && first(wval[w, "skeptics"]) + 0 >= 1)) bad(9, w, "adversarial_verify needs skeptics >= 1")
      if (gt == "judge_panel") { j = first(wval[w, "judges"]); if (!isnum(j) || j + 0 < 3 || j % 2 == 0) bad(9, w, "judge_panel needs an odd judges >= 3") }
      if (gt == "step_complete") {   # rule 9: done_condition on every work_item, so none may be runtime-generated
        if (!icount[w] || !enumerated(w)) bad(9, w, "step_complete needs every work_item listed, each with a done_condition")
        for (i = 1; i <= icount[w]; i++) { nm = iname[w, i]
          if (!iset[w, nm, "done_condition"]) bad(9, w, "work_item " nm " has no done_condition")
          else if (!done_ok(ival[w, nm, "done_condition"])) bad(9, w, "work_item " nm " done_condition is not exactly {token, command} with both non-empty") } }
    }
    if (wset[0, "session_id"] && wval[0, "session_id"] !~ /^[a-z0-9-]+$/) bad(13, 0, "session_id " wval[0, "session_id"] " does not match ^[a-z0-9-]+$")
    if (wset[0, "output_topic"]) {
      bt = first(wval[0, "output_topic"])
      if (bt ~ /[{}$<>]/) bad(14, 0, "bundle output_topic " bt " is not a literal")
      for (w = 1; w <= maxw; w++) if (wset[w, "output_topic"] && first(wval[w, "output_topic"]) != bt) bad(14, w, "per-wave output_topic differs from the bundle output_topic")
    }
    for (w = 1; w <= maxw; w++) {
      if (!seen[w]) continue
      edges = 0
      for (i = 1; i <= icount[w]; i++) { nm = iname[w, i]; nd[w, i] = 0
        if (!iset[w, nm, "depends_on"]) continue
        d = ival[w, nm, "depends_on"]; gsub(/\[|\]/, "", d); m = split(d, da, ",")
        for (x = 1; x <= m; x++) { e = trim(da[x]); if (e == "") continue
          edges++; nd[w, i]++; dep[w, i, nd[w, i]] = e
          if (!isitem[w, e]) { found = 0; for (o = 1; o <= maxw; o++) if (isitem[o, e]) found = 1
            bad(15, w, "work_item " nm " depends_on " e ", " (found ? "a work_item of another wave (cross-wave edge)" : "which this wave does not declare")) } } }
      frontier[w] = (edges > 0)
      if (!edges) continue
      if (!enumerated(w)) bad(15, w, "edges declared but the wave does not enumerate its work_items (work_items is a runtime rule)")
      for (i = 1; i <= icount[w]; i++) rem[w, i] = 0
      for (pass = 1; pass <= icount[w]; pass++) for (i = 1; i <= icount[w]; i++) if (!rem[w, i]) {
        ok = 1; for (x = 1; x <= nd[w, i]; x++) { dn = dep[w, i, x]; if (isitem[w, dn]) { for (y = 1; y <= icount[w]; y++) if (iname[w, y] == dn && !rem[w, y]) ok = 0 } }
        if (ok) rem[w, i] = 1 }
      for (i = 1; i <= icount[w]; i++) if (!rem[w, i]) { bad(15, w, "depends_on has a cycle through " iname[w, i]); break }
    }
    if (fails == 0 && wset[0, "dispatch_budget"]) {   # rule 11 runs last; a non-enumerated wave counts as 1 work_item
      total = 0
      for (w = 1; w <= maxw; w++) { n = icount[w] ? icount[w] : 1
        gt = wset[w, "gate_type"] ? first(wval[w, "gate_type"]) : "exit_criteria"
        cap = wset[w, "fix_loop_cap"] ? first(wval[w, "fix_loop_cap"]) + 0 : 3
        g = 1; if (gt == "adversarial_verify") g = first(wval[w, "skeptics"]) + 0; if (gt == "judge_panel") g = first(wval[w, "judges"]) + 0
        if (frontier[w]) total += n * (1 + (cap + 1) * g)
        else total += n + (cap + 1) * (gt == "step_complete" ? n : g) }
      budget = first(wval[0, "dispatch_budget"]) + 0
      if (total > budget) bad(11, 0, "projected " total " dispatches exceed dispatch_budget " budget " (split the bundle at a wave boundary)")
    }
    exit (fails > 0)
  }' "${files[@]}"
}

total=0; passed=0
rules_of() { printf '%s\n' "$1" | sed -n 's/^RULE \([0-9]*\):.*/\1/p' | sort -un | tr '\n' ' '; }
# expect <name> <dir> <want-rules>   want "" = must pass; "9" = fails with exactly rule 9
expect() {
  local out rc got; total=$((total + 1))
  out="$(check_bundle "$2" 2>&1)"; rc=$?; got="$(rules_of "$out")"
  local want_rc=0; [ -n "$3" ] && want_rc=1
  if [ "$got" = "${3:+$3 }" ] && [ "$rc" -eq "$want_rc" ]; then
    passed=$((passed + 1)); echo "PASS: $1"
  else echo "FAIL: $1 (rc=$rc, rules='$got', want='$3')"; printf '%s\n' "$out" | sed 's/^/  /'; fi
}

# 1. The full example bundle (3 legacy waves + the frontier wave 4 + bundle header) passes.
expect "example bundle (waves 1-4 + bundle header) passes" "$SPEC" ""
# 2. The legacy form (waves 1-3, no new fields) passes unchanged.
mkdir -p "$ROOT/legacy/waves"; cp "$SPEC"/waves/0[123]-*.md "$ROOT/legacy/waves/"
expect "legacy form (waves 1-3, no new fields) passes" "$ROOT/legacy" ""
# 3. Valid frontier fixture, then each negative fixture fails with exactly its named rule.
FX="$HERE/fixtures"
expect "fixture valid: frontier bundle passes (budget met exactly)" "$FX/valid" ""
expect "rule 9: step_complete without done_condition" "$FX/invalid-9-no-done" "9"
expect "rule 9: extra key in done_condition" "$FX/invalid-9-extra-key" "9"
expect "rule 9: gate_type outside the enum" "$FX/invalid-9-bad-enum" "9"
expect "rule 13: uppercase session_id" "$FX/invalid-13-uppercase" "13"
expect "rule 14: placeholder in bundle output_topic" "$FX/invalid-14-placeholder" "14"
expect "rule 14: per-wave output_topic differs from the bundle's" "$FX/invalid-14-differs" "14"
expect "rule 15: depends_on cycle" "$FX/invalid-15-cycle" "15"
expect "rule 15: cross-wave edge" "$FX/invalid-15-cross-wave" "15"
expect "rule 15: edges without enumerated work_items" "$FX/invalid-15-not-enumerated" "15"
expect "rule 11: frontier dispatch budget overrun" "$FX/invalid-11-overrun" "11"
# 4. Mutations of the example itself.
rm -rf "$ROOT/m"; mkdir -p "$ROOT/m"; cp -R "$SPEC/bundle.md" "$SPEC/waves" "$ROOT/m/"
sed -i.bak 's/^- \*\*session_id:\*\* `example-audit-fix`/- **session_id:** `Example_Fix`/' "$ROOT/m/bundle.md"
expect "mutation: example with uppercase session_id fails rule 13" "$ROOT/m" "13"
cp "$SPEC/bundle.md" "$ROOT/m/bundle.md"; rm -f "$ROOT/m/waves/02-fix.md"
expect "mutation: example with wave 2 removed fails rule 4" "$ROOT/m" "4"
cp -R "$SPEC/waves/02-fix.md" "$ROOT/m/waves/"
sed -i.bak 's/^- \*\*work_items:\*\* enumerated below.*/- **work_items:** one per file in `fixed_docs`, plus those below./' "$ROOT/m/waves/04-build.md"
rm -f "$ROOT/m/waves/"*.bak
expect "mutation: frontier step_complete wave whose work_items is a runtime rule fails rules 9 and 15" "$ROOT/m" "9 15"
# Rule 11 is the last check executed: with a rule 13 failure and an overrun, only rule 13 is reported.
cp -R "$FX/invalid-13-uppercase" "$ROOT/last"; sed -i.bak 's/dispatch_budget:\*\* 14/dispatch_budget:** 1/' "$ROOT/last/bundle.md"
expect "rule 11 runs last (suppressed while another rule fails)" "$ROOT/last" "13"

if [ "$passed" -eq "$total" ]; then echo "WAVE-EXEC-TESTS: PASS $passed/$total"; exit 0; fi
echo "WAVE-EXEC-TESTS: FAIL $passed/$total"; exit 1
