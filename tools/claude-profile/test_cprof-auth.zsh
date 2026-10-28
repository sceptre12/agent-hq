#!/usr/bin/env zsh
# tools/claude-profile/test_cprof-auth.zsh — tests for cprof's `--auth oauth|bedrock` (cprof-auth.zsh + the auth paths in
# cprof.zsh, cprof-tiers.zsh render/stale/launch/sync and cprof-checks.zsh doctor). Contract: architecture/claude-profile-02.md,
# Extension 2026-10-26 and Extension 2026-10-27 (profile.env snapshot + precedence + doctor). Hermetic: HOME and CPROF_ROOT
# live in a mktemp dir, zsh -f skips the user's config, a fake hq tree is used via CPROF_HQ_CONFIG, and real claude is never
# run (stub on PATH). Every cprof-managed var and every AWS/region/model var the code reads is unset in each child, so the
# result does not depend on the caller's profile or AWS shell state. Both snapshot halves (cprof-auth.zsh
# _CPROF_BEDROCK_SNAPSHOT_VARS and _CPROF_BEDROCK_SNAPSHOT_ANTHROPIC_VARS) are explicit allowlists, not a glob/pattern
# scan, so this CLEAN list below is deliberately kept byte-for-byte identical to that second array: ANTHROPIC_MODEL and
# every current ANTHROPIC_DEFAULT_<alias>_MODEL pin (opus/sonnet/haiku/fable), cleared so a real Bedrock-backed shell
# running these tests can't leak its own model ids in.
SRC=${0:A:h}
_TRK=(${(f)"$(zsh -fc "source $SRC/cprof.zsh; print -l \${_CPROF_TRACKED:#PS1}" 2>/dev/null)"}); CLEAN=()
for _v in $_TRK AWS_REGION AWS_DEFAULT_REGION AWS_PROFILE CPROF_SSO_REGION CPROF_OWNER \
  ANTHROPIC_MODEL ANTHROPIC_DEFAULT_OPUS_MODEL ANTHROPIC_DEFAULT_SONNET_MODEL ANTHROPIC_DEFAULT_HAIKU_MODEL \
  ANTHROPIC_DEFAULT_FABLE_MODEL; do CLEAN+=(-u $_v); done
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

# ---- self-contained profile.env snapshot at `new --auth bedrock` (architecture/claude-profile-02.md Extension 2026-10-27)
out=$(R AWS_PROFILE=snaptest AWS_REGION=us-west-2 ANTHROPIC_MODEL=sonnet-x ANTHROPIC_DEFAULT_OPUS_MODEL=opus-x \
  ANTHROPIC_DEFAULT_FABLE_MODEL=fable-x 'cprof new bsnap --auth bedrock; print RC=$?')
C=$(<$P/bsnap/profile.env 2>/dev/null)
[[ $out == *"RC=0" && -f $P/bsnap/profile.env && $(stat -f %Lp $P/bsnap/profile.env) == 600 \
   && $C == *"AWS_PROFILE='snaptest'"* && $C == *"AWS_REGION='us-west-2'"* && $C == *"ANTHROPIC_MODEL='sonnet-x'"* \
   && $C == *"ANTHROPIC_DEFAULT_OPUS_MODEL='opus-x'"* && $C == *"ANTHROPIC_DEFAULT_FABLE_MODEL='fable-x'"* ]] \
  && ok "a15 new --auth bedrock snapshots AWS_PROFILE/AWS_REGION/ANTHROPIC_MODEL/ANTHROPIC_DEFAULT_*_MODEL (incl. fable) via explicit allowlists into profile.env (600)" || bad "a15: $out C=[$C]"
out=$(R AWS_REGION=us-west-2 'cprof new bnoap --auth bedrock; print RC=$?'); C=$(<$P/bnoap/profile.env 2>/dev/null)
[[ $out == *"WARN: no AWS_PROFILE in this shell to snapshot"*"RC=0" && -f $P/bnoap/profile.env \
   && $C != *AWS_PROFILE* && $C == *"AWS_REGION='us-west-2'"* ]] \
  && ok "a16 new --auth bedrock with no AWS_PROFILE: WARN, profile.env written without it" || bad "a16: $out C=[$C]"
out=$(R 'cprof new bnone --auth bedrock; print RC=$?')
[[ $out == *"WARN: no AWS_PROFILE in this shell to snapshot"*"RC=0" && ! -e $P/bnone/profile.env ]] \
  && ok "a17 new --auth bedrock with nothing to snapshot: WARN, no profile.env written at all" || bad "a17: $out"

# ---- profile.env's AWS_PROFILE (snapshotted at creation) wins over a conflicting ambient AWS_PROFILE (the
# real xTest bug this closes: a stray already-exported AWS_PROFILE must never leak into a bedrock profile)
R AWS_REGION=us-east-1 AWS_PROFILE=fromfile 'cprof new eprec --auth bedrock --tier executor' >/dev/null
out=$(R AWS_PROFILE=ambient AWS_REGION=us-east-1 'cprof use eprec >/dev/null; print -r -- "IN AWS_PROFILE=$AWS_PROFILE"; cprof off >/dev/null')
[[ $out == "IN AWS_PROFILE=fromfile" ]] \
  && ok "a18 profile.env AWS_PROFILE overrides a conflicting ambient AWS_PROFILE on use" || bad "a18: $out"
out=$(R AWS_PROFILE=ambient AWS_REGION=us-east-1 STUBOUT=$T/stub18.out 'cprof launch eprec; print RC=$?')
[[ $out == *"RC=0" && $(<$T/stub18.out) == *"AP=fromfile"* ]] \
  && ok "a19 profile.env AWS_PROFILE overrides a conflicting ambient AWS_PROFILE on launch too" || bad "a19: $out $(<$T/stub18.out 2>/dev/null)"

# ---- doctor: bedrock profiles missing profile.env / missing AWS_PROFILE in it
out=$(R 'cprof doctor --no-claude')
[[ $out == *"WARN: bnone has no profile.env"* ]] && ok "a20 doctor warns on a bedrock profile with no profile.env" || bad "a20: $out"
[[ $out == *"WARN: bnoap has profile.env but no AWS_PROFILE in it"* ]] \
  && ok "a20b doctor warns when profile.env exists but lacks AWS_PROFILE" || bad "a20b: $out"
[[ $out != *"WARN: bsnap has"* && $out != *"WARN: eprec has"* ]] \
  && ok "a20c doctor does not warn on bedrock profiles with AWS_PROFILE in profile.env" || bad "a20c: $out"

# ---- doctor: cross-check profile.env's AWS_PROFILE against 'aws configure list-profiles' when aws is on PATH
# (fix-up pass M1). A fake 'aws' stub on its own PATH entry keeps this hermetic in both directions: present with
# the profile listed, present without it, and genuinely absent (restricted PATH, no homebrew/local bin dirs).
mkdir -p $T/awsbin
print -r -- '#!/bin/sh
[ "$1" = "configure" ] && [ "$2" = "list-profiles" ] && printf "fromfile\nother-profile\n"' > $T/awsbin/aws
chmod +x $T/awsbin/aws
AWSPATH="$T/awsbin:$T/bin:/usr/bin:/bin:/usr/local/bin:/opt/homebrew/bin"
NOAWSPATH="$T/bin:/usr/bin:/bin"
R AWS_REGION=us-east-1 'cprof new bmiss --auth bedrock' >/dev/null
print -r -- 'AWS_PROFILE=ghost' > $P/bmiss/profile.env
out=$(R PATH="$AWSPATH" 'cprof doctor --no-claude')
[[ $out == *"WARN: bmiss's profile.env AWS_PROFILE ('ghost') not found in 'aws configure list-profiles'"* ]] \
  && ok "a21 doctor WARNs when aws is present and profile.env's AWS_PROFILE is not in 'aws configure list-profiles'" || bad "a21: $out"
[[ $out != *"WARN: eprec's profile.env AWS_PROFILE"* ]] \
  && ok "a22 doctor does not WARN when aws is present and profile.env's AWS_PROFILE resolves" || bad "a22: $out"
out=$(R PATH="$NOAWSPATH" 'cprof doctor --no-claude')
[[ $out != *"not found in 'aws configure list-profiles'"* ]] \
  && ok "a23 doctor skips the aws cross-check gracefully (no WARN) when aws is not on PATH" || bad "a23: $out"

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

# ---- self-heal AWS profile health cache (cprof-auth-health.zsh; architecture/claude-profile.md
# Extension 2026-10-28). Own isolated CPROF_ROOT (HROOT, via the RH wrapper) so accumulated cache
# rows never leak into or out of the rest of this suite. A mock 'aws' on HPATH answers
# 'configure get credential_process', 'configure list-profiles' and 'bedrock list-inference-profiles'
# purely from the profile-name prefix (good*/bad*/other) and env vars AWS_STUB_PROFILES/AWS_STUB_CP;
# STUBLOG records each bedrock probe call (profile name, one per line, in call order) so tests can
# assert both WHICH profiles were live-probed and in WHAT ORDER.
HROOT=$T/hroot; mkdir -p $HROOT; HF=$HROOT/.aws-profile-health
RH() { R CPROF_ROOT=$HROOT "$@"; }
mkdir -p $T/healthbin
print -r -- '#!/bin/sh
if [ "$1" = "configure" ] && [ "$2" = "get" ] && [ "$3" = "credential_process" ]; then
  shift 3
  p=""
  while [ $# -gt 0 ]; do
    if [ "$1" = "--profile" ]; then p="$2"; shift 2; else shift; fi
  done
  case " $AWS_STUB_CP " in
    *" $p "*) echo "/fake/credproc-$p.sh"; exit 0 ;;
    *) exit 1 ;;
  esac
fi
if [ "$1" = "configure" ] && [ "$2" = "list-profiles" ]; then
  printf "%s\n" "$AWS_STUB_PROFILES"
  exit 0
fi
if [ "$1" = "bedrock" ] && [ "$2" = "list-inference-profiles" ]; then
  shift 2
  p=""
  while [ $# -gt 0 ]; do
    if [ "$1" = "--profile" ]; then p="$2"; shift 2; else shift; fi
  done
  if [ -n "$STUBLOG" ]; then echo "$p" >> "$STUBLOG"; fi
  case "$p" in
    good*) echo "{\"inferenceProfileSummaries\":[]}"; exit 0 ;;
    bad*) echo "An error occurred (AccessDeniedException) when calling the ListInferenceProfiles operation: explicit deny in a service control policy: arn:aws:organizations::123:policy/p-x" >&2; exit 254 ;;
    *) echo "An error occurred (ExpiredTokenException) when calling the ListInferenceProfiles operation: token expired" >&2; exit 255 ;;
  esac
