# Fixture dry run (delivery-architecture)

A non-author reader follows `SKILL.md` on this fixture and saves the output for the spec 15 §9 block. No agent is dispatched for review in the dry run: the two files in `run-home-stubs/` stand in for `review-tailor` and the round-1 synthesizer of `review-7-panel`.

## Contents

| Path | Role |
|---|---|
| `repo/` | a tiny fake repo (`demo-shop`): `package.json`, `src/orders/status.json`, `apps/admin/dev-server.json` (fixed port 4300), a stale existing doc `docs/architecture/orders.md` (lists 4 statuses; source has 6) |
| `repo/plans/repo-profile.md` | the profile, `e2e.harness: none`; git blob id `1ecdc5de9145d5eb21a274690163e8c683ca4b7b` |
| `repo/plans/DEMO-1/brief.md`, `facts.md` | the confirmed brief and 6 measured facts (`FACTS: 6 facts`) |
| `run-home-stubs/review-tailor-run-doc-1.md` | stands in for the `review-tailor` record (`RUNG: 2b seats: 7`) |
| `run-home-stubs/panel7-architecture-r1-synth.md` | stands in for the round-1 synthesizer (`APPROVAL BAR MET 0/0/1`) |
| `expected.md` | what the outputs must show |

## Procedure

1. `X=$TMPDIR/arch-dry; mkdir -p $X/delivery/demo-1-20261102; cp -R <this dir>/repo $X/repo`.
2. In `$X/repo/plans/repo-profile.md` do not edit anything (the blob id must still match): `git hash-object $X/repo/plans/repo-profile.md` prints the id above.
3. Run A (`RUN_HOME` unset): with `DELIVERY_ROOT=$X/delivery`, follow Step 0 with `PLANS_DIR=$X/repo/plans/DEMO-1 REPO_PROFILE=$X/repo/plans/repo-profile.md@1ecdc5de9145d5eb21a274690163e8c683ca4b7b` and no `RUN_HOME`; save stdout to `$X/repo/plans/DEMO-1/unset.txt`.
4. Run B: `DELIVERY_ROOT=$X/delivery`, `RUN_HOME=$X/delivery/demo-1-20261102`, same `PLANS_DIR` and `REPO_PROFILE`. Follow steps 0-15. At step 10, after minting `SLUG=run-doc-1`, copy `run-home-stubs/review-tailor-run-doc-1.md` into `RUN_HOME` instead of invoking `review-tailor`. At step 11, run the G48 pre-round check yourself (read-only) and treat `run-home-stubs/panel7-architecture-r1-synth.md` as the round-1 synthesizer result.
5. `FIXTURE_DIR=$X/repo/plans/DEMO-1` for the §9 block (it holds `review-architecture.md`, `drafts/`, `unset.txt`); `contracts/` lands at `$X/repo/contracts/`.
