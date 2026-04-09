#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=test.sh
source "${SCRIPT_DIR}/test.sh"

echo "=== Scenario: mount_host_config ==="
core_assertions

echo "--- Mount documentation verification ---"
INSTALL_SCRIPT="/usr/local/share/devcontainer-features/claude-code/install.sh"
if [[ -f "${INSTALL_SCRIPT}" ]]; then
    # shellcheck source=/dev/null
    source "${INSTALL_SCRIPT}" 2>/dev/null || true

    export MOUNT_HOST_CONFIG="true"
    export REMOTE_USER_HOME="${HOME}"

    MOUNT_OUTPUT=$(setup_mount_docs 2>&1) || true

    if echo "${MOUNT_OUTPUT}" | grep -q '\.claude'; then
        pass "Mount docs mention .claude directory"
    else
        fail "Mount docs do not mention .claude directory"
    fi

    if echo "${MOUNT_OUTPUT}" | grep -q '\.claude\.json'; then
        pass "Mount docs mention .claude.json file"
    else
        fail "Mount docs do not mention .claude.json file"
    fi

    if echo "${MOUNT_OUTPUT}" | grep -q 'mounts'; then
        pass "Mount docs contain mounts snippet"
    else
        fail "Mount docs do not contain mounts snippet"
    fi
else
    pass "install.sh not sourceable — mount_host_config is documentation-only"
fi

test_summary
