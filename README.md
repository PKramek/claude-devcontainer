# Claude Code DevContainer Feature

[![Test](https://github.com/pkramek/claude-code-devcontainer/actions/workflows/test.yml/badge.svg)](https://github.com/pkramek/claude-code-devcontainer/actions/workflows/test.yml)

Install [Claude Code](https://docs.anthropic.com/en/docs/claude-code) into any
devcontainer. Supports Debian, Ubuntu, Alpine, Arch, Fedora, RHEL, Rocky, Alma,
and Amazon Linux on amd64 and arm64.

## Usage

Add this feature to your `devcontainer.json`:

```json
{
    "features": {
        "ghcr.io/pkramek/claude-code-devcontainer/claude-code:1": {}
    }
}
```

### Options

| Option | Type | Default | Description |
|---|---|---|---|
| `version` | string | `latest` | Claude Code version (semver or `latest`) |
| `nodeVersion` | string | `lts` | Node.js version if not present (>= 18) |
| `installPath` | string | `/usr/local` | Custom npm global prefix |
| `enableMcpServers` | boolean | `false` | Create starter MCP config |
| `mountHostConfig` | boolean | `false` | Log mount snippet for host config |
| `shellCompletions` | boolean | `true` | Install bash/zsh/fish completions |

### Examples

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

Claude Code requires authentication. Three options:

1. **Browser login (recommended):** Run `claude login` in the container terminal.
   Claude Code opens a browser window for OAuth authentication. Works out of the
   box in VS Code's integrated terminal with no configuration needed.

2. **Environment variable:** Set `ANTHROPIC_API_KEY` in your devcontainer:

   ```json
   {
       "remoteEnv": {
           "ANTHROPIC_API_KEY": "${localEnv:ANTHROPIC_API_KEY}"
       }
   }
   ```

3. **Mount host config:** Mount your local `~/.claude` directory:

   ```json
   {
       "mounts": [
           "source=${localEnv:HOME}/.claude,target=${localEnv:HOME}/.claude,type=bind,consistency=cached,readonly"
       ]
   }
   ```

   > **Note:** Replace the `target` path with your container user's home directory
   > (e.g., `/home/vscode`, `/root`, or `/home/node` depending on your base image).
   > **Security warning:** This exposes your API keys inside the container.

## Tested Images

This feature is tested on 27 amd64 + 4 arm64 base images. See the
[test workflow](.github/workflows/test.yml) for the full matrix.

## Runtime Verification

Add this to your `devcontainer.json` to verify Claude Code at container start:

```json
{
    "postCreateCommand": "claude --version || true"
}
```

## Publishing (Maintainers)

After the first release tag push, the GHCR package is created as **private**.
You must manually change it to public:

1. Go to the repository's **Packages** tab
2. Click the `claude-code` package
3. Go to **Package settings**
4. Under **Danger Zone**, change visibility to **Public**

## Contributing

1. Fork the repository
2. Open in a devcontainer (`.devcontainer/devcontainer.json` is provided)
3. Make changes
4. Run `pre-commit run --all-files` before committing
5. Open a pull request

## License

MIT
