# Production-Grade Overhaul — Design Specification

**Date:** 2026-04-08
**Branch:** `feat/production-grade-overhaul`
**Status:** Draft

## 1. Problem Statement

Three independent expert audits (code quality, security, QA) identified 58 findings across the Claude Code DevContainer Feature (21 code quality, 6 actionable security + 13 positive, 31 QA). While the installer works on 27+ images with 10 test scenarios, it falls short of production-grade in three dimensions:

1. **Testability** — `install.sh` executes all logic at top level; individual functions cannot be unit-tested or sourced safely.
2. **Test coverage** — Several first-class feature options and critical error paths have zero test coverage. Completion tests cannot fail (every assertion has a `pass` else branch). Input validation rejection paths are untested.
3. **Robustness** — Incomplete ANSI stripping, fragile CI exit-code workaround, missing curl timeouts, and Arch Linux partial-upgrade anti-pattern.

## 2. Goals

- Every feature option is tested with at least one dedicated scenario.
- Every error-handling path in `install.sh` is either tested or explicitly documented as untested with rationale.
- The install script can be sourced for individual function testing without side effects.
- The CI pipeline reliably detects all failure modes (no false greens).
- The completion pipeline is robust against all known noise patterns.
- Security-relevant code (input validation, file permissions) has dedicated test coverage.

## 3. Non-Goals

- Rewriting the installer in a different language.
- Adding GPG verification of Node.js SHASUMS (documented as accepted risk).
- Changing the npm-based installation to a different distribution mechanism.
- Adding post-create hook for runtime completions (future enhancement).

## 4. Expert Audit Findings

### 4.1 Code Quality & Reliability (21 findings)

#### Critical / High

| #    | Finding                                                 | Lines | Severity |
| ---- | ------------------------------------------------------- | ----- | -------- |
| CQ-1 | `pacman -Sy` partial upgrade on Arch — should be `-Syu` | 222   | High     |

#### Medium

| #    | Finding                                                                | Lines                     | Severity |
| ---- | ---------------------------------------------------------------------- | ------------------------- | -------- |
| CQ-2 | ERR trap fires during normal cleanup — spurious "Failed at line 49"    | 44, 48-50                 | Medium   |
| CQ-3 | ANSI escape stripping regex incomplete — misses `ESC(B`, OSC sequences | 548-549, 574-575, 606-607 | Medium   |
| CQ-4 | `resolve_node_version` index.json fallback uses naive grep             | 308-313                   | Medium   |
| CQ-5 | Fish completions test re-sources full install.sh (dangerous)           | default_options.sh:47-52  | Medium   |
| CQ-6 | Idempotency test does not pass original options on re-run              | idempotency.sh:18         | Medium   |
| CQ-7 | No scenario tests for Fedora, RHEL, Rocky, Alma, or Amazon Linux       | scenarios.json            | Medium   |
| CQ-8 | `os-release` sourcing safe only due to command substitution (fragile)  | 152-157                   | Medium   |

#### Low

| #     | Finding                                                                          | Lines         | Severity |
| ----- | -------------------------------------------------------------------------------- | ------------- | -------- |
| CQ-9  | `validate_install_path` regex rejects hyphens in directory names                 | 73-78         | Low      |
| CQ-10 | `claude --version` may contain Node.js noise                                     | 501-504       | Low      |
| CQ-11 | No validation/normalization of boolean option inputs                             | 97-98         | Low      |
| CQ-12 | `detect_remote_user` awk fallback can select service accounts                    | 121-122       | Low      |
| CQ-13 | `set -E` makes ERR trap inheritance aggressive                                   | 32, 44        | Low      |
| CQ-14 | `sed -n '/[^ ]/,$p'` does not skip tab-only lines                                | 551, 577, 609 | Low      |
| CQ-15 | No timeout on curl for SHASUMS256.txt and tarball download                       | 343, 361      | Low      |
| CQ-16 | Debug mode `set -x` may leak non-API-key env vars                                | 38-41         | Low      |
| CQ-17 | Fish completions directory not created if missing but fish is installed          | 594-599       | Low      |
| CQ-18 | `configure_custom_path` doesn't write to `/etc/bash.bashrc` for non-login shells | 446-474       | Low      |
| CQ-19 | `sha256sum` availability assumption (low risk, coreutils standard)               | 367           | Low      |
| CQ-20 | `tar` extraction overwrites `/usr/local` without backup                          | 376           | Low      |
| CQ-21 | `cleanup_caches` deletes apt lists unconditionally                               | 700-703       | Low      |

