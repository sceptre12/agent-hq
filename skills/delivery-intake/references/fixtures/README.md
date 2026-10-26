# Dry-run fixture for delivery-intake

A fake repo (`repo/`) and the expected outputs (`expected/`). The check is on shape, not on exact prose; the `facts.md` rows are exact (each result is what the command prints on the copy below).

Run (by a reader agent that follows SKILL.md):
1. Copy `repo/` to a scratch directory, run `git init` and make one commit there with the message `initial commit`. Create `delivery/run-1-20261026/` and `delivery/plans-demo/` (any existing directory serves as the plans directory). Pass the five inputs in `expected/inputs.txt` (`DELIVERY_ROOT` as an environment variable, the rest as `NAME=value`), with `<dry-run dir>` replaced by the scratch directory. In `expected/`, `<PRIMARY_REPO>` and `<DELIVERY_ROOT>` are placeholders: the real files carry the absolute paths of that run.
2. Follow SKILL.md steps 0 to 11 against that copy; the explorer questions are answerable from the five files or are `cannot measure:` rows. No desk, so no `RESEARCH`. No human: each grilling question takes the recommended answer shown in `expected/brief.md` (Q1-Q5; park nothing else), and step 10 prints the summary and confirm question, then step 11 prints the `PROFILE:` line last in the same turn.
3. Save `facts.md` (copied from `PLANS_DIR`), the run's stdout as `stdout.txt` and, from a second run with `DELIVERY_ROOT` unset, the output as `unset.txt` into the output directory.

Expected:
- `facts.md` line 1 `FACTS: <n> facts` with `<n>` the row count; `expected/facts.md` lists the rows (36); the hosting-service question is a `cannot measure:` row.
- The profile carries every A.2.2 key, `release_tags.used: "no"` and sentinels for what the repo cannot show; `expected/profile-excerpt.yaml` shows the A.2.2 keys only, and its 17 sentinels, one open-item line each, are the counts printed in `expected/stdout.txt`. A full profile also carries the part-04 section 5.8 and skeleton fields, so the reader's counts are higher: check shape, not numbers.
- `stdout.txt`: the summary and confirm question, then `PROFILE: <abs path>@<40-hex>` as the last line; `git hash-object <profile>` equals that sha.
- `unset.txt` contains `INPUT-ERROR DELIVERY_ROOT unset`.
