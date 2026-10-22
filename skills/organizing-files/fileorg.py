#!/usr/bin/python3
"""fileorg -- file-organizer Phase 1 CLI.

Single source of truth for ALL index.db reads/writes and taxonomy moves.
Stdlib only, Python 3.9-compatible, zero external dependencies.
Design spec: hq architecture/file-organizer.md (settled).
"""
import argparse
import hashlib
import json
import os
import re
import shutil
import sqlite3
import sys
import time
from pathlib import Path

SCHEMA_VERSION = 1
SYS_UNSORTED = "SYS-Unsorted"
NEEDS_REVIEW_TAG = "needs-review"
JUNK_NAMES = {".DS_Store"}
TOOLING_NAMES = {"Claude", "skills"}
ARCHIVE_EXTS = {".zip", ".tar", ".gz", ".tgz", ".7z"}
FOLDER_CODE_RE = re.compile(r"^([A-Z]{2,4})-(.+)$")
SUBFOLDER_CODE_RE = re.compile(r"^([A-Z]{2,4})-(\d{3})_(.+)$")


def get_db_path():
    """The ONE canonical DB path resolver (spec section 4). Env override for tests."""
    env = os.environ.get("FILEORG_DB_PATH")
    if env:
        return Path(env)
    xdg = os.environ.get("XDG_DATA_HOME")
    base = Path(xdg) if xdg else Path.home() / ".local" / "share"
    return base / "file-organizer" / "index.db"


def get_documents_root():
    """Documents root; injectable via FILEORG_DOCUMENTS_ROOT for tests."""
    env = os.environ.get("FILEORG_DOCUMENTS_ROOT")
    if env:
        return Path(env)
    return Path.home() / "Documents"


def get_sweep_lock_path():
    """PID-file lock path for `sweep` (spec section 11.1). Lives beside the
    index DB in the Layer-2 file-organizer data dir. In production (no
    FILEORG_DB_PATH override) this resolves to exactly
    ${XDG_DATA_HOME:-~/.local/share}/file-organizer/sweep.lock; tests inject
    it via FILEORG_DB_PATH, same as load_codes/load_protected_paths."""
    return get_db_path().parent / "sweep.lock"


def get_sweep_log_path():
    """Append-mode summary log path for `sweep` (spec section 11.1/11.2
    step 5). In production this resolves to exactly
    ${XDG_DATA_HOME:-~/.local/share}/file-organizer/logs/sweep.log -- never
    under ~/Documents, never under hq's git tree."""
    return get_db_path().parent / "logs" / "sweep.log"


def read_lock_pid(lock_path):
    """Return the int PID recorded in `lock_path`, or None if the file is
    absent or its contents are not a bare integer (a corrupt lock file must
    never block a sweep forever -- it is treated as reclaimable)."""
    try:
        text = Path(lock_path).read_text(encoding="utf-8").strip()
    except OSError:
        return None
    try:
        return int(text)
    except ValueError:
        return None


def pid_is_running(pid):
    """True if a process with this PID currently exists. Signal 0 performs
    OS-level error checking without delivering a signal: ProcessLookupError
    means no such process (dead); PermissionError means the process exists
    but is owned by another user (still running)."""
    if pid is None or pid <= 0:
        return False
    try:
        os.kill(pid, 0)
    except ProcessLookupError:
        return False
    except PermissionError:
        return True
    return True


def acquire_sweep_lock(lock_path):
    """Acquire the PID-file lock (spec section 11.1). Returns
    (acquired, reclaimed):
      - (True, False): the lock was free/absent (or already ours) -> now ours.
      - (True, True):  an existing lock referenced a DEAD PID (stale) -> we
        reclaimed it (caller logs that it did) and it is now ours.
      - (False, False): the lock is genuinely held by a live foreign
        process -> caller logs a benign skip and exits 0.
    On acquisition our own PID is written to `lock_path`."""
    lock_path = Path(lock_path)
    existing = read_lock_pid(lock_path)
    reclaimed = False
    if existing is not None and existing != os.getpid():
        if pid_is_running(existing):
            return (False, False)
        reclaimed = True  # the recorded PID is dead -> stale lock
    lock_path.parent.mkdir(parents=True, exist_ok=True)
    lock_path.write_text(str(os.getpid()), encoding="utf-8")
    return (True, reclaimed)


def release_sweep_lock(lock_path):
    """Remove the PID-file lock iff it still records our PID -- never delete a
    lock another process has since taken over."""
    lock_path = Path(lock_path)
    if read_lock_pid(lock_path) == os.getpid():
        try:
            lock_path.unlink()
        except OSError:
            pass


IN_PROGRESS_EXTS = {".crdownload", ".download", ".part", ".tmp"}


def iter_sweep_files(directory):
    """Yield the top-level regular files of `directory` eligible for a sweep,
    in sorted order (spec section 11.2 step 3). Subdirectories are skipped
    entirely -- no recursion. Files whose extension is an in-progress-download
    marker (IN_PROGRESS_EXTS, matched case-insensitively) are skipped so a
    file still being written is left untouched for the next day's run.
    Non-regular entries (directories, symlinks-to-directories) are skipped."""
    directory = Path(directory)
    for entry in sorted(directory.iterdir()):
        if not entry.is_file():
            continue
        if entry.suffix.lower() in IN_PROGRESS_EXTS:
            continue
        yield entry


def sweep(conn, directory, codes, root=None, dry_run=False, protected=None):
    """Sweep every top-level file in `directory` through place_file, reusing
    Phase 1's classifier + protected-path guard unchanged (spec section 11.2
    step 4 / 11.3). `root` is the DOCUMENTS taxonomy root (the placement
    destination), NOT the sweep source dir. Per-file isolation: one file's
    exception is caught, counted, and skipped -- it never aborts the loop.

    Pure function: acquires no lock and writes no log (that is run_sweep's
    job, spec section 11.1) so it is unit-testable in isolation. Returns a
    stats dict: scanned / filed / staged / errored counts plus an `errors`
    list of (filename, repr(exc)) the caller logs. Action buckets: "place"
    -> filed; the four staging actions -> staged; a raised exception ->
    errored; every processed file counts toward scanned."""
    root = Path(root) if root is not None else get_documents_root()
    protected = load_protected_paths() if protected is None else protected
    stats = {"scanned": 0, "filed": 0, "staged": 0, "errored": 0, "errors": []}
    for f in iter_sweep_files(directory):
        stats["scanned"] += 1
        try:
            res = place_file(conn, f, codes, root=root, dry_run=dry_run,
                             protected=protected)
        except Exception as exc:
            # Per-file isolation (spec section 11.3): one bad file (permission
            # denied, vanished mid-run, staging collision) never stops the
            # sweep -- it is counted, recorded for the summary log, and
            # skipped.
            stats["errored"] += 1
            stats["errors"].append((f.name, repr(exc)))
            continue
        action = res.get("action")
        if action == "place":
            stats["filed"] += 1
        elif action in ("stage-unsorted", "stage-folder-ambiguous",
                        "refuse-exists", "refuse-protected"):
            stats["staged"] += 1
    return stats


