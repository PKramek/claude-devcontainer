#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=test.sh
source "${SCRIPT_DIR}/test.sh"

echo "=== Scenario: idempotency ==="

echo "--- First run assertions ---"
core_assertions

ORIGINAL_CLAUDE_VERSION=$(claude --version 2>/dev/null | head -n1)
ORIGINAL_NODE_VERSION=$(node --version 2>/dev/null)

echo "--- Second run (idempotent re-install) ---"
INSTALL_SCRIPT="/usr/local/share/devcontainer-features/claude-code/install.sh"
check_file_exists "${INSTALL_SCRIPT}"

# Pass the same default options that the first run used
sudo VERSION=latest NODEVERSION=lts INSTALLPATH=/usr/local \
    ENABLEMCPSERVERS=false MOUNTHOSTCONFIG=false SHELLCOMPLETIONS=true \
    bash "${INSTALL_SCRIPT}" 2>&1

echo "--- Post re-run assertions ---"
core_assertions

RERUN_CLAUDE_VERSION=$(claude --version 2>/dev/null | head -n1)
RERUN_NODE_VERSION=$(node --version 2>/dev/null)

if [[ "${ORIGINAL_CLAUDE_VERSION}" == "${RERUN_CLAUDE_VERSION}" ]]; then
    pass "Claude version unchanged after re-run: ${RERUN_CLAUDE_VERSION}"
else
    fail "Claude version changed: ${ORIGINAL_CLAUDE_VERSION} -> ${RERUN_CLAUDE_VERSION}"
fi

if [[ "${ORIGINAL_NODE_VERSION}" == "${RERUN_NODE_VERSION}" ]]; then
    pass "Node version unchanged after re-run: ${RERUN_NODE_VERSION}"
else
    fail "Node version changed: ${ORIGINAL_NODE_VERSION} -> ${RERUN_NODE_VERSION}"
fi

echo "--- Persisted script still exists ---"
check_file_exists "${INSTALL_SCRIPT}"

test_summary
