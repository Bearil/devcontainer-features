#!/usr/bin/env bash
set -uo pipefail

# Installed by the claude-persist Feature and wired as its postCreateCommand. Persists Claude Code state
# across rebuilds and (optionally) shares memory across parallel workspace copies. Pairs with volume
# mounts declared in the consuming project's devcontainer.json:
#   <folder>-claude-home    -> ~/.claude              per-copy: sessions + credentials + config
#   <project>-claude-memory -> ~/.claude-shared-memory per-project shared: memory files (optional)
# Arg 1 = workspace folder (the Feature passes ${containerWorkspaceFolder}); falls back to $PWD.

WORKSPACE_DIR="${1:-$PWD}"
CLAUDE_HOME="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
SHARED_MEMORY="$HOME/.claude-shared-memory"
OWNER="$(id -un):$(id -gn)"
BACKUP="$WORKSPACE_DIR/_scratch/.claude-home-backup"
MEM_BACKUP="$WORKSPACE_DIR/_scratch/.claude-memory-backup"

# Mirror a dir to a host snapshot — only if it has content (never overwrite a good snapshot with an
# empty/lost volume), via atomic swap (an interruption can't leave a half-written snapshot).
mirror_atomic() {
    local src="$1" dst="$2" tmp="$2.tmp"
    [ -n "$(ls -A "$src" 2>/dev/null || true)" ] || return 0
    mkdir -p "$(dirname "$dst")"
    rm -rf "$tmp"
    if cp -a "$src/." "$tmp/" 2>/dev/null; then
        rm -rf "$dst" && mv "$tmp" "$dst"
        echo "[claude-persist] backup refreshed: $dst"
    else
        rm -rf "$tmp"
    fi
    return 0
}

mkdir -p "$CLAUDE_HOME"
sudo chown -R "$OWNER" "$CLAUDE_HOME" 2>/dev/null || chown -R "$OWNER" "$CLAUDE_HOME" 2>/dev/null || true

# Seed sessions/credentials/config once from the host snapshot (empty volume only) — a non-empty volume
# skips this, so accumulated state is never overwritten.
if [ -z "$(ls -A "$CLAUDE_HOME" 2>/dev/null || true)" ] && [ -d "$BACKUP" ]; then
    cp -a "$BACKUP/." "$CLAUDE_HOME/"
    echo "[claude-persist] seeded $CLAUDE_HOME from $BACKUP"
fi

# Idempotent migration: a legacy ~/.claude.json (written before CLAUDE_CONFIG_DIR pointed config into the
# volume) sits in ephemeral $HOME and would be lost. Pull it in once — no-op if absent or already present.
if [ -f "$HOME/.claude.json" ] && [ ! -e "$CLAUDE_HOME/.claude.json" ]; then
    cp -a "$HOME/.claude.json" "$CLAUDE_HOME/.claude.json" 2>/dev/null || true
    echo "[claude-persist] migrated legacy ~/.claude.json -> $CLAUDE_HOME/.claude.json"
fi

# Share project memory across parallel copies (chat history stays per-copy). Active only when the
# shared-memory volume is mounted. Each copy symlinks its own slug's memory/ dir to the shared volume.
if [ -d "$SHARED_MEMORY" ]; then
    sudo chown -R "$OWNER" "$SHARED_MEMORY" 2>/dev/null || chown -R "$OWNER" "$SHARED_MEMORY" 2>/dev/null || true

    # Disaster recovery: restore shared memory from the host snapshot if the volume is empty.
    if [ -z "$(ls -A "$SHARED_MEMORY" 2>/dev/null || true)" ] && [ -d "$MEM_BACKUP" ]; then
        cp -a "$MEM_BACKUP/." "$SHARED_MEMORY/" 2>/dev/null || true
        echo "[claude-persist] seeded shared memory from $MEM_BACKUP"
    fi

    SLUG="$(printf '%s' "$WORKSPACE_DIR" | sed 's#/#-#g')"
    MEMDIR="$CLAUDE_HOME/projects/$SLUG/memory"
    if [ ! -L "$MEMDIR" ]; then
        mkdir -p "$(dirname "$MEMDIR")"
        if [ -d "$MEMDIR" ]; then
            cp -an "$MEMDIR/." "$SHARED_MEMORY/" 2>/dev/null || true
            rm -rf "$MEMDIR"
        fi
        ln -s "$SHARED_MEMORY" "$MEMDIR"
        echo "[claude-persist] memory: $MEMDIR -> $SHARED_MEMORY"
    fi
fi

# Refresh host-side disaster-recovery snapshots from the (now-current) volumes.
mirror_atomic "$CLAUDE_HOME" "$BACKUP"
if [ -d "$SHARED_MEMORY" ]; then
    mirror_atomic "$SHARED_MEMORY" "$MEM_BACKUP"
fi
exit 0