fi
exit 0' > $T/healthbin/aws
chmod +x $T/healthbin/aws
HPATH="$T/healthbin:$T/bin:/usr/bin:/bin:/usr/local/bin:/opt/homebrew/bin"

# h1: cache-hit good -> trusted, no live call at all (aws absent from PATH proves it)
print -r -- "cachedgood"$'\t'"good"$'\t'"20260101T000000Z"$'\t'"ok" > $HF
out=$(RH AWS_PROFILE=cachedgood AWS_REGION=us-east-1 PATH="$NOAWSPATH" 'cprof new hh1 --auth bedrock; print RC=$?')
C=$(<$HROOT/hh1/profile.env 2>/dev/null)
[[ $out == *"RC=0" && $out != *"could not validate"* && $out != *"substituting"* && $C == *"AWS_PROFILE='cachedgood'"* ]] \
  && ok "h1 cached-good AWS_PROFILE snapshots unchanged, no probe needed (aws absent from PATH)" || bad "h1: $out C=[$C]"

# h2: cache-hit bad with a cached-good already available -> substitutes straight from the cache,
# no live call either (aws still absent from PATH)
print -r -- "ambientbad"$'\t'"bad"$'\t'"20260101T000000Z"$'\t'"explicit deny in a service control policy: p-x"$'\n'"othergood"$'\t'"good"$'\t'"20260102T000000Z"$'\t'"ok" > $HF
out=$(RH AWS_PROFILE=ambientbad AWS_REGION=us-east-1 PATH="$NOAWSPATH" 'cprof new hh2 --auth bedrock; print RC=$?')
C=$(<$HROOT/hh2/profile.env 2>/dev/null)
[[ $out == *"RC=0" && $out == *"ambientbad"*"denied for Bedrock"*"explicit deny in a service control policy"*"substituting 'othergood'"* \
   && $C == *"AWS_PROFILE='othergood'"* ]] \
  && ok "h2 cached-bad with a cached-good available: substitutes from cache alone, no live call" || bad "h2: $out C=[$C]"

