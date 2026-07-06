# devcontainer-features

Personal/team [Dev Container Features](https://containers.dev/implementors/features/). Published to
GitHub Container Registry (ghcr.io) by [`.github/workflows/release.yml`](.github/workflows/release.yml)
on every push to `main`.

## `claude-persist`

Keeps Claude Code state across dev container rebuilds, and optionally shares memory across parallel
copies of a workspace — as a single versioned Feature instead of copy-pasted `.devcontainer` scripts.

It provides:
- **Persistence** — `CLAUDE_CONFIG_DIR` points Claude's config at `~/.claude` so config, credentials,
  sessions and memory all live in one place; a `postCreateCommand` seeds/refreshes a host-side
  disaster-recovery snapshot and migrates a legacy `~/.claude.json` in. Idempotent — a plain rebuild
  self-configures.
- **Shared memory (optional)** — if a second volume is mounted, each copy's `projects/<slug>/memory`
  is symlinked to it, so project memory is shared while chat sessions stay per-copy.
- **git safe.directory** and opt-in CLIs (`gh`, `glab`, `kubectl`, `gci`).

### Usage

The Feature carries the machinery; the **volume mounts stay in your project** because their names are
project-specific (the memory key isolates one project's memory from another's).

```jsonc
{
  "features": {
    "ghcr.io/Bearil/devcontainer-features/claude-persist:0": {
      "tools": "gh,glab"
    }
  },
  "mounts": [
    // per-copy: sessions + credentials + config (name auto-unique per folder)
    "source=${localWorkspaceFolderBasename}-claude-home,target=/home/vscode/.claude,type=volume",
    // per-PROJECT shared memory (optional). Same key for all copies of THIS project, distinct per project.
    "source=MYPROJECT-claude-memory,target=/home/vscode/.claude-shared-memory,type=volume"
  ],
  "remoteUser": "vscode"
}
```

- Omit the second mount to disable memory sharing.
- Default `CLAUDE_CONFIG_DIR` is `/home/vscode/.claude`. For a different `remoteUser`, override it in
  your own `containerEnv` and match the mount `target`.

### Options

| Option  | Default | Description |
|---------|---------|-------------|
| `tools` | `""`    | Comma-separated extra CLIs: `gh,glab,kubectl,gci` (`gci` needs Go present). |

### Verify after a rebuild

```bash
bash /usr/local/share/claude-persist/healthcheck.sh   # exit 0 = healthy
```

### Versioning

- `…/claude-persist:0` — floating major, good for your own machines during active iteration.
- Pin a specific version (e.g. `:0.1.0`) for teammates so they don't pick up half-baked changes.
- Bump `version` in `src/claude-persist/devcontainer-feature.json` on a meaningful change.

## Local development

```bash
npm install -g @devcontainers/cli
devcontainer features test --features claude-persist \
  --base-image mcr.microsoft.com/devcontainers/base:ubuntu .
```

## First-time setup

1. Create an empty GitHub repo named `devcontainer-features` (public = teammates can pull freely).
2. Push this directory to it.
3. First push to `main` runs the release workflow → publishes `ghcr.io/Bearil/devcontainer-features/claude-persist`.
4. In GitHub → Packages, set the package visibility to **public** (once) so pulls don't need auth.
