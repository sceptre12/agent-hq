# Dry-run fixture for delivery-intake

A fake repo (`repo/`) and the expected shape of the outputs (`expected/`). The check is on shape, not on exact prose.

Run (by a reader agent that follows SKILL.md; no desk needed, so no `RESEARCH`):
1. Copy `repo/` to a scratch directory, run `git init` and make one commit there. Create `delivery/run-1-20261026/` and a plans directory. Pass the five inputs in `expected/inputs.txt`.
2. Follow SKILL.md steps 0 to 11 against that copy; the explorer questions are answerable from the five files.
3. Save `facts.md` (copied from `PLANS_DIR`), the run's stdout as `stdout.txt` and, from a second run with `DELIVERY_ROOT` unset, the output as `unset.txt` into the output directory.

Expected: `facts.md` line 1 `FACTS: <n> facts` with `<n>` the row count; at least one `measured: ` row; the hosting-service question is a `cannot measure:` row; the profile carries `release_tags.used: "no"` and sentinels for what the repo cannot show; `stdout.txt` ends with `PROFILE: <abs path>@<40-hex>` and `git hash-object <profile>` equals that sha; `unset.txt` contains `INPUT-ERROR DELIVERY_ROOT unset`.
