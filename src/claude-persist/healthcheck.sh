#!/usr/bin/env bash
# Health check for the claude-persist Feature. Run after a (re)build:
#   bash /usr/local/share/claude-persist/healthcheck.sh
# Exit 0 = healthy, non-zero = a critical check failed.
set -uo pipefail

fail=0
ok()   { printf '  [ok]   %s\n' "$1"; }
bad()  { printf '  [FAIL] %s\n' "$1"; fail=1; }
info() { printf '  [--]   %s\n' "$1"; }

CLAUDE_HOME="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
SHARED_MEMORY="$HOME/.claude-shared-memory"

echo "== Persistence (critical) =="
if findmnt -no TARGET "$CLAUDE_HOME" >/dev/null 2>&1; then
    ok "~/.claude is a mount (claude-home volume) -> sessions survive rebuild"
else
    bad "~/.claude is NOT a separate mount -> claude-home volume didn't apply (check devcontainer.json 'mounts')"
fi
owner="$(stat -c '%U' "$CLAUDE_HOME" 2>/dev/null || echo '?')"
if [ "$owner" = "$(id -un)" ]; then
    ok "~/.claude owned by $owner"
else
    bad "~/.claude owned by '$owner' (expected $(id -un)) -> chown failed"
fi
if [ -f "$CLAUDE_HOME/.claude.json" ]; then
    ok "config .claude.json is inside the volume dir (survives rebuild)"
elif [ -f "$HOME/.claude.json" ]; then
    bad "config at ephemeral $HOME/.claude.json -> set CLAUDE_CONFIG_DIR=$CLAUDE_HOME"
else
    info ".claude.json not created yet (appears after the first Claude run)"
fi

echo "== Shared memory =="
if findmnt -no TARGET "$SHARED_MEMORY" >/dev/null 2>&1; then
    ok "~/.claude-shared-memory mounted -> memory sharing ENABLED"
    total=0
    while IFS= read -r m; do
        total=$((total + 1))
        if [ -L "$m" ] && [ "$(readlink -f "$m")" = "$(readlink -f "$SHARED_MEMORY")" ]; then
            ok "memory linked: $m"
        else
            bad "memory NOT linked to shared volume: $m"
        fi
    done < <(find "$CLAUDE_HOME/projects" -maxdepth 2 -name memory 2>/dev/null)
    [ "$total" -eq 0 ] && bad "sharing enabled but no projects/<slug>/memory symlink -> post-create didn't wire it"
else
    info "shared-memory volume not mounted -> memory is per-container (sharing disabled). OK if intentional."
fi

echo "== Tools (informational; depends on the feature options / your Dockerfile) =="
for t in claude go node gh glab kubectl gci; do
    command -v "$t" >/dev/null 2>&1 && info "$t: present" || info "$t: (absent)"
done

echo
if [ "$fail" -eq 0 ]; then
    echo "RESULT: healthy"
else
    echo "RESULT: problems found (see [FAIL] above)"
fi
exit "$fail"
