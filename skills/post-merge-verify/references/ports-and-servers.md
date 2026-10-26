# Ports and launched servers (post-merge-verify)

Single statement of the rule: INTERFACES part-a A.5.2 (amendment AM-1, AM-3 owner OQ-2). This file applies it to the `pm` lead; it does not restate it differently.

## Candidate
- Lane-less rows: a row with lane `-` or empty that starts a server or names a port has no candidate (the table keys by `lane/<name>`) and no lease; it is not run: stop and report to the `pm` lead (A.5.2 scope "every port a run binds"; open author question).
- Source: the `PLANS_DIR/dispatch-plan.md` port table, rows with role `lane/<name>` (`base_key` `ports.lane_base`, `candidate = <base> + 10*k`, `k` the lane index; fixed app ports keep `k = 0`). Lane leases are run-wide, so the `pm` lead reuses the lane's candidate (`skills/delivery-dispatch-plan/references/shared-files-and-parallelism.md`, lane `k` rule).
- No row for a bind, or a `FILL_IN_BEFORE_DISPATCH` candidate: stop and report to the `pm` lead. Never compute or pick a number yourself.

## Order per candidate
Precondition: the lane's `lane-lease` is already held by you (SKILL.md Step 3); never claim or launch for a lane whose lease was refused.
1. `tools/port-check.sh --claim <port> <bind> <container_port> <service> <run-id> claimed <run-id>-pm <note>` through the `port-claim` skill (`-` for an empty `container_port` or `note`).
2. Exit 0: go to 4.
3. Exit 1 (taken) or 2 (registry and `lsof` disagree), first refusal: do not launch. Claim candidate + 10 with the same call, before any bind. Exit 0: go to 4 with that port. Refused again: stop the line, report to the `pm` lead with C2 reason `lane-unavailable`. Never a second +10. Exit 3 at either claim: stop the line.
4. `catalog.sh register port <claimed-port> - run post-merge-verify pm <agent_id>` (`planned`).
5. Register a long-lived server you launch (below), launch it bound to `<claimed-port>`, then `catalog.sh start port <claimed-port>` and `catalog.sh start pm2-app <name>`. A server the row's own command starts gets no row before the run; it is handled after the row (below). A failed launch: `catalog.sh fail port <claimed-port>` and `catalog.sh fail pm2-app <name>`, then stop and report to the `pm` lead (no `planned` row left).

## Server registration (A.5.1: cleanup stops only `process` and `pm2-app` rows; the `port` row is released after the listener is stopped)
- A long-lived server you launch yourself runs as a pm2 app named `<run-id>-pm-<lane-name>` (A.1 namespacing): `catalog.sh register pm2-app <run-id>-pm-<lane-name> - run post-merge-verify pm <agent_id>` before launch, `catalog.sh start pm2-app <name>` after.
- A server the row's own command starts (for example a test runner's web server) ends with the row. After the row, check `lsof -nP -iTCP:<port> -sTCP:LISTEN`: a listener still there gets `catalog.sh register process <pid> - run post-merge-verify pm <agent_id>` then `catalog.sh start process <pid>`, so `delivery-cleanup` can stop it. Never kill it yourself.
- Release of `port`, `pm2-app` and `process` rows is `delivery-cleanup`'s, never this skill's.
