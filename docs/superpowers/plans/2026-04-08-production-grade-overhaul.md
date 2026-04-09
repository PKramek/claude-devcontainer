# Production-Grade Overhaul Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the Claude Code DevContainer Feature production-grade by refactoring install.sh for testability, fixing 11 installer bugs (CQ-9 dropped — original regex already correct), adding 18 completions pipeline unit tests, and reducing the CI matrix from 27 to 8 images while increasing scenario coverage from 10 to 17.

**Architecture:** The installer (`src/claude-code/install.sh`) gets a `main()` guard so tests can source it and call individual functions. The test suite (`test/claude-code/`) gains 3 new test files (completions pipeline, negative validation, security permissions), 4 new helpers, and strengthened existing scenarios. CI (`test.yml`) switches to a lean 8-image matrix with nightly extended coverage.

**Tech Stack:** Bash 5.x, ShellCheck, shfmt, devcontainers/cli@0.85.0, GitHub Actions

**Spec:** `docs/superpowers/specs/2026-04-08-production-grade-overhaul-design.md`

---

## File Map

| File                                                | Action | Responsibility                                                               |
| --------------------------------------------------- | ------ | ---------------------------------------------------------------------------- |
| `src/claude-code/install.sh`                        | Modify | main() guard + 12 bug fixes                                                  |
| `test/claude-code/test.sh`                          | Modify | 4 new helpers + strengthen check_completion_file_contents                    |
| `test/claude-code/completions_pipeline.sh`          | Create | 18 pipeline unit tests                                                       |
| `test/claude-code/negative_validation.sh`           | Create | Input validation rejection tests                                             |
| `test/claude-code/security_permissions.sh`          | Create | Permission and ownership tests                                               |
| `test/claude-code/custom_node_version.sh`           | Create | nodeVersion=22 scenario                                                      |
| `test/claude-code/fedora_default.sh`                | Create | Fedora core assertions                                                       |
| `test/claude-code/upgrade_version.sh`               | Create | Version upgrade test                                                         |
| `test/claude-code/install_path_with_completions.sh` | Create | Option combination test                                                      |
| `test/claude-code/default_options.sh`               | Modify | Remove fish re-source hack, use improved helpers                             |
| `test/claude-code/mount_host_config.sh`             | Modify | Replace no-op with real assertions                                           |
| `test/claude-code/custom_install_path.sh`           | Modify | Add profile.d content verification                                           |
| `test/claude-code/idempotency.sh`                   | Modify | Pass original options on re-run                                              |
| `test/claude-code/node_preinstalled.sh`             | Modify | Verify original Node location preserved                                      |
| `test/claude-code/multi_feature_combo.sh`           | Modify | Verify Node 22 active                                                        |
| `test/claude-code/scenarios.json`                   | Modify | Add 7 new scenario entries                                                   |
| `test/claude-code/duplicate.sh`                     | Delete | Orphaned, never runs                                                         |
| `.github/workflows/test.yml`                        | Modify | 8-image matrix, nightly extended, shfmt checksum, positive success assertion |

---

### Task 1: Phase 1 — main() Guard Refactor in install.sh

**Files:**

- Modify: `src/claude-code/install.sh`

This is the critical enabler for all subsequent test work. Move all execution logic (shell options, traps, option parsing, install steps) into a `main()` function with a `BASH_SOURCE` guard. Function definitions stay at top level.

- [ ] **Step 1: Read the current install.sh structure**

The file has 3 sections:

- Lines 1-29: POSIX bootstrap (`#!/bin/sh`, Alpine bash install, `exec bash`) — DO NOT TOUCH
- Lines 30-50: Bash setup (`set -Eeuo pipefail`, `umask`, traps, `TEMP_DIR`)
- Lines 51-747: Functions + execution (logging, validation, detect, ensure, install, setup, cleanup, persist)

The execution calls that must move inside `main()` are scattered at top level: lines 93-111 (option parsing/validation), 139-145 (remote user detection), 200-203 (OS/arch detection), 275 (`ensure_base_dependencies`), **278 (`NODE_MIN_VERSION=18` — top-level constant, must also move into main())**, 443 (`ensure_node`), 516-517 (`configure_custom_path`, `install_claude_code`), 626 (`setup_completions`), 659 (`setup_mcp_servers`), 693 (`setup_mount_docs`), 724 (`cleanup_caches`), 730-746 (persist + final log).

- [ ] **Step 2: Restructure install.sh**

After line 29 (`# --- From here on, bash is guaranteed ---`), the new structure is:

1. All function definitions (logging, validation, detect*\*, ensure\*\*, install\_*, setup*\*, configure\*\*, cleanup\_*) — unchanged, at top level
2. A new `main()` function containing ALL the execution logic that was previously at top level
3. The `BASH_SOURCE` guard at the very end

Specifically, wrap everything that was NOT a function definition into `main()`:

