# PR #9 port-guard: pr-review panel report (Phase B)

- PR: sceptre12/agent-hq #9 (port-clash guard: hook + port-check.sh + registries + settings wiring)
- Branch: wt/port-guard   Head: 074c09f (074c09ff940bdea1c0dd133e74595d1dfc33d4c8)   Base: c1ba30e
- Mode: local-diff (code read only via `git show 074c09f:<path>`; nothing written to the worktree)
- Panel: 7 seats (strategic-reviewer, integration-architect, platform-engineer, devops-engineer, security-engineer, fullstack-engineer, technical-writer) plus independent synthesizer
- Bus session: swarm-pr-review-20261026-718240f1 (topics pr-check-cold-read, pr-check-1..9 and all `-closed` topics read)
- Date: 2026-10-26
- Gates: gate1 7/7, gate2 7/7; timed_out_checks = { gate1: [], gate2: [] }

## 1. Severity summary

0 Blocking, 6 Medium, 8 Advisory (after merging 33 raw findings across 10 topics; duplicates merged, source ids listed).

## 2. Findings table

R = Responsible (raiser), A = Accountable (closer of the topic). C markers: ✓ VALIDATE, ⬆ ESCALATE, ↩ CHALLENGE, + ADD. No CHALLENGE was posted on any finding.

