"""Tests for fileorg. Run: /usr/bin/python3 -m unittest test_fileorg -v

Every test runs against a tempfile fixture tree and a temp DB via the
FILEORG_DOCUMENTS_ROOT / FILEORG_DB_PATH env vars -- never the real
~/Documents and never the real index.db.
"""
import io
import json
import os
import shutil
import sqlite3
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from pathlib import Path
from unittest import mock

import fileorg


class FileorgTestCase(unittest.TestCase):
    """Base fixture: temp Documents root + temp DB, injected via env vars."""

    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp()).resolve()
        self.root = self.tmp / "Documents"
        self.root.mkdir()
        self.db_path = self.tmp / "data" / "index.db"
        self._old_env = {
            k: os.environ.get(k)
            for k in ("FILEORG_DB_PATH", "FILEORG_DOCUMENTS_ROOT", "XDG_DATA_HOME")
        }
        os.environ["FILEORG_DB_PATH"] = str(self.db_path)
        os.environ["FILEORG_DOCUMENTS_ROOT"] = str(self.root)

    def tearDown(self):
        for k, v in self._old_env.items():
            if v is None:
                os.environ.pop(k, None)
            else:
                os.environ[k] = v
        shutil.rmtree(str(self.tmp), ignore_errors=True)

    def write(self, relpath, content=b"x"):
        """Create a file under the temp Documents root, making parent dirs."""
        p = self.root / relpath
        p.parent.mkdir(parents=True, exist_ok=True)
        if isinstance(content, str):
            content = content.encode("utf-8")
        p.write_bytes(content)
        return p

    def snapshot(self, subtree):
        """Relative-path -> identity map for every filesystem entry under
        `subtree`, recursive. Regular files are keyed by content hash;
        symlinks are keyed by their own raw target text (via os.readlink,
        never resolved) so a symlink that got swapped, moved, or replaced
        shows up as a snapshot diff even though its target file is
        untouched. This is the invariant-level assertion primitive (ADR
        0018): run the verb, then assert `snapshot(before) ==
        snapshot(after)` directly against the filesystem -- not against an
        intermediate signal like a returned action string or a DB row."""
        subtree = Path(subtree)
        snap = {}
        for dirpath, _dirnames, filenames in os.walk(str(subtree)):
            for fn in filenames:
                fpath = Path(dirpath) / fn
                rel = str(fpath.relative_to(subtree))
                if fpath.is_symlink():
                    snap[rel] = ("symlink", os.readlink(str(fpath)))
                else:
                    snap[rel] = ("file", fileorg.compute_hash(fpath))
        return snap


class TestPaths(FileorgTestCase):
    def test_db_path_env_override(self):
        self.assertEqual(fileorg.get_db_path(), self.db_path)

    def test_db_path_xdg_default(self):
        del os.environ["FILEORG_DB_PATH"]
        os.environ["XDG_DATA_HOME"] = str(self.tmp / "xdg")
        self.assertEqual(
            fileorg.get_db_path(),
            self.tmp / "xdg" / "file-organizer" / "index.db",
        )

    def test_db_path_home_default(self):
        del os.environ["FILEORG_DB_PATH"]
        os.environ.pop("XDG_DATA_HOME", None)
        self.assertEqual(
            fileorg.get_db_path(),
            Path.home() / ".local" / "share" / "file-organizer" / "index.db",
        )

    def test_documents_root_env_override(self):
        self.assertEqual(fileorg.get_documents_root(), self.root)

    def test_documents_root_default(self):
        del os.environ["FILEORG_DOCUMENTS_ROOT"]
        self.assertEqual(fileorg.get_documents_root(), Path.home() / "Documents")


class TestOpenDb(FileorgTestCase):
    def _tables(self, conn):
        return {
            r[0]
            for r in conn.execute(
                "SELECT name FROM sqlite_master WHERE type='table'"
            )
        }

    def test_creates_db_with_schema_and_version(self):
        conn = fileorg.open_db()
        try:
            self.assertTrue(self.db_path.is_file())
            self.assertEqual(
                self._tables(conn), {"folders", "files", "tags", "file_tags"}
            )
            version = conn.execute("PRAGMA user_version").fetchone()[0]
            self.assertEqual(version, fileorg.SCHEMA_VERSION)
        finally:
            conn.close()

    def test_files_columns_match_spec(self):
        conn = fileorg.open_db()
        try:
            cols = [r[1] for r in conn.execute("PRAGMA table_info(files)")]
            self.assertEqual(
                cols,
                ["id", "path", "folder_id", "code", "filename", "ext", "size",
                 "content_hash", "created_at", "modified_at", "indexed_at",
                 "description"],
            )
            self.assertNotIn("category", cols)
        finally:
            conn.close()

    def test_reopen_preserves_rows(self):
        conn = fileorg.open_db()
        conn.execute(
            "INSERT INTO folders (path, code, name) VALUES (?, ?, ?)",
            ("/x/FIN-Finance", "FIN", "Finance"),
        )
        conn.commit()
        conn.close()
        conn = fileorg.open_db()
        try:
            n = conn.execute("SELECT COUNT(*) FROM folders").fetchone()[0]
            self.assertEqual(n, 1)
        finally:
            conn.close()

    def test_version_mismatch_drops_and_rebuilds(self):
        conn = fileorg.open_db()
        conn.execute(
            "INSERT INTO folders (path, code, name) VALUES (?, ?, ?)",
            ("/x/FIN-Finance", "FIN", "Finance"),
        )
        conn.commit()
        conn.execute("PRAGMA user_version = 999")
        conn.commit()
        conn.close()
        conn = fileorg.open_db()
        try:
            n = conn.execute("SELECT COUNT(*) FROM folders").fetchone()[0]
            self.assertEqual(n, 0)
            version = conn.execute("PRAGMA user_version").fetchone()[0]
            self.assertEqual(version, fileorg.SCHEMA_VERSION)
        finally:
            conn.close()

    def test_explicit_path_argument_wins(self):
        other = self.tmp / "elsewhere" / "other.db"
        conn = fileorg.open_db(other)
        try:
            self.assertTrue(other.is_file())
        finally:
            conn.close()


class TestLoadCodes(FileorgTestCase):
    ALL_CODES = ["FIN", "HSE", "PPL", "WRK", "DIV", "LGL", "HLT", "EDU",
                 "GOV", "AUT", "PET", "ENT", "REF", "PRS", "AST", "TRV"]

    def _write_override(self, data):
        cfg_dir = self.db_path.parent
        cfg_dir.mkdir(parents=True, exist_ok=True)
        (cfg_dir / "codes.local.json").write_text(json.dumps(data))

    def test_default_has_all_16_codes(self):
        codes = fileorg.load_codes()
        self.assertEqual(sorted(codes.keys()), sorted(self.ALL_CODES))
        for code, entry in codes.items():
            self.assertIn("name", entry)
            self.assertIn("keywords", entry)
            self.assertIn("extensions", entry)

    def test_sys_never_in_code_list(self):
        codes = fileorg.load_codes()
        self.assertNotIn("SYS", codes)

    def test_local_override_merges(self):
        self._write_override(
            {"FIN": {"name": "Retirement", "keywords": ["pension"]}}
        )
        codes = fileorg.load_codes()
        self.assertEqual(codes["FIN"]["name"], "Retirement")
        self.assertEqual(codes["FIN"]["keywords"], ["pension"])
        self.assertEqual(codes["FIN"]["extensions"], [])
        self.assertEqual(len(codes), 16)

    def test_local_override_can_add_new_code(self):
        self._write_override(
            {"XYZ": {"name": "Example", "keywords": ["example"]}}
        )
        codes = fileorg.load_codes()
        self.assertIn("XYZ", codes)
        self.assertEqual(len(codes), 17)

    def test_override_defining_sys_is_rejected(self):
        self._write_override({"SYS": {"name": "Nope", "keywords": []}})
        with self.assertRaises(ValueError):
            fileorg.load_codes()

    def test_override_renaming_ref_is_rejected(self):
        self._write_override({"REF": {"name": "Recipes", "keywords": []}})
        with self.assertRaises(ValueError):
            fileorg.load_codes()

    def test_override_may_extend_ref_keywords(self):
        self._write_override({"REF": {"keywords": ["cheatsheet"]}})
        codes = fileorg.load_codes()
        self.assertEqual(codes["REF"]["keywords"], ["cheatsheet"])

    def test_explicit_config_dir_argument(self):
        alt = self.tmp / "altcfg"
        alt.mkdir()
        (alt / "codes.local.json").write_text(
            json.dumps({"TRV": {"name": "Trips"}})
        )
        codes = fileorg.load_codes(config_dir=alt)
        self.assertEqual(codes["TRV"]["name"], "Trips")

    def test_malformed_override_raises_value_error_with_path(self):
        """Malformed JSON in codes.local.json should raise ValueError (not JSONDecodeError) with file path."""
        cfg_dir = self.db_path.parent
        cfg_dir.mkdir(parents=True, exist_ok=True)
        override_path = cfg_dir / "codes.local.json"
        # Write syntactically broken JSON
        override_path.write_text('{"FIN": invalid json}')
        with self.assertRaises(ValueError) as cm:
            fileorg.load_codes()
        # Check message contains the file path and mentions JSON error
        error_msg = str(cm.exception)
        self.assertIn(str(override_path), error_msg)
        self.assertIn("Invalid JSON", error_msg)

    def test_local_override_folders_merge_without_clobbering(self):
        # Two overrides layered by hand-editing codes.local.json to already
        # carry a folders map, then a second write narrowing one folder --
        # exercises load_codes end-to-end, not just the pure merge helper.
        self._write_override({
            "FIN": {"folders": {
                "FIN-Alpha": {"keywords": ["chase"]},
                "FIN-Beta": {"keywords": ["1099"]},
            }}
        })
        codes = fileorg.load_codes()
        self.assertEqual(codes["FIN"]["folders"]["FIN-Alpha"]["keywords"], ["chase"])
        self.assertEqual(codes["FIN"]["folders"]["FIN-Beta"]["keywords"], ["1099"])
        # Code-level keywords from the shipped default must survive --
        # the override never touched FIN's own "keywords".
        self.assertIn("invoice", codes["FIN"]["keywords"])


class TestDeepMergeCodeEntry(unittest.TestCase):
    def test_folders_from_both_sides_are_merged_per_folder(self):
        base = {
            "name": "Finance",
            "keywords": ["invoice"],
            "extensions": [],
            "folders": {
                "FIN-Alpha": {"keywords": ["chase"]},
                "FIN-Beta": {"keywords": ["1099"]},
            },
        }
        override = {"folders": {"FIN-Alpha": {"keywords": ["chase", "wire"]}}}
        merged = fileorg._deep_merge_code_entry(base, override)
        self.assertEqual(merged["folders"]["FIN-Alpha"]["keywords"],
                         ["chase", "wire"])
        # FIN-Beta was not touched by the override -- must survive untouched.
        self.assertEqual(merged["folders"]["FIN-Beta"]["keywords"], ["1099"])
        # Code-level fields untouched by the override are preserved too.
        self.assertEqual(merged["name"], "Finance")
        self.assertEqual(merged["keywords"], ["invoice"])

    def test_code_level_fields_still_replaced_wholesale(self):
        base = {"name": "Finance", "keywords": ["invoice"], "extensions": []}
        override = {"name": "Retirement", "keywords": ["pension"]}
        merged = fileorg._deep_merge_code_entry(base, override)
        self.assertEqual(merged["name"], "Retirement")
        self.assertEqual(merged["keywords"], ["pension"])

    def test_override_only_folders_is_used_as_is(self):
        base = {"name": "Finance", "keywords": [], "extensions": []}
        override = {"folders": {"FIN-Alpha": {"keywords": ["chase"]}}}
        merged = fileorg._deep_merge_code_entry(base, override)
        self.assertEqual(merged["folders"], {"FIN-Alpha": {"keywords": ["chase"]}})


class TestFileMetadata(FileorgTestCase):
    def test_compute_hash_is_sha256_of_bytes(self):
        p = self.write("a.txt", "hello")
        import hashlib
        self.assertEqual(
            fileorg.compute_hash(p), hashlib.sha256(b"hello").hexdigest()
        )

    def test_identical_content_same_hash_different_names(self):
        a = self.write("a.txt", "same-bytes")
        b = self.write("b.pdf", "same-bytes")
        self.assertEqual(fileorg.compute_hash(a), fileorg.compute_hash(b))

    def test_created_at_uses_birthtime_when_available(self):
        p = self.write("a.txt", "hello")
        st = os.stat(str(p))
        if getattr(st, "st_birthtime", 0):
            self.assertEqual(fileorg.get_created_at(p), st.st_birthtime)
        else:
            self.assertEqual(fileorg.get_created_at(p), st.st_mtime)

    def test_created_at_falls_back_to_mtime_not_ctime(self):
        p = self.write("a.txt", "hello")

        class FakeStat(object):
            st_birthtime = 0
            st_mtime = 111.0
            st_ctime = 999.0

        with mock.patch.object(fileorg.os, "stat", return_value=FakeStat()):
            self.assertEqual(fileorg.get_created_at(p), 111.0)

    def test_created_at_falls_back_when_birthtime_missing(self):
        p = self.write("a.txt", "hello")

        class FakeStat(object):
            st_mtime = 222.0
            st_ctime = 999.0

        with mock.patch.object(fileorg.os, "stat", return_value=FakeStat()):
            self.assertEqual(fileorg.get_created_at(p), 222.0)


class TestIsProtectedPath(FileorgTestCase):
    def test_matches_itself(self):
        target = self.root / "LEG-Case" / "Export"
        self.assertEqual(
            fileorg.is_protected_path(target, ["LEG-Case/Export"], self.root),
            "LEG-Case/Export",
        )

    def test_matches_descendant(self):
        target = self.root / "LEG-Case" / "Export" / "exhibit1.pdf"
        self.assertTrue(
            fileorg.is_protected_path(target, ["LEG-Case/Export"], self.root)
        )

    def test_does_not_match_sibling_prefix(self):
        # Segment-boundary match: 'ExportNotes' is a sibling of
        # 'Export', not inside it -- a naive string prefix would
        # wrongly match here (spec section 6 / ADR 0018).
        target = self.root / "LEG-Case" / "ExportNotes" / "note.pdf"
        self.assertIsNone(
            fileorg.is_protected_path(target, ["LEG-Case/Export"], self.root)
        )

    def test_case_insensitive(self):
        target = self.root / "leg-case" / "EXPORT" / "exhibit1.pdf"
        self.assertTrue(
            fileorg.is_protected_path(target, ["LEG-Case/Export"], self.root)
        )

    def test_unrelated_path_is_none(self):
        target = self.root / "FIN-Finance" / "statement.pdf"
        self.assertIsNone(
            fileorg.is_protected_path(target, ["LEG-Case/Export"], self.root)
        )

    def test_outside_root_is_none(self):
        outside = self.tmp / "elsewhere" / "file.pdf"
        self.assertIsNone(
            fileorg.is_protected_path(outside, ["LEG-Case/Export"], self.root)
        )

    def test_empty_protected_list_is_none(self):
        target = self.root / "LEG-Case" / "Export" / "exhibit1.pdf"
        self.assertIsNone(fileorg.is_protected_path(target, [], self.root))

    def test_top_segment_sibling_prefix_does_not_match(self):
        # Top-level sibling-prefix non-match: 'LEG-CaseArchive' is a sibling
        # of 'LEG-Case', not a parent -- a naive string prefix would
        # wrongly match (spec section 6 / ADR 0018).
        target = self.root / "LEG-CaseArchive" / "Export" / "file.pdf"
        self.assertIsNone(
            fileorg.is_protected_path(target, ["LEG-Case/Export"], self.root)
        )

    def test_top_level_sibling_prefix_does_not_match(self):
        # Top-level sibling-prefix non-match: 'LEG-CaseArchive' is a sibling
        # of 'LEG-Case', not inside it -- protected path is top-level only.
        target = self.root / "LEG-CaseArchive" / "file.pdf"
        self.assertIsNone(
            fileorg.is_protected_path(target, ["LEG-Case"], self.root)
        )

    def test_case_insensitive_sibling_prefix_does_not_match(self):
        # Case-insensitive sibling-prefix non-match: case-insensitivity must not
        # turn segment-boundary matching into a sloppy string prefix match.
        target = self.root / "leg-casearchive" / "export" / "file.pdf"
        self.assertIsNone(
            fileorg.is_protected_path(target, ["LEG-Case/Export"], self.root)
        )


