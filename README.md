# Typescriper

Jackin role for TypeScript monorepos. Built for [food-guide](https://github.com/jackin-project) (pnpm workspace, React 19 + Vite client, Express 5 + Postgres server, Playwright e2e, Tessl spec-driven workflow), but generic enough for any TS project using the same stack.

## What's in the image

Base: `projectjackin/construct:0.4-trixie` (Debian + git + gh + mise + Docker CLI + zsh + ripgrep + fd + jq).

Added on top:

| Tool | Version (ARG) | Why |
|---|---|---|
| Node.js | `22.22.2` | matches food-guide `.nvmrc` |
| pnpm | `9.15.0` | matches `packageManager` field |
| Playwright + chromium | `1.49.0` | client e2e (system deps baked in) |
| Tessl CLI | `0.82.0` | `tessl mcp start` per `.mcp.json` |
| Caveman skills | `1.8.2` | output compression for claude / opencode / codex / amp |
| cavemem | `0.2.1` | cross-agent persistent memory (SQLite + MCP) |
| apt: `postgresql-client` | — | psql for migrate / restore |
| apt: `build-essential`, `libssl-dev`, `pkg-config`, `libvips-dev` | — | argon2 native build, Sharp |

Supported agents: `claude`, `codex`, `amp`, `opencode`, `kimi`.

Claude plugins (preconfigured in `jackin.role.toml`): `feature-dev`, `code-review`, `code-simplifier`, `commit-commands`, `github`, `claude-md-management`, `security-guidance`, `pr-review-toolkit`, `caveman`.

## Validate

```sh
jackin role validate .
```

## Build and load

```sh
jackin load typescriper --rebuild --debug
```

After the first successful build, drop `--rebuild`.

## Host mounts (workspace config)

The role expects per-workspace mounts to be wired in `~/.config/jackin/workspaces/<workspace>.toml` so `jackin load typescriper` works without `--mount` flags.

Example (`food-guide.toml`):

```toml
version = "v1alpha5"
workdir = "/Users/sotnikov/work/personal/food-guide"
last_role = "typescriper"

[[mounts]]
src = "/Users/sotnikov/work/personal/food-guide"
dst = "/Users/sotnikov/work/personal/food-guide"
readonly = false
isolation = "shared"

# SSH keys — deploy.sh / promote.sh / git push / gh
[[mounts]]
src = "/Users/sotnikov/.ssh"
dst = "/home/agent/.ssh"
readonly = true
isolation = "shared"

# Git author identity
[[mounts]]
src = "/Users/sotnikov/.gitconfig"
dst = "/home/agent/.gitconfig"
readonly = true
isolation = "shared"

# cavemem persistent memory store
[[mounts]]
src = "/Users/sotnikov/.cavemem-food-guide"
dst = "/home/agent/.cavemem"
readonly = false
isolation = "shared"

# pnpm content-addressable store (faster cold installs)
[[mounts]]
src = "/Users/sotnikov/.pnpm-store-jackin"
dst = "/home/agent/.local/share/pnpm/store"
readonly = false
isolation = "shared"
```

**One-time host setup:**

```sh
mkdir -p ~/.cavemem-food-guide ~/.pnpm-store-jackin
```

Without these directories, Docker creates them as root and the `agent` user (UID 1000) can't write.

### Optional mounts

- **GPG signing keys** — if `commit.gpgsign=true`:
  ```toml
  [[mounts]]
  src = "/Users/sotnikov/.gnupg"
  dst = "/home/agent/.gnupg"
  readonly = false
  isolation = "shared"
  ```
- **AWS / kube creds** — copy the pattern from existing role-configs if needed.

## First-session inside the container

1. `cd /workspace` (or the bound path), run `pnpm install` once.
2. `gh auth login` if you'll be using `gh` (gh CLI is from base image; auth isn't mounted by default).
3. Tessl MCP (`tessl mcp start`) auto-launches via the project's `.mcp.json`.
4. cavemem writes to `~/.cavemem`; web viewer at `http://localhost:37777` (host port mapping handled by jackin).

## Deploy from inside the role

`scripts/deploy.sh` and `scripts/promote.sh` need:
- The deploy SSH private key on `~/.ssh/id_foodguide_deploy` (already covered by the `~/.ssh` mount).
- VPS host fingerprint in `~/.ssh/known_hosts` (already covered).

Run as usual:

```sh
./scripts/promote.sh
DEPLOY_HOST=<VPS_IP> ./scripts/deploy.sh
```

## Tooling notes

- **Testcontainers / DinD** — handled by jackin's runtime; `apps/server` integration tests (`vitest.integration.config.ts`) spin up ephemeral Postgres without extra config.
- **Playwright** — chromium is preinstalled with system deps. To add firefox/webkit, run `pnpm exec playwright install firefox webkit` inside the container.
- **Sentry CLI** — read auth from `.sentryclirc` in the project workspace.

## Bumping versions

Edit the `ARG *_VERSION` lines in `Dockerfile`, then rebuild:

```sh
jackin load typescriper --rebuild
```

No renovate config — bumps are manual.
