"""Transactional writer for import-learnings (imported by import_learnings.py; not run directly)."""
import os, sys

TMP_NAME = ".SKILL.md.import-tmp"


def read_old(out):
    """Existing file text, or None when absent; raises ValueError when unreadable as UTF-8 text."""
    if not os.path.isfile(out):
        return None
    try:
        with open(out, encoding="utf-8") as fh:
            return fh.read()
    except (OSError, UnicodeDecodeError) as e:
        raise ValueError(type(e).__name__)


def _mkdirs(path, created):
    """makedirs that records each directory THIS run creates (outermost first)."""
    missing = []
    while path and not os.path.isdir(path):
        missing.append(path)
        path = os.path.dirname(path)
    for d in reversed(missing):
        os.mkdir(d)
        created.append(d)


def _put(tmp, content, track):
    """Create tmp exclusively and write it. O_EXCL|O_NOFOLLOW: a pre-existing file or symlink at that name makes
    the open fail and is never followed or touched. tmp joins `track` only once THIS call created it, so cleanup
    can never delete a file the run did not create."""
    fd = os.open(tmp, os.O_WRONLY | os.O_CREAT | os.O_EXCL | getattr(os, "O_NOFOLLOW", 0), 0o644)
    track.append(tmp)
    with os.fdopen(fd, "w", encoding="utf-8") as fh:
        fh.write(content)


def write_all(plan):
    """plan: [(status, out, content, old)]. Temp files first, then renames. On any OSError: restore the files
    already renamed (new -> removed, update -> old content), remove temps and directories this run created, and
    report what happened. Returns 0 or 1."""
    temps, done, created = [], [], []
    try:
        for st, out, content, old in plan:
            _mkdirs(os.path.dirname(out), created)
            tmp = os.path.join(os.path.dirname(out), TMP_NAME)
            _put(tmp, content, temps)
        for (st, out, content, old), tmp in zip(plan, temps):
            os.replace(tmp, out)
            done.append((st, out, old))
    except Exception as e:   # OSError, or anything else raised while writing: always clean up and exit 1
        print(f"error: write failed ({type(e).__name__}: {e}); rolling back", file=sys.stderr)
        failed = []
        for st, out, old in reversed(done):
            try:
                if old is None:
                    os.remove(out)
                else:
                    rb = []
                    try:
                        _put(out + ".rb", old, rb)
                        os.replace(out + ".rb", out)
                    finally:
                        for t in rb:
                            if os.path.lexists(t):
                                os.remove(t)
            except Exception:
                failed.append(out)
        for t in temps:
            if os.path.lexists(t):
                try:
                    os.remove(t)
                except Exception:
                    failed.append(t)
        for d in reversed(created):
            try:
                os.rmdir(d)
            except Exception:
                pass
        print(f"already renamed before the failure: {[o for _, o, _ in done] or 'none'}", file=sys.stderr)
        print(f"rollback incomplete, check by hand: {failed}" if failed else "rollback complete", file=sys.stderr)
        return 1
    return 0
