#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=test.sh
source "${SCRIPT_DIR}/test.sh"

echo "=== Scenario: security_permissions ==="
core_assertions

echo "--- Claude binary permissions ---"
CLAUDE_PATH=$(command -v claude)
check_permissions "${CLAUDE_PATH}" "755"

echo "--- No world-writable files under install path ---"
if [[ -d /usr/local/lib/node_modules/@anthropic-ai ]]; then
    check_no_world_writable "/usr/local/lib/node_modules/@anthropic-ai"
else
    pass "npm package dir not at expected location — skipping world-writable check"
fi

echo "--- MCP config permissions ---"
MCP_CONFIG="${HOME}/.claude/mcp_servers.json"
check_file_exists "${MCP_CONFIG}"
check_permissions "${HOME}/.claude" "700"
check_permissions "${MCP_CONFIG}" "600"
check_file_owner "${MCP_CONFIG}" "$(whoami)"
check_file_owner "${HOME}/.claude" "$(whoami)"
check_file_valid_json "${MCP_CONFIG}"

echo "--- Profile.d permissions ---"
if [[ -f /etc/profile.d/claude-code.sh ]]; then
    check_permissions /etc/profile.d/claude-code.sh "644"
fi

echo "--- Completion file integrity (if written) ---"
for comp_file in \
    /usr/share/bash-completion/completions/claude \
    /etc/bash_completion.d/claude \
    /usr/share/zsh/site-functions/_claude \
    /usr/share/fish/vendor_completions.d/claude.fish; do
    if [[ -f "${comp_file}" ]]; then
        check_completion_file_integrity "${comp_file}"
    fi
done

test_summary
