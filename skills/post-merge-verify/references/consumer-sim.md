# Consumer simulation (post-merge-verify)

- Runs after one serial pack: run the profile `pack` command once in the worktree, serially, before any consumer row. All consumer-simulation rows use that one artifact; do not repack per row.
- Each row installs or links the packed artifact into a throwaway consumer fixture under `RUN_HOME/pm/consumer/<row-id>/` (register it as a catalog `tmpdir` row), runs the row's command there, and compares to `expected`.
- Install in the fixture uses the profile frozen-lockfile form with scripts ignored. Anything that needs a new dependency is a desk `INSTALL` request, not an improvisation.
- Consumer repos named in the profile are read-only here; do not edit them.
- Publishing, tagging or promoting the artifact is never part of this skill (`release-track` and the desk own those).
- A consumer row is `gating` or `informational` per its own plan column and enters the verdict the same way as any other row.
