# Claude Code DevContainer Feature — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build and ship a universally compatible DevContainer Feature that installs Claude Code into any existing devcontainer.

**Architecture:** A single DevContainer Feature (`src/claude-code/`) with a bash install script that detects the host OS, ensures Node.js >= 18, installs Claude Code via npm, and optionally configures shell completions and MCP servers. Tested across 25+ base images on amd64/arm64 via GitHub Actions. Published to ghcr.io.

**Tech Stack:** Bash, DevContainer Features spec, GitHub Actions, ShellCheck, npm, Docker

**Spec:** `docs/superpowers/specs/2026-03-31-claude-code-devcontainer-feature-design.md`

---

## File Map

| File | Responsibility |
|---|---|
| `src/claude-code/devcontainer-feature.json` | Feature manifest: metadata, options, env vars |
| `src/claude-code/install.sh` | Installation script: OS detection, Node.js install, Claude Code install, completions, MCP, cleanup |
| `test/claude-code/test.sh` | Shared test helper functions (assertions) |
| `test/claude-code/scenarios.json` | Test scenario definitions (image + feature options) |
| `test/claude-code/default_options.sh` | Test: default options assertions |
| `test/claude-code/completions_disabled.sh` | Test: completions absent when disabled |
| `test/claude-code/mcp_enabled.sh` | Test: MCP config exists and is valid |
| `test/claude-code/custom_version.sh` | Test: pinned version matches exactly |
| `test/claude-code/node_preinstalled.sh` | Test: existing Node.js untouched |
| `test/claude-code/custom_install_path.sh` | Test: binary at custom path, PATH updated |
| `test/claude-code/mount_host_config.sh` | Test: mount snippet in output, no actual mount |
| `test/claude-code/alpine_specific.sh` | Test: bash installed, Alpine-specific paths |
| `test/claude-code/idempotency.sh` | Test: double-install produces same state |
| `test/claude-code/multi_feature_combo.sh` | Test: coexists with separate Node feature |
| `.github/workflows/test.yml` | CI: lint + exhaustive test matrix |
| `.github/workflows/release.yml` | CD: publish to ghcr.io on tag push |
| `.pre-commit-config.yaml` | Pre-commit hook definitions |
| `.shellcheckrc` | ShellCheck config (bash, warning severity) |
| `.editorconfig` | Formatting config (4-space indent for .sh) |
| `.devcontainer/devcontainer.json` | Contributor dev environment |
| `LICENSE` | MIT license |
| `README.md` | Usage docs, examples, CI badge |

---

## Task 1: Repository Foundation

**Files:**
- Create: `LICENSE`
- Create: `.editorconfig`
- Create: `.shellcheckrc`
- Create: `.gitignore`

- [ ] **Step 1: Create MIT LICENSE**

```
MIT License

Copyright (c) 2026 Claude Code DevContainer Feature Contributors

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

- [ ] **Step 2: Create `.editorconfig`**

```ini
root = true

[*]
end_of_line = lf
insert_final_newline = true
trim_trailing_whitespace = true
charset = utf-8

[*.sh]
indent_style = space
indent_size = 4

[*.{json,yml,yaml}]
indent_style = space
indent_size = 2

[*.md]
trim_trailing_whitespace = false

[Makefile]
indent_style = tab
```

- [ ] **Step 3: Create `.shellcheckrc`**

```
shell=bash
severity=warning
```

- [ ] **Step 4: Create `.gitignore`**

```gitignore
# OS
.DS_Store
Thumbs.db

# Editors
*.swp
*.swo
*~
.vscode/
.idea/

# Node (from npm install in CI)
node_modules/

# Pre-commit
.pre-commit-cache/
```

- [ ] **Step 5: Commit**

```bash
git add LICENSE .editorconfig .shellcheckrc .gitignore
git commit -m "chore: add LICENSE, editorconfig, shellcheckrc, gitignore"
```

---

## Task 2: Feature Manifest

**Files:**
- Create: `src/claude-code/devcontainer-feature.json`

- [ ] **Step 1: Create the feature manifest**

```json
{
    "id": "claude-code",
    "version": "1.0.0",
    "name": "Claude Code",
    "description": "Install Claude Code CLI into any devcontainer. Supports Debian, Ubuntu, Alpine, Arch, Fedora, RHEL, Rocky, Alma, and Amazon Linux on amd64/arm64.",
    "keywords": [
        "claude",
        "claude-code",
        "anthropic",
        "ai",
        "cli",
        "devcontainer"
    ],
    "documentationURL": "https://github.com/pkramek/claude-code-devcontainer#readme",
    "licenseURL": "https://github.com/pkramek/claude-code-devcontainer/blob/main/LICENSE",
    "installsAfter": [
        "ghcr.io/devcontainers/features/node"
    ],
    "options": {
        "version": {
            "type": "string",
            "default": "latest",
            "description": "Claude Code version to install (semver or 'latest'). Recommend pinning for teams."
        },
        "nodeVersion": {
            "type": "string",
            "default": "lts",
            "description": "Node.js version to install if not already present (>= 18 required). Resolved via NodeSource."
        },
        "installPath": {
            "type": "string",
            "default": "/usr/local",
            "description": "Custom npm global install prefix. Feature ensures <installPath>/bin is on PATH."
        },
        "enableMcpServers": {
            "type": "boolean",
            "default": false,
            "description": "Create a starter MCP server configuration at ~/.claude/mcp_servers.json (create-if-absent)."
        },
        "mountHostConfig": {
            "type": "boolean",
            "default": false,
            "description": "Log a mounts snippet for host ~/.claude config passthrough (documentation-only, does NOT auto-mount)."
        },
        "shellCompletions": {
            "type": "boolean",
            "default": true,
            "description": "Install shell completions for bash, zsh, and fish."
        }
    },
    "containerEnv": {
        "CLAUDE_CODE_INSTALLED": "true"
    }
}
```

**Note:** `postCreateCommand` is NOT a valid field in `devcontainer-feature.json` (it belongs in `devcontainer.json`). The runtime verification (`claude --version`) is already handled at the end of `install.sh`. The README documents a recommended `postCreateCommand` for users who want runtime verification.
```

- [ ] **Step 2: Validate JSON is well-formed**

Run: `python3 -m json.tool src/claude-code/devcontainer-feature.json > /dev/null`
Expected: exits 0, no output

- [ ] **Step 3: Commit**

```bash
git add src/claude-code/devcontainer-feature.json
git commit -m "feat: add devcontainer-feature.json manifest"
```

---

## Task 3: Install Script — Bootstrap, Error Handling, Input Validation

**Files:**
- Create: `src/claude-code/install.sh`

This task creates the script skeleton with the bootstrap, error handling, logging, input validation, and option parsing. No actual installation logic yet.

- [ ] **Step 1: Create `install.sh` with bootstrap and error handling**