def _append_sweep_log(log_path, message):
    """Append one timestamped line to the sweep summary log (spec section
    11.1), creating the parent dir as needed. Append mode -- never truncates,
    so a launchd-run line and a manual-run line accumulate in the same file."""
    log_path = Path(log_path)
    log_path.parent.mkdir(parents=True, exist_ok=True)
    timestamp = time.strftime("%Y-%m-%dT%H:%M:%S")
    with open(str(log_path), "a", encoding="utf-8") as fh:
        fh.write("%s %s\n" % (timestamp, message))


def write_sweep_summary(log_path, stats, dry_run=False):
    """Write the one-line run summary (spec section 11.2 step 5) -- counts of
    scanned / auto-filed / staged / errored, plus the _append_sweep_log
    timestamp. A --dry-run run writes the same line with a (dry-run) marker
    (spec section 11.4)."""
    marker = " (dry-run)" if dry_run else ""
    line = ("sweep%s: scanned=%d filed=%d staged=%d errored=%d"
            % (marker, stats["scanned"], stats["filed"],
               stats["staged"], stats["errored"]))
    _append_sweep_log(log_path, line)


def run_sweep(conn, directory=None, dry_run=False, codes=None,
              protected=None, root=None):
    """Orchestrate one sweep run (spec section 11.2 data flow): acquire the
    PID-file lock, run the pure sweep(), write the summary log line, release
    the lock. A genuinely-held lock is a benign skip (log one line, exit 0).
    A stale lock (dead PID) is reclaimed and logged. The lock is released in
    a finally so it is freed even if enumeration raises (which propagates to
    main() as a clean exit-2 error).

    `codes`/`protected`/`root` are loaded here when None, mirroring
    place_file's injectable pattern; `_cmd_sweep` passes `protected` in so it
    is loaded once for the guard-inactive warning."""
    root = get_documents_root() if root is None else Path(root)
    codes = load_codes() if codes is None else codes
    protected = load_protected_paths() if protected is None else protected
    directory = (Path(directory) if directory is not None
                 else Path.home() / "Downloads")
    lock_path = get_sweep_lock_path()
    log_path = get_sweep_log_path()
    acquired, reclaimed = acquire_sweep_lock(lock_path)
    if not acquired:
        _append_sweep_log(log_path, "sweep: already running, skipping")
        return {"scanned": 0, "filed": 0, "staged": 0, "errored": 0,
                "skipped": True, "reclaimed": False}
    try:
        if reclaimed:
            _append_sweep_log(log_path, "sweep: reclaimed stale lock")
        stats = sweep(conn, directory, codes, root=root, dry_run=dry_run,
                      protected=protected)
        for name, message in stats.get("errors", []):
            _append_sweep_log(log_path,
                              "sweep: error on %s: %s" % (name, message))
        write_sweep_summary(log_path, stats, dry_run)
        stats["skipped"] = False
        stats["reclaimed"] = reclaimed
        return stats
    finally:
        release_sweep_lock(lock_path)


SCHEMA = """
CREATE TABLE folders (
    id INTEGER PRIMARY KEY,
    path TEXT UNIQUE NOT NULL,
    code TEXT,
    name TEXT,
    description TEXT
);
CREATE TABLE files (
    id INTEGER PRIMARY KEY,
    path TEXT UNIQUE NOT NULL,
    folder_id INTEGER REFERENCES folders(id),
    code TEXT,
    filename TEXT,
    ext TEXT,
    size INTEGER,
    content_hash TEXT,
    created_at REAL,
    modified_at REAL,
    indexed_at REAL,
    description TEXT
);
CREATE TABLE tags (
    id INTEGER PRIMARY KEY,
    name TEXT UNIQUE NOT NULL
);
CREATE TABLE file_tags (
    file_id INTEGER NOT NULL REFERENCES files(id),
    tag_id INTEGER NOT NULL REFERENCES tags(id),
    PRIMARY KEY (file_id, tag_id)
);
"""


def open_db(db_path=None):
    """Open (creating/migrating as needed) the index DB.

    Migration policy (spec section 4): on user_version mismatch, drop and
    rebuild -- the DB is fully rebuildable by re-running `fileorg scan`.
    """
    path = Path(db_path) if db_path is not None else get_db_path()
    path.parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(str(path))
    conn.row_factory = sqlite3.Row
    version = conn.execute("PRAGMA user_version").fetchone()[0]
    tables = {
        r[0]
        for r in conn.execute("SELECT name FROM sqlite_master WHERE type='table'")
    }
    if not tables:
        conn.executescript(SCHEMA)
        conn.execute("PRAGMA user_version = %d" % SCHEMA_VERSION)
        conn.commit()
    elif version != SCHEMA_VERSION:
        for t in ("file_tags", "tags", "files", "folders"):
            conn.execute("DROP TABLE IF EXISTS %s" % t)
        conn.executescript(SCHEMA)
        conn.execute("PRAGMA user_version = %d" % SCHEMA_VERSION)
        conn.commit()
    return conn


def _deep_merge_code_entry(base, override):
    """Merge a codes.local.json override entry onto a code's base entry.

    Code-level scalar/list fields (name, keywords, extensions, ...) are
    replaced wholesale by `override`, matching the pre-existing shallow
    merge. The `folders` sub-map, when present on both sides, is merged one
    level deeper: each folder entry in override["folders"] is merged onto
    (not replacing) the corresponding entry in base["folders"], so an
    override that only touches one folder does not clobber the others
    (spec section 3.3/5)."""
    merged = dict(base)
    merged.update(override)
    base_folders = base.get("folders")
    override_folders = override.get("folders")
    if base_folders is not None and override_folders is not None:
        combined = dict(base_folders)
        for name, folder_entry in override_folders.items():
            merged_folder = dict(combined.get(name, {}))
            merged_folder.update(folder_entry)
            combined[name] = merged_folder
        merged["folders"] = combined
    return merged


def load_codes(config_dir=None):
    """Load the category code list: shipped defaults + local overrides.

    Defaults (Layer 1, generic, git-tracked) sit next to this script.
    Overrides (Layer 2, personal, never git-tracked) sit alongside index.db
    as codes.local.json. SYS- is reserved for tool-internal folders and may
    never be defined as a category; REF's meaning is fixed (spec section 5).
    """
    default_path = Path(__file__).resolve().parent / "codes.default.json"
    with open(str(default_path), "r", encoding="utf-8") as fh:
        codes = json.load(fh)
    cfg_dir = Path(config_dir) if config_dir is not None else get_db_path().parent
    override_path = cfg_dir / "codes.local.json"
    if override_path.exists():
        try:
            with open(str(override_path), "r", encoding="utf-8") as fh:
                overrides = json.load(fh)
        except json.JSONDecodeError as e:
            raise ValueError("Invalid JSON in codes override %s: %s" % (override_path, e))
        if "SYS" in overrides:
            raise ValueError(
                "'SYS' is reserved for tool-internal folders (e.g. %s) and "
                "cannot be a category code" % SYS_UNSORTED
            )
        if ("REF" in overrides
                and overrides["REF"].get("name", codes["REF"]["name"])
                != codes["REF"]["name"]):
            raise ValueError("'REF' is reserved: its meaning is fixed and "
                             "cannot be renamed")
        overrides.pop("protected", None)
        for code, entry in overrides.items():
            base = codes.get(code, {"name": "", "keywords": [], "extensions": []})
            codes[code] = _deep_merge_code_entry(base, entry)
    if "SYS" in codes:
        raise ValueError("'SYS' is reserved and cannot be a category code")
    return codes


