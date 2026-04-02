[![Test](https://github.com/pkramek/claude-devcontainer/actions/workflows/test.yml/badge.svg)](https://github.com/pkramek/claude-devcontainer/actions/workflows/test.yml) [![License: Apache 2.0](https://img.shields.io/badge/license-Apache%202.0-blue.svg)](LICENSE) [![Tested: 27 images](https://img.shields.io/badge/tested-27%20base%20images-brightgreen.svg)](.github/workflows/test.yml)

# Claude Code DevContainer Feature

The official Anthropic devcontainer image forces you into a heavy Node.js base (~1.5 GB). Your team
already has a carefully tuned Python, Rust, Go, or Alpine image — likely one that's been through your
security team's review and lives in your approved registry. You should not need to throw that away to
use Claude Code.

This feature adds Claude Code CLI to **any** devcontainer base image with a single line in
`devcontainer.json`. Your base image stays yours; the feature handles the rest.

```json
{
  "features": {
    "ghcr.io/pkramek/claude-devcontainer/claude-code:1": {}
  }
}
```

## Why Not Just Use the Official Image?

Three reasons that actually matter in practice:

**1. Your image is already approved.**
In most enterprises, adding a new base image means a vulnerability scan, a security review, and a
long wait. Your golden image — the hardened `ubuntu:22.04`, the approved `python:3.11`, the internal
RHEL derivative — is already through all of that. This feature installs on top of it.

**2. Size is a real cost.**
Switching from an Alpine or slim Python base to the full Anthropic Node.js image means replacing your
entire environment with a ~1.5 GB monolith. With this feature, you add Claude Code and its Node.js
runtime (~120 MB of overhead) to your existing image instead of discarding it.

**3. Composability.**
DevContainers features exist so you can assemble an environment from pieces. The official Anthropic
image combines base OS + Node.js + Claude Code into one thing you can't extend cleanly. This feature
is the composable alternative: bring your own base, add only what you need.

## Options

| Option             | Type    | Default      | Description                                                                  |
| ------------------ | ------- | ------------ | ---------------------------------------------------------------------------- |
| `version`          | string  | `latest`     | Claude Code version (semver or `latest`). Pin this for teams.                |
| `nodeVersion`      | string  | `lts`        | Node.js version to install if not already present (≥ 18 required).          |
| `installPath`      | string  | `/usr/local` | Custom npm global prefix. Adds `<installPath>/bin` to PATH automatically.    |
| `enableMcpServers` | boolean | `false`      | Create a starter MCP server config at `~/.claude/mcp_servers.json`.          |
| `mountHostConfig`  | boolean | `false`      | Print a `devcontainer.json` mount snippet to wire up your host `~/.claude`.  |
| `shellCompletions` | boolean | `true`       | Install bash/zsh/fish completions (silently skipped if the shell is absent). |

### Examples

Pin a specific Claude Code version (recommended for teams):

```json
{
  "features": {
    "ghcr.io/pkramek/claude-devcontainer/claude-code:1": {
      "version": "1.2.3"
    }
  }
}
```

Python base with MCP servers enabled:

```json
{
  "image": "mcr.microsoft.com/devcontainers/python:3",
  "features": {
    "ghcr.io/pkramek/claude-devcontainer/claude-code:1": {
      "enableMcpServers": true
    }
  }
}
```

Custom install path (useful when `/usr/local` is read-only):

```json
{
  "features": {
    "ghcr.io/pkramek/claude-devcontainer/claude-code:1": {
      "installPath": "/opt/claude"
    }
  }
}
```

## Authentication

Three ways to authenticate inside the container:

**1. Browser login (recommended).** Run `claude login` in the container terminal. Opens an OAuth
browser window. Works in VS Code's integrated terminal with no extra configuration.

**2. Environment variable.** Pass your API key from the host:

```json
{
  "remoteEnv": {
    "ANTHROPIC_API_KEY": "${localEnv:ANTHROPIC_API_KEY}"
  }
}
```

**3. Mount host `~/.claude`.** Share your full host config — API keys, session tokens, preferences
— directly into the container:

```json
{
  "mounts": [
    "source=${localEnv:HOME}/.claude,target=/home/vscode/.claude,type=bind,consistency=cached,readonly"
  ]
}
```

> ⚠️ **Security:** This exposes your API keys inside the container. Only do this in trusted
> environments. Adjust the `target` path to match your container user's home directory (`/root`,
> `/home/node`, etc.). The `readonly` flag prevents Claude Code from writing settings or session
> data back to the host — if you need bidirectional sync, remove it and accept the risk.
>
> Set `mountHostConfig: true` in the feature options to get this snippet printed at build time with
> your actual home directory path pre-filled.

## Tested Base Images

Tested in CI against **27 amd64** base images and **2 arm64** images (QEMU emulation on
`ubuntu-latest` runners):

**Raw OS:** Ubuntu 22.04 / 24.04, Debian Bullseye / Bookworm, Alpine 3.19 / 3.20 / 3.21,
Arch Linux, Fedora 39 / 40, Rocky Linux 9, AlmaLinux 9, Amazon Linux 2023

**DevContainer bases:** `base:debian`, `base:ubuntu`, `base:alpine`, `universal:2`

**Language-specific:** Python 3, JavaScript/Node, TypeScript/Node, Rust, Go, C++, .NET, Java,
Ruby, PHP

See [`.github/workflows/test.yml`](.github/workflows/test.yml) for the full matrix.

## Known Limitations

**`nodeVersion` on Alpine and Arch.** Node.js is installed from the distro package manager
(`apk add nodejs` / `pacman -S nodejs`). The `nodeVersion` option is silently ignored on these
distributions — you get whatever version the distro ships. On Debian, Ubuntu, and the RHEL family,
the requested version is fetched via NodeSource.

**arm64 coverage.** The arm64 matrix covers Ubuntu 24.04 and Alpine 3.21 via QEMU emulation. Other
arm64 distributions should work but are not currently CI-tested.

**Claude Code and native addons.** Claude Code is currently pure JavaScript with no native addons,
so it runs on Alpine (musl libc) without issues. If that changes upstream, Alpine images may break
before a musl-compatible build is published. Check the CI badge before upgrading.

## Contributing

1. Fork and clone
2. Open in the devcontainer (`.devcontainer/devcontainer.json` runs `pre-commit install`
   automatically), **or** run `pre-commit install` manually after cloning
3. Changes live in `src/claude-code/install.sh` and `test/claude-code/`
4. Run `pre-commit run --all-files` before committing
5. Open a pull request against `develop`

## Publishing (Maintainers)

After the first release tag push, the GHCR package is created as **private**. To make it public:

1. Go to the repository's **Packages** tab
2. Click the `claude-code` package → **Package settings**
3. Under **Danger Zone**, change visibility to **Public**

## License

[Apache 2.0](LICENSE)