# h3: cache-hit bad, no cached-good anywhere -> live search, non-credential_process profiles tried
# first (cheap, no popup risk), stops at the first good; both tried candidates get cached.
print -r -- "ambientbad2"$'\t'"bad"$'\t'"20260101T000000Z"$'\t'"explicit deny in a service control policy: p-x" > $HF
rm -f $T/h3.log
out=$(RH AWS_PROFILE=ambientbad2 AWS_REGION=us-east-1 PATH="$HPATH" \
         AWS_STUB_PROFILES=$'ambientbad2\nbadnocp1\ngoodnocp1\nbadcp1\ngoodcp1' AWS_STUB_CP='badcp1 goodcp1' STUBLOG=$T/h3.log \
         'cprof new hh3 --auth bedrock; print RC=$?')
C=$(<$HROOT/hh3/profile.env 2>/dev/null); LOG=$(<$T/h3.log 2>/dev/null); HFC=$(<$HF)
[[ $out == *"RC=0" && $out == *"substituting 'goodnocp1'"* && $C == *"AWS_PROFILE='goodnocp1'"* && $LOG == $'badnocp1\ngoodnocp1' ]] \
  && ok "h3 live substitute search tries non-credential_process profiles first, stops at first good" || bad "h3: $out LOG=[$LOG] C=[$C]"