def is_protected_path(path, protected, root, _resolved=None):
    """Return the matched entry from `protected` if `path` is inside (or
    equal to) it, else None (ADR 0018). Entries are interpreted relative to
    `root` (the Documents root); matching is segment-by-segment -- subtree
    prefix at path-segment boundaries, not a raw string prefix, so
    'LEG-Case/Export' protects itself and everything beneath it but
    NOT a sibling like 'LEG-Case/ExportNotes' -- and case-insensitive.
    Truthy/falsy, usable directly as a boolean guard.

    `_resolved`, when given, is used in place of calling `Path(path).resolve()`
    -- this lets `protected_hit` (below) reuse this function's segment-boundary
    comparison for the parent-resolved (symlink-safe) form without a second,
    re-following resolve() call collapsing that form back into the fully-
    resolved one. Internal to this module; callers outside it should not
    need it."""
    root = Path(root)
    try:
        p = _resolved if _resolved is not None else Path(path).resolve()
        rel = p.relative_to(root.resolve())
    except ValueError:
        return None
    parts = tuple(p.lower() for p in rel.parts)
    for entry in protected:
        entry_parts = tuple(p.lower() for p in Path(entry).parts)
        if parts[:len(entry_parts)] == entry_parts:
            return entry
    return None


def protected_hit(path, protected, root):
    """Symlink-safe protected-path check (ADR 0018, fixes D3 + the
    adversarial-verifier-confirmed symlinked-ANCESTOR hole): a path counts
    as protected if ANY of three forms matches:

    1. Fully-resolved (is_protected_path's default -- Path.resolve()
       follows every symlink, including the final path component).
    2. Parent-resolved (the containing directory resolved, final
       component NOT followed) -- catches a symlink planted inside a
       protected subtree that points OUTSIDE it, which resolves outside
       under form 1 alone.
    3. Purely lexical (os.path.abspath -- NO resolve() at all, no symlink
       in ANY component is followed). Forms 1 and 2 both call resolve()
       on the path's parent chain, so if the protected directory ITSELF
       -- or any subdirectory inside it -- is a symlink, both forms
       follow it and the result lands outside the protected subtree,
       evading the guard entirely. Form 3 is immune: it never follows
       any symlink, so a symlinked ancestor cannot move the literal
       (root-relative) path outside the protected entry.

    The inverse direction (an outside symlink pointing INTO the protected
    tree) is merely over-protective under form 1 and is fine as-is.
    Used for BOTH the source-side and destination-side checks so neither
    can be evaded by a symlink."""
    src = Path(path)
    hit = is_protected_path(src, protected, root)
    if hit:
        return hit
    try:
        parent_resolved = src.parent.resolve() / src.name
    except OSError:
        parent_resolved = None
    if parent_resolved is not None:
        hit = is_protected_path(src, protected, root, _resolved=parent_resolved)
        if hit:
            return hit
    lexical = Path(os.path.abspath(str(src)))
    return is_protected_path(src, protected, root, _resolved=lexical)


class ProtectedPathError(RuntimeError):
    """Raised by guarded_move when either side of a move touches a
    protected path (ADR 0018). NOT unreachable defense-in-depth: place_file
    only re-checks the destination when action == "place", so it never
    examines the STAGING destinations (stage-unsorted,
    stage-folder-ambiguous, refuse-exists, refuse-protected -- all of
    which land in SYS-Unsorted/). For those, guarded_move's internal check
    is the SOLE destination guard -- load-bearing, and this error is how
    it fires. main() catches it and prints a clean `error:` line (never a
    raw traceback) at exit code 2, matching the module's other guarded
    CLI failures."""


def guarded_move(src, dest, protected, root):
    """The ONLY sanctioned way to move a file under the taxonomy (ADR 0018
    choke point, fixes D2). Performs a symlink-safe protected-path check
    on BOTH src and dest and refuses (raises ProtectedPathError) on either
    hit -- never falls through to shutil.move if either side matches.

    This check is LOAD-BEARING, not redundant defense-in-depth: place_file
    only re-checks the destination when action == "place" (see the block
    guarded by `if action == "place":` there). The staging destinations
    (stage-unsorted, stage-folder-ambiguous, refuse-exists,
    refuse-protected -- all of which land in SYS-Unsorted/) are never
    destination-checked anywhere else in this module, so this is their
    SOLE guard. Do not remove it as unreachable.

    Creates dest's parent directory, but only AFTER the protected-path
    check has passed -- a refused move must never mutate the filesystem
    first, even to create a directory. shutil.move appears nowhere else
    in this module."""
    src, dest = Path(src), Path(dest)
    hit = protected_hit(src, protected, root) or protected_hit(dest, protected, root)
    if hit:
        raise ProtectedPathError(
            "refusing to move %s -> %s: protected path '%s' (ADR 0018)"
            % (src, dest, hit)
        )
    dest.parent.mkdir(parents=True, exist_ok=True)
    shutil.move(str(src), str(dest))


def load_protected_paths(config_dir=None):
    """Load the `protected` path list from codes.local.json (Layer 2, ADR
    0018). Missing file or missing key -> []. Entries are returned exactly
    as written (relative to the Documents root); is_protected_path does the
    interpretation, not this loader.

    This is a legal-discovery safety guard: a malformed `"protected"` value
    must never be silently ignored or partially applied -- that would leave
    the guard inert while the config author believes it is active. Any
    shape that is not an unambiguous list of non-empty, relative path
    strings raises ValueError immediately."""
    cfg_dir = Path(config_dir) if config_dir is not None else get_db_path().parent
    override_path = cfg_dir / "codes.local.json"
    if not override_path.exists():
        return []
    try:
        with open(str(override_path), "r", encoding="utf-8") as fh:
            data = json.load(fh)
    except json.JSONDecodeError as e:
        raise ValueError("Invalid JSON in codes override %s: %s" % (override_path, e))
    raw = data.get("protected", [])
    if not isinstance(raw, list):
        raise ValueError(
            "'protected' in %s must be a list of path strings, got %s "
            "(e.g. a bare string is NOT auto-wrapped -- it would be shredded "
            "into single-character entries that silently protect nothing)"
            % (override_path, type(raw).__name__)
        )
    protected = []
    for entry in raw:
        if not isinstance(entry, str):
            raise ValueError(
                "'protected' entry in %s must be a string, got %s: %r"
                % (override_path, type(entry).__name__, entry)
            )
        if entry.startswith("/"):
            raise ValueError(
                "'protected' entry %r in %s must be relative to the "
                "Documents root, not absolute (ADR 0018)" % (entry, override_path)
            )
        if not entry.strip():
            raise ValueError(
                "'protected' entry in %s must not be empty or "
                "whitespace-only -- an empty entry matches every path" % override_path
            )
        if ".." in Path(entry).parts:
            raise ValueError(
                "'protected' entry %r in %s must not contain '..' -- it "
                "resolves outside the intended subtree and would silently "
                "match nothing under is_protected_path's segment-prefix "
                "rule, leaving the guard inert (ADR 0018)"
                % (entry, override_path)
            )
        protected.append(entry)
    return protected


def compute_hash(path):
    """SHA-256 of the file's bytes -- the stable content identity (spec section 4)."""
    h = hashlib.sha256()
    with open(str(path), "rb") as fh:
        for chunk in iter(lambda: fh.read(65536), b""):
            h.update(chunk)
    return h.hexdigest()


