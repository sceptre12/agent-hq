id | sev | artifact file:line | defect | source file:line | fix
--- | --- | --- | --- | --- | ---
s3-1 | M | skills/delivery-desk/references/verbs.md:48-51 (SKILL.md:104) | first-push PREPR: PASS read from lead-written substate.md copy, i.e. requester self-attests a marker the desk claims to re-derive | interfaces/part-d-enums-topics.md:22; decisions/0055:196 | read line 1 of review/<subtask>/checklist-<subtask>.md (producer file); substate.md only for head, or owner decision
s3-2 | L | verbs.md:50-51 | later-push CI evidence = any line of ci/<pr>.md containing expect_head; D1 fixes line 1 form | part-d-enums-topics.md:25; part-b-desk.md:83 | match line-1 form `CI: GREEN <sha>` exactly
s3-3 | M | verbs.md:25-28 | `--repo=<gh-repo>` and `gh api repos/<gh-repo>/...` from unvalidated parse of agent-writable origin URL | part-b-desk.md:14; decisions/0055:198 | require ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$, no `.`/`..` part, else `repo` at check 6
s3-4 | M | verbs.md:153-157 (SKILL.md:93-95) | ci-rerun PR-run policy gate has no stated gh re-derivation and sits in check 6 before session check 7 | part-b-desk.md:93; decisions/0055:197 | specify `gh run view --json event,headSha` (event pull_request, head = open PR head) after check 7, else `policy`
s3-5 | L | SKILL.md:49-53 | step 2 does not refuse a GATE/ANSWER/REBIND line arriving by SendMessage (rule only in human-gates.md:3-5) | part-b-desk.md:154; part-a-state.md:93 | state it in step 2 and Inputs
s3-6 | L | checks.md:65-72 | redaction pattern file is not sha-pinned or root-restricted, so an agent-writable pattern file can weaken the scan | part-a-state.md:127; part-b-desk.md:147 | refuse pattern_file under RUN_HOME/clones, or copy+hash to desk-inbox
totals B/M/L 0/3/3