| # | Issue | Severity | Check | R | A | C Responses | Recommended Fix | Source ids |
|---|-------|----------|-------|---|---|-------------|-----------------|-----------|
| M1 | `port-check.sh` live-truth leg fails open: `if lsof_out=$(lsof ... 2>/dev/null)` (line 173) treats exit 127/exec/sandbox failure the same as exit 1 (no match), so a row-less port prints `RESULT: FREE`, exit 0, and `--claim` then registers it. `live_listen_ports` (line 148) swallows errors too (audit then shows every live row as GHOST, not clean). Contradicts the header "FAILS CLOSED" claim; no test covers lsof-absent. Hook impact nil (it discards the exit code and is fail-open by design). | Medium | pr-check-4/6/7 | devops, platform, fullstack | platform / devops / integration | platform ✓+, fullstack ✓+ (reproduced, refined audit effect), integration ⬆, devops ⬆, security ✓, tech-writer + | `command -v lsof \|\| exit 3` before check/claim/audit; treat only lsof exit 1 with empty output as "not listening", other codes exit 3; add an lsof-absent test | DEVOPS-1, FS-1, PLAT-4 |
| M2 | `--claim` can poison the shared registry: only port and status are validated; bind, container_port, service, project, source, note go into one TSV row unchecked. A tab/newline gives NF != 9 so `validate_rows` exits 3 for every reader machine-wide (including `--claim` that would repair it); an embedded newline can forge an extra row; non-numeric container_port accepted. | Medium | pr-check-6 | platform | devops | devops ✓, integration ✓, security + (raised to upper Medium), fullstack + (FS-4b) | Reject `[[:cntrl:]]` in every claim arg; require container_port `-` or port/range; require non-empty bind; add tests | PLAT-5, FS-4b |
| M3 | `architecture/port-registry.md` is truncated/incomplete: section 3 ends at "The argument, with evidence:" with no body; `## Source lineage` is an empty last heading; section 2 says nine columns but the table skips field 3 (`container_port`, which the code reads); section 2.1 says six enum values but defines five (`reserved` undefined) and has a garbled "The enum is closed" sentence. | Medium | pr-check-cold-read / pr-check-8 | integration, tech-writer | integration / fullstack | platform ✓, fullstack ✓, strategic ✓, integration ✓ | Restore or delete the section 3 body and the lineage heading; add the field-3 row and a `reserved` bullet; repair the 2.1 sentence | IA-1, TW-1, TW-2 |
| M4 | Doc claims behaviour the code does not have: (a) 200-active-row warning (doc lines 52/56) does not exist in the script; (b) section 5.1 says audit "walks every non-released row" / "Refresh verified" but `cmd_audit` classifies only `live` rows; (c) "the skill", its `## Red flags` table and the resource-catalog port row are cited but not in agent-hq; (d) script cites "SS8.6" which the doc lacks (section 8 item 2). | Medium | pr-check-2 / pr-check-8 | integration, tech-writer | platform / fullstack | devops ✓, fullstack ✓, platform +, security ✓, strategic +, integration ✓ | Implement the warn or mark it planned; reword 5.1 to match code; mark skill/catalog refs as not mirrored; fix SS8.6 | IA-3 (a,b), TW-3 |
| M5 | Sanitization and header contradiction in `tools/ports.tsv`: header says "Generic rows only ... work environment fills its own rows" but the two restored Hermes rows (11330 released, 8642 claimed) cite `~/claude-profiles/hermes/bin/H1-connect-log.py`, hq `plans/hermes-agent/evidence/H1-token-path.md`, LaunchAgent `local.hq.hermes-up`, ticket ids T-125/T-135/T-20261014-05 and a pid; system rows cite hq-only `raw-lsof.txt:N (PID n)`; the swarm row cites a nonexistent `.env.example`. Same hq-only pattern in `app-ports.tsv` header and `port-precheck.sh` line 4 (`plans/port-clash-precheck.md`). No secrets, tokens or personal-project content found. Source column is not parsed at runtime. | Medium | pr-check-1/3/9 | platform, integration, strategic | devops / platform / integration | devops ✓, integration + (consistency, not blocker), security + (no credentials), strategic +, tech-writer ✓+, fullstack ✓ | Keep 8642 (Hermes is agent-hq-owned) with an in-repo source (e.g. architecture/hermes-agent-ops.md or tools/hermes/...); drop the stale 11330 released row or cut its source/note to bare minimum; replace `raw-lsof.txt` cites with "lsof capture 2026-09-04"; strip ticket ids/pid/LaunchAgent label; fix the header; add the one-line hq-only provenance disclaimer to app-ports.tsv and the hook header. Owner may rule | PLAT-1, IA-4(1,3), STRAT-1, TW-4(c), TW-5, SEC-5, DEVOPS-4, STRAT-3 |
| M6 | Stale counts and false claims about this repo: hook header "all 19 rows in tools/ports.tsv (7 exit 2, 12 exit 1)" while the shipped file has 9 lines (7 data rows per tech-writer, 8 per strategic; seats disagree on the count); registry 7.1 "agent-hq / system - live" lists 1 row; app-ports.tsv says rows derive from P1 but ships zero; registry section 1 "verified by ls tools/" names two files absent from agent-hq. | Medium | pr-check-8 / cold-read / pr-check-3 | tech-writer, integration | fullstack / integration / platform | fullstack ✓, strategic ✓, integration ✓+, platform ✓ | Qualify figures as "hq measurement" or drop them (do not hard-code a count); update 7.1 or mark it illustrative; delete the ls-verified sentence | TW-4(a,b), IA-2, IA-4(2) |
| A1 | `--audit` with unusable TMPDIR: bare `mktemp` (line 240) under `set -e` exits 1 (= EXIT_TAKEN "findings"), not 3; test asserts only rc != 0. | Advisory | pr-check-7/2/4/5 | fullstack, devops, security | integration / devops | platform ✓ (Advisory), integration ✓ (Advisory to Medium), tech-writer ✓, fullstack ✓ | `AUDIT_TMP=$(mktemp ...) \|\| { echo FAIL >&2; return "${EXIT_ERROR}"; }`; assert rc==3 | FS-2, DEVOPS-2, SEC-4, IA-3(c) |
| A2 | Hook false negatives/positives on literal parsing: `-p 127.0.0.1:5000:80` captures 127 (reproduced, silent); `^docker` anchor misses `cd x && docker run`, `sudo docker`, `--publish`; `--port N`/`PORT=N` anywhere in command text (commit message, echo) with N listening prompts (5000/7000 always). Advisory control, so only "ask" is affected. | Advisory | pr-check-7/6 | fullstack, platform | integration / devops | platform ✓, tech-writer + (document limits), integration ✓, security + | Strip optional `host:` before host port; anchor on `(^\|[;&\|]\s*)`; add `--publish`; or add a "Known limits" comment | FS-3, PLAT-6(a,b) |
| A3 | `ask` from a PreToolUse hook in an unattended subagent/swarm run has no responder and can stall the worker. | Advisory | pr-check-6 | platform | devops | devops + (ops emphasis), security ✓, integration ✓ | Document it and the stall watchdog interplay | PLAT-6(c) |
| A4 | Hook header says non-zero exit blocks; only exit 2 blocks. Always-exit-0 design is sound; comment overstates. Crash paths (garbage jq output, unreadable cwd) untested. | Advisory | pr-check-6 | platform | devops | devops ✓, integration ✓, security ✓ | Reword comment to "exit 2 blocks, so never emit it"; optional tests | PLAT-7 |
| A5 | Hook and `app-ports.tsv` are inert until merge: settings.json points at the main checkout (`$HOME/projects/agent-hq/...`), and `app-ports.tsv` ships zero rows so only literal `--port`/`PORT=`/`docker -p` detection is live. A bad merge reaches every Bash call machine-wide; absent path gives non-blocking exit 127. | Advisory | pr-check-1/4/9 | platform, devops, strategic | devops / platform | devops +, integration ✓, security ✓, tech-writer ✓ | State in the PR description and registry doc; optional post-merge check | PLAT-2, DEVOPS-3, STRAT-2 (caveat), FS-4(d) |
| A6 | `PORT_PRECHECK_TABLE` / `PORT_PRECHECK_PORT_CHECK_SH` env overrides are honoured in production and the latter execs any `-x` path. Same trust as the env owner, not a privilege boundary. | Advisory | pr-check-1 | platform | devops | devops ✓, integration ✓, security + ("Advisory-plus") | Gate both behind one `PORT_PRECHECK_TEST=1` var, or document as supported | PLAT-3 |
| A7 | Minor robustness: IFS-tab collapses empty middle fields in table reads (empty `match_cmd` would match every command: latency only, bounded by 5s timeout); comments-only registry passes positive control as FREE; many `--port` tokens spawn one lsof each. | Advisory | pr-check-7/5 | fullstack, security | integration / platform | platform ✓, security +, devops ✓, integration ✓ | Non-whitespace placeholder for empty fields; require one data row; cap candidates (~10) and range-check 1-65535 | FS-4(a,c), SEC-2 |
| A8 | Test gaps: hook tests use a stub lsof (never real output); no lsof-absent test, no mktemp rc==3 assertion, no malformed-table-row test, nothing exercises the settings wiring; a one-time real-lsof smoke test is worthwhile. | Advisory | pr-check-9 | strategic | integration | tech-writer ✓, integration ✓, security + | Add the missing cases alongside the M1/A1 fixes | STRAT-2 |

