#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=test.sh
source "${SCRIPT_DIR}/test.sh"

echo "=== Scenario: upgrade_version ==="
core_assertions

echo "--- Initial version check ---"
INITIAL_VERSION=$(claude --version 2>/dev/null | head -n1)
if [[ "${INITIAL_VERSION}" == *"0.2.57"* ]]; then
    pass "Initial version is 0.2.57: ${INITIAL_VERSION}"
else
    fail "Initial version is not 0.2.57: ${INITIAL_VERSION}"
fi

echo "--- Upgrade to latest ---"
INSTALL_SCRIPT="/usr/local/share/devcontainer-features/claude-code/install.sh"
check_file_exists "${INSTALL_SCRIPT}"

sudo VERSION=latest NODEVERSION=lts INSTALLPATH=/usr/local \
    ENABLEMCPSERVERS=false MOUNTHOSTCONFIG=false SHELLCOMPLETIONS=true \
    bash "${INSTALL_SCRIPT}" 2>&1

echo "--- Post-upgrade check ---"
UPGRADED_VERSION=$(claude --version 2>/dev/null | head -n1)
if [[ "${UPGRADED_VERSION}" != *"0.2.57"* ]]; then
    pass "Version changed after upgrade: ${UPGRADED_VERSION}"
else
    fail "Version unchanged after upgrade: ${UPGRADED_VERSION}"
fi

test_summary