def get_created_at(path):
    """File creation time: st_birthtime, else st_mtime. NEVER st_ctime."""
    st = os.stat(str(path))
    birth = getattr(st, "st_birthtime", 0)
    if birth:
        return birth
    return st.st_mtime


def parse_folder_code(name):
    """Parse a top-level 'CODE-Name' folder name. Returns (code, name) or (None, None)."""
    m = FOLDER_CODE_RE.match(name)
    if not m:
        return (None, None)
    return (m.group(1), m.group(2))


def _top_level_dir(path, root):
    """Return the top-level (direct child of root) directory containing path."""
    rel = path.relative_to(root)
    parts = rel.parts
    if not parts:
        return None
    return root / parts[0]


def upsert_folder(conn, path, root):
    """Insert/update a folders row for a top-level directory; return its id."""
    code, name = parse_folder_code(path.name)
    row = conn.execute("SELECT id FROM folders WHERE path=?",
                       (str(path),)).fetchone()
    if row is None:
        cur = conn.execute(
            "INSERT INTO folders (path, code, name) VALUES (?, ?, ?)",
            (str(path), code, name),
        )
        return cur.lastrowid
    conn.execute("UPDATE folders SET code=?, name=? WHERE id=?",
                 (code, name, row["id"]))
    return row["id"]


def upsert_file(conn, path, root):
    """Insert/update a files row. A moved file (same hash, new path) UPDATEs the
    existing row's path -- preserving description and tags (spec section 4)."""
    st = os.stat(str(path))
    content_hash = compute_hash(path)
    ext = path.suffix.lstrip(".").lower()
    top = _top_level_dir(path, root)
    folder_id = None
    code = None
    if top is not None and top.is_dir():
        folder_id = upsert_folder(conn, top, root)
        code, _ = parse_folder_code(top.name)
    now = time.time()
    existing = conn.execute("SELECT id FROM files WHERE path=?",
                           (str(path),)).fetchone()
    if existing is not None:
        conn.execute(
            "UPDATE files SET folder_id=?, code=?, filename=?, ext=?, size=?, "
            "content_hash=?, created_at=?, modified_at=?, indexed_at=? WHERE id=?",
            (folder_id, code, path.name, ext, st.st_size, content_hash,
             get_created_at(path), st.st_mtime, now, existing["id"]),
        )
        return existing["id"]
    moved = conn.execute(
        "SELECT id, path FROM files WHERE content_hash=?", (content_hash,)
    ).fetchone()
    if moved is not None and not Path(moved["path"]).exists():
        conn.execute(
            "UPDATE files SET path=?, folder_id=?, code=?, filename=?, ext=?, "
            "size=?, created_at=?, modified_at=?, indexed_at=? WHERE id=?",
            (str(path), folder_id, code, path.name, ext, st.st_size,
             get_created_at(path), st.st_mtime, now, moved["id"]),
        )
        return moved["id"]
    cur = conn.execute(
        "INSERT INTO files (path, folder_id, code, filename, ext, size, "
        "content_hash, created_at, modified_at, indexed_at) "
        "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
        (str(path), folder_id, code, path.name, ext, st.st_size, content_hash,
         get_created_at(path), st.st_mtime, now),
    )
    return cur.lastrowid


def scan_index(conn, root=None):
    """Walk root; upsert folders/files; remove rows for vanished paths.

    Idempotent: re-running reconciles the index against the filesystem and
    never duplicates rows. A file that moved on disk (same content_hash, new
    path) is detected as an UPDATE, not a delete+insert, so tags/description
    survive (spec section 4). Returns stats dict."""
    root = Path(root) if root is not None else get_documents_root()
    stats = {"folders": 0, "files": 0, "moved": 0, "removed": 0, "folders_removed": 0}
    before = {r["path"]: r["id"]
              for r in conn.execute("SELECT id, path FROM files")}
    before_ids = set(before.values())
    seen_ids = set()
    for dirpath, dirnames, filenames in os.walk(str(root)):
        d = Path(dirpath)
        if d != root and _top_level_dir(d, root) == d:
            upsert_folder(conn, d, root)
        for fn in filenames:
            fpath = d / fn
            if not fpath.is_file():
                continue
            fid = upsert_file(conn, fpath, root)
            seen_ids.add(fid)
            # A moved file reuses an existing row id at a path not seen before.
            if str(fpath) not in before and fid in before_ids:
                stats["moved"] += 1
    # Remove rows whose path no longer exists on disk (and were not moved).
    for r in list(conn.execute("SELECT id, path FROM files")):
        if not Path(r["path"]).exists():
            conn.execute("DELETE FROM file_tags WHERE file_id=?", (r["id"],))
            conn.execute("DELETE FROM files WHERE id=?", (r["id"],))
            if r["id"] not in seen_ids:
                stats["removed"] += 1
    # Remove folders rows whose path no longer exists on disk. Runs after the
    # files-removal pass above so no live file row still references a
    # to-be-deleted folder (spec section 4).
    for r in list(conn.execute("SELECT id, path FROM folders")):
        if not Path(r["path"]).exists():
            conn.execute("DELETE FROM folders WHERE id=?", (r["id"],))
            stats["folders_removed"] += 1
    stats["files"] = conn.execute("SELECT COUNT(*) FROM files").fetchone()[0]
    stats["folders"] = conn.execute("SELECT COUNT(*) FROM folders").fetchone()[0]
    conn.commit()
    return stats


COLD_ARCHIVE_MIN_BYTES = 100 * 1024 * 1024


def _dir_is_empty(d):
    """True if no files exist anywhere beneath directory d."""
    for _dp, _dn, fns in os.walk(str(d)):
        if fns:
            return False
    return True


def classify_drift(conn, root=None):
    """Report (never act on) non-taxonomy items -- spec section 7 buckets.

    Files inside plain-named (uncoded) subfolders are summarized as an
    aggregate per top-level folder, never per-item, so the first run on the
    current tree does not emit hundreds of noise lines (spec section 7)."""
    root = Path(root) if root is not None else get_documents_root()
    codes = load_codes()
    drift = {
        "junk": [],
        "misplaced_tooling": [],
        "cold_archive": [],
        "loose_needs_placement": [],
        "duplicate": [],
        "uncoded_subfolders": {},
        "code_mismatch": [],
        "unknown_code": [],
    }
    # Top-level entries.
    for entry in sorted(root.iterdir()):
        if entry.name == SYS_UNSORTED or entry.name.startswith("SYS-"):
            continue
        if entry.is_dir():
            code, _ = parse_folder_code(entry.name)
            if code is None:
                if entry.name in TOOLING_NAMES:
                    drift["misplaced_tooling"].append(str(entry))
                elif _dir_is_empty(entry):
                    drift["junk"].append(str(entry))
                else:
                    drift["misplaced_tooling"].append(str(entry))
                continue
            if code not in codes:
                drift["unknown_code"].append(str(entry))
            # Coded top-level folder: inspect its immediate children.
            sub_count = 0
            sub_file_count = 0
            for child in sorted(entry.iterdir()):
                if child.is_dir():
                    if _dir_is_empty(child):
                        drift["junk"].append(str(child))
                        continue
                    sub_count += 1
                    for _dp, _dn, fns in os.walk(str(child)):
                        for fn in fns:
                            if fn in JUNK_NAMES:
                                drift["junk"].append(str(Path(_dp) / fn))
                            else:
                                sub_file_count += 1
                elif child.is_file():
                    if child.name in JUNK_NAMES:
                        drift["junk"].append(str(child))
                    else:
                        drift["loose_needs_placement"].append(str(child))
            if sub_count:
                drift["uncoded_subfolders"][entry.name] = {
                    "subfolders": sub_count, "files": sub_file_count
                }
        else:
            # Top-level loose file.
            if entry.name in JUNK_NAMES:
                drift["junk"].append(str(entry))
            elif ("." + entry.suffix.lstrip(".").lower()) in ARCHIVE_EXTS \
                    and entry.stat().st_size >= COLD_ARCHIVE_MIN_BYTES:
                drift["cold_archive"].append(str(entry))
            else:
                drift["loose_needs_placement"].append(str(entry))
    # Duplicate groups: same content_hash across >1 file.
    hashes = {}
    for r in conn.execute("SELECT path, content_hash FROM files"):
        hashes.setdefault(r["content_hash"], []).append(r["path"])
    for _h, paths in hashes.items():
        if len(paths) > 1:
            drift["duplicate"].append(sorted(paths))
    # Code mismatch: files.code != containing top-level folder's code.
    for r in conn.execute("SELECT f.path, f.code AS fcode, d.code AS dcode "
                          "FROM files f LEFT JOIN folders d "
                          "ON f.folder_id = d.id"):
        if r["dcode"] is not None and r["fcode"] != r["dcode"]:
            drift["code_mismatch"].append(r["path"])
    return drift


