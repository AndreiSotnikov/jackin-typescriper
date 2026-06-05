#!/usr/bin/env bash
# Runs after jackin installs the agent CLI and bootstraps plugins.
# Re-registers cavemem's IDE bindings because ~/.cavemem is bind-mounted
# from the host and wipes the build-time registry on every container start.
# Hooks in ~/.claude/settings.json are baked into the image and persist;
# this only restores cavemem's own "installed-ides" record so that
# `cavemem status` and the MCP server are visible to the agent.
set -euo pipefail

trap 'printf "[typescriper-preflight] ERROR: failed at line %s (exit %s)\n" "$LINENO" "$?" >&2; exit 1' ERR

log()  { printf '[typescriper-preflight] %s\n' "$*"; }
warn() { printf '[typescriper-preflight] WARNING: %s\n' "$*" >&2; }

if ! command -v cavemem >/dev/null 2>&1; then
    warn "cavemem CLI not on PATH — skipping IDE registration"
    exit 0
fi

case "${JACKIN_AGENT:-}" in
    claude)
        log "registering cavemem for claude-code"
        cavemem install --ide claude-code >/dev/null
        ;;
    codex)
        log "registering cavemem for codex"
        cavemem install --ide codex >/dev/null
        ;;
    opencode)
        log "registering cavemem for opencode"
        cavemem install --ide opencode >/dev/null
        ;;
    "")
        warn "JACKIN_AGENT unset — skipping cavemem IDE registration"
        ;;
    *)
        log "no cavemem support for JACKIN_AGENT=${JACKIN_AGENT} — skipping"
        ;;
esac
