#!/usr/bin/env zsh
# tools/claude-profile/test_cprof-checks.zsh — tests for cprof-checks.zsh (excludes + doctor).
# Hermetic: HOME and CPROF_ROOT point into a mktemp dir; `claude` is a stub on PATH; the user's
# zsh config is never loaded (zsh -f); ~/claude-profiles, ~/.claude and ~/.zshrc are never touched.
SRC=${0:A:h}
T=$(mktemp -d) || exit 1
trap 'chmod -R u+rwx "$T" 2>/dev/null; rm -rf "$T"' EXIT
mkdir -p "$T/bin" "$T/home" "$T/root"
fails=0
ok()   { print -r -- "ok   $1"; }
bad()  { print -r -- "FAIL $1"; fails=$((fails+1)); }
# zrun '<zsh code>' -> runs after sourcing cprof.zsh in a clean, hermetic zsh
zrun() { env HOME=$T/home CPROF_ROOT=$T/root PATH=$T/bin:/usr/bin:/bin:/usr/local/bin:/opt/homebrew/bin \
         zsh -fc "source $SRC/cprof.zsh; $1" 2>&1 </dev/null; }
command -v jq >/dev/null || { print "SKIP: jq missing"; exit 0; }

# Stub claude: logs argv, prints canned /context table for `-p /context`.
cat > $T/bin/claude <<STUB
#!/bin/sh
echo "\$*" >> "$T/claude.args"
case "\$*" in *"/context"*) cat "$T/context.txt" ;; esac
exit 0
STUB
chmod +x $T/bin/claude
cat > $T/context.txt <<'CTX'
### Memory Files
| Type | Path | Tokens |
| --- | --- | --- |
|  User  |  /outside/other/CLAUDE.md  | 12 |
| Project | CFGDIR/CLAUDE.md | 3 |
### Skills
| x | y |
CTX
mkdir -p $T/cfg $T/work
sed -i '' "s#CFGDIR#$T/cfg#" $T/context.txt

# Defect 1: doctor trims /context path cells and skips `| --- |` separator rows.
out=$(zrun "export CLAUDE_CONFIG_DIR=$T/cfg; cd $T/work; cprof doctor")
[[ $out == *"WARN: memory file outside \$CLAUDE_CONFIG_DIR and cwd: /outside/other/CLAUDE.md"$'\n'* ]] \
  && ok "1a path trimmed (no stray spaces)" || bad "1a path trimmed: $out"
[[ $out != *"outside"*"---"* ]] && ok "1b separator row skipped" || bad "1b separator row WARNed: $out"
[[ $out != *"WARN: memory file outside"*"$T/cfg/CLAUDE.md"* ]] && ok "1c in-config row not WARNed" || bad "1c in-config row WARNed"

# Defect 8: the init-event call passes --no-session-persistence.
grep -q -- '-p hi .*--no-session-persistence' $T/claude.args \
  && ok "8 claude -p hi has --no-session-persistence" || bad "8 args: $(<$T/claude.args)"

# Defect 2: unreadable settings.json -> fail closed, file untouched.
mkdir -p $T/c2; print -r -- '{"keep":1}' > $T/c2/settings.json; chmod 000 $T/c2/settings.json
zrun "_cprof_apply_excludes $T/c2" >/dev/null; rc=$?
chmod 600 $T/c2/settings.json
(( rc != 0 )) && ok "2a returns non-zero" || bad "2a rc=$rc"
[[ $(<$T/c2/settings.json) == '{"keep":1}' ]] && ok "2b settings.json untouched" || bad "2b clobbered: $(<$T/c2/settings.json)"

# Defect 9: excludes include $HOME/CLAUDE.md and $HOME/CLAUDE.local.md.
mkdir -p $T/c9
zrun "_cprof_apply_excludes $T/c9" >/dev/null
for f in CLAUDE.md CLAUDE.local.md; do
  jq -e --arg p "$T/home/$f" '.claudeMdExcludes | index($p)' $T/c9/settings.json >/dev/null \
    && ok "9 excludes \$HOME/$f" || bad "9 missing \$HOME/$f: $(<$T/c9/settings.json)"
done

# Defect 5: symlinked ancestor — a resolved-path exclude must match (:A resolution, not substitution).
mkdir -p $T/real/proj; : > $T/real/proj/CLAUDE.md; ln -s $T/real $T/link
mkdir -p $T/cfg5; print -r -- "{\"claudeMdExcludes\":[\"${T:A}/real/proj/CLAUDE.md\"]}" > $T/cfg5/settings.json
out=$(zrun "export CLAUDE_CONFIG_DIR=$T/cfg5; cd $T/link/proj; cprof doctor --no-claude")
[[ $out == *"EXCLUDED: $T/link/proj/CLAUDE.md"* ]] && ok "5 symlinked path matched via :A" || bad "5: $out"

(( fails )) && { print "$fails failure(s)"; exit 1; }
exit 0