class TestLoadProtectedPaths(FileorgTestCase):
    def _write_override(self, data):
        cfg_dir = self.db_path.parent
        cfg_dir.mkdir(parents=True, exist_ok=True)
        (cfg_dir / "codes.local.json").write_text(json.dumps(data))

    def test_empty_when_no_override_file(self):
        self.assertEqual(fileorg.load_protected_paths(), [])

    def test_reads_protected_list(self):
        cfg_dir = self.db_path.parent
        cfg_dir.mkdir(parents=True, exist_ok=True)
        (cfg_dir / "codes.local.json").write_text(
            json.dumps({"protected": ["LEG-Case/Export"]})
        )
        self.assertEqual(fileorg.load_protected_paths(), ["LEG-Case/Export"])

    def test_missing_protected_key_is_empty(self):
        cfg_dir = self.db_path.parent
        cfg_dir.mkdir(parents=True, exist_ok=True)
        (cfg_dir / "codes.local.json").write_text(json.dumps({"FIN": {"name": "X"}}))
        self.assertEqual(fileorg.load_protected_paths(), [])

    def test_trailing_slash_entry_still_loads(self):
        self._write_override({"protected": ["LEG-Case/Export/"]})
        self.assertEqual(fileorg.load_protected_paths(), ["LEG-Case/Export/"])

    def test_non_list_protected_value_raises(self):
        # A bare string instead of a list is an easy, natural JSON mistake --
        # list("LEG-Case/Export") would silently shred it into 15
        # single-character entries that never match anything, leaving the
        # protected-path guard silently inert. Must fail loud instead.
        self._write_override({"protected": "LEG-Case/Export"})
        with self.assertRaises(ValueError) as cm:
            fileorg.load_protected_paths()
        self.assertIn("protected", str(cm.exception).lower())

    def test_dict_protected_value_raises(self):
        self._write_override({"protected": {"LEG-Case/Export": True}})
        with self.assertRaises(ValueError):
            fileorg.load_protected_paths()

    def test_number_protected_value_raises(self):
        self._write_override({"protected": 1})
        with self.assertRaises(ValueError):
            fileorg.load_protected_paths()

    def test_non_string_entry_raises(self):
        self._write_override({"protected": ["LEG-Case/Export", 42]})
        with self.assertRaises(ValueError):
            fileorg.load_protected_paths()

    def test_absolute_path_entry_raises(self):
        # An entry accidentally written with a leading slash never matches
        # anything in is_protected_path (rel.parts never carries a leading
        # '/'), so this must be rejected loudly rather than silently
        # protecting nothing.
        self._write_override({"protected": ["/LEG-Case/Export"]})
        with self.assertRaises(ValueError) as cm:
            fileorg.load_protected_paths()
        error_msg = str(cm.exception)
        self.assertIn("relative", error_msg.lower())
        self.assertIn("0018", error_msg)

    def test_empty_string_entry_raises(self):
        # Path("").parts == () matches every path via the parts[:0] == ()
        # rule -- an empty entry would silently protect the whole tree.
        self._write_override({"protected": [""]})
        with self.assertRaises(ValueError):
            fileorg.load_protected_paths()

    def test_whitespace_only_entry_raises(self):
        self._write_override({"protected": ["   "]})
        with self.assertRaises(ValueError):
            fileorg.load_protected_paths()

    def test_dotdot_entry_raises(self):
        # "LEG-Case/../Export" resolves outside LEG-Case and never
        # matches anything under is_protected_path's segment-prefix rule --
        # the same inert-guard class as the other rejected shapes here. Must
        # fail loud rather than silently protecting nothing.
        self._write_override({"protected": ["LEG-Case/../Export"]})
        with self.assertRaises(ValueError) as cm:
            fileorg.load_protected_paths()
        error_msg = str(cm.exception)
        self.assertIn("LEG-Case/../Export", error_msg)
        self.assertIn("..", error_msg)

    def test_leading_dotdot_entry_raises(self):
        self._write_override({"protected": ["../Secret"]})
        with self.assertRaises(ValueError):
            fileorg.load_protected_paths()

    def test_dot_prefixed_entry_still_loads(self):
        # "./LEG-Case/Export" is fine -- Path() drops the leading '.'
        # and this must NOT be rejected as a '..' entry.
        self._write_override({"protected": ["./LEG-Case/Export"]})
        self.assertEqual(
            fileorg.load_protected_paths(), ["./LEG-Case/Export"]
        )

    def test_load_codes_ignores_protected_key(self):
        # codes.local.json legitimately carries BOTH code overrides and a
        # top-level 'protected' list (ADR 0018) in the same file --
        # load_codes must not treat 'protected' as a code entry: its value
        # is a list, not a code dict, and previously crashed
        # `dict.update()` inside the per-code merge loop (confirmed via a
        # live repro before this fix: ValueError, "dictionary update
        # sequence element #0 has length 21; 2 is required").
        cfg_dir = self.db_path.parent
        cfg_dir.mkdir(parents=True, exist_ok=True)
        (cfg_dir / "codes.local.json").write_text(json.dumps({
            "FIN": {"name": "Retirement"},
            "protected": ["LEG-Case/Export"],
        }))
        codes = fileorg.load_codes()
        self.assertEqual(codes["FIN"]["name"], "Retirement")
        self.assertNotIn("protected", codes)


class TestScanCore(FileorgTestCase):
    def _scan(self):
        conn = fileorg.open_db()
        try:
            return conn, fileorg.scan_index(conn)
        finally:
            pass

    def test_parse_folder_code(self):
        self.assertEqual(fileorg.parse_folder_code("FIN-Finance"),
                         ("FIN", "Finance"))
        self.assertEqual(fileorg.parse_folder_code("WRK-Work"),
                         ("WRK", "Work"))
        self.assertEqual(fileorg.parse_folder_code("Downloads"), (None, None))
        self.assertEqual(fileorg.parse_folder_code("lower-case"), (None, None))

    def test_scan_indexes_files_and_folders(self):
        self.write("FIN-Finance/statement.pdf", "aaa")
        self.write("WRK-Work/offer.pdf", "bbb")
        conn = fileorg.open_db()
        stats = fileorg.scan_index(conn)
        self.assertEqual(stats["files"], 2)
        self.assertEqual(stats["folders"], 2)
        rows = {r["filename"]: r for r in conn.execute("SELECT * FROM files")}
        self.assertEqual(rows["statement.pdf"]["code"], "FIN")
        self.assertEqual(rows["statement.pdf"]["ext"], "pdf")
        self.assertEqual(rows["offer.pdf"]["code"], "WRK")
        conn.close()

    def test_scan_is_idempotent(self):
        self.write("FIN-Finance/statement.pdf", "aaa")
        conn = fileorg.open_db()
        fileorg.scan_index(conn)
        fileorg.scan_index(conn)
        n = conn.execute("SELECT COUNT(*) FROM files").fetchone()[0]
        self.assertEqual(n, 1)
        nf = conn.execute("SELECT COUNT(*) FROM folders").fetchone()[0]
        self.assertEqual(nf, 1)
        conn.close()

    def test_moved_file_updates_path_preserving_metadata(self):
        p = self.write("FIN-Finance/statement.pdf", "unique-bytes")
        conn = fileorg.open_db()
        fileorg.scan_index(conn)
        fid = conn.execute("SELECT id FROM files").fetchone()[0]
        conn.execute("UPDATE files SET description=? WHERE id=?",
                     ("my note", fid))
        cur = conn.execute("INSERT INTO tags (name) VALUES ('important')")
        tid = cur.lastrowid
        conn.execute("INSERT INTO file_tags (file_id, tag_id) VALUES (?, ?)",
                     (fid, tid))
        conn.commit()
        # move the file to a different coded folder on disk
        dest = self.root / "WRK-Work" / "statement.pdf"
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.move(str(p), str(dest))
        stats = fileorg.scan_index(conn)
        self.assertEqual(stats["moved"], 1)
        rows = list(conn.execute("SELECT * FROM files"))
        self.assertEqual(len(rows), 1)
        self.assertEqual(rows[0]["id"], fid)
        self.assertEqual(rows[0]["path"], str(dest))
        self.assertEqual(rows[0]["code"], "WRK")
        self.assertEqual(rows[0]["description"], "my note")
        tag_count = conn.execute(
            "SELECT COUNT(*) FROM file_tags WHERE file_id=?", (fid,)
        ).fetchone()[0]
        self.assertEqual(tag_count, 1)
        conn.close()

    def test_scan_removes_rows_for_deleted_files(self):
        p = self.write("FIN-Finance/gone.pdf", "zzz")
        conn = fileorg.open_db()
        fileorg.scan_index(conn)
        os.remove(str(p))
        stats = fileorg.scan_index(conn)
        self.assertEqual(stats["removed"], 1)
        n = conn.execute("SELECT COUNT(*) FROM files").fetchone()[0]
        self.assertEqual(n, 0)
        conn.close()

    def test_scan_prunes_stale_folder_rows(self):
        # A top-level folder deleted from disk must not leave an orphan
        # folders row behind (spec section 4) -- inflates the folder count
        # forever otherwise (final review fix).
        self.write("FIN-Finance/statement.pdf", "aaa")
        self.write("WRK-Work/offer.pdf", "bbb")
        conn = fileorg.open_db()
        fileorg.scan_index(conn)
        n_before = conn.execute("SELECT COUNT(*) FROM folders").fetchone()[0]
        self.assertEqual(n_before, 2)
        shutil.rmtree(str(self.root / "WRK-Work"))
        stats = fileorg.scan_index(conn)
        n_after = conn.execute("SELECT COUNT(*) FROM folders").fetchone()[0]
        self.assertEqual(n_after, 1)
        self.assertEqual(stats["folders_removed"], 1)
        conn.close()


class TestClassifyDrift(FileorgTestCase):
    def test_junk_ds_store_and_empty_dir(self):
        self.write("FIN-Finance/statement.pdf", "aaa")
        self.write("FIN-Finance/.DS_Store", "x")
        (self.root / "Zoom").mkdir()
        conn = fileorg.open_db()
        fileorg.scan_index(conn)
        drift = fileorg.classify_drift(conn)
        junk = drift["junk"]
        self.assertTrue(any(p.endswith(".DS_Store") for p in junk))
        self.assertTrue(any(p.endswith("Zoom") for p in junk))
        conn.close()

    def test_misplaced_tooling(self):
        self.write("Claude/notes.md", "x")
        self.write("skills/thing.py", "y")
        conn = fileorg.open_db()
        fileorg.scan_index(conn)
        drift = fileorg.classify_drift(conn)
        names = {Path(p).name for p in drift["misplaced_tooling"]}
        self.assertEqual(names, {"Claude", "skills"})
        conn.close()

    def test_cold_archive(self):
        p = self.write("_ARCHIVE.zip", b"")
        with open(str(p), "wb") as fh:
            fh.seek(fileorg.COLD_ARCHIVE_MIN_BYTES)
            fh.write(b"\0")
        conn = fileorg.open_db()
        fileorg.scan_index(conn)
        drift = fileorg.classify_drift(conn)
        self.assertTrue(any(p.endswith("_ARCHIVE.zip")
                            for p in drift["cold_archive"]))
        conn.close()

    def test_loose_files_at_coded_root_are_per_item(self):
        self.write("AAA-Alpha/loose1.pdf", "a")
        self.write("AAA-Alpha/loose2.pdf", "b")
        conn = fileorg.open_db()
        fileorg.scan_index(conn)
        drift = fileorg.classify_drift(conn)
        loose = {Path(p).name for p in drift["loose_needs_placement"]}
        self.assertEqual(loose, {"loose1.pdf", "loose2.pdf"})
        conn.close()

    def test_uncoded_subfolder_files_are_aggregated_not_per_item(self):
        # Files inside a plain-named subfolder must NOT be per-item drift.
        self.write("WRK-Work/2024/a.pdf", "a")
        self.write("WRK-Work/2024/b.pdf", "b")
        self.write("WRK-Work/2025/c.pdf", "c")
        conn = fileorg.open_db()
        fileorg.scan_index(conn)
        drift = fileorg.classify_drift(conn)
        self.assertEqual(drift["loose_needs_placement"], [])
        agg = drift["uncoded_subfolders"]["WRK-Work"]
        self.assertEqual(agg["subfolders"], 2)
        self.assertEqual(agg["files"], 3)
        conn.close()

    def test_duplicate_groups_by_hash(self):
        self.write("FIN-Finance/sample_trip.pdf", "identical")
        self.write("TRV-Travel/sample_trip_copy.pdf", "identical")
        self.write("FIN-Finance/unique.pdf", "solo")
        conn = fileorg.open_db()
        fileorg.scan_index(conn)
        drift = fileorg.classify_drift(conn)
        self.assertEqual(len(drift["duplicate"]), 1)
        self.assertEqual(len(drift["duplicate"][0]), 2)
        conn.close()

    def test_code_mismatch_flagged(self):
        self.write("FIN-Finance/statement.pdf", "a")
        conn = fileorg.open_db()
        fileorg.scan_index(conn)
        conn.execute("UPDATE files SET code='WRK' WHERE filename='statement.pdf'")
        conn.commit()
        drift = fileorg.classify_drift(conn)
        self.assertEqual(len(drift["code_mismatch"]), 1)
        conn.close()

    def test_unknown_code_folder_flagged(self):
        # ZZZ is not in the shipped 16-code list -- surfaced, not silently
        # treated as a valid taxonomy folder (spec section 5).
        self.write("ZZZ-Whatever/thing.pdf", "a")
        conn = fileorg.open_db()
        fileorg.scan_index(conn)
        drift = fileorg.classify_drift(conn)
        names = {Path(p).name for p in drift["unknown_code"]}
        self.assertEqual(names, {"ZZZ-Whatever"})
        conn.close()

    def test_sys_prefix_reserved_folders_exempt_from_drift(self):
        # Constraint: SYS- reserved (e.g. SYS-Unsorted/) must not be flagged as
        # unknown_code or drift. This applies to ANY SYS- prefixed folder, not
        # just the exact literal SYS-Unsorted name.
        self.write("SYS-Unsorted/note.pdf", "a")
        self.write("SYS-Backup/old.pdf", "b")
        conn = fileorg.open_db()
        fileorg.scan_index(conn)
        drift = fileorg.classify_drift(conn)

        # SYS- folders should NOT appear in unknown_code
        unknown_names = {Path(p).name for p in drift["unknown_code"]}
        self.assertNotIn("SYS-Unsorted", unknown_names)
        self.assertNotIn("SYS-Backup", unknown_names)

        # Their files should NOT be in loose_needs_placement
        loose_names = {Path(p).name for p in drift["loose_needs_placement"]}
        self.assertNotIn("note.pdf", loose_names)
        self.assertNotIn("old.pdf", loose_names)

        # SYS- folders should NOT appear in misplaced_tooling
        tooling_names = {Path(p).name for p in drift["misplaced_tooling"]}
        self.assertNotIn("SYS-Unsorted", tooling_names)
        self.assertNotIn("SYS-Backup", tooling_names)

        conn.close()


