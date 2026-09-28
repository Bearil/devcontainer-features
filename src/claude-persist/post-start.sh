#!/usr/bin/env bash
set -uo pipefail

# Wired as the Feature's postStartCommand. Memory changes daily while rebuilds are rare, so the
# memory snapshot is refreshed on every container start; the large home snapshot stays rebuild-only.
# Arg 1 = workspace folder; falls back to $PWD.

WORKSPACE_DIR="${1:-$PWD}"
# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"

migrate_legacy_snapshots
if [ -d "$SHARED_MEMORY" ]; then
    mirror_atomic "$SHARED_MEMORY" "$MEM_BACKUP"
fi
exit 0
