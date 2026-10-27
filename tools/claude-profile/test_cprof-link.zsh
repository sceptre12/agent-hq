#!/usr/bin/env zsh
# tools/claude-profile/test_cprof-link.zsh — tests for cprof-link.zsh (`cprof link` + doctor link rows).
# Hermetic: HOME (with a fake main profile at $HOME/.claude and $HOME/.claude.json) and CPROF_ROOT live in a mktemp dir,
# zsh -f skips the user's config, real claude is never run. Same harness as test_cprof.zsh.
SRC=${0:A:h}
_TRK=(${(f)"$(zsh -fc "source $SRC/cprof.zsh; print -l \${_CPROF_TRACKED:#PS1}" 2>/dev/null)"}); CLEAN=(); for _v in $_TRK; do CLEAN+=(-u $_v); done
_tb=${TMPDIR:-/tmp}; T=$(mktemp -d "${_tb%/}/test_cprof-link.XXXXXX") || exit 1
T=${T:A}   # canonicalize once (TMPDIR is often itself a symlink, e.g. /tmp -> /private/tmp on macOS):
           # `link` now canonicalizes every <source-root> (A2) before linking, so every path this
           # test derives from $T must already be canonical too, or readlink/string comparisons
           # below would spuriously mismatch against the un-resolved form.
trap 'chmod -R u+rwx "$T" 2>/dev/null; rm -rf "$T"' EXIT
mkdir -p $T/bin $T/home $T/root
command -v jq >/dev/null || { print -r -- "FAIL: jq required (these tests cannot run without it)"; exit 1; }
fails=0
ok()  { print -r -- "ok   $1"; }
bad() { print -r -- "FAIL $1"; fails=$((fails+1)); }
zrun() { env $CLEAN HOME=$T/home CPROF_ROOT=$T/root PATH=$T/bin:/usr/bin:/bin:/usr/local/bin:/opt/homebrew/bin \
         zsh -fc "source $SRC/cprof.zsh; $1" 2>&1 </dev/null; }
mkprof() { mkdir -p $T/root/$1/config $T/root/$1/workspace; print -r -- "tok-$1" > $T/root/$1/token; }
h() { shasum -a 256 -- "$1" 2>/dev/null | cut -d' ' -f1; }
M=$T/home/.claude
mkdir -p $M/skills $M/agents $M/plugins
print -r -- "main rules" > $M/CLAUDE.md; print -r -- '{"theme":"main"}' > $M/settings.json
print -r -- '{"oauthAccount":{"x":1},"userID":"main-u","mcpServers":{
 "a":{"command":"uvx","args":["a"],"env":{"API_KEY":"sekrit-value","FOO":"bar","x_token":"t2"}},
 "b":{"type":"http","url":"https://b.example","headers":{"Authorization":"Bearer sekrit-value","X-Ok":"1"}}}}' > $T/home/.claude.json

# ---- plain profile: 5 links + .mcpServers merge; real files are backed up
mkprof pl
print -r -- "old rules" > $T/root/pl/config/CLAUDE.md; print -r -- '{"theme":"old"}' > $T/root/pl/config/settings.json
mkdir -p $T/root/pl/config/skills; print x > $T/root/pl/config/skills/own.md
print -r -- '{"hasCompletedOnboarding":true,"userID":"pl-u","mcpServers":{"mine":{"command":"m"}}}' > $T/root/pl/config/.claude.json
print -r -- 'FOO=1' > $T/root/pl/profile.env
HP=(${(f)"$(for f in token profile.env; do h $T/root/pl/$f; done)"})
out=$(zrun "cprof link pl $M; print RC=\$?"); P=$T/root/pl/config
okl=1; for e in CLAUDE.md skills agents plugins settings.json; do [[ -L $P/$e && $(readlink $P/$e) == $M/$e ]] || okl=0; done
[[ $out == *"RC=0" && $okl == 1 && $(grep -c '^linked: ' <<<"$out") == 5 && $out == *"linked: CLAUDE.md -> $M/CLAUDE.md"* \
   && $out == *"cprof: linked 'pl' (6 linked, 0 ok, 0 skipped)"* ]] \
  && ok "l1 plain: CLAUDE.md/skills/agents/plugins/settings.json linked, summary counts" || bad "l1: $out"
BK=(${T}/root/pl/config-backup-*(N/))
[[ $#BK == 1 && $(stat -f %Lp $BK[1]) == 700 && $(<$BK[1]/CLAUDE.md) == "old rules" && -f $BK[1]/skills/own.md && -f $BK[1]/settings.json \
   && -f $BK[1]/.claude.json && $out == *"backup: $BK[1]"* && $BK[1] =~ 'config-backup-[0-9]{8}T[0-9]{6}Z$' ]] \
  && ok "l2 replaced real entries moved into config-backup-<stamp> (700) with .claude.json copy" || bad "l2: $BK $out"
F=$P/.claude.json
[[ $out == *"copied: .mcpServers (2: a b)"* && $(jq -r '.mcpServers | keys | join(",")' $F) == a,b,mine && $(jq -r .userID $F) == pl-u && $(jq -r .hasCompletedOnboarding $F) == true \
   && $(jq -r '.mcpServers.mine.command' $F) == m && $(jq -r '.mcpServers.a.args[0]' $F) == a && ! -L $F && $(stat -f %Lp $F) == 600 ]] \
  && ok "l3 .mcpServers merged: main keys added, profile-only server and other keys kept, real file" || bad "l3: $out $(<$F)"
[[ $(jq -c '.mcpServers.a.env' $F) == '{"FOO":"bar"}' && $(jq -c '.mcpServers.b.headers' $F) == '{"X-Ok":"1"}' && $(<$F) != *sekrit-value* \
   && $out == *"stripped: a.env.API_KEY"* && $out == *"stripped: a.env.x_token"* && $out == *"stripped: b.headers.Authorization"* && $out != *sekrit-value* ]] \
  && ok "l4 secret-named env/header keys stripped and named (values never printed)" || bad "l4: $out $(<$F)"
[[ $(h $T/root/pl/token) == $HP[1] && $(h $T/root/pl/profile.env) == $HP[2] && $(<$T/home/.claude.json) == *sekrit-value* && $(<$M/CLAUDE.md) == "main rules" ]] \
  && ok "l5 token/profile.env untouched; main profile sources untouched" || bad "l5"

# ---- idempotent re-run
H1=$(h $F)
out=$(zrun "cprof link pl $M; print RC=\$?"); BK2=(${T}/root/pl/config-backup-*(N/))
[[ $out == *"RC=0" && $out == *"0 linked"* && $out != *"copied:"* && $out != *"backup:"* && $out == *"ok: .mcpServers (in-sync, 2)"* && $out == *"ok: skills (already linked)"* \
   && $#BK2 == 1 && $(h $F) == $H1 ]] \
  && ok "l6 re-run: 0 linked, no copied:, no backup, .claude.json byte-identical" || bad "l6: $out"

# ---- tiered profile
mkprof tr; print -r -- executor > $T/root/tr/tier; print -r -- 'abc /x
rendered zzz' > $T/root/tr/tier.src; print -r -- 'P=1' > $T/root/tr/profile.env
print -r -- '{"rendered":true,"deny":["x"]}' > $T/root/tr/config/settings.json
print -r -- 'tier-owned claude md' > $T/root/tr/config/CLAUDE.md
TH=(${(f)"$(for f in token profile.env tier tier.src config/settings.json config/CLAUDE.md; do h $T/root/tr/$f; done)"})
out=$(zrun "cprof link tr $M; print RC=\$?"); P=$T/root/tr/config
tl=1; for e in skills agents plugins; do [[ -L $P/$e && $(readlink $P/$e) == $M/$e ]] || tl=0; done
[[ $out == *"RC=0" && $tl == 1 && $(grep -c '^linked: ' <<<"$out") == 3 && ! -L $P/settings.json && $(h $P/settings.json) == $TH[5] \
   && $out == *"kept: settings.json (tiered: rendered file)"* && $out == *"skip: CLAUDE.md (tiered: global rules file stays excluded)"* \
   && $out == *"cprof: linked 'tr' (4 linked, 1 ok, 1 skipped)"* ]] \
  && ok "l7 tiered: 3 links + mcp merge, settings.json kept, CLAUDE.md skipped with message" || bad "l7: $out"
[[ ! -L $P/CLAUDE.md && $(h $P/CLAUDE.md) == $TH[6] && $(h $T/root/tr/token) == $TH[1] && $(h $T/root/tr/profile.env) == $TH[2] \
   && $(h $T/root/tr/tier) == $TH[3] && $(h $T/root/tr/tier.src) == $TH[4] && -d $T/root/tr/workspace ]] \
  && ok "l8 tiered: existing CLAUDE.md left as is; token/profile.env/tier/tier.src byte-identical" || bad "l8"
mkprof tr2; print executor > $T/root/tr2/tier
out=$(zrun "cprof link tr2 $M"); [[ ! -e $T/root/tr2/config/CLAUDE.md && ! -L $T/root/tr2/config/CLAUDE.md && $out == *"(4 linked, "* ]] \
  && ok "l9 tiered with no CLAUDE.md creates none" || bad "l9: $out"

# ---- source absent -> skip; main profile is $HOME/.claude even inside another profile
mv $M/agents $T/agents.away; mkprof sk
out=$(zrun "export CLAUDE_CONFIG_DIR=/nonexistent/other; cprof link sk $M; print RC=\$?"); mv $T/agents.away $M/agents
[[ $out == *"RC=0" && $out == *"skip: agents (none in $M)"* && ! -e $T/root/sk/config/agents && -L $T/root/sk/config/skills \
   && $(readlink $T/root/sk/config/skills) == $M/skills ]] \
  && ok "l10 absent source -> skip (nothing created); \$CLAUDE_CONFIG_DIR ignored" || bad "l10: $out"

# ---- main without .mcpServers -> skip, profile .claude.json untouched
mkprof nm; print -r -- '{"k":1}' > $T/root/nm/config/.claude.json; mv $T/home/.claude.json $T/cj.away; print -r -- '{"userID":"u"}' > $T/home/.claude.json
out=$(zrun "cprof link nm $M; print RC=\$?"); rm -f $T/home/.claude.json; mv $T/cj.away $T/home/.claude.json
[[ $out == *"RC=0" && $out == *"skip: .mcpServers"* && $(<$T/root/nm/config/.claude.json) == '{"k":1}' ]] && ok "l11 main without .mcpServers -> skip" || bad "l11: $out"

# ---- errors
out=$(zrun 'cprof link; print RC=$?'); [[ $out == *usage*"RC=1" ]] && ok "l12 no name -> usage, exit 1" || bad "l12: $out"
out=$(zrun 'cprof link ../x; print RC=$?'); [[ $out == *"invalid profile name"*"RC=1" ]] && ok "l13 invalid name -> exit 1" || bad "l13: $out"
out=$(zrun 'cprof link nosuch; print RC=$?'); [[ $out == *"no such profile"*"RC=1" && ! -e $T/root/nosuch ]] && ok "l14 unknown profile -> error, exit 1" || bad "l14: $out"
mkprof nj; print -r -- 'plain' > $T/root/nj/config/CLAUDE.md; mkdir -p $T/nobin
out=$(env $CLEAN HOME=$T/home CPROF_ROOT=$T/root PATH=$T/nobin ${commands[zsh]:-/bin/zsh} -fc "source $SRC/cprof.zsh; cprof link nj; print RC=\$?" 2>&1 </dev/null)
[[ $out == *"jq"*"RC=1" && ! -L $T/root/nj/config/CLAUDE.md && $(<$T/root/nj/config/CLAUDE.md) == plain && -z ${(M)${(f)"$(ls $T/root/nj)"}:#config-backup*} ]] \
  && ok "l15 jq missing -> exit 1, nothing changed" || bad "l15: $out"
mkprof bj; print -r -- '{not json' > $T/root/bj/config/.claude.json
out=$(zrun "cprof link bj $M; print RC=\$?"); [[ $out == *"RC=1" && $(<$T/root/bj/config/.claude.json) == '{not json' ]] && ok "l16 invalid profile .claude.json -> exit 1, left untouched" || bad "l16: $out"
mv $T/home/.claude.json $T/cj.away; print -r -- '{bad' > $T/home/.claude.json; mkprof bm
out=$(zrun "cprof link bm $M; print RC=\$?"); rm -f $T/home/.claude.json; mv $T/cj.away $T/home/.claude.json
[[ $out == *"RC=1" ]] && ok "l17 invalid ~/.claude.json -> exit 1" || bad "l17: $out"
# same-second backup dir already exists -> exit 1, nothing changed
mkdir -p $T/fakebin; print -r -- '#!/bin/sh
echo 20260101T000000Z' > $T/fakebin/date; chmod +x $T/fakebin/date
mkprof sd; print -r -- keep > $T/root/sd/config/CLAUDE.md; mkdir $T/root/sd/config-backup-20260101T000000Z
out=$(env $CLEAN HOME=$T/home CPROF_ROOT=$T/root PATH=$T/fakebin:$T/bin:/usr/bin:/bin:/opt/homebrew/bin zsh -fc "source $SRC/cprof.zsh; cprof link sd $M; print RC=\$?" 2>&1 </dev/null)
[[ $out == *"RC=1" && ! -L $T/root/sd/config/CLAUDE.md && $(<$T/root/sd/config/CLAUDE.md) == keep ]] && ok "l18 existing same-stamp backup dir -> exit 1, nothing changed" || bad "l18: $out"

# ---- M4: no 2nd arg and the default root does not exist yet -> explicit WARN, graceful all-skip, RC=0
mkprof nodef
out=$(zrun 'cprof link nodef; print RC=$?')
[[ $out == *"WARN: default source root '$T/home/projects/agent-hq' does not exist; every entry will skip"* && $out == *"RC=0"* \
   && $out == *"cprof: linked 'nodef' (0 linked, 0 ok, "* && ! -e $T/root/nodef/config/CLAUDE.md && ! -L $T/root/nodef/config/CLAUDE.md ]] \
  && ok "d0 default root missing -> explicit WARN + graceful all-skip, nothing created (M4)" || bad "d0: $out"

# ---- dynamic source root (Extension 2026-10-27): default -> ~/projects/agent-hq, explicit override, graceful skips, bad root
AH=$T/home/projects/agent-hq
mkdir -p $AH/config $AH/skills $AH/agents
print -r -- "hq rules" > $AH/config/CLAUDE.md; print -r -- '{"theme":"hq"}' > $AH/config/settings.json
print -r -- x > $AH/skills/hqskill.md; print -r -- x > $AH/agents/hqagent.md
( cd $AH && git init -q && git -c user.email=t@t -c user.name=t add -A \
  && git -c user.email=t@t -c user.name=t commit -q -m init )
AHSHA=$(git -C $AH rev-parse HEAD)

mkprof ah
out=$(zrun 'cprof link ah; print RC=$?'); P=$T/root/ah/config
okl=1; for e in CLAUDE.md skills agents settings.json; do [[ -L $P/$e ]] || okl=0; done
[[ $out == *"RC=0" && $okl == 1 && $(readlink $P/CLAUDE.md) == $AH/config/CLAUDE.md && $(readlink $P/settings.json) == $AH/config/settings.json \
   && $(readlink $P/skills) == $AH/skills && $(readlink $P/agents) == $AH/agents ]] \
  && ok "d1 no 2nd arg -> default root ~/projects/agent-hq: config/CLAUDE.md, config/settings.json, top-level skills/, agents/" || bad "d1: $out"
[[ $out == *"skip: plugins (none in $AH)"* && ! -e $P/plugins && ! -L $P/plugins ]] \
  && ok "d2 plugins skips gracefully (agent-hq has no plugins/)" || bad "d2: $out"
[[ $out == *"skip: .mcpServers (no $T/home/projects/agent-hq.json)"* ]] \
  && ok "d3 .mcpServers skips gracefully (agent-hq has no sibling .json)" || bad "d3: $out"
[[ $out == *"cprof: linked 'ah' (4 linked, 0 ok, 2 skipped)"* ]] \
  && ok "d4 summary: 4 linked, 2 skipped (plugins + mcpServers), 0 ok" || bad "d4: $out"
# A3: resolved root + the root's git HEAD are recorded in a new sibling `link-src` file
[[ $(<$T/root/ah/link-src) == "root $AH
commit $AHSHA" ]] \
  && ok "d4a link-src records the resolved root and its git HEAD (A3 audit trail)" || bad "d4a: $(<$T/root/ah/link-src)"

mkprof flat
out=$(zrun "cprof link flat ~/.claude; print RC=\$?"); P=$T/root/flat/config
okl=1; for e in CLAUDE.md skills agents plugins settings.json; do [[ -L $P/$e && $(readlink $P/$e) == $M/$e ]] || okl=0; done
[[ $out == *"RC=0" && $okl == 1 && $out == *"cprof: linked 'flat' (6 linked, 0 ok, 0 skipped)"* && $out != *"WARN: merging .mcpServers"* ]] \
  && ok "d5 explicit '~/.claude' override still links the old flat layout (all 5 entries + mcpServers), no M5 warning (default root is \$HOME/.claude)" || bad "d5: $out"
[[ $(<$T/root/flat/link-src) == "root $M" ]] \
  && ok "d5a link-src for a non-git root (\$HOME/.claude here) records only the root, no commit line" || bad "d5a: $(<$T/root/flat/link-src)"

mkprof badroot
out=$(zrun 'cprof link badroot /nonexistent/nowhere; print RC=$?')
[[ $out == *"no such source: '/nonexistent/nowhere'"* && $out == *"RC=1" && ! -e $T/root/badroot/config/CLAUDE.md && ! -L $T/root/badroot/config/CLAUDE.md ]] \
  && ok "d6 nonexistent explicit source-root -> clear error, exit 1, nothing changed" || bad "d6: $out"

# ---- M3: doctor reports a profile linked from a non-$HOME/.claude root correctly (not other-link)
out=$(zrun 'cprof doctor --no-claude')
[[ $out == *"ah: CLAUDE.md=linked skills=linked agents=linked plugins=- settings.json=linked; mcpServers=missing:a,b"* ]] \
  && ok "d7 doctor reports 'ah' (linked from the agent-hq default) as linked, not other-link (M2)" || bad "d7: $out"

# ---- M5 (security): merging .mcpServers from a non-default root prints an explicit warning first
OR=$T/home/other-root
mkdir -p $OR/skills $OR/agents
print -r -- "or rules" > $OR/CLAUDE.md; print -r -- '{"theme":"or"}' > $OR/settings.json
print -r -- '{"mcpServers":{"z":{"command":"zcmd","args":["--run"]}}}' > $T/home/other-root.json
mkprof orp
out=$(zrun "cprof link orp $OR; print RC=\$?")
[[ $out == *"WARN: merging .mcpServers from a non-default root ($T/home/other-root.json)"* && $out == *"not secret-scrubbed"* \
   && $out == *"copied: .mcpServers (1: z)"* && $out == *"RC=0"* ]] \
  && ok "m5 non-default-root .mcpServers merge prints an explicit warning before merging (M5)" || bad "m5: $out"

# ---- doctor link rows + help
out=$(zrun 'cprof doctor --no-claude')
[[ $out == *"-- link rows (main-profile links) --"* && $out == *"pl: CLAUDE.md=linked skills=linked agents=linked plugins=linked settings.json=linked; mcpServers=in-sync(2)"* \
   && $out == *"tr: CLAUDE.md=file skills=linked agents=linked plugins=linked settings.json=rendered; mcpServers=in-sync(2)"* \
   && $out == *"tr2: CLAUDE.md=- skills=linked"* && $out == *"sd: CLAUDE.md=file skills=- agents=- plugins=- settings.json=-; mcpServers=missing:a,b"* ]] \
  && ok "l19 doctor link rows (linked/file/-/rendered/in-sync/missing)" || bad "l19: $out"
ln -sfn /elsewhere $T/root/pl/config/agents; out=$(zrun 'cprof doctor --no-claude'); [[ $out == *"pl: CLAUDE.md=linked skills=linked agents=other-link"* ]] && ok "l20 doctor other-link" || bad "l20: $out"
mv $T/home/.claude.json $T/cj.away; print -r -- '{}' > $T/home/.claude.json; out=$(zrun 'cprof doctor --no-claude'); rm -f $T/home/.claude.json; mv $T/cj.away $T/home/.claude.json
[[ $out == *"nm: "*"mcpServers=absent"* ]] && ok "l21 doctor mcpServers=absent when main has none" || bad "l21: $out"
out=$(env $CLEAN HOME=$T/home CPROF_ROOT=$T/root PATH=$T/nobin ${commands[zsh]:-/bin/zsh} -fc "source $SRC/cprof.zsh; cprof doctor --no-claude" 2>&1 </dev/null)
[[ $out == *"WARN: link rows skipped: jq not installed"* ]] && ok "l22 doctor WARNs when jq is absent" || bad "l22: $out"
out=$(zrun 'cprof help'); [[ $out == *"cprof link <name>"* ]] && ok "l23 help lists link" || bad "l23"

(( fails )) && { print "$fails failure(s)"; exit 1; }
exit 0