[[ $HFC == *$'badnocp1\tbad'* && $HFC == *$'goodnocp1\tgood'* ]] \
  && ok "h3b substitute search caches both the bad and good candidates it actually tried" || bad "h3b: $HFC"

# h4: every candidate exhausted, no good found -> falls back to snapshotting the broken ambient
# profile anyway, with an unmissable WARN summarizing what was tried.
print -r -- "allbad1"$'\t'"bad"$'\t'"20260101T000000Z"$'\t'"explicit deny in a service control policy: p-x" > $HF
out=$(RH AWS_PROFILE=allbad1 AWS_REGION=us-east-1 PATH="$HPATH" AWS_STUB_PROFILES=$'allbad1\nbadx1\nbadx2' 'cprof new hh4 --auth bedrock; print RC=$?')
C=$(<$HROOT/hh4/profile.env 2>/dev/null)
[[ $out == *"RC=0" && $out == *"no working AWS profile was found to substitute"* && $out == *"snapshotting 'allbad1' anyway"* && $C == *"AWS_PROFILE='allbad1'"* ]] \
  && ok "h4 exhausted substitute search falls back to the broken ambient profile, unmissable WARN" || bad "h4: $out C=[$C]"

# h5: no cache entry at all -> live-validated now; good -> used and cached.
: > $HF
out=$(RH AWS_PROFILE=goodfresh1 AWS_REGION=us-east-1 PATH="$HPATH" 'cprof new hh5 --auth bedrock; print RC=$?')
C=$(<$HROOT/hh5/profile.env 2>/dev/null); HFC=$(<$HF)
[[ $out == *"RC=0" && $out != *"could not validate"* && $out != *"substituting"* && $C == *"AWS_PROFILE='goodfresh1'"* && $HFC == *$'goodfresh1\tgood'* ]] \
  && ok "h5 unknown profile validated live, snapshotted, cache written" || bad "h5: $out C=[$C] HFC=[$HFC]"

