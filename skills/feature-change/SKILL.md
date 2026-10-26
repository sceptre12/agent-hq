---
name: feature-change
description: Deterministic end-to-end workflow for a feature change, small change or bug fix in any repo — ticket, worktree, implement, tests, the repo's own gates, a distinct verifier, the review rung, integrate, cleanup, ledger. Use when asked to "make a feature change", "small change", "fix this bug in <repo>", or any single work unit that lands code in one repo. Not for multi-wave builds (wave-execution).
version: 1.1.0
---

## Trigger
Use for any single work unit that changes code in ONE repo: a feature, small change, or bug fix.
The orchestrator runs this skill and dispatches each step (Global Rule 2); every dispatch pins a
model and states a done condition plus a stop-on-anomaly clause (Rules 3-4). Multi-repo or
multi-wave work goes to `wave-execution`.
Inside a delivery run (`UNIT_MODE=team`) the same steps run with the `team:` markers below;
detail in `references/team-mode.md`.

## Inputs
- `REPO` absolute path of the repo's main checkout; `SLUG` kebab-case unit name (`<n>-<slug>`
  once a ticket number exists); `AC` the numbered acceptance items; `PROJECT` the ticket tracker's
  project/label option for this repo (an existing option, never a new one).
- Gates and integration route come from the Repo policy lookup below — never from this skill.
- `UNIT_MODE` (optional) `solo` (default, everything below as written) or `team` (one unit inside a
  delivery run; detail in `references/team-mode.md`). Any other value: print `INPUT-ERROR UNIT_MODE enum`, stop.
  Step 0 validates it before anything else.
- team: the brief also supplies `RUN_HOME`, `RUN_ID`, `SUBTASK`, `UNIT`, `AGENT_ID`, `REPO`, `SLUG`
  (ticket slug), `TASK_FILE`, `REPO_PROFILE`, `SUBTASK_BRANCH` as `NAME=value` (D2.3; names pending owner
  confirmation, `OQ-13-6`); Step 0 prints one
  `INPUT-ERROR <NAME> <missing|path|format>` line per failing field, then stops (table in
  `references/team-mode.md`). The branch is `<JIRA-KEY>-<slug>`.

## Repo policy lookup (Step 0 — before any edit)
Read, in this order, and stop at the first source that NAMES the gates and the route:
1. `<REPO>/CLAUDE.md` and `<REPO>/CONTRIBUTING.md`:
   `grep -n -i -E 'lint|test|typecheck|build|gate|merge|pull request|PR' <REPO>/CLAUDE.md <REPO>/CONTRIBUTING.md`
