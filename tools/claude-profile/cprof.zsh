# cprof — isolated, per-shell Claude Code profiles (hq architecture/claude-profile.md).
# Source from ~/.zshrc:  source ~/projects/agent-hq/tools/claude-profile/cprof.zsh
# Profile root: ${CPROF_ROOT:-$HOME/claude-profiles}
#   <root>/_templates/<t>/   optional seeds copied into a new profile's config/
#   <root>/<name>/{config,workspace,token,auth,profile.env}   (token absent for --auth bedrock; config/settings.json gets claudeMdExcludes)
# State lives in non-exported globals so it never reaches claude's environment.

typeset -gA _CPROF_PRE_VAL _CPROF_PRE_EXP _CPROF_TRK_SET _CPROF_TRK_VAL _CPROF_TRK_EXP
typeset -ga _CPROF_ADDED
typeset -g _CPROF_ACTIVE _CPROF_PRE_PWD

# Names whose set/unset/exported state is restored exactly on `off`.
_CPROF_TRACKED=(
  CLAUDE_CONFIG_DIR CLAUDE_CODE_OAUTH_TOKEN ANTHROPIC_API_KEY ANTHROPIC_AUTH_TOKEN
  CLAUDE_CODE_USE_BEDROCK CLAUDE_CODE_USE_VERTEX CLAUDE_CODE_USE_FOUNDRY
  CLAUDE_CODE_DISABLE_AUTO_MEMORY CLAUDE_CODE_DISABLE_OFFICIAL_MARKETPLACE_AUTOINSTALL PS1
)
# Auth vars that outrank CLAUDE_CODE_OAUTH_TOKEN and so must be unset in a profile.
_CPROF_HIGHER_AUTH=(
  ANTHROPIC_AUTH_TOKEN ANTHROPIC_API_KEY
  CLAUDE_CODE_USE_BEDROCK CLAUDE_CODE_USE_VERTEX CLAUDE_CODE_USE_FOUNDRY
)

# claudeMdExcludes + doctor live in a sibling file (keeps each file under the 300-line limit).
source "${${(%):-%x}:A:h}/cprof-checks.zsh"
source "${${(%):-%x}:A:h}/cprof-auth.zsh"     # auth modes oauth|bedrock + token I/O (architecture/claude-profile-02.md Extension 2026-10-26)
source "${${(%):-%x}:A:h}/cprof-tiers.zsh"   # tier verbs: render/launch/sync/trust (permission-tiers P2)
source "${${(%):-%x}:A:h}/cprof-link.zsh"    # link verb + doctor link rows (architecture/claude-profile.md Extension 2026-10-21)

_cprof_root() { print -r -- "${CPROF_ROOT:-$HOME/claude-profiles}"; }

_cprof_err() { print -u2 -r -- "cprof: $*"; }

_cprof_valid_name() {
  [[ $1 =~ '^[A-Za-z0-9][A-Za-z0-9._-]*$' ]] || { _cprof_err "invalid profile name: '$1'"; return 1; }
}

