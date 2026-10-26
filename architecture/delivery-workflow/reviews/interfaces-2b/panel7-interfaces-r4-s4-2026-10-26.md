id | sev | artifact file:line | defect | source | fix
s4-1 | M | interfaces/part-b-desk.md:86; part-a-state.md:103-117 | N11 is per repo but the desk reads "the run's repo-profile.md"; state.md has one repo_profile (primary); no mapping from the request repo to its profile in a multi-repo epic | owner-decisions.md:82-84; part-a-state.md:50,63,258 | State how the desk resolves the profile for the request repo; refuse policy if none resolves
s4-2 | L | part-a-state.md:290; part-b-desk.md:73,86 | N10 scope on the tag-push git push (inline HUSKY=0, no gate-runs file) is unstated | owner-decisions.md:80 | One clause in A.7/B4 tag-push

totals 0/1/1