class TestNoteAndTag(FileorgTestCase):
    def _indexed(self):
        p = self.write("FIN-Finance/statement.pdf", "aaa")
        conn = fileorg.open_db()
        fileorg.scan_index(conn)
        return conn, p

    def test_add_note_sets_description(self):
        conn, p = self._indexed()
        fileorg.add_note(conn, p, "2024 pension summary")
        row = conn.execute("SELECT description FROM files WHERE path=?",
                           (str(p),)).fetchone()
        self.assertEqual(row["description"], "2024 pension summary")
        conn.close()

    def test_add_note_unknown_path_raises(self):
        conn, _ = self._indexed()
        with self.assertRaises(LookupError):
            fileorg.add_note(conn, self.root / "nope.pdf", "x")
        conn.close()

    def test_add_tags_links_and_dedups(self):
        conn, p = self._indexed()
        fileorg.add_tags(conn, p, ["Pension", "important"])
        fileorg.add_tags(conn, p, ["important", "2024"])
        fid = conn.execute("SELECT id FROM files WHERE path=?",
                          (str(p),)).fetchone()["id"]
        self.assertEqual(fileorg.get_tags(conn, fid),
                        ["2024", "important", "pension"])
        n_tags = conn.execute("SELECT COUNT(*) FROM tags").fetchone()[0]
        self.assertEqual(n_tags, 3)
        conn.close()

    def test_add_tags_skips_empty(self):
        conn, p = self._indexed()
        fileorg.add_tags(conn, p, ["", "  ", "real"])
        fid = conn.execute("SELECT id FROM files WHERE path=?",
                          (str(p),)).fetchone()["id"]
        self.assertEqual(fileorg.get_tags(conn, fid), ["real"])
        conn.close()

    def test_add_tags_unknown_path_raises(self):
        conn, _ = self._indexed()
        with self.assertRaises(LookupError):
            fileorg.add_tags(conn, self.root / "nope.pdf", ["x"])
        conn.close()


class TestQuery(FileorgTestCase):
    def _setup(self):
        self.write("FIN-Finance/pension_summary.pdf", "a")
        self.write("WRK-Work/offer_letter.pdf", "b")
        self.write("TRV-Travel/sample_trip.pdf", "c")
        conn = fileorg.open_db()
        fileorg.scan_index(conn)
        fileorg.add_note(conn, self.root / "TRV-Travel/sample_trip.pdf",
                        "Sample trip itinerary")
        fileorg.add_tags(conn, self.root / "WRK-Work/offer_letter.pdf",
                        ["salary", "2024"])
        return conn

    def test_query_by_filename(self):
        conn = self._setup()
        res = fileorg.query_index(conn, ["pension"])
        self.assertEqual([Path(r["path"]).name for r in res],
                        ["pension_summary.pdf"])
        conn.close()

    def test_query_by_code(self):
        conn = self._setup()
        res = fileorg.query_index(conn, ["TRV"])
        self.assertEqual([Path(r["path"]).name for r in res], ["sample_trip.pdf"])
        conn.close()

    def test_query_by_description(self):
        conn = self._setup()
        res = fileorg.query_index(conn, ["itinerary"])
        self.assertEqual([Path(r["path"]).name for r in res], ["sample_trip.pdf"])
        conn.close()

    def test_query_by_tag(self):
        conn = self._setup()
        res = fileorg.query_index(conn, ["salary"])
        self.assertEqual([Path(r["path"]).name for r in res],
                        ["offer_letter.pdf"])
        self.assertIn("salary", res[0]["tags"])
        conn.close()

    def test_query_terms_are_anded(self):
        conn = self._setup()
        res = fileorg.query_index(conn, ["sample", "trip"])
        self.assertEqual([Path(r["path"]).name for r in res], ["sample_trip.pdf"])
        res2 = fileorg.query_index(conn, ["sample", "salary"])
        self.assertEqual(res2, [])
        conn.close()

    def test_query_empty_returns_all(self):
        conn = self._setup()
        res = fileorg.query_index(conn, [])
        self.assertEqual(len(res), 3)
        conn.close()


class TestClassifyFile(FileorgTestCase):
    def setUp(self):
        super().setUp()
        self.codes = fileorg.load_codes()

    def test_already_coded_relocation_wins(self):
        p = self.root / "FIN-Finance" / "random_name.pdf"
        code, reason = fileorg.classify_file(p, self.codes)
        self.assertEqual(code, "FIN")
        self.assertEqual(reason, "already-coded")

    def test_keyword_match(self):
        p = self.root / "loose_invoice_march.pdf"
        code, reason = fileorg.classify_file(p, self.codes)
        self.assertEqual(code, "FIN")
        self.assertEqual(reason, "keyword-match")

    def test_extension_match(self):
        p = self.root / "song.mp3"
        code, reason = fileorg.classify_file(p, self.codes)
        self.assertEqual(code, "ENT")
        self.assertEqual(reason, "keyword-match")

    def test_low_confidence_no_match(self):
        p = self.root / "xyzzy12345.dat"
        code, reason = fileorg.classify_file(p, self.codes)
        self.assertIsNone(code)
        self.assertEqual(reason, "low-confidence")

    def test_low_confidence_on_tie(self):
        # 'passport' -> GOV, 'lease' -> HSE: one keyword each, a tie.
        p = self.root / "passport_lease.pdf"
        code, reason = fileorg.classify_file(p, self.codes)
        self.assertIsNone(code)
        self.assertEqual(reason, "low-confidence")

    def test_uncoded_toplevel_folder_does_not_count_as_coded(self):
        p = self.root / "Downloads" / "invoice.pdf"
        code, reason = fileorg.classify_file(p, self.codes)
        self.assertEqual(code, "FIN")
        self.assertEqual(reason, "keyword-match")


class TestPlaceFile(FileorgTestCase):
    def setUp(self):
        super().setUp()
        self.codes = fileorg.load_codes()
        self.conn = fileorg.open_db()

    def tearDown(self):
        self.conn.close()
        super().tearDown()

    def test_confident_move_to_coded_folder(self):
        # Exactly one FIN-* folder exists -- the unambiguous case.
        (self.root / "FIN-Finance").mkdir()
        p = self.write("invoice_2024.pdf", "a")
        res = fileorg.place_file(self.conn, p, self.codes)
        dest = self.root / "FIN-Finance" / "invoice_2024.pdf"
        self.assertTrue(res["moved"])
        self.assertEqual(res["action"], "place")
        self.assertTrue(dest.exists())
        self.assertFalse(p.exists())
        row = self.conn.execute("SELECT code FROM files WHERE path=?",
                               (str(dest),)).fetchone()
        self.assertEqual(row["code"], "FIN")

    def test_already_filed_file_is_noop_not_restaged(self):
        # A file already correctly filed at its destination must be a no-op --
        # never re-routed into SYS-Unsorted (idempotency, spec section 6).
        (self.root / "FIN-Finance").mkdir()
        p = self.write("FIN-Finance/invoice_2024.pdf", "a")
        res = fileorg.place_file(self.conn, p, self.codes)
        self.assertEqual(res["action"], "noop")
        self.assertFalse(res["moved"])
        self.assertTrue(p.exists())
        staged = self.root / fileorg.SYS_UNSORTED / "invoice_2024.pdf"
        self.assertFalse(staged.exists())

    def test_already_filed_file_noop_even_with_multiple_folders_for_code(self):
        # Idempotency (spec section 6) must hold even when the file's code
        # maps to >1 existing folders (e.g. FIN-Finance and FIN-Savings both
        # parse to FIN). An already-correctly-filed file must stay a no-op,
        # not get swept into SYS-Unsorted just because the code is ambiguous
        # (final review fix).
        (self.root / "FIN-Finance").mkdir()
        (self.root / "FIN-Savings").mkdir()
        p = self.write("FIN-Finance/random_name.pdf", "a")
        res = fileorg.place_file(self.conn, p, self.codes)
        self.assertEqual(res["action"], "noop")
        self.assertFalse(res["moved"])
        self.assertEqual(res["code"], "FIN")
        self.assertTrue(p.exists())
        staged = self.root / fileorg.SYS_UNSORTED / "random_name.pdf"
        self.assertFalse(staged.exists())

    def test_ambiguous_zero_folders_for_code_goes_to_unsorted(self):
        # No FIN-* folder exists yet -- a confident code is never used to
        # create a new default-named folder (spec section 3.3).
        p = self.write("invoice_2024.pdf", "a")
        res = fileorg.place_file(self.conn, p, self.codes)
        dest = self.root / fileorg.SYS_UNSORTED / "invoice_2024.pdf"
        self.assertEqual(res["action"], "stage-unsorted")
        self.assertIsNone(res["code"])
        self.assertTrue(dest.exists())
        fid = self.conn.execute("SELECT id FROM files WHERE path=?",
                              (str(dest),)).fetchone()["id"]
        self.assertIn(fileorg.NEEDS_REVIEW_TAG, fileorg.get_tags(self.conn, fid))

    def test_ambiguous_multiple_folders_for_code_goes_to_unsorted(self):
        # Two FIN-* folders share the code, neither configured with its own
        # folders keywords -- stage 2 still runs (spec section 3.3: "more
        # than one such folder... run the second scoring stage... rather
        # than downgrading automatically") and ties via the shared
        # code-level keyword, so this is a stage-2 miss with the code
        # preserved (folder-ambiguous), not the generic zero-folders
        # low-confidence case below.
        (self.root / "FIN-Finance").mkdir()
        (self.root / "FIN-Taxes").mkdir()
        p = self.write("invoice_2024.pdf", "a")
        res = fileorg.place_file(self.conn, p, self.codes)
        dest = self.root / fileorg.SYS_UNSORTED / "invoice_2024.pdf"
        self.assertEqual(res["action"], "stage-folder-ambiguous")
        self.assertEqual(res["code"], "FIN")
        self.assertTrue(dest.exists())
        fid = self.conn.execute("SELECT id FROM files WHERE path=?",
                              (str(dest),)).fetchone()["id"]
        self.assertIn(fileorg.NEEDS_REVIEW_TAG, fileorg.get_tags(self.conn, fid))
        row = self.conn.execute("SELECT description FROM files WHERE id=?",
                              (fid,)).fetchone()
        self.assertEqual(row["description"], "folder-ambiguous: code=FIN")

    def test_low_confidence_goes_to_unsorted_with_marker(self):
        p = self.write("xyzzy98765.dat", "a")
        res = fileorg.place_file(self.conn, p, self.codes)
        dest = self.root / fileorg.SYS_UNSORTED / "xyzzy98765.dat"
        self.assertEqual(res["action"], "stage-unsorted")
        self.assertIsNone(res["code"])
        self.assertTrue(dest.exists())
        fid = self.conn.execute("SELECT id FROM files WHERE path=?",
                              (str(dest),)).fetchone()["id"]
        self.assertIn(fileorg.NEEDS_REVIEW_TAG, fileorg.get_tags(self.conn, fid))

    def test_destination_exists_is_refused_and_staged(self):
        existing = self.write("FIN-Finance/invoice_2024.pdf", "original")
        p = self.write("invoice_2024.pdf", "new-different")
        res = fileorg.place_file(self.conn, p, self.codes)
        self.assertEqual(res["action"], "refuse-exists")
        # Original at the coded destination is untouched.
        self.assertEqual(existing.read_bytes(), b"original")
        staged = self.root / fileorg.SYS_UNSORTED / "invoice_2024.pdf"
        self.assertTrue(staged.exists())
        self.assertEqual(staged.read_bytes(), b"new-different")

    def test_verify_before_recording_raises_on_missing(self):
        (self.root / "FIN-Finance").mkdir()
        p = self.write("invoice_2024.pdf", "a")

        def fake_move(src, dst):
            os.remove(src)  # simulate a move that loses the file

        with mock.patch.object(fileorg.shutil, "move", side_effect=fake_move):
            with self.assertRaises(RuntimeError):
                fileorg.place_file(self.conn, p, self.codes)
        n = self.conn.execute("SELECT COUNT(*) FROM files").fetchone()[0]
        self.assertEqual(n, 0)

    def test_double_collision_in_unsorted_raises_and_preserves_both(self):
        # A file needs staging in SYS-Unsorted/ but that exact destination
        # name is ALREADY occupied there. place_file must raise FileExistsError
        # (stop, never clobber) and preserve both the staged file and the source.
        # Use a low-confidence file (code=None) to route through SYS-Unsorted.
        staged = self.write("SYS-Unsorted/mystery.dat", "original-staged")
        p = self.write("mystery.dat", "source-new-different")
        with self.assertRaises(FileExistsError):
            fileorg.place_file(self.conn, p, self.codes)
        # Both files must be untouched.
        self.assertEqual(staged.read_bytes(), b"original-staged")
        self.assertTrue(p.exists())
        self.assertEqual(p.read_bytes(), b"source-new-different")

    def test_dry_run_touches_nothing(self):
        (self.root / "FIN-Finance").mkdir()
        p = self.write("invoice_2024.pdf", "a")
        plan = fileorg.place_file(self.conn, p, self.codes, dry_run=True)
        self.assertEqual(plan["code"], "FIN")
        self.assertEqual(plan["action"], "place")
        self.assertFalse(plan["moved"])
        self.assertTrue(p.exists())
        # Destination must not have been created.
        dest = self.root / "FIN-Finance" / "invoice_2024.pdf"
        self.assertFalse(dest.exists())
        n = self.conn.execute("SELECT COUNT(*) FROM files").fetchone()[0]
        self.assertEqual(n, 0)


class TestClassifyFolder(FileorgTestCase):
    def setUp(self):
        super().setUp()
        self.code_entry = {
            "name": "Finance",
            "keywords": ["invoice", "receipt"],
            "extensions": [],
            "folders": {
                "FIN-Alpha": {"keywords": ["chase", "checking"]},
                "FIN-Beta": {"keywords": ["1099", "tax"]},
            },
        }

    def test_winner_by_folder_specific_keyword(self):
        (self.root / "FIN-Alpha").mkdir()
        (self.root / "FIN-Beta").mkdir()
        folders = fileorg.folders_for_code(self.root, "FIN")
        p = self.root / "chase_checking_statement.pdf"
        winner = fileorg.classify_folder(p, self.code_entry, folders)
        self.assertEqual(winner.name, "FIN-Alpha")

    def test_winner_via_runtime_keyword_union(self):
        # 'invoice' only lives in the CODE-level keywords, not either
        # folder's own list -- the runtime union still counts it toward
        # both, but FIN-Alpha also matches its own 'chase' so it wins
        # outright rather than tying.
        (self.root / "FIN-Alpha").mkdir()
        (self.root / "FIN-Beta").mkdir()
        folders = fileorg.folders_for_code(self.root, "FIN")
        p = self.root / "chase_invoice.pdf"
        winner = fileorg.classify_folder(p, self.code_entry, folders)
        self.assertEqual(winner.name, "FIN-Alpha")

    def test_tie_yields_no_winner(self):
        # 'invoice' hits via the runtime union for BOTH folders equally --
        # neither folder's own keywords break the tie (strict tie-break,
        # spec section 3.3: no closest-match heuristic).
        (self.root / "FIN-Alpha").mkdir()
        (self.root / "FIN-Beta").mkdir()
        folders = fileorg.folders_for_code(self.root, "FIN")
        p = self.root / "invoice_march.pdf"
        winner = fileorg.classify_folder(p, self.code_entry, folders)
        self.assertIsNone(winner)

    def test_zero_score_yields_no_winner(self):
        (self.root / "FIN-Alpha").mkdir()
        (self.root / "FIN-Beta").mkdir()
        folders = fileorg.folders_for_code(self.root, "FIN")
        p = self.root / "xyzzy98765.dat"
        winner = fileorg.classify_folder(p, self.code_entry, folders)
        self.assertIsNone(winner)

    def test_folder_with_no_config_entry_scores_only_code_keywords(self):
        # A folder absent from code_entry["folders"] still participates,
        # scored on the code-level keywords alone (empty own-keyword set).
        # (Single folder here, deliberately -- a code-level keyword hit
        # applies identically to every folder via the runtime union, so
        # with a peer folder present this would tie rather than win.)
        (self.root / "FIN-Gamma").mkdir()
        folders = fileorg.folders_for_code(self.root, "FIN")
        p = self.root / "receipt_only.pdf"
        winner = fileorg.classify_folder(p, self.code_entry, folders)
        self.assertEqual(winner.name, "FIN-Gamma")