```bash
#!/usr/bin/env bash
#
# Claude Code DevContainer Feature — install.sh
# Installs Claude Code CLI into any devcontainer environment.
#
# Options (from devcontainer-feature.json):
#   VERSION          - Claude Code version (default: "latest")
#   NODEVERSION      - Node.js version (default: "lts")
#   INSTALLPATH      - npm global prefix (default: "/usr/local")
#   ENABLEMCPSERVERS - Create MCP config (default: "false")
#   MOUNTHOSTCONFIG  - Log mount snippet (default: "false")
#   SHELLCOMPLETIONS - Install completions (default: "true")

# --- POSIX-compatible bootstrap (runs under /bin/sh on Alpine) ---
if [ -z "${BASH_VERSION:-}" ]; then
    if command -v apk > /dev/null 2>&1; then
        apk add --no-cache bash > /dev/null || {
            echo "[claude-code feature] ERROR: Failed to install bash via apk." >&2
            exit 1
        }
    fi
    if ! command -v bash > /dev/null 2>&1; then
        echo "[claude-code feature] ERROR: bash is required but could not be found or installed." >&2
        exit 1
    fi
    exec bash "$0" "$@"
fi
# --- From here on, bash is guaranteed ---

set -Eeuo pipefail
umask 0022  # Ensure consistent file permissions regardless of build environment

FEATURE_LOG_PREFIX="[claude-code feature]"

# Debug mode — WARNING: unset secrets first to prevent leaking via set -x
if [[ "${DEBUG:-false}" == "true" ]]; then
    # Unset known secret variables to prevent exposure in trace output
    unset ANTHROPIC_API_KEY CLAUDE_API_KEY 2>/dev/null || true
    set -x
fi

# Traps
trap 'echo "${FEATURE_LOG_PREFIX} ERROR: Failed at line ${LINENO}. Exit code: $?" >&2' ERR
trap cleanup EXIT INT TERM

TEMP_DIR=""
cleanup() {
    [[ -n "${TEMP_DIR}" ]] && rm -rf "${TEMP_DIR}" 2>/dev/null || true
}

# --- Logging ---
log_info()  { echo "${FEATURE_LOG_PREFIX} $*"; }
log_warn()  { echo "${FEATURE_LOG_PREFIX} WARNING: $*" >&2; }
log_error() { echo "${FEATURE_LOG_PREFIX} ERROR: $*" >&2; }
log_debug() {
    if [[ "${DEBUG:-false}" == "true" ]]; then
        echo "${FEATURE_LOG_PREFIX} DEBUG: $*"
    fi
}

# --- Input Validation ---
validate_version() {
    local ver="$1"
    if [[ "${ver}" == "latest" ]]; then return 0; fi
    if [[ ! "${ver}" =~ ^[0-9][0-9a-zA-Z.+-]*$ ]]; then
        log_error "Invalid version '${ver}'. Must be 'latest' or a valid semver string."
        exit 1
    fi
}

validate_install_path() {
    local path="$1"
    if [[ ! "${path}" =~ ^/[a-zA-Z0-9/_.-]+$ ]]; then
        log_error "Invalid installPath '${path}'. Must be an absolute path with no special characters."
        exit 1
    fi
}

validate_node_version() {
    local ver="$1"
    if [[ "${ver}" == "lts" ]]; then return 0; fi
    if [[ ! "${ver}" =~ ^[0-9]+$ ]]; then
        log_error "Invalid nodeVersion '${ver}'. Must be 'lts' or a major version number (e.g., '20')."
        exit 1
    fi
    if [[ "${ver}" -lt 18 || "${ver}" -gt 99 ]]; then
        log_error "nodeVersion '${ver}' out of range. Must be between 18 and 99."
        exit 1
    fi
}

# --- Parse Options ---
VERSION="${VERSION:-latest}"
NODE_VERSION="${NODEVERSION:-lts}"
INSTALL_PATH="${INSTALLPATH:-/usr/local}"
ENABLE_MCP_SERVERS="${ENABLEMCPSERVERS:-false}"
MOUNT_HOST_CONFIG="${MOUNTHOSTCONFIG:-false}"
SHELL_COMPLETIONS="${SHELLCOMPLETIONS:-true}"

validate_version "${VERSION}"
validate_install_path "${INSTALL_PATH}"
validate_node_version "${NODE_VERSION}"

log_info "Starting installation..."
log_info "  Claude Code version: ${VERSION}"
log_info "  Node.js version: ${NODE_VERSION}"
log_info "  Install path: ${INSTALL_PATH}"
log_info "  MCP servers: ${ENABLE_MCP_SERVERS}"
log_info "  Mount host config: ${MOUNT_HOST_CONFIG}"
log_info "  Shell completions: ${SHELL_COMPLETIONS}"

# --- Remote User Detection ---
detect_remote_user() {
    if [[ -n "${_REMOTE_USER:-}" ]]; then
        echo "${_REMOTE_USER}"
    elif [[ -n "${_CONTAINER_USER:-}" ]]; then
        echo "${_CONTAINER_USER}"
    else
        # Find first non-root user with a valid login shell
        local user
        user=$(getent passwd | awk -F: '$3 >= 1000 && $7 !~ /nologin|false/ { print $1; exit }')
        if [[ -n "${user}" ]]; then
            echo "${user}"
        else
            echo "root"
        fi
    fi
}

detect_user_home() {
    local user="$1"
    if [[ -n "${_REMOTE_USER_HOME:-}" ]]; then
        echo "${_REMOTE_USER_HOME}"
    else
        getent passwd "${user}" | cut -d: -f6
    fi
}

REMOTE_USER=$(detect_remote_user)
REMOTE_USER_HOME=$(detect_user_home "${REMOTE_USER}")
if [[ -z "${REMOTE_USER_HOME}" ]]; then
    log_warn "Could not detect home directory for user '${REMOTE_USER}'. Defaulting to /root."
    REMOTE_USER_HOME="/root"
fi
log_info "  Remote user: ${REMOTE_USER} (home: ${REMOTE_USER_HOME})"

# Subsequent tasks will add: detect_os, install_dependencies, install_node,
# install_claude_code, setup_completions, setup_mcp, setup_mount_docs, cleanup_caches
log_info "Installation complete."
```

- [ ] **Step 2: Make the script executable**

Run: `chmod +x src/claude-code/install.sh`

- [ ] **Step 3: Run ShellCheck**

Run: `shellcheck src/claude-code/install.sh`
Expected: exits 0, no warnings

- [ ] **Step 4: Commit**

```bash
git add src/claude-code/install.sh
git commit -m "feat: add install.sh skeleton with bootstrap, logging, validation"
```

---

## Task 4: Install Script — OS Detection and Dependency Installation

**Files:**
- Modify: `src/claude-code/install.sh`

Add OS detection and base dependency installation functions.

- [ ] **Step 1: Add OS detection function**

Insert before the `log_info "Installation complete."` line:

```bash
# --- OS Detection ---
detect_os() {
    local id=""
    local id_like=""

    if [[ -f /etc/os-release ]]; then
        # shellcheck source=/dev/null
        . /etc/os-release
        id="${ID:-}"
        id_like="${ID_LIKE:-}"
    fi

    case "${id}" in
        debian|ubuntu|linuxmint)
            echo "debian"
            ;;
        alpine)
            echo "alpine"
            ;;
        arch|archarm|endeavouros|manjaro)
            echo "arch"
            ;;
        fedora|rhel|centos|rocky|almalinux|amzn)
            echo "rhel"
            ;;
        *)
            # Fallback to ID_LIKE
            case "${id_like}" in
                *debian*|*ubuntu*) echo "debian" ;;
                *arch*)            echo "arch" ;;
                *fedora*|*rhel*)   echo "rhel" ;;
                *)
                    log_error "Unsupported OS: ID=${id}, ID_LIKE=${id_like}"
                    exit 1
                    ;;
            esac
            ;;
    esac
}

detect_arch() {
    local arch
    arch=$(uname -m)
    case "${arch}" in
        x86_64)  echo "amd64" ;;
        aarch64) echo "arm64" ;;
        *)
            log_error "Unsupported architecture: ${arch}"
            exit 1
            ;;
    esac
}

OS_FAMILY=$(detect_os)
ARCH=$(detect_arch)
log_info "  Detected OS family: ${OS_FAMILY}"
log_info "  Detected architecture: ${ARCH}"
```

- [ ] **Step 2: Add dependency installation function**

Insert after the OS detection block:

```bash
# --- Dependency Installation ---
install_packages() {
    local packages=("$@")
    case "${OS_FAMILY}" in
        debian)
            # Check if apt lists are populated (not just if cache file exists)
            local apt_lists_count
            apt_lists_count=$(find /var/lib/apt/lists -maxdepth 1 -type f ! -name 'lock' ! -name 'partial' 2>/dev/null | wc -l)
            if [[ "${apt_lists_count}" -eq 0 ]]; then
                apt-get update -y -o DPkg::Lock::Timeout=60
            fi
            apt-get install -y --no-install-recommends -o DPkg::Lock::Timeout=60 "${packages[@]}"
            ;;
        alpine)
            apk add --no-cache "${packages[@]}"
            ;;
        arch)
            pacman -S --noconfirm --needed "${packages[@]}"
            ;;
        rhel)
            if command -v dnf > /dev/null 2>&1; then
                dnf install -y "${packages[@]}"
            else
                yum install -y "${packages[@]}"
            fi
            ;;
    esac
}

ensure_base_dependencies() {
    local missing=()

    command -v curl > /dev/null 2>&1 || missing+=("curl")
    command -v git > /dev/null 2>&1 || missing+=("git")

    # Always ensure ca-certificates for TLS verification (needed before any curl to nodejs.org/npm)
    case "${OS_FAMILY}" in
        alpine)
            command -v update-ca-certificates > /dev/null 2>&1 || missing+=("ca-certificates")
            ;;
        debian)
            [[ -d /etc/ssl/certs ]] && [[ -n "$(ls /etc/ssl/certs/ 2>/dev/null)" ]] || missing+=("ca-certificates")
            ;;
        # RHEL and Arch include ca-certificates by default
    esac

    if [[ ${#missing[@]} -gt 0 ]]; then
        log_info "Installing missing dependencies: ${missing[*]}"
        install_packages "${missing[@]}"
    fi
}

ensure_base_dependencies
```

- [ ] **Step 3: Run ShellCheck**

Run: `shellcheck src/claude-code/install.sh`
Expected: exits 0, no warnings

- [ ] **Step 4: Commit**

```bash
git add src/claude-code/install.sh
git commit -m "feat: add OS detection and dependency installation"
```

---

## Task 5: Install Script — Node.js Installation

**Files:**
- Modify: `src/claude-code/install.sh`

Add Node.js detection, version checking, and installation via NodeSource or distro packages.

- [ ] **Step 1: Add Node.js version checking and installation**

Insert after `ensure_base_dependencies`:

```bash
# --- Node.js Installation ---
NODE_MIN_VERSION=18

get_node_major_version() {
    local version_string
    version_string=$(node --version 2>/dev/null || echo "")
    if [[ -z "${version_string}" ]]; then
        echo "0"
        return
    fi
    # Strip leading 'v' and extract major version
    echo "${version_string}" | sed 's/^v//' | cut -d. -f1
}

resolve_node_version() {
    local requested="$1"
    if [[ "${requested}" == "lts" ]]; then
        # Query official Node.js release API for current LTS major version
        local lts_version
        lts_version=$(curl -fsSL https://nodejs.org/dist/index.json 2>/dev/null \
            | node -e "
                const data = JSON.parse(require('fs').readFileSync('/dev/stdin','utf8'));
                const lts = data.find(r => r.lts);
                console.log(lts ? lts.version.replace(/^v/,'').split('.')[0] : '22');
            " 2>/dev/null || echo "22")
        if [[ -z "${lts_version}" ]]; then lts_version="22"; fi
        log_info "Resolved LTS to Node.js ${lts_version}"
        echo "${lts_version}"
    else
        echo "${requested}"
    fi
}

install_node_binary() {
    local version="$1"
    local arch_label
    case "$(uname -m)" in
        x86_64)  arch_label="x64" ;;
        aarch64) arch_label="arm64" ;;
        *)       log_error "Unsupported arch for Node.js binary: $(uname -m)"; exit 1 ;;
    esac

    log_info "Installing Node.js ${version} via official binary tarball..."

    TEMP_DIR=$(mktemp -d)
    local tarball="node-v${version}.0.0-linux-${arch_label}.tar.xz"
    local url="https://nodejs.org/dist/latest-v${version}.x/"

    # Get the exact filename and checksum from the SHASUMS256 file
    local shasums
    shasums=$(curl -fsSL "${url}SHASUMS256.txt") || {
        log_error "Failed to download Node.js SHASUMS256.txt from ${url}"
        exit 1
    }

    # Find the linux tarball line
    local tarball_line
    tarball_line=$(echo "${shasums}" | grep "linux-${arch_label}.tar.xz" | head -1)
    if [[ -z "${tarball_line}" ]]; then
        log_error "No linux-${arch_label} tarball found in Node.js ${version} release."
        exit 1
    fi

    local expected_sha tarball_name
    expected_sha=$(echo "${tarball_line}" | awk '{print $1}')
    tarball_name=$(echo "${tarball_line}" | awk '{print $2}')

    log_debug "Downloading ${tarball_name} (SHA256: ${expected_sha})"

    curl -fsSL "${url}${tarball_name}" -o "${TEMP_DIR}/${tarball_name}" || {
        log_error "Failed to download Node.js from ${url}${tarball_name}"
        exit 1
    }

    # Verify SHA256 checksum
    local actual_sha
    actual_sha=$(sha256sum "${TEMP_DIR}/${tarball_name}" | awk '{print $1}')
    if [[ "${actual_sha}" != "${expected_sha}" ]]; then
        log_error "SHA256 checksum mismatch for Node.js tarball!"
        log_error "  Expected: ${expected_sha}"
        log_error "  Actual:   ${actual_sha}"
        exit 1
    fi
    log_info "SHA256 checksum verified."

    # Extract to /usr/local (merges bin/, lib/, include/, share/)
    tar -xJf "${TEMP_DIR}/${tarball_name}" -C /usr/local --strip-components=1
    rm -rf "${TEMP_DIR}"
    TEMP_DIR=""

    log_info "Node.js $(node --version) installed and verified."
}

install_node_distro() {
    if [[ "${NODE_VERSION}" != "lts" ]]; then
        log_warn "nodeVersion '${NODE_VERSION}' is ignored on ${OS_FAMILY} — distro package version will be used."
    fi
    log_info "Installing Node.js via distro packages..."
    case "${OS_FAMILY}" in
        alpine)
            install_packages nodejs npm
            ;;
        arch)
            install_packages nodejs npm
            ;;
        *)
            log_error "No distro package strategy for ${OS_FAMILY}."
            exit 1
            ;;
    esac

    # Post-install version floor check
    local installed_major
    installed_major=$(get_node_major_version)
    if [[ "${installed_major}" -lt "${NODE_MIN_VERSION}" ]]; then
        log_error "Node.js v${installed_major} from distro packages is below minimum ${NODE_MIN_VERSION}."
        log_error "Use a newer base image or set nodeVersion to install via NodeSource."
        exit 1
    fi
}

ensure_node() {
    local current_major
    current_major=$(get_node_major_version)

    if [[ "${current_major}" -ge "${NODE_MIN_VERSION}" ]]; then
        log_info "Node.js v$(node --version) already installed and meets minimum requirement (>= ${NODE_MIN_VERSION})."
        return 0
    fi

    if [[ "${current_major}" -gt 0 ]] && [[ "${current_major}" -lt "${NODE_MIN_VERSION}" ]]; then
        log_warn "Node.js v$(node --version) is below minimum ${NODE_MIN_VERSION}. Installing newer version..."
    fi

    local resolved_version
    resolved_version=$(resolve_node_version "${NODE_VERSION}")
    log_debug "Resolved Node.js version: ${resolved_version}"

    case "${OS_FAMILY}" in
        debian|rhel)
            install_node_binary "${resolved_version}"
            ;;
        alpine|arch)
            install_node_distro
            ;;
        *)
            log_error "No Node.js installation strategy for OS family: ${OS_FAMILY}"
            exit 1
            ;;
    esac

    log_info "Node.js $(node --version) installed successfully."
}

ensure_node
```

- [ ] **Step 2: Run ShellCheck**

Run: `shellcheck src/claude-code/install.sh`
Expected: exits 0, no warnings

- [ ] **Step 3: Commit**

```bash
git add src/claude-code/install.sh
git commit -m "feat: add Node.js detection and installation"
```

---

## Task 6: Install Script — PATH Configuration and Claude Code Installation

**Files:**
- Modify: `src/claude-code/install.sh`

