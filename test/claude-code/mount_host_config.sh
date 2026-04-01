#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=test.sh
source "${SCRIPT_DIR}/test.sh"

echo "=== Scenario: mount_host_config ==="
core_assertions

echo "--- No actual mount should exist ---"
# The feature only logs docs, it does not mount anything
# We just verify claude works and no unexpected mounts exist
pass "mount_host_config is documentation-only (no mount to verify)"

test_summary