class TestPlaceFileStage2Folders(FileorgTestCase):
    def setUp(self):
        super().setUp()
        cfg_dir = self.db_path.parent
        cfg_dir.mkdir(parents=True, exist_ok=True)
        (cfg_dir / "codes.local.json").write_text(json.dumps({
            "FIN": {"folders": {
                "FIN-Alpha": {"keywords": ["chase", "checking"]},
                "FIN-Beta": {"keywords": ["1099", "tax"]},
            }}
        }))
        self.codes = fileorg.load_codes()
        self.conn = fileorg.open_db()

    def tearDown(self):
        self.conn.close()
        super().tearDown()

    def test_stage2_winner_places_into_specific_folder(self):
        (self.root / "FIN-Alpha").mkdir()
        (self.root / "FIN-Beta").mkdir()
        p = self.write("chase_checking_statement.pdf", "a")
        res = fileorg.place_file(self.conn, p, self.codes)
        dest = self.root / "FIN-Alpha" / "chase_checking_statement.pdf"
        self.assertEqual(res["action"], "place")
        self.assertEqual(res["code"], "FIN")
        self.assertTrue(dest.exists())
        self.assertFalse(p.exists())

    def test_stage2_tie_stages_to_unsorted_with_both_markers(self):
        (self.root / "FIN-Alpha").mkdir()
        (self.root / "FIN-Beta").mkdir()
        p = self.write("invoice_march.pdf", "a")
        res = fileorg.place_file(self.conn, p, self.codes)
        dest = self.root / fileorg.SYS_UNSORTED / "invoice_march.pdf"
        self.assertEqual(res["action"], "stage-folder-ambiguous")
        self.assertEqual(res["code"], "FIN")
        self.assertTrue(dest.exists())
        fid = self.conn.execute("SELECT id FROM files WHERE path=?",
                              (str(dest),)).fetchone()["id"]
        self.assertIn(fileorg.NEEDS_REVIEW_TAG, fileorg.get_tags(self.conn, fid))
        row = self.conn.execute("SELECT description FROM files WHERE id=?",
                              (fid,)).fetchone()
        self.assertEqual(row["description"], "folder-ambiguous: code=FIN")


class TestPlaceFileProtectedPaths(FileorgTestCase):
    def setUp(self):
        super().setUp()
        self.cfg_dir = self.db_path.parent
        self.cfg_dir.mkdir(parents=True, exist_ok=True)
        self.conn = fileorg.open_db()

    def tearDown(self):
        self.conn.close()
        super().tearDown()

    def _write_cfg(self, data):
        (self.cfg_dir / "codes.local.json").write_text(json.dumps(data))

    def test_protected_top_level_folder_is_refused_and_staged(self):
        self._write_cfg({
            "protected": ["LEG-Case"],
            "LEG": {"name": "Case", "keywords": ["case"], "extensions": []},
        })
        codes = fileorg.load_codes()
        (self.root / "LEG-Case").mkdir()
        p = self.write("case_summary_draft.pdf", "a")
        res = fileorg.place_file(self.conn, p, codes)
        protected_dest = self.root / "LEG-Case" / "case_summary_draft.pdf"
        staged = self.root / fileorg.SYS_UNSORTED / "case_summary_draft.pdf"
        self.assertEqual(res["action"], "refuse-protected")
        self.assertFalse(protected_dest.exists())
        self.assertTrue(staged.exists())
        fid = self.conn.execute("SELECT id FROM files WHERE path=?",
                              (str(staged),)).fetchone()["id"]
        self.assertIn(fileorg.NEEDS_REVIEW_TAG, fileorg.get_tags(self.conn, fid))
        row = self.conn.execute("SELECT description FROM files WHERE id=?",
                              (fid,)).fetchone()
        self.assertEqual(row["description"], "protected-path: LEG-Case")

    def test_protected_path_reason_surfaced_on_unsorted_name_collision(self):
        # COMPOUND CASE: the protected-path guard reroutes to SYS-Unsorted,
        # but that exact name is ALREADY occupied there. Per the shipped
        # abort contract (SKILL.md red flags: "a second collision at the
        # SYS-Unsorted/ staging path aborts the move entirely (nothing is
        # recorded)"), place_file raises and records NOTHING -- so a DB note
        # is impossible here (add_note needs an indexed row, and the file
        # never moved). The audit trail must therefore ride on the surfaced
        # error: it names the protected path that was refused, so the legal
        # guardrail is never a silent generic "overwrite refused".
        self._write_cfg({
            "protected": ["LEG-Case"],
            "LEG": {"name": "Case", "keywords": ["case"], "extensions": []},
        })
        codes = fileorg.load_codes()
        (self.root / "LEG-Case").mkdir()
        staged = self.write("SYS-Unsorted/case_summary_draft.pdf",
                            "already-staged")
        p = self.write("case_summary_draft.pdf", "incoming")
        with self.assertRaises(FileExistsError) as cm:
            fileorg.place_file(self.conn, p, codes)
        msg = str(cm.exception)
        # The legal reason must be in the surfaced error, not swallowed.
        self.assertIn("protected", msg.lower())
        self.assertIn("LEG-Case", msg)
        # Nothing entered the protected tree.
        self.assertFalse(
            (self.root / "LEG-Case" / "case_summary_draft.pdf").exists())
        # Both files preserved, neither clobbered.
        self.assertEqual(staged.read_bytes(), b"already-staged")
        self.assertTrue(p.exists())
        self.assertEqual(p.read_bytes(), b"incoming")
        # Nothing recorded in the index (the abort contract).
        n = self.conn.execute("SELECT COUNT(*) FROM files").fetchone()[0]
        self.assertEqual(n, 0)

    def test_sibling_top_level_folder_is_not_protected(self):
        # Segment-boundary match: 'LEG-CaseArchive' is a DISTINCT
        # top-level folder, not inside 'LEG-Case' -- a naive string
        # prefix (e.g. str(dest).startswith(protected_str)) would wrongly
        # match here, since "LEG-CaseArchive" starts with the literal
        # characters "LEG-Case" (spec section 6 / ADR 0018).
        self._write_cfg({
            "protected": ["LEG-Case"],
            "LEG": {"name": "Case", "keywords": ["case"], "extensions": []},
        })
        codes = fileorg.load_codes()
        (self.root / "LEG-CaseArchive").mkdir()
        p = self.write("case_summary_draft.pdf", "a")
        res = fileorg.place_file(self.conn, p, codes)
        dest = self.root / "LEG-CaseArchive" / "case_summary_draft.pdf"
        self.assertEqual(res["action"], "place")
        self.assertTrue(dest.exists())

    def test_dry_run_plain_protected_hit_surfaces_protected_path(self):
        # Dry-run of a plain protected-path hit (no SYS-Unsorted collision):
        # the returned plan must still surface the protected path, not just
        # action="refuse-protected" with no trace of *why*.
        self._write_cfg({
            "protected": ["LEG-Case"],
            "LEG": {"name": "Case", "keywords": ["case"], "extensions": []},
        })
        codes = fileorg.load_codes()
        (self.root / "LEG-Case").mkdir()
        p = self.write("case_summary_draft.pdf", "a")
        plan = fileorg.place_file(self.conn, p, codes, dry_run=True)
        self.assertEqual(plan["action"], "refuse-protected")
        self.assertEqual(plan.get("protected_hit"), "LEG-Case")
        self.assertFalse(plan["moved"])
        # dry-run touches nothing.
        self.assertTrue(p.exists())
        staged = self.root / fileorg.SYS_UNSORTED / "case_summary_draft.pdf"
        self.assertFalse(staged.exists())

    def test_dry_run_compound_protected_and_unsorted_collision_surfaces_protected_path(self):
        # COMPOUND CASE (dry-run twin of
        # test_protected_path_reason_surfaced_on_unsorted_name_collision):
        # the protected-path guard reroutes to SYS-Unsorted, but that exact
        # name is already occupied there, so the destination-exists check
        # clobbers action to "refuse-exists". dry_run=True never calls
        # shutil.move or raises, so the ONLY audit channel is the returned
        # plan -- it must still name the protected path, branching on the
        # guard-time protected_hit rather than the now-overwritten action.
        self._write_cfg({
            "protected": ["LEG-Case"],
            "LEG": {"name": "Case", "keywords": ["case"], "extensions": []},
        })
        codes = fileorg.load_codes()
        (self.root / "LEG-Case").mkdir()
        staged = self.write("SYS-Unsorted/case_summary_draft.pdf",
                            "already-staged")
        p = self.write("case_summary_draft.pdf", "incoming")
        plan = fileorg.place_file(self.conn, p, codes, dry_run=True)
        self.assertEqual(plan["action"], "refuse-exists")
        self.assertEqual(plan.get("protected_hit"), "LEG-Case")
        self.assertFalse(plan["moved"])
        # dry-run touches nothing.
        self.assertEqual(staged.read_bytes(), b"already-staged")
        self.assertTrue(p.exists())
        self.assertEqual(p.read_bytes(), b"incoming")

    def test_dry_run_plain_refuse_exists_has_no_spurious_protected_hit(self):
        # Regression control: a plain (non-protected) refuse-exists dry-run
        # must NOT gain a protected_hit key -- the fix must not fire for
        # ordinary staging collisions.
        codes = fileorg.load_codes()
        self.write("SYS-Unsorted/mystery.dat", "original-staged")
        p = self.write("mystery.dat", "source-new-different")
        plan = fileorg.place_file(self.conn, p, codes, dry_run=True)
        self.assertEqual(plan["action"], "refuse-exists")
        self.assertNotIn("protected_hit", plan)

    def test_stage2_winner_that_is_protected_does_not_fall_back_to_peer(self):
        # A stage-2 winner folder that happens to be protected is refused
        # outright -- place never tries the next-best peer folder instead
        # (refuse-and-stage, not re-route within the code).
        self._write_cfg({
            "protected": ["FIN-Taxes"],
            "FIN": {"folders": {
                "FIN-Taxes": {"keywords": ["1099", "w2"]},
                "FIN-Banking": {"keywords": ["chase"]},
            }},
        })
        codes = fileorg.load_codes()
        (self.root / "FIN-Taxes").mkdir()
        (self.root / "FIN-Banking").mkdir()
        p = self.write("tax_1099_2024.pdf", "a")
        res = fileorg.place_file(self.conn, p, codes)
        self.assertEqual(res["action"], "refuse-protected")
        staged = self.root / fileorg.SYS_UNSORTED / "tax_1099_2024.pdf"
        self.assertTrue(staged.exists())
        self.assertFalse((self.root / "FIN-Taxes" / "tax_1099_2024.pdf").exists())
        self.assertFalse((self.root / "FIN-Banking" / "tax_1099_2024.pdf").exists())


class TestPlaceFileProtectedSourceInvariant(FileorgTestCase):
    """Invariant-level coverage for the ratified source-side guard (fixes
    D1/D2/D3). Every case here drives the FULL production place_file path
    with a production-shaped 2-segment protected entry ("LEG-Case/Export"),
    then asserts the filesystem invariant directly via self.snapshot(),
    not on an intermediate signal -- this is the class of test that would
    have caught the shipped defects."""

    def setUp(self):
        super().setUp()
        self.cfg_dir = self.db_path.parent
        self.cfg_dir.mkdir(parents=True, exist_ok=True)
        self.conn = fileorg.open_db()

    def tearDown(self):
        self.conn.close()
        super().tearDown()

    def _write_cfg(self, data):
        (self.cfg_dir / "codes.local.json").write_text(json.dumps(data))

    def _protect_export(self):
        self._write_cfg({"protected": ["LEG-Case/Export"]})
        return fileorg.load_codes()

    def test_source_inside_protected_subtree_is_refused_as_noop(self):
        # D1: the guard historically only checked the DESTINATION. A file
        # already living inside a protected subtree, once classified as
        # already-coded, resolves its destination to the subtree's own
        # PARENT -- outside the protected boundary -- so a destination-only
        # guard passes and shutil.move evacuates it. The source-side guard
        # must catch this BEFORE classification, as a pure no-op refusal:
        # nothing moved, nothing staged, nothing recorded.
        codes = self._protect_export()
        p = self.write("LEG-Case/Export/exhibit1.pdf", "a")
        before = self.snapshot(self.root / "LEG-Case")
        res = fileorg.place_file(self.conn, p, codes)
        after = self.snapshot(self.root / "LEG-Case")
        self.assertEqual(before, after)
        self.assertEqual(res["action"], "refuse-protected-source")
        self.assertFalse(res["moved"])
        self.assertEqual(res["protected_hit"], "LEG-Case/Export")
        self.assertEqual(res["dest"], str(p))
        self.assertTrue(p.exists())
        n = self.conn.execute("SELECT COUNT(*) FROM files").fetchone()[0]
        self.assertEqual(n, 0)

    def test_source_in_nested_subdir_of_protected_subtree_is_refused(self):
        codes = self._protect_export()
        p = self.write("LEG-Case/Export/Batch01/exhibit2.pdf", "a")
        before = self.snapshot(self.root / "LEG-Case")
        res = fileorg.place_file(self.conn, p, codes)
        after = self.snapshot(self.root / "LEG-Case")
        self.assertEqual(before, after)
        self.assertEqual(res["action"], "refuse-protected-source")
        self.assertFalse(res["moved"])
        n = self.conn.execute("SELECT COUNT(*) FROM files").fetchone()[0]
        self.assertEqual(n, 0)

    def test_source_inside_protected_subtree_dry_run_is_refused(self):
        codes = self._protect_export()
        p = self.write("LEG-Case/Export/exhibit1.pdf", "a")
        before = self.snapshot(self.root / "LEG-Case")
        plan = fileorg.place_file(self.conn, p, codes, dry_run=True)
        after = self.snapshot(self.root / "LEG-Case")
        self.assertEqual(before, after)
        self.assertEqual(plan["action"], "refuse-protected-source")
        self.assertEqual(plan.get("protected_hit"), "LEG-Case/Export")
        self.assertFalse(plan["moved"])
        self.assertTrue(p.exists())
        n = self.conn.execute("SELECT COUNT(*) FROM files").fetchone()[0]
        self.assertEqual(n, 0)

    def test_symlink_inside_protected_subtree_pointing_outside_is_refused(self):
        # D3: is_protected_path's Path.resolve() FOLLOWS symlinks. A
        # symlink planted inside the protected subtree that points OUTSIDE
        # resolves to an unprotected path -- a resolve-only check misses
        # it. The symlink-safe check must also test the parent-resolved
        # (unfollowed-final-component) form and catch it.
        codes = self._protect_export()
        outside_target = self.write("outside_file.pdf", "outside-content")
        link = self.root / "LEG-Case" / "Export" / "link.pdf"
        link.parent.mkdir(parents=True, exist_ok=True)
        os.symlink(str(outside_target), str(link))
        before = self.snapshot(self.root / "LEG-Case")
        res = fileorg.place_file(self.conn, link, codes)
        after = self.snapshot(self.root / "LEG-Case")
        self.assertEqual(before, after)
        self.assertEqual(res["action"], "refuse-protected-source")
        self.assertFalse(res["moved"])
        self.assertTrue(link.is_symlink())
        self.assertEqual(os.readlink(str(link)), str(outside_target))
        self.assertTrue(outside_target.exists())
        n = self.conn.execute("SELECT COUNT(*) FROM files").fetchone()[0]
        self.assertEqual(n, 0)

    def test_sweep_protects_subtree_while_placing_loose_files(self):
        # A sweep over a mixed set (protected-subtree files + ordinary
        # loose files) must refuse every protected-subtree file as a no-op
        # AND still place the ordinary files correctly -- the guard must
        # not degrade the tool's normal behavior outside the protected
        # tree, and must not stamp needs-review on the protected files.
        codes = self._protect_export()
        (self.root / "FIN-Finance").mkdir()
        protected_file = self.write("LEG-Case/Export/exhibit1.pdf", "a")
        nested_protected = self.write("LEG-Case/Export/Batch01/exhibit2.pdf", "b")
        loose = self.write("invoice_2024.pdf", "c")
        before = self.snapshot(self.root / "LEG-Case")
        results = [
            fileorg.place_file(self.conn, f, codes)
            for f in (protected_file, nested_protected, loose)
        ]
        after = self.snapshot(self.root / "LEG-Case")
        self.assertEqual(before, after)
        self.assertEqual(results[0]["action"], "refuse-protected-source")
        self.assertEqual(results[1]["action"], "refuse-protected-source")
        self.assertEqual(results[2]["action"], "place")
        self.assertTrue((self.root / "FIN-Finance" / "invoice_2024.pdf").exists())
        # No needs-review tag anywhere -- a sweep must not invert the tag's
        # meaning by stamping every protected exhibit for review.
        rows = self.conn.execute("SELECT id FROM files").fetchall()
        for row in rows:
            self.assertNotIn(fileorg.NEEDS_REVIEW_TAG,
                              fileorg.get_tags(self.conn, row["id"]))


