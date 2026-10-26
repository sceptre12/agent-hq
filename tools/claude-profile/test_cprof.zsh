#!/usr/bin/env zsh
# tools/claude-profile/test_cprof.zsh — tests for cprof.zsh (new/use/off). Hermetic: HOME and
# CPROF_ROOT live in a mktemp dir, zsh -f skips the user's config, real claude is never run. The cprof-managed
# variables are unset in every child (CLEAN) so the result does not depend on the profile the caller runs under.
SRC=${0:A:h}
# CLEAN is derived from cprof.zsh's own _CPROF_TRACKED (minus PS1, which is not exported env) so there is one authority.
_TRK=(${(f)"$(zsh -fc "source $SRC/cprof.zsh; print -l \${_CPROF_TRACKED:#PS1}" 2>/dev/null)"}); CLEAN=(); for _v in $_TRK; do CLEAN+=(-u $_v); done
_tb=${TMPDIR:-/tmp}; T=$(mktemp -d "${_tb%/}/test_cprof.XXXXXX") || exit 1
trap 'chmod -R u+rwx "$T" 2>/dev/null; rm -rf "$T"' EXIT
mkdir -p $T/bin $T/home $T/root
fails=0
ok()  { print -r -- "ok   $1"; }
bad() { print -r -- "FAIL $1"; fails=$((fails+1)); }
zrun() { env $CLEAN HOME=$T/home CPROF_ROOT=$T/root PATH=$T/bin:/usr/bin:/bin:/usr/local/bin:/opt/homebrew/bin \
         zsh -fc "source $SRC/cprof.zsh; $1" 2>&1 </dev/null; }
mkprof() { mkdir -p $T/root/$1/config $T/root/$1/workspace; print -r -- "tok-$1" > $T/root/$1/token; }

# Defect 3: profile.env assigning name/d/n/v must not clobber _cprof_use's state.
mkprof p3; print -r -- 'name=clobber; d=/nonexistent; n=x; v=y' > $T/root/p3/profile.env
out=$(zrun 'cprof use p3 >/dev/null; print -r -- "ACTIVE=$(cprof current) CFG=$CLAUDE_CONFIG_DIR PWD=$PWD"')
[[ $out == *"ACTIVE=p3 CFG=$T/root/p3/config PWD="*"/root/p3/workspace"* ]] && ok "3 profile.env locals isolated" || bad "3: $out"

# Defect 4: a set-but-unexported var assigned in profile.env is restored (value + unexported) on off.
mkprof p4; print -r -- 'MYV=new' > $T/root/p4/profile.env
out=$(zrun 'typeset +x MYV=orig; cprof use p4 >/dev/null; cprof off >/dev/null
            print -r -- "SET=${+MYV} VAL=${MYV-} T=${parameters[MYV]}"')
[[ $out == "SET=1 VAL=orig T=scalar" ]] && ok "4 unexported var restored" || bad "4: $out"
# ...and a var profile.env newly creates is still removed on off.
print -r -- 'NEWV=1' > $T/root/p4/profile.env
out=$(zrun 'cprof use p4 >/dev/null; cprof off >/dev/null; print -r -- "SET=${+NEWV}"')
[[ $out == "SET=0" ]] && ok "4b new var unset on off" || bad "4b: $out"

# Regression guard: an exported special var (PATH) changed by profile.env is still restored.
print -r -- 'PATH=/usr/bin:/bin' > $T/root/p4/profile.env
out=$(zrun 'p=$PATH; cprof use p4 >/dev/null; cprof off >/dev/null; [[ $PATH == $p ]] && print PATHOK')
[[ $out == PATHOK ]] && ok "4c PATH restored" || bad "4c: $out"

# Defect 6: empty / unreadable token -> use fails with an error and changes nothing.
mkprof p6; : > $T/root/p6/token
out=$(zrun 'cprof use p6; print -r -- "RC=$? SET=${+CLAUDE_CONFIG_DIR}"')
[[ $out == *"cprof:"*"token"*"RC=1 SET=0" ]] && ok "6a empty token rejected" || bad "6a: $out"
mkprof p6b; chmod 000 $T/root/p6b/token
out=$(zrun 'cprof use p6b; print -r -- "RC=$? SET=${+CLAUDE_CONFIG_DIR}"'); chmod 600 $T/root/p6b/token
[[ $out == *"cprof:"*"token"*"RC=1 SET=0" ]] && ok "6b unreadable token rejected" || bad "6b: $out"

# Defect 7: failed template copy -> new fails and removes the half-made profile.
mkdir -p $T/root/_templates/bad; print x > $T/root/_templates/bad/f; chmod 000 $T/root/_templates/bad/f
out=$(env $CLEAN HOME=$T/home CPROF_ROOT=$T/root PATH=/usr/bin:/bin zsh -fc "source $SRC/cprof.zsh; cprof new p7 --template bad; print RC=\$?" 2>&1 <<<tok)
chmod 600 $T/root/_templates/bad/f
[[ $out == *"RC=1" && ! -e $T/root/p7 ]] && ok "7 cp failure aborts and cleans up" || bad "7: $out (exists: $(ls $T/root))"

# Onboarding: a profile's own .claude.json must carry hasCompletedOnboarding=true (stub claude on PATH).
print -r -- '#!/bin/sh
exit 0' > $T/bin/claude; chmod +x $T/bin/claude
out=$(env $CLEAN HOME=$T/home CPROF_ROOT=$T/root PATH=$T/bin:/usr/bin:/bin:/opt/homebrew/bin zsh -fc "source $SRC/cprof.zsh; cprof new ob1" 2>&1 <<<tok)
f=$T/root/ob1/config/.claude.json
[[ -f $f && $(jq -r .hasCompletedOnboarding $f 2>/dev/null) == true && $(stat -f %Lp $f) == 600 ]] \
  && ok "a new creates .claude.json (flag true, mode 600)" || bad "a: $out"

mkprof ob2; print -r -- '{"projects":{"/x":{"a":1}},"theme":"dark"}' > $T/root/ob2/config/.claude.json
out=$(zrun 'pre=$CLAUDE_CONFIG_DIR; cprof use ob2 >/dev/null; cprof use ob2 >/dev/null; cprof off >/dev/null
            print -r -- "SET=${+CLAUDE_CONFIG_DIR}"')
f=$T/root/ob2/config/.claude.json
[[ $out == "SET=0" && $(jq -c '[.hasCompletedOnboarding,.theme,.projects["/x"].a]' $f) == '[true,"dark",1]' ]] \
  && ok "b use sets flag, preserves keys, off restores env" || bad "b: $out $(<$f)"

mkprof ob3; print -r -- '{not json' > $T/root/ob3/config/.claude.json
out=$(zrun 'cprof use ob3 >/dev/null; print -r -- "RC=$? SET=${+CLAUDE_CONFIG_DIR}"')
mkprof ob4; print -r -- '{"k":1}' > $T/root/ob4/config/.claude.json; chmod 000 $T/root/ob4/config/.claude.json
out4=$(zrun 'cprof use ob4 2>&1 >/dev/null; print -r -- "RC=$? SET=${+CLAUDE_CONFIG_DIR}"'); chmod 600 $T/root/ob4/config/.claude.json
[[ $out == *"RC=0 SET=1" && $(<$T/root/ob3/config/.claude.json) == '{not json' && $out4 == *"cprof:"*"RC=0 SET=1" \
   && $(<$T/root/ob4/config/.claude.json) == '{"k":1}' ]] \
  && ok "c invalid/unreadable left untouched, warned, use succeeds" || bad "c: $out | $out4"

# PR #32 A1: CLEAN covers every tracked env var, so an ambient provider flag cannot leak into a hermetic case.
(( $#_TRK >= 9 && $#CLEAN == 2 * $#_TRK )) && ok "CLEAN unsets all $#_TRK tracked vars (-u each)" || bad "CLEAN has $(( $#CLEAN / 2 )) vars"
out=$(CLAUDE_CODE_USE_BEDROCK=1 CLAUDE_CODE_DISABLE_AUTO_MEMORY=1 zrun 'print -r -- "B=${+CLAUDE_CODE_USE_BEDROCK} M=${+CLAUDE_CODE_DISABLE_AUTO_MEMORY}"')
[[ $out == "B=0 M=0" ]] && ok "ambient USE_BEDROCK / DISABLE_AUTO_MEMORY do not leak" || bad "ambient leak: $out"

# ---- permission-tiers P2: tier verbs (architecture/permission-tiers.md Components 3). Hermetic fake hq tree.
REPO=${SRC:h:h}; HQ=$T/hq
mkdir -p $HQ/config/tiers $HQ/tools/claude-profile
cp -R $REPO/config/tiers/. $HQ/config/tiers/; cp -R $REPO/tools/claude-profile/templates $HQ/tools/claude-profile/
print -r -- '{"theme":"dark","permissions":{"allow":["Read"],"deny":["Bash(rm -rf /)"]},"hooks":{"X":[1]},"sandbox":{"network":{"allowedDomains":["hq.example"]}}}' > $HQ/config/settings.json
trun() { env $CLEAN CPROF_OWNER=testowner HOME=$T/home CPROF_ROOT=$T/root CPROF_HQ_CONFIG=$HQ/config PATH=$T/bin:/usr/bin:/bin:/usr/local/bin:/opt/homebrew/bin \
         zsh -fc "source $SRC/cprof.zsh; $1" 2>&1 <<<"${2:-tok}"; }
S=$T/root/ex1/config/settings.json
out=$(trun 'cprof new ex1 --tier executor')
fd=$(jq -c '.permissions.deny' $HQ/config/tiers/executor.json)
[[ $(jq -r '.sandbox.enabled' $S) == true && $(jq --argjson f "$fd" '[$f[] as $x | (.permissions.deny | index($x)) != null] | all' $S) == true \
   && $(jq '.permissions.deny | index("Bash(rm -rf /)") != null' $S) == true && $(jq -r '.permissions.allow[0],.theme' $S | tr '\n' ,) == Read,dark, \
   && $(jq '.hooks.X[0]' $S) == 1 && $(jq '.sandbox.network.allowedDomains | index("hq.example") != null and index("api.anthropic.com") != null' $S) == true \
   && $(jq '[has("_tier"),has("_source")] | any' $S) == false && $(jq '.claudeMdExcludes | length > 0' $S) == true ]] \
  && ok "t1 new --tier executor renders deny/sandbox/allow/hooks/excludes" || bad "t1: $out $(<$S)"
[[ $(<$T/root/ex1/tier) == executor && $(tail -1 $T/root/ex1/tier.src) == "rendered $(shasum -a 256 < $S | cut -d' ' -f1)" \
   && $(wc -l < $T/root/ex1/tier.src) -eq 3 && $(sed -n 2p $T/root/ex1/tier.src) == "$(shasum -a 256 < $HQ/config/tiers/executor.json | cut -d' ' -f1) ${HQ:A}/config/tiers/executor.json" ]] \
  && ok "t2 tier + tier.src (input hashes, rendered hash)" || bad "t2: $(<$T/root/ex1/tier.src)"
W=$T/root/ex1/workspace/CLAUDE.md
[[ -f $W ]] && grep -q 'You are `ex1`' $W && ! grep -q '<profile>' $W && ! grep -q '<owner>' $W && grep -q 'accounts: `testowner`' $W && [[ -f $T/root/ex1/token ]] \
  && ok "t3 CLAUDE.md name + owner substituted (no <profile>/<owner> left), token written" || bad "t3"
# t3b: the renderer fails closed without CPROF_OWNER (unset, empty or malformed): no profile left behind, never a wildcard/empty default.
trun_own() { local -a oe; [[ $1 == UNSET ]] && oe=(-u CPROF_OWNER) || oe=(CPROF_OWNER=$1); shift
  env $CLEAN $oe HOME=$T/home CPROF_ROOT=$T/root CPROF_HQ_CONFIG=$HQ/config PATH=$T/bin:/usr/bin:/bin:/usr/local/bin:/opt/homebrew/bin \
  zsh -fc "source $SRC/cprof.zsh; $1" 2>&1 <<<tok; }
out=$(trun_own UNSET 'cprof new exno --tier executor; print RC=$?'); [[ $out == *"CPROF_OWNER is unset or empty"*"RC=1" && ! -e $T/root/exno ]] && ok "t3b CPROF_OWNER unset: render fails closed" || bad "t3b unset: $out"
out=$(trun_own '' 'cprof new exno --tier executor; print RC=$?'); [[ $out == *"CPROF_OWNER is unset or empty"*"RC=1" && ! -e $T/root/exno ]] && ok "t3c CPROF_OWNER empty: render fails closed" || bad "t3c empty: $out"
out=$(trun_own 'a/b;x' 'cprof new exno --tier executor; print RC=$?'); [[ $out == *"not a valid GitHub account name"*"RC=1" && ! -e $T/root/exno ]] && ok "t3d CPROF_OWNER malformed: render fails closed" || bad "t3d malformed: $out"
out=$(trun_own UNSET 'cprof new dkno --tier desk; print RC=$?'); [[ $out == *"RC=0" && -f $T/root/dkno/workspace/CLAUDE.md ]] && ! grep -q '<profile>\|<owner>' $T/root/dkno/workspace/CLAUDE.md && ok "t3e desk template needs no owner: renders without CPROF_OWNER" || bad "t3e desk: $out"
out=$(trun 'cprof new dk --tier desk'); S2=$T/root/dk/config/settings.json
[[ $(jq -r '.sandbox.enabled // "none"' $S2) == none && $(jq -r '.sandbox.filesystem // "none"' $S2) == none && $(<$T/root/dk/tier) == desk && $(jq '.permissions.deny | length' $S2) -gt 1 ]] \
  && ok "t4 desk: no sandbox, tier file" || bad "t4: $out $(<$S2)"
out=$(trun 'cprof new ov1 --tier executor --overlay example'); S3=$T/root/ov1/config/settings.json
[[ $(jq '.permissions.deny | (index("mcp__supabase") != null) and (index("WebFetch") != null)' $S3) == true \
   && $(jq -r '.sandbox.network.allowMachLookup' $S3) == true && $(grep -c overlays/example.json $T/root/ov1/tier.src) == 1 ]] \
  && ok "t5 overlay unions denies + allowMachLookup, listed in tier.src" || bad "t5: $out"
out=$(trun 'cprof new bad --tier root; print RC=$?'); [[ $out == *"unknown tier"*"RC=1" && ! -e $T/root/bad ]] && ok "t6 unknown tier refused" || bad "t6: $out"
out=$(trun 'cprof new bad --tier desk --overlay nope; print RC=$?'); [[ $out == *"missing render input"*"RC=1" && ! -e $T/root/bad ]] && ok "t6b missing overlay refused, no leftovers" || bad "t6b: $out"
out=$(trun 'cprof new plain; print RC=$?'); [[ $out == *"RC=0" && ! -e $T/root/plain/tier && ! -e $T/root/plain/tier.src ]] && ok "t7 new without --tier unchanged" || bad "t7: $out"

# launch
ACC='--settings '"'"'{"crossSessionInbound":"accept"}'"'"
out=$(trun 'cprof launch ex1 --dry-run -- -p hi')
[[ $out == *"exec claude --dangerously-skip-permissions $ACC -p hi"* && $out == *"CLAUDE_CODE_OAUTH_TOKEN=<token>"* && $out != *tok$'\n'* && $out == *"cd "*"/root/ex1/workspace"* ]] \
  && ok "t8 launch executor dry-run: skip flag, ACCEPT, token redacted" || bad "t8: $out"
out=$(trun 'cprof launch dk --dry-run -- --permission-mode auto')
[[ $out == *"exec claude --permission-mode auto $ACC --permission-mode auto"* ]] && ok "t9 launch desk dry-run: auto flag" || bad "t9: $out"
out=$(trun 'cprof launch ex1 --dry-run -- --permission-mode auto; print RC=$?'); [[ $out == *refused*"RC=2" && $out != *"dry-run:"* ]] && ok "t10 executor refuses --permission-mode" || bad "t10: $out"
out=$(trun 'cprof launch dk --dry-run -- --dangerously-skip-permissions; print RC=$?'); [[ $out == *refused*"RC=2" ]] && ok "t11 desk refuses skip flag" || bad "t11: $out"
out=$(trun 'cprof launch dk --dry-run -- --permission-mode bypassPermissions; print RC=$?'); [[ $out == *refused*"RC=2" ]] && ok "t11b desk refuses non-auto permission-mode" || bad "t11b: $out"
mkprof nt; out=$(trun 'cprof launch nt --dry-run; print RC=$?'); [[ $out == *"no tier file"*"RC=2" ]] && ok "t12 launch refuses profile without tier file" || bad "t12: $out"
# real exec path (stub claude): argv + env reach claude, token via env only
print -r -- '#!/bin/sh
echo "ARGV=$*" > "$STUBOUT"; echo "CFG=$CLAUDE_CONFIG_DIR TOK=$CLAUDE_CODE_OAUTH_TOKEN PWD=$(pwd)" >> "$STUBOUT"' > $T/bin/claude; chmod +x $T/bin/claude
trun "STUBOUT=$T/stub.out cprof launch ex1 -- -p hi; print RC=\$?" tok >/dev/null; export STUBOUT=$T/stub.out
out=$(env STUBOUT=$T/stub.out $=CLEAN HOME=$T/home CPROF_ROOT=$T/root PATH=$T/bin:/usr/bin:/bin zsh -fc "source $SRC/cprof.zsh; cprof launch ex1 -- -p hi" 2>&1 </dev/null); unset STUBOUT
[[ $(<$T/stub.out) == *'ARGV=--dangerously-skip-permissions --settings {"crossSessionInbound":"accept"} -p hi'*"CFG=$T/root/ex1/config"* ]] \
  && ok "t13 launch execs claude in subshell with tier flag" || bad "t13: $out $(<$T/stub.out)"

# sync
print -r -- '{"hand":"edit"}' > $S; rm -f $T/root/ex1/tier.src.bak
out=$(trun 'cprof sync ex1; print RC=$?'); [[ $out == *"hand-edited since last render"*"RC=3" && $(jq -r .hand $S) == edit ]] && ok "t14 sync refuses after hand edit (exit 3)" || bad "t14: $out"
out=$(trun 'cprof sync ex1 --force; print RC=$?')
[[ $out == *"re-rendered"*"RC=0" && $(jq -r '.hand // "gone"' $S) == gone && $(jq -r '.sandbox.enabled' $S) == true \
   && $(tail -1 $T/root/ex1/tier.src) == "rendered $(shasum -a 256 < $S | cut -d' ' -f1)" ]] && ok "t15 sync --force re-renders, rewrites tier.src" || bad "t15: $out"
out=$(trun 'cprof sync ex1; print RC=$?'); [[ $out == *"RC=0" ]] && ok "t15b sync on clean render succeeds" || bad "t15b: $out"
jq '.skipDangerousModePermissionPrompt = false | .claudeMdExcludes += ["/keep/me"]' $S > $S.n && mv $S.n $S
out=$(trun 'cprof doctor --no-claude'); [[ $out == *"WARN: executor needs skipDangerousModePermissionPrompt=true (is false)"* ]] && ok "t16a doctor WARNs when executor skip key is not true (F1)" || bad "t16a: $out"
trun 'cprof sync ex1 --force' >/dev/null
[[ $(jq -r '.skipDangerousModePermissionPrompt' $S) == true && $(jq '.claudeMdExcludes | index("/keep/me") != null' $S) == true ]] \
  && ok "t16 sync --force: executor skip key = fragment true (F1), claudeMdExcludes kept" || bad "t16: $(<$S)"
jq 'del(.skipDangerousModePermissionPrompt)' $S2 > $S2.n && mv $S2.n $S2; trun 'cprof sync dk --force' >/dev/null
[[ $(jq 'has("skipDangerousModePermissionPrompt")' $S2) == false ]] && ok "t16c desk omits the skip key unless present" || bad "t16c"
jq '.skipDangerousModePermissionPrompt = true' $S2 > $S2.n && mv $S2.n $S2; trun 'cprof sync dk --force' >/dev/null
[[ $(jq '.skipDangerousModePermissionPrompt' $S2) == true ]] && ok "t16d desk keeps an existing skip key" || bad "t16d"
# M2: --force backs up hand edits
jq '.permissions.deny += ["Bash(hand-added)"]' $S > $S.n && mv $S.n $S
out=$(trun 'cprof sync ex1; print RC=$?'); [[ $out == *"discards ALL hand edits except claudeMdExcludes (a backup is written)"*"RC=3" ]] && ok "t16e refusal text names the discard + backup" || bad "t16e: $out"
out=$(trun 'cprof sync ex1 --force; print RC=$?'); B=(${(f)"$(ls $T/root/ex1/config/settings.json.bak-* 2>/dev/null)"})
[[ $out == *"backup: $T/root/ex1/config/settings.json.bak-"*"RC=0" && $#B -ge 1 && $(stat -f %Lp $B[-1]) == 600 \
   && $(jq '.permissions.deny | index("Bash(hand-added)") != null' $B[-1]) == true && $(jq '.permissions.deny | index("Bash(hand-added)") != null' $S) == false \
   && $B[-1] =~ 'bak-[0-9]{8}T[0-9]{6}Z$' ]] && ok "t16f sync --force writes .bak-<stamp> (600) holding the hand edit; render drops it (M2)" || bad "t16f: $out $B"
trun 'cprof sync ov1' >/dev/null; [[ $(jq '.permissions.deny | index("mcp__supabase") != null' $S3) == true ]] && ok "t16b sync keeps the overlay" || bad "t16b"

# doctor tier rows
out=$(trun 'cprof doctor --no-claude')
[[ $out == *"ex1: tier=executor; render matches; launch=--dangerously-skip-permissions"*"ok: deny="*"sandbox.enabled=true"* && $out == *"dk: tier=desk; render matches; launch=--permission-mode auto"* ]] \
  && ok "t17 doctor tier rows" || bad "t17: $out"
jq '.sandbox.enabled = false' $S > $S.n && mv $S.n $S
out=$(trun 'cprof doctor --no-claude'); [[ $out == *"ex1: tier=executor; render MISMATCH"*"WARN: executor needs deny"* ]] && ok "t18 doctor flags MISMATCH + weak executor" || bad "t18: $out"

# M1: launch strips profile.env overrides (higher-precedence auth vars, auto-memory); use honours them
print -r -- 'ANTHROPIC_API_KEY=leak
CLAUDE_CODE_DISABLE_AUTO_MEMORY=0
CLAUDE_CODE_USE_BEDROCK=1' > $T/root/ex1/profile.env
print -r -- '#!/bin/sh
echo "AK=${ANTHROPIC_API_KEY-unset} AM=$CLAUDE_CODE_DISABLE_AUTO_MEMORY BR=${CLAUDE_CODE_USE_BEDROCK-unset}" > "$STUBOUT"' > $T/bin/claude
out=$(env $CLEAN STUBOUT=$T/stub2.out HOME=$T/home CPROF_ROOT=$T/root PATH=$T/bin:/usr/bin:/bin zsh -fc "source $SRC/cprof.zsh; cprof launch ex1" 2>&1 </dev/null)
d1=$(trun 'cprof launch ex1 --dry-run')
[[ $(<$T/stub2.out) == "AK=unset AM=1 BR=unset" && $d1 == *"CLAUDE_CODE_DISABLE_AUTO_MEMORY=1"* && $d1 != *leak* ]] \
  && ok "t16g launch strips profile.env API key / USE_* / auto-memory override (M1)" || bad "t16g: $out $(<$T/stub2.out) $d1"
out=$(trun 'cprof use ex1 >/dev/null; print -r -- "AK=$ANTHROPIC_API_KEY AM=$CLAUDE_CODE_DISABLE_AUTO_MEMORY"'); [[ $out == *"AK=leak AM=0"* ]] && ok "t16h use honours profile.env (documented divergence)" || bad "t16h: $out"
rm -f $T/root/ex1/profile.env

# A9: doctor without jq says so
mkdir -p $T/nobin
out=$(env $CLEAN HOME=$T/home CPROF_ROOT=$T/root PATH=$T/nobin ${commands[zsh]:-/bin/zsh} -fc "source $SRC/cprof.zsh; cprof doctor --no-claude" 2>&1 </dev/null)
[[ $out == *"WARN: tier rows skipped: jq not installed"* ]] && ok "t16i doctor WARNs when jq is absent (A9)" || bad "t16i: $out"

# trust
L=$T/root/_trust/ledger.jsonl
out=$(trun 'cprof trust ls'); [[ $out == "(no ledger at "* ]] && ok "t19 trust ls with no ledger" || bad "t19: $out"
out=$(trun 'cprof trust baseline --note "owner ruling test"; print RC=$?')
[[ $out == *"RC=0" && $(wc -l < $L) -eq 1 && $(jq -r '[.kind,.by,.note]|join("|")' $L) == "BASELINE|owner|owner ruling test" && $(stat -f %Lp $L) == 600 && $(stat -f %Lp $T/root/_trust) == 700 ]] \
  && ok "t20 trust baseline writes one row (600/700)" || bad "t20: $out"
out=$(trun 'cprof trust baseline; print RC=$?'); [[ $out == *"already exists"*"RC=4" && $(wc -l < $L) -eq 1 ]] && ok "t21 second baseline refused (exit 4)" || bad "t21: $out"
print -r -- '{"ts":"2026-10-14T21:00:00Z","kind":"DEP","name":"left-pad","version":"1.3.0","verdict":"INSTALLED","by":"desk"}' >> $L
out=$(trun 'cprof trust ls'); [[ $out == *"BASELINE - - owner"* && $out == *"2026-10-14T21:00:00Z DEP left-pad@1.3.0 INSTALLED desk"* ]] && ok "t22 trust ls pretty-prints rows" || bad "t22: $out"
printf '%s\n' '{"ts":"2026-10-14T22:00:00Z","kind":"DEP","name":"ev\u001b[2Jil","version":"1","verdict":"INSTALLED","by":"desk"}' 'not json at all' >> $L
out=$(trun 'cprof trust ls'); n=$(print -r -- "$out" | grep -c $'\x1b')
[[ $n -eq 0 && $out == *"ev?[2Jil@1"* && $out == *"UNPARSEABLE line 4"* ]] && ok "t22b trust ls strips control chars, flags unparseable rows (M3)" || bad "t22b: n=$n $out"
out=$(trun 'cprof help'); [[ $out == *"cprof launch"* && $out == *"cprof sync"* && $out == *"cprof trust"* && $out == *"--tier"* ]] && ok "t23 help documents tier verbs" || bad "t23"

# ---- launch staleness (architecture/claude-profile.md Extension G): stale tier.src -> re-render / warn / abort at launch.
lrun() { rm -f $T/lstub.out; env $CLEAN STUBOUT=$T/lstub.out HOME=$T/home CPROF_ROOT=$T/root CPROF_HQ_CONFIG=$HQ/config PATH=$T/bin:/usr/bin:/bin:/usr/local/bin:/opt/homebrew/bin \
         zsh -fc "source $SRC/cprof.zsh; $1; print RC=\$?" 2>&1 </dev/null; }
print -r -- '#!/bin/sh
echo RAN > "$STUBOUT"' > $T/bin/claude; chmod +x $T/bin/claude
for p in lc1 lc2 lc4 lc5; do trun "cprof new $p --tier executor" >/dev/null; done; trun 'cprof new lc3 --tier desk --overlay example' >/dev/null
out=$(lrun 'cprof launch lc1')
[[ $out == "RC=0" && -f $T/lstub.out ]] && ok "t24 fresh render: no output, claude ran" || bad "t24: $out"
jq '.hand = "edit"' $T/root/lc2/config/settings.json > $T/n.json && mv $T/n.json $T/root/lc2/config/settings.json
rm -f $T/root/lc4/tier.src
jq '.permissions.deny += ["Bash(newly-denied)"]' $HQ/config/settings.json > $T/n.json && mv $T/n.json $HQ/config/settings.json
S1=$T/root/lc1/config/settings.json
out=$(lrun 'cprof launch lc1'); B=($T/root/lc1/config/settings.json.bak-*(N))
[[ $out == *"cprof: 'lc1' render was stale ("*"settings.json"*"); re-rendered (backup: $T/root/lc1/config/settings.json.bak-"*")"*"RC=0" && -f $T/lstub.out && $#B == 1 && $(stat -f %Lp $B[1]) == 600 \
   && $(jq '.permissions.deny | index("Bash(newly-denied)") != null' $S1) == true && $(tail -1 $T/root/lc1/tier.src) == "rendered $(shasum -a 256 < $S1 | cut -d' ' -f1)" \
   && $(sed -n 1p $T/root/lc1/tier.src) == "$(shasum -a 256 < $HQ/config/settings.json | cut -d' ' -f1) ${HQ:A}/config/settings.json" ]] \
  && ok "t25 stale+clean: backup (600), re-render, tier.src rewritten, one line, claude ran" || bad "t25: $out"
out=$(lrun 'cprof launch lc1'); [[ $out == "RC=0" && -f $T/lstub.out ]] && ok "t25b launch after re-render is silent" || bad "t25b: $out"
H2=$(shasum -a 256 < $T/root/lc2/config/settings.json)
out=$(lrun 'cprof launch lc2'); B2=($T/root/lc2/config/settings.json.bak-*(N))
[[ $out == *"hand-edited since last render"*"-- not re-rendered; launching on the current file"*"RC=0" && -f $T/lstub.out && $(shasum -a 256 < $T/root/lc2/config/settings.json) == $H2 \
   && $#B2 == 0 ]] \
  && ok "t26 stale+hand-edited: sync's exit-3 text, not re-rendered, no write, claude ran" || bad "t26: $out"
mv $HQ/config/tiers/overlays/example.json $T/example.away; H3=$(shasum -a 256 < $T/root/lc3/config/settings.json)
out=$(lrun 'cprof launch lc3'); mv $T/example.away $HQ/config/tiers/overlays/example.json
[[ $out == *"cprof: 'lc3' re-render failed; not launching (a stale executor could be missing a deny)"*"RC=1" && ! -f $T/lstub.out && $(shasum -a 256 < $T/root/lc3/config/settings.json) == $H3 ]] \
  && ok "t27 stale+render fails: abort exit 1, claude NOT run, settings untouched" || bad "t27: $out"
out=$(lrun 'cprof launch lc4')
[[ $out == *"cprof: WARN 'lc4' has no tier.src; staleness not checked"*"RC=0" && -f $T/lstub.out ]] && ok "t28 no tier.src: WARN, claude ran" || bad "t28: $out"
H5=$(shasum -a 256 < $T/root/lc5/config/settings.json)
out=$(lrun 'cprof launch lc5 --dry-run'); B5=($T/root/lc5/config/settings.json.bak-*(N))
[[ $out == *"dry-run: render stale ("*"settings.json"*"); would re-render"*"RC=0" && ! -f $T/lstub.out && $(shasum -a 256 < $T/root/lc5/config/settings.json) == $H5 \
   && $#B5 == 0 ]] \
  && ok "t29 --dry-run + stale: nothing written, dry-run line, claude not run" || bad "t29: $out"

(( fails )) && { print "$fails failure(s)"; exit 1; }
exit 0
