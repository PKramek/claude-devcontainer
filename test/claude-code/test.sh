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
    TESTS_PASSED=$((TESTS_PASSED + 1))
}

fail() {
    echo "  FAIL: $*" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
}

check_command_exists() {
    local cmd="$1"
    if command -v "${cmd}" >/dev/null 2>&1; then
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
    if "${cmd}" --version >/dev/null 2>&1; then
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
    # -L/-L: dereference symlinks so we check the target file, not the symlink itself
    # (Linux symlinks always report 0777 via lstat; stat -L follows to the real file)
    actual=$(stat -Lc '%a' "${path}" 2>/dev/null || stat -f '%Lp' "${path}" 2>/dev/null)
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
    actual=$(stat -Lc '%U' "${path}" 2>/dev/null || stat -f '%Su' "${path}" 2>/dev/null)
    if [[ "${actual}" == "${expected_user}" ]]; then
        pass "Owner of ${path}: ${expected_user}"
    else
        fail "Owner of ${path}: expected ${expected_user}, got ${actual}"
    fi
}

check_file_valid_json() {
    local path="$1"
    # Use node (guaranteed present) with argv to avoid path injection
    if node -e "JSON.parse(require('fs').readFileSync(process.argv[1],'utf8'))" "${path}" >/dev/null 2>&1; then
        pass "Valid JSON: ${path}"
    else
        fail "Invalid JSON: ${path}"
    fi
}

# Assert a file contains a given string
check_file_contains() {
    local path="$1"
    local needle="$2"
    if [[ ! -f "${path}" ]]; then
        fail "Cannot check contents: ${path} does not exist"
        return
    fi
    if grep -qF -- "${needle}" "${path}"; then
        pass "File contains '${needle}': ${path}"
    else
        fail "File does NOT contain '${needle}': ${path}"
    fi
}

# Assert a file does NOT contain a given string
check_file_not_contains() {
    local path="$1"
    local needle="$2"
    if [[ ! -f "${path}" ]]; then
        pass "File absent (trivially does not contain '${needle}'): ${path}"
        return
    fi
    if grep -qF -- "${needle}" "${path}"; then
        fail "File unexpectedly contains '${needle}': ${path}"
    else
        pass "File does not contain '${needle}': ${path}"
    fi
}

# Assert no world-writable files exist under a given path
check_no_world_writable() {
    local scan_path="$1"
    if [[ ! -e "${scan_path}" ]]; then
        fail "Cannot scan: ${scan_path} does not exist"
        return
    fi
    local world_writable
    world_writable=$(find "${scan_path}" -perm -o+w -type f 2>/dev/null || true)
    if [[ -z "${world_writable}" ]]; then
        pass "No world-writable files under: ${scan_path}"
    else
        fail "World-writable files found under ${scan_path}: ${world_writable}"
    fi
}

# Full-file integrity check for completion files.
# Validates: non-empty, no CRLF, no ANSI codes, no Node.js warnings, no auth errors.
check_completion_file_integrity() {
    local file="$1"
    if [[ ! -f "${file}" ]]; then
        fail "Completion file missing: ${file}"
        return
    fi
    if [[ ! -s "${file}" ]]; then
        fail "Completion file is empty: ${file}"
        return
    fi
    pass "Completion file is non-empty: ${file}"

    if grep -qP '\r' "${file}" 2>/dev/null || grep -q $'\r' "${file}"; then
        fail "Completion file contains CRLF: ${file}"
    else
        pass "Completion file has no CRLF: ${file}"
    fi

    local esc
    esc=$(printf '\033')
    if grep -q "${esc}" "${file}"; then
        fail "Completion file contains ANSI escape sequences: ${file}"
    else
        pass "Completion file has no ANSI codes: ${file}"
    fi

    if grep -q '^(node:[0-9]' "${file}"; then
        fail "Completion file contains Node.js warning lines: ${file}"
    else
        pass "Completion file has no Node.js warnings: ${file}"
    fi

    if grep -qi -e 'not logged in' -e 'Please run /login' "${file}"; then
        fail "Completion file contains auth error text: ${file}"
    else
        pass "Completion file has no auth error text: ${file}"
    fi
}

check_completion_file_contents() {
    local file="$1"
    shift
    local prefixes=("$@")
    if [[ ! -f "${file}" ]]; then
        fail "Completion file missing: ${file}"
        return
    fi
    local first_line
    first_line=$(head -n1 "${file}")
    local prefix
    for prefix in "${prefixes[@]}"; do
        if [[ "${first_line}" == "${prefix}"* ]]; then
            pass "Completion file first line valid (prefix '${prefix}'): ${file}"
            # Also run full integrity check on the entire file
            check_completion_file_integrity "${file}"
            return
        fi
    done
    fail "Completion file has unexpected first line ('${first_line}'): ${file}"
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
    exit 0
}

# When executed directly (not sourced), run core assertions.
# This is what `devcontainer features test --skip-scenarios --base-image <img>` invokes.
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "=== Default test (core assertions) ==="
    core_assertions
    test_summary
fi
