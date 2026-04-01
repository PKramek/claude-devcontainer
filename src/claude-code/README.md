# Claude Code

Install [Claude Code](https://docs.anthropic.com/en/docs/claude-code) CLI into
any devcontainer. Supports Debian, Ubuntu, Alpine, Arch, Fedora, RHEL, Rocky,
Alma, and Amazon Linux on amd64 and arm64.

## Usage

```json
{
    "features": {
        "ghcr.io/pkramek/claude-code-devcontainer/claude-code:1": {}
    }
}
```

## Options

| Option | Type | Default | Description |
|---|---|---|---|
| `version` | string | `latest` | Claude Code version (semver or `latest`) |
| `nodeVersion` | string | `lts` | Node.js version if not present (>= 18) |
| `installPath` | string | `/usr/local` | Custom npm global prefix |
| `enableMcpServers` | boolean | `false` | Create starter MCP config at `~/.claude/mcp_servers.json` |
| `mountHostConfig` | boolean | `false` | Log mount snippet for host `~/.claude` passthrough |
| `shellCompletions` | boolean | `true` | Install bash/zsh/fish completions |

## Examples

Pin a specific version:

```json
{
    "features": {
        "ghcr.io/pkramek/claude-code-devcontainer/claude-code:1": {
            "version": "1.0.0"
        }
    }
}
```

Enable MCP servers:

```json
{
    "features": {
        "ghcr.io/pkramek/claude-code-devcontainer/claude-code:1": {
            "enableMcpServers": true
        }
    }
}
```

## Authentication

Claude Code requires authentication. Set `ANTHROPIC_API_KEY` in your
devcontainer:

```json
{
    "remoteEnv": {
        "ANTHROPIC_API_KEY": "${localEnv:ANTHROPIC_API_KEY}"
    }
}
```

Or mount your host `~/.claude` directory (see `mountHostConfig` option).

## Notes

- Node.js >= 18 is required. If not present, this feature installs the current
  LTS release automatically.
- Shell completions are installed for bash, zsh, and fish if those directories
  exist in the container.
- The `enableMcpServers` option creates a starter config with secure permissions
  (`chmod 600`) owned by the container user.
