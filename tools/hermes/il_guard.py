"""Live-home guard for import-learnings (imported by import_learnings.py; not run directly)."""
import os
import pwd

# The home comes from the passwd database, not $HOME, so overriding HOME cannot move the guard.
DEFAULT_LIVE = os.path.join(pwd.getpwuid(os.getuid()).pw_dir, "claude-profiles", "hermes", "h1-home")
TEST_LIVE_ENV = "HERMES_IMPORT_TEST_LIVE_HOME"   # test-only: ADDS one more guarded path; never replaces the default


def resolve(path):
    return os.path.realpath(os.path.expanduser(path))


def live_homes():
    """Guarded paths: the production h1-home, plus the test override when set. All guards are skipped only by
    --i-am-the-owner-live (by design: the owner runs the live import with it)."""
    extra = os.environ.get(TEST_LIVE_ENV)
    return [resolve(DEFAULT_LIVE)] + ([resolve(extra)] if extra else [])


def under(path, root):
    """True when path is root or lies below it. BOTH arguments are resolved (symlinks, '.', '..', relative)."""
    p, r = resolve(path).casefold(), resolve(root).casefold()
    return p == r or p.startswith(r.rstrip(os.sep) + os.sep)


def refuse_live(target, owner_flag, label="target"):
    """Return a refusal reason or None. HERMES_HOME is checked but never used as a default."""
    if owner_flag:
        return None
    hh = os.environ.get("HERMES_HOME")
    for live in live_homes():
        if under(target, live):
            return f"{label} resolves into the live Hermes home ({live})"
        if under(live, target):
            return f"{label} contains the live Hermes home ({live})"
        if hh and under(hh, live):
            return f"HERMES_HOME points at the live Hermes home ({live})"
    return None
