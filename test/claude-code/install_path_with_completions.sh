#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=test.sh
source "${SCRIPT_DIR}/test.sh"

echo "=== Scenario: install_path_with_completions ==="

echo "--- Binary at custom path ---"
check_file_exists /opt/claude/bin/claude

echo "--- PATH includes custom path ---"
if echo "${PATH}" | grep -q '/opt/claude/bin'; then
    pass "PATH contains /opt/claude/bin"
else
    fail "PATH does not contain /opt/claude/bin"
fi

echo "--- Profile.d script ---"
check_file_exists /etc/profile.d/claude-code.sh
check_file_contains /etc/profile.d/claude-code.sh '/opt/claude/bin'

echo "--- Completions with custom path ---"
if [[ -d /usr/share/bash-completion/completions ]]; then
    check_file_exists /usr/share/bash-completion/completions/claude
    check_completion_file_contents /usr/share/bash-completion/completions/claude \
        "_" "#" "if " "function " "#!/"
fi

core_assertions
test_summary
