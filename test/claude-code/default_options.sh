#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=test.sh
source "${SCRIPT_DIR}/test.sh"

echo "=== Scenario: default_options ==="
core_assertions

echo "--- Completions: bash ---"
if [[ -d /usr/share/bash-completion/completions ]]; then
    if [[ -f /usr/share/bash-completion/completions/claude ]]; then
        check_completion_file_contents /usr/share/bash-completion/completions/claude "_" "#" "if"
    else
        pass "Bash completion not written — install skipped (no valid output from completions command)"
    fi
elif [[ -d /etc/bash_completion.d ]]; then
    if [[ -f /etc/bash_completion.d/claude ]]; then
        check_completion_file_contents /etc/bash_completion.d/claude "_" "#" "if"
    else
        pass "Bash completion not written — install skipped (no valid output from completions command)"
    fi
else
    pass "Bash completion directory absent — skipping bash completion check"
fi

echo "--- Completions: zsh ---"
if command -v zsh >/dev/null 2>&1; then
    if [[ -f /usr/share/zsh/site-functions/_claude ]]; then
        check_completion_file_contents /usr/share/zsh/site-functions/_claude "#compdef" "#"
    else
        pass "Zsh completion not written — install skipped (no valid output from completions command)"
    fi
else
    pass "zsh not installed — skipping zsh completion check"
fi

echo "--- Completions: fish ---"
# Attempt to install fish so the fish completion path is exercised.
# This is a best-effort step: non-apt images (Alpine, Arch, etc.) will silently skip.
apt-get install -y --no-install-recommends fish >/dev/null 2>&1 || true
if command -v fish >/dev/null 2>&1; then
    mkdir -p /usr/share/fish/vendor_completions.d
    # Re-run setup_completions in a subshell so that only the function is sourced,
    # not the full install script (which would re-install claude).
    # The install script is persisted to a stable path at the end of installation.
    (
        export SHELL_COMPLETIONS="true"
        # shellcheck source=/dev/null
        source /usr/local/share/devcontainer-features/claude-code/install.sh 2>/dev/null || true
        setup_completions
    ) || true
    if [[ -f /usr/share/fish/vendor_completions.d/claude.fish ]]; then
        check_completion_file_contents /usr/share/fish/vendor_completions.d/claude.fish "complete"
    else
        pass "Fish completion not written — install skipped (no valid output from completions command)"
    fi
else
    pass "fish not available — skipping fish completion check"
fi

echo "--- MCP config should be absent ---"
check_file_absent "${HOME}/.claude/mcp_servers.json"

test_summary
