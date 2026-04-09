#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=test.sh
source "${SCRIPT_DIR}/test.sh"

echo "=== Scenario: completions_disabled ==="
core_assertions

echo "--- Bash completions absent ---"
check_file_absent /usr/share/bash-completion/completions/claude
check_file_absent /etc/bash_completion.d/claude

echo "--- Fish completions absent ---"
check_file_absent /usr/share/fish/vendor_completions.d/claude.fish
check_file_absent /usr/share/fish/completions/claude.fish

echo "--- Zsh completions absent ---"
if command -v zsh >/dev/null 2>&1; then
    check_file_absent /usr/share/zsh/site-functions/_claude
else
    pass "zsh not installed — skipping"
fi

test_summary
