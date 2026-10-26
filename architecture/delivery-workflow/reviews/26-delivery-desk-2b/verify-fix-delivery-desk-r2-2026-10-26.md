CLEAN

Fix-verifier (Sonnet, not the fixer), round 2, 26 delivery-desk. B 0 / M 0; two new Lows (informational, do not change the verdict).

## Closure (current text)
| id | sev | status | evidence | source |
|---|---|---|---|---|
| r2-1 | M | closed | verbs.md:21-28 Repository binding; every `gh pr/run` act in verbs.md (:57,96,119,128-129,140) and checks.md:105 carries `--repo=<gh-repo>`; `gh api` uses `repos/<gh-repo>/...` (valid syntax; `gh api` takes no `--repo`). `<gh-repo>` comes only from `git -C <repo> remote get-url origin` of the realpath'd registered clone, so no request value picks it; unparsable = `repo` | part-b:14,106 |
| r2-2 | M | closed | SKILL.md:65-67,131-134; checks.md §Inflight item 0: only STATUS served during wait/act, others queued until `.out`. STATUS is still answered within 2 min (slices <=60 s); replay (step 5) and `.inflight` reconcile now only meet handler-less attempts; "takes other lines" removed | part-b:47,22; pt-02:100-101 |
| r2-3 | M | closed | schemas.json:83-87 `envelope.verb` pattern `^[a-z-]+$`, no enum; python3 -I jsonschema probe: REJECTED `.out` verb `approve` ok, `Approve!` rejected, `push.result` rejects DONE verb `approve`, all 20 `verbs.*.result` reject DONE verb `approve`, DONE with result fields fails envelope (additionalProperties false) | part-b:116 |
| r2-5, r2-7, r2-11, r2-12, r2-17, r2-21, r2-22 | L | closed | verbs.md:23-24; SKILL.md:88/checks.md:53; SKILL.md:154-156,205-206 (scope push, branch-delete, tag-push, PR creation, A.7 link; verbs.md:45-46,107,160); SKILL.md:84-85/checks.md:59-61; SKILL.md:69-70/checks.md:28; checks.md:30 and SKILL.md:81 (ref, base, merged_into, tag, package); SKILL.md:122 | part-b:73,146; part-a:115,325-342 |

## Regression hunt
1. Body shrink: reason-code table, resend rule and sender-side paragraph moved intact to checks.md §Reason codes / §Requester-side (10 codes, classes, steps, OP5 B quotes present); verb table is replaced by the closed list of 20 plus conductor-only set, all columns exist in verbs.md; 14 red-flag rows, 7 exit criteria, Step 0 INPUT-ERROR, Provenance all present. Only loss: see V2-1.
2. `--repo` derivation: ok (above); all `gh` lines in verbs.md/checks.md carry it.
3. One-at-a-time: ok, BUSY rule, replay order and reconcile consistent (checks.md §Inflight 0-1, SKILL step 5, 15).
4. python3 -I probe: DONE `.out` with a non-B4 verb fails every `verbs.<v>.result`; see V2-2 for the bare-envelope gap.
5. `bash SCRATCH/s9-26.sh`: DESK-SCHEMAS-OK; check 2 (HUSKY=0, GATE-PASS, release_tags, record_path, pr-attach) no RULE-MISSING; check-doc-length 0 blocking; SKILL.md 2,792 words.
6. Spec §8 items present (Red flags, Step 0 INPUT-ERROR, Provenance).

## New Lows
| id | sev | file:line | issue | source |
|---|---|---|---|---|
| V2-1 | L | SKILL.md:154-156, 205-206 | The r2-11 rewrite dropped "never `--no-verify`" and "inline per-command, never exported" from the HUSKY bullet and exit criterion; the only remaining `--no-verify` text is verbs.md:46 (push). A.7 states both, and SKILL "Never: force-push or pass a raw flag" covers it, but the desk-wide ban is no longer stated on pr-create/branch-delete/tag-push. Add "no `--no-verify`" back to the exit criterion | part-a:333 |
| V2-2 | L | schemas.json `envelope.allOf` | Loosened `verb` has no `if status DONE then verb enum(20)`: a bare DONE envelope (no result fields) with verb `approve` passes `envelope` alone. Not reachable if DONE `.out` are validated against `verbs.<verb>.result` (all reject it), as SKILL exit criterion says. Optional hardening: add the `then` verb enum for DONE | part-b:116 |
