# Try agent-hq on your machine without touching your Claude setup

This guide is for a developer who wants to try agent-hq on a laptop that already has
Claude Code. Your login can be an Anthropic account (OAuth token) or an AWS Bedrock
account. Both paths use `cprof`, the profile tool in `tools/claude-profile/`.
Design: `architecture/claude-profile.md`.

## What you get, and what stays untouched

- A profile is a folder under `~/claude-profiles/<name>/`. It has its own
  `CLAUDE_CONFIG_DIR` (`config/`), its own settings, its own `workspace/`, and either
  its own token file or a pass-through of the AWS credentials in your shell.
- Apart from `cprof link` (see Skills below), `cprof` never writes to `~/.claude` or
  `~/.claude.json`. Your normal Claude Code setup keeps working as before.
- A profile applies to one shell at a time. Other terminals are not affected.
- `cprof off` restores the shell exactly: environment, prompt and directory.

## Prerequisites

- zsh, `jq`, `git`, and the Claude Code CLI (`claude` on your PATH).
- The `aws` CLI, only if you use Bedrock.

## Clone and the one line in `~/.zshrc`

Clone into `~/projects/agent-hq`. cprof reads its tier files from
`~/projects/agent-hq/config` unless `CPROF_HQ_CONFIG` says otherwise.

```sh
mkdir -p ~/projects
git clone https://github.com/sceptre12/agent-hq.git ~/projects/agent-hq
```

Add this one line to `~/.zshrc` by hand, then open a new terminal:

```sh
source ~/projects/agent-hq/tools/claude-profile/cprof.zsh
```

Check that it loaded:

```sh
cprof help
```

## Regular setup (Anthropic account)

1. In your normal shell, with your normal login, create a long-lived token.
   It prints the token once; copy it.

   ```sh
   claude setup-token
   ```

2. Create an executor profile. `CPROF_OWNER` is your GitHub account name; the executor
   rules name it as the only account it may push to. `cprof new` asks for the token
   with hidden input; paste it there. Never put a token on a command line.

   ```sh
   export CPROF_OWNER=<your-github-account>
   cprof new try --tier executor
   ```

3. See what launch would do, without starting anything. The token is shown as `<token>`.

   ```sh
   cprof launch try --dry-run
   ```

4. Start it. An executor runs Claude Code with permissions skipped, inside a deny list
   and an OS sandbox.

   ```sh
   cprof launch try
   ```

5. Check the isolation from a shell. `doctor` makes one small API call; add
   `--no-claude` to skip it.

   ```sh
   cprof use try
   cprof doctor
   cprof off
   ```

### The desk tier

A desk runs in auto permission mode instead of bypass. Create and launch it the same way:

```sh
cprof new try-desk --tier desk
cprof launch try-desk
```

### A plain profile (no tier)

A plain profile has no deny list or sandbox render. You enter it with `cprof use` and
start `claude` yourself. `cprof launch` refuses a plain profile.

```sh
cprof new try-plain
cprof use try-plain
claude
cprof off
```

## Bedrock setup (AWS account)

A Bedrock profile has no token. Claude Code uses the AWS credentials of the shell
that starts it.

1. Put a region and credentials in your shell. Pick one credential style.

   SSO profile:

   ```sh
   aws sso login --profile <your-aws-profile>
   export AWS_PROFILE=<your-aws-profile>
   export AWS_REGION=us-east-1
   ```

   The sandbox cannot open a browser login. When the SSO session expires mid-session,
   run `aws sso login --profile <your-aws-profile>` again in a normal shell and restart
   Claude Code.

   Access keys: export `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` and, for temporary
   keys, `AWS_SESSION_TOKEN`, plus `AWS_REGION`. Load them from your usual tool; do not
   type them on a command line.

   Bedrock API key: export `AWS_BEARER_TOKEN_BEDROCK` and `AWS_REGION`. When this key
   is set, Claude Code does not look up the other AWS credentials.

2. If your SSO region differs from the model region, set it too:

   ```sh
   export CPROF_SSO_REGION=<your-sso-region>
   ```

   Claude Code reads the SSO region from your AWS profile; cprof cannot, so it needs
   this variable to allow the right SSO hosts. The model region has no such override:
   cprof and Claude Code both read `AWS_REGION` (else `AWS_DEFAULT_REGION`).

