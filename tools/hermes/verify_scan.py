"""Filesystem side of verify-import: layout scan, bounded symlink-safe reads, tree digest. Read-only; imported by verify_import.py."""
import hashlib, os, stat
from import_learnings import BODY_MAX
from il_write import TMP_NAME

# The importer refuses any rendered skill longer than BODY_MAX characters (import_learnings.py:148; BODY_MAX=100_000 from
# Hermes skill_manager_tool.py:110). The count includes frontmatter and footer; UTF-8 is at most 4 bytes per character.
READ_MAX = 4 * BODY_MAX


class Unsafe(Exception):
    """A path the verifier refuses to open or read; str(e) is the short reason shown in the report."""


def read_regular(path):
    """Bytes of a regular file. lstat first (a symlink, FIFO, device or directory is refused without opening it), then
    open with O_NOFOLLOW|O_NONBLOCK (no hang on a swapped-in FIFO), fstat the descriptor, and read at most READ_MAX+1 bytes."""
    try:
        mode = os.lstat(path).st_mode
    except OSError:
        raise Unsafe("unreadable")
    if stat.S_ISLNK(mode):
        raise Unsafe("symlink")
    if not stat.S_ISREG(mode):
        raise Unsafe("not-regular-file")
    try:
        fd = os.open(path, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK)
    except OSError:
        raise Unsafe("unreadable")
    with os.fdopen(fd, "rb") as fh:
        if not stat.S_ISREG(os.fstat(fh.fileno()).st_mode):
            raise Unsafe("not-regular-file")
        data = fh.read(READ_MAX + 1)
    if len(data) > READ_MAX:
        raise Unsafe("oversize")
    return data


def _stray(rel, p):
    """Label for something that is not a directory where a directory belongs."""
    mode = os.lstat(p).st_mode
    if stat.S_ISLNK(mode):
        return f"{rel}(stray-symlink)"
    return f"{rel}(stale-import-tmp)" if os.path.basename(p) == TMP_NAME else f"{rel}(stray-file)"


def _isdir(p):
    return stat.S_ISDIR(os.lstat(p).st_mode)


def _extra(rel, p):
    """(files {relpath: bytes}, problems, n_skill_md) for one allowed extra; symlinks are never followed and FAIL."""
    files, bad, nskill = {}, [], 0
    if not os.path.lexists(p):
        return files, bad, nskill
    todo, parts = [], rel.split("/")
    for i in range(1, len(parts)):   # a symlinked parent component would route the walk outside the target
        if os.path.islink(os.path.join(p[:len(p) - len(rel)], *parts[:i])):
            return files, [f"{rel}(symlinked-parent)"], nskill
    if _isdir(p):
        for d, dn, fs in os.walk(p, followlinks=False):
            todo += [os.path.join(d, n) for n in fs] + [os.path.join(d, n) for n in dn if os.path.islink(os.path.join(d, n))]
    else:
        todo = [p]
    for f in sorted(todo):
        r = os.path.join(rel, os.path.relpath(f, p)) if f != p else rel
        try:
            files[r] = read_regular(f)
            nskill += os.path.basename(f) == "SKILL.md"
        except Unsafe as e:
            bad.append(f"{r}({e})")   # a symlink at or under an allowed extra is never followed, so it FAILs (N1)
    return files, bad, nskill


def scan(target, allowed):
    """Walk <target>/<category>/<name>/SKILL.md. Returns (found {rel: bytes|None}, layout problems, extras).
    found is None for a SKILL.md that is refused (symlink, FIFO, oversize); its reason is in the problems.
    Exact-match entries in `allowed` are skipped here and read separately: extras {rel: (files, problems, n_skill_md)}."""
    found, bad = {}, []
    for cat in sorted(os.listdir(target)):
        cp = os.path.join(target, cat)
        if cat in allowed:
            continue
        if not _isdir(cp):
            bad.append(_stray(cat, cp))
            continue
        kids = sorted(os.listdir(cp))
        if not kids:
            bad.append(f"{cat}(empty-category)")
        for nm in kids:
            rel, p = f"{cat}/{nm}", os.path.join(cp, nm)
            if rel in allowed:
                continue
            if not _isdir(p):
                bad.append(_stray(rel, p))
                continue
            listing = sorted(os.listdir(p))
            if "SKILL.md" not in listing:
                bad.append(f"{rel}(no-SKILL.md)")
                continue
            try:
                found[rel] = read_regular(os.path.join(p, "SKILL.md"))
            except Unsafe as e:
                found[rel] = None
                bad.append(f"{rel}(SKILL.md-{e})")
            others = [x for x in listing if x != "SKILL.md"]
            if others:
                bad.append(f"{rel}(extra-files:{','.join(others[:5])}{',...' if len(others) > 5 else ''})")
    extras = {a: _extra(a, os.path.join(target, a)) for a in sorted(allowed)}
    return found, bad, extras


def tree_digest(target):
    rows = []
    for d, dn, fs in os.walk(target, followlinks=False):
        for n in sorted(dn) + sorted(fs):
            st = os.lstat(os.path.join(d, n))
            rows.append(f"{os.path.relpath(os.path.join(d, n), target)}\t{st.st_size}\t{st.st_mtime_ns}\t{st.st_mode}")
    return hashlib.sha256("\n".join(sorted(rows)).encode()).hexdigest()
