# Wave 2 — second

- **goal:** Build one file per input, then a summary of the listed pair.
- **inputs:** `first_out` (Wave 1 output).
- **work_items:** one per file in `first_out`, plus the two listed below.
  - **a**
    - **persona:** `builder`
    - **depends_on:** `[]`
  - **b**
    - **persona:** `builder`
    - **depends_on:** `[a]`
- **agents:** one per work_item, model: sonnet.
- **exit_criteria:**
  - File `out/b.txt` exists.
- **outputs:** `second_out` — the files built.
