# panel7 r2 s4: marker re-derivation (B5), human gates (B8), redaction (B7)

Checked and found matching part B: B5 marker set and order, review-record lines, H-pr read-back, CI aggregate, content-merged on desk-fetched refs; B8 regexes, gate x verdict matrix, A.2.1 file names, desk-only writer, H-prod for publish and tag-push; B7 fail-closed scan, image by content type, traces scanned.

| id | sev | artifact file:line | defect | source file:line | fix |
|---|---|---|---|---|---|
| s4-1 | L | SKILL.md:109; references/checks.md:106 | `<remote>` never defined; the ref content-merged compares against is operator-chosen | interfaces/part-b-desk.md:110 | name the remote in checks.md Markers |
| s4-2 | L | SKILL.md:83-85; references/checks.md:63 | repo-less verbs (jira-*, test-report-push) have no stated profile for `secrets.pattern_file` | interfaces/part-b-desk.md:146; part-a-state.md:132 | say repo-less verbs use the primary profile |
| s4-3 | L | references/verbs.md:48,63,86; checks.md:99,102,104 | `gh` calls have no repo selector, unlike `git -C <repo>`; the registered-clone check does not bind gh's target | interfaces/part-b-desk.md:14 | use `gh -R` or run from the checked `<repo>` |

totals 0/0/3
