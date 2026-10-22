"""Import verifier for import-learnings (architecture/hermes-agent-memory.md section 9 row 7a).

Checks a skills tree written by import-learnings against the hq commit it claims to come from: expected set (inputs /
expected / skipped), count, layout, frontmatter, body (sha256 vs the source blob), secret scan, spot read-back, read-only
proof. STRICTLY READ-ONLY on the target; the hq source is read through git only. Never prints a secret match or a file
body. Run with `python3 -B -I` (the verify-import shim does). No network, no model, no Hermes.
"""
import argparse, os, random, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))   # -I drops the script dir from sys.path
from il_describe import git, has_secret, render, skill_name, category  # noqa: E402
from il_guard import refuse_live, resolve  # noqa: E402
from import_learnings import BODY_MAX, list_inputs  # noqa: E402
from verify_bundled import check_dir, compare  # noqa: E402
from verify_fm import body_ok, check_frontmatter  # noqa: E402
from verify_scan import Unsafe, read_regular, scan, tree_digest  # noqa: E402

CAP = 20
EPILOG = """\
Example (verify an import you just made into a scratch or staging skills dir):
  verify-import /private/tmp/skills-trial --repo ~/projects/agent-hq --sha <the sha the import used> --allow-extra hq-index
--sha must be the SAME commit the import used (default: origin/main of --repo), or the footers will not match.
Layout rule: every <category>/<name>/ holds exactly SKILL.md (regular file, name+description frontmatter only); anything
else FAILs (stray files, empty categories, stale .SKILL.md.import-tmp, extra files) unless named by --allow-extra.
Files the importer skipped (secret-shaped = its exit 7, oversize = exit 6) are listed by name and FAIL the run.
Exit: 0 PASS, 1 FAIL (checks failed), 2 usage / unreadable repo, sha or target / unexpected error, 3 live Hermes home refused.
"""
results = []


def rec(name, bad, detail):
    """bad: list of problems (empty = PASS). Prints only names and reasons, capped."""
    ok = not bad
    shown = ", ".join(bad[:CAP]) + (f", ... (+{len(bad) - CAP} more)" if len(bad) > CAP else "")
    print(f"{'PASS' if ok else 'FAIL'} {name}: {detail}" + ("" if ok else f"; {shown}"))
    results.append(ok)


def expected_set(repo, sha):
    """({category/name: (source path, source bytes, description)}, [(path, why skipped)], n_inputs) for what import-learnings writes:
    list_inputs (import_learnings.py:37-43) minus the files it skips (secret-shaped :142, oversize :148, non-UTF-8 :137)."""
    exp, skipped, inputs = {}, [], list_inputs(repo, sha)
    for p in inputs:
        raw = git(repo, "cat-file", "blob", f"{sha}:{p}")
        try:
            text = raw.decode("utf-8")
        except UnicodeDecodeError:
            skipped.append((p, "non-utf8, importer exit 1"))
            continue
        if has_secret(text):
            skipped.append((p, "secret-shaped, importer exit 7"))
        else:
            content, desc = render(repo, sha, p, text)
            if len(content) > BODY_MAX:
                skipped.append((p, "oversize, importer exit 6"))
            else:
                exp[f"{category(p)}/{skill_name(p)}"] = (p, raw, desc)
    return exp, skipped, len(inputs)


def check_allowed(allowed, exp):
    """Exact-match relative paths only; an entry that is, contains or lies inside an EXPECTED skill is an error."""
    for a in allowed:
        parts = a.split("/")
        if not a or a.startswith("/") or any(x in ("", ".", "..") for x in parts) or any(c in a for c in "*?[]"):
            raise ValueError(f"--allow-extra {a!r}: need an exact relative path (no globs, '..', or leading '/')")
        for k in exp:
            if a == k or k.startswith(a + "/") or a.startswith(k + "/"):
                raise ValueError(f"--allow-extra {a!r} names or overlaps the expected skill {k}")


def run_checks(a, target, repo, sha, allowed):
    before = tree_digest(target)
    exp, skipped, n_in = expected_set(repo, sha)
    check_allowed(allowed, exp)
    bad = [f"{p}({why})" for p, why in skipped]
    if a.expect is not None and a.expect != len(exp):
        bad.append(f"expected {len(exp)} != --expect {a.expect}")
    rec("expected", bad, f"inputs={n_in} expected={len(exp)} skipped={len(skipped)} at {sha[:12]}")
    found, layout, extras = scan(target, allowed)
    miss, extra = sorted(set(exp) - set(found)), sorted(set(found) - set(exp))
    for al in sorted(allowed):
        print(f"ALLOWED extra: {al}" + ("" if os.path.lexists(os.path.join(target, al)) else " (not present)"))
    n_al = sum(e[2] for e in extras.values())
    rec("count", [f"missing:{m}" for m in miss] + [f"extra:{e}" for e in extra],
        f"{len(found)} skills in target, {len(exp)} expected, missing={len(miss)} extra={len(extra)} allowed={n_al}")
    rec("layout", layout + [x for e in extras.values() for x in e[1]],
        "each <category>/<name>/ holds exactly SKILL.md (regular file); no stray files, empty categories or temp files")
    rec("frontmatter", check_frontmatter(exp, found, sha),
        f"{len(found)} folders; keys == name,description; name/description/created_by/footer path@sha")
    mism = [rel for rel, (_, src, _d) in sorted(exp.items()) if rel in found and not body_ok(found[rel], src)]
    rec("body", mism, f"sha256 of body vs source blob at {sha[:12]}")
    texts = {rel: raw for rel, raw in found.items() if raw is not None}
    same, bundled = (compare(a.bundled_source[0], target, allowed) if a.bundled_source else (set(), []))
    for al in sorted(same):
        print(f"ALLOWED extra (identical to source): {al}")
    if a.bundled_source:
        rec("bundled", bundled, f"{len(same)} extras byte-identical to the source tree (secret scan skipped for them)")
    texts.update({r: raw for k, e in extras.items() if k not in same for r, raw in e[0].items()})
    leaks = [f"{rel}(secret-shaped, match not printed)" for rel, raw in sorted(texts.items())
             if has_secret(raw.decode("utf-8", "replace"))]
    rec("secrets", leaks, f"{len(texts)} files scanned with il_describe.SECRET_RES (skills + allowed extras not identical to the bundled source)")
    seed = a.seed if a.seed is not None else random.SystemRandom().randrange(2 ** 31)
    pool = sorted(r for r in exp if found.get(r) is not None)
    pick = random.Random(seed).sample(pool, min(max(a.spot, 0), len(pool)))
    print(f"seed={seed} spot={len(pick)} sample={','.join(pick)}")
    bad = []
    for rel in pick:
        try:
            raw = read_regular(os.path.join(target, rel, "SKILL.md"))   # fresh read-back through the filesystem
        except Unsafe:
            bad.append(rel)
            continue
        if not body_ok(raw, exp[rel][1]):   # equal body hash implies the same first line, so no separate line compare
            bad.append(rel)
    rec("spot", bad, f"{len(pick)} read back through the filesystem: body hash")
    rec("readonly", [] if tree_digest(target) == before else ["target tree changed during verification"],
        "find+stat digest (path,size,mtime,mode) before == after")


