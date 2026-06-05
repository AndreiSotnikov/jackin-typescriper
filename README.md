# Typescriper

Jackin role for TypeScript monorepos. Targets pnpm workspaces with a Node.js server, a React + Vite client, Playwright e2e, optional Postgres, and the Tessl spec-driven workflow.

## What's in the image

Base: `projectjackin/construct:0.4-trixie` (Debian + git + gh + mise + Docker CLI + zsh + ripgrep + fd + jq).

Added on top:

| Tool | Version (ARG) | Why |
|---|---|---|
| Node.js | `22.22.2` | LTS, mise-managed |
| pnpm | `9.15.0` | corepack-activated; overridden by project's `packageManager` field at runtime |
| Playwright + chromium | `1.49.0` | client e2e (system deps baked in) |
| Tessl CLI | `0.82.0` | `tessl mcp start` for projects wiring it in `.mcp.json` |
| Caveman skills | `1.8.2` | output compression for claude / opencode / codex / amp |
| cavemem | `0.2.1` | cross-agent persistent memory (SQLite + MCP) |
| apt: `postgresql-client` | — | psql for migrations and DB inspection |
| apt: `build-essential`, `libssl-dev`, `pkg-config`, `libvips-dev` | — | native node-gyp deps (argon2, bcrypt) and Sharp |

Supported agents: `claude`, `codex`, `amp`, `opencode`, `kimi`.

Claude plugins (preconfigured in `jackin.role.toml`): `feature-dev`, `code-review`, `code-simplifier`, `commit-commands`, `github`, `claude-md-management`, `security-guidance`, `pr-review-toolkit`, `caveman`.

## Validate

```sh
jackin role validate .
```

## Register and load

Register the role once in `~/.config/jackin/config.toml`:

```toml
[roles.typescriper]
git = "https://github.com/<owner>/jackin-typescriper.git"
trusted = true
```

Then load it against a workspace:

```sh
jackin load typescriper --rebuild --debug
```

After the first successful build, drop `--rebuild`.

## Host mounts (workspace config)

The role expects per-workspace mounts to be wired in `~/.config/jackin/workspaces/<workspace>.toml` so `jackin load typescriper` works without `--mount` flags.

Example workspace TOML:

```toml
version = "v1alpha5"
workdir = "/Users/<you>/work/<project>"
last_role = "typescriper"

[[mounts]]
src = "/Users/<you>/work/<project>"
dst = "/Users/<you>/work/<project>"
readonly = false
isolation = "shared"

# SSH keys — git push, deploy scripts, gh
[[mounts]]
src = "/Users/<you>/.ssh"
dst = "/home/agent/.ssh"
readonly = true
isolation = "shared"

# Git author identity
[[mounts]]
src = "/Users/<you>/.gitconfig"
dst = "/home/agent/.gitconfig"
readonly = true
isolation = "shared"

# cavemem persistent memory store
[[mounts]]
src = "/Users/<you>/.cavemem-<project>"
dst = "/home/agent/.cavemem"
readonly = false
isolation = "shared"

# pnpm content-addressable store (faster cold installs)
[[mounts]]
src = "/Users/<you>/.pnpm-store-jackin"
dst = "/home/agent/.local/share/pnpm/store"
readonly = false
isolation = "shared"
```

**One-time host setup:**

```sh
mkdir -p ~/.cavemem-<project> ~/.pnpm-store-jackin
```

Without these directories, Docker creates them as root and the `agent` user (UID 1000) can't write.

### Optional mounts

- **GPG signing keys** — if `commit.gpgsign=true`:
  ```toml
  [[mounts]]
  src = "/Users/<you>/.gnupg"
  dst = "/home/agent/.gnupg"
  readonly = false
  isolation = "shared"
  ```
- **AWS / kube creds** — copy the pattern from existing role configs if needed.

## First-session inside the container

1. `cd /workspace` (or the bound path), run `pnpm install` once.
2. `gh auth login` if you'll be using `gh` (gh CLI is from base image; auth isn't mounted by default).
3. Tessl MCP (`tessl mcp start`) auto-launches via the project's `.mcp.json`.
4. cavemem writes to `~/.cavemem`; web viewer at `http://localhost:37777` (host port mapping handled by jackin).

## Tooling notes

- **Testcontainers / DinD** — handled by jackin's runtime; integration tests using `@testcontainers/postgresql` spin up ephemeral Postgres without extra config.
- **Playwright** — chromium is preinstalled with system deps. To add firefox/webkit, run `pnpm exec playwright install firefox webkit` inside the container.

## Bumping versions

Edit the `ARG *_VERSION` lines in `Dockerfile`, then rebuild:

```sh
jackin load typescriper --rebuild
```

No renovate config — bumps are manual.
