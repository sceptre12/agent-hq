FACTS: 9 facts
measured: cat .nvmrc -> v22.13.0
measured: grep packageManager package.json -> pnpm@9.15.3
measured: grep '"lint"\|"typecheck"\|"test"\|"build"\|"clean"' package.json -> eslint ., tsc --noEmit, vitest run, tsc -p tsconfig.build.json, rm -rf dist
measured: ls .github/workflows -> ci.yml
measured: grep -E '^  [a-z]+:$' .github/workflows/ci.yml -> lint, typecheck, test
measured: git tag -l | wc -l -> 0
measured: grep -i merge docs/CONTRIBUTING.md -> maintainers squash-merge; a merge to main does not deploy anything
measured: grep -i 'jira project' docs/CONTRIBUTING.md -> DEMO
cannot measure: hosting-service required-checks list and PR review rules (needs the hosting service, not in the repo)
