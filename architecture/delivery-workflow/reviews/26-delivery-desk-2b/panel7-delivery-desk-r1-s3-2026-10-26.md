id | sev | artifact file:line | defect | source file:line | fix
--- | --- | --- | --- | --- | ---
s3-1 | M | references/schemas.json:10,19,20; verbs.md:88,135 | git_ref, tag, package accept a leading '-' and act lines lack '--', so a raw flag can ride in a ref/tag value (desk-req.sh refuses it, desk does not) | tools/delivery/desk-req-schema.sh:15,23-24; decisions/0055-desk-verb-permission-tiers-02.md:198 | first char [A-Za-z0-9._/]; '--' before positionals
s3-2 | M | references/checks.md:92; verbs.md:81-84 | branch-delete content-merged uses bare merged_into (agent-writable local ref, any name), not the fetched remote base | architecture/delivery-workflow/interfaces/part-b-desk.md:110 | resolve as fetched remote-tracking ref equal to profile base, else marker
s3-3 | M | references/checks.md:66-67 | images classed by extension only; a text/secret file named x.png is attached unscanned | part-b-desk.md:147; decisions/0055-...:182-183 | check magic bytes; scan non-image content
s3-4 | M | references/checks.md:61-65; SKILL.md:83-86 | scan failure modes undefined (grep exit 2, absent/empty pattern_file) so redaction can fail open | part-b-desk.md:146-147 | only exit 1 on readable non-empty file passes; else policy
s3-5 | M | SKILL.md:88-91 | "operator's own account" / "switched identity" needs an expected-account memory = account lock | part-b-desk.md:14,75; decisions/0055-...:123-128 | freshness = gh auth status exit 0 / Atlassian answers only
s3-6 | M | SKILL.md:142-143,195 vs 71 | approve/trigger-prod/pipeline-edit "policy" but unknown verb is schema at check 5 first | part-b-desk.md:41,64 | state the code for a not-a-verb name
s3-7 | L | verbs.md:51-52 | request-changes review "only for Blocking" with no field/marker; desk would judge from body text | part-b-desk.md:93; decisions/0055-...:195 | pr-comment runs only gh pr comment
s3-8 | L | verbs.md:112-116 | ci-rerun PR-run derivation has no command | decisions/0055-...:196-197 | name gh run view derivation; refuse non-pull_request
s3-9 | L | verbs.md:142-143 | publish "per the repo's release procedure" can run repo-supplied/pipeline commands | decisions/0055-...:196-197 | fix command in skill, never from repo content, never triggers pipelines

totals B/M/L 0/6/3
