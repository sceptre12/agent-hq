# cprof helpers: claudeMdExcludes management and `cprof doctor`. Sourced by cprof.zsh.
# See architecture/claude-profile.md (Fable T2 amendments, 2026-10-01).

# Ensure <dir>/settings.json has claudeMdExcludes covering the user-level and hq-pointer memory
# files that Claude Code would otherwise load by walking up from any cwd under $HOME
# (architecture/claude-profile.md, Fable T2 2026-10-01). Unique-union merge; never clobbers.
_cprof_apply_excludes() {
  local cfg=$1 f=$1/settings.json cur new link
  local -a ex
  ex=("$HOME/.claude/CLAUDE.md" "$HOME/.claude/CLAUDE.local.md" "$HOME/.claude/rules/**"
      "$HOME/projects/CLAUDE.md" "$HOME/projects/CLAUDE.local.md"
      "$HOME/CLAUDE.md" "$HOME/CLAUDE.local.md")
  if [[ -L $HOME/.claude/CLAUDE.md ]]; then
    link=$(readlink -f "$HOME/.claude/CLAUDE.md" 2>/dev/null) && [[ -n $link ]] && ex+=("$link")
  fi
  if (( ! ${+commands[jq]} )); then
    if [[ -e $f ]]; then _cprof_err "jq not found and $f exists; refusing to overwrite it"; return 1; fi
    # No existing file to clobber: write a minimal one by hand (paths contain no quote chars).
    local e out=
    for e in "${ex[@]}"; do out+="${out:+,}\"$e\""; done
    ( umask 077; print -r -- "{\"claudeMdExcludes\":[$out]}" > "$f" ) || return 1
    return 0
  fi
  if [[ -e $f ]]; then   # fail closed: an unreadable settings.json is never replaced by {}
    cur=$(<"$f") || { _cprof_err "cannot read $f; left untouched"; return 1; }
  else
    cur='{}'
  fi
  [[ -n ${cur//[[:space:]]/} ]] || cur='{}'
  new=$(print -r -- "$cur" | jq --argjson ex "$(printf '%s\n' "${ex[@]}" | jq -R . | jq -s .)" \
        '.claudeMdExcludes = (((.claudeMdExcludes // []) + $ex) | unique)') \
    || { _cprof_err "could not merge claudeMdExcludes into $f (invalid JSON?); left untouched"; return 1; }
  ( umask 077; print -r -- "$new" > "$f.tmp.$$" && mv -f -- "$f.tmp.$$" "$f" ) || return 1
}

# Mark first-run onboarding complete in <dir>/.claude.json (CLAUDE_CONFIG_DIR relocates it), else interactive
# claude shows the login-method screen despite a valid CLAUDE_CODE_OAUTH_TOKEN. Idempotent merge; an
# unreadable/invalid file or missing jq is warned about and left untouched (returns 1; callers do not fail).
_cprof_onboarded() {
  local f=$1/.claude.json cur new
  if [[ ! -e $f ]]; then
    ( umask 077; print -r -- '{"hasCompletedOnboarding":true}' > "$f" ) || { _cprof_err "could not create $f"; return 1; }
    return 0
  fi
  (( ${+commands[jq]} )) || { _cprof_err "jq not found; $f left untouched (onboarding flag not set)"; return 1; }
  cur=$(<"$f") 2>/dev/null || { _cprof_err "cannot read $f; left untouched"; return 1; }
  [[ -n ${cur//[[:space:]]/} ]] || cur='{}'
  new=$(print -r -- "$cur" | jq '.hasCompletedOnboarding = true') 2>/dev/null \
    || { _cprof_err "invalid JSON in $f; left untouched"; return 1; }
  [[ -n $new ]] || { _cprof_err "invalid JSON in $f; left untouched"; return 1; }
  ( umask 077; print -r -- "$new" > "$f.tmp.$$" && mv -f -- "$f.tmp.$$" "$f" ) || { rm -f -- "$f.tmp.$$"; return 1; }
}

_cprof_excludes() {
  local name=$1 d
  [[ -n $name ]] || { _cprof_err "usage: cprof excludes <name>"; return 1; }
  _cprof_valid_name "$name" || return 1
  d=$(_cprof_root)/$name
  [[ -d $d/config ]] || { _cprof_err "no such profile: $name"; return 1; }
  _cprof_apply_excludes "$d/config" && print -r -- "claudeMdExcludes applied to $d/config/settings.json"
}

_cprof_doctor() {
  setopt localoptions extendedglob   # the ## # / %% # trims below need it (emulate -L zsh does not set it)
  local run_claude=1 n d hit line
  [[ $1 == --no-claude ]] && run_claude=0
  print -r -- "== cprof doctor =="
  print -r -- "active profile : ${_CPROF_ACTIVE:-(none)}"
  if (( ${+CLAUDE_CONFIG_DIR} )); then print -r -- "CLAUDE_CONFIG_DIR: $CLAUDE_CONFIG_DIR"
  else print -r -- "CLAUDE_CONFIG_DIR: (unset)"; fi
  print -r -- "prompt prefix is cosmetic (Warp may ignore PS1); trust 'cprof current' and CLAUDE_CONFIG_DIR."

  print -r -- "-- higher-precedence auth vars (must be unset) --"
  hit=0
  for n in $_CPROF_HIGHER_AUTH; do
    (( ${+parameters[$n]} )) && { print -r -- "WARN: $n is set"; hit=1; }
  done
  (( hit )) || print -r -- "ok: none set"

  print -r -- "-- walk-up context files (ancestors of $PWD; EXCLUDED = listed in claudeMdExcludes) --"
  hit=0
  local -a excl
  if (( ${+CLAUDE_CONFIG_DIR} && ${+commands[jq]} )) && [[ -f $CLAUDE_CONFIG_DIR/settings.json ]]; then
    excl=(${(f)"$(jq -r '.claudeMdExcludes[]? ' "$CLAUDE_CONFIG_DIR/settings.json" 2>/dev/null)"})
  fi
  d=$PWD
  while true; do
    for line in CLAUDE.md CLAUDE.local.md .claude/CLAUDE.md; do
      if [[ -e $d/$line ]]; then
        if [[ -n ${excl[(r)$d/$line]} || -n ${excl[(r)${${:-$d/$line}:A}]} ]]; then
          print -r -- "EXCLUDED: $d/$line"
        else
          print -r -- "WARN loaded: $d/$line"; hit=1
        fi
      fi
    done
    [[ $d == / ]] && break
    d=${d:h}
  done
  for line in .claude/settings*.json(N) .claude/rules(N) .mcp.json(N) AGENTS.md(N); do
    [[ -e $PWD/$line ]] && { print -r -- "WARN (cwd): $PWD/$line"; hit=1; }
  done
  (( hit )) || print -r -- "ok: no unexcluded ancestor files"
  _cprof_doctor_tiers
  _cprof_doctor_links

  if (( run_claude )); then
    if (( ${+commands[claude]} )); then
      print -r -- "-- claude auth status --"
      claude auth status 2>&1
      print -r -- "-- /context Memory Files (authoritative; local, no model call) --"
      local ctx mpath; local -a rows
      ctx=$(claude -p "/context" --no-session-persistence < /dev/null 2>/dev/null \
            | awk '/^### Memory Files/{f=1;next} f&&/^### /{exit} f&&/^\|/{print}')
      if [[ -n $ctx ]]; then print -r -- "$ctx"; else print -r -- "(no Memory Files section: no memory files loaded)"; fi
      rows=(${(f)ctx})
      for line in $rows; do
        [[ $line == '| Type'* || -z ${line//[| :-]/} ]] && continue   # header and `| --- |` separators
        mpath=${${(s:|:)line}[2]}; mpath=${${mpath## #}%% #}
        [[ -z $mpath ]] && continue
        if [[ -z ${CLAUDE_CONFIG_DIR:-} || $mpath != $CLAUDE_CONFIG_DIR/* ]] && [[ $mpath != $PWD/* ]]; then
          print -r -- "WARN: memory file outside \$CLAUDE_CONFIG_DIR and cwd: $mpath"
        fi
      done
      print -r -- "-- init event (runs: claude -p hi; makes one API call) --"
      if (( ${+commands[jq]} )); then
        claude -p hi --no-session-persistence --output-format stream-json --verbose < /dev/null 2>/dev/null \
          | jq -c 'select(.subtype=="init") | {mcp_servers, plugins, skills}'
      else
        print -r -- "jq not found; skipping init-event summary"
      fi
    else
      print -r -- "claude not on PATH; skipping claude checks"
    fi
  fi
}

