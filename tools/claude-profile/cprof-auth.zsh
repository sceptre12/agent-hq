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
