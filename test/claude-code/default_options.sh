#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=test.sh
source "${SCRIPT_DIR}/test.sh"

echo "=== Scenario: default_options ==="
core_assertions

echo "--- Completions ---"
# At least one completion directory should have the claude file
FOUND_COMPLETIONS=false
for path in \
    /usr/share/bash-completion/completions/claude \
    /etc/bash_completion.d/claude \
    /usr/share/zsh/site-functions/_claude \
    /usr/share/fish/vendor_completions.d/claude.fish \
    /usr/share/fish/completions/claude.fish; do
    if [[ -f "${path}" ]]; then
        FOUND_COMPLETIONS=true
        pass "Completion file found: ${path}"
    fi
done
if [[ "${FOUND_COMPLETIONS}" == "false" ]]; then
    fail "No shell completion files found"
fi

echo "--- MCP config should be absent ---"
check_file_absent "${HOME}/.claude/mcp_servers.json"

test_summary