def _file_id(conn, path):
    """Return the files.id for an indexed path, or raise LookupError."""
    abspath = str(Path(path).resolve())
    row = conn.execute("SELECT id FROM files WHERE path=?",
                      (abspath,)).fetchone()
    if row is None:
        # Fall back to the non-resolved form (fixtures may pass root-relative).
        row = conn.execute("SELECT id FROM files WHERE path=?",
                          (str(path),)).fetchone()
    if row is None:
        raise LookupError("no indexed file at %s (run scan first)" % path)
    return row["id"]


def add_note(conn, path, text):
    """Attach a free-text description to an indexed file (spec section 3.2)."""
    fid = _file_id(conn, path)
    conn.execute("UPDATE files SET description=? WHERE id=?", (text, fid))
    conn.commit()


def add_tags(conn, path, tags):
    """Attach searchable tags to an indexed file. Idempotent (spec section 6)."""
    fid = _file_id(conn, path)
    for raw in tags:
        name = raw.strip().lower()
        if not name:
            continue
        conn.execute("INSERT OR IGNORE INTO tags (name) VALUES (?)", (name,))
        tid = conn.execute("SELECT id FROM tags WHERE name=?",
                          (name,)).fetchone()["id"]
        conn.execute(
            "INSERT OR IGNORE INTO file_tags (file_id, tag_id) VALUES (?, ?)",
            (fid, tid),
        )
    conn.commit()


def get_tags(conn, file_id):
    """Sorted tag names attached to a file."""
    return sorted(
        r["name"]
        for r in conn.execute(
            "SELECT t.name FROM tags t JOIN file_tags ft ON t.id=ft.tag_id "
            "WHERE ft.file_id=?", (file_id,)
        )
    )


def query_index(conn, terms):
    """Search code, filename, description and tags for files matching ALL terms.

    Substring, case-insensitive. Structured columns + tags only -- no FTS
    (spec section 4). Returns list of result dicts sorted by path."""
    lowered = [t.strip().lower() for t in terms if t.strip()]
    results = []
    for r in conn.execute("SELECT * FROM files ORDER BY path"):
        tags = get_tags(conn, r["id"])
        haystack = " ".join(filter(None, [
            (r["code"] or ""),
            (r["filename"] or ""),
            (r["description"] or ""),
            " ".join(tags),
        ])).lower()
        if all(term in haystack for term in lowered):
            results.append({
                "path": r["path"],
                "code": r["code"],
                "filename": r["filename"],
                "description": r["description"],
                "tags": tags,
            })
    return results


def classify_file(path, codes, root=None):
    """Automatic classification (spec section 3.3) -- no interactive prompt.

    Precedence: already-coded relocation > keyword/extension match > low
    confidence. Returns (code, reason) where reason is one of
    'already-coded', 'keyword-match', 'low-confidence'."""
    path = Path(path)
    root = Path(root) if root is not None else get_documents_root()
    # 1. Already-coded relocation.
    try:
        rel = path.resolve().relative_to(root.resolve())
        parts = rel.parts
    except (ValueError, OSError):
        parts = ()
    if len(parts) >= 2:
        code, _ = parse_folder_code(parts[0])
        if code is not None and code in codes:
            return (code, "already-coded")
    # 2. Rule-based match.
    stem = path.stem.lower()
    ext = path.suffix.lstrip(".").lower()
    scores = {}
    for code, entry in codes.items():
        score = 0
        for kw in entry.get("keywords", []):
            if kw.lower() in stem:
                score += 2
        if ext and ext in [e.lower() for e in entry.get("extensions", [])]:
            score += 1
        if score:
            scores[code] = score
    if scores:
        best = max(scores.values())
        winners = [c for c, s in scores.items() if s == best]
        if best >= 1 and len(winners) == 1:
            return (winners[0], "keyword-match")
    # 3. Low confidence.
    return (None, "low-confidence")


def folders_for_code(documents_root, code):
    """Existing top-level CODE-Name folders under documents_root whose parsed
    code equals `code` (spec section 3.3). Never synthesizes a folder name --
    only reports what already exists on disk, so place_file can tell an
    unambiguous destination from an ambiguous (0 or >1 match) one."""
    root = Path(documents_root)
    return sorted(
        entry for entry in root.iterdir()
        if entry.is_dir() and parse_folder_code(entry.name)[0] == code
    )


def classify_folder(path, code_entry, folders):
    """Stage-2 folder-level scoring within a multi-folder code (spec 3.3).

    `folders` is the list of existing top-level CODE-Name Path objects for
    the already-resolved code (as returned by folders_for_code). Each
    folder's effective keyword set is the RUNTIME union of the code's own
    `keywords` (code_entry["keywords"]) and that folder's own `keywords`
    (code_entry["folders"][folder.name]["keywords"]), computed here at
    scoring time -- never pre-merged or stored. Filename-stem keyword hits
    score at weight 3. Strict single winner required: exactly one folder
    holds the max score, and that max is >= 1. Returns the winning Path,
    or None on a tie or an all-zero score (spec 3.3: no closest-match
    heuristic, ever)."""
    stem = Path(path).stem.lower()
    code_keywords = code_entry.get("keywords", [])
    folder_cfg = code_entry.get("folders", {})
    scores = {}
    for folder in folders:
        own_keywords = folder_cfg.get(folder.name, {}).get("keywords", [])
        effective = set(code_keywords) | set(own_keywords)
        score = sum(3 for kw in effective if kw.lower() in stem)
        if score:
            scores[folder] = score
    if not scores:
        return None
    best = max(scores.values())
    winners = [f for f, s in scores.items() if s == best]
    if best >= 1 and len(winners) == 1:
        return winners[0]
    return None


