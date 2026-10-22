# hqx-claude — bare Claude Code runner (ADR 0008). No token is ever baked in.
FROM node:22-slim
RUN apt-get update && apt-get install -y --no-install-recommends \
      git ca-certificates tini \
 && rm -rf /var/lib/apt/lists/*
# Pin to the host Claude Code version for behavioral parity (bump deliberately).
# R-l (owner, 2026-10-08): pin = host-installed version at build (v=$(claude --version | cut -d' ' -f1),
# passed as --build-arg CLAUDE_VERSION=$v); floor >=2.1.280 (T-38/T-41). Default below = host value on 2026-10-08 (task-pipeline U1, T-20261007-84).
ARG CLAUDE_VERSION=2.1.294
RUN npm install -g @anthropic-ai/claude-code@${CLAUDE_VERSION}
COPY entrypoint.sh /usr/local/bin/hqx-entrypoint.sh
RUN chmod +x /usr/local/bin/hqx-entrypoint.sh
# Non-root: reuse the base image's built-in unprivileged user (node, UID/GID 1000).
# node:22-slim pre-assigns UID 1000 to `node`; a second UID-1000 user cannot be
# created (as-built deviation 1). Same UID => identical bind-mount semantics.
USER node
# Neutral git identity for the results-out safety-net commit and any agent-made
# commits (as-built deviation 2). After USER node: writes /home/node/.gitconfig.
RUN git config --global user.name "hqx" \
 && git config --global user.email "hqx@container.invalid"
WORKDIR /work
ENTRYPOINT ["/usr/bin/tini","--","/usr/local/bin/hqx-entrypoint.sh"]
# NOTE: the OAuth token env var is injected at `docker run` time only; no ENV/ARG
# line may ever name or carry it (invariant 23 greps this file for its name —
# which is also why this comment does not spell it out; see as-built deviation 3).
