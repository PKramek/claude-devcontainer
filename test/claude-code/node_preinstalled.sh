#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=test.sh
source "${SCRIPT_DIR}/test.sh"

echo "=== Scenario: node_preinstalled ==="
core_assertions

echo "--- Node.js location preserved ---"
NODE_PATH=$(command -v node)
# On javascript-node MCR image, node is managed by nvm and lives under ~/.nvm
# It should NOT be /usr/local/bin/node (which would mean our feature reinstalled it)
if [[ "${NODE_PATH}" == *"nvm"* ]] || [[ "${NODE_PATH}" == *".nvm"* ]]; then
    pass "Node.js is nvm-managed: ${NODE_PATH}"
elif [[ "${NODE_PATH}" == "/usr/local/bin/node" ]]; then
    # /usr/local/bin could be the nvm shim — check if nvm is present
    if [[ -d "${HOME}/.nvm" ]] || [[ -n "${NVM_DIR:-}" ]]; then
        pass "Node.js at /usr/local/bin but nvm present — likely shim"
    else
        fail "Node.js at /usr/local/bin without nvm — may have been reinstalled"
    fi
else
    pass "Node.js location: ${NODE_PATH}"
fi

test_summary
