# Claude Code

Install [Claude Code](https://docs.anthropic.com/en/docs/claude-code) CLI into
any devcontainer. Supports Debian, Ubuntu, Alpine, Arch, Fedora, RHEL, Rocky,
Alma, and Amazon Linux on amd64 and arm64.

## Usage

```json
{
  "features": {
    "ghcr.io/pkramek/claude-devcontainer/claude-code:1": {}
  }
}
```

## Options

| Option             | Type    | Default      | Description                                               |
| ------------------ | ------- | ------------ | --------------------------------------------------------- |
| `version`          | string  | `latest`     | Claude Code version (semver or `latest`)                  |
| `nodeVersion`      | string  | `lts`        | Node.js version if not present (>= 18)                    |
| `installPath`      | string  | `/usr/local` | Custom npm global prefix                                  |
| `enableMcpServers` | boolean | `false`      | Create starter MCP config at `~/.claude/mcp_servers.json` |
| `mountHostConfig`  | boolean | `false`      | Log mount snippet for host `~/.claude` passthrough        |
| `shellCompletions` | boolean | `true`       | Install bash/zsh/fish completions                         |

## Examples

Pin a specific version:

```json
{
  "features": {
    "ghcr.io/pkramek/claude-devcontainer/claude-code:1": {
      "version": "1.0.0"
    }
  }
}
```

Enable MCP servers:

```json
{
  "features": {
    "ghcr.io/pkramek/claude-devcontainer/claude-code:1": {
      "enableMcpServers": true
    }
  }
}
```

## Authentication

Claude Code requires authentication. Three options:

1. **Browser login (recommended):** Run `claude login` in the container terminal.
   Works out of the box in VS Code's integrated terminal.

2. **Environment variable:**

   ```json
   {
     "remoteEnv": {
       "ANTHROPIC_API_KEY": "${localEnv:ANTHROPIC_API_KEY}"
     }
   }
   ```

3. **Mount host config:** Use the `mountHostConfig` option to get the two-mount
   snippet, then add both entries to `mounts` in your `devcontainer.json`. Two
   mounts are required: `~/.claude/` holds session data and MCP config;
   `~/.claude.json` holds global settings and onboarding state. Mounting only
   the directory causes the onboarding wizard to re-run on every container
   start. Adjust both `target` paths to match your container user's home
   directory.

## Notes

- Node.js >= 18 is required. If not present, this feature installs the current
  LTS release automatically.
- Shell completions for bash, zsh, and fish are installed automatically. Set
  `shellCompletions` to `false` to skip. To regenerate completions matching
  your exact installed version, run:
  `claude completions bash > /usr/share/bash-completion/completions/claude`
  (adjust path and shell name as needed).
- The `enableMcpServers` option creates a starter config with secure permissions
  (`chmod 600`) owned by the container user.