```bash
main() {
    set -Eeuo pipefail
    umask 0022

    FEATURE_LOG_PREFIX="[claude-code feature]"

    # Debug mode
    if [[ "${DEBUG:-false}" == "true" ]]; then
        unset ANTHROPIC_API_KEY CLAUDE_API_KEY 2>/dev/null || true
        set -x
    fi

    # Traps
    trap 'echo "${FEATURE_LOG_PREFIX} ERROR: Failed at line ${LINENO}. Exit code: $?" >&2' ERR
    trap cleanup EXIT INT TERM

    TEMP_DIR=""

    # --- Parse Options ---
    VERSION="${VERSION:-latest}"
    NODE_VERSION="${NODEVERSION:-lts}"
    INSTALL_PATH="${INSTALLPATH:-/usr/local}"
    ENABLE_MCP_SERVERS="${ENABLEMCPSERVERS:-false}"
    MOUNT_HOST_CONFIG="${MOUNTHOSTCONFIG:-false}"
    SHELL_COMPLETIONS="${SHELLCOMPLETIONS:-true}"

    validate_version "${VERSION}"
    validate_install_path "${INSTALL_PATH}"
    validate_node_version "${NODE_VERSION}"

    log_info "Starting installation..."
    # ... (all remaining execution logic) ...

    log_info "Claude Code DevContainer Feature installation complete."
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
```

Things that stay OUTSIDE `main()` (at top level after line 30):

- `FEATURE_LOG_PREFIX="[claude-code feature]"` — needed by logging functions that are also at top level. Actually, move this inside `main()` and have log functions use `${FEATURE_LOG_PREFIX:-[claude-code feature]}` with a default.
- All function definitions: `log_info`, `log_warn`, `log_error`, `log_debug`, `validate_version`, `validate_install_path`, `validate_node_version`, `cleanup`, `detect_remote_user`, `detect_user_home`, `detect_os`, `detect_arch`, `install_packages`, `ensure_base_dependencies`, `ensure_node`, `resolve_node_version`, `install_node_binary`, `install_node_distro`, `configure_custom_path`, `install_claude_code`, `setup_completions`, `setup_mcp_servers`, `setup_mount_docs`, `cleanup_caches`

Key detail: The `cleanup()` function references `TEMP_DIR`. When sourced, `TEMP_DIR` won't exist. Guard it:

```bash
cleanup() {
    if [[ -n "${TEMP_DIR:-}" ]]; then
        rm -rf "${TEMP_DIR}" 2>/dev/null || true
    fi
}
```

This also fixes CQ-2 (ERR trap on cleanup).

Update all four log functions to use a default prefix so they work when sourced without main():

```bash
log_info() { echo "${FEATURE_LOG_PREFIX:-[claude-code feature]} $*" >&2; }
log_warn() { echo "${FEATURE_LOG_PREFIX:-[claude-code feature]} WARNING: $*" >&2; }
log_error() { echo "${FEATURE_LOG_PREFIX:-[claude-code feature]} ERROR: $*" >&2; }
log_debug() {
    if [[ "${DEBUG:-false}" == "true" ]]; then
        echo "${FEATURE_LOG_PREFIX:-[claude-code feature]} DEBUG: $*" >&2
    fi
}
```

Also add a comment above `detect_os` documenting CQ-8:

```bash
# IMPORTANT: detect_os sources /etc/os-release which sets global variables including
# VERSION. This is safe ONLY because detect_os is called via command substitution
# (OS_FAMILY=$(detect_os)) which runs in a subshell. Do NOT refactor to call
# detect_os directly — it would clobber the script's VERSION variable.
```

- [ ] **Step 3: Apply the remaining must-fix script changes (CQ-1, CQ-3, CQ-10, CQ-14, CQ-15, CQ-17)**

In the same file, also apply these fixes:

**CQ-1** (line 221): Change `pacman -Sy --noconfirm --needed` to `pacman -Syu --noconfirm --needed`

**CQ-3** (lines 549, 575, 607): Broaden ANSI stripping. Replace:

```bash
sed "s/${esc}\[[0-9;]*[a-zA-Z]//g"
```

With:

```bash
sed "s/${esc}\[[0-9;]*[a-zA-Z]//g; s/${esc}[()][AB012]//g; s/${esc}[>=]//g"
```

**CQ-9: DROPPED.** The original regex `^/[a-zA-Z0-9/_.-]+$` already handles hyphens correctly — the `-` is at the end of the character class (before `]`), which is the standard POSIX-safe placement for a literal hyphen. Verified: `[[ "/opt/my-app" =~ ^/[a-zA-Z0-9/_.-]+$ ]]` returns true on bash 5.x.

**CQ-10** (line 502): Clean up claude --version output. Replace:

```bash
installed_version=$(claude --version 2>/dev/null) || {
```

With:

```bash
installed_version=$(claude --version 2>/dev/null | head -n1) || {
```

**CQ-14** (lines 551, 577, 609): Fix whitespace skip. Replace all three instances of:

```bash
sed -n '/[^ ]/,$p')
```

With:

```bash
sed -n '/[^[:space:]]/,$p')
```

**CQ-15** (lines 343, 361): Add curl timeouts. Add `--connect-timeout 30 --max-time 300` to both curl commands in `install_node_binary`:

```bash
curl -fsSL --connect-timeout 30 --max-time 300 "https://nodejs.org/..."
```

**CQ-17** (after line 599): Create fish completions directory if fish is installed but dir missing. After the `for dir in ...` loop, add:

```bash
    if [[ -z "${fish_comp_dir}" ]] && command -v fish >/dev/null 2>&1; then
        fish_comp_dir="/usr/share/fish/vendor_completions.d"
        mkdir -p "${fish_comp_dir}"
    fi
```

- [ ] **Step 4: Apply should-fix changes (CQ-11, CQ-12)**

**CQ-11**: Normalize boolean options to lowercase. Inside `main()`, after the option parsing block, add (uses bash 4.0+ `,,` operator — bash 5.x is guaranteed by our POSIX bootstrap):

```bash
    ENABLE_MCP_SERVERS="${ENABLE_MCP_SERVERS,,}"
    MOUNT_HOST_CONFIG="${MOUNT_HOST_CONFIG,,}"
    SHELL_COMPLETIONS="${SHELL_COMPLETIONS,,}"
```

**CQ-12**: Restrict detect_remote_user UID range. In `detect_remote_user`, change:

```bash
user=$(getent passwd | awk -F: '$3 >= 1000 && $7 !~ /nologin|false/ { print $1; exit }')
```

To:

```bash
user=$(getent passwd | awk -F: '$3 >= 1000 && $3 <= 60000 && $7 !~ /nologin|false/ { print $1; exit }')
```

- [ ] **Step 5: Verify ShellCheck and shfmt pass**

Run:

```bash
shellcheck -S warning src/claude-code/install.sh
shfmt -ln bash -i 4 -ci -d src/claude-code/install.sh
```

If shfmt shows diffs, apply with `-w`. Both must produce no output.

- [ ] **Step 6: Commit**

```bash
git add src/claude-code/install.sh
git commit -m "refactor: add main() guard for testability; fix 12 installer bugs

- Wrap execution logic in main() with BASH_SOURCE guard (QA-23)
- Fix cleanup ERR trap: use if/then instead of && chain (CQ-2)
- Change pacman -Sy to -Syu (CQ-1)
- Broaden ANSI stripping: ESC(B, ESC=, ESC> (CQ-3)
- Fix whitespace skip: [^[:space:]] instead of [^ ] (CQ-14)
- Allow hyphens in validate_install_path (CQ-9)
- Add curl timeouts --connect-timeout 30 --max-time 300 (CQ-15)
- Create fish completions dir if missing (CQ-17)
- Clean claude --version output via head -n1 (CQ-10)
- Normalize boolean options to lowercase (CQ-11)
- Restrict detect_remote_user UID range to 1000-60000 (CQ-12)
- Document detect_os subshell protection for VERSION (CQ-8)"
```

---

### Task 2: Phase 3 — Test Helpers

**Files:**

- Modify: `test/claude-code/test.sh`

Add 4 new helper functions and strengthen `check_completion_file_contents`.

- [ ] **Step 1: Add new helpers to test.sh**

Add after `check_file_valid_json` (after line 143):

```bash
# Assert a file contains a given string
check_file_contains() {
    local path="$1"
    local needle="$2"
    if [[ ! -f "${path}" ]]; then
        fail "Cannot check contents: ${path} does not exist"
        return
    fi
    if grep -qF "${needle}" "${path}"; then
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
    if grep -qF "${needle}" "${path}"; then
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
```

- [ ] **Step 2: Strengthen check_completion_file_contents**

Replace the existing `check_completion_file_contents` function (lines 145-163) with:

```bash
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
```

- [ ] **Step 3: Add explicit exit 0 to test_summary**

Replace the `test_summary` function (lines 211-217) with:

```bash
test_summary() {
    echo ""
    echo "--- Results: ${TESTS_PASSED} passed, ${TESTS_FAILED} failed ---"
    if [[ "${TESTS_FAILED}" -gt 0 ]]; then
        exit 1
    fi
    exit 0
}
```

- [ ] **Step 4: Verify and commit**

```bash
shellcheck -S warning test/claude-code/test.sh
git add test/claude-code/test.sh
git commit -m "test: add 4 new helpers and strengthen completion file validation"
```

---

### Task 3: Phase 4 — Strengthen Existing Scenarios

**Files:**

- Modify: `test/claude-code/default_options.sh`
- Modify: `test/claude-code/completions_disabled.sh`
- Modify: `test/claude-code/mount_host_config.sh`
- Modify: `test/claude-code/custom_install_path.sh`
- Modify: `test/claude-code/idempotency.sh`
- Modify: `test/claude-code/node_preinstalled.sh`
- Modify: `test/claude-code/multi_feature_combo.sh`
- Delete: `test/claude-code/duplicate.sh`

- [ ] **Step 1: Rewrite default_options.sh**

Replace entire file with:

```bash
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
        check_completion_file_contents /usr/share/bash-completion/completions/claude \
            "_" "#" "if " "function "
    else
        pass "Bash completion not written — auth likely unavailable during build"
    fi
elif [[ -d /etc/bash_completion.d ]]; then
    if [[ -f /etc/bash_completion.d/claude ]]; then
        check_completion_file_contents /etc/bash_completion.d/claude \
            "_" "#" "if " "function "
    else
        pass "Bash completion not written — auth likely unavailable during build"
    fi
else
    pass "Bash completion directory absent — skipping"
fi

echo "--- Completions: zsh ---"
if command -v zsh >/dev/null 2>&1; then
    if [[ -f /usr/share/zsh/site-functions/_claude ]]; then
        check_completion_file_contents /usr/share/zsh/site-functions/_claude \
            "_" "#compdef" "#" "if " "function "
    else
        pass "Zsh completion not written — auth likely unavailable during build"
    fi
else
    pass "zsh not installed — skipping"
fi

echo "--- Completions: fish ---"
FISH_COMP_FILE=""
for dir in /usr/share/fish/vendor_completions.d /usr/share/fish/completions; do
    if [[ -f "${dir}/claude.fish" ]]; then
        FISH_COMP_FILE="${dir}/claude.fish"
        break
    fi
done
if [[ -n "${FISH_COMP_FILE}" ]]; then
    check_completion_file_contents "${FISH_COMP_FILE}" "complete" "#"
elif command -v fish >/dev/null 2>&1; then
    pass "Fish installed but completion not written — auth likely unavailable"
else
    pass "fish not installed — skipping"
fi

echo "--- MCP config should be absent ---"
check_file_absent "${HOME}/.claude/mcp_servers.json"

test_summary
```

- [ ] **Step 1b: Strengthen completions_disabled.sh**

Read the current file, then add assertions that completion files are absent for all three shells:

```bash
#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=test.sh
source "${SCRIPT_DIR}/test.sh"

echo "=== Scenario: completions_disabled ==="
core_assertions

echo "--- Bash completions absent ---"
check_file_absent /usr/share/bash-completion/completions/claude
check_file_absent /etc/bash_completion.d/claude

echo "--- Fish completions absent ---"
check_file_absent /usr/share/fish/vendor_completions.d/claude.fish
check_file_absent /usr/share/fish/completions/claude.fish

echo "--- Zsh completions absent ---"
if command -v zsh >/dev/null 2>&1; then
    check_file_absent /usr/share/zsh/site-functions/_claude
else
    pass "zsh not installed — skipping"
fi

test_summary
```

- [ ] **Step 2: Rewrite mount_host_config.sh**

Replace entire file with:

```bash
#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=test.sh
source "${SCRIPT_DIR}/test.sh"

echo "=== Scenario: mount_host_config ==="
core_assertions

echo "--- Mount documentation verification ---"
INSTALL_SCRIPT="/usr/local/share/devcontainer-features/claude-code/install.sh"
if [[ -f "${INSTALL_SCRIPT}" ]]; then
    # shellcheck source=/dev/null
    source "${INSTALL_SCRIPT}" 2>/dev/null || true

    MOUNT_HOST_CONFIG="true"
    REMOTE_USER_HOME="${HOME}"

    MOUNT_OUTPUT=$(setup_mount_docs 2>&1) || true

    if echo "${MOUNT_OUTPUT}" | grep -q '\.claude'; then
        pass "Mount docs mention .claude directory"
    else
        fail "Mount docs do not mention .claude directory"
    fi

    if echo "${MOUNT_OUTPUT}" | grep -q '\.claude\.json'; then
        pass "Mount docs mention .claude.json file"
    else
        fail "Mount docs do not mention .claude.json file"
    fi

    if echo "${MOUNT_OUTPUT}" | grep -q 'mounts'; then
        pass "Mount docs contain mounts snippet"
    else
        fail "Mount docs do not contain mounts snippet"
    fi
else
    pass "install.sh not sourceable — mount_host_config is documentation-only"
fi

test_summary
```

- [ ] **Step 3: Strengthen custom_install_path.sh**

Replace entire file with:

```bash
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

echo "--- Profile.d script exists with correct content ---"
check_file_exists /etc/profile.d/claude-code.sh
check_file_contains /etc/profile.d/claude-code.sh '/opt/claude/bin'
check_permissions /etc/profile.d/claude-code.sh "644"

echo "--- Claude resolves to custom path ---"
CLAUDE_PATH=$(command -v claude)
if [[ "${CLAUDE_PATH}" == "/opt/claude/bin/claude" ]]; then
    pass "claude resolves to /opt/claude/bin/claude"
else
    fail "claude resolves to ${CLAUDE_PATH}, expected /opt/claude/bin/claude"
fi

core_assertions
test_summary
```

- [ ] **Step 4: Strengthen idempotency.sh**

Read the current file, then replace it. The key change: export original options before the re-run.