def place_file(conn, path, codes, root=None, dry_run=False, protected=None):
    """Place a file into its coded destination -- automatic, safe (spec 3.3, 6).

    SOURCE-side guard first (ADR 0018, fixes D1): if `path` itself is inside
    a protected subtree, refuse as a pure NO-OP before classification,
    before the idempotency check, before anything else -- touch nothing,
    move nothing, write NOTHING to the index (no upsert_file, no tag, no
    note). Staging to SYS-Unsorted/ would itself move the file out of the
    protected tree (the exact harm being guarded against), and a tree-wide
    sweep must not stamp every protected file needs-review (that would
    invert the tag's meaning). Returns normally, exit 0, never raises -- a
    refusal is expected during a sweep, not an error.

    Otherwise: Stage 1 keyword/extension (weights 2/1) picks CODE (strict
    winner). Single folder -> place. Multiple -> Stage 2 scores (weight 3,
    strict winner). Winner -> place. No CODE, zero folders, or stage-2
    tie/all-zero -> SYS-Unsorted/ with needs-review. Idempotent. Destination
    exists -> refuse, staged instead. Verified before DB write. A computed
    destination inside a protected path (ADR 0018) is refused and staged to
    SYS-Unsorted instead -- never falls back to a peer folder for the same
    code. Both the source and destination checks are symlink-safe
    (protected_hit, fixes D3), and the actual move is routed through
    guarded_move (fixes D2) -- the single choke point through which every
    filesystem mutation in this module passes."""
    src = Path(path)
    root = Path(root) if root is not None else get_documents_root()
    protected = load_protected_paths() if protected is None else protected
    src_hit = protected_hit(src, protected, root)
    if src_hit:
        return {"src": str(src), "code": None, "reason": "protected-source",
                "dest": str(src), "action": "refuse-protected-source",
                "moved": False, "protected_hit": src_hit}
    dest_protected_hit = None
    code, reason = classify_file(src, codes, root)
    if code is not None:
        matches = folders_for_code(root, code)
        if len(matches) == 1:
            dest = matches[0] / src.name
            action = "place"
            # Idempotency: a file already correctly filed at its destination
            # is a no-op -- never re-route it into SYS-Unsorted (spec section
            # 6: every verb is idempotent; re-running reconciles, not re-moves).
            if dest.resolve() == src.resolve():
                return {"src": str(src), "code": code, "reason": reason,
                        "dest": str(dest), "action": "noop", "moved": False}
        else:
            # Zero or multiple folders share this code. Before downgrading,
            # check whether the file is already correctly filed under one of
            # the matching folders -- idempotency (spec section 6) must hold
            # even when the code maps to >1 folders, otherwise an
            # already-filed file gets scattered into SYS-Unsorted just
            # because its code is ambiguous.
            try:
                top = _top_level_dir(src.resolve(), root.resolve())
            except ValueError:
                top = None
            if top is not None and any(
                    top == m.resolve() for m in matches):
                return {"src": str(src), "code": code, "reason": reason,
                        "dest": str(src), "action": "noop", "moved": False}
            winner = (classify_folder(src, codes[code], matches)
                      if len(matches) > 1 else None)
            if winner is not None:
                dest = winner / src.name
                action = "place"
            elif len(matches) > 1:
                # Stage-2 miss (tie or zero score): the CODE resolved, but
                # no single folder won. Code is NOT downgraded to None --
                # unlike the zero-matching-folders case below -- so the
                # note below can name it (spec section 3.3).
                reason = "folder-ambiguous"
                dest = root / SYS_UNSORTED / src.name
                action = "stage-folder-ambiguous"
            else:
                # Zero matching folders: never guess, never invent a new
                # default-named folder.
                code, reason = None, "low-confidence"
                dest = root / SYS_UNSORTED / src.name
                action = "stage-unsorted"
    else:
        dest = root / SYS_UNSORTED / src.name
        action = "stage-unsorted"
    # Protected-path guard (ADR 0018): a computed destination inside a
    # protected path is never used as a placement target -- refuse and
    # stage instead, same discipline as the destination-exists check below.
    # Never falls back to a different peer folder for the same code.
    if action == "place":
        hit = protected_hit(dest, protected, root)
        if hit:
            dest_protected_hit = hit
            action = "refuse-protected"
            dest = root / SYS_UNSORTED / src.name
    # Destination-exists check: refuse to overwrite; re-route to staging.
    if dest.exists():
        action = "refuse-exists"
        dest = root / SYS_UNSORTED / src.name
    plan = {"src": str(src), "code": code, "reason": reason,
            "dest": str(dest), "action": action, "moved": False}
    if dest_protected_hit is not None:
        # Surface the guard-time protected_hit in the plan regardless of
        # what `action` was clobbered to afterward (e.g. the destination-
        # exists check below reassigning it to "refuse-exists") -- branch
        # on dest_protected_hit, never on the mutable `action` (ADR 0018).
        # This is the ONLY audit channel for a dry-run compound refusal,
        # since dry_run never raises and never writes a DB note.
        plan["protected_hit"] = dest_protected_hit
    if dry_run:
        return plan
    if dest.exists():
        # Nothing is recorded on this path (the abort contract), so the
        # surfaced error is the ONLY audit channel left. When the
        # protected-path guard is what routed the file here, name it --
        # a legal-guardrail refusal must never read as a generic
        # overwrite refusal (ADR 0018).
        if dest_protected_hit is not None:
            raise FileExistsError(
                "refusing to overwrite staged destination %s; this file was "
                "refused entry to protected path '%s' and could not be staged "
                "(nothing was moved or recorded -- resolve the staging "
                "collision by hand)" % (dest, dest_protected_hit)
            )
        raise FileExistsError(
            "refusing to overwrite staged destination %s" % dest
        )
    # dest.parent is created inside guarded_move, AFTER its protected-path
    # check passes -- never here, and never before the guard has cleared
    # (spec section 6 / ADR 0018 MINOR finding: a pathological config that
    # lists the staging root itself as protected must not have a directory
    # created inside it before the refusal fires).
    guarded_move(src, dest, protected, root)
    # Verify before recording: a failed/partial move must never be recorded.
    if not dest.exists():
        raise RuntimeError("move did not land at %s; not recording" % dest)
    upsert_file(conn, dest, root)
    if action in ("stage-unsorted", "refuse-exists", "stage-folder-ambiguous",
                  "refuse-protected"):
        add_tags(conn, dest, [NEEDS_REVIEW_TAG])
    if action == "stage-folder-ambiguous":
        add_note(conn, dest, "folder-ambiguous: code=%s" % code)
    if action == "refuse-protected":
        add_note(conn, dest, "protected-path: %s" % dest_protected_hit)
    conn.commit()
    plan["moved"] = True
    return plan


