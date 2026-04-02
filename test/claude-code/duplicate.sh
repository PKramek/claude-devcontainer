#!/usr/bin/env bash
# Idempotency test: run by the devcontainer framework after installing the feature
# a second time. Verifies the feature is still fully functional after re-install.
set -Eeuo pipefail

# shellcheck source=test.sh
source "$(dirname "$0")/test.sh"

echo "=== Duplicate Install Test (idempotency) ==="
core_assertions
test_summary
