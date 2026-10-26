# Fix record r4-0 (owner rulings INTERFACES 2b, N10 and N11; preround r3d C5), 2026-10-26

Scope: owner rulings at `architecture/delivery-workflow-sources/owner-decisions.md:78-84`; the 3 C5 fails of `preround-interfaces-r3d-2026-10-26.md`. Freeze-status line (INTERFACES.md:3) untouched. No git commands run.

| id | file:line | change | source |
|---|---|---|---|
| N10-a | INTERFACES.md:29 | N10 settled ("N10 (settled, owner 2026-10-26, `owner-decisions.md:80`)"); verbatim owner quote; inline, never exported, no `--no-verify`, GATE-PASS gates push; commits outside a desk push keep D21 (DEFAULT (integrator) reading, owner question if wider); H36 first-push signal moot; options/recommendation removed | owner-decisions.md:80 |
| N10-b | INTERFACES.md:102 | decisions-log row A.7 now Kind O (row O-N10; was DEF) | owner-decisions.md:80 |
| N10-c | INTERFACES.md:170, :192 | new row O-N10 in "Owner rulings of 2026-10-26"; heading now retires N1-N11 | owner-decisions.md:80 |
| N10-d | interfaces/part-a-state.md:290 | A.7 statement: HUSKY=0 on every desk push (verbatim quote), inline only; non-desk commits per D21 as written (quoted); per-push recorded pass (verbatim quote); "open owner note N10" pointer removed | owner-decisions.md:28, :37, :80 |
| N10-e | interfaces/part-b-desk.md:73 | `push` row: `HUSKY=0` inline on every push (verbatim quote, A.7 link) | owner-decisions.md:80 |
| N11-a | INTERFACES.md:31 | N11 settled; verbatim quote segments; DEFAULT (integrator) forms named; options (a)/(b) and recommendation removed | owner-decisions.md:81-84 |
| N11-b | INTERFACES.md:193, :197-201 | row O-N11; new table "Decisions added by the round-4-0 fix", row R40-1 (DEF) | owner-decisions.md:81-84; DEFAULT (integrator) |
| N11-c | interfaces/part-a-state.md:113-117 | A.2.2 keys `release_tags.used` `yes\|no`, `release_tags.pattern` anchored regex (push rule), `release_tags.approval` `none\|human`; missing entry = `REJECTED policy`, not INPUT-ERROR | DEFAULT (integrator) on owner ruling :84 |
| N11-d | interfaces/part-a-state.md:99, :101 | H-prod gate also serves `tag-push` under `approval: human`; enforcement sentence | DEFAULT (integrator) |
| N11-e | interfaces/part-b-desk.md:86 | `tag-push` row: `{repo, tag, sha, step_id}`; desk reads profile `release_tags.*`, `REJECTED policy` (terminal) when absent / `used: no` / pattern miss; `human` needs `H-prod.<step_id>.ok` else `gate-missing` | owner-decisions.md:82-84; DEFAULT (integrator) |
| N11-f | interfaces/part-b-desk.md:54, :56, :63, :160 | B2.1 `policy` and `gate-missing` triggers; B3 steps 6 and 8; B8 H-prod row | DEFAULT (integrator) |
| C5-1 | INTERFACES.md:29 | D21 paraphrase replaced by verbatim quote; remaining rule sentences tagged default / question | preround r3d C5 |
| C5-2 | INTERFACES.md:31 | D15 paraphrase removed; verbatim quotes and DEFAULT (integrator) tags | preround r3d C5 |
| C5-3 | interfaces/part-c-waves-control.md:52 | sentence now quotes part-03:35 and owner-decisions.md:7 verbatim; rule set 1-11, 13-15 tagged DEFAULT (integrator) | preround r3d C5 |
| C1 | INTERFACES.md:5, :27 | Authority cite `:1-84` adds 2b answers `:78-84`; "Two open owner notes" -> "No owner note remains open" (rows O-N10, O-N11) | owner-decisions.md:78-84 |

Note: the ruling does not name commits made outside a desk push; they keep D21 as written (hooks run), labelled `DEFAULT (integrator)` reading and an owner question if wider. `step_id` on `tag-push` is a new required field (DEFAULT); C5.1 `CONDUCTOR-REQUEST` carries B4 fields, so it follows without edit.

Doc-length: `bash tools/check-doc-length.sh <W>`: 0 blocking files over 500 lines; 2 informational over 40000 bytes (changelog.md 44874, interfaces/part-a-state.md 44432 bytes / 303 lines), non-blocking.
