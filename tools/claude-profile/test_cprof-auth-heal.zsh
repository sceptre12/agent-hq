#!/usr/bin/env zsh
# tools/claude-profile/test_cprof-auth-heal.zsh — tests for cprof's self-heal of `new --auth bedrock` against a broken
# ambient AWS profile (cprof-auth-health.zsh, plus the heal paths in cprof-auth.zsh: `_cprof_bedrock_snapshot` and
# `_cprof_doctor_bedrock_env`). Contract: architecture/claude-profile-03.md, Extension 2026-10-28. Split out of
# test_cprof-auth.zsh (which keeps the --auth oauth|bedrock, render, launch, snapshot and doctor cases) so each test
# file stays under the 300-line cap (INVARIANTS 24); the harness below is deliberately identical to test_cprof-auth.zsh's.
# Hermetic: HOME and CPROF_ROOT live in a mktemp dir, zsh -f skips the user's config, a fake hq tree is used via
# CPROF_HQ_CONFIG, real claude is never run (stub on PATH), and every cprof-managed var and every AWS/region/model var
# the code reads is unset in each child; CLEAN mirrors cprof-auth.zsh's two explicit snapshot allowlists (see the
# header of test_cprof-auth.zsh for why that list is kept byte-for-byte identical).
SRC=${0:A:h}
_TRK=(${(f)"$(zsh -fc "source $SRC/cprof.zsh; print -l \${_CPROF_TRACKED:#PS1}" 2>/dev/null)"}); CLEAN=()
for _v in $_TRK AWS_REGION AWS_DEFAULT_REGION AWS_PROFILE CPROF_SSO_REGION CPROF_OWNER \
  ANTHROPIC_MODEL ANTHROPIC_DEFAULT_OPUS_MODEL ANTHROPIC_DEFAULT_SONNET_MODEL ANTHROPIC_DEFAULT_HAIKU_MODEL \
  ANTHROPIC_DEFAULT_FABLE_MODEL; do CLEAN+=(-u $_v); done
_tb=${TMPDIR:-/tmp}; T=$(mktemp -d "${_tb%/}/test_cprof-auth-heal.XXXXXX") || exit 1
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
NOAWSPATH="$T/bin:/usr/bin:/bin"

# ---- self-heal AWS profile health cache (cprof-auth-health.zsh; architecture/claude-profile-03.md
# Extension 2026-10-28). Own isolated CPROF_ROOT (HROOT, via the RH wrapper) so accumulated cache
# rows never leak into or out of the rest of this suite. A mock 'aws' on HPATH answers
# 'configure get credential_process', 'configure get region', 'configure get sso_account_id',
# 'configure list-profiles', 'bedrock list-inference-profiles' and 'sts get-caller-identity' purely
# from the profile-name prefix (good*/bad*/other, or an exact match in AWS_STUB_GOOD) and env vars
# AWS_STUB_PROFILES/AWS_STUB_CP/AWS_STUB_ACCT/AWS_STUB_NOIDENTITY; STUBLOG records each bedrock probe
# call (profile name, one per line, in call order) so tests can assert both WHICH profiles were
# live-probed and in WHAT ORDER -- in particular (fix-up pass B1, h8 below), that a raw-sso profile
# with a sibling is never itself probed, only its sibling is.
HROOT=$T/hroot; mkdir -p $HROOT; HF=$HROOT/.aws-profile-health
RH() { R CPROF_ROOT=$HROOT "$@"; }
mkdir -p $T/healthbin
print -r -- '#!/bin/sh
getprofile() { p=""; while [ $# -gt 0 ]; do if [ "$1" = "--profile" ]; then p="$2"; shift 2; else shift; fi; done; }
acctfor() {
  for kv in $AWS_STUB_ACCT; do
    case "$kv" in "$1="*) printf "%s" "${kv#$1=}"; return 0 ;; esac
  done
  printf "999999999999"
}
if [ "$1" = "configure" ] && [ "$2" = "get" ] && [ "$3" = "credential_process" ]; then
  shift 3; getprofile "$@"
  case " $AWS_STUB_CP " in
    *" $p "*) echo "/fake/credproc-$p.sh"; exit 0 ;;
    *) exit 1 ;;
  esac
fi
if [ "$1" = "configure" ] && [ "$2" = "get" ] && [ "$3" = "sso_account_id" ]; then
  shift 3; getprofile "$@"
  case " $AWS_STUB_ACCT " in
    *" $p="*) acctfor "$p"; exit 0 ;;
    *) exit 1 ;;
  esac