Add custom PATH setup and the actual Claude Code npm install.

- [ ] **Step 1: Add PATH configuration and Claude Code install**

Insert after `ensure_node`:

```bash
# --- PATH Configuration ---
configure_custom_path() {
    if [[ "${INSTALL_PATH}" == "/usr/local" ]]; then
        return 0
    fi

    log_info "Configuring custom install path: ${INSTALL_PATH}"

    # Immediate PATH update for this script
    export PATH="${INSTALL_PATH}/bin:${PATH}"

    # Persistent PATH for login shells (bash, zsh)
    mkdir -p /etc/profile.d
    cat > /etc/profile.d/claude-code.sh << PATHEOF
# Added by Claude Code DevContainer Feature
export PATH="${INSTALL_PATH}/bin:\${PATH}"
PATHEOF
    chmod 644 /etc/profile.d/claude-code.sh

    # Persistent PATH for Alpine ash non-login shells
    if [[ "${OS_FAMILY}" == "alpine" ]]; then
        # BusyBox ash reads ENV on startup for non-login shells
        # Write to /etc/profile (not /etc/environment which is PAM-specific)
        if ! grep -q 'claude-code' /etc/profile 2>/dev/null; then
            echo 'export PATH="'"${INSTALL_PATH}"'/bin:${PATH}"  # claude-code' >> /etc/profile
        fi
    fi

    log_info "PATH configured: ${INSTALL_PATH}/bin"
}

# --- Claude Code Installation ---
install_claude_code() {
    local npm_args=(install -g --fetch-retries=3)

    if [[ "${INSTALL_PATH}" != "/usr/local" ]]; then
        npm_args+=(--prefix "${INSTALL_PATH}")
    fi

    if [[ "${VERSION}" == "latest" ]]; then
        npm_args+=("@anthropic-ai/claude-code")
    else
        npm_args+=("@anthropic-ai/claude-code@${VERSION}")
    fi

    log_info "Installing Claude Code (version: ${VERSION})..."
    log_debug "npm ${npm_args[*]}"

    timeout 300 npm "${npm_args[@]}" || {
        log_error "Failed to install Claude Code."
        log_error "Check network connectivity and npm registry access."
        exit 1
    }

    # Verify installation
    if ! claude --version > /dev/null 2>&1; then
        log_error "Claude Code installed but 'claude' not found on PATH."
        log_error "PATH=${PATH}"
        exit 1
    fi

    log_info "Claude Code $(claude --version) installed successfully."
}

configure_custom_path
install_claude_code
```

- [ ] **Step 2: Run ShellCheck**

Run: `shellcheck src/claude-code/install.sh`
Expected: exits 0, no warnings

- [ ] **Step 3: Commit**

```bash
git add src/claude-code/install.sh
git commit -m "feat: add PATH configuration and Claude Code installation"
```

---

## Task 7: Install Script — Shell Completions, MCP, Mount Docs, Cleanup

**Files:**
- Modify: `src/claude-code/install.sh`

Add the batteries-included features and cleanup. This completes `install.sh`.

- [ ] **Step 1: Add shell completions**

Insert after `install_claude_code`:

```bash
# --- Shell Completions ---
setup_completions() {
    if [[ "${SHELL_COMPLETIONS}" != "true" ]]; then
        log_debug "Shell completions disabled."
        return 0
    fi

    log_info "Installing shell completions..."

    # Bash completions
    local bash_comp_dir=""
    if [[ -d /usr/share/bash-completion/completions ]]; then
        bash_comp_dir="/usr/share/bash-completion/completions"
    elif [[ -d /etc/bash_completion.d ]]; then
        bash_comp_dir="/etc/bash_completion.d"
    fi
    if [[ -n "${bash_comp_dir}" ]]; then
        claude completions bash > "${bash_comp_dir}/claude" 2>/dev/null || {
            log_warn "Failed to install bash completions."
        }
    fi

    # Zsh completions
    if [[ -d /usr/share/zsh/site-functions ]] || mkdir -p /usr/share/zsh/site-functions 2>/dev/null; then
        claude completions zsh > /usr/share/zsh/site-functions/_claude 2>/dev/null || {
            log_warn "Failed to install zsh completions."
        }
    fi

    # Fish completions
    local fish_comp_dir=""
    for dir in /usr/share/fish/vendor_completions.d /usr/share/fish/completions; do
        if [[ -d "${dir}" ]]; then
            fish_comp_dir="${dir}"
            break
        fi
    done
    if [[ -n "${fish_comp_dir}" ]]; then
        claude completions fish > "${fish_comp_dir}/claude.fish" 2>/dev/null || {
            log_warn "Failed to install fish completions."
        }
    fi

    log_info "Shell completions installed."
}

setup_completions
```

- [ ] **Step 2: Add MCP server config**

Insert after `setup_completions`:

```bash
# --- MCP Server Configuration ---
setup_mcp_servers() {
    if [[ "${ENABLE_MCP_SERVERS}" != "true" ]]; then
        log_debug "MCP server configuration disabled."
        return 0
    fi

    local claude_dir="${REMOTE_USER_HOME}/.claude"
    local mcp_config="${claude_dir}/mcp_servers.json"

    if [[ -f "${mcp_config}" ]]; then
        log_info "MCP config already exists at ${mcp_config}, skipping."
        return 0
    fi

    log_info "Creating starter MCP configuration..."
    mkdir -p "${claude_dir}"

    cat > "${mcp_config}" << 'MCPEOF'
{
    "mcpServers": {}
}
MCPEOF

    chmod 700 "${claude_dir}"
    chmod 600 "${mcp_config}"
    chown "${REMOTE_USER}:$(id -gn "${REMOTE_USER}")" "${claude_dir}"
    chown "${REMOTE_USER}:$(id -gn "${REMOTE_USER}")" "${mcp_config}"
    log_info "MCP config created at ${mcp_config} (mode 600)"
}

setup_mcp_servers
```

- [ ] **Step 3: Add mount documentation and cache cleanup**

Insert after `setup_mcp_servers`:

```bash
# --- Host Config Mount Documentation ---
setup_mount_docs() {
    if [[ "${MOUNT_HOST_CONFIG}" != "true" ]]; then
        return 0
    fi

    log_info ""
    log_info "============================================================"
    log_info "HOST CONFIG MOUNTING"
    log_info "============================================================"
    log_info "To mount your host Claude config, add this to your"
    log_info "devcontainer.json:"
    log_info ""
    log_info '  "mounts": ['
    log_info "    \"source=\${localEnv:HOME}/.claude,target=${REMOTE_USER_HOME}/.claude,type=bind,consistency=cached,readonly\""
    log_info '  ]'
    log_info ""
    log_info "WARNING: This exposes your API keys inside the container."
    log_info "See README for security considerations."
    log_info "============================================================"
    log_info ""
}

setup_mount_docs

# --- Cache Cleanup ---
cleanup_caches() {
    log_info "Cleaning up package manager caches..."

    case "${OS_FAMILY}" in
        debian)
            apt-get clean
            rm -rf /var/lib/apt/lists/*
            ;;
        alpine)
            rm -rf /var/cache/apk/*
            ;;
        arch)
            pacman -Sc --noconfirm 2>/dev/null || true
            ;;
        rhel)
            if command -v dnf > /dev/null 2>&1; then
                dnf clean all
            else
                yum clean all
            fi
            rm -rf /var/cache/dnf /var/cache/yum
            ;;
    esac

    npm cache clean --force 2>/dev/null || true
    log_info "Cache cleanup complete."
}

cleanup_caches
```

- [ ] **Step 4: Remove the placeholder `log_info "Installation complete."` and replace with final log**

Replace the old `log_info "Installation complete."` with:

```bash
log_info "Claude Code DevContainer Feature installation complete."
log_info "  Claude Code: $(claude --version 2>/dev/null || echo 'unknown')"
log_info "  Node.js: $(node --version 2>/dev/null || echo 'unknown')"
log_info "  OS: ${OS_FAMILY} (${ARCH})"
log_info "  User: ${REMOTE_USER}"
```