class TestProtectedHitSymlinkedAncestor(FileorgTestCase):
    """CRITICAL 1 (adversarial-verifier-confirmed hole): protected_hit's
    original two forms -- the fully-resolved path, and the parent-resolved
    (final component literal) path -- BOTH call Path.resolve() on every
    directory component of the path's parent. If the protected directory
    itself, or any subdirectory inside it, is itself a symlink, both forms
    follow that symlink and the resulting path lands outside the protected
    subtree, so is_protected_path returns None for both and the guard is
    evaded. A third, purely lexical form (os.path.abspath -- no resolve()
    of any kind) is required: it never follows any symlink in any
    component, so a symlinked ANCESTOR cannot make the literal path
    (relative to root) fall outside the protected entry."""

    def test_symlinked_protected_directory_itself_is_refused(self):
        # The protected directory ("LEG-Case/Export") is ITSELF a symlink
        # to a real directory elsewhere. A file reached through that
        # symlinked path must still be caught as protected.
        real_target = self.tmp / "real_export"
        real_target.mkdir()
        (self.root / "LEG-Case").mkdir()
        link = self.root / "LEG-Case" / "Export"
        os.symlink(str(real_target), str(link))
        victim = link / "exhibit1.pdf"
        victim.write_bytes(b"secret")
        hit = fileorg.protected_hit(victim, ["LEG-Case/Export"], self.root)
        self.assertEqual(hit, "LEG-Case/Export")

    def test_symlinked_subdir_inside_protected_tree_is_refused(self):
        # A subdirectory INSIDE the (non-symlinked) protected tree is
        # itself a symlink to a real directory elsewhere. A file reached
        # through it must still be caught.
        real_target = self.tmp / "real_batch"
        real_target.mkdir()
        export = self.root / "LEG-Case" / "Export"
        export.mkdir(parents=True)
        link = export / "Batch01"
        os.symlink(str(real_target), str(link))
        victim = link / "exhibit2.pdf"
        victim.write_bytes(b"secret")
        hit = fileorg.protected_hit(victim, ["LEG-Case/Export"], self.root)
        self.assertEqual(hit, "LEG-Case/Export")

    def test_end_to_end_symlinked_protected_dir_file_not_moved_out(self):
        # Full production place_file path -- the exact scenario the
        # adversarial verifier executed: with the protected dir itself a
        # symlink to a real dir elsewhere, a file reached through it must
        # NOT be moved out of the (nominally) protected tree.
        cfg_dir = self.db_path.parent
        cfg_dir.mkdir(parents=True, exist_ok=True)
        (cfg_dir / "codes.local.json").write_text(
            json.dumps({"protected": ["LEG-Case/Export"]}))
        codes = fileorg.load_codes()
        conn = fileorg.open_db()
        try:
            real_target = self.tmp / "real_export"
            real_target.mkdir()
            (self.root / "LEG-Case").mkdir()
            link = self.root / "LEG-Case" / "Export"
            os.symlink(str(real_target), str(link))
            real_file = real_target / "exhibit1.pdf"
            real_file.write_bytes(b"secret")
            via_link = link / "exhibit1.pdf"
            res = fileorg.place_file(conn, via_link, codes)
            self.assertEqual(res["action"], "refuse-protected-source")
            self.assertFalse(res["moved"])
            self.assertTrue(real_file.exists())
            n = conn.execute("SELECT COUNT(*) FROM files").fetchone()[0]
            self.assertEqual(n, 0)
        finally:
            conn.close()

    def test_near_miss_export_notes_is_still_unprotected(self):
        # Regression control: the lexical third form must not turn
        # segment-boundary matching into a sloppy string prefix match.
        # 'ExportNotes' is a sibling of 'Export', not inside it.
        (self.root / "LEG-Case" / "ExportNotes").mkdir(parents=True)
        target = self.root / "LEG-Case" / "ExportNotes" / "note.pdf"
        self.assertIsNone(
            fileorg.protected_hit(target, ["LEG-Case/Export"], self.root))

    def test_near_miss_leg_case_archive_is_still_unprotected(self):
        # Regression control: 'LEG-CaseArchive' is a distinct top-level
        # folder, not inside 'LEG-Case'.
        (self.root / "LEG-CaseArchive" / "Export").mkdir(parents=True)
        target = self.root / "LEG-CaseArchive" / "Export" / "file.pdf"
        self.assertIsNone(
            fileorg.protected_hit(target, ["LEG-Case/Export"], self.root))

    def test_near_miss_sibling_of_protected_file_is_still_unprotected(self):
        # Regression control: a FILE-level protected entry does not protect
        # its sibling file in the same directory -- 'exhibit2.pdf' is next
        # to the protected 'exhibit1.pdf', not inside/equal to it.
        export = self.root / "LEG-Case" / "Export"
        export.mkdir(parents=True)
        sibling = export / "exhibit2.pdf"
        sibling.write_bytes(b"not protected")
        self.assertIsNone(
            fileorg.protected_hit(
                sibling, ["LEG-Case/Export/exhibit1.pdf"], self.root))

    def test_near_misses_and_loose_files_are_never_refused_as_protected(self):
        # No-over-protection, end to end: with the symlink-hole fix active,
        # near-miss siblings and an ordinary loose file must never be
        # refused on protected-path grounds -- legitimate work must not be
        # collaterally blocked by the fix.
        cfg_dir = self.db_path.parent
        cfg_dir.mkdir(parents=True, exist_ok=True)
        (cfg_dir / "codes.local.json").write_text(
            json.dumps({"protected": ["LEG-Case/Export"]}))
        codes = fileorg.load_codes()
        conn = fileorg.open_db()
        try:
            (self.root / "LEG-Case" / "ExportNotes").mkdir(parents=True)
            (self.root / "LEG-CaseArchive").mkdir()
            note = self.write("LEG-Case/ExportNotes/note.pdf", "a")
            archived = self.write("LEG-CaseArchive/old_case.pdf", "b")
            loose = self.write("invoice_2024.pdf", "c")
            for f in (note, archived, loose):
                res = fileorg.place_file(conn, f, codes)
                self.assertNotIn(
                    res["action"],
                    ("refuse-protected", "refuse-protected-source"))
        finally:
            conn.close()


class TestCLI(FileorgTestCase):
    def _run(self, args):
        buf = io.StringIO()
        with redirect_stdout(buf):
            rc = fileorg.main(args)
        return rc, buf.getvalue()

    def test_scan_reports_stats(self):
        self.write("FIN-Finance/statement.pdf", "a")
        rc, out = self._run(["scan"])
        self.assertEqual(rc, 0)
        self.assertIn("1 file", out)

    def test_scan_aggregates_uncoded_subfolders(self):
        self.write("WRK-Work/2024/a.pdf", "a")
        self.write("WRK-Work/2024/b.pdf", "b")
        rc, out = self._run(["scan"])
        self.assertEqual(rc, 0)
        self.assertIn("WRK-Work", out)
        self.assertIn("uncoded", out)

    def test_scan_reports_unknown_code_drift(self):
        # ZZZ is not in the shipped code list -- classify_drift buckets it
        # under unknown_code, and scan's printed output must surface that
        # bucket like it does junk/misplaced_tooling/etc (final review fix).
        self.write("ZZZ-Whatever/x.pdf", "a")
        rc, out = self._run(["scan"])
        self.assertEqual(rc, 0)
        self.assertIn("unknown_code", out)

    def test_place_dry_run_moves_nothing(self):
        (self.root / "FIN-Finance").mkdir()
        p = self.write("invoice_2024.pdf", "a")
        rc, out = self._run(["place", str(p), "--dry-run"])
        self.assertEqual(rc, 0)
        self.assertIn("FIN", out)
        self.assertTrue(p.exists())

    def test_place_moves_file(self):
        (self.root / "FIN-Finance").mkdir()
        p = self.write("invoice_2024.pdf", "a")
        rc, out = self._run(["place", str(p)])
        self.assertEqual(rc, 0)
        self.assertTrue((self.root / "FIN-Finance" / "invoice_2024.pdf").exists())

    def test_place_cli_refuses_protected_destination(self):
        cfg_dir = self.db_path.parent
        cfg_dir.mkdir(parents=True, exist_ok=True)
        (cfg_dir / "codes.local.json").write_text(
            json.dumps({
                "protected": ["LEG-Case"],
                "LEG": {"name": "Case", "keywords": ["case"], "extensions": []},
            })
        )
        (self.root / "LEG-Case").mkdir()
        p = self.write("case_summary_draft.pdf", "a")
        rc, out = self._run(["place", str(p)])
        self.assertEqual(rc, 0)
        self.assertTrue(
            (self.root / fileorg.SYS_UNSORTED / "case_summary_draft.pdf").exists()
        )
        self.assertFalse((self.root / "LEG-Case" / "case_summary_draft.pdf").exists())

    def test_place_dry_run_cli_prints_protected_path_on_compound_collision(self):
        # CLI-level twin of the compound protected+refuse-exists dry-run
        # case: the printed preview line must contain the protected path,
        # not just a generic "refuse-exists" outcome (reviewer finding --
        # no test previously covered the printed output).
        cfg_dir = self.db_path.parent
        cfg_dir.mkdir(parents=True, exist_ok=True)
        (cfg_dir / "codes.local.json").write_text(
            json.dumps({
                "protected": ["LEG-Case"],
                "LEG": {"name": "Case", "keywords": ["case"], "extensions": []},
            })
        )
        (self.root / "LEG-Case").mkdir()
        self.write("SYS-Unsorted/case_summary_draft.pdf", "already-staged")
        p = self.write("case_summary_draft.pdf", "incoming")
        rc, out = self._run(["place", str(p), "--dry-run"])
        self.assertEqual(rc, 0)
        self.assertIn("LEG-Case", out)
        # Nothing touched.
        self.assertTrue(p.exists())
        self.assertFalse(
            (self.root / "LEG-Case" / "case_summary_draft.pdf").exists())

    def test_place_no_protected_config_proceeds_and_warns(self):
        # An inert guard (no codes.local.json, or no "protected" key) must
        # still let a generic user with no legal export place files
        # normally -- but the CLI must print a loud stderr warning so a
        # clean dry-run and an inert-guard dry-run are never
        # indistinguishable (ADR 0018).
        (self.root / "FIN-Finance").mkdir()
        p = self.write("invoice_2024.pdf", "a")
        out_buf, err_buf = io.StringIO(), io.StringIO()
        with redirect_stdout(out_buf), redirect_stderr(err_buf):
            rc = fileorg.main(["place", str(p)])
        self.assertEqual(rc, 0)
        self.assertTrue((self.root / "FIN-Finance" / "invoice_2024.pdf").exists())
        err = err_buf.getvalue()
        self.assertIn("no protected paths configured", err)
        self.assertIn("ADR 0018", err)

    def test_protected_staging_destination_raises_clean_error_not_traceback(self):
        # IMPORTANT 2: a pathological-but-valid config lists the STAGING
        # root itself (SYS-Unsorted) as protected. place_file's own
        # destination guard only runs for action == "place", so a
        # low-confidence file routed to SYS-Unsorted/ is never checked
        # there -- guarded_move's internal check is the sole guard (fires
        # ProtectedPathError, IMPORTANT 3). main() must catch it and print
        # a clean `error:` line, not a raw Python traceback -- and
        # (MINOR 5) must not have created SYS-Unsorted/ on disk first.
        cfg_dir = self.db_path.parent
        cfg_dir.mkdir(parents=True, exist_ok=True)
        (cfg_dir / "codes.local.json").write_text(
            json.dumps({"protected": [fileorg.SYS_UNSORTED]}))
        p = self.write("xyzzy98765.dat", "a")  # low-confidence -> stages
        out_buf, err_buf = io.StringIO(), io.StringIO()
        with redirect_stdout(out_buf), redirect_stderr(err_buf):
            rc = fileorg.main(["place", str(p)])
        self.assertEqual(rc, 2)
        err = err_buf.getvalue()
        self.assertIn("error:", err)
        self.assertIn(fileorg.SYS_UNSORTED, err)
        self.assertIn("protected", err.lower())
        self.assertNotIn("Traceback", err)
        self.assertNotIn("Traceback", out_buf.getvalue())
        # Nothing moved, nothing recorded.
        self.assertTrue(p.exists())
        conn = fileorg.open_db()
        n = conn.execute("SELECT COUNT(*) FROM files").fetchone()[0]
        conn.close()
        self.assertEqual(n, 0)
        # MINOR 5: the protected staging directory must not have been
        # created on disk before the refusal fired.
        self.assertFalse((self.root / fileorg.SYS_UNSORTED).exists())

    def test_query_prints_hits(self):
        self.write("FIN-Finance/pension_summary.pdf", "a")
        self._run(["scan"])
        rc, out = self._run(["query", "pension"])
        self.assertEqual(rc, 0)
        self.assertIn("pension_summary.pdf", out)

    def test_note_and_tag_via_cli(self):
        p = self.write("FIN-Finance/statement.pdf", "a")
        self._run(["scan"])
        rc1, _ = self._run(["note", str(p), "pension summary"])
        rc2, _ = self._run(["tag", str(p), "important", "2024"])
        self.assertEqual((rc1, rc2), (0, 0))
        conn = fileorg.open_db()
        row = conn.execute("SELECT description FROM files WHERE path=?",
                         (str(p),)).fetchone()
        self.assertEqual(row["description"], "pension summary")
        conn.close()

    def test_note_unindexed_path_returns_2(self):
        rc, _ = self._run(["note", str(self.root / "nope.pdf"), "x"])
        self.assertEqual(rc, 2)

    def test_scan_nonexistent_path_returns_nonzero(self):
        nonexistent = self.root / "nonexistent-subdir"
        rc, _ = self._run(["scan", str(nonexistent)])
        self.assertEqual(rc, 2)

    def test_place_nonexistent_file_returns_nonzero(self):
        nonexistent = self.root / "nonexistent.pdf"
        rc, _ = self._run(["place", str(nonexistent)])
        self.assertEqual(rc, 2)

    def test_tag_unindexed_path_returns_nonzero(self):
        # Create and scan a real file to have a non-empty index,
        # then try to tag a path that was never indexed.
        self.write("FIN-Finance/statement.pdf", "a")
        self._run(["scan"])
        unindexed = self.root / "unindexed.pdf"
        rc, _ = self._run(["tag", str(unindexed), "test"])
        self.assertEqual(rc, 2)