### 4.2 Security Audit (19 findings, 13 positive)

#### Medium (Security)

| #     | Finding                                                              | Category     |
| ----- | -------------------------------------------------------------------- | ------------ |
| SEC-1 | SHASUMS256.txt not GPG-verified (trust-on-first-use via HTTPS)       | Supply Chain |
| SEC-2 | npm install without integrity pinning (relies on registry integrity) | Supply Chain |

#### Low (Security)

| #     | Finding                                                                  | Category        |
| ----- | ------------------------------------------------------------------------ | --------------- |
| SEC-3 | `shfmt` downloaded in CI without checksum verification                   | CI Supply Chain |
| SEC-4 | `npx` commands in CI execute version-pinned but hash-unverified packages | CI Supply Chain |

#### Positive Findings (no action needed)

- Input validation is thorough and prevents command injection (SEC-5)
- MCP config file permissions correctly set to 600/700 (SEC-6)
- Secrets handling in debug mode properly implemented (SEC-7)
- All GitHub Actions pinned to full commit SHAs (SEC-8)
- `github.head_ref` safely handled via env block (SEC-9)
- Minimal workflow permissions with proper scoping (SEC-10)
- Completion output validated before writing to system dirs (SEC-11)
- `umask 0022` correctly applied (SEC-12)
- Timeout protection on network operations (SEC-13)
- No container escape risks identified (SEC-14)
- Profile.d path expansion safe due to input validation (SEC-15)
- Node.js tarball SHA256-verified before extraction (SEC-16)
- `advance-main` workflow correctly uses `force=false` (SEC-17)
- `/etc/os-release` sourcing safe in current usage (SEC-18)
- Self-persisted script has appropriate permissions (SEC-19)

### 4.3 QA & Test Coverage (31 findings)

#### P0 (Must-Fix)

| #    | Finding                                                                                                       | Category       |
| ---- | ------------------------------------------------------------------------------------------------------------- | -------------- |
| QA-1 | No negative tests for input validation (`validate_version`, `validate_install_path`, `validate_node_version`) | Coverage Gap   |
| QA-2 | `devcontainer-cli` exit code workaround is fragile — grepping for failure strings                             | Infrastructure |
| QA-3 | `nodeVersion` option never tested with specific version (binary download path untested)                       | Coverage Gap   |
| QA-4 | Fish completions test re-sources entire install.sh in subshell                                                | Test Quality   |

#### P1 (Should-Fix)