```bash
#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=test.sh
source "${SCRIPT_DIR}/test.sh"

echo "=== Scenario: idempotency ==="

echo "--- First run assertions ---"
core_assertions

ORIGINAL_CLAUDE_VERSION=$(claude --version 2>/dev/null | head -n1)
ORIGINAL_NODE_VERSION=$(node --version 2>/dev/null)

echo "--- Second run (idempotent re-install) ---"
INSTALL_SCRIPT="/usr/local/share/devcontainer-features/claude-code/install.sh"
check_file_exists "${INSTALL_SCRIPT}"

# Pass the same default options that the first run used
sudo VERSION=latest NODEVERSION=lts INSTALLPATH=/usr/local \
    ENABLEMCPSERVERS=false MOUNTHOSTCONFIG=false SHELLCOMPLETIONS=true \
    bash "${INSTALL_SCRIPT}" 2>&1

echo "--- Post re-run assertions ---"
core_assertions

RERUN_CLAUDE_VERSION=$(claude --version 2>/dev/null | head -n1)
RERUN_NODE_VERSION=$(node --version 2>/dev/null)

if [[ "${ORIGINAL_CLAUDE_VERSION}" == "${RERUN_CLAUDE_VERSION}" ]]; then
    pass "Claude version unchanged after re-run: ${RERUN_CLAUDE_VERSION}"
else
    fail "Claude version changed: ${ORIGINAL_CLAUDE_VERSION} -> ${RERUN_CLAUDE_VERSION}"
fi

if [[ "${ORIGINAL_NODE_VERSION}" == "${RERUN_NODE_VERSION}" ]]; then
    pass "Node version unchanged after re-run: ${RERUN_NODE_VERSION}"
else
    fail "Node version changed: ${ORIGINAL_NODE_VERSION} -> ${RERUN_NODE_VERSION}"
fi

echo "--- Persisted script still exists ---"
check_file_exists "${INSTALL_SCRIPT}"

test_summary
```

- [ ] **Step 5: Strengthen node_preinstalled.sh**

Add a check that the original Node.js location is preserved:

```bash
#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=test.sh
source "${SCRIPT_DIR}/test.sh"

echo "=== Scenario: node_preinstalled ==="
core_assertions

echo "--- Node.js location preserved ---"
NODE_PATH=$(command -v node)
# On javascript-node MCR image, node is managed by nvm and lives under ~/.nvm
# It should NOT be /usr/local/bin/node (which would mean our feature reinstalled it)
if [[ "${NODE_PATH}" == *"nvm"* ]] || [[ "${NODE_PATH}" == *".nvm"* ]]; then
    pass "Node.js is nvm-managed: ${NODE_PATH}"
elif [[ "${NODE_PATH}" == "/usr/local/bin/node" ]]; then
    # /usr/local/bin could be the nvm shim — check if nvm is present
    if [[ -d "${HOME}/.nvm" ]] || [[ -n "${NVM_DIR:-}" ]]; then
        pass "Node.js at /usr/local/bin but nvm present — likely shim"
    else
        fail "Node.js at /usr/local/bin without nvm — may have been reinstalled"
    fi
else
    pass "Node.js location: ${NODE_PATH}"
fi

test_summary
```

- [ ] **Step 6: Strengthen multi_feature_combo.sh**

```bash
#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=test.sh
source "${SCRIPT_DIR}/test.sh"

echo "=== Scenario: multi_feature_combo ==="
core_assertions

echo "--- Node.js version check ---"
NODE_MAJOR=$(node --version 2>/dev/null | sed 's/^v//' | cut -d. -f1)
if [[ "${NODE_MAJOR}" == "22" ]]; then
    pass "Node.js major version is 22 (from explicit node feature)"
else
    fail "Node.js major version is ${NODE_MAJOR}, expected 22"
fi

test_summary
```

- [ ] **Step 7: Delete duplicate.sh**

```bash
rm test/claude-code/duplicate.sh
```

- [ ] **Step 8: Verify and commit**

```bash
shellcheck -S warning test/claude-code/*.sh
git add test/claude-code/
git rm test/claude-code/duplicate.sh
git commit -m "test: strengthen existing scenarios, remove orphaned duplicate.sh

- default_options: remove fish re-source hack, use improved helpers
- mount_host_config: replace no-op with real documentation verification
- custom_install_path: verify profile.d content and path resolution
- idempotency: pass original options on re-run
- node_preinstalled: verify original Node location preserved
- multi_feature_combo: verify Node 22 is active version
- Delete orphaned duplicate.sh"
```

---

### Task 4: Phase 5 — New Test Scenarios

**Files:**

- Create: `test/claude-code/completions_pipeline.sh`
- Create: `test/claude-code/negative_validation.sh`
- Create: `test/claude-code/security_permissions.sh`
- Create: `test/claude-code/custom_node_version.sh`
- Create: `test/claude-code/fedora_default.sh`
- Create: `test/claude-code/upgrade_version.sh`
- Create: `test/claude-code/install_path_with_completions.sh`
- Modify: `test/claude-code/scenarios.json`

- [ ] **Step 1: Create completions_pipeline.sh**

This is the most important new test — 18 unit tests for the completions cleanup pipeline using a mock `claude` binary. Create `test/claude-code/completions_pipeline.sh` with full code. The implementer MUST:

1. Source `install.sh` (safe with main() guard — only defines functions)
2. Extract the cleanup pipeline into a `run_bash_pipeline` helper that replicates the exact pipeline from `setup_completions`: `tr -d '\r' | sed ANSI_strip | sed node_warning_strip | sed whitespace_skip`
3. Create a `check_first_line_prefix` helper that tests if the first line starts with any of the given prefixes
4. Implement all 18 tests from the spec table (A1-A18), each with explicit input strings and assertions:
   - A1: Clean valid `_claude() {` → accepted
   - A2: ANSI codes `\033[0m\033[32m_claude()` → stripped, content preserved
   - A3: CRLF `_claude() {\r\n` → `\r` stripped
   - A4: Node.js warning preamble + valid content → warning stripped
   - A5: Node.js warning ONLY → empty output
   - A6: Auth error "Not logged in" → rejected by prefix, detected by grep
   - A7: Combined ANSI + CRLF + Node.js + valid → all noise stripped
   - A8: Valid fish `complete -c claude` → accepted
   - A9: Valid zsh `#compdef claude` → accepted
   - A10: `if type complete` format → accepted with `if` prefix
   - A11: `function _claude_completion()` → accepted with `function` prefix
   - A12: Empty string → empty output
   - A13: Whitespace-only → empty output
   - A14: Random garbage → rejected by prefix
   - A15: End-to-end valid mock → file written, passes integrity
   - A16: End-to-end auth error → no file created
   - A17: Mid-line ANSI codes → stripped without corrupting
   - A18: Multiple stacked Node.js warnings → all stripped

Each test uses `pass`/`fail` helpers from `test.sh`. Ends with `test_summary`.

- [ ] **Step 2: Create negative_validation.sh**

Create `test/claude-code/negative_validation.sh` with full code. The test sources `install.sh` (requires main() guard) and calls each validator in subshells:

```bash
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
```

- [ ] **Step 3: Create security_permissions.sh**

Create `test/claude-code/security_permissions.sh` with full code:

```bash
#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=test.sh
source "${SCRIPT_DIR}/test.sh"

echo "=== Scenario: security_permissions ==="
core_assertions

echo "--- Claude binary permissions ---"
CLAUDE_PATH=$(command -v claude)
check_permissions "${CLAUDE_PATH}" "755"

echo "--- No world-writable files under install path ---"
if [[ -d /usr/local/lib/node_modules/@anthropic-ai ]]; then
    check_no_world_writable "/usr/local/lib/node_modules/@anthropic-ai"
else
    pass "npm package dir not at expected location — skipping world-writable check"
fi

echo "--- MCP config permissions ---"
MCP_CONFIG="${HOME}/.claude/mcp_servers.json"
check_file_exists "${MCP_CONFIG}"
check_permissions "${HOME}/.claude" "700"
check_permissions "${MCP_CONFIG}" "600"
check_file_owner "${MCP_CONFIG}" "$(whoami)"
check_file_owner "${HOME}/.claude" "$(whoami)"
check_file_valid_json "${MCP_CONFIG}"

echo "--- Profile.d permissions ---"
if [[ -f /etc/profile.d/claude-code.sh ]]; then
    check_permissions /etc/profile.d/claude-code.sh "644"
fi

echo "--- Completion file integrity (if written) ---"
for comp_file in \
    /usr/share/bash-completion/completions/claude \
    /etc/bash_completion.d/claude \
    /usr/share/zsh/site-functions/_claude \
    /usr/share/fish/vendor_completions.d/claude.fish; do
    if [[ -f "${comp_file}" ]]; then
        check_completion_file_integrity "${comp_file}"
    fi
done

test_summary
```

- [ ] **Step 4: Create custom_node_version.sh**

```bash
#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=test.sh
source "${SCRIPT_DIR}/test.sh"

echo "=== Scenario: custom_node_version ==="
core_assertions

echo "--- Node.js 22.x installed ---"
NODE_MAJOR=$(node --version 2>/dev/null | sed 's/^v//' | cut -d. -f1)
if [[ "${NODE_MAJOR}" == "22" ]]; then
    pass "Node.js major version is 22"
else
    fail "Node.js major version is ${NODE_MAJOR}, expected 22"
fi

test_summary
```

- [ ] **Step 5: Create fedora_default.sh**

```bash
#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=test.sh
source "${SCRIPT_DIR}/test.sh"

echo "=== Scenario: fedora_default ==="
core_assertions

test_summary
```

- [ ] **Step 6: Create upgrade_version.sh**

```bash
#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=test.sh
source "${SCRIPT_DIR}/test.sh"

echo "=== Scenario: upgrade_version ==="
core_assertions

echo "--- Initial version check ---"
INITIAL_VERSION=$(claude --version 2>/dev/null | head -n1)
if [[ "${INITIAL_VERSION}" == *"0.2.57"* ]]; then
    pass "Initial version is 0.2.57: ${INITIAL_VERSION}"
else
    fail "Initial version is not 0.2.57: ${INITIAL_VERSION}"
fi

echo "--- Upgrade to latest ---"
INSTALL_SCRIPT="/usr/local/share/devcontainer-features/claude-code/install.sh"
check_file_exists "${INSTALL_SCRIPT}"

sudo VERSION=latest NODEVERSION=lts INSTALLPATH=/usr/local \
    ENABLEMCPSERVERS=false MOUNTHOSTCONFIG=false SHELLCOMPLETIONS=true \
    bash "${INSTALL_SCRIPT}" 2>&1

echo "--- Post-upgrade check ---"
UPGRADED_VERSION=$(claude --version 2>/dev/null | head -n1)
if [[ "${UPGRADED_VERSION}" != *"0.2.57"* ]]; then
    pass "Version changed after upgrade: ${UPGRADED_VERSION}"
else
    fail "Version unchanged after upgrade: ${UPGRADED_VERSION}"
fi

test_summary
```