def _local_personal_folder_names():
    """Personal top-level folder names configured in the REAL, untracked
    codes.local.json on this machine (never in a test fixture -- reads
    fileorg.get_db_path() unmodified, so it targets the actual local
    config, not a tempfile). None of the shipped codes.default.json
    entries define a "folders" sub-map (verified: grep codes.default.json
    for '"folders"' returns nothing), so any folder name appearing under
    any code's "folders" map in the local override is, by construction, a
    personal customization -- exactly the class of string that must never
    leak into a tracked doc. Returns [] if no local config exists (a
    fresh checkout, CI, or a machine that hasn't configured personal
    folders yet) -- test_no_personal_identifiers treats that as "nothing
    to check", not a failure to hide behind."""
    try:
        override_path = fileorg.get_db_path().parent / "codes.local.json"
        if not override_path.exists():
            return []
        with open(str(override_path), "r", encoding="utf-8") as fh:
            data = json.load(fh)
    except (OSError, ValueError):
        return []
    names = []
    for code, entry in data.items():
        if code == "protected" or not isinstance(entry, dict):
            continue
        for folder_name in (entry.get("folders") or {}):
            names.append(folder_name)
    return names


class TestSweepPaths(FileorgTestCase):
    def test_lock_path_derives_from_db_dir(self):
        # FILEORG_DB_PATH is set in setUp to self.db_path (tmp/data/index.db),
        # so the lock lives beside it at tmp/data/sweep.lock.
        self.assertEqual(
            fileorg.get_sweep_lock_path(), self.db_path.parent / "sweep.lock"
        )

    def test_log_path_derives_from_db_dir(self):
        self.assertEqual(
            fileorg.get_sweep_log_path(),
            self.db_path.parent / "logs" / "sweep.log",
        )

    def test_lock_path_xdg_default(self):
        del os.environ["FILEORG_DB_PATH"]
        os.environ["XDG_DATA_HOME"] = str(self.tmp / "xdg")
        self.assertEqual(
            fileorg.get_sweep_lock_path(),
            self.tmp / "xdg" / "file-organizer" / "sweep.lock",
        )

    def test_log_path_xdg_default(self):
        del os.environ["FILEORG_DB_PATH"]
        os.environ["XDG_DATA_HOME"] = str(self.tmp / "xdg")
        self.assertEqual(
            fileorg.get_sweep_log_path(),
            self.tmp / "xdg" / "file-organizer" / "logs" / "sweep.log",
        )


class TestSweepLock(FileorgTestCase):
    def _lock(self):
        return self.tmp / "data" / "sweep.lock"

    def _spawn_live_pid(self):
        """A definitely-alive PID that is NOT this process: a child that
        sleeps. Caller must terminate it (returned handle)."""
        import subprocess
        import sys as _sys
        proc = subprocess.Popen([_sys.executable, "-c",
                                 "import time; time.sleep(30)"])
        return proc

    def _dead_pid(self):
        """A definitely-dead PID: spawn a child that exits immediately, reap
        it, and return its now-unused PID."""
        import subprocess
        import sys as _sys
        proc = subprocess.Popen([_sys.executable, "-c", "pass"])
        proc.wait()
        return proc.pid

    def test_read_lock_pid_absent_returns_none(self):
        self.assertIsNone(fileorg.read_lock_pid(self._lock()))

    def test_read_lock_pid_unparseable_returns_none(self):
        lock = self._lock()
        lock.parent.mkdir(parents=True, exist_ok=True)
        lock.write_text("not-a-number", encoding="utf-8")
        self.assertIsNone(fileorg.read_lock_pid(lock))

    def test_read_lock_pid_reads_int(self):
        lock = self._lock()
        lock.parent.mkdir(parents=True, exist_ok=True)
        lock.write_text("4242\n", encoding="utf-8")
        self.assertEqual(fileorg.read_lock_pid(lock), 4242)

    def test_pid_is_running_true_for_current_process(self):
        self.assertTrue(fileorg.pid_is_running(os.getpid()))

    def test_pid_is_running_false_for_dead_pid(self):
        self.assertFalse(fileorg.pid_is_running(self._dead_pid()))

    def test_acquire_when_absent_writes_our_pid(self):
        lock = self._lock()
        acquired, reclaimed = fileorg.acquire_sweep_lock(lock)
        self.assertTrue(acquired)
        self.assertFalse(reclaimed)
        self.assertEqual(fileorg.read_lock_pid(lock), os.getpid())

    def test_acquire_when_held_by_live_process_returns_not_acquired(self):
        lock = self._lock()
        lock.parent.mkdir(parents=True, exist_ok=True)
        proc = self._spawn_live_pid()
        try:
            lock.write_text(str(proc.pid), encoding="utf-8")
            acquired, reclaimed = fileorg.acquire_sweep_lock(lock)
            self.assertFalse(acquired)
            self.assertFalse(reclaimed)
            # The foreign live PID is left in the lock, untouched.
            self.assertEqual(fileorg.read_lock_pid(lock), proc.pid)
        finally:
            proc.terminate()
            proc.wait()

    def test_acquire_reclaims_stale_lock(self):
        lock = self._lock()
        lock.parent.mkdir(parents=True, exist_ok=True)
        lock.write_text(str(self._dead_pid()), encoding="utf-8")
        acquired, reclaimed = fileorg.acquire_sweep_lock(lock)
        self.assertTrue(acquired)
        self.assertTrue(reclaimed)
        self.assertEqual(fileorg.read_lock_pid(lock), os.getpid())

    def test_release_removes_our_lock(self):
        lock = self._lock()
        fileorg.acquire_sweep_lock(lock)
        fileorg.release_sweep_lock(lock)
        self.assertFalse(lock.exists())

    def test_release_leaves_foreign_lock(self):
        lock = self._lock()
        lock.parent.mkdir(parents=True, exist_ok=True)
        lock.write_text("999999", encoding="utf-8")  # not our PID
        fileorg.release_sweep_lock(lock)
        self.assertTrue(lock.exists())
        self.assertEqual(fileorg.read_lock_pid(lock), 999999)


class TestSweepEnumeration(FileorgTestCase):
    def setUp(self):
        super().setUp()
        self.dl = self.tmp / "Downloads"
        self.dl.mkdir()

    def _touch(self, name):
        p = self.dl / name
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_bytes(b"x")
        return p

    def _names(self):
        return sorted(p.name for p in fileorg.iter_sweep_files(self.dl))

    def test_yields_only_top_level_files(self):
        self._touch("a.pdf")
        self._touch("b.pdf")
        self.assertEqual(self._names(), ["a.pdf", "b.pdf"])

    def test_skips_subdirectories(self):
        # A subdir and a file inside it must NOT be yielded (no recursion).
        self._touch("top.pdf")
        (self.dl / "sub").mkdir()
        (self.dl / "sub" / "nested.pdf").write_bytes(b"y")
        self.assertEqual(self._names(), ["top.pdf"])

    def test_skips_in_progress_extensions(self):
        self._touch("done.pdf")
        self._touch("a.crdownload")
        self._touch("b.download")
        self._touch("c.part")
        self._touch("d.tmp")
        self.assertEqual(self._names(), ["done.pdf"])

    def test_in_progress_skip_is_case_insensitive(self):
        self._touch("keep.pdf")
        self._touch("LOUD.CRDOWNLOAD")
        self.assertEqual(self._names(), ["keep.pdf"])

    def test_empty_dir_yields_nothing(self):
        self.assertEqual(self._names(), [])


class TestSweepCore(FileorgTestCase):
    def setUp(self):
        super().setUp()
        self.codes = fileorg.load_codes()
        self.conn = fileorg.open_db()
        self.dl = self.tmp / "Downloads"
        self.dl.mkdir()

    def tearDown(self):
        self.conn.close()
        super().tearDown()

    def _dl(self, name, content=b"x"):
        p = self.dl / name
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_bytes(content)
        return p

    def test_matching_file_is_filed_into_documents(self):
        # A FIN-Finance folder exists under the Documents root; an invoice in
        # Downloads is filed into it (reusing place_file unchanged).
        (self.root / "FIN-Finance").mkdir()
        self._dl("invoice_2024.pdf")
        stats = fileorg.sweep(self.conn, self.dl, self.codes, root=self.root)
        self.assertEqual(stats["filed"], 1)
        self.assertEqual(stats["staged"], 0)
        self.assertTrue((self.root / "FIN-Finance" / "invoice_2024.pdf").exists())

    def test_low_confidence_file_is_staged(self):
        self._dl("xyzzy98765.dat")
        stats = fileorg.sweep(self.conn, self.dl, self.codes, root=self.root)
        self.assertEqual(stats["filed"], 0)
        self.assertEqual(stats["staged"], 1)
        self.assertTrue(
            (self.root / fileorg.SYS_UNSORTED / "xyzzy98765.dat").exists())

    def test_subdirectory_files_are_untouched(self):
        (self.dl / "sub").mkdir()
        nested = self.dl / "sub" / "invoice_2024.pdf"
        nested.write_bytes(b"x")
        (self.root / "FIN-Finance").mkdir()
        stats = fileorg.sweep(self.conn, self.dl, self.codes, root=self.root)
        self.assertEqual(stats["scanned"], 0)  # nothing at top level
        self.assertTrue(nested.exists())  # left where it was

    def test_stats_count_scanned_filed_staged(self):
        (self.root / "FIN-Finance").mkdir()
        self._dl("invoice_2024.pdf")   # filed
        self._dl("xyzzy98765.dat")     # staged (low confidence)
        stats = fileorg.sweep(self.conn, self.dl, self.codes, root=self.root)
        self.assertEqual(stats["scanned"], 2)
        self.assertEqual(stats["filed"], 1)
        self.assertEqual(stats["staged"], 1)
        self.assertEqual(stats["errored"], 0)

    def test_per_file_error_isolation(self):
        # One file's place_file raises; the loop must continue and still file
        # the others. Patch place_file to blow up only on "boom.pdf".
        (self.root / "FIN-Finance").mkdir()
        self._dl("invoice_2024.pdf")
        self._dl("boom.pdf")
        real_place = fileorg.place_file

        def flaky(conn, path, codes, **kw):
            if fileorg.Path(path).name == "boom.pdf":
                raise OSError("permission denied")
            return real_place(conn, path, codes, **kw)

        with mock.patch.object(fileorg, "place_file", side_effect=flaky):
            stats = fileorg.sweep(self.conn, self.dl, self.codes, root=self.root)
        self.assertEqual(stats["scanned"], 2)
        self.assertEqual(stats["errored"], 1)
        self.assertEqual(stats["filed"], 1)  # the good file still filed
        self.assertEqual(len(stats["errors"]), 1)
        self.assertEqual(stats["errors"][0][0], "boom.pdf")
        self.assertIn("permission denied", stats["errors"][0][1])
        self.assertTrue(
            (self.root / "FIN-Finance" / "invoice_2024.pdf").exists())

    def test_dry_run_counts_but_moves_nothing(self):
        (self.root / "FIN-Finance").mkdir()
        src = self._dl("invoice_2024.pdf")
        stats = fileorg.sweep(self.conn, self.dl, self.codes,
                              root=self.root, dry_run=True)
        self.assertEqual(stats["scanned"], 1)
        self.assertEqual(stats["filed"], 1)  # would-file
        self.assertTrue(src.exists())  # nothing moved
        self.assertFalse((self.root / "FIN-Finance" / "invoice_2024.pdf").exists())


class TestSweepLog(FileorgTestCase):
    def _log(self):
        return self.tmp / "data" / "logs" / "sweep.log"

    def _stats(self, scanned=5, filed=3, staged=2, errored=0):
        return {"scanned": scanned, "filed": filed, "staged": staged,
                "errored": errored, "errors": []}

    def test_append_creates_file_and_writes_line(self):
        log = self._log()
        fileorg._append_sweep_log(log, "hello world")
        self.assertTrue(log.exists())
        self.assertIn("hello world", log.read_text(encoding="utf-8"))

    def test_append_is_append_mode(self):
        log = self._log()
        fileorg._append_sweep_log(log, "line one")
        fileorg._append_sweep_log(log, "line two")
        body = log.read_text(encoding="utf-8")
        self.assertIn("line one", body)
        self.assertIn("line two", body)
        self.assertEqual(body.count("\n"), 2)

    def test_summary_contains_counts(self):
        log = self._log()
        fileorg.write_sweep_summary(log, self._stats())
        body = log.read_text(encoding="utf-8")
        self.assertIn("scanned=5", body)
        self.assertIn("filed=3", body)
        self.assertIn("staged=2", body)
        self.assertIn("errored=0", body)

    def test_summary_dry_run_marker(self):
        log = self._log()
        fileorg.write_sweep_summary(log, self._stats(), dry_run=True)
        self.assertIn("(dry-run)", log.read_text(encoding="utf-8"))

    def test_summary_has_timestamp(self):
        log = self._log()
        fileorg.write_sweep_summary(log, self._stats())
        # ISO-ish timestamp: starts with a 4-digit year and a 'T' separator.
        first = log.read_text(encoding="utf-8").splitlines()[0]
        self.assertRegex(first, r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2} ")


class TestRunSweep(FileorgTestCase):
    def setUp(self):
        super().setUp()
        self.conn = fileorg.open_db()
        self.dl = self.tmp / "Downloads"
        self.dl.mkdir()
        self.lock = self.db_path.parent / "sweep.lock"
        self.log = self.db_path.parent / "logs" / "sweep.log"

    def tearDown(self):
        self.conn.close()
        super().tearDown()

    def _dl(self, name):
        p = self.dl / name
        p.write_bytes(b"x")
        return p

    def _spawn_live(self):
        import subprocess
        import sys as _sys
        return subprocess.Popen([_sys.executable, "-c",
                                 "import time; time.sleep(30)"])

    def _dead_pid(self):
        import subprocess
        import sys as _sys
        proc = subprocess.Popen([_sys.executable, "-c", "pass"])
        proc.wait()
        return proc.pid

    def test_runs_sweep_and_writes_summary_log(self):
        (self.root / "FIN-Finance").mkdir()
        self._dl("invoice_2024.pdf")
        stats = fileorg.run_sweep(self.conn, self.dl)
        self.assertFalse(stats["skipped"])
        self.assertEqual(stats["filed"], 1)
        self.assertIn("scanned=1", self.log.read_text(encoding="utf-8"))

    def test_releases_lock_after_run(self):
        self._dl("xyzzy98765.dat")
        fileorg.run_sweep(self.conn, self.dl)
        self.assertFalse(self.lock.exists())

    def test_skips_when_lock_held_by_live_process(self):
        proc = self._spawn_live()
        try:
            self.lock.parent.mkdir(parents=True, exist_ok=True)
            self.lock.write_text(str(proc.pid), encoding="utf-8")
            self._dl("invoice_2024.pdf")
            (self.root / "FIN-Finance").mkdir()
            stats = fileorg.run_sweep(self.conn, self.dl)
            self.assertTrue(stats["skipped"])
            self.assertIn("already running, skipping",
                          self.log.read_text(encoding="utf-8"))
            # Nothing was filed -- the sweep was skipped.
            self.assertFalse(
                (self.root / "FIN-Finance" / "invoice_2024.pdf").exists())
            # The foreign lock is left intact (we did not own it).
            self.assertEqual(fileorg.read_lock_pid(self.lock), proc.pid)
        finally:
            proc.terminate()
            proc.wait()

    def test_reclaims_stale_lock_and_logs(self):
        self.lock.parent.mkdir(parents=True, exist_ok=True)
        self.lock.write_text(str(self._dead_pid()), encoding="utf-8")
        (self.root / "FIN-Finance").mkdir()
        self._dl("invoice_2024.pdf")
        stats = fileorg.run_sweep(self.conn, self.dl)
        self.assertTrue(stats["reclaimed"])
        self.assertFalse(stats["skipped"])
        self.assertEqual(stats["filed"], 1)
        body = self.log.read_text(encoding="utf-8")
        self.assertIn("reclaimed stale lock", body)
        self.assertIn("scanned=1", body)

    def test_lock_released_even_on_enumeration_error(self):
        # A nonexistent sweep dir makes iter_sweep_files' iterdir raise; the
        # lock must still be released (finally), and the error propagates so
        # main() can map it to exit 2.
        missing = self.tmp / "no-such-dir"
        with self.assertRaises(OSError):
            fileorg.run_sweep(self.conn, missing)
        self.assertFalse(self.lock.exists())