| #     | Finding                                                                                 | Category          |
| ----- | --------------------------------------------------------------------------------------- | ----------------- |
| QA-5  | npm install failure path untested                                                       | Coverage Gap      |
| QA-6  | Node.js download failure paths untested (4 distinct modes)                              | Coverage Gap      |
| QA-7  | Unsupported OS/architecture rejection untested                                          | Coverage Gap      |
| QA-8  | LTS resolution fallback path untested                                                   | Coverage Gap      |
| QA-9  | Completion tests always pass — every assertion has `pass` else branch                   | Test Quality      |
| QA-10 | `mount_host_config` test is a no-op                                                     | Test Quality      |
| QA-11 | Idempotency test does not check completions or MCP persistence                          | Test Quality      |
| QA-12 | `custom_install_path` does not verify profile.d script content                          | Test Quality      |
| QA-13 | `node_preinstalled` does not verify Node.js was not reinstalled                         | Test Quality      |
| QA-14 | `multi_feature_combo` is nearly identical to `node_preinstalled`                        | Redundancy        |
| QA-15 | Missing option combinations (installPath+completions, installPath+MCP, etc.)            | Scenario Coverage |
| QA-16 | No RHEL/Fedora/Arch scenario tests                                                      | Scenario Coverage |
| QA-17 | Image matrix only runs core assertions — no option-specific tests                       | Image Matrix      |
| QA-18 | No upgrade/downgrade tests                                                              | Missing Category  |
| QA-19 | No permission/non-root user focused tests                                               | Missing Category  |
| QA-20 | No security-focused permission scan tests                                               | Missing Category  |
| QA-21 | `check_completion_file_contents` only checks first line — no ANSI/CRLF/noise validation | Test Helpers      |
| QA-22 | Scenario test output not separated per scenario                                         | Infrastructure    |
| QA-23 | `install.sh` not testable in isolation — no `main()` guard                              | Structural        |
| QA-24 | `duplicate.sh` is orphaned — not in `scenarios.json`, never runs                        | Redundancy        |
| QA-25 | Completion auth-error branch only tested implicitly                                     | Coverage Gap      |

#### P2 (Nice-to-Have)

| #     | Finding                                                      | Category         |
| ----- | ------------------------------------------------------------ | ---------------- |
| QA-26 | No cache cleanup verification (apt lists, npm cache)         | Missing Category |
| QA-27 | arm64 tests only cover 2 images with core assertions         | Image Matrix     |
| QA-28 | 60-minute timeout for scenarios may be insufficient          | Infrastructure   |
| QA-29 | No retry logic for QEMU arm64 flakiness                      | Infrastructure   |
| QA-30 | No Docker layer caching in CI                                | Performance      |
| QA-31 | `check_permissions` uses potentially incompatible stat flags | Test Helpers     |

## 5. Architecture: install.sh Testability Refactor

### Current Structure

```
install.sh (executed top-to-bottom)
├── Lines 1-29:  POSIX bootstrap (#!/bin/sh, detect bash, exec bash on Alpine)
├── Lines 30-50: Bash-specific setup (set -Eeuo pipefail, umask, traps, TEMP_DIR)
├── Lines 51+:   Logging functions, validation functions, all feature logic
└── Executes everything sequentially — no main() function
```

### Target Structure

```
install.sh
├── Lines 1-29:   POSIX bootstrap (UNCHANGED — must remain at top level)
├── Lines 30+:    Bash-only section begins
│   ├── Function definitions ONLY (logging, validation, detect_*, ensure_*, install_*, setup_*, etc.)
│   ├── main() function wrapping ALL execution logic:
│   │   ├── set -Eeuo pipefail, umask 0022
│   │   ├── trap setup (ERR, EXIT, INT, TERM)
│   │   ├── TEMP_DIR creation
│   │   ├── Option reading and validation
│   │   ├── All install steps (ensure_node, install_claude_code, etc.)
│   │   └── cleanup_caches, persist_script
│   └── Guard: if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then main "$@"; fi
```

### Critical Design Decisions

**POSIX bootstrap stays at top level.** Lines 1-29 use `#!/bin/sh` and handle Alpine's missing bash. The `BASH_SOURCE` guard goes AFTER the `exec bash` re-invocation point (line 30+), so it is only evaluated under bash.

**Shell options, traps, and umask move INSIDE `main()`.** This is essential — `set -Eeuo pipefail`, `umask 0022`, the ERR/EXIT traps, and `TEMP_DIR` creation are all side effects that must NOT execute when the script is sourced for testing. Moving them inside `main()` means:

- Sourcing only defines functions (safe for test callers).
- Direct execution calls `main()` which sets up the environment and runs.

**Function definitions remain at top level (after line 30).** Logging functions (`log_info`, `log_warn`, etc.), validation functions, and all feature functions are defined at the top level of the bash section. They do NOT need to be inside `main()` — they are pure functions that are safe to define.

