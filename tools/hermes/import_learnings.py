#!/usr/bin/env python3
"""Import hq learnings/ and retros/ into a Hermes skills tree: one skill per file.

Design: architecture/hermes-agent-memory.md section 4 "Import script design" and section 9 row 5.
Run with `python3 -I`: this file is mode 644 on purpose,
only the import-learnings shim (755) starts it, with -I. No network, no model calls, never reads an env or auth file.

What it writes: <target>/<category>/<name>/SKILL.md (layout: Hermes tools/skill_manager_tool.py:7). The category is
the topic folder (learnings/<topic>/x.md -> <topic>), else "learnings" or "retros". Inputs: learnings/**.md and retros/*.md
at one hq commit, read with git (default: origin/main of --repo); every .md file is imported. Four generic files get
a category prefix so the names stay unique: learnings/README.md -> learnings-readme, learnings/METHODOLOGY.md ->
learnings-methodology, retros/README.md -> retros-readme, retros/_TEMPLATE.md -> retros-template (exact full-path
match, case-sensitive; this prefix naming is the brain default under R-q, owner may veto). The original text is
copied verbatim; a footer adds the file's own date and `path@sha`. No `created_by` key is written, so Hermes'
curator does not manage these skills.

Description (generated, <= 1024 chars, deterministic): "Title. summary. Sections: ... Use when the task touches:
X. (Learning|Retro, category, date)". Hermes cuts each description in the system-prompt skill index to 57 chars + "..."
(agent/skill_utils.py:822,831-834), so the title leads; the full text is what skills_list and skill_view show.

Default is a DRY RUN (prints the plan, writes nothing); --apply writes: temp files, then renames; a write error
rolls back the renames and the directories this run created. Files skipped with exit 6 (oversize) or 7
(secret-shaped) are NOT written while the other files ARE; an error (exit 1, 3, 4) before writing writes nothing.
An existing SKILL.md is overwritten only when it carries this script's "Imported from hq" footer; a hand-written or
Hermes-edited one, or an output path that is a symlink, is refused (exit 4). Token-shaped content in an input refuses that file (exit 7 at the end).
Examples:
  import-learnings /private/tmp/skills-trial --limit 10            # dry run
  import-learnings /private/tmp/skills-trial --limit 10 --apply
  import-learnings DIR --files learnings/git-identity-hooks.md --sha <hq-sha> --apply
Exit: 0 ok, 1 error, 2 usage, 3 live-home refusal, 4 refused overwrite (non-imported SKILL.md or symlink), 6 oversize skill(s), 7 secret-shaped file(s).
--i-am-the-owner-live skips every live-home guard by design (owner only).
"""
import argparse, os, re, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))   # -I drops the script dir from sys.path
from il_describe import (DESC_MAX, FOOTER_RE, category, git, has_secret, render, skill_name)  # noqa: E402
from il_write import read_old, write_all  # noqa: E402
from il_guard import live_homes, refuse_live, resolve, under  # noqa: E402

BODY_MAX = 100_000                                   # skill_manager_tool.py:110
NAME_RE = re.compile(r"^[a-z0-9][a-z0-9._-]*$")      # skill_manager_tool.py:112
ROOTS = ("learnings", "retros")


def list_inputs(repo, sha):
    paths = []
    for ent in filter(None, git(repo, "ls-tree", "-r", "-z", sha, "--", *ROOTS).split(b"\0")):
        meta, path = ent.decode().split("\t", 1)
        if meta.split()[0] in ("100644", "100755") and path.endswith(".md"):
            paths.append(path)
    return sorted(paths)


def existing_names(target):
    """{skill name: category} for skills already under target (Hermes resolves a bare name across categories)."""
    found = {}
    if os.path.isdir(target):
        for cat in os.listdir(target):
            for nm in (os.listdir(os.path.join(target, cat)) if os.path.isdir(os.path.join(target, cat)) else []):
                if os.path.isfile(os.path.join(target, cat, nm, "SKILL.md")):
                    found.setdefault(nm, set()).add(cat)
    return found