Informational, no row: SEC-1 and SEC-3 (no injection/eval path; fail-open/fail-closed split is correct) are PASS-type findings.

Severity decisions:
- M1 (lsof): kept Medium, not Blocking. Escalated by devops and integration to "should-fix before merge", security confirmed it defeats the squatter control, but the hook (the only machine-wide runtime path) discards the exit code, the failure needs lsof absent or blocked, and fullstack showed audit does not read clean. No data loss and no silent corruption.
- A1 (mktemp, FS-2): split Medium (fullstack, integration IA-3, partly) vs Advisory (devops, security, platform). Decided Advisory: output is still non-zero, never reads as clean or as free, no secret/race (templated, 0600); it is a wrong exit-code class plus an under-tight test. The doc/contract drift part is carried inside M4/M6-style fixes, and the one-line fix rides with M1.
- M2 (PLAT-5): Medium. Security argued upper Medium; it is a self-inflicted writer bug on an agent-callable CLI, recoverable by hand-editing, so not Blocking.
- M5: PLAT-1, IA-4, STRAT-1 rated Medium; SEC-5, DEVOPS-4, TW-5 Advisory. Decided Medium: header-vs-row contradiction plus broken file:line traceability is the doc's own rule (section 7), cheap to fix, but no secrets and no runtime effect.
- M3/M4/M6: TW-1..4 and IA-1/IA-3 all Medium with no dissent (partial/stale port, claims not backed by code).

## 3. Deliberation trails (escalated findings; no Blocking findings)

> **M1 (pr-check-6 PLAT-4 / pr-check-4 DEVOPS-1 / pr-check-7 FS-1) deliberation:**
> platform-engineer (R): lsof failure reads as LISTENING=no; Medium.
> devops-engineer (C): ESCALATE — realistic in Seatbelt-sandboxed profiles; keep Medium but should-fix before merge.
> integration-architect (C): ESCALATE (on DEVOPS-1) — hook impact nil, but `--claim` and skill-contract callers rely on exit codes; keep Medium.
> fullstack-engineer (C): reproduced with lsof absent; refined that audit goes GHOST, not clean.
> security-engineer (C): hold Medium; defeats the documented fail-closed invariant.
> Synthesizer: Medium, not Blocking (see decisions above). Verified at 074c09f: line 173 `if lsof_out="$(lsof ... 2>/dev/null)"; then` else branch leaves `live_hit=0`.

> **M2 (PLAT-5) deliberation:**
> platform-engineer (R): Medium. devops ✓, integration ✓ ("Medium reasonable").
> security-engineer (C): escalate-lite to upper Medium (forged row via newline; DoS on shared registry).
> Synthesizer: Medium. Verified: `cmd_claim` validates only `validate_port` and the status enum before `printf` of 9 tab-joined fields (lines 208-229).

> **A1 mktemp (FS-2 vs DEVOPS-2/SEC-4) split:** fullstack R Medium; platform, devops, security Advisory; integration "Advisory-to-Medium". Resolved Advisory (above).

