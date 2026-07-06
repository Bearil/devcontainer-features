#!/usr/bin/env bash
# Build-time install for the claude-persist Feature (runs as root). Places the lifecycle scripts into
# the image and installs any opt-in CLIs. Feature options arrive as UPPERCASE env vars (tools -> TOOLS).
set -euo pipefail

FEATURE_DIR="$(cd "$(dirname "$0")" && pwd)"
SHARE=/usr/local/share/claude-persist

install -d "$SHARE"
install -m 0755 "$FEATURE_DIR/post-create.sh" "$SHARE/post-create.sh"
install -m 0755 "$FEATURE_DIR/healthcheck.sh" "$SHARE/healthcheck.sh"

# Workspace files are commonly root-owned while remoteUser differs -> git "dubious ownership".
git config --system --add safe.directory '*' 2>/dev/null || true

ARCH="$(dpkg --print-architecture 2>/dev/null || echo amd64)"
TOOLS="${TOOLS:-}"
want() { case ",$TOOLS," in *",$1,"*) return 0 ;; *) return 1 ;; esac; }

if [ -n "$TOOLS" ] && command -v apt-get >/dev/null 2>&1; then
    apt-get update
    apt-get install -y --no-install-recommends curl ca-certificates gnupg tar >/dev/null
fi

if want gh; then
    mkdir -p /etc/apt/keyrings
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
        -o /etc/apt/keyrings/githubcli-archive-keyring.gpg
    chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
    echo "deb [arch=$ARCH signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
        > /etc/apt/sources.list.d/github-cli.list
    apt-get update && apt-get install -y --no-install-recommends gh
fi

if want glab; then
    GLAB_VERSION="1.106.0"
    curl -fsSL -o /tmp/glab.tgz \
        "https://gitlab.com/gitlab-org/cli/-/releases/v${GLAB_VERSION}/downloads/glab_${GLAB_VERSION}_linux_${ARCH}.tar.gz"
    mkdir -p /tmp/glab && tar -xzf /tmp/glab.tgz -C /tmp/glab
    install -m 0755 /tmp/glab/bin/glab /usr/local/bin/glab
    rm -rf /tmp/glab.tgz /tmp/glab
fi

if want kubectl; then
    curl -fsSL -o /usr/local/bin/kubectl \
        "https://dl.k8s.io/release/$(curl -fsSL https://dl.k8s.io/release/stable.txt)/bin/linux/${ARCH}/kubectl"
    chmod +x /usr/local/bin/kubectl
fi

if want gci; then
    if command -v go >/dev/null 2>&1; then
        GOBIN=/usr/local/bin go install github.com/daixiang0/gci@latest || true
    else
        echo "claude-persist: gci requested but Go not found — skipping (add the Go feature/base image)."
    fi
fi

rm -rf /var/lib/apt/lists/* 2>/dev/null || true
echo "claude-persist: installed (tools='${TOOLS:-none}')."