def apply_classification(conn, file, folder, codes, root=None, dry_run=False,
                         protected=None):
    """Move one already-decided file into one already-named REAL folder
    (spec section 12.3). Unlike `place`, the destination FOLDER is chosen by
    the caller (an LLM classification pass), not computed -- so the verb's
    whole job is to validate that folder is real and safe, then move through
    the same single choke point `place` uses.

    Order (spec section 12.3):
      1. Folder validation -- real AND recognized, or refuse. The folder name
         must parse as CODE-Name (parse_folder_code), its code must be in the
         loaded `codes`, and the folder Path must appear in
         folders_for_code(root, code) -- the same enumerator place_file uses.
         A hallucinated/misspelled/unrecognized folder is refused here as
         `refuse-invalid-folder`: the file is left UNTOUCHED, nothing is
         moved or recorded, and NO folder is ever created.
      2. Protected-path guard on the resolved destination (protected_hit) --
         refuse-and-stage (added in T2 / spec section 12.3 step 2).
      3. Collision check -- refuse-and-stage (added in T2 / step 3).
      4. Move via guarded_move -- the ONLY sanctioned mover (ADR 0018). Never
         calls shutil.move directly; guarded_move re-checks src+dest against
         the protected list before touching disk.

    Returns a plan dict: src, folder, code, dest, action, moved. `--dry-run`
    returns the same plan with moved=False and touches nothing."""
    src = Path(file)
    root = Path(root) if root is not None else get_documents_root()
    protected = load_protected_paths() if protected is None else protected

    # Step 1: folder validation -- real AND recognized, or refuse.
    folder_name = Path(folder).name
    code, _ = parse_folder_code(folder_name)
    folder_path = root / folder_name
    recognized = (
        code is not None
        and code in codes
        and any(folder_path.resolve() == c.resolve()
                for c in folders_for_code(root, code))
    )
    if not recognized:
        # Never create a folder, never guess, never fall back. Leave the file
        # exactly where it is (spec section 12.3 step 1).
        return {"src": str(src), "folder": folder_name, "code": code,
                "dest": str(src), "action": "refuse-invalid-folder",
                "moved": False}

    dest = folder_path / src.name

    staged = root / SYS_UNSORTED / src.name

    # Step 2: protected-path guard on the resolved destination (ADR 0018) --
    # runs on EVERY call regardless of caller confidence (spec section 12.5,
    # the load-bearing safety property). A wrong LLM destination can never
    # enter a protected legal tree: same check, same choke point as place.
    dest_hit = protected_hit(dest, protected, root)
    if dest_hit:
        return _refuse_and_stage(
            conn, src, staged, "refuse-protected", protected, root, dry_run,
            note="protected-path: %s" % dest_hit, protected_hit_value=dest_hit,
            code=code, folder=folder_name)

    # Step 3: collision check -- refuse-exists semantics (never overwrite).
    if dest.exists():
        return _refuse_and_stage(
            conn, src, staged, "refuse-exists", protected, root, dry_run,
            note=None, protected_hit_value=None, code=code, folder=folder_name)

    # Step 4: move through guarded_move -- the one mover (ADR 0018).
    plan = {"src": str(src), "folder": folder_name, "code": code,
            "dest": str(dest), "action": "apply", "moved": False}
    if dry_run:
        return plan
    guarded_move(src, dest, protected, root)
    if not dest.exists():
        raise RuntimeError("move did not land at %s; not recording" % dest)
    upsert_file(conn, dest, root)
    conn.commit()
    plan["moved"] = True
    return plan


def _refuse_and_stage(conn, src, staged, action, protected, root, dry_run,
                      note, protected_hit_value, code, folder):
    """Refuse a chosen destination and stage the file to SYS-Unsorted/
    instead, mirroring place_file's refuse-protected / refuse-exists
    discipline (spec section 12.3 steps 2/3):

      - If `src` is ALREADY at `staged` (its SYS-Unsorted/<name> path -- the
        normal case, since the Workflow feeds already-staged files), refusal
        is a pure NO-OP: leave it untouched, record nothing. This avoids a
        file-moves-onto-itself self-collision and honors idempotency.
      - Otherwise move `src` -> `staged` through guarded_move (the ONE mover,
        ADR 0018), tag needs-review, and (for a protected refusal) note the
        reason. If `staged` is occupied by a DIFFERENT file, abort with
        FileExistsError (nothing recorded) -- never clobber the file already
        staged there (same double-collision contract as place_file).

      - The double-collision check runs BEFORE the dry_run early return
        (same ordering as place_file's destination-exists check, fileorg.py
        ~1025-1040): a dry-run call must not report success when a real call
        against the same inputs would abort. Matching place_file's own
        dry_run discipline exactly, dry_run still never raises and never
        touches disk -- instead the plan's `action` is overwritten to
        "refuse-exists" (the same label place_file uses for this case) as
        the audit signal, while `protected_hit` (if any) is preserved so the
        ORIGINAL reason for routing here is never lost. Branch on
        `protected_hit`, never on the mutable `action`, same discipline as
        place_file (see its dry-run compound-collision test)."""
    plan = {"src": str(src), "folder": folder, "code": code,
            "dest": str(staged), "action": action, "moved": False}
    if protected_hit_value is not None:
        plan["protected_hit"] = protected_hit_value
    # Idempotent no-op: the file already sits at its staging destination.
    if Path(src).resolve() == Path(staged).resolve():
        plan["dest"] = str(src)
        return plan
    if Path(staged).exists():
        # Double collision: a different file already occupies the staging
        # name. Abort, never clobber (spec section 6, file-organizer-01.md)
        # -- but only for a REAL run; dry_run never raises (place_file
        # parity), so the plan is relabeled and returned instead.
        plan["action"] = "refuse-exists"
        if dry_run:
            return plan
        if protected_hit_value is not None:
            raise FileExistsError(
                "refusing to overwrite staged destination %s; this file was "
                "refused entry to protected path '%s' (nothing moved or "
                "recorded -- resolve the staging collision by hand)"
                % (staged, protected_hit_value))
        raise FileExistsError(
            "refusing to overwrite staged destination %s" % staged)
    if dry_run:
        return plan
    guarded_move(src, staged, protected, root)
    if not Path(staged).exists():
        raise RuntimeError("move did not land at %s; not recording" % staged)
    upsert_file(conn, staged, root)
    add_tags(conn, staged, [NEEDS_REVIEW_TAG])
    if note is not None:
        add_note(conn, staged, note)
    conn.commit()
    plan["moved"] = True
    return plan


def build_parser():
    """Build the fileorg argparse CLI (spec section 3.2 verb table)."""
    p = argparse.ArgumentParser(
        prog="fileorg",
        description="Maintain a coded filing system for ~/Documents.",
    )
    p.add_argument("--root", help="Documents root (overrides FILEORG_DOCUMENTS_ROOT)")
    p.add_argument("--db", help="Index DB path (overrides FILEORG_DB_PATH)")
    sub = p.add_subparsers(dest="cmd", required=True)
    sp = sub.add_parser("scan", help="Refresh the index; report drift.")
    sp.add_argument("path", nargs="?", help="Subtree to scan (default: root).")
    pp = sub.add_parser("place", help="File one file into its coded folder.")
    pp.add_argument("file", help="File to place.")
    pp.add_argument("--dry-run", action="store_true",
                    help="Print the planned action only; move nothing.")
    qp = sub.add_parser("query", help="Search the index.")
    qp.add_argument("terms", nargs="*", help="Search terms (ANDed).")
    npp = sub.add_parser("note", help="Attach a description to a file.")
    npp.add_argument("path", help="Indexed file path.")
    npp.add_argument("text", help="Description text.")
    tp = sub.add_parser("tag", help="Attach tags to a file.")
    tp.add_argument("path", help="Indexed file path.")
    tp.add_argument("tags", nargs="+", help="One or more tags.")
    swp = sub.add_parser(
        "sweep",
        help="Sweep a directory (default ~/Downloads), filing each top-level "
             "file into its coded folder.",
    )
    swp.add_argument("dir", nargs="?",
                     help="Directory to sweep (default: ~/Downloads).")
    swp.add_argument("--dry-run", action="store_true",
                     help="Print the planned actions only; move nothing.")
    acp = sub.add_parser(
        "apply-classification",
        help="Move one file into one already-decided REAL folder, through "
             "the same validation + protected-path guard + guarded_move path "
             "place uses.",
    )
    acp.add_argument("file", help="File to move.")
    acp.add_argument("folder", help="Destination CODE-Name folder (must be a "
                     "real, recognized folder on disk).")
    acp.add_argument("--dry-run", action="store_true",
                     help="Print the planned action only; move nothing.")
    return p