3. Create the profile. A tiered Bedrock render needs `AWS_REGION` (or
   `AWS_DEFAULT_REGION`) in this shell; without a valid region id it stops and creates
   nothing.

   ```sh
   export CPROF_OWNER=<your-github-account>
   cprof new try-bedrock --auth bedrock --tier executor
   ```

   It asks for no token. The last line ends with
   `(auth: bedrock, no token; AWS credentials come from your shell)`.

   `new --auth bedrock` also snapshots this shell's `AWS_PROFILE`, `AWS_REGION`/`AWS_DEFAULT_REGION` and any
   `ANTHROPIC_MODEL`/`ANTHROPIC_DEFAULT_*_MODEL` vars into `try-bedrock/profile.env` right away, so the profile is
   self-contained from creation instead of depending on whatever a later shell's ambient AWS state happens to be.
   No `AWS_PROFILE` exported here: `cprof: WARN: no AWS_PROFILE in this shell to snapshot into
   'try-bedrock/profile.env'; set AWS_PROFILE before 'cprof new <name> --auth bedrock', or add it to
   <path>/profile.env by hand` — the profile is still created; add `AWS_PROFILE` to `profile.env` by hand
   afterward, or re-run `new` in a shell that has it exported.

   This step also self-heals a broken `AWS_PROFILE` automatically — no flag, no setup. If the ambient
   profile turns out to be denied Bedrock access (e.g. an SCP-restricted sandbox account), `new` prints
   a WARN naming the problem and substitutes a working AWS profile it finds live, so `profile.env` ends
   up pointing at something that actually works instead of faithfully recording a broken one. The search
   prefers a directly-usable profile over a raw, internal-only SSO session profile of the same identity
   (one commented "do not use directly" in `~/.aws/config`, typically named `<profile>-sso`), and
   independently re-verifies every candidate's identity live before accepting it — this confirms the
   substitute can reach Bedrock, not that it has identical IAM access to whatever profile was ambient
   before. A result this validated is cached in `<root>/.aws-profile-health` (keyed by profile and
   region), so repeat `cprof new`/`cprof doctor` runs with the same profile and region are instant; a
   live check may pop a normal browser SSO login if that profile's cached token is stale, same as any
   other AWS CLI call.

4. Choose models. Claude Code's Bedrock defaults are not pinned, so set model ids in
   `~/claude-profiles/try-bedrock/profile.env`. Model ids and inference profiles are
   specific to your AWS account and region; check which ones yours has. Set all four of
   them: Claude Code also makes background calls with the Haiku id. One example:

   ```sh
   ANTHROPIC_MODEL=us.anthropic.claude-sonnet-4-6
   ANTHROPIC_DEFAULT_OPUS_MODEL=us.anthropic.claude-opus-4-8
   ANTHROPIC_DEFAULT_SONNET_MODEL=us.anthropic.claude-sonnet-4-6
   ANTHROPIC_DEFAULT_HAIKU_MODEL=us.anthropic.claude-haiku-4-5-20251001-v1:0
   ANTHROPIC_DEFAULT_FABLE_MODEL=us.anthropic.claude-fable-4-5-20251001-v1:0
   ```

   The `us.` prefix is for US regions. Elsewhere use `eu.`, `apac.` or `global.` to
   match your region (Claude Code also reads `ANTHROPIC_BEDROCK_REGION_PREFIX`).
   `profile.env` can also hold `AWS_PROFILE`. Keep `AWS_REGION` exported in your shell
   as well: the tiered render reads the region from the shell only.
   `use` honours `profile.env`, including auth vars; `launch` strips them. Do not put
   Anthropic keys in a bedrock profile's `profile.env`; `cprof doctor` warns when one is set.

   If any of these were already exported in this shell at step 3, they are already in `profile.env` from the
   auto-snapshot above — edit the values there directly rather than re-exporting and re-running `new` (which
   refuses: the profile directory already exists).

5. Dry-run, check and launch:

   ```sh
   cprof launch try-bedrock --dry-run
   cprof use try-bedrock; cprof doctor --no-claude; cprof off
   cprof launch try-bedrock
   ```

   The dry-run env line shows `CLAUDE_CODE_USE_BEDROCK=1`, your `AWS_REGION` and
   `AWS_PROFILE` (or `unset`), and never a token. `cprof doctor` shows `auth=bedrock`
   on the tier row.

What changes in a Bedrock profile:

- `cprof use` and `cprof launch` set `CLAUDE_CODE_USE_BEDROCK=1` and unset
  `ANTHROPIC_AUTH_TOKEN`, `ANTHROPIC_API_KEY`, `CLAUDE_CODE_OAUTH_TOKEN`,
  `CLAUDE_CODE_USE_VERTEX` and `CLAUDE_CODE_USE_FOUNDRY`. Your `AWS_*` variables pass
  through unchanged. `cprof off` puts everything back.
