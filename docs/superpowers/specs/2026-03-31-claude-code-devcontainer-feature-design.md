# Claude Code DevContainer Feature — Design Spec

**Date:** 2026-03-31
**Status:** Draft (v3 — revised after two rounds of architecture, shell, and CI/CD reviews)
**Goal:** Build an industry-standard, universally compatible DevContainer Feature that installs Claude Code into any existing devcontainer seamlessly.

---

## 1. Overview

A DevContainer Feature published to `ghcr.io` that installs Claude Code via npm into any devcontainer environment. It auto-detects the host OS and package manager, ensures Node.js is available, installs Claude Code globally, and optionally sets up shell completions, host config mounting documentation, and MCP server stubs.

The feature must work on Debian, Ubuntu, Alpine, Arch, Fedora/RHEL, Rocky/Alma, and Amazon Linux across amd64 and arm64 architectures with zero disruption to the user's existing devcontainer setup.

## 2. Repository Structure

```
claude-code-devcontainer/
├── src/
│   └── claude-code/
│       ├── devcontainer-feature.json   # Feature manifest
│       └── install.sh                  # Installation script (bash)
├── test/
│   └── claude-code/
│       ├── test.sh                     # Default test (shared assertions)
│       ├── scenarios.json              # Test scenario definitions
│       ├── test_default_options.sh     # Scenario: default options
│       ├── test_completions_disabled.sh # Scenario: shellCompletions=false
│       ├── test_mcp_enabled.sh         # Scenario: enableMcpServers=true
│       ├── test_custom_version.sh      # Scenario: pinned version
│       ├── test_node_preinstalled.sh   # Scenario: Node.js already present
│       ├── test_custom_install_path.sh # Scenario: custom installPath
│       ├── test_mount_host_config.sh   # Scenario: mountHostConfig=true
│       ├── test_alpine_specific.sh     # Scenario: Alpine-specific behavior
│       └── test_idempotency.sh         # Scenario: double-install idempotency
├── .github/
│   └── workflows/
│       ├── test.yml                    # CI: lint + test matrix (PRs + push to main)
│       └── release.yml                 # CD: publish to ghcr.io (tag push)
├── .devcontainer/
│   └── devcontainer.json              # Self-development devcontainer for contributors
├── .pre-commit-config.yaml             # Pre-commit hooks
├── .shellcheckrc                       # ShellCheck configuration
├── .editorconfig                       # Formatting standards (consumed by shfmt)
├── LICENSE                             # MIT
└── README.md                           # Usage docs with CI status badge
```

Follows the official `devcontainers/feature-template` convention. Per-scenario test scripts enable targeted assertions (positive and negative) for each option combination.

## 3. Feature Manifest (`devcontainer-feature.json`)

### Metadata

- **id:** `claude-code`
- **name:** `Claude Code`
- **version:** `1.0.0`
- **description:** Install Claude Code CLI into any devcontainer
- **documentationURL:** Points to repo README
- **licenseURL:** Points to LICENSE file in repo
- **containerEnv:** Sets `CLAUDE_CODE_INSTALLED=true` — documented as a stable public contract for downstream features/scripts to detect Claude Code presence
- **installsAfter:** `["ghcr.io/devcontainers/features/node"]` — soft ordering hint only, NOT a hard dependency. The install script is fully self-contained and will install Node.js on its own if needed.

### Options

| Option             | Type    | Default        | Description                                                                                                                                                                                                 |
| ------------------ | ------- | -------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `version`          | string  | `"latest"`     | Claude Code version to install (semver or `"latest"`. Note: `"latest"` is non-deterministic across builds — recommend pinning for teams)                                                                    |
| `nodeVersion`      | string  | `"lts"`        | Node.js version to install if not already present. Resolved via NodeSource, not distro packages. Minimum floor: Node.js >= 18.                                                                              |
| `installPath`      | string  | `"/usr/local"` | Custom npm global install prefix. The feature will ensure `<installPath>/bin` is on PATH for all shell contexts.                                                                                            |
| `enableMcpServers` | boolean | `false`        | Drop a starter MCP configuration file at `~/.claude/mcp_servers.json` (create-if-absent, never overwrite).                                                                                                  |
| `mountHostConfig`  | boolean | `false`        | **Documentation-only.** When true, the feature adds a comment to build output with the `mounts` snippet users should add to their `devcontainer.json`. Does NOT auto-mount. Defaults to false for security. |
| `shellCompletions` | boolean | `true`         | Install shell completions for detected shells (bash, zsh, fish).                                                                                                                                            |