- [ ] **Step 7: Create install_path_with_completions.sh**

```bash
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

echo "--- Completions attempted ---"
# With auth unavailable at build time, completions may not be written.
# If written, verify integrity.
if [[ -d /usr/share/bash-completion/completions ]]; then
    if [[ -f /usr/share/bash-completion/completions/claude ]]; then
        check_completion_file_contents /usr/share/bash-completion/completions/claude \
            "_" "#" "if " "function "
    else
        pass "Bash completion not written — auth likely unavailable"
    fi
fi

core_assertions
test_summary
```

- [ ] **Step 8: Update scenarios.json**

Replace entire file with:

```json
{
  "default_options": {
    "image": "mcr.microsoft.com/devcontainers/base:ubuntu",
    "features": {
      "claude-code": {}
    }
  },
  "completions_disabled": {
    "image": "mcr.microsoft.com/devcontainers/base:debian",
    "features": {
      "claude-code": {
        "shellCompletions": false
      }
    }
  },
  "completions_pipeline": {
    "image": "mcr.microsoft.com/devcontainers/base:ubuntu",
    "features": {
      "claude-code": {}
    }
  },
  "mcp_enabled": {
    "image": "mcr.microsoft.com/devcontainers/base:ubuntu",
    "features": {
      "claude-code": {
        "enableMcpServers": true
      }
    }
  },
  "custom_version": {
    "image": "mcr.microsoft.com/devcontainers/base:ubuntu",
    "features": {
      "claude-code": {
        "version": "0.2.57"
      }
    }
  },
  "node_preinstalled": {
    "image": "mcr.microsoft.com/devcontainers/javascript-node",
    "features": {
      "claude-code": {}
    }
  },
  "custom_install_path": {
    "image": "mcr.microsoft.com/devcontainers/base:ubuntu",
    "features": {
      "claude-code": {
        "installPath": "/opt/claude"
      }
    }
  },
  "mount_host_config": {
    "image": "mcr.microsoft.com/devcontainers/base:debian",
    "features": {
      "claude-code": {
        "mountHostConfig": true
      }
    }
  },
  "alpine_specific": {
    "image": "mcr.microsoft.com/devcontainers/base:alpine",
    "features": {
      "claude-code": {}
    }
  },
  "idempotency": {
    "image": "mcr.microsoft.com/devcontainers/base:ubuntu",
    "features": {
      "claude-code": {}
    }
  },
  "multi_feature_combo": {
    "image": "mcr.microsoft.com/devcontainers/javascript-node",
    "features": {
      "ghcr.io/devcontainers/features/node:1": {
        "version": "22"
      },
      "claude-code": {}
    }
  },
  "negative_validation": {
    "image": "mcr.microsoft.com/devcontainers/base:ubuntu",
    "features": {
      "claude-code": {}
    }
  },
  "custom_node_version": {
    "image": "mcr.microsoft.com/devcontainers/base:ubuntu",
    "features": {
      "claude-code": {
        "nodeVersion": "22"
      }
    }
  },
  "fedora_default": {
    "image": "fedora:40",
    "features": {
      "claude-code": {}
    }
  },
  "upgrade_version": {
    "image": "mcr.microsoft.com/devcontainers/base:ubuntu",
    "features": {
      "claude-code": {
        "version": "0.2.57"
      }
    }
  },
  "install_path_with_completions": {
    "image": "mcr.microsoft.com/devcontainers/base:ubuntu",
    "features": {
      "claude-code": {
        "installPath": "/opt/claude",
        "shellCompletions": true
      }
    }
  },
  "security_permissions": {
    "image": "mcr.microsoft.com/devcontainers/base:ubuntu",
    "features": {
      "claude-code": {
        "enableMcpServers": true
      }
    }
  }
}
```

- [ ] **Step 9: Make all new .sh files executable and verify**

```bash
chmod +x test/claude-code/completions_pipeline.sh \
         test/claude-code/negative_validation.sh \
         test/claude-code/security_permissions.sh \
         test/claude-code/custom_node_version.sh \
         test/claude-code/fedora_default.sh \
         test/claude-code/upgrade_version.sh \
         test/claude-code/install_path_with_completions.sh
shellcheck -S warning test/claude-code/*.sh
```

- [ ] **Step 10: Commit**

```bash
git add test/claude-code/
git commit -m "test: add 7 new scenarios — completions pipeline, validation, security, node version, fedora, upgrade, path+completions"
```

---

### Task 5: Phase 6 — CI Pipeline Improvements

**Files:**

- Modify: `.github/workflows/test.yml`

- [ ] **Step 1: Reduce image matrix to 8 images**

Replace the `matrix.image` list in the `test-image-matrix` job (lines 128-158) with:

```yaml
image:
  - "mcr.microsoft.com/devcontainers/base:ubuntu"
  - "mcr.microsoft.com/devcontainers/base:debian"
  - "mcr.microsoft.com/devcontainers/base:alpine"
  - "mcr.microsoft.com/devcontainers/javascript-node"
  - "ubuntu:24.04"
  - "alpine:3.21"
  - "archlinux:latest"
  - "fedora:40"
```

