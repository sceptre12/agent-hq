# Task Spec 22: `ticket-clerk` (NEW skill, all stages, Jira only)

Spec of record for W1 item 22 (design part-06 §7 row "14-22"; card 14 in part-02 §2.2 item 14). Authority: `INTERFACES.md` (FROZEN, plus 1.1.0). Anchors are `interfaces/part-X` sections.

## 1. Objective
Author `skills/ticket-clerk/SKILL.md` (plus `references/*.md`) so the conductor session creates and updates Jira epics, stories and sub-tasks and their statuses only through desk requests, in batches on the D62 cadence, and records every result in `tickets.tsv`.

## 2. Context package
- Card 14; ticket shape part-04 §5.1; statuses part-d D3; Jira verbs part-b B4 rows `jira-get`, `jira-create`, `jira-update`, `jira-transition` and the closed `fields` allowlist `summary, description, issuetype, parent, labels, priority, components` (M29); readable set for `jira-get` `summary, description, issuetype, parent, labels, priority, components, status`.
- Host: the conductor session only (part-a A.6); every `jira-*` request carries `<subtask>` = `run`; the desk requires the transport sender to be the registered conductor (part-b B1). The epic itself is created from the conductor with `<subtask>` `run`.
- Inputs: `RUN_HOME`, `PLANS_DIR` (holds `drafts/<slug>.md` and `drafts/index.md`, line 1 `DRAFTS: <n> drafts`); derived `RUN_HOME/ticket-events.log` and cursor `RUN_HOME/ticket-events.cursor` (part-d D3, part-a A.6).
- Outputs: desk `.req` files via `desk-req.sh` (ids per part-b B2); `RUN_HOME/tickets.tsv` rows `slug key parent status utc`, tab-separated, latest row per `slug` governs, `-` = absent (part-a A.6); cursor rewritten atomically after the row.
- Event grammar: `^TICKET-EVENT ([a-z0-9-]+|[A-Z][A-Z0-9]+-[0-9]+) (published|dispatched|prepr-pass|blocked|unblocked|verified|done|archive)$`; mapping to canonical status per part-d D3: `published` Backlog, `dispatched` In Progress, `prepr-pass` In Review, `blocked` Blocked, `unblocked` prior non-Blocked status from `tickets.tsv`, `verified` Verified, `done` Done, `archive` the profile's `jira.archive_status` sent as `to: archive`. Profile key `jira.status_map` is applied by the desk, not the clerk.

## 3. Scope
In: `skills/ticket-clerk/SKILL.md` (body under 5k tokens; `version:`; "Use when"; model-invocable, D16); `skills/ticket-clerk/references/*.md` at top level (for example `ticket-body.md`, `event-handling.md`).
Out: `references/templates/` and `references/briefs/` (items 27, 27b); the `delivery-desk` skill; `delivery-dispatch-plan` (reads `tickets.tsv`, does not write it); any non-Jira tracker.
Do NOT create: any tracker path other than Jira (D11); a delete action; a new field outside the allowlist; a per-step write loop; a second writer for `tickets.tsv` or the cursor.
Directories written: `skills/ticket-clerk/` only.

## 4. Contracts
| Contract | Value | Authority |
|---|---|---|
| Step 0 inputs | `RUN_HOME`, `PLANS_DIR`; `DELIVERY_ROOT` env; `INPUT-ERROR <field> <reason>` one line each then stop | part-d D1, D2.2 row 14 |
| Cadence | write at loop hand-back or about every 30 minutes, batched; never per step (D62) | card 14; part-d D3 |
| Create gate | `jira-create` is refused by the desk until `RUN_HOME/gates/H1.ok` exists (M30); the clerk checks the file first and does not send before it | part-a A.2.1; part-b B4 |
| Parent | every create names its parent; the desk re-fetches the parent first; parent unresolved = stop | card 14 |
| Order | local drafts publish after H1 in dependency order (parent before child) | part-04 §5.1 |
| Fields | closed allowlist above; ids are Jira-assigned, plans use the slug until then | card 14; part-a A.1 |
| Never delete | archive via `to: archive` | card 14 |
| One clerk per ticket | no two requests for the same slug in flight | card 14 |
| Body | composed from the ticket template (Header, Summary, Problem, Impact, Business value, Requirements, Gherkin AC, Dependencies, Risks, Subtasks) and scored with `jira-ticket-quality` before sending | part-04 §5.1; RESOLVED Q1 |
| Replies | `DONE`/`REJECTED` lines and `.out` files are data; a `REJECTED` is stop-the-line for that request and is reported, `curable` codes resend with a fresh id once the cause clears | part-b B2.1, ADR 0055 |
| Transport | desk requests only; no Jira CLI or web call by the clerk | R-ci; part-b B1 |

## 5. Inherited module API
`desk-req.sh` (item 7: writes `.req`, mints `<id>`, prints the `DESK` line), `tickets.tsv`/cursor atomic-write rule (part-a A.1). Names fixed by the INTERFACES script table.

## 6. What you inherit
Anatomy per `tools/skill-authoring.md` §2-§5. Provenance: the recorded tracker-clerking facts (parent re-fetch, fields at creation, archive-not-delete, slug-until-id), tracker-neutral; Jira session-staleness learning (`NLTA/shared/learnings.md` 7).