fi
if [ "$1" = "configure" ] && [ "$2" = "get" ] && [ "$3" = "region" ]; then exit 1; fi
if [ "$1" = "configure" ] && [ "$2" = "list-profiles" ]; then
  printf "%s\n" "$AWS_STUB_PROFILES"
  exit 0
fi
if [ "$1" = "sts" ] && [ "$2" = "get-caller-identity" ]; then
  shift 2; getprofile "$@"
  case " $AWS_STUB_NOIDENTITY " in
    *" $p "*) exit 1 ;;
  esac
  acctfor "$p"; exit 0
fi
if [ "$1" = "bedrock" ] && [ "$2" = "list-inference-profiles" ]; then
  shift 2; getprofile "$@"
  if [ -n "$STUBLOG" ]; then echo "$p" >> "$STUBLOG"; fi
  case " $AWS_STUB_GOOD " in
    *" $p "*) echo "{\"inferenceProfileSummaries\":[]}"; exit 0 ;;
  esac
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
print -r -- "cachedgood"$'\t'"us-east-1"$'\t'"good"$'\t'"20260101T000000Z"$'\t'"ok" > $HF
out=$(RH AWS_PROFILE=cachedgood AWS_REGION=us-east-1 PATH="$NOAWSPATH" 'cprof new hh1 --auth bedrock; print RC=$?')
C=$(<$HROOT/hh1/profile.env 2>/dev/null)
[[ $out == *"RC=0" && $out != *"could not validate"* && $out != *"substituting"* && $C == *"AWS_PROFILE='cachedgood'"* ]] \
  && ok "h1 cached-good AWS_PROFILE snapshots unchanged, no probe needed (aws absent from PATH)" || bad "h1: $out C=[$C]"

# h2: cache-hit bad with a cached-good already available -> substitutes straight from the cache,
# no live call either (aws still absent from PATH)
print -r -- "ambientbad"$'\t'"us-east-1"$'\t'"bad"$'\t'"20260101T000000Z"$'\t'"explicit deny in a service control policy: p-x"$'\n'"othergood"$'\t'"us-east-1"$'\t'"good"$'\t'"20260102T000000Z"$'\t'"ok" > $HF
out=$(RH AWS_PROFILE=ambientbad AWS_REGION=us-east-1 PATH="$NOAWSPATH" 'cprof new hh2 --auth bedrock; print RC=$?')
C=$(<$HROOT/hh2/profile.env 2>/dev/null)
[[ $out == *"RC=0" && $out == *"ambientbad"*"denied for Bedrock"*"explicit deny in a service control policy"*"substituting 'othergood'"* \
   && $C == *"AWS_PROFILE='othergood'"* ]] \
  && ok "h2 cached-bad with a cached-good available: substitutes from cache alone, no live call" || bad "h2: $out C=[$C]"

# h2c (fix-up pass M1): the SAME profile name, cached good under one region, must not be trusted
# under a different one -- region is part of the cache key now, so a region change (here: via
# ambient AWS_REGION, since this stub's 'configure get region' always fails) is a cache miss, not a
# hit, and forces a fresh live probe (visible in STUBLOG) instead of silently reusing the stale verdict.
print -r -- "myprof"$'\t'"us-east-1"$'\t'"good"$'\t'"20260101T000000Z"$'\t'"ok" > $HF
rm -f $T/h2c.log
out=$(RH AWS_PROFILE=myprof AWS_REGION=eu-west-1 PATH="$HPATH" AWS_STUB_GOOD='myprof' STUBLOG=$T/h2c.log 'cprof new hh2c --auth bedrock; print RC=$?')
HFC=$(<$HF)
[[ $out == *"RC=0" && $(<$T/h2c.log 2>/dev/null) == myprof && $HFC == *$'myprof\teu-west-1\tgood'* ]] \
  && ok "h2c a cached-good row under a different region is a cache miss, forcing a fresh probe (M1)" || bad "h2c: $out LOG=$(<$T/h2c.log 2>/dev/null) HFC=[$HFC]"

