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

    # Always ensure ca-certificates for TLS verification
    case "${OS_FAMILY}" in
        alpine)
            command -v update-ca-certificates > /dev/null 2>&1 || missing+=("ca-certificates")
            ;;
        debian)
            [[ -d /etc/ssl/certs ]] && [[ -n "$(ls /etc/ssl/certs/ 2>/dev/null)" ]] || missing+=("ca-certificates")
            ;;
    esac

    if [[ ${#missing[@]} -gt 0 ]]; then
        log_info "Installing missing dependencies: ${missing[*]}"
        install_packages "${missing[@]}"
    fi
}

ensure_base_dependencies

log_info "Installation complete."