- If no region is set, `cprof use` warns that Claude Code falls back to the AWS
  profile's region, then `us-east-1`.
- The sandbox network allowlist gains seven AWS hosts, filled in with your region
  (and SSO region):

  ```text
  bedrock-runtime.<region>.amazonaws.com
  bedrock.<region>.amazonaws.com
  sts.<region>.amazonaws.com
  sts.amazonaws.com
  sso.<sso_region>.amazonaws.com
  oidc.<sso_region>.amazonaws.com
  portal.sso.<sso_region>.amazonaws.com
  ```

  These come from the AWS endpoint pages, not from the Claude Code docs, and are not yet
  tested in every region. The SSO hosts are added for every credential style (harmless).
  A gateway set with `ANTHROPIC_BEDROCK_BASE_URL` gets no host; add it with an overlay.
  An overlay is `config/tiers/overlays/<project>.json` (see `config/tiers/overlays/README.md`).
  It may only ADD denies and sandbox allowances. Render with
  `cprof new <name> --auth bedrock --tier executor --overlay <project>`. Example:

  ```json
  {
    "_overlay": "<project>",
    "sandbox": { "network": { "allowedDomains": ["bedrock-gateway.example.com"] } }
  }
  ```

  If the sandbox blocks a host, that is a design signal: report it with the host name.
  Do not disable the sandbox.
- WebSearch is not available on Bedrock (Claude Code docs, read 2026-10-26).
- If you change `AWS_REGION` or `CPROF_SSO_REGION`, the next `cprof launch` sees the
  render as stale and re-renders it for the new region before starting, unless
  `settings.json` was edited by hand (then run `cprof sync try-bedrock --force`).
- `cprof token try-bedrock` refuses: a Bedrock profile has no token.

## Skills in a profile

A new profile has no skills. They are not installed automatically. The documented
install (ADR 0009) symlinks each skill into `~/.claude/skills`, which is your main
setup, so do not use it for an isolated try.

Instead, link the agent-hq skills into the profile only:

```sh
P=${CPROF_ROOT:-$HOME/claude-profiles}/try/config
mkdir -p "$P/skills"
for s in ~/projects/agent-hq/skills/*(/); do
  ln -sfn "$s" "$P/skills/${s:t}"
done
```

Run the loop once per profile; change `try` to the profile name. To take only some
skills, list their names instead of `*(/)`. Run it only on a profile you have not
`cprof link`ed to `~/.claude`: after that link, the profile's `skills` is a link to
`~/.claude/skills`, so the loop would write into your main setup.

`cprof link <name> ~/.claude` is a cprof invocation that does write into
`~/.claude/skills`: it links the profile's `skills` to it, so skills added through the
profile land in your main setup. Bare `cprof link <name>`, with no second argument,
defaults to `~/projects/agent-hq` instead of `~/.claude` — but that is **not** an escape
from this caveat, it is the same footgun pointed at a different live checkout: it
symlinks the profile's `skills` (and `agents`) straight into your `~/projects/agent-hq`
working tree, so anything written through the profile (a skill install, an edit) lands
in that checkout too, not in an isolated copy. Treat bare `cprof link <name>` as subject
to the same caveat as `cprof link <name> ~/.claude`. For an isolated trial use the loop
above, not `link`, either form.
If your main setup already has the skills you want, `cprof link try ~/.claude` links the
profile's `skills`, `agents` and `plugins` to `~/.claude` and copies your MCP server list
(without secret-looking keys). It brings your main plugins and MCP servers into the
profile, and plugin installs made inside it then land in `~/.claude`. On a tiered profile
it keeps the rendered `settings.json` and does not link `CLAUDE.md`. See
`tools/claude-profile/README.md`.

## Do not run the global config install

`config/README.md` describes a symlink install of `config/CLAUDE.md` and
`config/settings.json` into `~/.claude`. That is the global install. It replaces your
`~/.claude/CLAUDE.md` and `~/.claude/settings.json`. Do not run it for a trial; profiles
need none of it.

## Leaving

```sh
cprof off
cprof rm try
```

`cprof rm` shows what it will delete and asks first. It refuses the active profile, so
run `cprof off` before it. Remove the `source` line from `~/.zshrc` if you are done with
cprof. Nothing else needs undoing.