def parser():
    ap = argparse.ArgumentParser(prog="verify-import", usage="verify-import TARGET_SKILLS_DIR [options]",
                                 description="Verify a skills tree written by import-learnings against its hq commit (read-only).",
                                 epilog=EPILOG, formatter_class=argparse.RawDescriptionHelpFormatter, allow_abbrev=False)
    ap.add_argument("target", help="skills directory to verify (REQUIRED)")
    ap.add_argument("--repo", help="hq git repo (default: $HQ_REPO, else the repo holding this script) [as import-learnings]",
                    default=os.environ.get("HQ_REPO") or os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
    ap.add_argument("--sha", help="hq commit the import used; must equal the import's sha (default: origin/main of --repo)")
    ap.add_argument("--spot", type=int, default=10, help="random files to read back (default 10)")
    ap.add_argument("--seed", type=int, help="make the sample repeatable (printed as seed=S)")
    ap.add_argument("--expect", type=int, help="owner's pin of the expected skill count; a different count FAILs")
    ap.add_argument("--allow-extra", action="append", default=[], metavar="REL",
                    help="repeatable; exact relative path (e.g. hq-index, .archive) exempt from the count/layout/frontmatter "
                         "rules; still listed as 'ALLOWED extra: REL' and secret-scanned unless --bundled-source holds a byte-identical copy of it; no globs; may not name an expected skill")
    ap.add_argument("--bundled-source", action="append", default=[], metavar="DIR",
                    help="absolute dir of an operator-supplied copy of the Hermes source (the tool does not check its commit); an --allow-extra REL that exists as DIR/REL must be "
                         "byte-identical to it (same files, bytes, no symlinks) and then skips the secret scan, else FAIL; "
                         "extras with no DIR/REL are scanned as before. Once only. Refused (exit 3) if it is, holds or lies in "
                         "the live Hermes home, even with --i-am-the-owner-live (that flag never relaxes this)")
    ap.add_argument("--i-am-the-owner-live", action="store_true", help="owner only: skip the live-home guard (same as import-learnings)")
    return ap


def main(argv):
    try:
        a = parser().parse_args(argv)
    except SystemExit as e:
        return 0 if e.code == 0 else 2
    target = resolve(a.target)
    if len(a.bundled_source) > 1:
        print("error: --bundled-source may be given only once", file=sys.stderr)
        return 2
    why = refuse_live(target, a.i_am_the_owner_live)   # import_learnings.py:106-110
    if why:
        print(f"REFUSED: {why}; nothing read. Next: verify a scratch/staging copy under /private/tmp "
              f"(the owner's live check uses --i-am-the-owner-live)", file=sys.stderr)
        return 3
    if not os.path.isdir(target):
        print(f"error: target is not a directory: {a.target}. Next: pass the skills directory the import wrote.", file=sys.stderr)
        return 2
    if a.bundled_source:
        bad = check_dir(a.bundled_source[0], target)
        if bad:
            print(f"REFUSED: {bad[1]}; nothing read." if bad[0] == 3 else f"error: {bad[1]}", file=sys.stderr)
            return bad[0]
    try:
        try:
            sha = git(a.repo, "rev-parse", "--verify", (a.sha or "origin/main") + "^{commit}").decode().strip()
        except RuntimeError as e:
            print(f"error: cannot resolve {a.sha or 'origin/main'} in repo {a.repo}: {str(e).splitlines()[-1]}\n"
                  f"Next: check --repo/--sha, or run `git -C {a.repo} fetch origin main`.", file=sys.stderr)
            return 2
        run_checks(a, target, a.repo, sha, set(x.rstrip("/") for x in a.allow_extra))
    except ValueError as e:
        print(f"error: {e}", file=sys.stderr)
        return 2
    except Exception as e:   # one-line message, never a traceback (M4)
        print(f"error: {type(e).__name__}: {str(e).splitlines()[0] if str(e) else ''}. Next: check --repo, --sha and the target.", file=sys.stderr)
        return 2
    n, f = len(results), results.count(False)
    print(f"verify-import: {'FAIL' if f else 'PASS'} ({n} checks, {f} failed)")
    return 1 if f else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
