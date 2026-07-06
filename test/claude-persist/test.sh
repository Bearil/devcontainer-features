#!/bin/bash
set -e

# 'test/_global' lib provided by `devcontainer features test`.
source dev-container-features-test-lib

check "post-create script installed"  test -f /usr/local/share/claude-persist/post-create.sh
check "post-create is executable"      test -x /usr/local/share/claude-persist/post-create.sh
check "healthcheck installed"          test -f /usr/local/share/claude-persist/healthcheck.sh
check "CLAUDE_CONFIG_DIR exported"     bash -c '[ -n "${CLAUDE_CONFIG_DIR:-}" ]'
check "git safe.directory set"         bash -c "git config --system --get-all safe.directory | grep -q '\\*'"
check "post-create runs idempotently"  bash -c 'HOME=$(mktemp -d) bash /usr/local/share/claude-persist/post-create.sh "$(mktemp -d)"'

reportResults
