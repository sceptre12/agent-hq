"""Bundled-source comparison for verify-import (--bundled-source). Read-only; imported by verify_import.py.

An allowed extra whose counterpart exists under the bundled-source dir is compared as a TREE (lstat, never following
links): same relative entries (files and directories), same bytes per file, no symlink or special file on either side.
Only differences' relative paths are returned, never content."""
import filecmp, os, stat
from il_guard import refuse_live, under


def check_dir(d, target, label="source dir"):
    """None when d is usable, else (exit_code, reason): 2 = bad argument, 3 = live Hermes home. The owner flag never applies."""
    if not os.path.isabs(d):
        return 2, f"--bundled-source {d!r}: must be an absolute path"
    why = refuse_live(d, False, label)   # il_guard: is, inside or contains the live home; deliberately NOT relaxed by --i-am-the-owner-live
    if why:
        return 3, f"--bundled-source {why}"
    if os.path.islink(d.rstrip("/") or "/"):
        return 2, f"--bundled-source {d!r}: is a symlink; pass the real directory"
    if not os.path.isdir(d):
        return 2, f"--bundled-source {d!r}: not an existing directory"
    if under(d, target):
        return 2, f"--bundled-source {d!r}: equals or lies inside the target"
    return None


def _kind(p):
    m = os.lstat(p).st_mode
    return "l" if stat.S_ISLNK(m) else "d" if stat.S_ISDIR(m) else "f" if stat.S_ISREG(m) else "o"


def _tree(root):
    """{relpath ('' = root): kind}; directories are entered only when they are real directories (never via a link)."""
    out = {"": _kind(root)}
    todo = [""] if out[""] == "d" else []
    while todo:
        r = todo.pop()
        for n in sorted(os.listdir(os.path.join(root, r))):
            rel = os.path.join(r, n)
            out[rel] = _kind(os.path.join(root, rel))
            if out[rel] == "d":
                todo.append(rel)
    return out


def diff(src, dst, rel):
    """Sorted relative names (prefixed by rel) that differ between src and dst trees; [] means byte-identical trees."""
    a, b = _tree(src), _tree(dst)
    bad = []
    for k in sorted(set(a) | set(b)):
        ka, kb = a.get(k), b.get(k)
        why = ("missing-in-target" if kb is None else "extra-in-target" if ka is None else
               "symlink-in-source" if ka == "l" else "symlink-in-target" if kb == "l" else
               "special-file" if "o" in (ka, kb) else "type-differs" if ka != kb else
               "bytes-differ" if ka == "f" and not filecmp.cmp(os.path.join(src, k) if k else src, os.path.join(dst, k) if k else dst, shallow=False) else None)
        if why:
            bad.append(f"{os.path.join(rel, k) if k else rel}({why})")
    return bad


def layout_problem(root, rel):
    """Reason when a PARENT component of rel under root is a symlink, or the path leaves realpath(root); else None."""
    parts, cur = rel.split("/"), root
    for part in parts[:-1]:
        cur = os.path.join(cur, part)
        if os.path.islink(cur):
            return "symlinked-parent"
    full = os.path.join(root, rel)
    if not os.path.islink(full) and os.path.lexists(full) and not under(os.path.realpath(full), os.path.realpath(root)):
        return "outside-root"
    return None


def compare(source_dir, target, allowed):
    """(identical extras set, problems list) over the allowed extras that exist under source_dir."""
    same, bad = set(), []
    for al in sorted(allowed):
        sp = os.path.join(source_dir, al)
        if not os.path.lexists(sp):
            continue
        tp = os.path.join(target, al)
        lay = layout_problem(source_dir, al) or layout_problem(target, al)
        if lay:
            bad.append(f"{al}({lay})")
            continue
        d = diff(sp, tp, al) if os.path.lexists(tp) else [f"{al}(missing-in-target)"]
        if d:
            bad += d
        else:
            same.add(al)
    return same, bad
