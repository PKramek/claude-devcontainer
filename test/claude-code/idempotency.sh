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
