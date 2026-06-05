FROM projectjackin/construct:0.4-trixie@sha256:6910f6ea9dd3ceffd9f9f08c8345b42e967d8e930de3e037e1ffcd0e052b8e4e

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# CAVEMAN_VERSION must be a release tag from
# https://github.com/JuliusBrussee/caveman/releases — never `main`,
# never a raw commit SHA. The `skills` CLI's shallow git-clone fetch
# resolves tags but not arbitrary SHAs.
ARG NODE_VERSION=22.22.2
ARG PNPM_VERSION=9.15.0
ARG PLAYWRIGHT_VERSION=1.49.0
ARG TESSL_VERSION=0.82.0
ARG CAVEMAN_VERSION=1.8.2
ARG CAVEMEM_VERSION=0.2.1

# System packages:
# - build-essential, libssl-dev, pkg-config: native node-gyp deps (argon2, bcrypt, etc.)
# - libvips-dev: Sharp image processing
# - postgresql-client: psql for migrations and DB inspection
# - libnss3..libasound2: Playwright chromium runtime
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    sudo apt-get update && \
    sudo apt-get install -y --no-install-recommends \
    build-essential \
    libssl-dev \
    pkg-config \
    libvips-dev \
    postgresql-client \
    libnss3 \
    libnspr4 \
    libatk1.0-0 \
    libatk-bridge2.0-0 \
    libcups2 \
    libdrm2 \
    libxkbcommon0 \
    libxcomposite1 \
    libxdamage1 \
    libxfixes3 \
    libxrandr2 \
    libgbm1 \
    libpango-1.0-0 \
    libcairo2 \
    libasound2 && \
    sudo apt-get autoremove -y

USER agent

ENV MISE_TRUSTED_CONFIG_PATHS=/workspace

# Per-tool RUNs: bumping one ARG only invalidates that tool's layer.
RUN --mount=type=secret,id=github_token,uid=1000,required=false \
    GITHUB_TOKEN=$(cat /run/secrets/github_token 2>/dev/null || true) \
    mise install "node@${NODE_VERSION}" && \
    mise use -g --pin "node@${NODE_VERSION}"

# pnpm via mise (consistent with node). At runtime, projects with a
# `packageManager` field in package.json will use that pinned version
# instead (pnpm self-bootstraps to the requested release).
RUN --mount=type=secret,id=github_token,uid=1000,required=false \
    GITHUB_TOKEN=$(cat /run/secrets/github_token 2>/dev/null || true) \
    mise install "pnpm@${PNPM_VERSION}" && \
    mise use -g --pin "pnpm@${PNPM_VERSION}"

# Playwright chromium for client e2e. System deps installed above; using
# `--with-deps` would re-invoke apt as root and fight cache mounts.
RUN --mount=type=cache,target=/home/agent/.npm,uid=1000 \
    --mount=type=cache,target=/home/agent/.cache/ms-playwright,uid=1000,sharing=locked \
    . ~/.profile && \
    npm i -g "playwright@${PLAYWRIGHT_VERSION}" && \
    playwright install chromium && \
    playwright --version

# Tessl CLI for spec-driven workflows. Projects that wire `tessl mcp start`
# in .mcp.json need the binary on PATH for the MCP server to launch.
RUN --mount=type=cache,target=/home/agent/.npm,uid=1000 \
    . ~/.profile && \
    npm i -g "tessl@${TESSL_VERSION}" && \
    tessl --version

# Caveman skills install (same pattern as jackin-the-architect).
# Agent CLIs aren't on PATH at build time, so `--only` forces each target.
# `--no-mcp-shrink` skips registration that needs the claude CLI.
RUN . ~/.profile && \
    mkdir -p "${HOME}/.claude" "${HOME}/.codex" && \
    git clone --depth 1 --branch "v${CAVEMAN_VERSION}" https://github.com/JuliusBrussee/caveman.git /tmp/caveman && \
    node /tmp/caveman/bin/install.js --only claude --only opencode --no-mcp-shrink && \
    test -f "${HOME}/.claude/hooks/caveman-statusline.sh" && \
    test -f "${HOME}/.claude/hooks/caveman-activate.js" && \
    test -f "${HOME}/.claude/hooks/caveman-mode-tracker.js" && \
    test -f "${HOME}/.config/opencode/plugins/caveman/plugin.js" && \
    cd "${HOME}" && \
    npx -y skills add "JuliusBrussee/caveman#v${CAVEMAN_VERSION}" -a codex --yes --global && \
    npx -y skills add "JuliusBrussee/caveman#v${CAVEMAN_VERSION}" -a amp --yes --global && \
    test -f "${HOME}/.agents/skills/caveman/SKILL.md" && \
    rm -rf /tmp/caveman

# cavemem: cross-agent persistent memory (SQLite + MCP). Wire hooks for
# claude/opencode/codex (amp + kimi unsupported by cavemem installer).
# SQLite store lives at ~/.cavemem — mount at runtime to persist across container rebuilds.
RUN --mount=type=cache,target=/home/agent/.npm,uid=1000 \
    . ~/.profile && \
    npm i -g "cavemem@${CAVEMEM_VERSION}" && \
    cavemem install && \
    cavemem install --ide opencode && \
    cavemem install --ide codex && \
    cavemem --version

# Smoke tests fail the build fast if any tool is broken.
RUN . ~/.profile && \
    node --version && \
    pnpm --version && \
    playwright --version && \
    tessl --version && \
    cavemem --version && \
    psql --version