**Tests source the script and selectively set up what they need.** A test that calls `validate_version` does not need `set -Eeuo pipefail` or traps. A test that calls `setup_completions` may need to set specific variables (`SHELL_COMPLETIONS`, `esc`). The test is responsible for its own environment.

### Impact Assessment

- All existing behavior is preserved (script runs identically when executed directly).
- Tests can now `source install.sh` and call `validate_version "bad;input"` to test rejection.
- The fish completions test can call `setup_completions` without re-running the entire installer.
- No changes to `devcontainer-feature.json` or the feature's public interface.
- Sourcing does NOT modify shell options, traps, or umask of the calling shell.

## 6. Test Suite Redesign

### New Scenarios to Add

| Scenario                        | Image         | Options                                                | Tests                                                                                                                               |
| ------------------------------- | ------------- | ------------------------------------------------------ | ----------------------------------------------------------------------------------------------------------------------------------- |
| `negative_validation`           | `base:ubuntu` | default (valid install)                                | Sources persisted `install.sh` and calls validators with bad input; asserts each rejects (see mechanism below)                      |
| `custom_node_version`           | `base:ubuntu` | `nodeVersion: "22"`                                    | Node.js 22.x installed, binary download path exercised                                                                              |
| `fedora_default`                | `fedora:40`   | default                                                | Core assertions (verifies dnf-based install path succeeds; no Fedora-specific assertions beyond core)                               |
| `upgrade_version`               | `base:ubuntu` | `version: "0.2.57"`                                    | After initial install, re-runs persisted `install.sh` with `VERSION=latest` env var; verifies version changed (see mechanism below) |
| `install_path_with_completions` | `base:ubuntu` | `installPath: "/opt/claude"`, `shellCompletions: true` | PATH propagation via profile.d + completions attempted                                                                              |
| `security_permissions`          | `base:ubuntu` | `enableMcpServers: true`                               | No world-writable files under `$INSTALL_PATH`, MCP config is 600, `~/.claude/` is 700, correct ownership by remote user             |

#### Mechanism: `negative_validation` Scenario

The devcontainer CLI always installs with valid options first (the container must build and start for the test script to run). Inside the running container, the test script:

1. Sources the persisted install script with the `main()` guard active:
   `source /usr/local/share/devcontainer-features/claude-code/install.sh`
2. Calls individual validators in subshells and asserts non-zero exit:
   ```bash
   (validate_version "bad;input") && fail "Should have rejected" || pass "Rejected bad version"
   (validate_install_path "relative/path") && fail "Should have rejected" || pass "Rejected relative path"
   (validate_node_version "abc") && fail "Should have rejected" || pass "Rejected non-numeric node version"
   ```

This requires Phase 1 (`main()` guard) to be complete first.

#### Mechanism: `upgrade_version` Scenario

The scenario installs `version: "0.2.57"` via `scenarios.json`. The test script then:

1. Records `claude --version` (should be `0.2.57`).
2. Re-runs the persisted install script with `VERSION=latest`:
   ```bash
   sudo VERSION=latest bash /usr/local/share/devcontainer-features/claude-code/install.sh
   ```
3. Records `claude --version` again and asserts it differs from `0.2.57`.

### Existing Scenarios to Strengthen

| Scenario               | Changes                                                                                                                                            |
| ---------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------- |
| `default_options`      | Remove fish re-source hack; add completion content depth check (no ANSI, no CRLF, no Node.js noise); make bash completion hard assertion on Ubuntu |
| `mount_host_config`    | Verify documentation strings are printed (grep install log)                                                                                        |
| `idempotency`          | Check completions/MCP persist; pass original options on re-run                                                                                     |
| `custom_install_path`  | Verify profile.d content contains correct path                                                                                                     |
| `node_preinstalled`    | Verify original Node.js location preserved                                                                                                         |
| `multi_feature_combo`  | Verify Node 22 is active version (not older)                                                                                                       |
| `completions_disabled` | Verify no WARNING emitted; confirm `log_debug "Shell completions disabled."` path exercised (grep build log if available)                          |

### Orphaned / Redundant Files

