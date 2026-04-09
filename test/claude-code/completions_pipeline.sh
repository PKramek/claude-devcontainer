#!/usr/bin/env bash
#
# Scenario: completions_pipeline
# Validates that static completion files are installed correctly and pass
# integrity checks.
#
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=test.sh
source "${SCRIPT_DIR}/test.sh"

echo "=== Scenario: completions_pipeline ==="
core_assertions

# --- Verify the persisted completions directory exists ---
PERSIST_DIR="/usr/local/share/devcontainer-features/claude-code"
echo "--- Persisted completions directory ---"
check_dir_exists "${PERSIST_DIR}/completions"
check_file_exists "${PERSIST_DIR}/completions/claude.bash"
check_file_exists "${PERSIST_DIR}/completions/_claude.zsh"
check_file_exists "${PERSIST_DIR}/completions/claude.fish"

# --- Bash completion installed and valid ---
echo "--- Bash completion file ---"
if [[ -d /usr/share/bash-completion/completions ]]; then
    check_file_exists /usr/share/bash-completion/completions/claude
    check_completion_file_integrity /usr/share/bash-completion/completions/claude
    check_file_contains /usr/share/bash-completion/completions/claude "_claude"
    check_file_contains /usr/share/bash-completion/completions/claude "complete -F _claude claude"
    check_permissions /usr/share/bash-completion/completions/claude "644"
elif [[ -d /etc/bash_completion.d ]]; then
    check_file_exists /etc/bash_completion.d/claude
    check_completion_file_integrity /etc/bash_completion.d/claude
    check_file_contains /etc/bash_completion.d/claude "_claude"
    check_permissions /etc/bash_completion.d/claude "644"
else
    pass "No bash completion directory found — skipping"
fi

# --- Zsh completion installed and valid ---
echo "--- Zsh completion file ---"
if command -v zsh >/dev/null 2>&1; then
    check_file_exists /usr/share/zsh/site-functions/_claude
    check_completion_file_integrity /usr/share/zsh/site-functions/_claude
    check_file_contains /usr/share/zsh/site-functions/_claude "#compdef claude"
    check_permissions /usr/share/zsh/site-functions/_claude "644"
else
    pass "zsh not installed — skipping"
fi

# --- Fish completion installed and valid ---
echo "--- Fish completion file ---"
FISH_COMP_FILE=""
for dir in /usr/share/fish/vendor_completions.d /usr/share/fish/completions; do
    if [[ -f "${dir}/claude.fish" ]]; then
        FISH_COMP_FILE="${dir}/claude.fish"
        break
    fi
done
if [[ -n "${FISH_COMP_FILE}" ]]; then
    check_completion_file_integrity "${FISH_COMP_FILE}"
    check_file_contains "${FISH_COMP_FILE}" "complete -c claude"
    check_permissions "${FISH_COMP_FILE}" "644"
elif command -v fish >/dev/null 2>&1; then
    # fish is installed but no known completion dir existed — check vendor dir
    if [[ -f /usr/share/fish/vendor_completions.d/claude.fish ]]; then
        check_completion_file_integrity /usr/share/fish/vendor_completions.d/claude.fish
    else
        fail "Fish installed but completion not found"
    fi
else
    pass "fish not installed and no completion directory — skipping"
fi

# --- Verify completion content covers key subcommands ---
echo "--- Completion content coverage ---"
BASH_COMP=""
if [[ -f /usr/share/bash-completion/completions/claude ]]; then
    BASH_COMP="/usr/share/bash-completion/completions/claude"
elif [[ -f /etc/bash_completion.d/claude ]]; then
    BASH_COMP="/etc/bash_completion.d/claude"
fi

if [[ -n "${BASH_COMP}" ]]; then
    for subcmd in agents auth doctor mcp update upgrade; do
        check_file_contains "${BASH_COMP}" "${subcmd}"
    done
    for flag in "--help" "--version" "--model" "--permission-mode"; do
        check_file_contains "${BASH_COMP}" "${flag}"
    done
fi

test_summary
