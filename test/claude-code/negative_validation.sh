#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=test.sh
source "${SCRIPT_DIR}/test.sh"

echo "=== Scenario: negative_validation ==="
core_assertions

INSTALL_SCRIPT="/usr/local/share/devcontainer-features/claude-code/install.sh"
if [[ ! -f "${INSTALL_SCRIPT}" ]]; then
    fail "Persisted install.sh not found"
    test_summary
fi
# shellcheck source=/dev/null
source "${INSTALL_SCRIPT}"

echo "--- validate_version: bad inputs ---"
if (validate_version "bad;rm -rf /" 2>/dev/null); then
    fail "validate_version accepted shell injection"
else
    pass "validate_version rejected shell injection"
fi
if (validate_version "1.0 0" 2>/dev/null); then
    fail "validate_version accepted spaces"
else
    pass "validate_version rejected spaces"
fi
if (validate_version "" 2>/dev/null); then
    fail "validate_version accepted empty string"
else
    pass "validate_version rejected empty string"
fi
if (validate_version "v1.0.0" 2>/dev/null); then
    fail "validate_version accepted leading 'v'"
else
    pass "validate_version rejected leading 'v'"
fi

echo "--- validate_version: valid inputs ---"
if (validate_version "latest" 2>/dev/null); then
    pass "validate_version accepted 'latest'"
else
    fail "validate_version rejected 'latest'"
fi
if (validate_version "1.2.3" 2>/dev/null); then
    pass "validate_version accepted '1.2.3'"
else
    fail "validate_version rejected '1.2.3'"
fi

echo "--- validate_install_path: bad inputs ---"
if (validate_install_path "relative/path" 2>/dev/null); then
    fail "validate_install_path accepted relative path"
else
    pass "validate_install_path rejected relative path"
fi
if (validate_install_path "" 2>/dev/null); then
    fail "validate_install_path accepted empty string"
else
    pass "validate_install_path rejected empty string"
fi
if (validate_install_path '/tmp/$(whoami)' 2>/dev/null); then
    fail "validate_install_path accepted path with \$()"
else
    pass "validate_install_path rejected shell metacharacters"
fi
if (validate_install_path "/opt/my path" 2>/dev/null); then
    fail "validate_install_path accepted spaces"
else
    pass "validate_install_path rejected spaces"
fi

echo "--- validate_install_path: valid inputs ---"
if (validate_install_path "/usr/local" 2>/dev/null); then
    pass "validate_install_path accepted '/usr/local'"
else
    fail "validate_install_path rejected '/usr/local'"
fi
if (validate_install_path "/opt/claude" 2>/dev/null); then
    pass "validate_install_path accepted '/opt/claude'"
else
    fail "validate_install_path rejected '/opt/claude'"
fi
if (validate_install_path "/opt/my-app" 2>/dev/null); then
    pass "validate_install_path accepted '/opt/my-app' (hyphen)"
else
    fail "validate_install_path rejected '/opt/my-app'"
fi

echo "--- validate_node_version: bad inputs ---"
if (validate_node_version "abc" 2>/dev/null); then
    fail "validate_node_version accepted 'abc'"
else
    pass "validate_node_version rejected non-numeric"
fi
if (validate_node_version "17" 2>/dev/null); then
    fail "validate_node_version accepted '17' (below min)"
else
    pass "validate_node_version rejected below 18"
fi
if (validate_node_version "100" 2>/dev/null); then
    fail "validate_node_version accepted '100' (above max)"
else
    pass "validate_node_version rejected above 99"
fi

echo "--- validate_node_version: valid inputs ---"
if (validate_node_version "lts" 2>/dev/null); then
    pass "validate_node_version accepted 'lts'"
else
    fail "validate_node_version rejected 'lts'"
fi
if (validate_node_version "22" 2>/dev/null); then
    pass "validate_node_version accepted '22'"
else
    fail "validate_node_version rejected '22'"
fi
if (validate_node_version "18" 2>/dev/null); then
    pass "validate_node_version accepted '18' (boundary min)"
else
    fail "validate_node_version rejected '18'"
fi
if (validate_node_version "99" 2>/dev/null); then
    pass "validate_node_version accepted '99' (boundary max)"
else
    fail "validate_node_version rejected '99'"
fi

test_summary
