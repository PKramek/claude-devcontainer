# Install Fix, Formatting Enforcement, and License Change Design

**Date:** 2026-04-01

---

## Summary

Four changes grouped into one implementation cycle:

1. Fix `log_info` stdout contamination bug (breaks install on all images)
2. Fix CI false positives (test steps pass despite feature install failures)
3. Two-layer formatting enforcement (pre-commit auto-formats; CI blocks unformatted PRs)
4. Change license from MIT to Apache 2.0

---

## 1. install.sh Bug: log_info Stdout Contamination

### Root Cause

`log_info()` writes to **stdout**:

```bash
log_info() { echo "${FEATURE_LOG_PREFIX} $*"; }
```

`ensure_node` calls `resolve_node_version` via command substitution:

```bash
resolved_version=$(resolve_node_version "${NODE_VERSION}")
```

Inside `resolve_node_version`, `log_info "Resolved LTS to Node.js ${lts_version}"` is called
before `echo "${lts_version}"`. Both writes go to stdout. The command substitution captures
**all** stdout, so `resolved_version` becomes:

```
[claude-code feature] Resolved LTS to Node.js 24
24
```

That multi-line string is then used to build the Node.js download URL:

```
https://nodejs.org/dist/latest-v[claude-code feature] Resolved LTS to Node.js 24
24.x/SHASUMS256.txt
```

curl rejects this with `bad range in URL position 34` (the `[` bracket). Every image fails.

### Fix

Change `log_info` to write to stderr, consistent with `log_warn` and `log_error`:

```bash
log_info() { echo "${FEATURE_LOG_PREFIX} $*" >&2; }
```

One character change (`>&2`). No other logging functions need to change — `log_warn` and
`log_error` already write to stderr.

### Affected File

- `src/claude-code/install.sh` line 51

---

## 2. CI False Positives: devcontainer features test Exit Code

### Root Cause

`devcontainer features test` (CLI v0.85.0) exits **0** even when the feature install fails
inside Docker. The container build failure is printed to output but does not set a non-zero
exit code on the CLI process. The `| tee` pipeline in the workflow steps does not compensate.

### Evidence

GitHub Actions shows the `test-image-matrix (ubuntu:22.04)` job as **succeeded** while the
log contains:

```
Exit code 1
[-] Failed to launch container
```

### Fix

After each `devcontainer features test` step, grep the captured log for known failure
strings. If any are found, force `exit 1`:

```bash
devcontainer features test ... 2>&1 | tee /tmp/test-output.log
if grep -qE "Exit code [^0]|failed to install|Failed to launch" /tmp/test-output.log; then
  echo "ERROR: Test output contains failures."
  exit 1
fi
```

This pattern is applied to all three test jobs: `test-scenarios`, `test-image-matrix`,
`test-arm64`.

### Affected File

- `.github/workflows/test.yml` — all three test job `run:` blocks

---

## 3. Two-Layer Formatting Enforcement

### Architecture

| Layer | Tool | Mode | Bypassable? |
|---|---|---|---|
| Pre-commit (local) | shfmt, prettier, markdownlint | **Write** (auto-format) | Yes (`--no-verify`) |
| CI lint job | shfmt, prettier, markdownlint | **Check** (fail on diff) | No (required status check) |

Developers get auto-formatting on commit (no manual formatting step). If they skip hooks
with `--no-verify`, the CI lint job catches it and blocks the PR from merging.

### Pre-commit Changes

**shfmt**: Add `-w` explicitly so the hook writes formatted files in place:

```yaml
- repo: https://github.com/scop/pre-commit-shfmt
  rev: v3.13.0-1
  hooks:
    - id: shfmt
      args: ["-w", "-i", "4", "-ci"]
```

**prettier** (`mirrors-prettier`): Already writes in pre-commit context. No change.

**markdownlint** (`--fix`): Already writes in pre-commit context. No change.

**no-commit-to-branch**: Add `develop` alongside `main` to prevent direct commits to both
protected branches:

```yaml
- id: no-commit-to-branch
  args: ["--branch", "main", "--branch", "develop"]
```

### CI Changes

No changes to check mode. The CI lint job already runs:

- `shfmt -d -i 4 -ci src/ test/` — diff mode, fails if files would change
- `npx prettier --check` — fails if files would change
- `npx markdownlint-cli` — fails on lint errors

These remain unchanged. They are the enforcement layer.

### Affected File

- `.pre-commit-config.yaml`

---

## 4. License: MIT → Apache 2.0

### Changes

**`LICENSE`**: Replace MIT text with Apache 2.0 text. Keep `Copyright (c) 2026 PKramek`.

**`src/claude-code/devcontainer-feature.json`**: Update `licenseURL` from pointing to the
MIT license to Apache 2.0:

```json
"licenseURL": "https://github.com/pkramek/claude-devcontainer/blob/main/LICENSE"
```

(The URL itself does not change — it points to the `LICENSE` file whose content is
replaced. No URL update needed.)

**`README.md`**: No change needed — README does not mention the license name inline.

### Affected Files

- `LICENSE`
- No other files require changes (licenseURL already points to the file, not the license name)

---

## Implementation Order

1. `log_info` fix in `install.sh` (unblocks all test runs)
2. License file replacement
3. Pre-commit config update (shfmt `-w`, no-commit-to-branch `develop`)
4. CI false positive grep checks in `test.yml`

Each change is independent. All four can land in a single commit or separate commits per
logical group.

---

## What This Does NOT Change

- CI check-mode commands (shfmt `-d`, prettier `--check`) — these stay as-is
- Node.js version resolution logic — only the logging output destination changes
- Any test scenarios or test assertions
- Branch protection rulesets (handled separately in Task 6)