2. Project record: `grep -n -i -E 'gate|merge|PR flow|integration' $HOME/projects/agent-hq/projects/<slug>.md`
3. An owner ruling the dispatching plan cites (e.g. "lint + test + typecheck + build, then local
   merge + push main") or a repo ADR naming the flow.
4. None of the above names them → ask the owner ONE question (Rule 9: this skill never invents
   gates or a route).
Record `GATES=<exact commands>` and `ROUTE=<local-merge|pr>` with the source line cited.
Then run arrival duty (Rule 6): `git -C <REPO> status --porcelain` and
`git -C <REPO> log origin/main..main --oneline` — dirty or unpushed = fix-or-surface first
(local-only repos named by the project record: unpushed main is intentional, not an anomaly).
team: the lookup is replaced by the team input check: `GATES` = `gates.command` from `REPO_PROFILE`, `ROUTE` is moot;
arrival duty is surface-only (report the output, never fix or stop on the lead's checkout; `OQ-13-11`).

## Steps
1. **Ticket (idempotent).** Query the ticket tracker the
   dispatching plan names for exact `Name` + `Project`; a hit = reuse its number. Else create one
   with Name, Status `Backlog`, Project, Labels (existing options only), body `Do:` + `AC:`. Then
   set `Branch` to `<n>-<slug>`. No tracker named = skip and say so.
   team: skip this step, say "ticket owned by the conductor"; read the key from `RUN_HOME/tickets.tsv` (the desk read-back, A.6); key absent = `ESCALATE` `spec-gap`.
2. **Worktree (Rule 6).** `git -C <REPO> fetch origin` then
   `git -C <REPO> worktree add <REPO>-worktrees/<SLUG> -b wt/<SLUG> origin/main`
   (absolute target path — `git -C` with a relative path nests inside the repo). Never edit main.
   team: worktree `<worktree_base>/<run-id>-<subtask>-<unit>`, branch `<JIRA-KEY>-<slug>`; `catalog.sh register worktree`
   and `register branch` (inline `RUN_HOME` and `WORKTREE_BASE`) before the add, `start` both after; if the lead already
   added the worktree (Wave 0), register and create only the branch; if `$WT` is already on the branch (re-dispatch
   after `ROLLED`), add nothing and register only rows not `live`. Exact commands in `references/team-mode.md`.
   Write `NEXT: <unit>.<n>` per C3 (`<n>` from the `.tasks` §9 list, not these steps).
3. **Investigate, then implement.** Read the code paths the AC touch before editing. If the change
   needs a layer outside this repo (backend migration, another repo, prod config): STOP and hand
   back `HANDBACK: <layer> needed — <evidence file:line>`; do not reach across. Dispatch shape:
   `superpowers:subagent-driven-development` (fresh implementer, exact brief, no session history).
   team: confirm the Agent tool first (a unit at depth 1 dispatches its `review path` reviewer at depth 2; it dispatches no verifier); absent = a launcher defect: print `INPUT-ERROR tools` and stop, before any edit (INTERFACES 1.6.0 AM-6 C-5).
4. **Tests.** Follow `superpowers:test-driven-development`: a failing test per AC item first,
   watched fail, then pass. Adjust existing tests only where the AC change their expectation.
5. **Repo gates.** In the worktree run every command in `GATES`, each as its own call, capturing
   exit code and counts (e.g. `npm run lint`, `npm test`, `npx tsc --noEmit`, `npm run build`
   ONLY if those are what `GATES` names). Any non-zero exit = fix in the worktree, re-run all gates.
   Baseline pre-existing failures on `origin/main` first so they are not attributed to this change.
   team: run the checks locally while working; the engine's gate agent writes the record `gate-runs/<head>.md` after the post (Step 10).
6. **Distinct verifier (Rule 4).** A separate agent instance (never the implementer) re-runs
   `GATES` in the worktree and checks each AC item against the diff
   (`git -C <WT> diff origin/main...HEAD`), reporting `AC-n: MET|NOT MET <evidence>`. Brief it
   without expected values (external memory note `dont-seed-expected-values-in-briefs`). Per
   `superpowers:verification-before-completion`: no claim without fresh output.
   team: the distinct verifier is `wave-execution`'s per-work_item gate agent (INTERFACES 1.5.0 A.7); dispatch none.
7. **Review rung (Rule 12).** Pick from `tools/review-ladder.md`: small or
   mechanical diff = Rung 0 direct review by a distinct agent; substantial diff or any PR-flow repo
   = `pr-review` (Rung 3); agent-hq executable code = `pr-review` mandatory (Rule 10). Merge only at
   0 Blocking / 0 Medium; findings go reviewer → fixer → `fix-verifier`.
   team: the rung is the unit table's `review path`; at most 3 rounds (D7), then `ESCALATE` per the failure table.
8. **Integrate per `ROUTE`.**
   - local-merge: `git -C <REPO> fetch origin`, `git -C <REPO> merge --ff-only origin/main`,
     `git -C <REPO> merge --no-ff wt/<SLUG>`, re-run `GATES` on main, `git -C <REPO> push origin main`
     (skip the push for local-only repos).
   - pr: `git -C <WT> push -u origin wt/<SLUG>` then `gh pr create`; integrate as the repo's flow says.
     Never merge an agent-hq PR on GitHub (Rule 10).
   - Merge conflict = stop and report; never resolve by guessing.
   team: skip integration (the Integrator persona owns the sub-task branch); no push.
9. **Cleanup (Rule 6).** Guards: `git -C <WT> status --porcelain` empty and
   `git -C <REPO> merge-base --is-ancestor wt/<SLUG> origin/main` exit 0 (PR route: after merge).
   Then `git -C <REPO> worktree remove <WT>`. KEEP the branch (external memory note
   `cleanup-worktrees-keep-branches`). Never `rm -rf` a worktree.
   team: skip cleanup (`delivery-cleanup` owns it).
10. **Record.** Append one row to the ledger the dispatching plan names (merge sha, gate counts,
    verifier verdict, review rung); no plan ledger = skip and say so. Update the ticket: Status to
    the tracker's existing done option (`Done`) and a comment with the merge sha / PR URL.
    team: skip the ledger row and ticket update (the lead owns the record); instead run the ordered Unit end of
    `references/team-mode.md`: commit, review, read `head` (never write, request or wait for `GATE-PASS`: the engine's gate
    agent writes `gate-runs/<head>.md` for that head after the post, A.7), then post the `UNIT-VERDICT` JSON with the `swarm-communication` `broadcast` tool on
    `<run-id>-<subtask>-rendezvous` (coordinates from `bus.endpoint`), or write `status/<agent-id>.verdict` if the bus is unreachable.
    Verdict and reason come only from the failure table there (C2 pairs).
11. **No scope creep.** Defects found outside the AC are NAMED in the report and the ticket
    comment (or filed as new tickets per external memory note `defects-file-tickets-not-chat`), never fixed
    in this unit (external memory note `no-scope-creep`).

## Red flags
| Rationalization | What to do instead |
|---|---|
| "The repo obviously uses lint/test/build, I'll run those." | Gates come from the policy lookup with a cited line, or one owner question. Never assumed. |
| "It's a one-line change, I'll edit main directly." | Rule 6 has no exemptions. Worktree, always. |
| "The implementer already ran the gates green." | Step 6 needs a distinct instance re-running them. Author evidence is not verification. |
| "The backend just needs a tiny migration, I'll add it." | Out-of-scope layer = `HANDBACK`, not a reach-across. |
| "I noticed another bug next to this one, I'll fix it too." | Name it, ticket it, leave it. |
| "Small diff, but pr-review to be safe." | Rung follows the ladder: lowest rung covering the risk (Rule 12). |
| "The ticket probably doesn't exist yet, I'll just create it." | Query exact Name + Project first; duplicates are the failure mode. |
| "Merge is done, I'll delete the branch too." | Remove the worktree, keep the branch. |
| team: "I'll write GATE-PASS myself, the gates passed." | Never: the engine's gate agent writes `gate-runs/<head>.md` after your post (A.7). |
| team: "I'll merge or remove the worktree, it's done." | Integration and cleanup belong to the Integrator and `delivery-cleanup`. |
| team: "UNIT-VERDICT: {...} as text is fine." | Bare four-key JSON on the rendezvous topic, or the `.verdict` file. |
| team: "`ROLLED` with `spec-gap` is close enough." | `ROLLED` takes only `budget`, `lane-unavailable`, `env-bug`, `merge-conflict` (C2); use the failure table. |
| team: "The post answer was unclear, I'll send it again." | Never re-send; write the same record to the `.verdict` file (C4). |
| team: "The bus is down, I'll restart it." | Never; `delivery-run` is the only restarter (C1.1). Use the `.verdict` file. |
| team: "The worktree is left from my last attempt, I'll add it again." | Re-entry (Case C): add nothing, register only rows not `live`, continue from the commits. |

## Exit criteria
- [ ] `GATES` and `ROUTE` recorded with a cited source line or an owner answer.
- [ ] Ticket exists exactly once (query before create); `Branch` set.
- [ ] All work committed on `wt/<SLUG>` in `<REPO>-worktrees/<SLUG>`; main never authored on.
- [ ] Each AC item has a test, and every `GATES` command exits 0 in the worktree (counts recorded).
- [ ] A distinct verifier reported every AC item MET and re-ran `GATES`.
- [ ] Review rung named per the ladder; 0 Blocking / 0 Medium at merge.
- [ ] Integrated per `ROUTE`; `origin/main` (or the PR) contains the merge; `GATES` green after merge.
- [ ] Worktree removed, branch kept; ledger row written (or "no ledger" stated); ticket updated.
- [ ] Adjacent defects named, not fixed; any `HANDBACK` reported instead of worked around.
- [ ] team: `UNIT_MODE` and every brief field validated (no `INPUT-ERROR` line printed).
- [ ] team: `catalog.tsv` holds this unit's `branch` row (and its `worktree` row unless Wave 0 added it) in state `live`,
  unless the unit stopped before the add (key absent, catalog exit, failed add: rows `fail`ed or never registered).
- [ ] team: `status/<agent-id>.md` holds one line matching `^NEXT: (u[0-9]+)\.([0-9]+) .+$` once the worktree exists.
- [ ] team: `gate-runs/<head>.md` path and line 1 cited, or the record is not `PASS`.
- [ ] team: exactly one record posted (`status:"sent"`) or written to `.verdict` (none after an `INPUT-ERROR`), with a
  C2 verdict/reason pair and `head` per the failure table's `head` rule (the worktree's `HEAD` once it exists).
- [ ] team: no ticket, integrate, cleanup, push or ledger work done (`git -C <REPO> worktree list` still shows any worktree made).

## Provenance
Provenance: owner request, 2026-10-21 (verbatim): "For feature changes is there a skill surrounding
that work flow you just laid out so that process is deterministic as oppposed to having to be
remembered and thought through each time?" / "Have an agent build tht if thats not the case and
have hermes remember that". Example route ruling (owner, verbatim): "The agent merges to main
right now with the only gates being lint test and typecheck and build as long as that works it can
be merged to main and then pushed. Of course work is always done on worktrees". Composes, does not
duplicate: `superpowers:test-driven-development`, `superpowers:subagent-driven-development`,
`superpowers:verification-before-completion` (external plugin skills), `pr-review`, `fix-verifier`.
Lineage: hq skills/feature-change (authored in hq per ADR 0009).
Ported into agent-hq 2026-10-26 for the delivery workflow (design §7 item 8).
Extended 2026-10-26 for the delivery workflow (design §2.3): `UNIT_MODE=team`, detail in `references/team-mode.md`; no port bound (any dev server is claimed per A.5.2 via `port-claim`).
Friction (2026-10-26, item 13 review round 1): the first team text left the verdict/reason pairing, the bus
transport and the catalog values implicit; round 2 found no re-entry after `ROLLED` and no `head` for pre-worktree stops;
`references/team-mode.md` now states each with its INTERFACES anchor. Record:
`architecture/delivery-workflow/reviews/13-feature-change-rung1.md`.
