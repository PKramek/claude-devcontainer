#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=test.sh
source "${SCRIPT_DIR}/test.sh"

echo "=== Scenario: alpine_specific ==="
core_assertions

echo "--- Bash should be installed ---"
check_command_exists "bash"

echo "--- APK cache should be clean ---"
APK_CACHE_COUNT=$(find /var/cache/apk/ -type f 2>/dev/null | wc -l)
if [[ "${APK_CACHE_COUNT}" -eq 0 ]]; then
    pass "APK cache is clean"
else
    fail "APK cache has ${APK_CACHE_COUNT} files"
fi

test_summary
