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
