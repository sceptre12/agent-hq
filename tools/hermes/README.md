# tools/hermes — the Hermes hq digest builder (and stored backup/restore tools)

Builds the read-only snapshot of hq `main` that Hermes reads, its `MANIFEST.tsv`, and the staged
`hq-index` pointer skill, and proves the snapshot equals `main`. It also stores the backup and restore tools (`backup-hermes.sh`,
`restore-hermes.sh`, a LaunchAgent plist draft and their tests; not part of the Hermes setup, see "Stored tools"). Design: `architecture/hermes-agent.md`
§7 and §13 D3/D8. These scripts never run Hermes,
never fetch, never read a token and never write under the hq repo.

The Hermes setup templates and records (launcher, hook, plist, config extract) are in `setup/`; see `setup/README.md`.
To install and lock down Hermes on a new machine, follow `setup/INSTALL.md`; `setup/check-config` verifies the locked `config.yaml` against `setup/required-config.tsv`.

## Files

- `build-digest.sh <sha> <out-root>` — snapshot of the digest set at `<sha>` into `<out-root>/hq/<sha>/`.
  The hq repo is `$HQ_REPO`, else the repo holding the script.
- `verify-digest.sh <snapshot-dir> [<hq-repo>]` — checks (1)-(4) of §7 "Verify the digest matches main";
  prints `DIGEST == MAIN <sha>`. `verify-digest.sh --paths <sha> [<hq-repo>]` prints the selected set.
- `digest-set.txt` — the §7 file set in index order and the exclusion globs (data; read by both scripts).
- `test_build-digest.sh` — hermetic tests (fixture repo in `mktemp -d`; no network, no Hermes).
- `backup-hermes.sh --src <HERMES_HOME> --dest <BACKUP_ROOT>` — STORED tool (not installed): one dated, hash-verified generation.
- `restore-hermes.sh --gen <gen> --target <dir>` — STORED tool: verified restore of one generation.
- `hermes-backup.plist.example` — draft LaunchAgent, stored and not installed.
- `test_backup-hermes.sh`, `test_backup-hermes-2.sh`, `-3.sh`, `-4.sh`, `-5.sh` — hermetic tests of both scripts and the plist (synthetic trees). Both scripts take `--help` (usage, flags, exit codes; touches nothing).

## What build-digest.sh does

1. Selects tracked regular files at `<sha>` (`git ls-tree -r`) that match an `include` line of
   `digest-set.txt` and no `exclude` line (symlinks and submodules are never selected), then
   `git archive <sha> -- <selection>` into a temporary directory beside the snapshot. `inbox/`,
   `memory/`, untracked files and `node_modules/` are absent by construction.
2. Secret abort: scans every file with the `tools/git-hooks/pre-commit` check (c) regex (without its
   diff prefix). Any hit prints `SECRET-HIT: <path>` (never the match), deletes the partial snapshot,
   exits 3. A scan error also fails closed (exit 3).
