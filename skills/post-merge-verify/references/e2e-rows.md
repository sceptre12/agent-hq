# E2E rows (post-merge-verify)

- Run each e2e row through the `nl-run-e2e` plugin skill (work-environment NLTA plugin; cite it, do not copy its text). Inputs come from the repo profile `e2e.*` keys and the row's `.feature` path.
- Ports: the e2e lane's servers follow Step 3 of the skill (claim, register, launch, start). A refused claim fails the row with reason `lane-unavailable`.
- Auto-heal: if the run heals specs, collect every healed diff. A reviewer other than the runner reads each diff and decides accept or reject. A healed diff is never accepted blind. Record `auto-heal reviewed=yes|no` and the diff path in the evidence line. Healing that touches product source is a reject.
- Failure classes (the plugin owns them; cited, not frozen): `SELECTOR_DRIFT`, `TIMING_BUG`, `TEST_BUG`, `SOURCE_BUG`, `ENV_BUG`, `AMBIGUOUS`.
  - `SOURCE_BUG`: always escalate to the human. Stop that row, record `source-bug`, and do not heal or retry.
  - `ENV_BUG`: the row fails with reason `env-bug`; the failure policy decides retries.
  - Others: the row's failure policy decides; a healed pass counts only after the diff review.
- Evidence line carries the `nl-run-e2e` result, the class if any, and the reviewed-diff paths.
