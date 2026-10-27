# cprof link: link a profile to a source root (default $HOME/projects/agent-hq; override with a 2nd
# arg, e.g. $HOME/.claude for the old personal-linking behavior) + doctor link rows. Sourced by cprof.zsh.
# Design: architecture/claude-profile.md "Extension (2026-10-21)" B-F; "Extension (2026-10-27)" dynamic
# source root. Per entry, independently: <root>/config/<entry> first, else <root>/<entry> (agent-hq:
# config/ holds CLAUDE.md + settings.json, skills/agents live at the root; $HOME/.claude: all flat).
# Writes a new `link-src` file (resolved root + the root's git HEAD, if it is a git tree) next to
# `token`/`tier` so `doctor` reports against the root a profile was actually last linked to (M2/A3).
# Never reads or writes token, profile.env, tier, tier.src, workspace/ or the Keychain.

_CPROF_LINK_ENTRIES=(CLAUDE.md skills agents plugins settings.json)
_CPROF_LINK_SECRET='SECRET|TOKEN|KEY|PASSWORD|AUTH'
# main .mcpServers with secret-named env/header keys dropped (stdin: ~/.claude.json)
_CPROF_LINK_CLEAN='def c(f): if (type=="object") and has(f) and (.[f]|type)=="object" then .[f] |= with_entries(select(.key|test($re;"i")|not)) else . end;
  ((.mcpServers // {}) | if type=="object" then with_entries(.value |= (c("env")|c("headers"))) else {} end)'
_CPROF_LINK_DROPPED='(.mcpServers // {}) | to_entries[] | .key as $s | .value | objects
  | (["env","headers"][] as $f | ((.[$f]? // empty) | objects | keys[] | select(test($re;"i")) | "\($s).\($f).\(.)"))'

# _cprof_link_src <root> <entry>: resolve <entry> under <root>, per entry, independently (A1 — no
# whole-root "is this a config/-style root" pre-check; each candidate path is tested on its own
# merits so a root could even mix layouts without a special case): <root>/config/<entry> first (e.g.
# agent-hq's CLAUDE.md/settings.json), else <root>/<entry> (e.g. agent-hq's top-level skills/agents,
# or any entry under a flat root like $HOME/.claude, which has no config/ at all). Prints the
# resolved path and returns 0 if it exists (file/dir/symlink); returns 1 (prints nothing) if absent
# under both.
_cprof_link_src() {
  local root=$1 e=$2 p
  p=$root/config/$e
  [[ -e $p || -L $p ]] && { print -r -- "$p"; return 0; }
  p=$root/$e
  [[ -e $p || -L $p ]] && { print -r -- "$p"; return 0; }
  return 1
}

# _cprof_link_bak <profile-dir>: lazily create config-backup-<stamp> (700); sets/prints _cpl_bak (caller local).
_cprof_link_bak() {
  [[ -n $_cpl_bak ]] && return 0
  _cpl_bak=$1/config-backup-$(date -u +%Y%m%dT%H%M%SZ)
  ( umask 077; mkdir -m 700 -- "$_cpl_bak" ) 2>/dev/null || { _cprof_err "cannot create backup dir $_cpl_bak (exists?); nothing changed"; _cpl_bak=; return 1; }
  print -r -- "backup: $_cpl_bak"
}

_cprof_link() {
  local name=$1 root=$2 d cfg e src dst main_cj def_root tiered=0 nl=0 nk=0 ns=0 _cpl_bak= mcp cur new line sha
  [[ -n $name ]] || { _cprof_err "usage: cprof link <name> [<source-root>]"; return 1; }
  _cprof_valid_name "$name" || return 1
  (( $# > 2 )) && { _cprof_err "unknown option: $3"; return 1; }
  # Canonicalize whichever root we end up with: zsh ':A' resolves symlinks and collapses repeated or
  # trailing slashes in one pass (A2 + A4 — a single robust trim, not a one-slash %/ strip), so a
  # symlinked or multi-trailing-slash <source-root> can't malform a <root>/<entry> join or the
  # derived .mcpServers sibling path (${root:h}/${root:t}.json below).
  if [[ -n $root ]]; then
    root=${root:A}
    [[ -d $root ]] || { _cprof_err "no such source: '$root'"; return 1; }
  else
    root=$HOME/projects/agent-hq
    root=${root:A}
    # M4: the default root is never hard-errored (an absent ~/projects/agent-hq on a fresh machine
    # is normal), but silently all-skipping is confusing — say so explicitly, once, up front.
    [[ -d $root ]] || print -r -- "WARN: default source root '$root' does not exist; every entry will skip (pass an explicit <source-root>, or create it)"
  fi
  _cprof_need_jq || return 1
  d=$(_cprof_root)/$name; cfg=$d/config
  [[ -d $cfg ]] || { _cprof_err "no such profile: $name"; return 1; }
  [[ -e $d/tier ]] && tiered=1
  for e in $_CPROF_LINK_ENTRIES; do
    dst=$cfg/$e
    if (( tiered )) && [[ $e == CLAUDE.md ]]; then
      print -r -- "skip: CLAUDE.md (tiered: global rules file stays excluded)"; ns=$((ns+1)); continue
    elif (( tiered )) && [[ $e == settings.json ]]; then
      print -r -- "kept: settings.json (tiered: rendered file)"; nk=$((nk+1)); continue
    elif ! src=$(_cprof_link_src "$root" "$e"); then
      print -r -- "skip: $e (none in $root)"; ns=$((ns+1)); continue
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
  # .mcpServers: merge <root>'s main-account json (sibling of <root>, named <root-basename>.json — e.g.
  # $HOME/.claude -> $HOME/.claude.json; agent-hq has no such file) into the profile's .claude.json
  main_cj=${root:h}/${root:t}.json
  if [[ ! -e $main_cj ]]; then
    print -r -- "skip: .mcpServers (no $main_cj)"; ns=$((ns+1))
  else
    mcp=$(jq -c --arg re "$_CPROF_LINK_SECRET" "$_CPROF_LINK_CLEAN" "$main_cj" 2>/dev/null) \
      || { _cprof_err "cannot read $main_cj (missing or invalid JSON)"; return 1; }
    if [[ $mcp == '{}' ]]; then
      print -r -- "skip: .mcpServers (none in $main_cj)"; ns=$((ns+1))
    else
      # M5 (security): a wider default root widens the .mcpServers merge blast radius too — the
      # secret-scrub regex only drops SECRET|TOKEN|KEY|PASSWORD|AUTH-named env/header keys, never
      # `command`/`args`/`url`, which run verbatim when claude starts. Rather than gate this on a
      # new --force/confirm flag (which would make `link` non-scriptable — it is called from tests
      # and automation today, and D's idempotency guarantee depends on that), surface the risk with
      # an explicit warning every time a non-default root's MCP config is about to be merged in, so
      # it is never silently trusted.
      def_root=$HOME/.claude; def_root=${def_root:A}
      if [[ $root != $def_root ]]; then
        print -r -- "WARN: merging .mcpServers from a non-default root ($main_cj) — command/args/url fields are not secret-scrubbed and run verbatim when claude starts; review $cfg/.claude.json before trusting this profile"
      fi
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
  fi
  # A3/M2: record an audit trail of what was linked and when — the root a profile is linked to
  # (e.g. a live agent-hq checkout) can drift after the fact, so persist the resolved root plus its
  # git HEAD (if it is a git working tree) in a new sibling file, and have doctor (M2, below) read
  # it back instead of assuming $HOME/.claude. Written on every successful run, even an idempotent
  # re-run with 0 linked, so the record always reflects the most recent `link` invocation.
  sha=$(git -C "$root" rev-parse HEAD 2>/dev/null) || sha=
  # Trailing `true`: without it the group's exit status is that of the `[[ -n $sha ]] && print ...`
  # line, which is 1 (short-circuited, no commit line to write) whenever the root isn't a git tree —
  # that would make a perfectly successful write look like a failure below.
  ( umask 077; { print -r -- "root $root"; [[ -n $sha ]] && print -r -- "commit $sha"; true } > "$d/link-src.tmp.$$" \
    && mv -f -- "$d/link-src.tmp.$$" "$d/link-src" ) \
    || { rm -f -- "$d/link-src.tmp.$$"; _cprof_err "cannot write $d/link-src"; return 1; }
  print -r -- "cprof: linked '$name' ($nl linked, $nk ok, $ns skipped)"
}

# doctor: one link row per non-`_` profile (informational; an unlinked profile shows file/- without WARN).
# M2: each profile's entries are compared against the root it was *actually* last linked to (read
# from `link-src`, written by `_cprof_link` above), not a hardcoded $HOME/.claude — otherwise a
# profile linked via the agent-hq default would misreport every entry as `other-link`. A profile
# with no `link-src` (never linked, or linked before this field existed) falls back to
# $HOME/.claude, matching the pre-2026-10-27 behavior exactly.
_cprof_doctor_links() {
  local d n e src dst v row tiered mm have lroot lsline; local -a miss
  print -r -- "-- link rows (main-profile links) --"
  (( ${+commands[jq]} )) || { print -r -- "WARN: link rows skipped: jq not installed"; return 0; }
  mm=$(jq -r '(.mcpServers // {}) | if type=="object" then keys[] else empty end' "$HOME/.claude.json" 2>/dev/null)
  for d in "$(_cprof_root)"/*(N/); do
    n=${d:t}; [[ $n == _* || ! -d $d/config ]] && continue
    tiered=0; [[ -e $d/tier ]] && tiered=1
    # Canonicalized the same way `link` canonicalizes <source-root> (zsh ':A'), so the fallback
    # default compares on equal footing with a recorded root read from link-src below — both
    # `link` and `ln -s` operate on the resolved path, so an uncanonicalized fallback here would
    # spuriously mismatch every entry whenever $HOME contains a symlink component.
    lroot=$HOME/.claude; lroot=${lroot:A}
    if [[ -r $d/link-src ]]; then
      for lsline in ${(f)"$(<$d/link-src)"}; do [[ $lsline == root\ * ]] && lroot=${lsline#root }; done
    fi
    row="$n:"
    for e in $_CPROF_LINK_ENTRIES; do
      src=$(_cprof_link_src "$lroot" "$e") || src=
      dst=$d/config/$e
      if [[ -L $dst ]]; then [[ -n $src && $(readlink -- "$dst") == $src ]] && v=linked || v=other-link
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