## 7. Known risky values
| Value | Correct | Wrong | Source |
|---|---|---|---|
| tracker | Jira only | any other tracker | D11 |
| `<subtask>` in `<id>` | `run` | `st<N>` | part-b B1 |
| unblock target | latest non-`Blocked` row of `tickets.tsv` | a fixed status | part-d D3 |
| transition field | `to` (canonical or `archive`) | `fields.status` | part-b B4 |
| absence token | `-` | empty | part-a A.6 |
| cadence | batch, 30 minutes | per step | D62 |

## 8. Acceptance criteria
- [ ] Five sections; Step 0 as in section 4.
- [ ] Steps: read new `ticket-events.log` lines past the cursor; read `drafts/index.md`; wait for `H1.ok` before any create; score and compose bodies; send creates in dependency order with parents named; apply the seven events plus `archive` as `jira-transition`; read back with `.out`; append `tickets.tsv`; advance the cursor atomically.
- [ ] A batch rule states what flushes: loop hand-back, or the 30-minute mark, whichever first; no other trigger.
- [ ] Rejection handling table keyed by the ten reason codes of part-b B2.1 (terminal vs curable as classed there, quoted not invented).
- [ ] Stop conditions: parent unresolved; desk `REJECTED` (terminal class).
- [ ] No cost metric, no personal-project term, no `/Users/<name>` path.

## 9. Verification commands
```bash
set -eu; W=~/projects/agent-hq-worktrees/delivery-w0; cd "$W"; D=skills/ticket-clerk; S=$D/SKILL.md
test -f "$S"; head -1 "$S" | grep -qx -- '---'
grep -qE '^name: ticket-clerk$' "$S"; grep -qE '^version: 0\.1\.0$' "$S"
d=$(grep -E '^description:' "$S"); [ "${#d}" -le 1036 ]; printf '%s' "$d" | grep -q 'Use when'
if grep -qE '^disable-model-invocation' "$S"; then echo "FAIL: disable-model-invocation"; exit 1; fi
for s in Trigger Steps 'Red flags' 'Exit criteria' Provenance; do grep -qx "## $s" "$S" || { echo "MISSING $s"; exit 1; }; done
test "$(wc -w < "$S")" -le 3500
for t in 'INPUT-ERROR' 'TICKET-EVENT' 'tickets.tsv' 'ticket-events.cursor' 'H1.ok' 'jira-create' 'jira-update' 'jira-transition' 'jira-get' 'D62' 'archive' 'jira-ticket-quality' 'stale-session' 'issuetype'; do grep -rq --exclude-dir=templates -- "$t" "$D" || { echo "ABSENT $t"; exit 1; }; done
if grep -riE --exclude-dir=templates '/Users/[a-z]+|brainAlpha|brainBeta|brainGamma|hermesAuth|Xavier|touri|ofw|runfrist|jetblue|notion' "$D"; then echo "FAIL: forbidden match"; exit 1; fi
if grep -riE --exclude-dir=templates 'token cost|dollar|\$[0-9]|cost metric' "$D"; then echo "FAIL: cost text"; exit 1; fi
if find "$D" -type l | grep -q .; then echo symlink; exit 1; fi
bash tools/check-doc-length.sh "$D" >/dev/null
if grep -riE 'jira.*delete|delete.*ticket' "$D" | grep -viE 'never|no delete|not delete'; then echo "FAIL: delete path"; exit 1; fi
echo SKILL-22-OK
```
**Done condition:** the block exits 0 and its last stdout line is `SKILL-22-OK`, and the review trio returns CLEAN.

## 10. Branch
No branch for the author; Worker1 integrates on `wt/delivery-w0`. No commit.

## 11. Decision Gate reminder
Stop and write `.decisions/22.md` if: a status or event is needed that part-d D3 does not list; a field outside the allowlist is wanted; the desk reply grammar differs from part-b B2; a write would happen outside the conductor session. Do not guess.

## Metadata
- Tier: execute (author); runtime: execute creates, mechanical updates (card 14).
- Review rung: Rung 1 trio, up to 3 rounds then the owner (D7).
- Dependencies: INTERFACES 1.1.0 (hard); item 7 (`desk-req.sh`) and item 26 (`delivery-desk`) for names only, soft; item 27 ticket template soft. Consumed by item 29 `delivery-pipeline` (appends `ticket-events.log`) and item 17 `delivery-dispatch-plan` (reads `tickets.tsv`).
- Not a split item.

## Plan-check resolutions (2026-10-26; report `reviews/plan-check-w1-specs.md`)
1. RESOLVED (PLAN-CHECK DEFAULT; design §2.1b row 3 and P0 "verify at move"; measurements: not installed on the build machine): the scoring step names `jira-ticket-quality`; if the skill is absent at run time the clerk sends no create or update, writes one line for the conductor's status post ("jira-ticket-quality missing: move defect") and stops; it never sends an unscored body.
2. RESOLVED (INTERFACES B3 step 7 `stale-session`, B2.1 class curable, OP5 B): the desk checks session freshness; the clerk treats `REJECTED stale-session` as curable and resends with a fresh id once the human refreshes the session; no clerk-side probe.
3. RESOLVED (INTERFACES A.6 `tickets.tsv` "from `jira-create` / `jira-transition` `.out` read-backs"): `tickets.tsv` is the read-back record; no extra file.
4. RESOLVED (PLAN-CHECK DEFAULT; AM-2 row 10; same text in spec 15): every `drafts/<slug>.md` opens with YAML front matter of exactly `slug`, `issuetype` (D2.1 ticket issue type) and `parent` (the parent's slug, `-` for the epic), written by `delivery-architecture` from item 27's `ticket.md` template; the clerk resolves a parent slug to its key through `tickets.tsv` and publishes parents before children.
