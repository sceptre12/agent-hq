FACTS: 36 facts
measured: git remote -v -> (no output)
measured: git rev-parse --show-cdup -> (no output)
measured: find . -maxdepth 1 \( -name nx.json -o -name turbo.json -o -name pnpm-workspace.yaml -o -name lerna.json \) -> (no output)
measured: command grep -E '"(name|workspaces)"' package.json -> "name": "demo-widgets",
measured: command grep -riE 'consumer|depends on' README.md docs -> (no output)
measured: cat .nvmrc -> v22.13.0
measured: command grep -E '"(packageManager|node)"' package.json -> "packageManager": "pnpm@9.15.3",; "engines": { "node": ">=22" },
measured: find . -maxdepth 1 -name '*lock*' -> ./pnpm-lock.yaml
measured: command grep -E '"(install|lint|typecheck|test|build|pack|clean|release|publish)":' package.json -> "lint": "eslint .",; "typecheck": "tsc --noEmit",; "test": "vitest run",; "build": "tsc -p tsconfig.build.json",; "clean": "rm -rf dist"
measured: find . -maxdepth 1 -name .husky -> (no output)
measured: git config core.hooksPath -> (no output)
measured: find . -maxdepth 1 \( -name 'commitlint*' -o -name '.commitlintrc*' \) -> (no output)
measured: find .github/workflows -type f -> .github/workflows/ci.yml
measured: sed -n '/^on:/,/^jobs:/p' .github/workflows/ci.yml -> on:; pull_request:; push:; branches: [main]; jobs:
measured: sed -n '/^jobs:/,$p' .github/workflows/ci.yml | command grep -E '^  [a-z]+:$' -> lint:; typecheck:; test:
measured: command grep -cE 'concurrency|needs:' .github/workflows/ci.yml -> 0
measured: git tag -l | wc -l -> 0
measured: command grep -rliE 'deploy|publish|release' .github/workflows -> (no output)
measured: command grep -riE 'version|bump' README.md docs -> (no output)
measured: command grep -i merge docs/CONTRIBUTING.md -> - Open a PR to `main`; the maintainers squash-merge.; - A merge to `main` does not deploy anything; releases are cut by hand.
measured: find . -path ./.git -prune -o \( -iname '*pull_request_template*' -o -name labeler.yml \) -print -> (no output)
measured: command grep -i branch README.md -> A small widget library. Branches are named `<JIRA-KEY>-<desc>`. See docs/CONTRIBUTING.md.
measured: find . -path ./.git -prune -o \( -name .gitleaks.toml -o -name 'secrets*' \) -print -> (no output)
measured: command grep -rE 'process\.env' README.md docs package.json -> (no output)
measured: find . -maxdepth 1 \( -name 'playwright.config.*' -o -name 'cypress.config.*' -o -name 'vitest.config.*' \) -> (no output)
measured: command grep -i coverage package.json -> (no output)
measured: find . -path ./.git -prune -o \( -name CODEOWNERS -o -name .gitignore \) -print -> (no output)
measured: find . -path ./.git -prune -o \( -name 'docker-compose*' -o -name app-ports.tsv \) -print -> (no output)
measured: git log --format=%s | head -> initial commit
measured: command grep -i 'jira project' docs/CONTRIBUTING.md -> - Do not commit credentials. The Jira project key is DEMO.
measured: command grep -riE 'zephyr|xray|testrail' README.md docs -> (no output)
cannot measure: hosting-service required-checks list, merge-method setting and PR review rules (they live on the hosting service, not in the repo)
cannot measure: durations.pr_review_min, durations.ci_round_min, durations.unit_median_min (CI run history lives on the hosting service; no local record in the repo)
cannot measure: Node version manager and machine limits for node.prefix_cmd and gates.parallel, gates.min_free_kb, gates.runner_slots (facts of the run machine, not the repo)
cannot measure: ports.bus_base, ports.lane_base (no tools/ports.tsv or tools/app-ports.tsv given to the dry run; the base is the human's choice)
cannot measure: gates.command (no affected-capable runner: no nx.json, turbo.json or task runner file; package.json has only the full-repo scripts lint, typecheck, test)
