# Wave 2 — second

- **goal:** Build one file per input.
- **inputs:** `first_out` (Wave 1 output).
- **work_items:** one per file in `first_out`.
- **depends_on:** `[one]`
- **agents:** one per work_item, model: sonnet.
- **exit_criteria:**
  - File `out/b.txt` exists.
- **outputs:** `second_out` — the files built.