3. Writes `MANIFEST.tsv` (`# hq <sha> built <ISO-UTC>`, then `<path>\t<blob-sha>`, `LC_ALL=C` sorted)
   and the staged index skill `.index/hq-index/SKILL.md` (sha, the §7 order, one line per file:
   path + first `#` heading, and the retrieval rule "grep first, read the matched slice, cite
   `path:line@sha`").
   The skill also states `Root: <out-root>/hq/current/ (this snapshot: <out-root>/hq/<sha>/)` (`$base` in
   the script is `<out-root>/hq`) and tells Hermes to pass ABSOLUTE paths to `read_file`/`search_files`
   (`build-digest.sh:59`).
4. Moves it to `<out-root>/hq/<sha>/`, `chmod -R a-w`, runs `verify-digest.sh`; only on a pass flips
   `<out-root>/hq/current` with `ln -sfn`. On a failed verify the new snapshot is deleted and
   `current` is untouched. Previous snapshots are kept; an existing `<sha>` is never overwritten.

Exit codes (`build-digest.sh` and `verify-digest.sh`): 0 ok, 1 error, 2 usage, 3 secret hit, 4 stale, 5 mismatch.

## Refresh when hq main moves (§7, manual owner step in phase 1)

1. Stop Hermes.
2. `git -C <hq> fetch origin main`, then `tools/hermes/build-digest.sh "$(git -C <hq> rev-parse origin/main)" <hermes-profile-dir>`
   (builds the new `<sha>` snapshot, runs the secret scan, regenerates `MANIFEST.tsv` and the index skill).
3. The owner approves the index skill: review `<hermes-profile-dir>/hq/<sha>/.index/hq-index/SKILL.md`
   and copy it into `HERMES_HOME/skills/hq-index/` (it is staged only; the scripts never install it).
4. `current` is flipped by the build only after `verify-digest.sh` passes; keep the previous snapshot
   until the new one is verified in use.
5. Before use, `tools/hermes/verify-digest.sh <hermes-profile-dir>/hq/current <hq>` must print
   `DIGEST == MAIN <sha>`; STALE (exit 4) or any mismatch (exit 5): do not use the snapshot.

## verify-import (row 7a)

`verify-import TARGET_SKILLS_DIR --repo <hq> --sha <sha-the-import-used> [--allow-extra REL]... [--expect N] [--spot N] [--seed S]`
checks a skills tree written by `import-learnings` against that hq commit, read-only: inputs / expected /
skipped, count, layout (each `<category>/<name>/` holds exactly `SKILL.md`, a regular file; no stray files,
empty categories or stale `.SKILL.md.import-tmp`), frontmatter (keys exactly `name`, `description`), footer
`path@sha`, body sha256, secret scan, spot read-back and a read-only proof. It prints `verify-import: PASS` or
FAIL with names only (never a secret match or a body). Files the importer skipped (exit 6 / 7) fail the run.
`--allow-extra hq-index` (repeatable, exact relative path, no globs) exempts a folder the owner flow adds
(`hq-index`, Hermes' `.archive`); it is listed as `ALLOWED extra: REL` (`(not present)` if absent). `--allow-extra .archive`
covers everything BELOW `.archive` but nothing named like it (`.archive-x` still FAILs). Allowed extras are exempt from the
frontmatter, description and extra-file rules but are secret-scanned (unless `--bundled-source` holds a byte-identical copy, see below); a symlink at or under one FAILs (never followed).
Known non-checks: a hard link inside an allowed extra passes (its content is still secret-scanned); swapping the order of the
`name` and `description` lines passes (the key SET is checked, not the order).
`--expect N` pins the expected skill count. Exit: 0 PASS, 1 FAIL, 2 usage/unreadable, 3 live home refused.
Code is `verify_import.py` (+ `verify_scan.py`, `verify_fm.py`); tests: `bash tools/hermes/test_verify-import.sh`.

### verify-import --bundled-source DIR

`--bundled-source DIR` (once; brain default under R-q, the owner may veto) lets a bundled Hermes tree named by `--allow-extra`
skip the secret scan when it is byte-identical to a Hermes source copy. DIR is operator-supplied: the tool checks that it is
absolute, a real directory (not a symlink), not inside TARGET and not the live Hermes home, but NOT which commit it holds.
Source commit for the M6 flow: hermes-agent `908e4a4b44480912ae3571833492c1aeac2d0eda`. Build DIR outside the live home:
`mkdir /private/tmp/hsrc && git -C ~/claude-profiles/hermes/hermes-agent archive 908e4a4b44480912ae3571833492c1aeac2d0eda skills | tar -x -C /private/tmp/hsrc`,
then pass `--bundled-source /private/tmp/hsrc/skills`. That `skills/` holds 13 directories (apple, autonomous-ai-agents, creative,
devops, email, index-cache, media, note-taking, productivity, research, social-media, software-development, web) plus `AGENTS.md`;
only the REL names you pass with `--allow-extra` are compared, so the rest is ignored.
Worked example: `verify-import TARGET --repo ~/projects/agent-hq --sha <import sha> --bundled-source /private/tmp/hsrc/skills
--allow-extra apple --allow-extra autonomous-ai-agents --allow-extra creative --allow-extra devops --allow-extra email
--allow-extra media --allow-extra note-taking --allow-extra productivity --allow-extra research --allow-extra social-media
--allow-extra software-development --allow-extra web --allow-extra .bundled_manifest --allow-extra .curator_state
--allow-extra hq-index --allow-extra .archive`.
Per extra: if `DIR/REL` exists, `TARGET/REL` must match it as a tree (same entries, same bytes; no symlink or special file on either
side, lstat, never followed; hard links and metadata are not compared). The same holds for every PARENT component of REL under
both roots: a symlinked parent FAILs `REL(symlinked-parent)`, and REL must stay inside the real path of DIR and of TARGET
(`outside-root`). A match prints `ALLOWED extra (identical to source): REL` and skips the scan for it (never printed for a REL whose
comparison failed). Any difference prints `FAIL bundled` with RELATIVE paths and a reason (`bytes-differ`, `extra-in-target`,
`missing-in-target`, `symlink-in-target`, `symlink-in-source`, `type-differs`, `special-file`, `symlinked-parent`, `outside-root`),
never content. A file-type REL (for example `AGENTS.md`) is compared as a single file. An extra with no `DIR/REL`
(`.bundled_manifest`, `.curator_state`, `hq-index`, `.archive`: runtime files with no source counterpart) is still secret-scanned.
Under the flag a REL absent from TARGET but present in DIR FAILs `missing-in-target`; without the flag it is `ALLOWED extra: REL (not present)` and passes.
Drift: the Hermes curator may patch bundled skills, so a patched file FAILs `bytes-differ` naming its path. Remedy: review that
file, then re-build DIR from the commit the live home was built from; do not drop the flag to get a PASS.
Exit: 0 PASS (9 checks with the flag, 8 without), 1 FAIL, 2 bad usage (DIR relative, missing, a symlink, inside TARGET, or the flag
given twice), 3 DIR is, holds or lies in the live home (`--i-am-the-owner-live` never relaxes this). FAIL name lists are cut at 20 names.
Code: `verify_bundled.py`; tests: `bash tools/hermes/test_verify-import-bundled.sh`.

## import-learnings

`import-learnings TARGET_SKILLS_DIR [--apply] [--limit N] [--files PATH...] [--repo <hq>] [--sha <sha>] [--i-am-the-owner-live]`
turns hq `learnings/` and `retros/` into a Hermes skills tree, one skill per file, at one commit (default `origin/main` of
`--repo`, which defaults to `$HQ_REPO`, else the repo holding the script). Cites below are `26baf333:<file>:<line>`;
`python3 -I tools/hermes/import_learnings.py -h` prints the full help.
- Dry run is the default: it prints the plan and writes nothing. `--apply` writes (temp files, then renames; rolled back on a write error).
  `--limit N` takes the first N inputs in path order; `--files` takes repo-relative paths (`learnings/x.md`); a path that is not an input is reported as `skip (not an input): <path>` and skipped, and the run continues (`import_learnings.py:90-94`).
- Live home: a target that is, contains or lies inside the live Hermes home, or a `HERMES_HOME` pointing at it, exits 3
  (`il_guard.py:6,28-38`; the home comes from `pwd.getpwuid`, not `$HOME`). `--i-am-the-owner-live` skips the guards (owner only).
- Input set: every `.md` blob (mode 100644 or 100755) under `learnings/` (any depth) and `retros/` at the commit, sorted
  (`import_learnings.py:42-48`); 116 files at the time of writing. Other file types are ignored.
- Names: the file stem, lowercased and sanitised. Four generic files are prefixed by an exact, case-sensitive full-path map
  (`il_describe.py:6`, used by `skill_name()` at `:30-31`): `learnings/README.md` -> `learnings-readme`,
  `learnings/METHODOLOGY.md` -> `learnings-methodology`, `retros/README.md` -> `retros-readme`, `retros/_TEMPLATE.md` -> `retros-template`.
  `readme.md`, `Readme.md` and other spellings are not in the map and keep their plain name. The prefix naming is the brain
  default under R-q; the owner may veto.
- Collision rule: two inputs that map to one skill name, or a name that already exists in another category of the target, exit 1
  with `name collision` and write nothing (`import_learnings.py:102-106`).
- Exit codes: 0 ok, 1 error, 2 usage, 3 live-home refusal, 4 refused overwrite (non-imported `SKILL.md` or a symlink),
  6 oversize skill(s), 7 secret-shaped file(s) (`import_learnings.py:152`); 6 and 7 skip only those files, the rest are written.
- Check the result: `verify-import TARGET --repo <hq> --sha <sha-used> --expect 116` (the shim runs `verify_import.py`; see verify-import above).
  Tests: `bash tools/hermes/test_import-learnings.sh`.

## Tests

`bash tools/hermes/test_build-digest.sh` (mapped in `tools/code-gate/test-map.tsv`; Rule 10).

## Stored tools: backup and restore (row 6, removed from the setup)

The owner removed row 6 from the Hermes setup on 2026-10-13; the decision is in `architecture/hermes-agent-memory.md` section 7.
The tools below stay in hq as STORED tools: they are not installed, no backup generation is a gate condition, and nothing
schedules them. Scripts: `backup-hermes.sh`, `restore-hermes.sh`; draft LaunchAgent `hermes-backup.plist.example`; tests
`test_backup-hermes*.sh` (synthetic tree in `mktemp -d`; never touches the live home, never runs Hermes).
Defaults marked "brain default" are under R-q and the owner may veto them.

### Scope of one generation (relative to `--src`, the Hermes home; read-only)

`memories/`; `skills/` including `skills/.archive/` and `skills/.curator_ledger.jsonl`;
`.curator_backups/blobs/` (outside `skills/`, content-addressed by sha256, needed by `curator rollback`);
`state.db` with `state.db-wal` and `state.db-shm` if present; `pending/`. Dotfiles included. Missing optional
pieces are recorded in `MANIFEST.txt`, not errors; `memories/` and `skills/` both missing is an error.

### Generations and retention

`backup-hermes.sh --src <HERMES_HOME> --dest <BACKUP_ROOT> [--keep N] [--allow-live]` (no defaults for src/dest)
first computes `SHA256SUMS` from the SOURCE files (paths relative to `data/`, sorted), then copies into
`<dest>/.tmp-<stamp>-<pid>/data/`, writes `MANIFEST.txt`, verifies the copy against the source-derived hashes,
re-hashes the source after the copy (a change means exit 4 "source changed during backup"; skipped with
`--allow-live`, and `MANIFEST.txt` then says "LIVE COPY"), runs `PRAGMA integrity_check` on a scratch copy of the
staged `state.db` (anything but `ok` is exit 4 "source state.db failed integrity_check"; nothing is published and
older generations stay), then renames to `<dest>/gen-YYYYmmddTHHMMSSZ/`. A failure removes
only its own `.tmp-*` and never leaves a half `gen-*`. It is not a mirror. Retention `--keep` defaults to 7
(brain default): after a verified generation the oldest `gen-*` directories beyond N are deleted, never the new
one, never symlinks or non-matching names. Only real directories named `gen-<8 digits>T<6 digits>Z` that hold `SHA256SUMS`, `MANIFEST.txt` and a `data/` directory count, so a decoy or forged `gen-*` directory takes no slot and
never evicts a real generation or serves as the "previous generation" of the shrink guard. `--allow-live` generations are not safe recovery points: they are kept in their own pool
(the newest N of them) and never count against, or evict, clean generations. If the new generation has fewer than
50% of the files of the newest generation of its pool, it is still kept but retention is SKIPPED with a loud warning
on stderr (a shrunken source must not rotate good generations out). The log line prints the resolved src realpath.
It refuses (exit 5) a dest inside src, src inside dest, a dest under `~/claude-profiles/hermes` (the real path,
derived from `$HOME` and the passwd database, is always checked; the tests-only env var can only add a prefix), any
`--src`/`--dest` containing a `..` component, a dest that is a symlink or a file. The path checks compare
case-insensitively (macOS default volumes), conservatively also on case-sensitive ones.
Staging, `.tmp-*` and `gen-*` directories are created with `umask 077` (directories mode 700), and the staged copy
is `chmod -R go-rwx` after `cp -Rp`, so files are owner-only (a 644 source file is 600, 755 is 700); mtimes are kept.

Exit codes of `backup-hermes.sh`:

| Exit | Meaning |
|---|---|
| 0 | ok |
| 1 | other failure (unreadable file, cp error): nothing published (a staged copy is removed) |
| 2 | usage, invalid source, or no files in scope |
| 3 | not quiesced (state.db open, or lsof absent while a state.db file exists) |
| 4 | verify failed, source changed during backup, or state.db failed integrity_check |
| 5 | refused: path (.., live home, dest in src, dest file/symlink), the passwd home cannot be read (python3 missing or failing), symlink in scope, stamp collision |

Exit codes of `restore-hermes.sh`:

| Exit | Meaning |
|---|---|
| 0 | ok: `restored N files, hashes OK` |
| 1 | other failure, e.g. `cp` cannot overwrite a read-only file in the target: the target may be PARTIALLY merged (some files written, others not); nothing is published or rolled back, so inspect the target |
| 2 | usage, or `--gen` is not a backup generation |
| 4 | the generation fails `SHA256SUMS`, its file count differs, or it contains a symlink (all checked BEFORE anything is written); or the restored copy fails the re-verify (files are already written) |
| 5 | refused: target (live home, `..`, symlink component, inside the generation / cwd / `$HOME`, not empty without `--force`, file), stale sidecar, or the passwd home cannot be read (python3 missing or failing) |

Both scripts need `python3` on PATH to read the passwd home for the live-home guard; without it they refuse every invocation, including `--help` and `--print-forbidden` (the guard runs before argument parsing; exit 5).
Restored files keep the generation's modes (files 600, directories 700, mtimes kept by `cp -Rp`); the target directory itself
becomes 700, also when it existed before (`--force`). `--print-forbidden` (both scripts) is TESTS-ONLY by intent but reachable in
production: it is read-only, prints the forbidden live-home list (resolved physically) and exits 0.

Symlinks: a Hermes home with a symlink in scope (a scoped piece, its parent, or any entry inside the scoped tree)
is refused with exit 5 and nothing is written; links are never followed. Ask the owner.

Empty source: if the scoped pieces hold no regular files the run fails with exit 2 "no files in scope: nothing to
back up" before copying, on purpose, so an empty source can never rotate good generations out through
retention. A fresh Hermes home therefore fails until the first import has put files in scope.

A killed run (SIGKILL, power loss) can leave a stale `.tmp-*` directory in `<dest>`; it is never pruned. It is
safe to delete by hand once no backup is running; the script removes only its own on failure.

### Quiesce rule

`state.db`, `-wal`, `-shm` must not be open by another process (`lsof`). If one of those files exists and `lsof` is
absent the run exits 3 (not quiesced); a source without any of them never calls `lsof`. If `lsof` is present but
errors, the files count as NOT open (known limit 2).
Otherwise exit 3 and nothing is written: the gateway must be booted out first. The lsof check is a point-in-time check
(a small race remains). With the gateway running, a run therefore exits 3. `--allow-live` makes a live copy anyway (not
guaranteed consistent; a copy that changes mid-run fails verification, exit 4) and writes
"LIVE COPY: not guaranteed consistent" into `MANIFEST.txt`.

### Restore procedure

1. Pick a generation under `<BACKUP_ROOT>` (newest `gen-*`); read its `MANIFEST.txt`.
2. Rehearse on a scratch directory: `restore-hermes.sh --gen <gen> --target <new-empty-dir>`. It verifies
   `SHA256SUMS` first (fail closed, exit 4), copies `data/`, re-verifies, prints `restored N files, hashes OK`.
   It refuses a non-empty target without `--force`, a target containing `..`, a target that is a file, a symlink or has a
   symlink component below the top level, a target inside the generation, a target that is the generation, the cwd or
   `$HOME` or an ancestor of any of them (so `--force` cannot merge into a parent or `.`), and any target under
   `~/claude-profiles/hermes` (the real path is always checked). Top-level system links such as `/tmp` and `/var`
   (macOS, into `/private`) are resolved, so a scratch target under them works. `--force` MERGES into the target
   (it does not replace it): it refuses (exit 5) when the target holds a `state.db-wal` or `state.db-shm` the
   generation lacks, and it prints "target had N extra files not in the generation" when other files remain.
3. Owner-only restore into the live home: boot the gateway out (`launchctl bootout gui/$UID/<gateway label>`),
   move the damaged home aside (do not delete it), restore into a new directory with the script, check the
   result, then place it as the Hermes home by the owner's own move, and start the gateway again. The script
   itself will not target the live home.
4. Undo a skill edit by hash: the ledger line's `before` hash names a file in `.curator_backups/blobs/<sha256>`.
   `hermes curator rollback <entry-id>`: UNVERIFIED (not run; Hermes is not run by this work). Test (j) proves
   only that the restored blob's sha256 equals the ledger entry's before-hash.
5. Probe rows affected, all UNVERIFIED until run on a scratch home: P7, P14, D1, X1b, W3, C2, D2 (D2 is the
   delete-then-`curator rollback` check).

### The draft LaunchAgent (stored, not installed)

`hermes-backup.plist.example` is a draft LaunchAgent kept with the stored tools; under the current design nothing installs
or schedules it. It would run `backup-hermes.sh` daily at 03:17 (`RunAtLoad` false, logs under `__HOME__/Library/Logs/`) with the
placeholders `__HQ__`, `__HERMES_HOME__`, `__BACKUP_ROOT__`, `__HOME__` to fill. The shipped plist has neither the gateway
bootout nor `--allow-live`, so with the gateway holding `state.db` a run exits 3 (see the quiesce rule); with `--allow-live` every
generation is a LIVE COPY (not a safe recovery point, kept in its own pool, integrity check still applies). A pre-created
`<BACKUP_ROOT>` keeps its own mode (the script creates a missing one at 700). The job needs `python3` and `lsof` on launchd's
default PATH (`/usr/bin:/bin:/usr/sbin:/sbin`); without `python3` the run is refused (exit 5, passwd home unreadable).

### Known limits (accepted)

1. No lock against concurrent runs: two simultaneous runs could race (a same-second stamp collision exits 5, but
   no lock is implemented).
2. An `lsof` ERROR (lsof present but failing) is treated as quiesced; how `lsof` fails here is UNVERIFIED, and the
   check is point-in-time. (An ABSENT `lsof` with a state.db file present is exit 3, see the exit table.)
3. Processes of other users are invisible to `lsof`.
4. The literal command `hermes curator rollback <entry-id>` is UNVERIFIED (not run); rollback is proven only by hash.
5. The integrity check covers `state.db` only (`PRAGMA integrity_check` on a copy). The hash check proves copy ==
   source, not that the source is healthy; the content health of `skills/`, `memories/`, ledger and blobs is NOT
   checked. The shrink guard only skips retention (under 50% of the previous file count); it does not fail the run.
6. Stale `.tmp-*` directories from killed runs are never pruned (delete by hand); `--allow-live` generations are
   retained in their own pool (newest N), not counted against `--keep` of the clean pool.
7. A symlinked `--src` root is followed (its resolved path is printed in the log line); a symlinked `--dest` root is refused.
