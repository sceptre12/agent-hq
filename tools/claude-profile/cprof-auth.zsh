# cprof auth modes: `oauth` (default: the profile's token file) and `bedrock` (no token; Claude Code uses the AWS credential
# chain of the calling shell). Sourced by cprof.zsh. Design: architecture/claude-profile-02.md, Extension 2026-10-26 (owner ruling
# "Add Bedrock mode to cprof"). `<profile>/auth` holds the mode; an absent file means oauth, so every existing profile is unchanged.

# Unset in bedrock mode: Bedrock ranks first in Claude Code's auth precedence, but a stray Anthropic key or token must not
# leak into the profile (and a managed policy can refuse a Bedrock session while one is present).
_CPROF_BEDROCK_UNSET=(ANTHROPIC_AUTH_TOKEN ANTHROPIC_API_KEY CLAUDE_CODE_OAUTH_TOKEN CLAUDE_CODE_USE_VERTEX CLAUDE_CODE_USE_FOUNDRY)

_cprof_auth_valid() { [[ $1 == (oauth|bedrock) ]] || { _cprof_err "unknown auth mode: '$1' (oauth|bedrock)"; return 1; } }

# _cprof_auth_mode <profile-dir>: prints the mode (file content without whitespace; default oauth).
_cprof_auth_mode() {
  local m
  [[ -f $1/auth ]] && { m=$(<"$1/auth") 2>/dev/null; m=${m//[[:space:]]/}; }
  print -r -- "${m:-oauth}"
}

# Region for the sandbox host list and the launch warning: AWS_REGION, else AWS_DEFAULT_REGION (Claude Code's own order,
# minus its AWS-profile and us-east-1 fallbacks, which cprof cannot see). No cprof-only override: the host list and Claude Code
# must read the same region.
_cprof_aws_region() { print -r -- "${AWS_REGION:-${AWS_DEFAULT_REGION-}}"; }
_cprof_region_valid() { [[ $1 =~ '^[a-z]{2}(-gov)?-[a-z]+-[0-9]$' ]] }

# _cprof_render_inputs <mode> <region> <file>...: cat the render inputs; in bedrock mode substitute the auth fragment's
# <region>/<sso_region> placeholders (SSO region: CPROF_SSO_REGION, else the model region). Input files are never modified.
_cprof_render_inputs() {
  local mode=$1 r=$2 s=${CPROF_SSO_REGION:-$2}; shift 2
  if [[ $mode == bedrock ]]; then cat -- "$@" | sed -e "s/<region>/$r/g" -e "s/<sso_region>/$s/g"; else cat -- "$@"; fi
}

# Read a token from stdin (silent on a tty), strip whitespace, write chmod-600 via umask.
_cprof_write_token() {
  local file=$1 tok
  read -rs "tok?OAuth token (input hidden): " || true
  [[ -t 0 ]] && print
  tok=${tok//[[:space:]]/}
  [[ -n $tok ]] || { _cprof_err "empty token, nothing written"; return 1; }
  rm -f -- "$file"
  ( umask 077; print -r -- "$tok" > "$file" ) || return 1
  tok=
}

# _cprof_auth_token <profile-dir> <mode> <varname>: stores the token (oauth) or "" (bedrock: no token file is read) into the
# caller's variable <varname> (never into argv or a global). Returns 1 with a message when an oauth token is missing, unreadable or empty.
_cprof_auth_token() {
  local d=$1 m=$2 t
  : ${(P)3::=}
  [[ $m == bedrock ]] && return 0
  [[ -f $d/token ]] || { _cprof_err "no such profile (or no token): ${d:t}"; return 1; }
  t=$(<"$d/token") 2>/dev/null || { _cprof_err "cannot read token file for '${d:t}'"; return 1; }
  t=${t//[[:space:]]/}
  [[ -n $t ]] || { _cprof_err "token file for '${d:t}' is empty; run 'cprof token ${d:t}'"; return 1; }
  : ${(P)3::=$t}
}

# _cprof_auth_apply <mode> <token>: the auth part of the profile environment; `use` and `launch` share it.
# bedrock: AWS_PROFILE, AWS_REGION, AWS_* keys and AWS_BEARER_TOKEN_BEDROCK pass through from the caller (or profile.env) untouched.
_cprof_auth_apply() {
  if [[ $1 == bedrock ]]; then
    unset -- $_CPROF_BEDROCK_UNSET
    export CLAUDE_CODE_USE_BEDROCK=1
    [[ -n $(_cprof_aws_region) ]] \
      || _cprof_err "WARN: no AWS_REGION/AWS_DEFAULT_REGION in this shell; Claude Code falls back to the AWS profile's region, then us-east-1"
  else
    unset -- $_CPROF_HIGHER_AUTH
    export CLAUDE_CODE_OAUTH_TOKEN=$2
  fi
}

# _cprof_auth_dryrun <mode>: the auth words of the launch dry-run env line (the token is never printed).
_cprof_auth_dryrun() {
  if [[ $1 == bedrock ]]; then print -rn -- "CLAUDE_CODE_USE_BEDROCK=1 AWS_REGION=${AWS_REGION-unset} AWS_PROFILE=${AWS_PROFILE-unset}"
  else print -rn -- "CLAUDE_CODE_OAUTH_TOKEN=<token>"; fi
}

# _cprof_bedrock_snapshot <profile-dir>: at `new --auth bedrock`, captures the CREATING shell's AWS_PROFILE,
# AWS_REGION, AWS_DEFAULT_REGION and any Anthropic model-override vars into <profile-dir>/profile.env, so the
# profile is self-contained instead of depending on whatever AWS_PROFILE a LATER shell happens to have exported
# already (the real-world bug this closes: a profile with no profile.env let an unrelated already-running shell's
# AWS_PROFILE -- pointed at an SCP-denied sandbox account -- pass straight through untouched). Mirrors
# cprof-link.zsh's link-src audit-trail write style: atomic tmp+mv, umask 077, never touches an existing file (this
# only ever runs once, right after `new` creates a fresh profile dir). Only vars actually set in this shell are
# written; a missing AWS_PROFILE gets a WARN (matching the M4/M5 WARN style in cprof-link.zsh) instead of a blank
# or wrong line, and nothing is written at all when there is truly nothing to snapshot.
# Self-heal (Extension 2026-10-28): the ambient AWS_PROFILE candidate is run through
# _cprof_aws_heal_profile (cprof-auth-health.zsh) before being written. A cached-good or
# freshly-validated-good candidate snapshots unchanged; a bad one (SCP-denied, the recurring
# real-world bug) is swapped for a working substitute found live via the AWS profile health cache
# and 'aws configure list-profiles', with a WARN naming the substitution; AWS_REGION/AWS_DEFAULT_REGION
# and the Anthropic vars below are never touched by this.
_CPROF_BEDROCK_SNAPSHOT_VARS=(AWS_PROFILE AWS_REGION AWS_DEFAULT_REGION)
# Explicit allowlist, not a glob/pattern scan of the parameter table -- same reasoning as the AWS array above: a
# dynamic scan makes profile.env content shell-session-dependent in a way the AWS half isn't, and is easy to lose
# track of (fix-up pass, pr-review M3/M4). Verified against the installed Claude Code CLI and
# code.claude.com/en/docs/claude-code/env-vars (2026-10-27): ANTHROPIC_MODEL plus every current
# ANTHROPIC_DEFAULT_<alias>_MODEL pin (opus/sonnet/haiku/fable). Excludes ANTHROPIC_DEFAULT_MODEL (a different
# "default model for new sessions" setting, not an alias pin) and the deprecated ANTHROPIC_SMALL_FAST_MODEL.
_CPROF_BEDROCK_SNAPSHOT_ANTHROPIC_VARS=(ANTHROPIC_MODEL ANTHROPIC_DEFAULT_OPUS_MODEL ANTHROPIC_DEFAULT_SONNET_MODEL ANTHROPIC_DEFAULT_HAIKU_MODEL ANTHROPIC_DEFAULT_FABLE_MODEL)
_cprof_bedrock_snapshot() {
  local d=$1 n v out= region
  for n in $_CPROF_BEDROCK_SNAPSHOT_VARS; do
    v=${(P)n-}
    if [[ $n == AWS_PROFILE && -n $v ]]; then
      region=$(_cprof_aws_region); [[ -n $region ]] || region=us-east-1
      v=$(_cprof_aws_heal_profile "$v" "$region")
    fi
    [[ -n $v ]] && out+="$n=${(qq)v}"$'\n'
  done
  for n in $_CPROF_BEDROCK_SNAPSHOT_ANTHROPIC_VARS; do
    v=${(P)n-}
    [[ -n $v ]] && out+="$n=${(qq)v}"$'\n'
  done
  [[ -n ${AWS_PROFILE-} ]] \
    || _cprof_err "WARN: no AWS_PROFILE in this shell to snapshot into '${d:t}/profile.env'; set AWS_PROFILE before 'cprof new <name> --auth bedrock', or add it to $d/profile.env by hand"
  [[ -n $out ]] || return 0
  ( umask 077; print -rn -- "$out" > "$d/profile.env.tmp.$$" && mv -f -- "$d/profile.env.tmp.$$" "$d/profile.env" ) \
    || { rm -f -- "$d/profile.env.tmp.$$"; _cprof_err "cannot write $d/profile.env"; return 1; }
}

# doctor: one row per bedrock profile, flagging a missing profile.env or a profile.env with no AWS_PROFILE in
# it -- this is how a legacy profile predating _cprof_bedrock_snapshot (e.g. one created before this fix) is
# spotted: it silently inherits whatever AWS_PROFILE the shell running `cprof use`/`launch` happens to have,
# the exact failure mode this extension closes for every *new* bedrock profile. No repair subcommand: the fix
# is a one-line manual edit, named explicitly below, not something cprof should re-render on your behalf.
# Fix-up pass (pr-review M1): a present AWS_PROFILE= line only proves the NAME was recorded, never that the
# profile still resolves in ~/.aws/config -- a renamed/removed AWS profile would otherwise go stale with no WARN,
# the same failure class this whole extension exists to close. When `aws` is on PATH, cross-check the recorded
# value against `aws configure list-profiles` and WARN (never fail) if it is not found; skip this check
# gracefully, with no WARN at all, when `aws` is not installed (doctor must not require the AWS CLI).
# Health-cache refresh (Extension 2026-10-28): once a recorded AWS_PROFILE resolves in
# 'aws configure list-profiles', consult _cprof_aws_health_read (cprof-auth-health.zsh). A cache hit
# (good or bad) is trusted with no live call -- `doctor` must stay fast on repeat runs. A cache miss
# runs one live probe via _cprof_aws_bedrock_probe (same classification rules as `new`), which also
# writes the cache -- this is what keeps the cache warm for profiles a recent `cprof new` never
# touched. A browser SSO login prompt may occur on that probe (accepted, same ruling as `new`).
_cprof_doctor_bedrock_env() {
  local d n ln ap apval regval reg hst det; local -a lines
  print -r -- "-- bedrock profile.env rows (auth=bedrock profiles only) --"
  local hit=0
  for d in "$(_cprof_root)"/*(N/); do
    n=${d:t}; [[ $n == _* || ! -d $d/config ]] && continue
    [[ $(_cprof_auth_mode "$d") == bedrock ]] || continue
    if [[ ! -f $d/profile.env ]]; then
      print -r -- "WARN: $n has no profile.env; AWS_PROFILE will come from whatever shell happens to run 'cprof use/launch $n' -- re-running 'cprof new' is not needed, just add AWS_PROFILE=<profile> (and AWS_REGION=<region>) to $d/profile.env by hand, or re-run 'cprof new' in a shell that already has AWS_PROFILE exported"
      hit=1; continue
    fi
    ap=; lines=(${(f)"$(<$d/profile.env)"}) 2>/dev/null
    for ln in $lines; do [[ $ln == AWS_PROFILE=* ]] && { ap=1; break }; done
    if [[ -z $ap ]]; then
      print -r -- "WARN: $n has profile.env but no AWS_PROFILE in it; add AWS_PROFILE=<profile> to $d/profile.env by hand"
      hit=1
    elif (( ${+commands[aws]} )); then
      lines=(${(f)"$(() { setopt localoptions allexport; unset AWS_PROFILE AWS_REGION; source "$1" 2>/dev/null; print -r -- "${AWS_PROFILE-}"; print -r -- "${AWS_REGION-}"; } "$d/profile.env")"})
      apval=$lines[1]; regval=$lines[2]
      if [[ -n $apval ]] && ! aws configure list-profiles 2>/dev/null | grep -qxF -- "$apval"; then
        print -r -- "WARN: $n's profile.env AWS_PROFILE ('$apval') not found in 'aws configure list-profiles'; the AWS profile may have been renamed or removed"
        hit=1
      elif [[ -n $apval ]]; then
        if _cprof_aws_health_read "$apval"; then
          hst=$reply[1]; det=$reply[3]
        else
          reg=$regval; [[ -n $reg ]] || reg=$(_cprof_aws_region); [[ -n $reg ]] || reg=us-east-1
          _cprof_aws_bedrock_probe "$apval" "$reg"
          hst=$reply[1]; det=$reply[2]
        fi
        if [[ $hst == bad ]]; then
          print -r -- "WARN: $n's profile.env AWS_PROFILE ('$apval') is cached bad for Bedrock ($det); see $(_cprof_root)/.aws-profile-health"
          hit=1
        fi
      fi
    fi
  done
  (( hit )) || print -r -- "ok: every bedrock profile has profile.env with AWS_PROFILE"
  return 0
}
