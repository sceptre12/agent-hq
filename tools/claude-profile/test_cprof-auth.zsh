#!/usr/bin/env zsh
# tools/claude-profile/test_cprof-auth.zsh — tests for cprof's `--auth oauth|bedrock` (cprof-auth.zsh + the auth paths in
# cprof.zsh, cprof-tiers.zsh render/stale/launch/sync and cprof-checks.zsh doctor). Contract: architecture/claude-profile.md,
# Extension 2026-10-26. Hermetic: HOME and CPROF_ROOT live in a mktemp dir, zsh -f skips the user's config, a fake hq tree
# is used via CPROF_HQ_CONFIG, and real claude is never run (stub on PATH). Every cprof-managed var and every AWS/region var
# the code reads is unset in each child, so the result does not depend on the caller's profile or AWS shell state.
SRC=${0:A:h}
_TRK=(${(f)"$(zsh -fc "source $SRC/cprof.zsh; print -l \${_CPROF_TRACKED:#PS1}" 2>/dev/null)"}); CLEAN=()
for _v in $_TRK AWS_REGION AWS_DEFAULT_REGION AWS_PROFILE CPROF_SSO_REGION CPROF_OWNER; do CLEAN+=(-u $_v); done
_tb=${TMPDIR:-/tmp}; T=$(mktemp -d "${_tb%/}/test_cprof-auth.XXXXXX") || exit 1
trap 'chmod -R u+rwx "$T" 2>/dev/null; rm -rf "$T"' EXIT
mkdir -p $T/bin $T/home $T/root
command -v jq >/dev/null || { print -r -- "FAIL: jq required (these tests cannot run without it)"; exit 1; }
fails=0
ok()  { print -r -- "ok   $1"; }
bad() { print -r -- "FAIL $1"; fails=$((fails+1)); }

# Fake hq tree (same shape as test_cprof.zsh): real tier fragments + templates, a small hq settings.json.
REPO=${SRC:h:h}; HQ=$T/hq
mkdir -p $HQ/config/tiers $HQ/tools/claude-profile
cp -R $REPO/config/tiers/. $HQ/config/tiers/; cp -R $REPO/tools/claude-profile/templates $HQ/tools/claude-profile/
print -r -- '{"theme":"dark","permissions":{"allow":["Read"],"deny":["Bash(rm -rf /)"]},"sandbox":{"network":{"allowedDomains":["hq.example"]}}}' > $HQ/config/settings.json
print -r -- tok > $T/tok

# R [VAR=val ...] '<zsh code>': runs after sourcing cprof.zsh in a clean child; stdin is $RIN (default /dev/null).
R() { local -a e; while (( $# > 1 )) && [[ $1 =~ '^[A-Za-z_][A-Za-z0-9_]*=' ]]; do e+=($1); shift; done
  env $CLEAN CPROF_OWNER=testowner HOME=$T/home CPROF_ROOT=$T/root CPROF_HQ_CONFIG=$HQ/config \
      PATH=$T/bin:/usr/bin:/bin:/usr/local/bin:/opt/homebrew/bin $e zsh -fc "source $SRC/cprof.zsh; $1" 2>&1 <${RIN:-/dev/null}; }
print -r -- '#!/bin/sh
echo "BR=${CLAUDE_CODE_USE_BEDROCK-unset} AK=${ANTHROPIC_API_KEY-unset} TOK=${CLAUDE_CODE_OAUTH_TOKEN-unset} AP=${AWS_PROFILE-unset} CFG=$CLAUDE_CONFIG_DIR" > "$STUBOUT"' > $T/bin/claude
chmod +x $T/bin/claude
P=$T/root

# ---- new / ls / token
out=$(R 'cprof new b1 --auth bedrock; print RC=$?; cprof ls')
[[ $out == *"created profile 'b1'"*"(auth: bedrock, no token; AWS credentials come from your shell)"*"RC=0"* && $(<$P/b1/auth) == bedrock \
   && $(stat -f %Lp $P/b1/auth) == 600 && ! -e $P/b1/token && $out == *"b1  [bedrock]"* ]] \
  && ok "a1 new --auth bedrock: auth file (600), no token, success line, ls [bedrock]" || bad "a1: $out"
out=$(R 'cprof new bx --auth nope; print RC=$?')
[[ $out == *"unknown auth mode: 'nope' (oauth|bedrock)"*"RC=1" && ! -e $P/bx ]] && ok "a2 unknown auth mode refused, no dir" || bad "a2: $out"
out=$(R 'cprof new bx --auth; print RC=$?'); [[ $out == *"RC=1" && ! -e $P/bx ]] && ok "a2b --auth without value refused" || bad "a2b: $out"

# ---- use / off
out=$(R AWS_REGION=us-east-1 'export ANTHROPIC_API_KEY=leak CLAUDE_CODE_OAUTH_TOKEN=x CLAUDE_CODE_USE_VERTEX=1
  cprof use b1 >/dev/null
  print -r -- "IN BR=${CLAUDE_CODE_USE_BEDROCK-u} OT=${+CLAUDE_CODE_OAUTH_TOKEN} AK=${+ANTHROPIC_API_KEY} VX=${+CLAUDE_CODE_USE_VERTEX} CFG=$CLAUDE_CONFIG_DIR PWD=$PWD"
  cprof off >/dev/null
  print -r -- "OUT AK=$ANTHROPIC_API_KEY/${parameters[ANTHROPIC_API_KEY]} OT=$CLAUDE_CODE_OAUTH_TOKEN/${parameters[CLAUDE_CODE_OAUTH_TOKEN]} VX=$CLAUDE_CODE_USE_VERTEX/${parameters[CLAUDE_CODE_USE_VERTEX]} BR=${+CLAUDE_CODE_USE_BEDROCK} CFG=${+CLAUDE_CONFIG_DIR}"')
[[ $out == *"IN BR=1 OT=0 AK=0 VX=0 CFG=$P/b1/config PWD="*"/root/b1/workspace"* \
   && $out == *"OUT AK=leak/scalar-export OT=x/scalar-export VX=1/scalar-export BR=0 CFG=0"* ]] \
  && ok "a3 use strips Anthropic/Vertex vars, sets USE_BEDROCK; off restores exactly" || bad "a3: $out"
out=$(R 'cprof use b1 2>&1 >/dev/null; print RC=$?')
[[ $out == *"WARN: no AWS_REGION"*"RC=0" ]] && ok "a3b use without AWS_REGION: WARN on stderr, RC 0" || bad "a3b: $out"
out=$(R 'export AWS_PROFILE=dev AWS_REGION=eu-west-1; cprof use b1 2>&1 >/dev/null; print -r -- "IN $AWS_PROFILE $AWS_REGION"
  cprof off >/dev/null; print -r -- "OUT $AWS_PROFILE/${parameters[AWS_PROFILE]} $AWS_REGION/${parameters[AWS_REGION]}"')
[[ $out == "IN dev eu-west-1"$'\n'"OUT dev/scalar-export eu-west-1/scalar-export" ]] && ok "a3c AWS_PROFILE/AWS_REGION pass through use and off untouched" || bad "a3c: $out"
out=$(R 'cprof token b1; print RC=$?')
[[ $out == *"'b1' uses --auth bedrock; it has no token"*"RC=1" ]] && ok "a4 token refused on a bedrock profile" || bad "a4: $out"
out=$(RIN=$T/tok R 'cprof new o1; print RC=$?; cprof ls')
[[ $out == *"RC=0"* && $(<$P/o1/token) == tok && ! -e $P/o1/auth && $out == *"o1  [token]"* && $out != *"auth: bedrock"* ]] \
  && ok "a5 oauth profile unchanged: token written, no auth file, ls [token]" || bad "a5: $out"

# ---- tiered render
sha() { shasum -a 256 < $1 | cut -d' ' -f1; }
doms() { jq -r '.sandbox.network.allowedDomains[]' $1 2>/dev/null; }
out=$(R AWS_REGION=us-east-1 'cprof new e1 --auth bedrock --tier executor; print RC=$?'); S=$P/e1/config/settings.json; D=$(doms $S); miss=
for h in bedrock-runtime.us-east-1.amazonaws.com bedrock.us-east-1.amazonaws.com sts.us-east-1.amazonaws.com sts.amazonaws.com \
         sso.us-east-1.amazonaws.com oidc.us-east-1.amazonaws.com portal.sso.us-east-1.amazonaws.com api.anthropic.com hq.example; do
  (( ${${(f)D}[(Ie)$h]} )) || miss+=" $h"
done
TS=$P/e1/tier.src
[[ $out == *"RC=0" && -z $miss && $(jq 'has("_auth")' $S) == false && $(wc -l < $TS) -eq 5 && $(sed -n 3p $TS) == "$(sha $HQ/config/tiers/auth-bedrock.json) ${HQ:A}/config/tiers/auth-bedrock.json" \
   && $(sed -n 4p $TS) == "region us-east-1" && $(sed -n 5p $TS) == "rendered $(sha $S)" && $(<$P/e1/auth) == bedrock ]] \
  && ok "a6 bedrock executor render: AWS hosts + base hosts, no _auth, tier.src 3 inputs + region + rendered" || bad "a6: $out miss=[$miss] $(<$TS)"
out=$(R AWS_REGION=us-east-1 CPROF_SSO_REGION=us-west-2 'cprof new e2 --auth bedrock --tier executor; print RC=$?'); D=$(doms $P/e2/config/settings.json); miss=
for h in bedrock-runtime.us-east-1.amazonaws.com bedrock.us-east-1.amazonaws.com sso.us-west-2.amazonaws.com oidc.us-west-2.amazonaws.com portal.sso.us-west-2.amazonaws.com; do
  (( ${${(f)D}[(Ie)$h]} )) || miss+=" $h"; done
[[ $out == *"RC=0" && -z $miss && $D != *sso.us-east-1* && $D != *oidc.us-east-1* && $(sed -n 4p $P/e2/tier.src) == "region us-east-1 sso=us-west-2" ]] \
  && ok "a6b CPROF_SSO_REGION: SSO hosts on us-west-2, Bedrock hosts on us-east-1, tier.src sso=" || bad "a6b: $out miss=[$miss]"
out=$(R 'cprof new e3 --auth bedrock --tier executor; print RC=$?')
[[ $out == *"is not a region id"*"RC=1" && ! -e $P/e3 ]] && ok "a6c no region: render refused, no profile left" || bad "a6c: $out"
out=$(R AWS_REGION=bogus 'cprof new e3 --auth bedrock --tier executor; print RC=$?')
[[ $out == *"AWS region 'bogus' is not a region id"*"RC=1" && ! -e $P/e3 ]] && ok "a6d AWS_REGION=bogus: render refused, no profile left" || bad "a6d: $out"
out=$(R AWS_REGION=us-east-1 'cprof new d1 --auth bedrock --tier desk; print RC=$?'); S2=$P/d1/config/settings.json
[[ $out == *"RC=0" && $(jq -r '.sandbox.enabled // "none"' $S2) == none && $(<$P/d1/auth) == bedrock && $(<$P/d1/tier) == desk \
   && $(doms $S2) == *bedrock-runtime.us-east-1.amazonaws.com* ]] && ok "a6e desk + bedrock renders (no sandbox.enabled), auth file present" || bad "a6e: $out"
out=$(R AWS_REGION=us-east-1 CPROF_SSO_REGION='a/b&c' 'cprof new e4 --auth bedrock --tier executor; print RC=$?')
[[ $out == *"CPROF_SSO_REGION 'a/b&c' is not a region id"*"RC=1" && ! -e $P/e4 ]] && ok "a6f CPROF_SSO_REGION='a/b&c' refused, no profile left" || bad "a6f: $out"
out=$(R AWS_REGION=us-east-1 CPROF_SSO_REGION='*' 'cprof new e4 --auth bedrock --tier executor; print RC=$?')
[[ $out == *"CPROF_SSO_REGION"*"RC=1" && ! -e $P/e4 ]] && ok "a6g CPROF_SSO_REGION='*' refused, no profile left" || bad "a6g: $out"
# a6h: an invalid auth fragment must write nothing (new: no profile; sync of an existing profile: settings.json unchanged).
HB=$T/hqbad; cp -R $HQ $HB; head -c 40 $HQ/config/tiers/auth-bedrock.json > $HB/config/tiers/auth-bedrock.json; h0=$(sha $S)
out=$(R AWS_REGION=us-east-1 CPROF_HQ_CONFIG=$HB/config 'cprof new e4 --auth bedrock --tier executor; print RC=$?; cprof sync e1 --force; print RC=$?')
[[ $out == *"RC=1"*"RC=1" && ! -e $P/e4 && $(sha $S) == $h0 && $(tail -1 $P/e1/tier.src) == "rendered $h0" ]] \
  && ok "a6h invalid fragment: nothing written (no new profile, e1 settings.json unchanged)" || bad "a6h: $out"

# ---- launch
out=$(R AWS_REGION=us-east-1 'cprof launch e1 --dry-run; print RC=$?')
[[ $out == *"dry-run env: "*"CLAUDE_CODE_USE_BEDROCK=1 AWS_REGION=us-east-1"* && $out != *CLAUDE_CODE_OAUTH_TOKEN* && $out == *"exec claude --dangerously-skip-permissions"*"RC=0" \
   && $out != *stale* ]] && ok "a7 launch --dry-run: bedrock env line, no token, skip flag" || bad "a7: $out"
print -r -- 'ANTHROPIC_API_KEY=leak
AWS_PROFILE=team' > $P/e1/profile.env
out=$(R AWS_REGION=us-east-1 STUBOUT=$T/stub.out 'cprof launch e1; print RC=$?'); rm -f $P/e1/profile.env
[[ $out == *"RC=0" && $(<$T/stub.out) == "BR=1 AK=unset TOK=unset AP=team CFG=$P/e1/config" ]] \
  && ok "a8 launch: claude sees USE_BEDROCK=1, no API key/token, profile.env AWS_PROFILE, CFG" || bad "a8: $out $(<$T/stub.out 2>/dev/null)"

# ---- region change -> stale -> re-render at launch / sync
R AWS_REGION=us-east-1 'cprof new e9 --auth bedrock --tier executor' >/dev/null; S9=$P/e9/config/settings.json
out=$(R AWS_REGION=eu-central-1 STUBOUT=$T/stub9.out 'cprof launch e9; print RC=$?'); B=($P/e9/config/settings.json.bak-*(N))
[[ $out == *"'e9' render was stale ("*"); re-rendered (backup: $P/e9/config/settings.json.bak-"*"RC=0" && -f $T/stub9.out \
   && $(doms $S9) == *bedrock-runtime.eu-central-1.amazonaws.com* && $(doms $S9) != *bedrock-runtime.us-east-1* \
   && $(sed -n 4p $P/e9/tier.src) == "region eu-central-1" && $(tail -1 $P/e9/tier.src) == "rendered $(sha $S9)" \
   && $#B == 1 && $(stat -f %Lp $B[1]) == 600 ]] \
  && ok "a9 region change at launch: stale, re-rendered for eu-central-1, tier.src updated, backup 600" || bad "a9: $out"
# The changed-inputs list must name "region" (impl-notes contract), not just the new region value.
[[ $out == *"render was stale (region"* ]] && ok "a9a stale message names 'region'" || bad "a9a stale list does not name 'region': $out"
out=$(R AWS_REGION=eu-central-1 STUBOUT=$T/stub9.out 'cprof launch e9; print RC=$?')
[[ $out == "RC=0" ]] && ok "a9b launch again, same region: silent" || bad "a9b: $out"
out=$(R AWS_REGION=ap-southeast-2 'cprof sync e9; print RC=$?')
[[ $out == *"re-rendered 'e9'"*"RC=0" && $(sed -n 4p $P/e9/tier.src) == "region ap-southeast-2" && $(doms $S9) == *bedrock-runtime.ap-southeast-2.amazonaws.com* ]] \
  && ok "a10 sync after region change re-renders, tier.src region updated" || bad "a10: $out"

# ---- doctor
RIN=$T/tok R 'cprof new o2 --tier executor' >/dev/null
out=$(R AWS_REGION=us-east-1 'cprof doctor --no-claude')
[[ $out == *"e1: tier=executor; auth=bedrock; render "* && $out == *"o2: tier=executor; render "* && $out != *"o2: tier=executor; auth="* ]] \
  && ok "a11 doctor tier row: '; auth=bedrock' only on bedrock profiles" || bad "a11: $out"
out=$(R AWS_REGION=us-east-1 'cprof use b1 >/dev/null; cprof doctor --no-claude')
[[ $out == *"ok: CLAUDE_CODE_USE_BEDROCK=1 (active profile uses --auth bedrock)"* && $out != *"WARN: CLAUDE_CODE_USE_BEDROCK is set"* ]] \
  && ok "a12 doctor with active bedrock profile: USE_BEDROCK=1 is ok" || bad "a12: $out"

# ---- help + file length
out=$(R 'cprof help'); [[ $out == *"--auth oauth|bedrock"* ]] && ok "a13 help documents --auth oauth|bedrock" || bad "a13"
long=(); for f in $SRC/cprof*.zsh; do (( $(wc -l < $f) <= 300 )) || long+=(${f:t}); done
(( $#long == 0 )) && ok "a14 every cprof*.zsh <= 300 lines" || bad "a14 over 300 lines: $long"

(( fails )) && { print "$fails failure(s)"; exit 1; }
exit 0
