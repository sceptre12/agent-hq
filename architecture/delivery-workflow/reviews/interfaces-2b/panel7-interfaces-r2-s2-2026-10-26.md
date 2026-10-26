id | sev | artifact file:line | defect | source | fix
s2-1 | M | interfaces/part-d-enums-topics.md:40 | H1 verdict named ACCEPT/CHANGES/REJECT in D2.1 but ok/changes/reject in the GATE grammar and file suffixes | interfaces/part-b-desk.md:144; interfaces/part-a-state.md:95 | List the GATE tokens in D2.1 or state the mapping once
s2-2 | M | interfaces/part-b-desk.md:99 | B5 lists merge_reach and order as markers and says failure is REJECTED marker; B2.1 maps them to gate-missing and order | interfaces/part-b-desk.md:55, :52; INTERFACES.md:66 | Reword B5 closing clause; cite B2.1
s2-3 | M | interfaces/part-d-enums-topics.md:18 | review-tailor-<slug>.md (slug undefined) and drafts/index.md exist only in D1.1, not in A.6/D6; drafts/index.md collides with drafts/<slug>.md | interfaces/part-a-state.md:240; part-d-enums-topics.md:131,139 | Add to A.6 and D6, define slug, reserve index
s2-4 | M | interfaces/part-a-state.md:134 | sub-task branch has no name shape; only branch grammar is <JIRA-KEY>(-slug) | interfaces/part-b-desk.md:68; part-c-waves-control.md:30 | Define sub-task branch name and extend desk regex
s2-5 | L | interfaces/part-d-enums-topics.md:25 | RELEASE: token vs RELEASE <subtask> message | interfaces/part-c-waves-control.md:144 | Rename token
s2-6 | L | interfaces/part-d-enums-topics.md:79 | ci class token policy/flake vs desk reason policy | interfaces/part-b-desk.md:53 | Prefix or document
s2-7 | L | interfaces/part-d-enums-topics.md:77 | mode enum literal subtask|final vs placeholder <subtask|final> | interfaces/part-a-state.md:249 | Use <st-id|final>
s2-8 | L | interfaces/part-a-state.md:30 | all gate files said to be under RUN_HOME/gates/ vs H-e2e under <subtask>/gates/ | interfaces/part-a-state.md:42; part-d-enums-topics.md:137 | Say run-level only
s2-9 | L | interfaces/part-d-enums-topics.md:110 | {SESSION_ID} vs session_id | interfaces/part-c-waves-control.md:17 | Note alias
s2-10 | L | interfaces/part-a-state.md:170 | tier enum vs permission tier | interfaces/part-b-desk.md:12 | Name permission tier
totals 0/4/6