# h6: _cprof_aws_classify in isolation -- the crux-of-correctness rule.
out=$(RH '_cprof_aws_classify 254 "AccessDeniedException ... explicit deny in a service control policy: p-x"; print -r -- "A:$reply[1]"
  _cprof_aws_classify 255 "ExpiredTokenException: token expired"; print -r -- "B:$reply[1]"
  _cprof_aws_classify 1 "UnauthorizedSSOTokenError: token is not valid"; print -r -- "C:$reply[1]"
  _cprof_aws_classify 1 "Unable to locate credentials"; print -r -- "D:$reply[1]"
  _cprof_aws_classify 0 "ignored"; print -r -- "E:$reply[1]"
  _cprof_aws_classify 1 "some unrelated network error"; print -r -- "F:$reply[1]"')
[[ $out == *"A:bad"* && $out == *"B:inconclusive"* && $out == *"C:inconclusive"* && $out == *"D:inconclusive"* && $out == *"E:good"* && $out == *"F:inconclusive"* ]] \
  && ok "h6 classify: AccessDenied+SCP-deny=bad; ExpiredToken/UnauthorizedSSOToken/no-credentials/other=inconclusive; rc=0=good" || bad "h6: $out"

# h6b: an inconclusive probe never poisons the cache (only good/bad are ever written).
out=$(RH AWS_PROFILE=inconprofile1 AWS_REGION=us-east-1 PATH="$HPATH" 'cprof new hh6 --auth bedrock; print RC=$?')
C=$(<$HROOT/hh6/profile.env 2>/dev/null); HFC=$(<$HF)
[[ $out == *"RC=0" && $out == *"could not validate AWS profile 'inconprofile1'"* && $C == *"AWS_PROFILE='inconprofile1'"* && $HFC != *"inconprofile1"* ]] \
  && ok "h6b inconclusive probe snapshots ambient as-is with a WARN, writes no cache row" || bad "h6b: $out HFC=[$HFC]"

# h7/h7c: `cprof doctor` live-validates and caches a bedrock profile's AWS_PROFILE that `cprof new`
# never probed (profile.env written by hand here, as a stand-in for a profile created before this
# extension shipped), and trusts the cache (no re-probe) on a later run.
: > $HF
RH 'cprof new hh7 --auth bedrock' >/dev/null 2>&1
print -r -- 'AWS_PROFILE=goodhh7' > $HROOT/hh7/profile.env
rm -f $T/h7.log
out=$(RH PATH="$HPATH" AWS_STUB_PROFILES=$'goodhh7' STUBLOG=$T/h7.log 'cprof doctor --no-claude')
HFC=$(<$HF)
[[ $out != *"WARN: hh7's profile.env AWS_PROFILE"* && $HFC == *$'goodhh7\tgood'* && $(<$T/h7.log) == goodhh7 ]] \
  && ok "h7 doctor live-validates and caches a bedrock profile's AWS_PROFILE that 'cprof new' never probed" || bad "h7: $out HFC=[$HFC] LOG=$(<$T/h7.log 2>/dev/null)"
out=$(RH PATH="$HPATH" AWS_STUB_PROFILES=$'goodhh7' STUBLOG=$T/h7.log 'cprof doctor --no-claude')
[[ $(<$T/h7.log) == goodhh7 ]] \
  && ok "h7b second doctor run trusts the cache, no re-probe (log unchanged)" || bad "h7b: $(<$T/h7.log 2>/dev/null)"
RH 'cprof new hh7c --auth bedrock' >/dev/null 2>&1
print -r -- 'AWS_PROFILE=badhh7c' > $HROOT/hh7c/profile.env
out=$(RH PATH="$HPATH" AWS_STUB_PROFILES=$'badhh7c' 'cprof doctor --no-claude')
[[ $out == *"WARN: hh7c's profile.env AWS_PROFILE ('badhh7c') is cached bad for Bedrock"*"explicit deny in a service control policy"* ]] \
  && ok "h7c doctor WARNs when a profile.env AWS_PROFILE is cached bad for Bedrock" || bad "h7c: $out"

# ---- help + file length
out=$(R 'cprof help'); [[ $out == *"--auth oauth|bedrock"* ]] && ok "a13 help documents --auth oauth|bedrock" || bad "a13"
long=(); for f in $SRC/cprof*.zsh; do (( $(wc -l < $f) <= 300 )) || long+=(${f:t}); done
(( $#long == 0 )) && ok "a14 every cprof*.zsh <= 300 lines" || bad "a14 over 300 lines: $long"

(( fails )) && { print "$fails failure(s)"; exit 1; }
exit 0