class TestSweepCLI(FileorgTestCase):
    def setUp(self):
        super().setUp()
        self.dl = self.tmp / "Downloads"
        self.dl.mkdir()

    def _run(self, args):
        out_buf, err_buf = io.StringIO(), io.StringIO()
        with redirect_stdout(out_buf), redirect_stderr(err_buf):
            rc = fileorg.main(args)
        return rc, out_buf.getvalue(), err_buf.getvalue()

    def _dl(self, name):
        p = self.dl / name
        p.write_bytes(b"x")
        return p

    def _protect_cfg(self, data):
        cfg = self.db_path.parent
        cfg.mkdir(parents=True, exist_ok=True)
        (cfg / "codes.local.json").write_text(json.dumps(data))

    def test_sweep_subcommand_parses(self):
        parser = fileorg.build_parser()
        ns = parser.parse_args(["sweep", str(self.dl), "--dry-run"])
        self.assertEqual(ns.cmd, "sweep")
        self.assertEqual(ns.dir, str(self.dl))
        self.assertTrue(ns.dry_run)

    def test_cmd_sweep_files_and_prints_summary(self):
        self._protect_cfg({"protected": ["LEG-Case"]})  # silence the warning
        (self.root / "FIN-Finance").mkdir()
        self._dl("invoice_2024.pdf")
        rc, out, _ = self._run(["sweep", str(self.dl)])
        self.assertEqual(rc, 0)
        self.assertIn("scanned=1", out)
        self.assertIn("filed=1", out)
        self.assertTrue((self.root / "FIN-Finance" / "invoice_2024.pdf").exists())

    def test_cmd_sweep_dry_run_moves_nothing(self):
        self._protect_cfg({"protected": ["LEG-Case"]})
        (self.root / "FIN-Finance").mkdir()
        src = self._dl("invoice_2024.pdf")
        rc, out, _ = self._run(["sweep", str(self.dl), "--dry-run"])
        self.assertEqual(rc, 0)
        self.assertIn("would sweep", out)
        self.assertTrue(src.exists())
        self.assertFalse((self.root / "FIN-Finance" / "invoice_2024.pdf").exists())

    def test_cmd_sweep_default_dir_is_downloads(self):
        # No dir arg -> ~/Downloads (resolved via $HOME). Point HOME at the
        # temp tree so the real ~/Downloads is never touched. FILEORG_DB_PATH /
        # FILEORG_DOCUMENTS_ROOT are already set in setUp, so only the
        # Downloads default is affected.
        self._protect_cfg({"protected": ["LEG-Case"]})
        home_dl = self.tmp / "Downloads"  # == self.dl, Path.home()/"Downloads"
        (self.root / "FIN-Finance").mkdir()
        (home_dl / "invoice_2024.pdf").write_bytes(b"x")
        with mock.patch.dict(os.environ, {"HOME": str(self.tmp)}):
            rc, out, _ = self._run(["sweep"])
        self.assertEqual(rc, 0)
        self.assertIn("scanned=1", out)
        self.assertTrue((self.root / "FIN-Finance" / "invoice_2024.pdf").exists())

    def test_cmd_sweep_warns_when_guard_inactive(self):
        # No codes.local.json / no "protected" -> the ADR 0018 stderr warning,
        # same as _cmd_place.
        (self.root / "FIN-Finance").mkdir()
        self._dl("invoice_2024.pdf")
        rc, _, err = self._run(["sweep", str(self.dl)])
        self.assertEqual(rc, 0)
        self.assertIn("no protected paths configured", err)
        self.assertIn("ADR 0018", err)

    def test_cmd_sweep_held_lock_prints_skip(self):
        import subprocess
        import sys as _sys
        self._protect_cfg({"protected": ["LEG-Case"]})
        lock = self.db_path.parent / "sweep.lock"
        lock.parent.mkdir(parents=True, exist_ok=True)
        proc = subprocess.Popen([_sys.executable, "-c",
                                 "import time; time.sleep(30)"])
        try:
            lock.write_text(str(proc.pid), encoding="utf-8")
            self._dl("invoice_2024.pdf")
            rc, out, _ = self._run(["sweep", str(self.dl)])
            self.assertEqual(rc, 0)
            self.assertIn("already running, skipping", out)
        finally:
            proc.terminate()
            proc.wait()

    def test_cmd_sweep_nonexistent_dir_returns_2(self):
        self._protect_cfg({"protected": ["LEG-Case"]})
        missing = self.tmp / "no-such-downloads"
        rc, _, _ = self._run(["sweep", str(missing)])
        self.assertEqual(rc, 2)


class TestApplyClassificationCore(FileorgTestCase):
    def setUp(self):
        super().setUp()
        self.codes = fileorg.load_codes()
        self.conn = fileorg.open_db()

    def tearDown(self):
        self.conn.close()
        super().tearDown()

    def test_valid_folder_moves_file(self):
        # FIN is a shipped default code; a real FIN-Banking folder exists on
        # disk -> apply moves the file into it via guarded_move.
        (self.root / "FIN-Banking").mkdir()
        p = self.write("bank_statement.pdf", "a")
        res = fileorg.apply_classification(
            self.conn, p, "FIN-Banking", self.codes)
        dest = self.root / "FIN-Banking" / "bank_statement.pdf"
        self.assertEqual(res["action"], "apply")
        self.assertTrue(res["moved"])
        self.assertEqual(res["code"], "FIN")
        self.assertTrue(dest.exists())
        self.assertFalse(p.exists())
        row = self.conn.execute("SELECT code FROM files WHERE path=?",
                               (str(dest),)).fetchone()
        self.assertEqual(row["code"], "FIN")

    def test_invalid_folder_name_refused_untouched_no_folder_created(self):
        # A hallucinated folder name that does NOT exist on disk -> refused,
        # file left exactly where it is, and the folder is NEVER created.
        p = self.write("bank_statement.pdf", "a")
        res = fileorg.apply_classification(
            self.conn, p, "FIN-Nonexistent", self.codes)
        self.assertEqual(res["action"], "refuse-invalid-folder")
        self.assertFalse(res["moved"])
        self.assertTrue(p.exists())
        self.assertFalse((self.root / "FIN-Nonexistent").exists())
        n = self.conn.execute("SELECT COUNT(*) FROM files").fetchone()[0]
        self.assertEqual(n, 0)

    def test_unrecognized_code_folder_refused_even_if_dir_exists(self):
        # ZZZ-Whatever EXISTS on disk, but ZZZ is not a code in the loaded
        # config -> not a "recognized folder for some code" -> refused.
        (self.root / "ZZZ-Whatever").mkdir()
        p = self.write("mystery.pdf", "a")
        res = fileorg.apply_classification(
            self.conn, p, "ZZZ-Whatever", self.codes)
        self.assertEqual(res["action"], "refuse-invalid-folder")
        self.assertFalse(res["moved"])
        self.assertTrue(p.exists())
        self.assertFalse((self.root / "ZZZ-Whatever" / "mystery.pdf").exists())

    def test_non_code_folder_name_refused(self):
        # A plain (uncoded) folder name that does not parse as CODE-Name ->
        # refused (parse_folder_code returns None).
        (self.root / "Downloads").mkdir()
        p = self.write("mystery.pdf", "a")
        res = fileorg.apply_classification(
            self.conn, p, "Downloads", self.codes)
        self.assertEqual(res["action"], "refuse-invalid-folder")
        self.assertFalse(res["moved"])
        self.assertTrue(p.exists())

    def test_dry_run_apply_moves_nothing(self):
        (self.root / "FIN-Banking").mkdir()
        p = self.write("bank_statement.pdf", "a")
        plan = fileorg.apply_classification(
            self.conn, p, "FIN-Banking", self.codes, dry_run=True)
        self.assertEqual(plan["action"], "apply")
        self.assertFalse(plan["moved"])
        self.assertTrue(p.exists())  # nothing moved
        self.assertFalse(
            (self.root / "FIN-Banking" / "bank_statement.pdf").exists())
        n = self.conn.execute("SELECT COUNT(*) FROM files").fetchone()[0]
        self.assertEqual(n, 0)

    def test_success_move_routes_through_guarded_move(self):
        # ADR 0018 single-mover invariant: apply must move via guarded_move,
        # never a bare shutil.move -- assert the choke point is the one called.
        (self.root / "FIN-Banking").mkdir()
        p = self.write("bank_statement.pdf", "a")
        real_guarded = fileorg.guarded_move
        calls = []

        def spy(src, dest, protected, root):
            calls.append((str(src), str(dest)))
            return real_guarded(src, dest, protected, root)

        with mock.patch.object(fileorg, "guarded_move", side_effect=spy):
            fileorg.apply_classification(
                self.conn, p, "FIN-Banking", self.codes)
        self.assertEqual(len(calls), 1)
        self.assertTrue(calls[0][1].endswith("FIN-Banking/bank_statement.pdf"))


class TestApplyClassificationRefuseAndStage(FileorgTestCase):
    def setUp(self):
        super().setUp()
        self.cfg_dir = self.db_path.parent
        self.cfg_dir.mkdir(parents=True, exist_ok=True)
        self.conn = fileorg.open_db()

    def tearDown(self):
        self.conn.close()
        super().tearDown()

    def _write_cfg(self, data):
        (self.cfg_dir / "codes.local.json").write_text(json.dumps(data))

    def test_protected_destination_refused_and_staged(self):
        # LEG-Case is a real, recognized (LEG added via cfg) folder that is
        # ALSO protected -> the destination is inside a protected path -> the
        # file is refused and staged to SYS-Unsorted with needs-review + note,
        # and the protected folder is left empty (ADR 0018, spec 12.3 step 2).
        self._write_cfg({
            "protected": ["LEG-Case"],
            "LEG": {"name": "Case", "keywords": ["case"], "extensions": []},
        })
        codes = fileorg.load_codes()
        (self.root / "LEG-Case").mkdir()
        p = self.write("case_notes.pdf", "a")
        res = fileorg.apply_classification(self.conn, p, "LEG-Case", codes)
        staged = self.root / fileorg.SYS_UNSORTED / "case_notes.pdf"
        self.assertEqual(res["action"], "refuse-protected")
        self.assertEqual(res["protected_hit"], "LEG-Case")
        self.assertTrue(staged.exists())
        self.assertFalse((self.root / "LEG-Case" / "case_notes.pdf").exists())
        fid = self.conn.execute("SELECT id FROM files WHERE path=?",
                               (str(staged),)).fetchone()["id"]
        self.assertIn(fileorg.NEEDS_REVIEW_TAG,
                      fileorg.get_tags(self.conn, fid))
        row = self.conn.execute("SELECT description FROM files WHERE id=?",
                               (fid,)).fetchone()
        self.assertEqual(row["description"], "protected-path: LEG-Case")

    def test_protected_never_creates_folder_or_falls_back_to_peer(self):
        # The chosen folder is protected, and a peer folder for the same code
        # exists -> the verb must NOT fall back to the peer; it refuses and
        # stages, touching neither coded folder (spec 12.3 step 2 / 12.5).
        self._write_cfg({
            "protected": ["FIN-Taxes"],
            "FIN": {"folders": {
                "FIN-Taxes": {"keywords": ["1099"]},
                "FIN-Banking": {"keywords": ["chase"]},
            }},
        })
        codes = fileorg.load_codes()
        (self.root / "FIN-Taxes").mkdir()
        (self.root / "FIN-Banking").mkdir()
        p = self.write("tax_1099.pdf", "a")
        res = fileorg.apply_classification(self.conn, p, "FIN-Taxes", codes)
        self.assertEqual(res["action"], "refuse-protected")
        self.assertTrue(
            (self.root / fileorg.SYS_UNSORTED / "tax_1099.pdf").exists())
        self.assertFalse((self.root / "FIN-Taxes" / "tax_1099.pdf").exists())
        self.assertFalse((self.root / "FIN-Banking" / "tax_1099.pdf").exists())

    def test_collision_at_destination_refused_and_staged(self):
        # A file already occupies the real destination -> refuse-exists,
        # staged to SYS-Unsorted with needs-review; the original is untouched
        # (spec 12.3 step 3).
        (self.root / "FIN-Banking").mkdir()
        existing = self.write("FIN-Banking/statement.pdf", "original")
        p = self.write("statement.pdf", "new-different")
        res = fileorg.apply_classification(
            self.conn, p, "FIN-Banking", fileorg.load_codes())
        staged = self.root / fileorg.SYS_UNSORTED / "statement.pdf"
        self.assertEqual(res["action"], "refuse-exists")
        self.assertEqual(existing.read_bytes(), b"original")
        self.assertTrue(staged.exists())
        self.assertEqual(staged.read_bytes(), b"new-different")
        fid = self.conn.execute("SELECT id FROM files WHERE path=?",
                               (str(staged),)).fetchone()["id"]
        self.assertIn(fileorg.NEEDS_REVIEW_TAG,
                      fileorg.get_tags(self.conn, fid))

    def test_already_staged_source_protected_is_noop(self):
        # The source is ALREADY at its SYS-Unsorted/<name> path (the normal
        # Workflow case) and the chosen folder is protected -> refusal is a
        # pure no-op: the file is left exactly where it is, nothing moves
        # (idempotency; no file-moves-onto-itself self-collision).
        self._write_cfg({
            "protected": ["LEG-Case"],
            "LEG": {"name": "Case", "keywords": ["case"], "extensions": []},
        })
        codes = fileorg.load_codes()
        (self.root / "LEG-Case").mkdir()
        staged = self.write("SYS-Unsorted/case_notes.pdf", "a")
        res = fileorg.apply_classification(self.conn, staged, "LEG-Case", codes)
        self.assertEqual(res["action"], "refuse-protected")
        self.assertFalse(res["moved"])
        self.assertEqual(res["dest"], str(staged))
        self.assertTrue(staged.exists())
        self.assertEqual(staged.read_bytes(), b"a")

    def test_double_collision_at_staging_aborts_and_preserves_both(self):
        # Refuse-and-stage wants SYS-Unsorted/<name>, but a DIFFERENT file
        # already occupies it -> abort (FileExistsError), nothing recorded,
        # both files preserved, and the protected reason is named in the error.
        self._write_cfg({
            "protected": ["LEG-Case"],
            "LEG": {"name": "Case", "keywords": ["case"], "extensions": []},
        })
        codes = fileorg.load_codes()
        (self.root / "LEG-Case").mkdir()
        occupied = self.write("SYS-Unsorted/case_notes.pdf", "already-staged")
        p = self.write("case_notes.pdf", "incoming")
        with self.assertRaises(FileExistsError) as cm:
            fileorg.apply_classification(self.conn, p, "LEG-Case", codes)
        msg = str(cm.exception)
        self.assertIn("LEG-Case", msg)
        self.assertIn("protected", msg.lower())
        self.assertEqual(occupied.read_bytes(), b"already-staged")
        self.assertTrue(p.exists())
        self.assertEqual(p.read_bytes(), b"incoming")
        n = self.conn.execute("SELECT COUNT(*) FROM files").fetchone()[0]
        self.assertEqual(n, 0)

    def test_dry_run_protected_surfaces_protected_hit_moves_nothing(self):
        self._write_cfg({
            "protected": ["LEG-Case"],
            "LEG": {"name": "Case", "keywords": ["case"], "extensions": []},
        })
        codes = fileorg.load_codes()
        (self.root / "LEG-Case").mkdir()
        p = self.write("case_notes.pdf", "a")
        plan = fileorg.apply_classification(
            self.conn, p, "LEG-Case", codes, dry_run=True)
        self.assertEqual(plan["action"], "refuse-protected")
        self.assertEqual(plan.get("protected_hit"), "LEG-Case")
        self.assertFalse(plan["moved"])
        self.assertTrue(p.exists())
        self.assertFalse(
            (self.root / fileorg.SYS_UNSORTED / "case_notes.pdf").exists())

    def test_dry_run_compound_protected_and_staging_collision_surfaces_protected_path(self):
        # COMPOUND CASE, dry-run twin of
        # test_double_collision_at_staging_aborts_and_preserves_both (and the
        # apply_classification analogue of place_file's
        # test_dry_run_compound_protected_and_unsorted_collision_surfaces_protected_path):
        # the chosen folder is protected, so refuse-and-stage wants to route
        # to SYS-Unsorted/<name>, but that exact name is ALREADY occupied by
        # a different file. A REAL call would abort with FileExistsError
        # (see the sibling raising test above) -- a dry-run call against the
        # same inputs must surface that impending failure too, not report
        # a clean refuse-protected plan as if staging would succeed. Per
        # place_file's own dry-run discipline, dry_run never raises; the
        # signal instead is `action` being overwritten to "refuse-exists"
        # while `protected_hit` names the original reason.
        self._write_cfg({
            "protected": ["LEG-Case"],
            "LEG": {"name": "Case", "keywords": ["case"], "extensions": []},
        })
        codes = fileorg.load_codes()
        (self.root / "LEG-Case").mkdir()
        occupied = self.write("SYS-Unsorted/case_notes.pdf", "already-staged")
        p = self.write("case_notes.pdf", "incoming")
        plan = fileorg.apply_classification(
            self.conn, p, "LEG-Case", codes, dry_run=True)
        self.assertEqual(plan["action"], "refuse-exists")
        self.assertEqual(plan.get("protected_hit"), "LEG-Case")
        self.assertFalse(plan["moved"])
        # dry-run touches nothing.
        self.assertEqual(occupied.read_bytes(), b"already-staged")
        self.assertTrue(p.exists())
        self.assertEqual(p.read_bytes(), b"incoming")
        n = self.conn.execute("SELECT COUNT(*) FROM files").fetchone()[0]
        self.assertEqual(n, 0)

    def test_refuse_and_stage_move_routes_through_guarded_move(self):
        # ADR 0018: even the refuse-and-stage move is the one mover.
        (self.root / "FIN-Banking").mkdir()
        self.write("FIN-Banking/statement.pdf", "original")
        p = self.write("statement.pdf", "new-different")
        real_guarded = fileorg.guarded_move
        calls = []

        def spy(src, dest, protected, root):
            calls.append(str(dest))
            return real_guarded(src, dest, protected, root)

        with mock.patch.object(fileorg, "guarded_move", side_effect=spy):
            fileorg.apply_classification(
                self.conn, p, "FIN-Banking", fileorg.load_codes())
        self.assertEqual(len(calls), 1)
        self.assertTrue(calls[0].endswith("SYS-Unsorted/statement.pdf"))