- `duplicate.sh` — **Delete.** It is not in `scenarios.json`, never runs, and is functionally identical to `core_assertions` already run by `test.sh`.

### Test Helper Improvements

| Helper                                 | Change                                                                                                                                                                       |
| -------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `check_completion_file_contents`       | After first-line prefix passes, automatically call `check_completion_file_integrity` (see below). This retroactively strengthens every existing test that calls this helper. |
| New: `check_completion_file_integrity` | Full-file validation: non-empty, no `\r` (CRLF), no ANSI escape sequences (`\033`), no `(node:` lines, no auth error text. Would have caught bugs B1, B3, B4, B5 from PR #8. |
| New: `check_file_contains`             | Assert file contains a given string (uses `grep -qF`)                                                                                                                        |
| New: `check_file_not_contains`         | Assert file does NOT contain a given string                                                                                                                                  |
| New: `check_no_world_writable`         | Scan a path for world-writable files (`find -perm -o+w -type f`)                                                                                                             |
| `test_summary`                         | Add explicit `exit 0` on success (minor behavioral change: code after `test_summary` no longer runs, but all current tests call it as their last statement)                  |

### New Test File: `completions_pipeline.sh` (HIGHEST PRIORITY)

**Purpose:** Unit-test the completions cleanup pipeline in isolation using a mock `claude` binary. This is the single most important new test — it directly targets the area that required 6 fix iterations.

**Mechanism:** Sources `install.sh` (requires `main()` guard). Creates a mock `claude` script that returns controlled output. Extracts the pipeline logic into a helper (`run_bash_pipeline`) and tests 18 cases:

| Test | Input                                    | Expected Behavior                               | Bug Caught   |
| ---- | ---------------------------------------- | ----------------------------------------------- | ------------ |
| A1   | Clean valid `_claude() {`                | Accepted, first line starts with `_`            | Baseline     |
| A2   | ANSI codes wrapping `_claude() {`        | ANSI stripped, content preserved                | B3 (affd121) |
| A3   | CRLF line endings                        | `\r` stripped, prefix valid                     | B5 (087492b) |
| A4   | Node.js warning + valid content          | Warning stripped, valid content retained        | B4 (3465717) |
| A5   | Node.js warning ONLY (no valid content)  | Empty output (nothing to write)                 | B4 variant   |
| A6   | "Not logged in" auth error               | Rejected by prefix check, detected by auth grep | B1, B6       |
| A7   | Combined ANSI + CRLF + Node.js + valid   | All noise stripped, valid content extracted     | B3+B4+B5     |
| A8   | Valid fish `complete -c claude`          | Accepted with `complete` prefix                 | B1 (fish)    |
| A9   | Valid zsh `#compdef claude`              | Accepted with `#compdef` prefix                 | Baseline     |
| A10  | `if type complete` format                | Accepted with `if` prefix                       | B5 (087492b) |
| A11  | `function _claude_completion()` format   | Accepted with `function` prefix                 | B6 (41b346b) |
| A12  | Empty string                             | Empty output                                    | Edge case    |
| A13  | Whitespace-only                          | Empty output                                    | Edge case    |
| A14  | Random garbage text                      | Rejected by prefix check                        | B1 (995bbd4) |
| A15  | End-to-end: valid mock → file written    | File exists, passes integrity check             | All          |
| A16  | End-to-end: auth error → no file written | File not created                                | B1, B6       |
| A17  | Mid-line ANSI codes                      | Stripped without corrupting content             | B3 variant   |
| A18  | Multiple stacked Node.js warnings        | All stripped, valid content retained            | B4 variant   |

**Coverage proof:** Every PR #8 bug is caught by at least 2-3 independent assertions.

### New Test File: `negative_validation.sh`

Tests all three input validators (`validate_version`, `validate_install_path`, `validate_node_version`) with known-bad and known-good inputs. Requires `main()` guard. Tests boundary values (18, 99), shell injection attempts, path traversal, spaces, empty strings.

### New Test File: `security_permissions.sh`