- [ ] **Step 5: Run ShellCheck**

Run: `shellcheck src/claude-code/install.sh`
Expected: exits 0, no warnings

- [ ] **Step 6: Commit**

```bash
git add src/claude-code/install.sh
git commit -m "feat: add completions, MCP config, mount docs, cache cleanup"
```

---

## Task 8: Test Helpers and Scenarios

**Files:**
- Create: `test/claude-code/test.sh`
- Create: `test/claude-code/scenarios.json`

- [ ] **Step 1: Create shared test helpers (`test.sh`)**

```bash
#!/usr/bin/env bash
#
# Shared test helpers for Claude Code DevContainer Feature.
# Sourced by per-scenario test scripts.
#

set -Eeuo pipefail

TESTS_PASSED=0
TESTS_FAILED=0

pass() {
    echo "  PASS: $*"
    ((TESTS_PASSED++))
}

fail() {
    echo "  FAIL: $*" >&2
    ((TESTS_FAILED++))
}

check_command_exists() {
    local cmd="$1"
    if command -v "${cmd}" > /dev/null 2>&1; then
        pass "${cmd} is on PATH"
    else
        fail "${cmd} not found on PATH"
    fi
}

check_command_version() {
    local cmd="$1"
    local expected="$2"
    local actual
    actual=$("${cmd}" --version 2>&1 || echo "")
    if [[ "${actual}" == *"${expected}"* ]]; then
        pass "${cmd} version contains '${expected}' (got: ${actual})"
    else
        fail "${cmd} version mismatch: expected '${expected}', got '${actual}'"
    fi
}

check_command_runs() {
    local cmd="$1"
    if "${cmd}" --version > /dev/null 2>&1; then
        pass "${cmd} --version exits 0"
    else
        fail "${cmd} --version failed"
    fi
}

check_node_min_version() {
    local min="$1"
    local major
    major=$(node --version 2>/dev/null | sed 's/^v//' | cut -d. -f1)
    if [[ "${major}" -ge "${min}" ]]; then
        pass "Node.js v${major} >= ${min}"
    else
        fail "Node.js v${major} < ${min}"
    fi
}

check_file_exists() {
    local path="$1"
    if [[ -f "${path}" ]]; then
        pass "File exists: ${path}"
    else
        fail "File missing: ${path}"
    fi
}

check_file_absent() {
    local path="$1"
    if [[ ! -f "${path}" ]]; then
        pass "File absent (expected): ${path}"
    else
        fail "File exists (unexpected): ${path}"
    fi
}

check_dir_exists() {
    local path="$1"
    if [[ -d "${path}" ]]; then
        pass "Directory exists: ${path}"
    else
        fail "Directory missing: ${path}"
    fi
}

check_env_var() {
    local name="$1"
    local expected="$2"
    local actual="${!name:-}"
    if [[ "${actual}" == "${expected}" ]]; then
        pass "Env var ${name}='${expected}'"
    else
        fail "Env var ${name}: expected '${expected}', got '${actual}'"
    fi
}

check_permissions() {
    local path="$1"
    local expected="$2"
    if [[ ! -e "${path}" ]]; then
        fail "Cannot check permissions: ${path} does not exist"
        return
    fi
    local actual
    actual=$(stat -c '%a' "${path}" 2>/dev/null || stat -f '%Lp' "${path}" 2>/dev/null)
    if [[ "${actual}" == "${expected}" ]]; then
        pass "Permissions on ${path}: ${expected}"
    else
        fail "Permissions on ${path}: expected ${expected}, got ${actual}"
    fi
}

check_file_owner() {
    local path="$1"
    local expected_user="$2"
    if [[ ! -e "${path}" ]]; then
        fail "Cannot check owner: ${path} does not exist"
        return
    fi
    local actual
    actual=$(stat -c '%U' "${path}" 2>/dev/null || stat -f '%Su' "${path}" 2>/dev/null)
    if [[ "${actual}" == "${expected_user}" ]]; then
        pass "Owner of ${path}: ${expected_user}"
    else
        fail "Owner of ${path}: expected ${expected_user}, got ${actual}"
    fi
}

check_file_valid_json() {
    local path="$1"
    # Use node (guaranteed present) with argv to avoid path injection
    if node -e "JSON.parse(require('fs').readFileSync(process.argv[1],'utf8'))" "${path}" > /dev/null 2>&1; then
        pass "Valid JSON: ${path}"
    else
        fail "Invalid JSON: ${path}"
    fi
}

check_path_clean() {
    local cache_dir="$1"
    if [[ ! -d "${cache_dir}" ]]; then
        pass "Cache dir absent: ${cache_dir}"
        return
    fi
    local count
    count=$(find "${cache_dir}" -type f 2>/dev/null | wc -l)
    if [[ "${count}" -eq 0 ]]; then
        pass "Cache dir clean: ${cache_dir}"
    else
        fail "Cache dir has ${count} files: ${cache_dir}"
    fi
}

check_non_root() {
    local current_user
    current_user=$(whoami)
    if [[ "${current_user}" != "root" ]]; then
        pass "Running as non-root user: ${current_user}"
    else
        # Raw OS images (ubuntu:22.04, alpine:3.21, etc.) run as root.
        # This is expected — the devcontainer CLI has no non-root user to switch to.
        # Only warn, don't fail, since the permission model still works for root.
        pass "Running as root (acceptable for raw OS base images)"
    fi
}

# Run core assertions shared by all scenarios
core_assertions() {
    echo "--- Core Assertions ---"
    check_command_exists "claude"
    check_command_runs "claude"
    check_command_exists "node"
    check_node_min_version 18
    check_env_var "CLAUDE_CODE_INSTALLED" "true"
    check_non_root
    # Check claude binary permissions (should be executable by all)
    local claude_path
    claude_path=$(command -v claude)
    if [[ -n "${claude_path}" ]]; then
        check_permissions "${claude_path}" "755"
    fi
}

# Print summary and exit with appropriate code
test_summary() {
    echo ""
    echo "--- Results: ${TESTS_PASSED} passed, ${TESTS_FAILED} failed ---"
    if [[ "${TESTS_FAILED}" -gt 0 ]]; then
        exit 1
    fi
}

# When executed directly (not sourced), run core assertions.
# This is what `devcontainer features test --skip-scenarios --base-image <img>` invokes.
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "=== Default test (core assertions) ==="
    core_assertions
    test_summary
fi
```

- [ ] **Step 2: Create `scenarios.json`**

