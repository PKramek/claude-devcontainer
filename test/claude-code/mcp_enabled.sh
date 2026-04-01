#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=test.sh
source "${SCRIPT_DIR}/test.sh"

echo "=== Scenario: mcp_enabled ==="
core_assertions

echo "--- MCP config ---"
MCP_CONFIG="${HOME}/.claude/mcp_servers.json"
check_file_exists "${MCP_CONFIG}"
check_file_valid_json "${MCP_CONFIG}"
check_file_owner "${MCP_CONFIG}" "$(whoami)"
check_permissions "${HOME}/.claude" "700"
check_permissions "${MCP_CONFIG}" "600"

test_summary