Validates file permissions and ownership after install with MCP enabled: claude binary is 755, no world-writable files under install path, MCP config is 600, `~/.claude/` is 700, correct ownership by remote user, completion files have no ANSI/CRLF/noise.

## 7. Install Script Fixes

### Must-Fix (this PR)

| #   | Fix                                                                                                                                                                                                                                                       | Finding |
| --- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------- |
| 1   | Change `pacman -Sy` to `pacman -Syu --noconfirm --needed` (trade-off: adds system upgrade time on Arch, but avoids partial-upgrade breakage; Arch images in CI are fresh so upgrade is minimal)                                                           | CQ-1    |
| 2   | Fix ERR trap in cleanup: replace `[[ -n "${TEMP_DIR}" ]] && rm -rf ... \|\| true` with `if [[ -n "${TEMP_DIR}" ]]; then rm -rf ... \|\| true; fi` (the `&&` chain causes `[[ -n "" ]]` to return 1, triggering ERR trap before `\|\| true` suppresses it) | CQ-2    |
| 3   | Broaden ANSI stripping: add `ESC(B`, `ESC=`, `ESC>` patterns                                                                                                                                                                                              | CQ-3    |
| 4   | Fix `sed -n '/[^ ]/,$p'` to use `'/[^[:space:]]/,$p'`                                                                                                                                                                                                     | CQ-14   |
| 5   | Allow hyphens in `validate_install_path` regex                                                                                                                                                                                                            | CQ-9    |
| 6   | Add `--connect-timeout 30 --max-time 300` to curl downloads                                                                                                                                                                                               | CQ-15   |
| 7   | Create fish completions directory if fish is installed but dir missing                                                                                                                                                                                    | CQ-17   |
| 8   | _(Implemented in Phase 1, not Phase 2)_ Wrap execution in `main()` with `BASH_SOURCE` guard                                                                                                                                                               | QA-23   |
| 9   | Clean up `claude --version` output (pipe through `head -1` + ANSI strip)                                                                                                                                                                                  | CQ-10   |

### Should-Fix (included in this PR)

| #   | Fix                                                                                                                                                                                                                                                                                                                                         | Finding |
| --- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------- |
| 10  | Normalize boolean options to lowercase                                                                                                                                                                                                                                                                                                      | CQ-11   |
| 11  | Restrict `detect_remote_user` UID range to 1000-60000                                                                                                                                                                                                                                                                                       | CQ-12   |
| 12  | Protect `detect_os` from os-release variable clobbering: add a comment documenting that the subshell-via-command-substitution (`OS_FAMILY=$(detect_os)`) is the intentional protection mechanism that prevents `. /etc/os-release` from overwriting global `VERSION`; do NOT refactor `detect_os` to be called without command substitution | CQ-8    |

## 8. CI Pipeline Improvements

### Image Matrix Redesign

**Remove `mcr.microsoft.com/devcontainers/universal:2`** — multi-GB image, extremely slow to build, provides zero unique code path coverage beyond `javascript-node`.

**Remove redundant language-specific MCR images** — `typescript-node`, `python:3`, `rust`, `go`, `cpp`, `dotnet`, `java`, `ruby`, `php` are all Debian-based and exercise the same code path as `base:ubuntu`. Only `javascript-node` is unique (pre-installed Node.js).

**Remove redundant same-family images** — Within each distro family, the code paths are identical. `ubuntu:22.04` is the same as `ubuntu:24.04`; `fedora:39` is the same as `fedora:40`.

**PR image matrix (8 images, down from 27):**

| Image                                             | Family | Rationale                         |
| ------------------------------------------------- | ------ | --------------------------------- |
| `mcr.microsoft.com/devcontainers/base:ubuntu`     | Debian | Primary target, MCR base          |
| `mcr.microsoft.com/devcontainers/base:debian`     | Debian | MCR Debian variant                |
| `mcr.microsoft.com/devcontainers/base:alpine`     | Alpine | MCR Alpine, musl, POSIX bootstrap |
| `mcr.microsoft.com/devcontainers/javascript-node` | Debian | Pre-installed Node.js path        |
| `ubuntu:24.04`                                    | Debian | Raw OS, full Node binary download |
| `alpine:3.21`                                     | Alpine | Raw Alpine, apk Node install      |
| `archlinux:latest`                                | Arch   | Only Arch image, pacman path      |
| `fedora:40`                                       | RHEL   | RHEL family, dnf path             |

