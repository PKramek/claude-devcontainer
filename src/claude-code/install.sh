#!/bin/sh
# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: 2026 PKramek
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
    if command -v apk >/dev/null 2>&1; then
        apk add --no-cache bash >/dev/null || {
            echo "[claude-code feature] ERROR: Failed to install bash via apk." >&2
            exit 1
        }
    fi
    if ! command -v bash >/dev/null 2>&1; then
        echo "[claude-code feature] ERROR: bash is required but could not be found or installed." >&2
        exit 1
    fi
    exec bash "$0" "$@"
fi
# --- From here on, bash is guaranteed ---

set -Eeuo pipefail
umask 0022

FEATURE_LOG_PREFIX="[claude-code feature]"

# Debug mode
if [[ "${DEBUG:-false}" == "true" ]]; then
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
log_info() { echo "${FEATURE_LOG_PREFIX} $*" >&2; }
log_warn() { echo "${FEATURE_LOG_PREFIX} WARNING: $*" >&2; }
log_error() { echo "${FEATURE_LOG_PREFIX} ERROR: $*" >&2; }
log_debug() {
    if [[ "${DEBUG:-false}" == "true" ]]; then
        echo "${FEATURE_LOG_PREFIX} DEBUG: $*" >&2
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
        debian | ubuntu | linuxmint)
            echo "debian"
            ;;
        alpine)
            echo "alpine"
            ;;
        arch | archarm | endeavouros | manjaro)
            echo "arch"
            ;;
        fedora | rhel | centos | rocky | almalinux | amzn)
            echo "rhel"
            ;;
        *)
            # Fallback to ID_LIKE
            case "${id_like}" in
                *debian* | *ubuntu*) echo "debian" ;;
                *arch*) echo "arch" ;;
                *fedora* | *rhel*) echo "rhel" ;;
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
        x86_64) echo "amd64" ;;
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

# --- Dependency Installation ---
install_packages() {
    local packages=("$@")
    case "${OS_FAMILY}" in
        debian)
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
            pacman -Sy --noconfirm --needed "${packages[@]}"
            ;;
        rhel)
            if command -v dnf >/dev/null 2>&1; then
                dnf install -y "${packages[@]}"
            else
                yum install -y "${packages[@]}"
            fi
            ;;
    esac
}

ensure_base_dependencies() {
    local missing=()

    command -v curl >/dev/null 2>&1 || missing+=("curl")
    command -v git >/dev/null 2>&1 || missing+=("git")

    # Always ensure ca-certificates for TLS verification (needed before any curl to nodejs.org/npm)
    case "${OS_FAMILY}" in
        alpine)
            command -v update-ca-certificates >/dev/null 2>&1 || missing+=("ca-certificates")
            ;;
        debian)
            [[ -d /etc/ssl/certs ]] && [[ -n "$(ls /etc/ssl/certs/ 2>/dev/null)" ]] || missing+=("ca-certificates")
            ;;
        arch)
            # ca-certificates may be absent on raw archlinux:latest images
            [[ -d /etc/ssl/certs ]] && [[ -n "$(ls /etc/ssl/certs/ 2>/dev/null)" ]] || missing+=("ca-certificates")
            ;;
        rhel)
            # ca-certificates may be absent on minimal Amazon Linux / Rocky / Alma images
            [[ -d /etc/pki/tls/certs ]] && [[ -n "$(ls /etc/pki/tls/certs/ 2>/dev/null)" ]] || missing+=("ca-certificates")
            ;;
    esac

    # xz decompression is required for Node.js binary tarballs (.tar.xz) on debian/rhel.
    # xz-utils (Debian) / xz (RHEL) may be absent on minimal base images.
    case "${OS_FAMILY}" in
        debian)
            command -v xz >/dev/null 2>&1 || missing+=("xz-utils")
            ;;
        rhel)
            command -v xz >/dev/null 2>&1 || missing+=("xz")
            command -v tar >/dev/null 2>&1 || missing+=("tar")
            ;;
    esac

    if [[ ${#missing[@]} -gt 0 ]]; then
        log_info "Installing missing dependencies: ${missing[*]}"
        install_packages "${missing[@]}"
    fi
}

ensure_base_dependencies

# --- Node.js Installation ---
NODE_MIN_VERSION=18

get_node_major_version() {
    local version_string
    version_string=$(node --version 2>/dev/null || echo "")
    if [[ -z "${version_string}" ]]; then
        echo "0"
        return
    fi
    echo "${version_string}" | sed 's/^v//' | cut -d. -f1
}

resolve_node_version() {
    local requested="$1"
    if [[ "${requested}" != "lts" ]]; then
        echo "${requested}"
        return
    fi

    local lts_version=""

    # Primary: parse index.tab (TSV) via awk — requires no JSON parser, no python3, no node.
    # The header row identifies the "lts" column; non-LTS rows contain "-" in that column.
    lts_version=$(curl -fsSL https://nodejs.org/dist/index.tab 2>/dev/null |
        awk 'NR==1 { for (i=1;i<=NF;i++) { if ($i=="lts") lts_col=i } next }
               lts_col && $lts_col!="-" { gsub(/^v/,"",$1); split($1,v,"."); print v[1]; exit }' \
            2>/dev/null || echo "")

    # Fallback: grep/sed on index.json — compatible with all POSIX systems.
    # LTS entries have "lts":"Codename"; non-LTS entries have "lts":false.
    if [[ -z "${lts_version}" ]]; then
        lts_version=$(curl -fsSL https://nodejs.org/dist/index.json 2>/dev/null |
            grep -m 1 '"lts":"' |
            grep -o '"version":"v[0-9]*' |
            sed 's/.*v//' \
                2>/dev/null || echo "")
    fi

    if [[ -z "${lts_version}" ]]; then
        log_warn "Could not resolve Node.js LTS version from nodejs.org, defaulting to 22"
        lts_version="22"
    fi

    log_info "Resolved LTS to Node.js ${lts_version}"
    echo "${lts_version}"
}

install_node_binary() {
    local version="$1"
    local arch_label
    case "$(uname -m)" in
        x86_64) arch_label="x64" ;;
        aarch64) arch_label="arm64" ;;
        *)
            log_error "Unsupported arch for Node.js binary: $(uname -m)"
            exit 1
            ;;
    esac

    log_info "Installing Node.js ${version} via official binary tarball..."

    TEMP_DIR=$(mktemp -d)
    local url="https://nodejs.org/dist/latest-v${version}.x/"

    local shasums
    shasums=$(curl -fsSL "${url}SHASUMS256.txt") || {
        log_error "Failed to download Node.js SHASUMS256.txt from ${url}"
        exit 1
    }

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

    local actual_sha
    actual_sha=$(sha256sum "${TEMP_DIR}/${tarball_name}" | awk '{print $1}')
    if [[ "${actual_sha}" != "${expected_sha}" ]]; then
        log_error "SHA256 checksum mismatch for Node.js tarball!"
        log_error "  Expected: ${expected_sha}"
        log_error "  Actual:   ${actual_sha}"
        exit 1
    fi
    log_info "SHA256 checksum verified."

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
        debian | rhel)
            install_node_binary "${resolved_version}"
            ;;
        alpine | arch)
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
    cat >/etc/profile.d/claude-code.sh <<PATHEOF
