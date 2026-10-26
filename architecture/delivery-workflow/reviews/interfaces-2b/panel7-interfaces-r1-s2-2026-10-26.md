# panel7 interfaces R1 seat s2 (one name per thing)

id | sev | artifact file:line | defect | source | fix
s2-1 | M | part-b-desk.md:69,70,107 | `run_id` = GitHub Actions run in ci-logs/ci-rerun, but = delivery run in state.md and catalog col 2 | part-a-state.md:54,172 | rename CI fields `ci_run_id`
s2-2 | M | part-a-state.md:70 (:23,:159) | subtasks[].session / machine `<session-id>` (s-a1, s-a0) vs substate `session_id` = `<run-id>-<subtask>`: one word, two shapes | part-a-state.md:113; part-d:35 | name the machine key and say what subtasks[].session is
s2-3 | M | part-a-state.md:123; part-d:97 | bus.endpoint `topic=` value undefined; same literal is bundle `output_topic` | part-c:18,20; part-d:84 | state topic= equals output_topic, source of truth is the bundle
s2-4 | M | part-d:67 | `dispatch_budget` never defined/mapped in C1; competes with `budget`, `budget_min`, `spawns` | part-c:32; part-02-skill-inventory.md:84 | add a C1.1 row with value rule
s2-5 | L | part-b-desk.md:75 | `step_id` / `H-prod.<step_id>.ok` vs `<step-id>`; INTERFACES.md C3 row reuses `<step-id>` for NEXT step n | part-a:88; part-b:138; INTERFACES.md:68 | one spelling
s2-6 | L | part-a-state.md:15 | compact timestamp "only inside desk ids" but also row_id and inbox names | part-a:174; part-c:103 | widen rule
s2-7 | L | part-d:34 | conductor-message enum omits `INBOX <subtask>` and `NUDGE` | part-c:110,146 | add to D2.1
s2-8 | L | part-c:128 | `RELEASE <subtask>` vs `RELEASE: LIVE...` token, plus `released` states | part-d:57 | rename or anchor regexes
s2-9 | L | part-d:76 | "six events" then seven tokens | INTERFACES.md:75 | say seven
s2-10 | L | part-a-state.md:112 | sub-task id spelled `id`, `subtask_id`, `subtask` | part-a:69,173; part-b:51 | one name or mapping note

totals 0/4/6