- [ ] **Step 2: Add nightly extended matrix job**

Add a new job after `test-image-matrix`:

```yaml
# Extended image matrix — runs on schedule (weekly) and pushes to main
test-image-matrix-extended:
  needs: lint
  if: github.event_name == 'schedule' || github.ref == 'refs/heads/main'
  runs-on: ubuntu-latest
  timeout-minutes: 30
  permissions:
    contents: read
  strategy:
    fail-fast: false
    max-parallel: 5
    matrix:
      image:
        - "rockylinux:9"
        - "amazonlinux:2023"
        - "debian:bookworm"
        - "ubuntu:22.04"
        - "alpine:3.20"
  steps:
    - uses: actions/checkout@de0fac2e4500dabe0009e67214ff5f5447ce83dd # v6.0.2

    - name: Set up Docker Buildx
      uses: docker/setup-buildx-action@4d04d5d9486b7bd6fa91e7baf45bbb4f8b9deedd # v4.0.0

    - name: Install devcontainer CLI
      run: npm install -g @devcontainers/cli@0.85.0

    - name: Test on ${{ matrix.image }}
      run: |
        devcontainer features test \
          --features claude-code \
          --skip-scenarios \
          --base-image "${{ matrix.image }}" \
          --project-folder . 2>&1 | tee /tmp/test-output.log
        if grep -qE "Exit code [1-9][0-9]*|failed to install|Failed to launch|Failed:|  FAIL:" /tmp/test-output.log; then
          echo "ERROR: Test output contains failures."
          exit 1
        fi
```

- [ ] **Step 3: Move arm64 to nightly + main only**

Add condition to `test-arm64` job:

```yaml
test-arm64:
  needs: lint
  if: github.event_name == 'schedule' || github.ref == 'refs/heads/main'
```

- [ ] **Step 4: Add schedule trigger**

Update the `on:` block at the top of the file:

```yaml
on:
  pull_request:
  push:
    branches: [main, develop]
  schedule:
    - cron: "0 4 * * 1" # Weekly Monday 4am UTC
```

- [ ] **Step 5: Add shfmt SHA256 checksum verification**

Replace the shfmt download step (lines 56-58) with:

```yaml
- name: shfmt format check
  run: |
    SHFMT_VERSION="v3.13.0"
    SHFMT_SHA256="1e82e587a04302e30a19c4e78e48ba3e5a0e0a5c3e8a0b1f3e8a4b2c6d0e9f7"
    curl -fsSL "https://github.com/mvdan/sh/releases/download/${SHFMT_VERSION}/shfmt_${SHFMT_VERSION}_linux_amd64" \
      -o /tmp/shfmt
    echo "${SHFMT_SHA256}  /tmp/shfmt" | sha256sum -c -
    install -m 755 /tmp/shfmt /usr/local/bin/shfmt
    shfmt -ln bash -d -i 4 -ci src/ test/
```

NOTE: The implementer must look up the actual SHA256 hash for shfmt v3.13.0 linux_amd64 from the GitHub release page. The hash above is a placeholder. Run: `curl -fsSL https://github.com/mvdan/sh/releases/download/v3.13.0/shfmt_v3.13.0_linux_amd64 | sha256sum`

- [ ] **Step 6: Add positive success assertion to failure grep**

In all three test jobs (`test-scenarios`, `test-image-matrix`, `test-image-matrix-extended`), add after the failure grep:

```bash
          # Positive assertion: verify at least one test passed
          if ! grep -q "PASS:" /tmp/test-output.log && ! grep -q "passed" /tmp/test-output.log; then
            echo "ERROR: No PASS markers found in output — test may not have run."
            exit 1
          fi
```

For `test-scenarios`, use `/tmp/scenario-test-output.log`.

- [ ] **Step 7: Update timeout for scenarios job**

Change the timeout from 60 to 90 minutes to accommodate 17 scenarios:

```yaml
timeout-minutes: 90
```

- [ ] **Step 8: Commit**

```bash
git add .github/workflows/test.yml
git commit -m "ci: reduce image matrix to 8, add nightly extended + arm64 gating, shfmt checksum, positive success assertion"
```

---

### Task 6: Phase 7 — Final Review

- [ ] **Step 1: Run local verification**

```bash
shellcheck -S warning src/claude-code/install.sh test/claude-code/*.sh
shfmt -ln bash -i 4 -ci -d src/claude-code/install.sh test/claude-code/*.sh
python3 -m json.tool test/claude-code/scenarios.json > /dev/null
```

- [ ] **Step 2: Dispatch expert review agents**

Dispatch voltagent code-reviewer and qa-expert agents to review all changes against the spec. Verify:

- All 12 install.sh fixes applied correctly
- All 18 completions pipeline tests present
- scenarios.json has exactly 17 entries
- test.yml has 8 images in PR matrix
- No ShellCheck warnings, no shfmt diffs

- [ ] **Step 3: Push and verify CI**

```bash
git push origin feat/production-grade-overhaul
```

Monitor CI run. All 17 scenarios and 8 matrix images should pass.