def _cmd_scan(conn, args):
    root = Path(args.path) if args.path else get_documents_root()
    stats = scan_index(conn, root)
    drift = classify_drift(conn, root)
    print("scan: %d folders, %d files (%d moved, %d removed)" % (
        stats["folders"], stats["files"], stats["moved"], stats["removed"]))
    for name, agg in sorted(drift["uncoded_subfolders"].items()):
        print("  %s: %d uncoded subfolders, %d files"
              % (name, agg["subfolders"], agg["files"]))
    for bucket in ("junk", "misplaced_tooling", "cold_archive",
                   "loose_needs_placement"):
        items = drift[bucket]
        if items:
            print("  %s: %d" % (bucket, len(items)))
    if drift["duplicate"]:
        print("  duplicate groups: %d" % len(drift["duplicate"]))
    if drift["code_mismatch"]:
        print("  code mismatch: %d" % len(drift["code_mismatch"]))
    if drift["unknown_code"]:
        print("  unknown_code: %d" % len(drift["unknown_code"]))
    return 0


def _cmd_place(conn, args):
    codes = load_codes()
    protected = load_protected_paths()
    if not protected:
        # An inert guard and a clean run must never be indistinguishable
        # (ADR 0018) -- absent config still PROCEEDS (a generic user with
        # no protected paths needs a working tool with zero config), but
        # loudly, on stderr, every time the guard has nothing to enforce.
        sys.stderr.write(
            "warning: no protected paths configured (ADR 0018 guard inactive)\n"
        )
    res = place_file(conn, args.file, codes, protected=protected, dry_run=args.dry_run)
    if res["action"] == "refuse-protected-source":
        # No-op refusal (ADR 0018): the SOURCE itself is inside a
        # protected path. Nothing moved, staged, or recorded -- a
        # dedicated line, not the placed/would-place verb used for an
        # actual placement, which would misleadingly imply the file went
        # somewhere.
        print("refused (protected source): %s (protected-path: %s)" % (
            res["src"], res["protected_hit"]))
        return 0
    verb = "would place" if args.dry_run else "placed"
    line = "%s: %s -> %s [%s / %s]" % (
        verb, res["src"], res["dest"], res["code"] or "LOW-CONFIDENCE",
        res["reason"])
    if res.get("protected_hit") is not None:
        # Legal-guardrail refusal must never read as a generic staging
        # collision in the operator-facing preview (ADR 0018) -- name the
        # protected path even when `action` reads "refuse-exists".
        line += " (protected-path: %s)" % res["protected_hit"]
    print(line)
    return 0


def _cmd_query(conn, args):
    for r in query_index(conn, args.terms):
        tags = (" [" + ", ".join(r["tags"]) + "]") if r["tags"] else ""
        print("%s  %s%s" % (r["code"] or "?", r["path"], tags))
    return 0


def _cmd_note(conn, args):
    add_note(conn, args.path, args.text)
    print("noted: %s" % args.path)
    return 0


def _cmd_tag(conn, args):
    add_tags(conn, args.path, args.tags)
    print("tagged: %s [%s]" % (args.path, ", ".join(args.tags)))
    return 0


def _cmd_sweep(conn, args):
    protected = load_protected_paths()
    if not protected:
        # Same ADR 0018 discipline as _cmd_place: an inert guard and an active
        # guard must never be indistinguishable. sweep accepts an arbitrary
        # DIR, so the guard runs defensively on every invocation regardless of
        # target dir (spec section 11.3).
        sys.stderr.write(
            "warning: no protected paths configured (ADR 0018 guard inactive)\n"
        )
    directory = Path(args.dir) if args.dir else Path.home() / "Downloads"
    result = run_sweep(conn, directory, dry_run=args.dry_run,
                       protected=protected)
    if result.get("skipped"):
        print("sweep: already running, skipping")
        return 0
    verb = "would sweep" if args.dry_run else "swept"
    print("%s: %s -- scanned=%d filed=%d staged=%d errored=%d" % (
        verb, directory, result["scanned"], result["filed"],
        result["staged"], result["errored"]))
    return 0


def _cmd_apply_classification(conn, args):
    codes = load_codes()
    protected = load_protected_paths()
    if not protected:
        # Same ADR 0018 discipline as _cmd_place / _cmd_sweep: a guarded run
        # and an unguarded run must never be indistinguishable. The guard runs
        # on every apply-classification call regardless (spec section 12.5).
        sys.stderr.write(
            "warning: no protected paths configured (ADR 0018 guard inactive)\n"
        )
    res = apply_classification(conn, args.file, args.folder, codes,
                               protected=protected, dry_run=args.dry_run)
    action = res["action"]
    if action == "apply":
        verb = "would apply" if args.dry_run else "applied"
        print("%s: %s -> %s [%s]" % (verb, res["src"], res["dest"],
                                     res["code"]))
        return 0
    if action == "refuse-invalid-folder":
        print("refused (unknown folder): %s -- '%s' is not a real, recognized "
              "CODE-Name folder under Documents (nothing moved)"
              % (res["src"], res["folder"]))
        return 0
    # refuse-protected / refuse-exists: staged (or left) in SYS-Unsorted.
    line = "refused (%s): %s -> %s" % (action, res["src"], res["dest"])
    if res.get("protected_hit") is not None:
        # A legal-guardrail refusal must never read as a generic staging
        # collision in the operator-facing line (ADR 0018) -- name the path.
        line += " (protected-path: %s)" % res["protected_hit"]
    print(line)
    return 0


def main(argv=None):
    parser = build_parser()
    args = parser.parse_args(argv)
    if args.root:
        os.environ["FILEORG_DOCUMENTS_ROOT"] = args.root
    if args.db:
        os.environ["FILEORG_DB_PATH"] = args.db
    dispatch = {"scan": _cmd_scan, "place": _cmd_place, "query": _cmd_query,
                "note": _cmd_note, "tag": _cmd_tag, "sweep": _cmd_sweep,
                "apply-classification": _cmd_apply_classification}
    conn = open_db()
    try:
        return dispatch[args.cmd](conn, args)
    except (LookupError, OSError, ProtectedPathError) as exc:
        # ProtectedPathError (ADR 0018) is a refusal, not a crash: nothing
        # was mutated when it fires, but it subclasses RuntimeError, not
        # LookupError/OSError, so it needs its own arm here -- otherwise it
        # would propagate past this handler as an unhandled traceback
        # instead of the clean, actionable message every other guarded CLI
        # failure gets.
        sys.stderr.write("error: %s\n" % exc)
        return 2
    finally:
        conn.close()


if __name__ == "__main__":
    sys.exit(main())
