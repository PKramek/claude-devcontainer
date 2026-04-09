#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=test.sh
source "${SCRIPT_DIR}/test.sh"

echo "=== Scenario: custom_node_version ==="
core_assertions

echo "--- Node.js 22.x installed ---"
NODE_MAJOR=$(node --version 2>/dev/null | sed 's/^v//' | cut -d. -f1)
if [[ "${NODE_MAJOR}" == "22" ]]; then
    pass "Node.js major version is 22"
else
    fail "Node.js major version is ${NODE_MAJOR}, expected 22"
fi

test_summary
