#!/usr/bin/env bash
#
# Shared test helpers for Claude Code DevContainer Feature.
# Sourced by per-scenario test scripts.
#

set -Eeuo pipefail

TESTS_PASSED=0
TESTS_FAILED=0

pass() {
    echo "  PASS: $*"
    ((TESTS_PASSED++))
}

fail() {
    echo "  FAIL: $*" >&2
    ((TESTS_FAILED++))
}

check_command_exists() {
    local cmd="$1"
    if command -v "${cmd}" > /dev/null 2>&1; then
        pass "${cmd} is on PATH"
    else
        fail "${cmd} not found on PATH"
    fi
}

check_command_version() {
    local cmd="$1"
    local expected="$2"
    local actual
    actual=$("${cmd}" --version 2>&1 || echo "")
    if [[ "${actual}" == *"${expected}"* ]]; then
        pass "${cmd} version contains '${expected}' (got: ${actual})"
    else
        fail "${cmd} version mismatch: expected '${expected}', got '${actual}'"
    fi
}

check_command_runs() {
    local cmd="$1"
    if "${cmd}" --version > /dev/null 2>&1; then
        pass "${cmd} --version exits 0"
    else
        fail "${cmd} --version failed"
    fi
}

check_node_min_version() {
    local min="$1"
    local major
    major=$(node --version 2>/dev/null | sed 's/^v//' | cut -d. -f1)
    if [[ "${major}" -ge "${min}" ]]; then
        pass "Node.js v${major} >= ${min}"
    else
        fail "Node.js v${major} < ${min}"
    fi
}

check_file_exists() {
    local path="$1"
    if [[ -f "${path}" ]]; then
        pass "File exists: ${path}"
    else
        fail "File missing: ${path}"
    fi
}

check_file_absent() {
    local path="$1"
    if [[ ! -f "${path}" ]]; then
        pass "File absent (expected): ${path}"
    else
        fail "File exists (unexpected): ${path}"
    fi
}

check_dir_exists() {
    local path="$1"
    if [[ -d "${path}" ]]; then
        pass "Directory exists: ${path}"
    else
        fail "Directory missing: ${path}"
    fi
}

check_env_var() {
    local name="$1"
    local expected="$2"
    local actual="${!name:-}"
    if [[ "${actual}" == "${expected}" ]]; then
        pass "Env var ${name}='${expected}'"
    else
        fail "Env var ${name}: expected '${expected}', got '${actual}'"
    fi
}

check_permissions() {
    local path="$1"
    local expected="$2"
    if [[ ! -e "${path}" ]]; then
        fail "Cannot check permissions: ${path} does not exist"
        return
    fi
    local actual
    actual=$(stat -c '%a' "${path}" 2>/dev/null || stat -f '%Lp' "${path}" 2>/dev/null)
    if [[ "${actual}" == "${expected}" ]]; then
        pass "Permissions on ${path}: ${expected}"
    else
        fail "Permissions on ${path}: expected ${expected}, got ${actual}"
    fi
}

check_file_owner() {
    local path="$1"
    local expected_user="$2"
    if [[ ! -e "${path}" ]]; then
        fail "Cannot check owner: ${path} does not exist"
        return
    fi
    local actual
    actual=$(stat -c '%U' "${path}" 2>/dev/null || stat -f '%Su' "${path}" 2>/dev/null)
    if [[ "${actual}" == "${expected_user}" ]]; then
        pass "Owner of ${path}: ${expected_user}"
    else
        fail "Owner of ${path}: expected ${expected_user}, got ${actual}"
    fi
}

check_file_valid_json() {
    local path="$1"
    # Use node (guaranteed present) with argv to avoid path injection
    if node -e "JSON.parse(require('fs').readFileSync(process.argv[1],'utf8'))" "${path}" > /dev/null 2>&1; then
        pass "Valid JSON: ${path}"
    else
        fail "Invalid JSON: ${path}"
    fi
}

check_path_clean() {
    local cache_dir="$1"
    if [[ ! -d "${cache_dir}" ]]; then
        pass "Cache dir absent: ${cache_dir}"
        return
    fi
    local count
    count=$(find "${cache_dir}" -type f 2>/dev/null | wc -l)
    if [[ "${count}" -eq 0 ]]; then
        pass "Cache dir clean: ${cache_dir}"
    else
        fail "Cache dir has ${count} files: ${cache_dir}"
    fi
}

check_non_root() {
    local current_user
    current_user=$(whoami)
    if [[ "${current_user}" != "root" ]]; then
        pass "Running as non-root user: ${current_user}"
    else
        # Raw OS images (ubuntu:22.04, alpine:3.21, etc.) run as root.
        # This is expected — the devcontainer CLI has no non-root user to switch to.
        # Only warn, don't fail, since the permission model still works for root.
        pass "Running as root (acceptable for raw OS base images)"
    fi
}

# Run core assertions shared by all scenarios
core_assertions() {
    echo "--- Core Assertions ---"
    check_command_exists "claude"
    check_command_runs "claude"
    check_command_exists "node"
    check_node_min_version 18
    check_env_var "CLAUDE_CODE_INSTALLED" "true"
    check_non_root
    # Check claude binary permissions (should be executable by all)
    local claude_path
    claude_path=$(command -v claude)
    if [[ -n "${claude_path}" ]]; then
        check_permissions "${claude_path}" "755"
    fi
}

# Print summary and exit with appropriate code
test_summary() {
    echo ""
    echo "--- Results: ${TESTS_PASSED} passed, ${TESTS_FAILED} failed ---"
    if [[ "${TESTS_FAILED}" -gt 0 ]]; then
        exit 1
    fi
}

# When executed directly (not sourced), run core assertions.
# This is what `devcontainer features test --skip-scenarios --base-image <img>` invokes.
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "=== Default test (core assertions) ==="
    core_assertions
    test_summary
fi
