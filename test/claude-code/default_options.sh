#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=test.sh
source "${SCRIPT_DIR}/test.sh"

echo "=== Scenario: default_options ==="
core_assertions

echo "--- Completions: bash ---"
if [[ -d /usr/share/bash-completion/completions ]]; then
    check_file_exists /usr/share/bash-completion/completions/claude
    check_completion_file_contents /usr/share/bash-completion/completions/claude \
        "_" "#" "if " "function " "#!/"
    # Verify completions contain expected subcommands
    check_file_contains /usr/share/bash-completion/completions/claude "auth"
    check_file_contains /usr/share/bash-completion/completions/claude "mcp"
    check_file_contains /usr/share/bash-completion/completions/claude "update"
elif [[ -d /etc/bash_completion.d ]]; then
    check_file_exists /etc/bash_completion.d/claude
    check_completion_file_contents /etc/bash_completion.d/claude \
        "_" "#" "if " "function " "#!/"
else
    pass "Bash completion directory absent — skipping"
fi

echo "--- Completions: zsh ---"
if command -v zsh >/dev/null 2>&1; then
    check_file_exists /usr/share/zsh/site-functions/_claude
    check_completion_file_contents /usr/share/zsh/site-functions/_claude \
        "#compdef" "#" "_"
    check_file_contains /usr/share/zsh/site-functions/_claude "auth"
    check_file_contains /usr/share/zsh/site-functions/_claude "mcp"
else
    pass "zsh not installed — skipping"
fi

echo "--- Completions: fish ---"
FISH_COMP_FILE=""
for dir in /usr/share/fish/vendor_completions.d /usr/share/fish/completions; do
    if [[ -f "${dir}/claude.fish" ]]; then
        FISH_COMP_FILE="${dir}/claude.fish"
        break
    fi
done
if [[ -n "${FISH_COMP_FILE}" ]]; then
    check_completion_file_contents "${FISH_COMP_FILE}" "complete" "#"
    check_file_contains "${FISH_COMP_FILE}" "auth"
    check_file_contains "${FISH_COMP_FILE}" "mcp"
elif command -v fish >/dev/null 2>&1; then
    # Fish is installed — completions dir should have been created
    fail "Fish installed but no completion file found"
else
    pass "fish not installed — skipping"
fi

echo "--- MCP config should be absent ---"
check_file_absent "${HOME}/.claude/mcp_servers.json"

test_summary