# Sets $reply to the names of global, non-special scalar params, exported or not (minus volatile ones,
# cprof's own state, the tracked vars restored separately, and _cp_* locals).
_cprof_scalars() {
  local -a n
  n=(${(k)parameters[(R)scalar*]})
  n=(${n:#(OLDPWD|_|SHLVL|PWD|REPLY|_CPROF_*|_cp_*)})
  reply=()
  for n in $n; do
    [[ ${parameters[$n]} == *(local|readonly)* ]] && continue
    [[ ${parameters[$n]} == *special* && ${parameters[$n]} != *export* ]] && continue   # RANDOM, SECONDS, ...
    (( ${_CPROF_TRACKED[(Ie)$n]} )) && continue
    reply+=($n)
  done
}

_cprof_new() {
  local name tmpl root d tier ov force=0 auth=oauth
  name=$1; shift
  [[ -n $name ]] || { _cprof_err "usage: cprof new <name> [--template T] [--auth oauth|bedrock] [--tier executor|desk [--overlay P]] (--tier executor renders <owner> from CPROF_OWNER, a GitHub account name [A-Za-z0-9-]; it fails closed if CPROF_OWNER is unset, empty or malformed; --auth bedrock reads no token and needs AWS_REGION for a tiered render)"; return 1; }
  while (( $# )); do
    case $1 in
      --template) tmpl=$2; shift 2 || { _cprof_err "--template needs a value"; return 1; } ;;
      --auth) auth=$2; shift 2 || { _cprof_err "--auth needs a value"; return 1; } ;;
      --tier) tier=$2; shift 2 || { _cprof_err "--tier needs a value"; return 1; } ;;
      --overlay) ov=$2; shift 2 || { _cprof_err "--overlay needs a value"; return 1; } ;;
      --force) force=1; shift ;;
      *) _cprof_err "unknown option: $1"; return 1 ;;
    esac
  done
  _cprof_valid_name "$name" || return 1
  _cprof_auth_valid "$auth" || return 1
  [[ -z $ov || -n $tier ]] || { _cprof_err "--overlay needs --tier"; return 1; }
  if [[ -n $tier ]]; then
    [[ $tier == (executor|desk) ]] || { _cprof_err "unknown tier: '$tier' (executor|desk)"; return 1; }
    [[ -z $ov ]] || { _cprof_valid_name "$ov" || return 1; }
    _cprof_need_jq || return 1
  fi
  root=$(_cprof_root); d=$root/$name
  [[ -e $d ]] && { _cprof_err "profile '$name' already exists"; return 1; }
  if [[ -n $tmpl ]]; then
    _cprof_valid_name "$tmpl" || return 1
    [[ -d $root/_templates/$tmpl ]] || { _cprof_err "no such template: $root/_templates/$tmpl"; return 1; }
  fi
  ( umask 077; mkdir -p -- "$d/config" "$d/workspace" ) || return 1
  if [[ -n $tmpl ]]; then
    cp -R -- "$root/_templates/$tmpl/." "$d/config/" || { _cprof_err "template copy failed"; rm -rf -- "$d"; return 1; }
  fi
  _cprof_apply_excludes "$d/config" || { rm -rf -- "$d"; return 1; }
  _cprof_onboarded "$d/config" || true
  if [[ $auth == bedrock ]]; then ( umask 077; print -r -- bedrock > "$d/auth" ) || { rm -rf -- "$d"; return 1; }; fi
  if [[ -n $tier ]]; then   # before the token prompt, so a bad render never costs a paste
    { _cprof_render "$d" "$tier" "$ov" && _cprof_tier_md "$d" "$tier" "$name" "$force"; } || { rm -rf -- "$d"; return 1; }
  fi
  if [[ $auth != bedrock ]]; then _cprof_write_token "$d/token" || { rm -rf -- "$d"; return 1; }; fi
  print -r -- "created profile '$name' at $d${${(M)auth:#bedrock}:+ (auth: bedrock, no token; AWS credentials come from your shell)}"
}

_cprof_token() {
  local name=$1 d
  [[ -n $name ]] || { _cprof_err "usage: cprof token <name>"; return 1; }
  _cprof_valid_name "$name" || return 1
  d=$(_cprof_root)/$name
  [[ -d $d ]] || { _cprof_err "no such profile: $name"; return 1; }
  [[ $(_cprof_auth_mode "$d") == bedrock ]] && { _cprof_err "'$name' uses --auth bedrock; it has no token"; return 1; }
  _cprof_write_token "$d/token" && print -r -- "token rotated for '$name' (takes effect on next 'cprof use $name')"
}