**Nightly-only extended matrix (5 additional images):**

| Image              | Rationale                          |
| ------------------ | ---------------------------------- |
| `rockylinux:9`     | Enterprise RHEL-compatible         |
| `amazonlinux:2023` | AWS environments                   |
| `debian:bookworm`  | Specific Debian release validation |
| `ubuntu:22.04`     | Older LTS release                  |
| `alpine:3.20`      | Older Alpine release               |

**arm64 matrix** — Unchanged (`ubuntu:24.04`, `alpine:3.21`). Move to nightly + release branches only (QEMU too slow for every PR).

### CI Workflow Structure

| Tier | Job                          | Trigger        | Target Time       |
| ---- | ---------------------------- | -------------- | ----------------- |
| 0    | `lint`                       | Every push/PR  | ~2 min            |
| 1    | `test-scenarios`             | Every push/PR  | ~25 min           |
| 1    | `test-image-matrix`          | Every push/PR  | ~5 min (parallel) |
| 2    | `test-arm64`                 | Nightly + main | ~30 min           |
| 2    | `test-image-matrix-extended` | Nightly        | ~10 min           |

**Target PR CI time: ~25 min** (lint + scenarios + matrix run in parallel after lint).

### Other CI Changes

| #   | Change                                                            | Finding |
| --- | ----------------------------------------------------------------- | ------- |
| 1   | Add SHA256 checksum verification for shfmt download               | SEC-3   |
| 2   | Add positive success assertion alongside failure grep             | QA-2    |
| 3   | Upgrade `@devcontainers/cli` if newer version fixes exit code bug | QA-2    |

## 9. Implementation Order

1. **Phase 1: Structural** — `main()` guard refactor in `install.sh` (enables all subsequent test work)
2. **Phase 2: Script fixes** — All must-fix items from section 7
3. **Phase 3: Test helpers** — New and improved helper functions in `test.sh`
4. **Phase 4: Existing scenario improvements** — Strengthen existing tests
5. **Phase 5: New scenarios** — Add missing test scenarios
6. **Phase 6: CI improvements** — Pipeline hardening
7. **Phase 7: Final review** — Expert agent review of all changes

## 10. Success Criteria

- All tests pass on the 8-image PR matrix and 16 scenarios.
- Every feature option (`version`, `nodeVersion`, `installPath`, `enableMcpServers`, `mountHostConfig`, `shellCompletions`) has at least one dedicated scenario with meaningful assertions.
- Input validation rejection is tested for all three validators.
- `install.sh` can be sourced without side effects.
- No `WARNING:` lines from completions in CI output for expected scenarios (auth-error and timeout cases demoted to `DEBUG:`; `WARNING` preserved for genuinely unexpected output).
- CI failure detection does not rely solely on string matching (positive success assertion added).
- Boolean options work case-insensitively (`TRUE`, `True`, `true` all accepted).
- `detect_remote_user` UID range restricted to 1000-60000 (excludes `nobody` and service accounts).
- `detect_os` does not clobber global variables when refactored out of command substitution.
- Expert review agents confirm production readiness.
- Untested error paths documented as comments in `install.sh` (e.g., `# UNTESTED: requires network failure to trigger`).

## 11. Accepted Risks (No Action)

- **SEC-1**: SHASUMS256.txt not GPG-verified — accepted tradeoff; HTTPS provides baseline integrity.
- **SEC-2**: npm install relies on registry integrity — industry standard; recommend version pinning for teams.
- **QA-27**: arm64 scenario coverage limited — QEMU too slow for full scenarios.
- **QA-30**: No Docker layer caching — acceptable CI runtime for this project size.
