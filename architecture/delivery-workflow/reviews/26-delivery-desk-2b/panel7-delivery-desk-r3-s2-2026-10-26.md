| id | sev | artifact file:line | defect | source file:line | fix |
|---|---|---|---|---|---|
| s2-1 | L | skills/delivery-desk/references/verbs.md:48-51 | `PREPR: PASS` evidence is read from `substate.md` (`prepr`/`head`) and `ci/<pr>.md` lines, both written by the requesting lead, not from the pre-pr-gate artifact `review/<subtask>/checklist-<subtask>.md` line 1 | architecture/delivery-workflow/interfaces/part-d-enums-topics.md:22; part-a-state.md:174-184 | Cross-check checklist line 1 `PREPR: PASS` (head from substate) or state the weaker source as an explicit DEFAULT (author) trust gap |

Perspective s2 otherwise clean: 12-check order and codes, replay before copy/hash, inflight + target + fresh-id guard, .out 0600 atomic incl. REJECTED (none for sender), class/resend rules, one-at-a-time with STATUS-only, 60 s push-spacing slices, AM-4 rows (push first/later at check 8 `marker`, jira-create parent at check 5 `schema`, grant gate in human lines, default_branch `marker`) match part B.

totals 0/0/1