# Locals are _cp_-prefixed and profile.env is sourced from an anonymous function with no locals,
# so a profile.env assigning name=, d=, n= or v= cannot clobber this function's state.
_cprof_use() {
  local _cp_name=$1 _cp_d _cp_n _cp_v _cp_tok _cp_mode
  local -A _cp_pre _cp_preexp
  [[ -n $_cp_name ]] || { _cprof_err "usage: cprof use <name>"; return 1; }
  _cprof_valid_name "$_cp_name" || return 1
  _cp_d=$(_cprof_root)/$_cp_name
  [[ -d $_cp_d/config ]] || { _cprof_err "no such profile (or no token): $_cp_name"; return 1; }
  _cp_mode=$(_cprof_auth_mode "$_cp_d")
  _cprof_auth_token "$_cp_d" "$_cp_mode" _cp_tok || return 1
  [[ -n $_CPROF_ACTIVE ]] && _cprof_off quiet

  # Snapshot 1: set-ness/value/exported-ness of every scalar name, and of the tracked vars.
  _CPROF_PRE_VAL=(); _CPROF_PRE_EXP=()
  _cprof_scalars
  for _cp_n in $reply; do
    _cp_pre[$_cp_n]=${(P)_cp_n}
    [[ ${parameters[$_cp_n]} == *export* ]] && _cp_preexp[$_cp_n]=1 || _cp_preexp[$_cp_n]=0
  done
  _CPROF_TRK_SET=(); _CPROF_TRK_VAL=(); _CPROF_TRK_EXP=()
  for _cp_n in $_CPROF_TRACKED; do
    _CPROF_TRK_SET[$_cp_n]=${+parameters[$_cp_n]}
    _CPROF_TRK_VAL[$_cp_n]=${(P)_cp_n}
    [[ ${parameters[$_cp_n]} == *export* ]] && _CPROF_TRK_EXP[$_cp_n]=1 || _CPROF_TRK_EXP[$_cp_n]=0
  done
  _CPROF_PRE_PWD=$PWD

  _cprof_onboarded "$_cp_d/config" || true   # warns only; never fails use
  # Apply.
  _cprof_auth_apply "$_cp_mode" "$_cp_tok"; _cp_tok=
  export CLAUDE_CONFIG_DIR=$_cp_d/config
  export CLAUDE_CODE_DISABLE_AUTO_MEMORY=1
  export CLAUDE_CODE_DISABLE_OFFICIAL_MARKETPLACE_AUTOINSTALL=1
  if [[ -f $_cp_d/profile.env ]]; then
    () { setopt localoptions allexport; source "$1"; } "$_cp_d/profile.env"
  fi

  # Snapshot 2 (after profile.env): new names are ours to unset on off; names whose value,
  # exported-ness or set-ness changed get their pre-state recorded for restore.
  _cprof_scalars
  _CPROF_ADDED=()
  for _cp_n in $reply; do (( ${+_cp_pre[$_cp_n]} )) || _CPROF_ADDED+=($_cp_n); done
  for _cp_n _cp_v in "${(@kv)_cp_pre}"; do
    if (( ! ${+parameters[$_cp_n]} )) || [[ ${(P)_cp_n} != "$_cp_v" ]] \
       || [[ ${parameters[$_cp_n]} == *export* && ${_cp_preexp[$_cp_n]} == 0 ]]; then
      _CPROF_PRE_VAL[$_cp_n]=$_cp_v; _CPROF_PRE_EXP[$_cp_n]=${_cp_preexp[$_cp_n]}
    fi
  done

  PS1="[cprof:$_cp_name] $PS1"
  _CPROF_ACTIVE=$_cp_name
  builtin cd -q -- "$_cp_d/workspace" 2>/dev/null
  [[ $1 == quiet ]] || print -r -- "cprof: using '$_cp_name' (config: $_cp_d/config)"
}

_cprof_off() {
  local n v quiet=$1
  if [[ -z $_CPROF_ACTIVE ]]; then
    [[ $quiet == quiet ]] || print -u2 -r -- "cprof: no active profile"
    return 0
  fi
  local was=$_CPROF_ACTIVE
  # Diff-based restore: unset what use/profile.env added, restore what changed or vanished.
  for n in $_CPROF_ADDED; do unset -- "$n" 2>/dev/null; done
  for n v in "${(@kv)_CPROF_PRE_VAL}"; do
    typeset -g -- "$n=$v" 2>/dev/null
    if (( _CPROF_PRE_EXP[$n] )); then typeset -gx -- "$n"; else typeset -g +x -- "$n"; fi
  done
  # Exact set/unset/exported-ness restore for tracked names.
  for n in $_CPROF_TRACKED; do
    if (( _CPROF_TRK_SET[$n] )); then
      typeset -g -- "$n=${_CPROF_TRK_VAL[$n]}"
      if (( _CPROF_TRK_EXP[$n] )); then typeset -gx -- "$n"; else typeset -g +x -- "$n"; fi
    else
      unset -- "$n" 2>/dev/null
    fi
  done
  [[ -d $_CPROF_PRE_PWD ]] && builtin cd -q -- "$_CPROF_PRE_PWD"
  _CPROF_PRE_VAL=(); _CPROF_PRE_EXP=(); _CPROF_TRK_SET=(); _CPROF_TRK_VAL=(); _CPROF_TRK_EXP=(); _CPROF_ADDED=()
  _CPROF_ACTIVE=; _CPROF_PRE_PWD=
  [[ $quiet == quiet ]] || print -r -- "cprof: left '$was'"
}

