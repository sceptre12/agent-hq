# Expected dry-run outputs (fixture DEMO-1)

| Output | Expected |
|---|---|
| `unset.txt` | contains the line `INPUT-ERROR RUN_HOME missing` and no other line (with `DELIVERY_ROOT` set) |
| `drafts/index.md` line 1 | `DRAFTS: <n> drafts`, `<n>` between 4 and 7, equal to the draft count |
| drafts | one `Epic` (`parent: -`); at least one `Spike` (CSV streaming without a new library, from the brief) listed before the Stories it unblocks; a Story for the streaming endpoint and a Story for the admin Export button, each with happy, failure and observability scenarios |
| slugs | each matches `^[a-z0-9][a-z0-9-]*$`; none is `index` |
| `architecture.md` | header line `security_sensitive: yes` (personal data: `customer_email`; possibly a new third-party dependency); item 3 names the fixed port 4300 of `admin-ui` (127.0.0.1) and the CSV contract by pin; item 8 names the e2e gap (`e2e.harness: none`); item 13 blank |
| existing doc | `$X/repo/docs/architecture/orders.md` updated to the 6 statuses of `src/orders/status.json` (Rule 5, `config/CLAUDE.md:32`), or cited as stale with the update planned; not duplicated |
| `contracts/` | one owning file for the CSV columns (`order_id`, `status`, `placed_utc`, `customer_email`, `total_minor_units`); no draft restates the column list |
| `test-plan.md` | human hand-test rows post-merge for both Stories |
| `release-plan.md` | step table with unique `step_id`s; the production deploy step owner is `human` |
| `review-architecture.md` line 1 | `ARCH: ready`; body links `RUN_HOME/review-tailor-run-doc-1.md` and records rung 2b, 1 round, 0/0/1 |
| `h1-packet.md` | one page; no "Open findings" block; desk lines `GATE demo-1-20261102 H1 ok|changes|reject` |
| not written | no gate file, no Jira call, no port claim, no `security-audit/` directory |