class TestApplyClassificationCLI(FileorgTestCase):
    def _run(self, args):
        out_buf, err_buf = io.StringIO(), io.StringIO()
        with redirect_stdout(out_buf), redirect_stderr(err_buf):
            rc = fileorg.main(args)
        return rc, out_buf.getvalue(), err_buf.getvalue()

    def _protect_cfg(self, data):
        cfg = self.db_path.parent
        cfg.mkdir(parents=True, exist_ok=True)
        (cfg / "codes.local.json").write_text(json.dumps(data))

    def test_apply_classification_subcommand_parses(self):
        parser = fileorg.build_parser()
        ns = parser.parse_args(
            ["apply-classification", "/x/f.pdf", "FIN-Banking", "--dry-run"])
        self.assertEqual(ns.cmd, "apply-classification")
        self.assertEqual(ns.file, "/x/f.pdf")
        self.assertEqual(ns.folder, "FIN-Banking")
        self.assertTrue(ns.dry_run)

    def test_cmd_applies_and_prints(self):
        self._protect_cfg({"protected": ["LEG-Case"]})  # silence the warning
        (self.root / "FIN-Banking").mkdir()
        p = self.write("bank_statement.pdf", "a")
        rc, out, _ = self._run(
            ["apply-classification", str(p), "FIN-Banking"])
        self.assertEqual(rc, 0)
        self.assertIn("applied", out)
        self.assertTrue(
            (self.root / "FIN-Banking" / "bank_statement.pdf").exists())

    def test_cmd_dry_run_prints_would_apply_moves_nothing(self):
        self._protect_cfg({"protected": ["LEG-Case"]})
        (self.root / "FIN-Banking").mkdir()
        p = self.write("bank_statement.pdf", "a")
        rc, out, _ = self._run(
            ["apply-classification", str(p), "FIN-Banking", "--dry-run"])
        self.assertEqual(rc, 0)
        self.assertIn("would apply", out)
        self.assertTrue(p.exists())
        self.assertFalse(
            (self.root / "FIN-Banking" / "bank_statement.pdf").exists())

    def test_cmd_invalid_folder_prints_refused_rc0(self):
        self._protect_cfg({"protected": ["LEG-Case"]})
        p = self.write("bank_statement.pdf", "a")
        rc, out, _ = self._run(
            ["apply-classification", str(p), "FIN-Nonexistent"])
        self.assertEqual(rc, 0)
        self.assertIn("refused", out.lower())
        self.assertIn("FIN-Nonexistent", out)
        self.assertTrue(p.exists())
        self.assertFalse((self.root / "FIN-Nonexistent").exists())

    def test_cmd_warns_when_guard_inactive(self):
        # No codes.local.json / no "protected" -> the ADR 0018 stderr warning,
        # same as _cmd_place / _cmd_sweep.
        (self.root / "FIN-Banking").mkdir()
        p = self.write("bank_statement.pdf", "a")
        rc, _, err = self._run(
            ["apply-classification", str(p), "FIN-Banking"])
        self.assertEqual(rc, 0)
        self.assertIn("no protected paths configured", err)
        self.assertIn("ADR 0018", err)

    def test_cmd_nonexistent_file_returns_2(self):
        # Valid folder, but the source file does not exist -> guarded_move's
        # shutil.move raises FileNotFoundError (OSError) -> main() maps it to
        # a clean exit 2, no traceback.
        self._protect_cfg({"protected": ["LEG-Case"]})
        (self.root / "FIN-Banking").mkdir()
        missing = self.root / "no-such-file.pdf"
        rc, _, err = self._run(
            ["apply-classification", str(missing), "FIN-Banking"])
        self.assertEqual(rc, 2)
        self.assertNotIn("Traceback", err)

    def test_cmd_refuse_protected_via_cli(self):
        # CLI-level twin of TestApplyClassificationRefuseAndStage's
        # test_protected_destination_refused_and_staged -- closes the review
        # finding that refuse-protected was only exercised at the
        # apply_classification() function level, never driven through the
        # real `fileorg apply-classification` subcommand end-to-end. This is
        # the legal-discovery protected-path guard (ADR 0018), so it needs an
        # executable CLI test, not just code-tracing.
        self._protect_cfg({
            "protected": ["LEG-Case"],
            "LEG": {"name": "Case", "keywords": ["case"], "extensions": []},
        })
        (self.root / "LEG-Case").mkdir()
        p = self.write("case_notes.pdf", "a")
        rc, out, _ = self._run(
            ["apply-classification", str(p), "LEG-Case"])
        staged = self.root / fileorg.SYS_UNSORTED / "case_notes.pdf"
        self.assertEqual(rc, 0)
        # The printed line must name BOTH the refusal kind and the protected
        # path itself (ADR 0018: a legal-guardrail refusal must never read
        # as a generic staging collision).
        self.assertIn("refused (refuse-protected)", out)
        self.assertIn("protected-path: LEG-Case", out)
        self.assertFalse(p.exists())
        self.assertTrue(staged.exists())
        self.assertFalse((self.root / "LEG-Case" / "case_notes.pdf").exists())
        self.assertEqual(list((self.root / "LEG-Case").iterdir()), [])
        conn = fileorg.open_db()
        try:
            row = conn.execute(
                "SELECT id FROM files WHERE path=?", (str(staged),)).fetchone()
            self.assertIsNotNone(row)
            self.assertIn(fileorg.NEEDS_REVIEW_TAG,
                          fileorg.get_tags(conn, row["id"]))
            n_protected = conn.execute(
                "SELECT COUNT(*) FROM files WHERE path=?",
                (str(self.root / "LEG-Case" / "case_notes.pdf"),)
            ).fetchone()[0]
            self.assertEqual(n_protected, 0)
        finally:
            conn.close()

    def test_cmd_refuse_exists_via_cli(self):
        # CLI-level twin of TestApplyClassificationRefuseAndStage's
        # test_collision_at_destination_refused_and_staged -- closes the
        # review finding that refuse-exists was only exercised at the
        # apply_classification() function level, never driven through the
        # real subcommand.
        #
        # NOTE (verified against apply_classification's actual step 3,
        # fileorg.py ~1140): refuse-exists fires on a collision at the
        # REAL chosen-folder destination (`dest.exists()`, i.e.
        # FIN-Banking/statement.pdf here) -- not at the SYS-Unsorted staging
        # path. Pre-occupying SYS-Unsorted/<name> instead exercises a
        # DIFFERENT code path (the double-collision abort, FileExistsError,
        # rc=2), already covered by
        # test_double_collision_at_staging_aborts_and_preserves_both. That
        # scenario cannot assert rc==0, so it is not what's being closed here.
        self._protect_cfg({"protected": ["LEG-Case"]})  # silence the warning
        (self.root / "FIN-Banking").mkdir()
        existing = self.write("FIN-Banking/statement.pdf", "original")
        p = self.write("statement.pdf", "new-different")
        rc, out, _ = self._run(
            ["apply-classification", str(p), "FIN-Banking"])
        staged = self.root / fileorg.SYS_UNSORTED / "statement.pdf"
        self.assertEqual(rc, 0)
        self.assertIn("refused (refuse-exists)", out)
        # A plain collision refusal must NOT be labeled protected-path --
        # that suffix is reserved for an actual ADR 0018 guard hit.
        self.assertNotIn("protected-path", out)
        self.assertEqual(existing.read_bytes(), b"original")
        self.assertTrue(staged.exists())
        self.assertEqual(staged.read_bytes(), b"new-different")
        self.assertFalse(p.exists())
        conn = fileorg.open_db()
        try:
            row = conn.execute(
                "SELECT id FROM files WHERE path=?", (str(staged),)).fetchone()
            self.assertIsNotNone(row)
            self.assertIn(fileorg.NEEDS_REVIEW_TAG,
                          fileorg.get_tags(conn, row["id"]))
            n_real_dest = conn.execute(
                "SELECT COUNT(*) FROM files WHERE path=?",
                (str(self.root / "FIN-Banking" / "statement.pdf"),)
            ).fetchone()[0]
            self.assertEqual(n_real_dest, 0)
        finally:
            conn.close()


class TestSkillDoc(unittest.TestCase):
    def setUp(self):
        self.skill = Path(fileorg.__file__).resolve().parent / "SKILL.md"

    def test_skill_exists(self):
        self.assertTrue(self.skill.is_file())

    def test_frontmatter_has_use_when_trigger(self):
        text = self.skill.read_text()
        self.assertTrue(text.startswith("---"))
        head = text.split("---", 2)[1]
        self.assertIn("description:", head)
        self.assertIn("Use when", head)

    def test_examples_use_absolute_python(self):
        text = self.skill.read_text()
        self.assertIn("/usr/bin/python3 fileorg.py", text)

    def test_documents_sweep_verb(self):
        # The Phase 2 sweep verb must be documented in Steps, invoked with the
        # absolute interpreter, and note the ~/Downloads default + dry-run.
        text = self.skill.read_text()
        self.assertIn("/usr/bin/python3 fileorg.py sweep", text)
        lower = text.lower()
        self.assertIn("downloads", lower)
        self.assertIn("--dry-run", lower)

    def test_documents_apply_classification_verb(self):
        # The Phase 3 apply-classification verb must be documented in Steps,
        # invoked with the absolute interpreter, and note the real+recognized
        # folder validation + protected-path guard reuse.
        text = self.skill.read_text()
        self.assertIn("/usr/bin/python3 fileorg.py apply-classification", text)
        lower = text.lower()
        self.assertIn("apply-classification", lower)
        self.assertIn("--dry-run", lower)

    def test_no_bare_python3_invocation(self):
        text = self.skill.read_text()
        for line in text.splitlines():
            stripped = line.strip()
            if stripped.startswith("python3 ") or stripped.startswith("$ python3 "):
                self.fail("bare python3 invocation found: %r" % line)

    def test_restates_safety_rules(self):
        text = self.skill.read_text().lower()
        self.assertIn("--dry-run", text)
        self.assertIn("overwrite", text)
        self.assertIn("sys-unsorted", text)

    def test_states_classification_is_fully_automatic(self):
        # Red flags must explicitly call out that the CLI never prompts for
        # a category (spec 3.3: "fully automatic -- no interactive prompt").
        text = self.skill.read_text().lower()
        self.assertIn("never prompt", text)

    def test_has_five_required_sections_in_order(self):
        # hq skill-authoring standard (tools/skill-authoring.md §2/§4): every
        # skill body must have these five headings, in this order.
        text = self.skill.read_text()
        required = ["## Trigger", "## Steps", "## Red flags",
                    "## Exit criteria", "## Provenance"]
        positions = []
        for heading in required:
            self.assertIn(heading, text,
                          "missing required section: %s" % heading)
            positions.append(text.index(heading))
        self.assertEqual(positions, sorted(positions),
                         "required sections are out of order: %r" % required)

    def test_steps_are_numbered(self):
        text = self.skill.read_text()
        steps_start = text.index("## Steps")
        steps_end = text.index("## Red flags")
        steps_body = text[steps_start:steps_end]
        self.assertIn("1.", steps_body)
        self.assertIn("2.", steps_body)

    def test_red_flags_is_rationalization_table(self):
        text = self.skill.read_text()
        start = text.index("## Red flags")
        end = text.index("## Exit criteria")
        body = text[start:end]
        self.assertIn("Rationalization", body)
        self.assertIn("What to do instead", body)
        # At least three real rows (header + separator + >=3 data rows).
        row_count = sum(1 for line in body.splitlines()
                        if line.strip().startswith("|"))
        self.assertGreaterEqual(row_count, 5)

    def test_exit_criteria_is_checklist(self):
        text = self.skill.read_text()
        start = text.index("## Exit criteria")
        end = text.index("## Provenance")
        body = text[start:end]
        checklist_items = body.count("- [ ]")
        self.assertGreaterEqual(checklist_items, 3)

    def test_provenance_links_architecture_source(self):
        text = self.skill.read_text()
        start = text.index("## Provenance")
        body = text[start:]
        self.assertIn("Provenance:", body)
        self.assertIn("architecture/file-organizer.md", body)

    def test_no_personal_identifiers(self):
        text = self.skill.read_text()
        # Category-name-level examples (a code plus a generic descriptive
        # word, e.g. "the retirement subfolder of FIN") -- not an actual
        # person's name or address, so these are safe to keep inline in
        # this tracked test file.
        forbidden = ["FIN-Retirement", "DIV-Divorce", "WRK-Employment"]
        for pattern in forbidden:
            self.assertNotIn(pattern, text,
                             "PII pattern found in SKILL.md: %r" % pattern)
        # Real personal identifiers (a person's name, a street name) must
        # NEVER be written into this tracked test file -- doing so would
        # itself be the exact leak this test exists to catch. Instead,
        # read them from the REAL, untracked local codes.local.json (see
        # fileorg.load_protected_paths / load_codes for the same
        # Layer-1/Layer-2 split) if one happens to exist on this machine,
        # and skip this half of the check when it doesn't -- e.g. on a
        # fresh checkout or in CI, which has no real personal config to
        # check the doc against, so there is nothing to regress.
        local_patterns = _local_personal_folder_names()
        if not local_patterns:
            return
        for pattern in local_patterns:
            self.assertNotIn(pattern, text,
                             "PII pattern found in SKILL.md: %r" % pattern)


if __name__ == "__main__":
    unittest.main()
