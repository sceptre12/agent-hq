#!/bin/zsh
# hermes pre_tool_call hook (fail-closed). Stdin JSON {tool_name, tool_input{path,..}, cwd}. Block = exit 2 + JSON.
# Writes (write_file, patch): ONLY under $HERMES_HOME/work/. Reads: denylist. search_files roots: HERMES_HOME/work, HERMES_HOME/sessions, ~/claude-profiles/hermes/hq only.
# Matching is on realpath, lowercased (APFS is case-insensitive). Any internal error -> block.
block() { print -r -- "{\"action\":\"block\",\"message\":\"hq-gate: $1\"}"; exit 2; }
[[ -n "${HERMES_HOME:-}" && -d "$HERMES_HOME" ]] || block "HERMES_HOME unset"
HERMES_HOME_RESOLVED=$(cd "$HERMES_HOME" 2>/dev/null && pwd -P) || block "HERMES_HOME unresolved"
export HERMES_HOME_RESOLVED
out=$(/usr/bin/python3 -I -c '
import sys,os,json
try:
    d=json.load(sys.stdin); t=d.get("tool_name") or ""; a=d.get("tool_input") or {}
    cwd=d.get("cwd") or os.getcwd(); home=os.path.realpath(os.path.expanduser("~"))
    hh=os.environ["HERMES_HOME_RESOLVED"]; L=lambda s:s.lower()
    p=a.get("path")
    if (not isinstance(p,str) or not p):
        if t=="search_files": p=cwd
        else: print("BLOCK no path arg"); sys.exit(0)
    r=L(os.path.realpath(os.path.join(cwd,os.path.expanduser(p)))); H=L(hh); HM=L(home)
    def under(x,b): return x==b or x.startswith(b.rstrip("/")+"/")
    cp=HM+"/claude-profiles/"
    if r.startswith(HM+"/.claude") or under(r,HM+"/library/keychains") or r.startswith(H+"/.env") or r.startswith(H+"/auth"):
        print("BLOCK denied path"); sys.exit(0)
    if r.startswith(cp):
        rest=r[len(cp):].split("/")
        if len(rest)>=2 and (rest[1].startswith("token") or rest[1].startswith("config")): print("BLOCK denied path"); sys.exit(0)
    if t in ("write_file","patch"):
        if not under(r,H+"/work"): print("BLOCK write outside HERMES_HOME/work"); sys.exit(0)
        if t=="patch" and a.get("mode")=="patch": print("BLOCK multi-file patch mode"); sys.exit(0)
    if t=="search_files":
        # roots confined to work/, sessions/ (hermes_state.py:437) and the hq snapshot; HERMES_HOME itself or any ancestor of auth.json/.env/config.yaml is refused
        if not (under(r,H+"/work") or under(r,H+"/sessions") or under(r,cp+"hermes/hq")): print("BLOCK search root not allowed"); sys.exit(0)
    print("OK")
except Exception: print("BLOCK internal error")
' 2>/dev/null) || block "checker failed"
[[ "$out" == OK ]] || block "${out#BLOCK }"
exit 0