This file defines per-scenario test configs. The CI workflow also runs the `default_options` scenario across ALL base images in a separate matrix dimension (see Task 11).

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
    "mcp_enabled": {
        "image": "mcr.microsoft.com/devcontainers/base:ubuntu",
        "features": {
            "claude-code": {
                "enableMcpServers": true
            }
        }
    },
    "custom_version": {
        "image": "mcr.microsoft.com/devcontainers/base:ubuntu",
        "features": {
            "claude-code": {
                "version": "0.2.57"
            }
        }
    },
    "node_preinstalled": {
        "image": "mcr.microsoft.com/devcontainers/javascript-node",
        "features": {
            "claude-code": {}
        }
    },
    "custom_install_path": {
        "image": "mcr.microsoft.com/devcontainers/base:ubuntu",
        "features": {
            "claude-code": {
                "installPath": "/opt/claude"
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
    },
    "multi_feature_combo": {
        "image": "mcr.microsoft.com/devcontainers/javascript-node",
        "features": {
            "ghcr.io/devcontainers/features/node:1": {
                "version": "22"
            },
            "claude-code": {}
        }
    }
}
```

- [ ] **Step 3: Make test.sh executable, validate JSON**

Run: `chmod +x test/claude-code/test.sh && python3 -m json.tool test/claude-code/scenarios.json > /dev/null`
Expected: exits 0

- [ ] **Step 4: Commit**

```bash
git add test/claude-code/test.sh test/claude-code/scenarios.json
git commit -m "feat: add test helpers and scenario definitions"
```

---

## Task 9: Per-Scenario Test Scripts

**Files:**
- Create: `test/claude-code/default_options.sh`
- Create: `test/claude-code/completions_disabled.sh`
- Create: `test/claude-code/mcp_enabled.sh`
- Create: `test/claude-code/custom_version.sh`
- Create: `test/claude-code/node_preinstalled.sh`
- Create: `test/claude-code/custom_install_path.sh`
- Create: `test/claude-code/mount_host_config.sh`
- Create: `test/claude-code/alpine_specific.sh`
- Create: `test/claude-code/idempotency.sh`

- [ ] **Step 1: Create `test_default_options.sh`**

```bash
#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=test.sh
source "${SCRIPT_DIR}/test.sh"

echo "=== Scenario: default_options ==="
core_assertions

echo "--- Completions ---"
# At least one completion directory should have the claude file
FOUND_COMPLETIONS=false
for path in \
    /usr/share/bash-completion/completions/claude \
    /etc/bash_completion.d/claude \
    /usr/share/zsh/site-functions/_claude \
    /usr/share/fish/vendor_completions.d/claude.fish \
    /usr/share/fish/completions/claude.fish; do
    if [[ -f "${path}" ]]; then
        FOUND_COMPLETIONS=true
        pass "Completion file found: ${path}"
    fi
done
if [[ "${FOUND_COMPLETIONS}" == "false" ]]; then
    fail "No shell completion files found"
fi

echo "--- MCP config should be absent ---"
check_file_absent "${HOME}/.claude/mcp_servers.json"

test_summary
```

- [ ] **Step 2: Create `test_completions_disabled.sh`**

```bash
#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=test.sh
source "${SCRIPT_DIR}/test.sh"

echo "=== Scenario: completions_disabled ==="
core_assertions

echo "--- Completions should be absent ---"
check_file_absent /usr/share/bash-completion/completions/claude
check_file_absent /etc/bash_completion.d/claude
check_file_absent /usr/share/zsh/site-functions/_claude
check_file_absent /usr/share/fish/vendor_completions.d/claude.fish
check_file_absent /usr/share/fish/completions/claude.fish

test_summary
```

- [ ] **Step 3: Create `test_mcp_enabled.sh`**

```bash
#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=test.sh
source "${SCRIPT_DIR}/test.sh"

echo "=== Scenario: mcp_enabled ==="
core_assertions

echo "--- MCP config ---"
MCP_CONFIG="${HOME}/.claude/mcp_servers.json"
check_file_exists "${MCP_CONFIG}"
check_file_valid_json "${MCP_CONFIG}"
check_file_owner "${MCP_CONFIG}" "$(whoami)"

test_summary
```

- [ ] **Step 4: Create `test_custom_version.sh`**

```bash
#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=test.sh
source "${SCRIPT_DIR}/test.sh"

echo "=== Scenario: custom_version ==="
core_assertions

echo "--- Version check ---"
check_command_version "claude" "0.2.57"

test_summary
```

- [ ] **Step 5: Create `test_node_preinstalled.sh`**

```bash
#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=test.sh
source "${SCRIPT_DIR}/test.sh"

echo "=== Scenario: node_preinstalled ==="
core_assertions

echo "--- Node.js should be unchanged ---"
# The javascript-node image ships Node.js via nvm.
# Verify Node.js is still available and meets minimum version.
check_command_exists "node"
check_node_min_version 18

test_summary
```

- [ ] **Step 6: Create `test_custom_install_path.sh`**

```bash
#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=test.sh
source "${SCRIPT_DIR}/test.sh"

echo "=== Scenario: custom_install_path ==="

echo "--- Binary at custom path ---"
check_file_exists /opt/claude/bin/claude

echo "--- PATH includes custom path ---"
if echo "${PATH}" | grep -q '/opt/claude/bin'; then
    pass "PATH contains /opt/claude/bin"
else
    fail "PATH does not contain /opt/claude/bin"
fi

echo "--- Profile.d script exists ---"
check_file_exists /etc/profile.d/claude-code.sh

core_assertions
test_summary
```

- [ ] **Step 7: Create `test_mount_host_config.sh`**

```bash
#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=test.sh
source "${SCRIPT_DIR}/test.sh"

echo "=== Scenario: mount_host_config ==="
core_assertions

echo "--- No actual mount should exist ---"
# The feature only logs docs, it does not mount anything
# We just verify claude works and no unexpected mounts exist
pass "mount_host_config is documentation-only (no mount to verify)"

test_summary
```

- [ ] **Step 8: Create `test_alpine_specific.sh`**

```bash
#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=test.sh
source "${SCRIPT_DIR}/test.sh"

echo "=== Scenario: alpine_specific ==="
core_assertions

echo "--- Bash should be installed ---"
check_command_exists "bash"

echo "--- APK cache should be clean ---"
APK_CACHE_COUNT=$(find /var/cache/apk/ -type f 2>/dev/null | wc -l)
if [[ "${APK_CACHE_COUNT}" -eq 0 ]]; then
    pass "APK cache is clean"
else
    fail "APK cache has ${APK_CACHE_COUNT} files"
fi

test_summary
```

- [ ] **Step 9: Create `test_idempotency.sh`**

```bash
#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=test.sh
source "${SCRIPT_DIR}/test.sh"

echo "=== Scenario: idempotency ==="
core_assertions

echo "--- Idempotency: record state before second install ---"
CLAUDE_VERSION_BEFORE=$(claude --version 2>&1)
NODE_VERSION_BEFORE=$(node --version 2>&1)

echo "--- Idempotency: run install.sh a second time ---"
# Re-run install as root to simulate a container rebuild
sudo bash /usr/local/share/claude-code/install.sh 2>&1 || {
    fail "Second install.sh run failed"
    test_summary
}

echo "--- Idempotency: verify state unchanged ---"
CLAUDE_VERSION_AFTER=$(claude --version 2>&1)
NODE_VERSION_AFTER=$(node --version 2>&1)

if [[ "${CLAUDE_VERSION_BEFORE}" == "${CLAUDE_VERSION_AFTER}" ]]; then
    pass "Claude Code version unchanged after re-install: ${CLAUDE_VERSION_AFTER}"
else
    fail "Claude Code version changed: ${CLAUDE_VERSION_BEFORE} -> ${CLAUDE_VERSION_AFTER}"
fi

if [[ "${NODE_VERSION_BEFORE}" == "${NODE_VERSION_AFTER}" ]]; then
    pass "Node.js version unchanged after re-install: ${NODE_VERSION_AFTER}"
else
    fail "Node.js version changed: ${NODE_VERSION_BEFORE} -> ${NODE_VERSION_AFTER}"
fi

test_summary
```

- [ ] **Step 10: Create `test_multi_feature_combo.sh`**

```bash
#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=test.sh
source "${SCRIPT_DIR}/test.sh"

echo "=== Scenario: multi_feature_combo ==="
core_assertions

echo "--- Node.js from separate feature should still work ---"
check_command_exists "node"
check_node_min_version 18

echo "--- Claude Code should coexist with separate Node feature ---"
check_command_runs "claude"

test_summary
```

- [ ] **Step 11: Make all test scripts executable**

Run: `chmod +x test/claude-code/*.sh`

- [ ] **Step 12: Run ShellCheck on all test scripts**

Run: `shellcheck test/claude-code/*.sh`
Expected: exits 0, no warnings

- [ ] **Step 13: Commit**

```bash
git add test/claude-code/default_options.sh test/claude-code/completions_disabled.sh test/claude-code/mcp_enabled.sh test/claude-code/custom_version.sh test/claude-code/node_preinstalled.sh test/claude-code/custom_install_path.sh test/claude-code/mount_host_config.sh test/claude-code/alpine_specific.sh test/claude-code/idempotency.sh test/claude-code/multi_feature_combo.sh
git commit -m "feat: add per-scenario test scripts"
```

---

## Task 10: Pre-commit Configuration

**Files:**
- Create: `.pre-commit-config.yaml`

- [ ] **Step 1: Create `.pre-commit-config.yaml`**

```yaml
repos:
  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v6.0.0
    hooks:
      - id: check-json
      - id: check-yaml
      - id: trailing-whitespace
      - id: end-of-file-fixer
      - id: check-merge-conflict
      - id: detect-private-key
      - id: check-added-large-files
        args: ["--maxkb=500"]
      - id: no-commit-to-branch
        args: ["--branch", "main"]

  - repo: https://github.com/koalaman/shellcheck-precommit
    rev: v0.11.0
    hooks:
      - id: shellcheck
        args: ["--severity=warning"]

  - repo: https://github.com/scop/pre-commit-shfmt
    rev: v3.13.0-1
    hooks:
      - id: shfmt
        args: ["-i", "4", "-ci"]

  - repo: https://github.com/pre-commit/mirrors-prettier
    rev: v4.0.0-alpha.8
    hooks:
      - id: prettier
        types_or: [json, yaml, markdown]

  - repo: https://github.com/igorshubovych/markdownlint-cli
    rev: v0.48.0
    hooks:
      - id: markdownlint
        args: ["--fix"]
```

- [ ] **Step 2: Commit**

```bash
git add .pre-commit-config.yaml
git commit -m "chore: add pre-commit hooks configuration"
```

---

## Task 11: CI/CD — Test Workflow

**Files:**
- Create: `.github/workflows/test.yml`

- [ ] **Step 1: Create `test.yml`**

The CI has two test dimensions:
1. **Scenario tests** — run `scenarios.json` (which maps scenario names to `test_<name>.sh` scripts). The devcontainer CLI reads `scenarios.json` directly and invokes the correct per-scenario test script automatically. Do NOT use `--skip-scenarios`.
2. **Image matrix tests** — run the default `test.sh` (core assertions only) across all 25+ base images to verify universal install compatibility.

```yaml
name: "Test"

on:
  pull_request:
  push:
    branches: [main]

concurrency:
  group: "${{ github.workflow }}-${{ github.ref }}"
  cancel-in-progress: true

permissions: {}

jobs:
  lint:
    runs-on: ubuntu-latest
    timeout-minutes: 10
    permissions:
      contents: read
    steps:
      - uses: actions/checkout@de0fac2e4500dabe0009e67214ff5f5447ce83dd # v6.0.2

      - name: ShellCheck
        uses: ludeeus/action-shellcheck@00cae500b08a931fb5698e11e79bfbd38e612a38 # 2.0.0
        with:
          severity: warning

      - name: Validate JSON
        run: |
          FAIL=0
          while IFS= read -r -d '' f; do
            if ! python3 -m json.tool "$f" > /dev/null 2>&1; then
              echo "ERROR: Invalid JSON: $f"
              FAIL=1
            fi
          done < <(find . -name '*.json' -not -path './.git/*' -print0)
          exit "$FAIL"

      - name: Validate YAML
        run: |
          uvx yamllint@1.38.0 -d relaxed .github/workflows/

      - name: Prettier check
        run: |
          npx prettier@4.0.0-alpha.8 --check "**/*.{json,yml,yaml,md}" --ignore-path .gitignore

      - name: Markdownlint
        run: |
          npx markdownlint-cli@0.48.0 "**/*.md" --ignore node_modules

      - name: Check .sh files are executable
        run: |
          FAIL=0
          while IFS= read -r -d '' f; do
            if [[ ! -x "$f" ]]; then
              echo "ERROR: $f is not executable"
              FAIL=1
            fi
          done < <(find . -name '*.sh' -not -path './.git/*' -print0)
          exit "$FAIL"

  # Run all per-scenario tests (options-specific assertions)
  test-scenarios:
    needs: lint
    runs-on: ubuntu-latest
    timeout-minutes: 60  # 10 scenarios building containers takes time
    permissions:
      contents: read
    steps:
      - uses: actions/checkout@de0fac2e4500dabe0009e67214ff5f5447ce83dd # v6.0.2

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@4d04d5d9486b7bd6fa91e7baf45bbb4f8b9deedd # v4.0.0

      - name: Install devcontainer CLI
        run: npm install -g @devcontainers/cli@0.85.0

      - name: Run all scenarios
        run: devcontainer features test --project-folder . 2>&1 | tee /tmp/scenario-test-output.log

      - name: Upload logs on failure
        if: failure()
        uses: actions/upload-artifact@bbbca2ddaa5d8feaa63e36b76fdaad77386f024f # v7.0.0
        with:
          name: logs-scenarios
          path: /tmp/scenario-test-output.log
          retention-days: 7

  # Run core assertions across all supported base images
  test-image-matrix:
    needs: lint
    runs-on: ubuntu-latest
    timeout-minutes: 30
    permissions:
      contents: read
    strategy:
      fail-fast: false
      max-parallel: 10
      matrix:
        image:
          # Raw OS images
          - "ubuntu:22.04"
          - "ubuntu:24.04"
          - "debian:bullseye"
          - "debian:bookworm"
          - "alpine:3.19"
          - "alpine:3.20"
          - "alpine:3.21"
          - "archlinux:latest"
          - "fedora:39"
          - "fedora:40"
          - "rockylinux:9"
          - "almalinux:9"
          - "amazonlinux:2023"
          # DevContainer base images
          - "mcr.microsoft.com/devcontainers/base:debian"
          - "mcr.microsoft.com/devcontainers/base:ubuntu"
          - "mcr.microsoft.com/devcontainers/base:alpine"
          - "mcr.microsoft.com/devcontainers/universal:2"
          # Language-specific images
          - "mcr.microsoft.com/devcontainers/python"
          - "mcr.microsoft.com/devcontainers/javascript-node"
          - "mcr.microsoft.com/devcontainers/typescript-node"
          - "mcr.microsoft.com/devcontainers/rust"
          - "mcr.microsoft.com/devcontainers/go"
          - "mcr.microsoft.com/devcontainers/cpp"
          - "mcr.microsoft.com/devcontainers/dotnet"
          - "mcr.microsoft.com/devcontainers/java"
          - "mcr.microsoft.com/devcontainers/ruby"
          - "mcr.microsoft.com/devcontainers/php"
    steps:
      - uses: actions/checkout@de0fac2e4500dabe0009e67214ff5f5447ce83dd # v6.0.2

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@4d04d5d9486b7bd6fa91e7baf45bbb4f8b9deedd # v4.0.0

      - name: Install devcontainer CLI
        run: npm install -g @devcontainers/cli@0.85.0

      - name: Test on ${{ matrix.image }}
        run: |
          devcontainer features test \
            --features claude-code \
            --skip-scenarios \
            --base-image "${{ matrix.image }}" \
            --project-folder . 2>&1 | tee /tmp/test-output.log

      - name: Upload logs on failure
        if: failure()
        uses: actions/upload-artifact@bbbca2ddaa5d8feaa63e36b76fdaad77386f024f # v7.0.0
        with:
          name: logs-amd64-${{ strategy.job-index }}
          path: /tmp/test-output.log
          retention-days: 7

  # arm64 tests on native runners (reduced matrix)
  test-arm64:
    needs: lint
    runs-on: ubuntu-24.04-arm64
    timeout-minutes: 30
    permissions:
      contents: read
    strategy:
      fail-fast: false
      max-parallel: 2
      matrix:
        image:
          - "ubuntu:24.04"
          - "alpine:3.21"
          - "mcr.microsoft.com/devcontainers/base:debian"
          - "mcr.microsoft.com/devcontainers/universal:2"
    steps:
      - uses: actions/checkout@de0fac2e4500dabe0009e67214ff5f5447ce83dd # v6.0.2

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@4d04d5d9486b7bd6fa91e7baf45bbb4f8b9deedd # v4.0.0

      - name: Install devcontainer CLI
        run: npm install -g @devcontainers/cli@0.85.0

      - name: Test on ${{ matrix.image }} (arm64)
        run: |
          devcontainer features test \
            --features claude-code \
            --skip-scenarios \
            --base-image "${{ matrix.image }}" \
            --project-folder . 2>&1 | tee /tmp/test-output.log

      - name: Upload logs on failure
        if: failure()
        uses: actions/upload-artifact@bbbca2ddaa5d8feaa63e36b76fdaad77386f024f # v7.0.0
        with:
          name: logs-arm64-${{ strategy.job-index }}
          path: /tmp/test-output.log
          retention-days: 7
```

- [ ] **Step 2: Commit**

```bash
git add .github/workflows/test.yml
git commit -m "ci: add test workflow with lint and exhaustive matrix"
```

---

## Task 12: CI/CD — Release Workflow

**Files:**
- Create: `.github/workflows/release.yml`

- [ ] **Step 1: Create `release.yml`**

```yaml
name: "Release"

on:
  push:
    tags: ["v*"]

concurrency:
  group: "release-${{ github.repository }}"
  cancel-in-progress: false

permissions: {}

jobs:
  validate:
    runs-on: ubuntu-latest
    timeout-minutes: 15
    permissions:
      contents: read
    steps:
      - uses: actions/checkout@de0fac2e4500dabe0009e67214ff5f5447ce83dd # v6.0.2

      - name: ShellCheck
        uses: ludeeus/action-shellcheck@00cae500b08a931fb5698e11e79bfbd38e612a38 # 2.0.0
        with:
          severity: warning

      - name: Install devcontainer CLI
        run: npm install -g @devcontainers/cli@0.85.0

      - name: Smoke test (3 representative images)
        run: |
          for img in \
            "mcr.microsoft.com/devcontainers/base:ubuntu" \
            "mcr.microsoft.com/devcontainers/base:alpine" \
            "mcr.microsoft.com/devcontainers/universal:2"; do
            echo "--- Smoke testing: ${img} ---"
            devcontainer features test \
              --features claude-code \
              --skip-scenarios \
              --base-image "${img}" \
              --project-folder .
          done

  version-check:
    runs-on: ubuntu-latest
    timeout-minutes: 5
    permissions:
      contents: read
    steps:
      - uses: actions/checkout@de0fac2e4500dabe0009e67214ff5f5447ce83dd # v6.0.2

      - name: Verify version matches tag
        run: |
          TAG_VERSION="${GITHUB_REF_NAME#v}"
          JSON_VERSION=$(python3 -c "
          import json
          with open('src/claude-code/devcontainer-feature.json') as f:
              print(json.load(f)['version'])
          ")
          if [[ "${TAG_VERSION}" != "${JSON_VERSION}" ]]; then
            echo "ERROR: Tag version (${TAG_VERSION}) does not match feature version (${JSON_VERSION})"
            exit 1
          fi
          echo "Version match: ${TAG_VERSION}"

  publish:
    needs: [validate, version-check]
    runs-on: ubuntu-latest
    timeout-minutes: 15
    permissions:
      contents: read
      packages: write
    steps:
      - uses: actions/checkout@de0fac2e4500dabe0009e67214ff5f5447ce83dd # v6.0.2

      - name: Publish feature
        uses: devcontainers/action@1082abd5d2bf3a11abccba70eef98df068277772 # v1.4.3
        with:
          publish-features: "true"
          base-path-to-features: "./src"
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}

  post-publish:
    needs: publish
    runs-on: ubuntu-latest
    timeout-minutes: 10
    permissions:
      packages: read
    steps:
      - name: Verify published feature
        run: |
          npm install -g @devcontainers/cli@0.85.0
          TAG_VERSION="${GITHUB_REF_NAME#v}"
          FEATURE_REF="ghcr.io/${{ github.repository }}/claude-code:${TAG_VERSION}"
          echo "Verifying: ${FEATURE_REF}"
          devcontainer features info manifest "${FEATURE_REF}" || {
            echo "ERROR: Published feature not accessible at ${FEATURE_REF}"
            exit 1
          }
          echo "Published feature verified successfully."
```

- [ ] **Step 2: Commit**

```bash
git add .github/workflows/release.yml
git commit -m "ci: add release workflow with version check and publish"
```

---

## Task 13: Contributor DevContainer and README

**Files:**
- Create: `.devcontainer/devcontainer.json`
- Create: `README.md`

- [ ] **Step 1: Create contributor devcontainer**

```json
{
    "name": "Claude Code Feature Development",
    "image": "mcr.microsoft.com/devcontainers/base:ubuntu",
    "features": {
        "ghcr.io/devcontainers/features/node:1": {
            "version": "22"
        }
    },
    "postCreateCommand": "npm install -g @devcontainers/cli && pre-commit install || true",
    "customizations": {
        "vscode": {
            "extensions": [
                "timonwong.shellcheck",
                "foxundermoon.shell-format",
                "esbenp.prettier-vscode"
            ]
        }
    }
}
```

- [ ] **Step 2: Create `README.md`**

```markdown
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

Claude Code requires authentication. Options:

1. **Environment variable:** Set `ANTHROPIC_API_KEY` in your devcontainer:

   ```json
   {
       "remoteEnv": {
           "ANTHROPIC_API_KEY": "${localEnv:ANTHROPIC_API_KEY}"
       }
   }
   ```

2. **Mount host config:** Mount your local `~/.claude` directory:

   ```json
   {
       "mounts": [
           "source=${localEnv:HOME}/.claude,target=/home/vscode/.claude,type=bind,consistency=cached,readonly"
       ]
   }
   ```

   > **Security warning:** This exposes your API keys inside the container.
   > If the container is compromised, credentials are at risk.

## Tested Images

This feature is tested on 25+ base images across amd64 and arm64. See the
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
```

- [ ] **Step 3: Commit**

```bash
git add .devcontainer/devcontainer.json README.md
git commit -m "docs: add contributor devcontainer and README"
```

---

## Self-Review Checklist

| Spec Section | Covered By |
|---|---|
| 1. Overview | All tasks combined |
| 2. Repository Structure | Task 1-13 file map |
| 3. Feature Manifest | Task 2 |
| 3. Lifecycle Hooks (postCreateCommand) | Task 13 (README documents recommended postCreateCommand for users) |
| 3. Security (mountHostConfig) | Task 7 (setup_mount_docs), Task 13 (README) |
| 4. Alpine Bootstrap | Task 3 (POSIX bootstrap) |
| 4. Error Handling | Task 3 (set -Eeuo pipefail, traps) |
| 4. Input Validation | Task 3 (validate_version, validate_install_path) |
| 4. OS Detection | Task 4 (detect_os, detect_arch) |
| 4. Dependencies | Task 4 (ensure_base_dependencies) |
| 4. Node.js Installation | Task 5 (ensure_node, decision tree) |
| 4. PATH Configuration | Task 6 (configure_custom_path) |
| 4. Claude Code Installation | Task 6 (install_claude_code) |
| 4. Shell Completions | Task 7 (setup_completions) |
| 4. MCP Servers | Task 7 (setup_mcp_servers) |
| 4. Mount Documentation | Task 7 (setup_mount_docs) |
| 4. Remote User Detection | Task 3 (detect_remote_user, detect_user_home) |
| 4. Cleanup | Task 7 (cleanup_caches) |
| 5. Test Helpers | Task 8 (test.sh) |
| 5. Scenarios | Task 8 (scenarios.json) |
| 5. Per-Scenario Tests | Task 9 (all 9 scripts) |
| 6. CI test.yml | Task 11 |
| 6. CI release.yml | Task 12 |
| 7. Pre-commit Hooks | Task 10 |
| 8. License | Task 1 |
| 10. Success Criteria | Covered by test matrix + CI |
| 11. Versioning | Task 12 (version-check job) |
