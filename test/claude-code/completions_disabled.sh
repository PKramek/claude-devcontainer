#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=test.sh
source "${SCRIPT_DIR}/test.sh"

echo "=== Scenario: completions_disabled ==="
core_assertions

echo "--- Completions should be absent ---"
check_file_absent /usr/share/bash-completion/completions/claude
check_file_absent /etc/bash_completion.d/claude
check_file_absent /usr/share/zsh/site-functions/_claude
check_file_absent /usr/share/fish/vendor_completions.d/claude.fish
check_file_absent /usr/share/fish/completions/claude.fish

test_summary
