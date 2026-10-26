# Consumer simulation (post-merge-verify)

- Runs after one serial pack (card 12): run the profile `commands.pack` (design part-04 §5.8; `delivery-intake` profile template) once in the worktree, serially, before any consumer row. All consumer-simulation rows use that one artifact; never repack per row.
- Each row installs or links the packed artifact into a throwaway consumer fixture under `RUN_HOME/pm/consumer/<row-id>/` (skill-local path, `DEFAULT`; catalog `tmpdir` row: `catalog.sh register tmpdir <abs path> - run post-merge-verify pm <agent_id>`, then `start`; if the directory cannot be created, `catalog.sh fail tmpdir <abs path>` and stop), runs the row's "how it is simulated" text there, and compares to `expected`.
- Install in the fixture uses the profile `commands.install` form (frozen lockfile, scripts ignored). A row that needs a dependency the lockfile does not hold: do not run it, do not improvise; stop and report the missing dependency to the `pm` lead.
- The profile `repo.consumer_repos[]` are read-only here; never edit them.
- Publishing, tagging or promoting the artifact is never part of this skill (`release-track` and the desk own those).
- Class: the plan template's consumer table (`id | consumer | how it is simulated | expected`) has no class column. Until the owner rules, a consumer row counts as `gating` (the conservative reading: it can only block a PASS, never make one). A plan that gives the row a class column uses that class.
