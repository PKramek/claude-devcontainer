# Install Fix, Formatting Enforcement, and License Change Design

**Date:** 2026-04-01

---

## Summary

Five changes grouped into one implementation cycle:

1. Fix `log_info` and `log_debug` stdout contamination bug (breaks install on all images)
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

Change both `log_info` and `log_debug` to write to stderr, consistent with `log_warn` and
`log_error`:

```bash
log_info()  { echo "${FEATURE_LOG_PREFIX} $*" >&2; }
log_debug() {
    if [[ "${DEBUG:-false}" == "true" ]]; then
        echo "${FEATURE_LOG_PREFIX} DEBUG: $*" >&2
    fi
}
```

`log_debug` has the same stdout defect (line 54-57). While it is not a live bug today
(no command-substitution call site currently uses a function that calls `log_debug`), the
same class of issue applies and fixing it is required for defensive correctness.

`log_warn` and `log_error` already write to stderr — no change needed.

### Affected File

- `src/claude-code/install.sh` lines 51 and 54-57

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

This is a **heuristic workaround** for a devcontainer CLI bug (exits 0 on container build
failure). The real fix would be a CLI patch. The workaround is tied to the CLI's current
output format and must be revisited if the CLI version is upgraded.

After each `devcontainer features test` step, grep the captured log for known failure
strings. If any are found, force `exit 1`. Each job uses a different log path:

**test-scenarios** (log: `/tmp/scenario-test-output.log`):

```bash
devcontainer features test --project-folder . \
  2>&1 | tee /tmp/scenario-test-output.log
if grep -qE "Exit code [^0]|failed to install|Failed to launch" \
    /tmp/scenario-test-output.log; then
  echo "ERROR: Test output contains failures."
  exit 1
fi
```

**test-image-matrix and test-arm64** (log: `/tmp/test-output.log`):

```bash
devcontainer features test ... \
  2>&1 | tee /tmp/test-output.log
if grep -qE "Exit code [^0]|failed to install|Failed to launch" \
    /tmp/test-output.log; then
  echo "ERROR: Test output contains failures."
  exit 1
fi
```

### Affected File

- `.github/workflows/test.yml` — all three test job `run:` blocks (note: different log
  paths per job)

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

**shfmt**: The `scop/pre-commit-shfmt` hook already runs in write mode (`-w`) by default.
The `-w` flag in user args is redundant but harmless (shfmt tolerates duplicate `-w`).
Keep it for explicitness — it documents intent clearly:

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

**`LICENSE`**: Replace MIT text with the standard, verbatim Apache License 2.0 text
(OSI-approved format). Do not embed the copyright line inside the license body — Apache 2.0
copyright attribution goes in a separate `NOTICE` file.

**`NOTICE`** (new file): Create with the copyright attribution:

```
claude-devcontainer
Copyright (c) 2026 PKramek
```

The Apache 2.0 license (Section 4(d)) requires redistributors to include the NOTICE file.
Creating it now ensures compliance.

**`README.md`**: The `## License` section currently reads `MIT`. Update to `Apache 2.0`:

```markdown
## License

Apache 2.0
```

**`src/claude-code/devcontainer-feature.json`**: The `licenseURL` value already points to
`https://github.com/pkramek/claude-devcontainer/blob/main/LICENSE` — no URL change needed,
the file content replacement is sufficient.

### Affected Files

- `LICENSE` (content replaced)
- `NOTICE` (new file)
- `README.md` (license name updated)

---

## Implementation Order

1. `log_info` + `log_debug` fix in `install.sh` (unblocks all test runs)
2. License: replace `LICENSE`, create `NOTICE`, update `README.md`
3. Pre-commit config update (shfmt `-w` explicit, no-commit-to-branch `develop`)
4. CI false positive grep checks in `test.yml` (correct log path per job)

Each change is independent. All four can land in a single commit or separate commits per
logical group.

---

## What This Does NOT Change

- CI check-mode commands (shfmt `-d`, prettier `--check`) — these stay as-is
- Node.js version resolution logic — only the logging output destination changes
- Any test scenarios or test assertions
- Branch protection rulesets (handled separately in Task 6)