# Added by Claude Code DevContainer Feature
export PATH="${INSTALL_PATH}/bin:\${PATH}"
PATHEOF
    chmod 644 /etc/profile.d/claude-code.sh

    # Persistent PATH for Alpine ash non-login shells
    if [[ "${OS_FAMILY}" == "alpine" ]]; then
        # BusyBox ash reads ENV on startup for non-login shells
        # Write to /etc/profile (not /etc/environment which is PAM-specific)
        if ! grep -q 'claude-code' /etc/profile 2>/dev/null; then
            # shellcheck disable=SC2016  # ${PATH} is intentionally literal — expands at shell startup
            printf 'export PATH="%s/bin:${PATH}"  # claude-code\n' "${INSTALL_PATH}" >>/etc/profile
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

    # Verify installation and capture version in one invocation
    local installed_version
    installed_version=$(claude --version 2>/dev/null) || {
        log_error "Claude Code installed but 'claude' not found on PATH."
        log_error "PATH=${PATH}"
        exit 1
    }

    log_info "Claude Code ${installed_version} installed successfully."

    # npm may create the binary with 777; enforce 755 for security.
    local claude_bin
    claude_bin=$(command -v claude)
    chmod 755 "${claude_bin}"
}

configure_custom_path
install_claude_code

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
        timeout 30 claude completions bash </dev/null >"${bash_comp_dir}/claude" 2>/dev/null || {
            log_warn "Failed to install bash completions."
        }
    fi

    # Zsh completions
    if [[ -d /usr/share/zsh/site-functions ]] || mkdir -p /usr/share/zsh/site-functions 2>/dev/null; then
        timeout 30 claude completions zsh </dev/null >/usr/share/zsh/site-functions/_claude 2>/dev/null || {
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
        timeout 30 claude completions fish </dev/null >"${fish_comp_dir}/claude.fish" 2>/dev/null || {
            log_warn "Failed to install fish completions."
        }
    fi

    log_info "Shell completions installed."
}

setup_completions

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

    cat >"${mcp_config}" <<'MCPEOF'
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
            if command -v dnf >/dev/null 2>&1; then
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

# Persist this script so tests and postCreateCommand hooks can re-invoke it.
# The devcontainer CLI removes /tmp/dev-container-features/ after installation,
# so we copy to a stable path before that cleanup occurs.
PERSIST_DIR="/usr/local/share/devcontainer-features/claude-code"
mkdir -p "${PERSIST_DIR}"
cp "$0" "${PERSIST_DIR}/install.sh"
chmod +x "${PERSIST_DIR}/install.sh"
log_debug "Install script persisted to ${PERSIST_DIR}/install.sh"

log_info "Claude Code DevContainer Feature installation complete."
log_info "  Claude Code: $(claude --version 2>/dev/null || echo 'unknown')"
log_info "  Node.js: $(node --version 2>/dev/null || echo 'unknown')"
log_info "  OS: ${OS_FAMILY} (${ARCH})"
log_info "  User: ${REMOTE_USER}"
