# Fix r1: delivery-architecture (W1 item 15, 2b), 2026-10-26

Fixer: Opus, non-author. Input: panel7-delivery-architecture-r1-2026-10-26.md (B/M rows R1-1..R1-18, PR2-C2, PR2-C5) plus the orchestrator course correction to INTERFACES 1.4.0 (AM-4; rows AM4-a..e). L rows R1-19..R1-31 not touched, except where noted. Paths are under skills/delivery-architecture/; templates/ untouched.

| finding id | file:line changed | change (one clause) | status |
|---|---|---|---|
| R1-1 | SKILL.md:15,26; references/step0-inputs.md:29-30; review-handoff.md:17; fixtures/README.md:12,22; fixtures/run-home-stubs/state.md (new) | Step 0 reads `RUN_HOME/state.md` `orchestrator_tier` (A.2 :59; missing is `INPUT-ERROR orchestrator_tier missing`); step 10 and the hand-off table pass `ORCHESTRATOR_TIER`; fixture gets a state.md stub so the dry run still passes Step 0 | fixed |
| R1-2 | SKILL.md:15,26; step0-inputs.md:30; review-handoff.md:16; security-sensitive.md:36 | `SECURITY_AUDIT` = `state.md` `security_audit` unchanged (`guidance` when absent, A.2 :71); "says full" wording dropped; never derived from own line | fixed |
| R1-3 | security-sensitive.md:3,17-31; SKILL.md:21 | OQ-1 list stated as the rule (owner-decisions.md:88-89); session/token and credential sources marked skill defaults that only add an audit; `plan-check default` kept in a history clause | fixed |
| R1-4 | tree-rules.md:12-17 (§Item 5), K6 | item 5 uses the template columns; st0 (slug `-`), `st<N>` build rows, Epic/Spike/split rows with `-`; K6 compares the ticket-slug column to draft stems | fixed |
| R1-5 | SKILL.md:20; contracts.md:12,26; tree-rules.md K14 | item 3 contract sub-table `contract | owner path | consumers` under the template table, ports as rows; K14 and contracts check 1 keyed on its owner-path column | fixed |
| R1-6 | SKILL.md:20,60; tree-rules.md K15 | item 7 carries lanes, shared-file owners, no-parallel units, ports as cites to item 3 rows; new check K15 | fixed |
| R1-7 | SKILL.md:22 | A3 `sub-task` = item 5 id, `unit slug` = draft slug; batched `st<N>:` list written at v0, final before H-e2e | fixed |
| R1-8 | SKILL.md:18; decomposer-brief.md:7; tree-rules.md:31 | e2e `new|updated|none` + reason in all three | fixed |
| R1-9 | SKILL.md:18,24; decomposer-brief.md:6-7; contracts.md:27,35 | step-3 drafts carry `PIN-TBD:<contract name>`; step 8 mandatory on first pass; no-placeholder check (contracts check 4, K14) | fixed |
| R1-10 | tree-rules.md K9, §Draft headings | required `##` headings per issuetype and order; Agent fields last on every non-Epic draft (default); `#`/`###` lines ignored | fixed |
| R1-11 | SKILL.md:15,23; step0-inputs.md:22; tree-rules.md K12 | `release_tags.*` read optionally; tag step only with `used: "yes"`, tag matches pattern; step_ids kept on re-entry | fixed |
| R1-12 | SKILL.md:27-28; tree-rules.md:56; review-handoff.md:38-40,61 | K1-K15 run in the G48 pre-round slot (before round 1, after every fix), so every K fix is reviewed (D1); step 12 only re-runs and pastes; a final failure is an open finding, never an unreviewed fix | fixed (reading per orchestrator rule; "final failure = open finding" is a skill default, not an owner decision) |
| R1-13 | SKILL.md:15,30; step0-inputs.md:41-47 (§Re-entry) | re-entry renames old record and packet to `<name>.<yyyymmddThhmmssZ>` first, deletes removed nodes' drafts, restarts the round counter, `note <k>` lines | fixed |
| R1-14 | SKILL.md:30; h1-packet.md:7,33-44 | one row per file, absolute path + sha256; 60-line cap excludes the table rows | fixed |
| R1-15 | SKILL.md:16,26,30; review-handoff.md:11; h1-packet.md | updated existing docs go into ARTIFACTS and the packet table | fixed |
| R1-16 | SKILL.md:27; review-handoff.md:36; architect-brief.md:11 | orchestrator only at 2b/4; at 1-2 the architect dispatches G48 checker, reviewer, non-author fixer, fix-verifier | fixed |
| R1-17 | SKILL.md:27; review-handoff.md:61; h1-packet.md:26-27 | no fix after round-3 NOT MET; open findings = that synthesizer's B/M rows as-is; packet hashes the reviewed artifacts; Low pass + verifier after 0B/0M | fixed |
| R1-18 | SKILL.md:26; review-handoff.md:25 | below-floor: no override, no run; print `RUNG below card-3 floor: <rung> < <floor>` as last stdout line, write no record or packet, stop; conductor decides. No INTERFACES token or ESCALATE form fits (D1.1, D4 searched): stated as a skill default. The synthesis "run the floor rung" direction is refused per the orchestrator reading rule | fixed (orchestrator reading) |
| PR2-C2 | all references/*.md:3 (+ security-sensitive.md:15) | `INTERFACES 1.1.0` replaced by `INTERFACES 1.4.0 (architecture/delivery-workflow/INTERFACES.md:3)` with part path:line ranges | fixed |
| PR2-C5 | SKILL.md:39 | publication red flag anchored to A.2.1 Enforcement `interfaces/part-a-state.md:104` and `RUN_HOME/gates/H1.ok` | fixed |
| AM4-a | step0-inputs.md:3,5,19 | D1 reason `sha` added: blob-id mismatch with unreadable pinned blob is `INPUT-ERROR REPO_PROFILE sha` (A.2 :64 cat-file fallback kept); an INPUT-ERROR is neither a D7 round nor a fix-verifier iteration (also review-handoff.md:25 for review-tailor) | fixed |
| AM4-b | SKILL.md:18; decomposer-brief.md:7; tree-rules.md:42 | drafts carry team, priority, requested-by in the template's short body header under the unchanged 3-key front matter (part-d :110); B4 parent rule cited, not restated | fixed |
| AM4-c | review-handoff.md:25 | seat set stays fixed, profile-mandatory extra seat noted in `mechanism:` (D1.1 :19, RT-Q1); seat caps unchanged and consistent; no dispatch sum stated in the skill (the fixture stub's `dispatch: 11` line is L row R1-30, left for the Low pass) | fixed |
| AM4-d | none | STAKES/CONTENTION/NOVELTY "produced by the architecture handoff (D2.2 row 3 output -> row 5 input)": not found in 1.4.0 (row 3 outputs are `ARCH: ready`, `DRAFTS:`; row 5 inputs do not list them); kept as this skill's row 4 inputs to review-tailor | not found in 1.4.0 |
| AM4-e | SKILL.md:68; references/*.md | every version string now 1.4.0; anchors re-measured (A.2.1 :91-105, A.2.2 :106-155, A.5.2 :279-282, A.5.3 :283-286, A.6 :287-328, release_tags :132-136, D6 :134-162) | fixed |

Open (not invented): the D7 reading "after fix round 3" vs "no fix after a round-3 NOT MET" follows the orchestrator's binding rule, not a new owner decision. R1-30 touched only for the state.md stub R1-1 requires.

## Checks run
- `wc -w SKILL.md` 2718 (<=3500); `wc -l SKILL.md` 68 (<=500); references max 85 lines.
- Section count 5: ok. §9 grep tokens all present; `plan-check default` present in security-sensitive.md.
- Forbidden-list grep (outside templates/): clean. No symlinks. No `1.1.0`/`1.3.0` left outside templates/.
- `bash W/tools/check-doc-length.sh W`: 0 blocking files over 500 lines, exit 0.
