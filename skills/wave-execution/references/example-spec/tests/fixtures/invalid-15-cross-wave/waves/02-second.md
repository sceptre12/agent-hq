# Wave 2 — second (frontier)

- **goal:** Build b after a.
- **inputs:** `first_out` (Wave 1 output).
- **work_items:** enumerated below.
  - **a**
    - **persona:** `builder`
    - **lane:** `lane-a`
    - **depends_on:** `[]`
    - **done_condition:** `{"token": "A-OK", "command": "bash checks/a.sh"}`
  - **b**
    - **persona:** `builder`
    - **lane:** `lane-b`
    - **depends_on:** `[one]`
    - **done_condition:** `{"token": "B-OK", "command": "bash checks/b.sh"}`
- **agents:** one per work_item, model: sonnet.
- **gate_type:** `step_complete`
- **fix_loop_cap:** 2

- **exit_criteria:**
  - File `out/b.txt` exists.
- **outputs:** `second_out` — the files built.