### Lifecycle Hooks

- **`postCreateCommand`:** Runs `claude --version || true` as a **non-blocking** runtime verification step. Runs as the `remoteUser` (non-root). Logs the installed version for diagnostics. The `|| true` ensures a PATH issue in the runtime context does not prevent container creation — it logs the failure for diagnosis rather than blocking the user.

### Removed: `autoUpdate` Option

The original `autoUpdate` option was removed because `install.sh` runs at image build time only. "Update on every rebuild" would require a `postStartCommand` that runs `npm install -g` on every container start, which is slow and network-dependent. Users who want the latest version should rebuild their image (`devcontainer rebuild`). This is the standard pattern for DevContainer Features.

### Security Considerations for `mountHostConfig`

Mounting `~/.claude` from the host exposes API keys and tokens inside the container. The feature defaults `mountHostConfig` to `false` and documents:

- The security implications (container compromise = credential exposure)
- The cross-platform mount syntax using `${localEnv:HOME}` for macOS/Linux/WSL2 compatibility
- That `~/.claude` path may change in future Claude Code versions

The feature does NOT auto-mount. It provides documentation only, leaving the security decision to the user.

## 4. Installation Script (`install.sh`)

### Shell Choice: Bash (not POSIX sh)

The script uses `#!/usr/bin/env bash` explicitly. Rationale:

- POSIX sh (`dash` on Debian, `ash` on Alpine) has unreliable `set -e` semantics and lacks arrays, `[[ ]]`, and `pipefail`
- Bash is pre-installed on Debian, Ubuntu, Fedora, Arch, RHEL, Rocky, Alma, and Amazon Linux
- ShellCheck is configured with `--shell=bash` via `.shellcheckrc`

### Alpine Bash Bootstrap

**Critical implementation detail:** The DevContainer CLI invokes `install.sh` via `/bin/sh`, NOT via the shebang. This means the first lines of the script execute under Alpine's BusyBox `ash`. The script must:

1. Begin with a POSIX-compatible bootstrap section that installs bash
2. Re-exec itself under bash: `exec bash "$0" "$@"`
3. Only then use bash-specific features

```bash
#!/usr/bin/env bash
# --- POSIX-compatible bootstrap (runs under /bin/sh on Alpine) ---
if [ -z "${BASH_VERSION:-}" ]; then
    # Not running under bash — install it and re-exec
    if command -v apk > /dev/null 2>&1; then
        apk add --no-cache bash > /dev/null 2>&1
    fi
    exec bash "$0" "$@"
fi
# --- From here on, bash is guaranteed ---
```

This pattern is used by other DevContainer Features (e.g., the official `common-utils` feature) and is the standard approach for bash-dependent install scripts.

### Error Handling Strategy

```bash
# (After bash bootstrap — see Alpine Bootstrap section above)
set -Eeuo pipefail
# -E (errtrace): ERR trap propagates into functions and subshells
# -e: exit on error
# -u: error on unset variables
# -o pipefail: pipe fails if any command fails

FEATURE_LOG_PREFIX="[claude-code feature]"

# Debug mode: set -x for verbose tracing
if [[ "${DEBUG:-false}" == "true" ]]; then set -x; fi

# ERR trap for diagnostics (single quotes: $LINENO/$? expand at trap time, not definition time)
trap 'echo "${FEATURE_LOG_PREFIX} ERROR: Failed at line ${LINENO}. Exit code: $?" >&2' ERR

# EXIT trap for cleanup (also fires on INT/TERM for defense-in-depth)
trap cleanup EXIT INT TERM

TEMP_DIR=""  # Set to mktemp -d result when needed
cleanup() {
    [[ -n "${TEMP_DIR}" ]] && rm -rf "${TEMP_DIR}" 2>/dev/null || true
}

log_info()  { echo "${FEATURE_LOG_PREFIX} $*"; }
log_warn()  { echo "${FEATURE_LOG_PREFIX} WARNING: $*" >&2; }
log_error() { echo "${FEATURE_LOG_PREFIX} ERROR: $*" >&2; }
log_debug() { if [[ "${DEBUG:-false}" == "true" ]]; then echo "${FEATURE_LOG_PREFIX} DEBUG: $*"; fi; }
```