def main(argv):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter,
                                 allow_abbrev=False)
    ap.add_argument("target", help="skills directory to write into (REQUIRED)")
    ap.add_argument("--apply", action="store_true", help="write (default: dry run)")
    ap.add_argument("--limit", type=int, help="first N inputs in path order")
    ap.add_argument("--files", nargs="+", help="repo-relative input paths (learnings/x.md)")
    ap.add_argument("--repo", default=os.environ.get("HQ_REPO") or
                    os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))),
                    help="hq git repo to read (default: the repo holding this script, or $HQ_REPO)")
    ap.add_argument("--sha", help="hq commit to read (default: origin/main of --repo)")
    ap.add_argument("--i-am-the-owner-live", action="store_true", help="owner only: skip the live-home guards")
    ap.add_argument("--show-live-home", action="store_true", help=argparse.SUPPRESS)
    a = ap.parse_args(argv)
    if a.show_live_home:
        print(live_homes()[0])
        return 0
    target = resolve(a.target)   # once: symlinks, '.', '..', '~' and relative paths are resolved before any check
    why = refuse_live(target, a.i_am_the_owner_live)
    if why:
        print(f"REFUSED: {why}; nothing written", file=sys.stderr)
        return 3
    try:
        sha = git(a.repo, "rev-parse", "--verify", (a.sha or "origin/main") + "^{commit}").decode().strip()
        inputs = list_inputs(a.repo, sha)
    except RuntimeError as e:
        print(f"error: {e}", file=sys.stderr)
        return 1
    if a.files:
        for f in a.files:
            if f not in inputs:
                print(f"skip (not an input): {f}")
        inputs = [p for p in inputs if p in set(a.files)]
    if a.limit is not None:
        inputs = inputs[:max(a.limit, 0)]
    names = {}
    for p in inputs:
        names.setdefault(skill_name(p), []).append(p)
    clash = {n: ps for n, ps in names.items() if len(ps) > 1}
    seen = existing_names(target)
    clash.update({n: [category(p) + "/" + n, "existing in " + ",".join(sorted(seen[n]))]
                  for p in inputs for n in [skill_name(p)] if n in seen and seen[n] - {category(p)}})
    if clash:
        print(f"error: skill name collision: {clash}; nothing written", file=sys.stderr)
        return 1
    counts, oversize, secrets, plan = {"new": 0, "unchanged": 0, "update": 0}, [], [], []
    print(f"# import-learnings {'APPLY' if a.apply else 'DRY RUN'} sha={sha} target={target} inputs={len(inputs)}")
    for p in inputs:   # phase 1: read, render and check EVERYTHING; nothing is written until all pass
        try:
            text = git(a.repo, "cat-file", "blob", f"{sha}:{p}").decode("utf-8")
        except (UnicodeDecodeError, RuntimeError) as e:
            print(f"error: cannot read {p} as UTF-8 text ({type(e).__name__}); nothing written", file=sys.stderr)
            return 1
        if has_secret(text):
            secrets.append(p)
            print(f"SECRET-SHAPED\t{p}\tnot imported (match not printed)")
            continue
        content, desc = render(a.repo, sha, p, text)
        out = os.path.join(target, category(p), skill_name(p), "SKILL.md")
        if len(content) > BODY_MAX:
            oversize.append(p)
            print(f"OVERSIZE\t{p}\t{len(content)} chars > {BODY_MAX}; not imported")
            continue
        if not NAME_RE.match(skill_name(p)) or not category(p) or len(desc) > DESC_MAX:
            print(f"error: invalid name/category/description for {p}; nothing written", file=sys.stderr)
            return 1
        if not a.i_am_the_owner_live and any(under(out, lv) for lv in live_homes()):
            print(f"REFUSED: output path for {p} resolves into the live Hermes home; nothing written", file=sys.stderr)
            return 3
        if os.path.islink(out):   # symlink (broken or not): refuse like a non-imported file; touch nothing
            print(f"REFUSED-OVERWRITE\t{out}\toutput path is a symlink; nothing written", file=sys.stderr)
            return 4
        try:
            old = read_old(out)
        except ValueError as e:
            print(f"REFUSED-OVERWRITE\t{out}\tunreadable existing file ({e}); nothing written", file=sys.stderr)
            return 4
        if old is not None and old != content and not FOOTER_RE.search(old):
            print(f"REFUSED-OVERWRITE\t{out}\texisting SKILL.md has no 'Imported from hq' footer; nothing written",
                  file=sys.stderr)
            return 4
        st = "new" if old is None else ("unchanged" if old == content else "update")
        counts[st] += 1
        if st != "unchanged":
            plan.append((st, out, content, old))
        print(f"{st}\t{category(p)}/{skill_name(p)}\t{len(desc)}\t{p}")
    if a.apply and plan and write_all(plan):
        return 1
    print(f"# summary: new={counts['new']} unchanged={counts['unchanged']} update={counts['update']} "
          f"oversize={len(oversize)} secret_shaped={len(secrets)} written={'yes' if a.apply else 'no (dry run)'}")
    return 7 if secrets else (6 if oversize else 0)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