## 4. Timed-out threads

None. All 10 topics closed with quorum (cold-read by integration; pr-check-1 devops; 2, 3, 4, 5 platform; 6 devops; 7 integration; 8 fullstack; 9 integration).

## 5. Overall verdict

READY WITH CONDITIONS. No Blocking issue. The hook design is sound and safe; fix M1-M6 before merge (M1 and M2 are small code fixes, M3-M6 are doc/data cleanup). A5/A6/A8 can be addressed in the PR description or deferred.

## 6. Confidence notes

- Validated by 3+ C members (high confidence): M1 (6 seats), M3, M4, M5, M6, A1, A2, A4, A5; M2 (5 seats, plus integration's "plausible from code" caveat).
- Solo or thinly validated: A3 (platform; devops, security, integration agreed), A7 (fullstack FS-4a/c, security SEC-2; light cross-check), A8 (strategic).
- Synthesizer spot-checked every Medium against `git show 074c09f`: M1 (port-check.sh:173,148), M2 (cmd_claim 196-232), M3 (registry section 2 table skips field 3; section 3 body empty; file ends on `## Source lineage`), M4 (200-row warn present only in doc, lines 52/56; "Red flags" at 163; SS8.6 at script lines 21/85), M5/M6 (ports.tsv content; header "Generic rows only" over 9 lines). All confirmed. Row-count figures differ by seat (7/8/9); the fix text avoids hard-coding one.
- M1 runtime repro was by fullstack (lsof absent); devops' own repro attempt failed for an unrelated reason. Synthesizer did not run code.

## 7. Caller focus answers

1. Hook decision path: holds. Verified by 6 seats: always exits 0, decides from lsof only, emits only `ask` (never deny); missing jq/lsof/table/bad JSON are silent-allow. Residual: false negatives/positives on parsing (A2), unattended `ask` stall (A3), comment overstating that non-zero blocks (A4).
2. port-check.sh fail-closed: file- and row-level fail-closed is real (bad/empty registry or row = exit 3). The live-truth leg is not: lsof failure reads FREE (M1). mktemp change is correct (templated under `${TMPDIR:-/tmp}`, 0600, atomic, trap cleanup safe on empty), and failure is non-zero so never reads clean, but exits 1 instead of the documented 3 (A1).
3. Test adequacy: 43/43 hook and 15/15 port-check tests reproduced independently from git exports by several seats. Adequate for the happy and missing-dependency paths; they miss lsof-absent, mktemp rc==3, claim poison rows, real-lsof output and the settings wiring (A8).
4. Security of a PreToolUse hook on every Bash call: no injection or eval path (command text only via `printf '%s'`; the one unquoted expansion yields digits; `jq --arg` escapes the reason; numeric arg to lsof). Fail-open is the right posture; cost measured 0.03s no-match, 0.36s with hits, bounded by `timeout 5`. Same unsandboxed trust model as the sibling hooks. Residuals: env-override exec (A6), per-token lsof (A7). Shared-registry poisoning via `--claim` (M2) is the real security-relevant gap.
5. config/settings.json wiring: correct. PreToolUse Bash entry to `$HOME/projects/agent-hq/tools/hooks/port-precheck.sh` (exists, 100755, same form and `timeout 5` as siblings); test-map.tsv rows point at existing 100755 test scripts. Inert until merge to the main checkout, no-op (non-blocking 127) if the repo lives elsewhere (A5).
6. Sanitization of the ports.tsv Hermes source cells: acceptable content-wise, not acceptable as written. Panel split: integration, platform, strategic, tech-writer, fullstack, security found no secrets/personal content and the SUB rules mechanically met, and consider the rows in scope (Hermes is agent-hq-owned), so prefer reword over deletion; devops said "not acceptable as-is, drop or generalize"; platform (PLAT-1), security (SEC-5) and tech-writer (TW-5) also accept dropping the stale released 11330 row. Unanimous: sources cite unresolvable hq/`~/claude-profiles` paths, ticket ids and a pid, and contradict the "Generic rows only" header. Merged as M5 (Medium, owner may rule).

## 8. Phase C

No fixes were applied. The panel presents; the reviewer decides which of M1-M6 and A1-A8 to apply, defer or reject.

CODE-GATE-REVIEW: FAIL head=074c09f blocking=0 medium=6
0 Blocking, 6 Medium (lsof fail-open, claim row poisoning, registry doc truncation, doc/code drift, Hermes/hq citations, stale counts), 8 Advisory; READY WITH CONDITIONS.