**Debug mode:** Set `DEBUG=true` environment variable to enable verbose logging including `set -x` tracing. Invaluable for CI failure diagnosis.

### Input Validation

All user-supplied options are validated before use in shell commands:

```bash
# Validate version: must be "latest" or semver-like (digits, dots, hyphens, plus)
validate_version() {
    local ver="$1"
    if [[ "${ver}" == "latest" ]]; then return 0; fi
    if [[ ! "${ver}" =~ ^[0-9][0-9a-zA-Z.+-]*$ ]]; then
        log_error "Invalid version '${ver}'. Must be 'latest' or a valid semver string."
        exit 1
    fi
}

# Validate installPath: must be absolute, no special characters
validate_install_path() {
    local path="$1"
    if [[ ! "${path}" =~ ^/[a-zA-Z0-9/_.-]+$ ]]; then
        log_error "Invalid installPath '${path}'. Must be an absolute path with no special characters."
        exit 1
    fi
}
```

These are **safety gates** (preventing shell injection), not correctness gates. npm will reject invalid version strings with its own error message. The validation here prevents dangerous characters from reaching shell interpolation.

### Step 1: Environment Detection

- Detect OS family via `/etc/os-release` `ID` and `ID_LIKE` fields
- Supported families and their package managers:
  - Debian/Ubuntu: `apt-get`
  - Alpine: `apk`
  - Arch: `pacman`
  - Fedora/RHEL/Rocky/Alma/Amazon Linux: `dnf` (fallback `yum`)
- Detect architecture via `uname -m` (map `x86_64` -> `amd64`, `aarch64` -> `arm64`)
- Check if Node.js is already on PATH and its version

### Step 2: Dependency Installation

**On Alpine:** Bash is installed by the POSIX-compatible bootstrap section (see Alpine Bash Bootstrap above). By the time Step 2 runs, bash is already available.

**Base dependencies** (installed if missing): `curl`, `git`, `ca-certificates`

All package manager invocations use non-interactive flags:

- `apt-get -y`
- `apk add --no-cache`
- `pacman -S --noconfirm --needed`
- `dnf -y` / `yum -y`

**Node.js installation decision tree:**

1. If Node.js exists on PATH AND version >= 18: **use it, do not install**
2. If Node.js exists but version < 18: **log warning, install requested version via NodeSource** which overwrites the system Node.js in-place (same `/usr/bin/node` path). The old version is replaced, not kept alongside. This ensures PATH is unambiguous.
3. If Node.js is absent: **install via NodeSource** (Debian/Ubuntu/Fedora/RHEL) or **distro package** (Alpine `apk add nodejs npm`, Arch `pacman -S nodejs npm`) at the requested `nodeVersion`
4. `"lts"` resolves to the current LTS version number via NodeSource's release metadata
5. **Post-install version check (Alpine/Arch):** After distro package install, verify the installed Node.js is >= 18. If not, fail with a clear error: `"Node.js $(node --version) from distro packages is below minimum 18. Use a newer base image or set nodeVersion to install via NodeSource."`

**Why NodeSource over nvm/fnm:** DevContainer Features run as root at build time. `nvm` is user-scoped and creates PATH complications for the remote user. NodeSource installs system-wide Node.js that is available to all users and all shell contexts.

**Alpine musl consideration:** Claude Code is distributed as a JavaScript package via npm (no native binary addons). Therefore, musl vs glibc is NOT a concern — no `libc6-compat` or `gcompat` needed. If this assumption changes (e.g., Claude Code adds native modules), this section must be revisited and Alpine support may need to be reconsidered.

**Proxy/registry support:** The script respects `HTTP_PROXY`, `HTTPS_PROXY`, `NO_PROXY`, and `npm_config_registry` environment variables. No special handling needed — npm and curl honor these natively.

**npm retry:** The `npm install` command uses npm's built-in `--fetch-retries=3` to handle transient registry failures (503s, timeouts). Combined with the `timeout 300` wrapper, this provides resilience without custom retry logic.

### Step 3: PATH Configuration for Custom `installPath` (before install)

If `installPath` is not `/usr/local` (which is already on PATH), the feature ensures discoverability **before** running `npm install`:

1. Update `PATH` in the current script context immediately (so `claude` is findable for verification)
2. Create `/etc/profile.d/claude-code.sh` for bash/zsh login shells in future sessions
3. Set `ENV` variable pointing to a script for Alpine ash non-login shells
4. Use `npm install --prefix` flag instead of `npm config set prefix` to avoid polluting the global npmrc (which would affect the remote user's future npm operations)

### Step 4: Claude Code Installation

```bash
# Use --prefix flag (less invasive than npm config set prefix)
if [[ "${INSTALL_PATH}" != "/usr/local" ]]; then
    export PATH="${INSTALL_PATH}/bin:${PATH}"
    timeout 300 npm install -g --prefix "${INSTALL_PATH}" --fetch-retries=3 "@anthropic-ai/claude-code@${VERSION}" || {
        log_error "Failed to install Claude Code. Check network connectivity and npm registry access."
        exit 1
    }
else
    timeout 300 npm install -g --fetch-retries=3 "@anthropic-ai/claude-code@${VERSION}" || {
        log_error "Failed to install Claude Code. Check network connectivity and npm registry access."
        exit 1
    }
fi

# Verify installation (PATH is already set from Step 3)
claude --version || {
    log_error "Claude Code installed but 'claude' command not found on PATH."
    exit 1
}
```

The `timeout 300` (5 minutes) prevents indefinite hangs on network issues during CI or restricted environments.

### Step 5: Batteries-Included Setup

**Shell completions** (`shellCompletions=true`):

- Detect available shells by checking for their completion directories
- Bash: `/etc/bash_completion.d/claude` (Debian/Ubuntu/Fedora) or `/usr/share/bash-completion/completions/claude` (Arch/Alpine)
- Zsh: `/usr/share/zsh/site-functions/_claude`
- Fish: `/usr/share/fish/vendor_completions.d/claude.fish` (detected dynamically — path may vary on Alpine depending on Fish installation method)
- **Graceful degradation:** If completion installation fails, log a warning but do NOT abort the build

**MCP servers** (`enableMcpServers=true`):

- Target file: `${_REMOTE_USER_HOME}/.claude/mcp_servers.json`
- Strategy: **create-if-absent** — never overwrite an existing file
- Content: minimal starter config with comments explaining how to extend
- Owned by `$_REMOTE_USER`

**Host config documentation** (`mountHostConfig=true`):

- Logs the following snippet to build output:
  ```
  To mount your host Claude config, add this to your devcontainer.json:
  "mounts": ["source=${localEnv:HOME}/.claude,target=/home/${_REMOTE_USER}/.claude,type=bind,consistency=cached"]
  ```
- Does NOT auto-mount (security decision documented in Section 3)

### Step 6: Permissions and Cleanup

**Remote user detection** (using DevContainer-provided variables):

1. Use `$_REMOTE_USER` if set
2. Else use `$_CONTAINER_USER` if set
3. Else detect first non-root user from `/etc/passwd` with a valid shell
4. Else fall back to `root`

Home directory: use `$_REMOTE_USER_HOME` if set, else look up via `getent passwd "${DETECTED_USER}" | cut -d: -f6`. **Do NOT use `eval echo ~${user}`** — this is a code injection risk if the username contains unexpected characters.

**Ownership:** Set `chown` on specific paths only (never `chown -R` on the entire home directory):

- `~/.claude/` directory (if created by this feature)
- `~/.claude/mcp_servers.json` (if created by `enableMcpServers`)
- No other files in the home directory are touched

**Cache cleanup:**

- `apt-get clean && rm -rf /var/lib/apt/lists/*` (Debian/Ubuntu)
- `rm -rf /var/cache/apk/*` (Alpine)
- `pacman -Scc --noconfirm` (Arch)
- `dnf clean all` (Fedora/RHEL)
- `npm cache clean --force` (all distros)

**Idempotency:** The script is safe to run multiple times. `npm install -g` overwrites cleanly. Dependency installation uses `--needed` (pacman) or is naturally idempotent (apt, apk, dnf). File creation uses create-if-absent patterns.

## 5. Testing Strategy

### Test Architecture

Each scenario in `scenarios.json` has a dedicated test script at `test/claude-code/test_<scenario>.sh`. This enables:

- **Positive assertions:** verify expected behavior when an option is enabled
- **Negative assertions:** verify things are NOT present when an option is disabled
- **Option-specific verification:** e.g., pinned version matches exactly

Test scripts run as the **non-root remote user**, not root. This validates the permission model.

### Shared Test Helpers (`test.sh`)

Common assertion functions used by all scenario scripts:

- `check_command_exists <cmd>` — verify binary on PATH
- `check_command_version <cmd> <expected>` — verify version output
- `check_file_exists <path>` — verify file presence
- `check_file_absent <path>` — verify file absence (for negative tests)
- `check_env_var <name> <value>` — verify environment variable
- `check_permissions <path> <expected_perms>` — verify file permissions
- `check_path_clean <cache_dir>` — verify cache directories are clean

### Core Assertions (all scenarios)

- `claude` binary exists and is on PATH
- `claude --version` exits 0 and outputs a version string
- Node.js is available and >= 18 (`node --version`)
- Non-root user can execute `claude`
- `CLAUDE_CODE_INSTALLED=true` environment variable is set
- `claude` binary has correct permissions (755)
- Package manager caches are cleaned

### Per-Scenario Assertions

| Scenario               | Assertions                                                                      |
| ---------------------- | ------------------------------------------------------------------------------- |
| `default_options`      | Completions exist for detected shells. MCP config absent.                       |
| `completions_disabled` | Completion files do NOT exist for any shell.                                    |
| `mcp_enabled`          | `~/.claude/mcp_servers.json` exists, is valid JSON, owned by remote user.       |
| `custom_version`       | `claude --version` outputs exact pinned version.                                |
| `node_preinstalled`    | Existing Node.js version unchanged. No second Node.js installation.             |
| `custom_install_path`  | Binary at `<installPath>/bin/claude`. PATH includes `<installPath>/bin`.        |
| `mount_host_config`    | Build output contains the mount snippet documentation. No actual mount created. |
| `alpine_specific`      | Bash was installed. Completions at Alpine-specific paths. `apk` caches cleaned. |
| `idempotency`          | Run install twice — no errors, same end state.                                  |

### Test Matrix (`scenarios.json`)

Each scenario specifies a base image and feature options.

**Raw OS images:**

- `ubuntu:22.04`, `ubuntu:24.04`
- `debian:bullseye`, `debian:bookworm`
- `alpine:3.19`, `alpine:3.20`, `alpine:3.21`
- `archlinux:latest`
- `fedora:39`, `fedora:40`
- `rockylinux:9`, `almalinux:9`
- `amazonlinux:2023`

**DevContainer base images:**

- `mcr.microsoft.com/devcontainers/base:debian`
- `mcr.microsoft.com/devcontainers/base:ubuntu`
- `mcr.microsoft.com/devcontainers/base:alpine`
- `mcr.microsoft.com/devcontainers/universal:2` (Codespaces default — critical)

**Language-specific devcontainer images:**

- `mcr.microsoft.com/devcontainers/python`
- `mcr.microsoft.com/devcontainers/javascript-node`
- `mcr.microsoft.com/devcontainers/typescript-node`
- `mcr.microsoft.com/devcontainers/rust`
- `mcr.microsoft.com/devcontainers/go`
- `mcr.microsoft.com/devcontainers/cpp`
- `mcr.microsoft.com/devcontainers/dotnet`
- `mcr.microsoft.com/devcontainers/java`
- `mcr.microsoft.com/devcontainers/ruby`
- `mcr.microsoft.com/devcontainers/php`

**Multi-feature combo scenario:**

- `devcontainers/javascript-node` with `ghcr.io/devcontainers/features/node` already present — validates `installsAfter` ordering and no version conflict

**Concrete `scenarios.json` example** (subset — full file includes all scenarios):

```json
{
  "default_options": {
    "image": "mcr.microsoft.com/devcontainers/base:ubuntu",
    "features": {
      "claude-code": {}
    }
  },
  "completions_disabled": {
    "image": "mcr.microsoft.com/devcontainers/base:debian",
    "features": {
      "claude-code": {
        "shellCompletions": false
      }
    }
  },
  "custom_version": {
    "image": "mcr.microsoft.com/devcontainers/base:ubuntu",
    "features": {
      "claude-code": {
        "version": "PINNED_VERSION"
      }
    }
  },
  "node_preinstalled": {
    "image": "mcr.microsoft.com/devcontainers/javascript-node",
    "features": {
      "claude-code": {}
    }
  },
  "mcp_enabled": {
    "image": "mcr.microsoft.com/devcontainers/base:ubuntu",
    "features": {
      "claude-code": {
        "enableMcpServers": true
      }
    }
  },
  "mount_host_config": {
    "image": "mcr.microsoft.com/devcontainers/base:debian",
    "features": {
      "claude-code": {
        "mountHostConfig": true
      }
    }
  },
  "alpine_specific": {
    "image": "mcr.microsoft.com/devcontainers/base:alpine",
    "features": {
      "claude-code": {}
    }
  },
  "idempotency": {
    "image": "mcr.microsoft.com/devcontainers/base:ubuntu",
    "features": {
      "claude-code": {}
    }
  }
}
```

**Note on `custom_version`:** The `PINNED_VERSION` placeholder must be replaced with a known-good recent version at implementation time. This version should be updated periodically (or queried from npm in CI) to avoid rot if older versions are unpublished.

### Architecture Testing Strategy

**amd64:** Full matrix — all images and all scenarios. Primary gate.

**arm64:** Reduced matrix on **native** GitHub Actions arm64 runners (`runs-on: ubuntu-24.04-arm`). No QEMU emulation (too slow, too flaky). Tested images:

- `ubuntu:24.04`
- `alpine:3.21`
- `mcr.microsoft.com/devcontainers/base:debian`
- `mcr.microsoft.com/devcontainers/universal:2`

Matrix `exclude` list for images without arm64 variants (e.g., `archlinux` if no arm64 image exists).

## 6. CI/CD Pipeline

### Split into Two Workflows

**`test.yml`** — runs on PRs and push to main:

```yaml
concurrency:
  group: "${{ github.workflow }}-${{ github.ref }}"
  cancel-in-progress: true

permissions:
  contents: read
```

**Stages:**

1. **Lint** (single job, `timeout-minutes: 10`)
   - ShellCheck on all `.sh` files (`--shell=bash --severity=warning`)
   - JSON schema validation on `devcontainer-feature.json`
   - `check-yaml` on all YAML files
   - Prettier check on JSON/YAML/Markdown
   - `markdownlint` on Markdown files
   - Custom step: verify `.sh` files have execute bit set

2. **Test (amd64)** (matrix job)
   - `runs-on: ubuntu-latest`
   - `strategy: { fail-fast: false, max-parallel: 10 }`
   - Matrix across all images and scenarios
   - Uses pinned `@devcontainers/cli` version
   - `timeout-minutes: 30` per job
   - Docker layer caching via `docker/setup-buildx-action` with `cache-from: type=gha`
   - On failure: upload Docker build logs via `actions/upload-artifact`

3. **Test (arm64)** (matrix job)
   - `runs-on: ubuntu-24.04-arm` (native arm64 runner)
   - Reduced matrix (4 representative images)
   - `strategy: { fail-fast: false, max-parallel: 2 }` (arm64 runners may have lower availability)
   - `timeout-minutes: 30`
   - Docker layer caching via `docker/setup-buildx-action` with `cache-from: type=gha` (same as amd64)
   - On failure: upload Docker build logs via `actions/upload-artifact` (same as amd64)

**`release.yml`** — runs on `v*` tag push:

```yaml
permissions: {} # deny all at top level

concurrency:
  group: "release-${{ github.repository }}"
  cancel-in-progress: false # never cancel an in-flight release

on:
  push:
    tags: ["v*"]
```

**Stages** (each job declares its own permissions):

1. **Validate** (`timeout-minutes: 15`, `permissions: { contents: read }`) — lint + smoke test (3 representative images)
2. **Version check** (`timeout-minutes: 5`, `permissions: { contents: read }`) — verify `devcontainer-feature.json` version matches git tag (strip `v` prefix)
3. **Publish** (`timeout-minutes: 15`, `permissions: { contents: read, packages: write }`) — uses `devcontainers/action@v1` (pinned to SHA) to publish to `ghcr.io`
4. **Post-publish** (`timeout-minutes: 10`, `permissions: { packages: read }`) — verify the published feature is pullable by running `devcontainer features info` against the published OCI artifact

**Post-first-publish manual step:** Change GHCR package visibility from private to public. Documented in README.

### CI Security Hardening

- Top-level `permissions: {}` (deny all), grant per-job
- Third-party actions pinned to SHA hashes
- No secrets in test matrix (Claude Code is installed but not authenticated in CI)

## 7. Pre-commit Hooks

### `.shellcheckrc`

```
shell=bash
severity=warning
```

### `.editorconfig`

```ini
[*.sh]
indent_style = space
indent_size = 4
```

### `.pre-commit-config.yaml`

| Hook                      | Source                           | Purpose                                                            |
| ------------------------- | -------------------------------- | ------------------------------------------------------------------ |
| `shellcheck`              | `koalaman/shellcheck-precommit`  | Lint shell scripts (bash dialect, warning severity)                |
| `shfmt`                   | `scop/pre-commit-shfmt`          | Enforce consistent formatting (4-space indent per `.editorconfig`) |
| `check-json`              | `pre-commit/pre-commit-hooks`    | Validate JSON files                                                |
| `check-yaml`              | `pre-commit/pre-commit-hooks`    | Validate YAML files                                                |
| `trailing-whitespace`     | `pre-commit/pre-commit-hooks`    | Remove trailing whitespace                                         |
| `end-of-file-fixer`       | `pre-commit/pre-commit-hooks`    | Ensure newline at end of files                                     |
| `check-merge-conflict`    | `pre-commit/pre-commit-hooks`    | Prevent committing merge markers                                   |
| `detect-private-key`      | `pre-commit/pre-commit-hooks`    | Prevent committing SSH private keys                                |
| `check-added-large-files` | `pre-commit/pre-commit-hooks`    | Prevent committing large binaries                                  |
| `no-commit-to-branch`     | `pre-commit/pre-commit-hooks`    | Protect `main` branch from direct pushes                           |
| `prettier`                | `pre-commit/mirrors-prettier`    | Format JSON, YAML, and Markdown                                    |
| `markdownlint`            | `igorshubovych/markdownlint-cli` | Structural Markdown linting                                        |

**Note:** There is no standard pre-commit hook to enforce `.sh` files have the execute bit set. This will be validated in CI via a custom script step instead.

## 8. License

MIT License — open source, free to use.

## 9. Pre-Implementation Quality Gates

Before writing any code:

1. **Deep research agent** — Validate this design against the latest devcontainers spec, `devcontainers/action` documentation, and `@devcontainers/cli` test framework behavior
2. **Parallel review agents** — Architecture, shell scripting, and CI/CD review passes (completed: 2 rounds, all critical findings resolved)

## 10. Success Criteria

- Feature installs cleanly on every image in the test matrix
- `claude --version` works for both root and non-root users
- Zero warnings from ShellCheck
- CI pipeline passes on all amd64 matrix combinations
- CI pipeline passes on reduced arm64 matrix
- Per-scenario tests validate both positive and negative assertions
- Published to ghcr.io and installable via `"features": { "ghcr.io/<org>/claude-code-devcontainer/claude-code:1": {} }`
- README provides clear usage instructions with examples, CI status badge, and security documentation for host config mounting

## 11. Versioning Strategy

The feature uses semver. Version in `devcontainer-feature.json` must match the git tag (without `v` prefix). CI enforces this.

- **Patch:** Bug fixes, dependency updates, new distro support
- **Minor:** New options, new capabilities (backward-compatible)
- **Major:** Breaking changes to option behavior or defaults

Users pin by major version: `claude-code:1`. This is independent of the Claude Code npm package version.

## 12. Known Assumptions and Risks

| Assumption                                              | Risk if Wrong                                                            | Mitigation                                                                                                                                              |
| ------------------------------------------------------- | ------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Claude Code npm package is pure JS (no native addons)   | Alpine support breaks                                                    | Remove Alpine from matrix, document limitation                                                                                                          |
| `~/.claude` is the config directory                     | Host config mount breaks                                                 | Check `claude` CLI for config path discovery                                                                                                            |
| NodeSource supports all target distros                  | Node.js install fails                                                    | Fallback to distro packages for unsupported distros                                                                                                     |
| Alpine/Arch distro packages ship Node.js >= 18          | Hard failure with error message directing user to use a newer base image | Older Alpine (< 3.19) and theoretical older Arch images may ship Node < 18. No NodeSource fallback exists for Alpine/Arch — this is a known limitation. |
| GitHub Actions arm64 runners available for public repos | arm64 testing blocked                                                    | Fall back to QEMU for a reduced subset                                                                                                                  |
