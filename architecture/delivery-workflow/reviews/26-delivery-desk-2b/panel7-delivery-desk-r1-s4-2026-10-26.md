# panel7 delivery-desk r1 s4 (marker re-derivation, human gates, redaction)

id | sev | artifact file:line | defect | source file:line | fix
---|---|---|---|---|---
s4-1 | M | skills/delivery-desk/references/checks.md:61-65 | Redaction is fail-open: an empty, missing or unreadable `secrets.pattern_file` (grep -f matches nothing; exit 2 not distinguished from 1) lets bodies, payloads, logs and attachments pass unscanned | architecture/delivery-workflow/interfaces/part-b-desk.md:147; part-a-state.md:125 | Refuse (policy, detail names the file) on an absent, unreadable or empty pattern file or any grep exit other than 0/1 |
s4-2 | M | skills/delivery-desk/references/checks.md:66-67 | Images exempted from the scan by file extension only; a text file renamed .png is attached unscanned | architecture/delivery-workflow/interfaces/part-b-desk.md:147 | Classify images by content (magic bytes), scan everything else |
s4-3 | M | skills/delivery-desk/references/schemas.json:10,19,20; verbs.md:25,88,135 | git_ref, tag, package patterns allow a leading `-` and act commands pass them with no `--`, so a raw flag is reachable | architecture/delivery-workflow/interfaces/part-b-desk.md:79; decisions/0055-desk-verb-permission-tiers-02.md:103,198 | Reject leading `-` as schema; put `--` before request-derived positionals |

totals 0/3/0
