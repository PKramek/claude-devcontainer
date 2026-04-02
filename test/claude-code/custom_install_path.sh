#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=test.sh
source "${SCRIPT_DIR}/test.sh"

echo "=== Scenario: custom_install_path ==="

echo "--- Binary at custom path ---"
check_file_exists /opt/claude/bin/claude

echo "--- PATH includes custom path ---"
if echo "${PATH}" | grep -q '/opt/claude/bin'; then
    pass "PATH contains /opt/claude/bin"
else
    fail "PATH does not contain /opt/claude/bin"
fi

echo "--- Profile.d script exists ---"
check_file_exists /etc/profile.d/claude-code.sh

core_assertions
test_summary
