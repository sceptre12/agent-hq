# Wave 4 — build (DAG-frontier)

- **goal:** Build a small documentation site from the audited and fixed docs, with
  each piece released as soon as the pieces it needs have passed their own gate.
- **inputs:** `fixed_docs` (Wave 2 output); `target_dir` (caller-supplied).
- **work_items:** enumerated below (a wave with `depends_on` edges must list its work_items).
  - **index**
    - **persona:** `doc-builder`
    - **lane:** `writer-a`
    - **depends_on:** `[]`
    - **done_condition:** `{"token": "INDEX-OK", "command": "bash checks/index.sh"}`
  - **toc**
    - **persona:** `doc-builder`
    - **lane:** `writer-a`
    - **depends_on:** `[]`
    - **done_condition:** `{"token": "TOC-OK", "command": "bash checks/toc.sh"}`
  - **site**
    - **persona:** `doc-builder`
    - **lane:** `writer-b`
    - **depends_on:** `[index, toc]`
    - **done_condition:** `{"token": "SITE-OK", "command": "bash checks/site.sh"}`
  - **release-note**
    - **persona:** `doc-builder`
    - **lane:** `writer-b`
    - **depends_on:** `[site]`
    - **done_condition:** `{"token": "NOTE-OK", "command": "bash checks/note.sh"}`
- **agents:** one per work_item, model: sonnet.
- **gate_type:** `step_complete` (one gate agent per work_item; each walks that
  work_item's `done_condition` plus `exit_criteria`, read against that work_item's
  output only).
- **fix_loop_cap:** 2 (per work_item in a frontier wave)
- **exit_criteria:**
  - The work_item's own file under `target_dir/site/` exists and is non-empty.
  - The work_item's `done_condition` command exits 0 and its last stdout line equals its token.
- **outputs:** `docs_site` — the paths of the files built under `target_dir/site/`.

`index` and `toc` share lane `writer-a`, so one waits for the other even though
neither has an edge; `site` is released only after both pass their gates, and
`release-note` only after `site`. If `site` exhausts its fix loop, `release-note`
is never released and `index` and `toc` keep their passes.
