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
