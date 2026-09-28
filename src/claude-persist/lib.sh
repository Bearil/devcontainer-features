#!/usr/bin/env bash
# Shared by post-create.sh and post-start.sh. Expects WORKSPACE_DIR to be set by the caller.

CLAUDE_HOME="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
SHARED_MEMORY="$HOME/.claude-shared-memory"
BACKUP_ROOT="$WORKSPACE_DIR/.claude-backup"
BACKUP="$BACKUP_ROOT/home"
MEM_BACKUP="$BACKUP_ROOT/memory"

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

# Snapshots used to live in _scratch/, a folder projects treat as disposable. Move them out once;
# a real legacy dir is never deleted while its new home already holds data.
migrate_legacy_snapshot() {
    local legacy="$1" dst="$2"
    if [ -L "$legacy" ]; then
        [ -e "$dst" ] && rm -f "$legacy"
        return 0
    fi
    [ -d "$legacy" ] || return 0
    if [ -e "$dst" ]; then
        echo "[claude-persist] both $legacy and $dst exist — keeping both, remove the legacy one by hand"
        return 0
    fi
    mkdir -p "$(dirname "$dst")"
    mv "$legacy" "$dst" && echo "[claude-persist] snapshot moved: $legacy -> $dst"
}

migrate_legacy_snapshots() {
    migrate_legacy_snapshot "$WORKSPACE_DIR/_scratch/.claude-home-backup" "$BACKUP"
    migrate_legacy_snapshot "$WORKSPACE_DIR/_scratch/.claude-memory-backup" "$MEM_BACKUP"
}
