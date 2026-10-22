# cprof link: link a profile to the main profile ($HOME/.claude) + doctor link rows. Sourced by cprof.zsh.
# Design: architecture/claude-profile.md "Extension (2026-10-21)" B-F. Main = literal $HOME/.claude and $HOME/.claude.json.
# Never reads or writes token, profile.env, tier, tier.src, workspace/ or the Keychain.

_CPROF_LINK_ENTRIES=(CLAUDE.md skills agents plugins settings.json)
_CPROF_LINK_SECRET='SECRET|TOKEN|KEY|PASSWORD|AUTH'
# main .mcpServers with secret-named env/header keys dropped (stdin: ~/.claude.json)
_CPROF_LINK_CLEAN='def c(f): if (type=="object") and has(f) and (.[f]|type)=="object" then .[f] |= with_entries(select(.key|test($re;"i")|not)) else . end;
  ((.mcpServers // {}) | if type=="object" then with_entries(.value |= (c("env")|c("headers"))) else {} end)'
_CPROF_LINK_DROPPED='(.mcpServers // {}) | to_entries[] | .key as $s | .value | objects
  | (["env","headers"][] as $f | ((.[$f]? // empty) | objects | keys[] | select(test($re;"i")) | "\($s).\($f).\(.)"))'

# _cprof_link_bak <profile-dir>: lazily create config-backup-<stamp> (700); sets/prints _cpl_bak (caller local).
_cprof_link_bak() {
  [[ -n $_cpl_bak ]] && return 0
  _cpl_bak=$1/config-backup-$(date -u +%Y%m%dT%H%M%SZ)
  ( umask 077; mkdir -m 700 -- "$_cpl_bak" ) 2>/dev/null || { _cprof_err "cannot create backup dir $_cpl_bak (exists?); nothing changed"; _cpl_bak=; return 1; }
  print -r -- "backup: $_cpl_bak"
}

_cprof_link() {
  local name=$1 d cfg e src dst main_cj=$HOME/.claude.json tiered=0 nl=0 nk=0 ns=0 _cpl_bak= mcp cur new line
  [[ -n $name ]] || { _cprof_err "usage: cprof link <name>"; return 1; }
  _cprof_valid_name "$name" || return 1
  (( $# > 1 )) && { _cprof_err "unknown option: $2"; return 1; }
  _cprof_need_jq || return 1
  d=$(_cprof_root)/$name; cfg=$d/config
  [[ -d $cfg ]] || { _cprof_err "no such profile: $name"; return 1; }
  [[ -e $d/tier ]] && tiered=1
  for e in $_CPROF_LINK_ENTRIES; do
    src=$HOME/.claude/$e; dst=$cfg/$e
    if (( tiered )) && [[ $e == CLAUDE.md ]]; then
      print -r -- "skip: CLAUDE.md (tiered: global rules file stays excluded)"; ns=$((ns+1)); continue
    elif (( tiered )) && [[ $e == settings.json ]]; then
      print -r -- "kept: settings.json (tiered: rendered file)"; nk=$((nk+1)); continue
    elif [[ ! -e $src && ! -L $src ]]; then
      print -r -- "skip: $e (none in $HOME/.claude)"; ns=$((ns+1)); continue
    elif [[ -L $dst && $(readlink -- "$dst") == $src ]]; then
      print -r -- "ok: $e (already linked)"; nk=$((nk+1)); continue
    fi
    if [[ -e $dst || -L $dst ]]; then
      _cprof_link_bak "$d" || return 1
      mv -- "$dst" "$_cpl_bak/$e" || { _cprof_err "cannot move $dst into the backup"; return 1; }
    fi
    ln -s -- "$src" "$dst" || {
      [[ -e $_cpl_bak/$e || -L $_cpl_bak/$e ]] && mv -- "$_cpl_bak/$e" "$dst"
      _cprof_err "cannot link $dst"; return 1; }
    print -r -- "linked: $e -> $src"; nl=$((nl+1))
  done
  # .mcpServers: merge main's servers (secret-named env/header keys dropped) into the profile's .claude.json
  mcp=$(jq -c --arg re "$_CPROF_LINK_SECRET" "$_CPROF_LINK_CLEAN" "$main_cj" 2>/dev/null) \
    || { _cprof_err "cannot read $main_cj (missing or invalid JSON)"; return 1; }
  if [[ $mcp == '{}' ]]; then
    print -r -- "skip: .mcpServers (none in $main_cj)"; ns=$((ns+1))
  else
    for line in ${(f)"$(jq -r --arg re "$_CPROF_LINK_SECRET" "$_CPROF_LINK_DROPPED" "$main_cj")"}; do print -r -- "stripped: $line"; done
    if [[ -e $cfg/.claude.json ]]; then cur=$(<"$cfg/.claude.json") 2>/dev/null || { _cprof_err "cannot read $cfg/.claude.json"; return 1; }
    else cur='{}'; fi
    [[ -n ${cur//[[:space:]]/} ]] || cur='{}'
    new=$(print -r -- "$cur" | jq --argjson m "$mcp" '.mcpServers = ((.mcpServers // {}) * $m)') \
      || { _cprof_err "invalid JSON in $cfg/.claude.json; left untouched"; return 1; }
    if [[ $(print -r -- "$cur" | jq -S -c '.mcpServers // {}') == $(print -r -- "$new" | jq -S -c '.mcpServers') && -e $cfg/.claude.json ]]; then
      print -r -- "ok: .mcpServers (in-sync, $(print -r -- "$mcp" | jq 'length'))"; nk=$((nk+1))
    else
      if [[ -e $cfg/.claude.json ]]; then
        _cprof_link_bak "$d" || return 1
        ( umask 077; cp -- "$cfg/.claude.json" "$_cpl_bak/.claude.json" ) || { _cprof_err "cannot back up $cfg/.claude.json"; return 1; }
      fi
      ( umask 077; print -r -- "$new" > "$cfg/.claude.json.tmp.$$" && mv -f -- "$cfg/.claude.json.tmp.$$" "$cfg/.claude.json" ) \
        || { rm -f -- "$cfg/.claude.json.tmp.$$"; _cprof_err "cannot write $cfg/.claude.json"; return 1; }
      print -r -- "copied: .mcpServers ($(print -r -- "$mcp" | jq 'length'): $(print -r -- "$mcp" | jq -r 'keys | join(" ")'))"; nl=$((nl+1))
    fi
  fi
  print -r -- "cprof: linked '$name' ($nl linked, $nk ok, $ns skipped)"
}

# doctor: one link row per non-`_` profile (informational; an unlinked profile shows file/- without WARN).
_cprof_doctor_links() {
  local d n e src dst v row tiered mm have; local -a miss
  print -r -- "-- link rows (main-profile links) --"
  (( ${+commands[jq]} )) || { print -r -- "WARN: link rows skipped: jq not installed"; return 0; }
  mm=$(jq -r '(.mcpServers // {}) | if type=="object" then keys[] else empty end' "$HOME/.claude.json" 2>/dev/null)
  for d in "$(_cprof_root)"/*(N/); do
    n=${d:t}; [[ $n == _* || ! -d $d/config ]] && continue
    tiered=0; [[ -e $d/tier ]] && tiered=1
    row="$n:"
    for e in $_CPROF_LINK_ENTRIES; do
      src=$HOME/.claude/$e; dst=$d/config/$e
      if [[ -L $dst ]]; then [[ $(readlink -- "$dst") == $src ]] && v=linked || v=other-link
      elif [[ -e $dst ]]; then v=file; (( tiered )) && [[ $e == settings.json ]] && v=rendered
      else v=-; fi
      row+=" $e=$v"
    done
    if [[ -z $mm ]]; then row+="; mcpServers=absent"
    else
      have=$(jq -r '(.mcpServers // {}) | if type=="object" then keys[] else empty end' "$d/config/.claude.json" 2>/dev/null)
      local -a hv; hv=(${(f)have}); miss=(${(f)mm}); miss=(${miss:|hv})
      (( $#miss )) && row+="; mcpServers=missing:${(j:,:)miss}" || row+="; mcpServers=in-sync(${#${(f)mm}})"
    fi
    print -r -- "$row"
  done
  return 0
}