_cprof_ls() {
  local root d name tok mark; root=$(_cprof_root)
  [[ -d $root ]] || { print -r -- "(no profiles; root $root does not exist)"; return 0; }
  for d in "$root"/*(N/); do
    name=${d:t}; [[ $name == _* ]] && continue
    if [[ $(_cprof_auth_mode "$d") == bedrock ]]; then tok=bedrock; elif [[ -f $d/token ]]; then tok=token; else tok=NO-TOKEN; fi
    [[ $name == $_CPROF_ACTIVE ]] && mark='*' || mark=' '
    print -r -- "$mark $name  [$tok]"
  done
  for d in "$root"/_templates/*(N/); do print -r -- "  template: ${d:t}"; done
  return 0
}

_cprof_current() { [[ -n $_CPROF_ACTIVE ]] && print -r -- "$_CPROF_ACTIVE"; return 0; }

_cprof_rm() {
  local name=$1 d ans
  [[ -n $name ]] || { _cprof_err "usage: cprof rm <name>"; return 1; }
  _cprof_valid_name "$name" || return 1
  d=$(_cprof_root)/$name
  [[ -d $d ]] || { _cprof_err "no such profile: $name"; return 1; }
  [[ $name == $_CPROF_ACTIVE ]] && { _cprof_err "'$name' is active in this shell; run 'cprof off' first"; return 1; }
  print -r -- "This will permanently delete: $d"
  print -r -- "  size: $(du -sh -- "$d" 2>/dev/null | cut -f1)"
  ls -A -- "$d" | sed 's/^/  - /'
  read -r "ans?Type 'yes' to delete: " || true
  [[ -t 0 ]] || print
  [[ $ans == yes ]] || { print -r -- "aborted"; return 1; }
  rm -rf -- "$d" && print -r -- "removed '$name'"
}

_cprof_help() {
  cat <<'H'
cprof — isolated per-shell Claude Code profiles
  cprof new <name> [--template T] [--auth oauth|bedrock] [--tier executor|desk [--overlay P] [--force]]
                                    create profile; token read from stdin (hidden on a tty);
                                    --auth bedrock: no token; use/launch set CLAUDE_CODE_USE_BEDROCK=1 and pass your AWS_*
                                    vars through; a tiered render adds the Bedrock/STS/SSO hosts for AWS_REGION (required)
                                    --tier renders config/settings.json + tier/tier.src + CLAUDE.md
                                    --tier executor renders <owner> from CPROF_OWNER (a GitHub account name, [A-Za-z0-9-]);
                                    it fails closed if CPROF_OWNER is unset, empty or malformed
  cprof launch <name> [--dry-run] [-- <claude args>]
                                    exec claude with the tier's flag (refuses the opposite tier's); unlike `use`,
                                    strips ANTHROPIC_API_KEY/CLAUDE_CODE_USE_*/DISABLE_AUTO_MEMORY set by profile.env
  cprof sync <name> [--force]       re-render a tiered profile (refuses a hand-edited render, exit 3;
                                    --force discards ALL hand edits except claudeMdExcludes, backup written)
  cprof trust ls | baseline [--note "<text>"]   trust ledger (_trust/ledger.jsonl)
  cprof link <name> [<source-root>] link a profile to <source-root> (default $HOME/projects/agent-hq; pass
                                    $HOME/.claude for the old personal-linking behavior, or any other root):
                                    skills/agents/plugins (+CLAUDE.md, settings.json on plain profiles), merge
                                    .mcpServers; replaced entries are backed up; missing entries skip gracefully
  cprof use <name>                  enter profile in THIS shell (cd to its workspace)
  cprof off                         restore the shell exactly
  cprof ls                          list profiles and templates
  cprof current                     print active profile name (nothing if none)
  cprof token <name>                re-paste / rotate the token (refused for --auth bedrock profiles)
  cprof excludes <name>             (re)apply claudeMdExcludes to a profile's settings.json
  cprof rm <name>                   delete a profile (asks to confirm)
  cprof doctor [--no-claude]        auth vars, walk-up scan, /context memory rows, init event
  cprof help
Root: ${CPROF_ROOT:-$HOME/claude-profiles}
H
}

cprof() {
  emulate -L zsh
  local sub=${1:-help}; (( $# )) && shift
  case $sub in
    new)     _cprof_new "$@" ;;
    use)     _cprof_use "$@" ;;
    off)     _cprof_off "$@" ;;
    ls)      _cprof_ls "$@" ;;
    current) _cprof_current "$@" ;;
    token)   _cprof_token "$@" ;;
    excludes) _cprof_excludes "$@" ;;
    rm)      _cprof_rm "$@" ;;
    launch)  _cprof_launch "$@" ;;
    sync)    _cprof_sync "$@" ;;
    trust)   _cprof_trust "$@" ;;
    link)    _cprof_link "$@" ;;
    doctor)  _cprof_doctor "$@" ;;
    help|-h|--help) _cprof_help ;;
    *) _cprof_err "unknown subcommand: $sub"; _cprof_help >&2; return 1 ;;
  esac
}