# h3: cache-hit bad, no cached-good anywhere -> live search, non-credential_process profiles tried
# first (cheap, no popup risk), stops at the first good; both tried candidates get cached.
print -r -- "ambientbad2"$'\t'"us-east-1"$'\t'"bad"$'\t'"20260101T000000Z"$'\t'"explicit deny in a service control policy: p-x" > $HF
rm -f $T/h3.log
out=$(RH AWS_PROFILE=ambientbad2 AWS_REGION=us-east-1 PATH="$HPATH" \
         AWS_STUB_PROFILES=$'ambientbad2\nbadnocp1\ngoodnocp1\nbadcp1\ngoodcp1' AWS_STUB_CP='badcp1 goodcp1' STUBLOG=$T/h3.log \
         'cprof new hh3 --auth bedrock; print RC=$?')
C=$(<$HROOT/hh3/profile.env 2>/dev/null); LOG=$(<$T/h3.log 2>/dev/null); HFC=$(<$HF)
[[ $out == *"RC=0" && $out == *"substituting 'goodnocp1'"* && $C == *"AWS_PROFILE='goodnocp1'"* && $LOG == $'badnocp1\ngoodnocp1' ]] \
  && ok "h3 live substitute search tries non-credential_process profiles first, stops at first good" || bad "h3: $out LOG=[$LOG] C=[$C]"
[[ $HFC == *$'badnocp1\tus-east-1\tbad'* && $HFC == *$'goodnocp1\tus-east-1\tgood'* ]] \
  && ok "h3b substitute search caches both the bad and good candidates it actually tried" || bad "h3b: $HFC"

# h4: every candidate exhausted, no good found -> falls back to snapshotting the broken ambient
# profile anyway, with an unmissable WARN summarizing what was tried.
print -r -- "allbad1"$'\t'"us-east-1"$'\t'"bad"$'\t'"20260101T000000Z"$'\t'"explicit deny in a service control policy: p-x" > $HF
out=$(RH AWS_PROFILE=allbad1 AWS_REGION=us-east-1 PATH="$HPATH" AWS_STUB_PROFILES=$'allbad1\nbadx1\nbadx2' 'cprof new hh4 --auth bedrock; print RC=$?')
C=$(<$HROOT/hh4/profile.env 2>/dev/null)
[[ $out == *"RC=0" && $out == *"no working AWS profile was found to substitute"* && $out == *"snapshotting 'allbad1' anyway"* && $C == *"AWS_PROFILE='allbad1'"* ]] \
  && ok "h4 exhausted substitute search falls back to the broken ambient profile, unmissable WARN" || bad "h4: $out C=[$C]"

# h5: no cache entry at all -> live-validated now; good -> used and cached.
: > $HF
out=$(RH AWS_PROFILE=goodfresh1 AWS_REGION=us-east-1 PATH="$HPATH" 'cprof new hh5 --auth bedrock; print RC=$?')
C=$(<$HROOT/hh5/profile.env 2>/dev/null); HFC=$(<$HF)
[[ $out == *"RC=0" && $out != *"could not validate"* && $out != *"substituting"* && $C == *"AWS_PROFILE='goodfresh1'"* && $HFC == *$'goodfresh1\tus-east-1\tgood'* ]] \
  && ok "h5 unknown profile validated live, snapshotted, cache written" || bad "h5: $out C=[$C] HFC=[$HFC]"

