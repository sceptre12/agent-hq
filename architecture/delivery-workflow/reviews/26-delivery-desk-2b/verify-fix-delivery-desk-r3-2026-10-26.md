ISSUES_FOUND 0/0/2

Fix-verifier (Sonnet), round 3. Scope: R3-M1, R3-M2, verify-r2b L1; changed lines only. Paths relative to skills/delivery-desk/.

| id | sev | file:line | issue | source |
|---|---|---|---|---|
| V3-1 | L | references/checks.md:148-149; SKILL.md:66-67; references/verbs.md (branch-delete) | `branch-delete` "present = `git ls-remote` prints nothing" does not require exit 0. A failed ls-remote (network, auth) also prints nothing, so a crash-resume could write `DONE deleted=true` for a branch never deleted. Add "exit 0 and prints nothing"; any other exit continues at check 3. Narrow (crash + read failure), consequence is a leftover branch. | part-b:47 (read-back before acting again) |
| V3-2 | L | SKILL.md:65-67 | Step 5 omits the two gates checks.md item 1 imposes (desk copy `desk-inbox/<id>.req` exists, `target` verb equals line verb). An executor reading only SKILL.md would reconcile on any `.inflight`. Add "(desk copy exists, verb matches)". | SKILL.md vs checks.md agreement |

Verified:
- R3-M1 closed: one placement (step 5); replay of a stored `.out` still precedes it with no hash compare; `.inflight`/`target` semantics and fresh-id guard (item 3, step 12) unchanged; a never-acted `.inflight` (read-back absent, or no desk copy) continues at check 3 and runs 3-8; `.out` is written for every REJECTED incl. `action-failed`, so an `.inflight` without `.out` is only a stopped attempt. `.derived` written at step 9 before the act; SKILL, checks, verbs agree.
- R3-M2 closed: `cp -P` copy to `desk-inbox/<id>.attach/` (desk-owned 0700), non-regular copy = `repo` (covers a symlink swapped after the root check), classify, scan and upload on the copy only; grep shows no other read of `lanes/` after the copy; `attached[].path` stays the request path.
- verify-r2b L1 closed: checks.md Markers names the requester-host files, each compared to desk-derived `expect_head`/`<pr>`, refusal-only; matches part-b:83 push row; SKILL.md:106 consistent.
- `bash SCRATCH/s9-26.sh` from W: DESK-SCHEMAS-OK; check-doc-length.sh 0 blocking.