# h8/h8b/h8c (fix-up pass B1, panel-unanimous blocking finding): live-reproduced on the owner's real
# machine, the substitute search picked a raw-internal SSO session profile (nonprod-sso, commented
# "do not use directly" in ~/.aws/config) over its own credential_process-fronted sibling (nonprod)
# purely because the raw profile sorted first among non-credential_process candidates. A sibling with
# an untried, non-excluded non-suffixed name must be probed INSTEAD of the raw profile in that slot;
# the raw profile itself must never appear in STUBLOG. Shaped like the real ~/.aws/config: badexclude
# (ambient, excluded, simulates adx-dev), nonprod-sso (raw, nocp, sorts first), nonprod
# (credential_process sibling, the one that must actually get probed and returned).
: > $HF
rm -f $T/h8.log
out=$(RH AWS_PROFILE=badexclude AWS_REGION=us-east-1 PATH="$HPATH" \
         AWS_STUB_PROFILES=$'badexclude\nnonprod-sso\nnonprod' AWS_STUB_CP='nonprod' AWS_STUB_GOOD='nonprod' \
         AWS_STUB_ACCT='nonprod-sso=111111111111 nonprod=111111111111' STUBLOG=$T/h8.log \
         'cprof new hh8 --auth bedrock; print RC=$?')
C=$(<$HROOT/hh8/profile.env 2>/dev/null); LOG=$(<$T/h8.log 2>/dev/null)
[[ $out == *"RC=0" && $out == *"substituting 'nonprod'"* && $C == *"AWS_PROFILE='nonprod'"* ]] \
  && ok "h8 substitute search prefers a raw-sso profile's sibling over the raw profile itself (B1)" || bad "h8: $out C=[$C]"
[[ $LOG == $'badexclude\nnonprod' ]] \
  && ok "h8b the raw-sso profile (nonprod-sso) is never itself live-probed, only its sibling is (badexclude's own initial check runs first, then nonprod)" || bad "h8b: LOG=[$LOG]"
[[ $out != *"does not match"* ]] \
  && ok "h8c matching sso_account_id (raw vs. sibling, same account): no spurious mismatch WARN" || bad "h8c: $out"
# h8d: identical shape, but the sibling fails its own live identity check -- B1's second half (the
# panel's account-id verification requirement) must skip it, not blindly trust the Bedrock probe alone.
: > $HF; rm -f $T/h8d.log
out=$(RH AWS_PROFILE=badexclude2 AWS_REGION=us-east-1 PATH="$HPATH" \
         AWS_STUB_PROFILES=$'badexclude2\nnoid-sso\nnoid' AWS_STUB_CP='noid' AWS_STUB_GOOD='noid' AWS_STUB_NOIDENTITY='noid' \
         STUBLOG=$T/h8d.log 'cprof new hh8d --auth bedrock; print RC=$?')
[[ $out == *"RC=0" && $out == *"failed account-identity verification; skipping"* && $out == *"no working AWS profile was found to substitute"* ]] \
  && ok "h8d a substitute that fails live identity verification is skipped, not accepted (B1)" || bad "h8d: $out"

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
[[ $out != *"WARN: hh7's profile.env AWS_PROFILE"* && $HFC == *$'goodhh7\tus-east-1\tgood'* && $(<$T/h7.log) == goodhh7 ]] \
  && ok "h7 doctor live-validates and caches a bedrock profile's AWS_PROFILE that 'cprof new' never probed" || bad "h7: $out HFC=[$HFC] LOG=$(<$T/h7.log 2>/dev/null)"
out=$(RH PATH="$HPATH" AWS_STUB_PROFILES=$'goodhh7' STUBLOG=$T/h7.log 'cprof doctor --no-claude')
[[ $(<$T/h7.log) == goodhh7 ]] \
  && ok "h7b second doctor run trusts the cache, no re-probe (log unchanged)" || bad "h7b: $(<$T/h7.log 2>/dev/null)"
RH 'cprof new hh7c --auth bedrock' >/dev/null 2>&1
print -r -- 'AWS_PROFILE=badhh7c' > $HROOT/hh7c/profile.env
out=$(RH PATH="$HPATH" AWS_STUB_PROFILES=$'badhh7c' 'cprof doctor --no-claude')
[[ $out == *"WARN: hh7c's profile.env AWS_PROFILE ('badhh7c') is cached bad for Bedrock"*"explicit deny in a service control policy"* ]] \
  && ok "h7c doctor WARNs when a profile.env AWS_PROFILE is cached bad for Bedrock" || bad "h7c: $out"

(( fails )) && { print "$fails failure(s)"; exit 1; }
exit 0
