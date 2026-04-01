# Install Fix, Formatting Enforcement, and License Change Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix the install.sh stdout contamination bug that breaks every image, add CI false-positive protection, enforce two-layer formatting, and change the license to Apache 2.0.

**Architecture:** Four independent, ordered changes: (1) fix logging functions so they write to stderr — unblocking all test runs; (2) update the license files, README, and feature manifest; (3) pin pre-commit hooks to commit SHAs and add develop branch protection; (4) add grep-based failure detection to all three CI test jobs to work around a devcontainer CLI exit-code bug.

**Tech Stack:** Bash, GitHub Actions, pre-commit, Apache 2.0

**Git author for all commits:** `PKramek <peterkramek@gmail.com>`

**CRITICAL:** No Co-Authored-By, no AI attribution in any commit message.

---

## File Map

| File | Change |
|---|---|
| `src/claude-code/install.sh` | `log_info` → stderr; `log_debug` → stderr; SPDX headers added |
| `LICENSE` | Replaced with verbatim Apache 2.0 text |
| `NOTICE` | New file — copyright attribution |
| `README.md` | License section: MIT → Apache 2.0; Contributing: add `pre-commit install` step |
| `src/claude-code/devcontainer-feature.json` | Add `"license": "Apache-2.0"` field |
| `.pre-commit-config.yaml` | shfmt `-w` explicit; `no-commit-to-branch` adds `develop`; all `rev:` values replaced with commit SHAs |
| `.github/workflows/test.yml` | All three test job `run:` blocks get grep-based failure detection |

---

## Task 1: Fix install.sh Logging and Add SPDX Headers

**Files:**
- Modify: `src/claude-code/install.sh` lines 1-2 (SPDX headers), 51 (`log_info`), 54-57 (`log_debug`)

**Context:** `log_info()` currently writes to stdout. When `resolve_node_version` is called
via `$(...)`, the log message contaminates the captured return value, producing a malformed
Node.js download URL that curl rejects with "bad range in URL". Every image fails silently.
`log_debug` has the same class of defect. The fix is one character per function: `>&2`.

- [ ] **Step 1: Add SPDX headers after the shebang**

The current file starts:
```bash
#!/usr/bin/env bash
#
# Claude Code DevContainer Feature — install.sh
```

Edit `src/claude-code/install.sh` — INSERT two new lines after line 1 (do NOT replace the
existing comment block). The result must be:
```bash
#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: 2026 PKramek
#
# Claude Code DevContainer Feature — install.sh
```

This adds 2 net new lines. Every line below the shebang shifts down by 2.

- [ ] **Step 2: Fix log_info to write to stderr**

Current line 51 (will be line 53 after step 1):
```bash
log_info() { echo "${FEATURE_LOG_PREFIX} $*"; }
```

Change to:
```bash
log_info()  { echo "${FEATURE_LOG_PREFIX} $*" >&2; }
```

- [ ] **Step 3: Fix log_debug to write to stderr**

Current lines 54-57 (will be lines 56-59 after steps 1-2):
```bash
log_debug() {
    if [[ "${DEBUG:-false}" == "true" ]]; then
        echo "${FEATURE_LOG_PREFIX} DEBUG: $*"
    fi
}
```

Change to:
```bash
log_debug() {
    if [[ "${DEBUG:-false}" == "true" ]]; then
        echo "${FEATURE_LOG_PREFIX} DEBUG: $*" >&2
    fi
}
```

- [ ] **Step 4: Verify log_warn and log_error already write to stderr**

Run:
```bash
grep -n "log_info\|log_warn\|log_error\|log_debug" src/claude-code/install.sh | head -8
```

Expected output (line numbers will be offset by 2 from step 1):
```
53:log_info()  { echo "${FEATURE_LOG_PREFIX} $*" >&2; }
54:log_warn()  { echo "${FEATURE_LOG_PREFIX} WARNING: $*" >&2; }
55:log_error() { echo "${FEATURE_LOG_PREFIX} ERROR: $*" >&2; }
56:log_debug() {
```

All four functions must end with `>&2`. If `log_warn` or `log_error` are missing `>&2`, stop and fix them too.

- [ ] **Step 5: Verify no stdout-writing log functions remain**

Run:
```bash
grep -n 'echo.*FEATURE_LOG_PREFIX' src/claude-code/install.sh | grep -v '>&2'
```

Expected: no output. Any line without `>&2` is a bug.

- [ ] **Step 6: Verify SPDX headers are correct**

Run:
```bash
head -5 src/claude-code/install.sh
```

Expected:
```
#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: 2026 PKramek
#
# Claude Code DevContainer Feature — install.sh
```

- [ ] **Step 7: Run ShellCheck to verify no regressions**

Run (requires `shellcheck` installed — install via `brew install shellcheck` on macOS or
`apt install shellcheck` on Debian/Ubuntu if not present):
```bash
shellcheck --severity=warning src/claude-code/install.sh
```

Expected: no output (no warnings or errors).

- [ ] **Step 8: Run pre-commit on install.sh to ensure it is already clean**

This step prevents Task 3's `pre-commit run --all-files` from reformatting this file and
contaminating the Task 3 commit with changes from Task 1.

Run:
```bash
pre-commit run shfmt --files src/claude-code/install.sh
pre-commit run shellcheck --files src/claude-code/install.sh
```

Expected: both exit 0. If shfmt modifies the file, stage the reformatted version before
committing — the commit should include the clean, shfmt-formatted version.

- [ ] **Step 9: Commit**

```bash
git add src/claude-code/install.sh
git commit --author="PKramek <peterkramek@gmail.com>" \
  -m "fix: redirect log_info and log_debug to stderr, add SPDX headers"
```

---

## Task 2: Update License to Apache 2.0

**Files:**
- Modify: `LICENSE`
- Create: `NOTICE`
- Modify: `README.md`
- Modify: `src/claude-code/devcontainer-feature.json`

**Context:** The project is changing from MIT to Apache 2.0. Apache 2.0 requires a separate
NOTICE file for copyright attribution (not embedded in LICENSE). The devcontainer-feature.json
needs a `"license"` SPDX field so the GHCR registry displays the license correctly. The
README Contributing section needs a `pre-commit install` step for non-devcontainer contributors.

- [ ] **Step 1: Replace LICENSE with verbatim Apache 2.0 text**

Download the canonical, byte-for-byte Apache 2.0 text from the official source. Do NOT
copy-paste from a website or embed text in a script — copy-paste strips the APPENDIX and
introduces subtle differences. Do NOT add a copyright line inside this file — copyright
goes in NOTICE.

```bash
curl -o LICENSE https://www.apache.org/licenses/LICENSE-2.0.txt
```

Verify the APPENDIX section is present (it follows "END OF TERMS AND CONDITIONS"):
```bash
grep -c "APPENDIX" LICENSE
```
Expected: `1`

Verify no copyright line was added inside:
```bash
head -5 LICENSE
```
Expected: the file starts with whitespace + "Apache License" header, no copyright line.

The full canonical text starts as follows and includes the APPENDIX section at the end:
```
                                 Apache License
                           Version 2.0, January 2004
                        http://www.apache.org/licenses/

   TERMS AND CONDITIONS FOR USE, REPRODUCTION, AND DISTRIBUTION

   1. Definitions.

      "License" shall mean the terms and conditions for use, reproduction,
      and distribution as defined by Sections 1 through 9 of this document.

      "Licensor" shall mean the copyright owner or entity authorized by
      the copyright owner that is granting the License.

      "Legal Entity" shall mean the union of the acting entity and all
      other entities that control, are controlled by, or are under common
      control with that entity. For the purposes of this definition,
      "control" means (i) the power, direct or indirect, to cause the
      direction or management of such entity, whether by contract or
      otherwise, or (ii) ownership of fifty percent (50%) or more of the
      outstanding shares, or (iii) beneficial ownership of such entity.

      "You" (or "Your") shall mean an individual or Legal Entity
      exercising permissions granted by this License.

      "Source" form shall mean the preferred form for making modifications,
      including but not limited to software source code, documentation
      source, and configuration files.

      "Object" form shall mean any form resulting from mechanical
      transformation or translation of a Source form, including but
      not limited to compiled object code, generated documentation,
      and conversions to other media types.

      "Work" shall mean the work of authorship made available under
      the License, as indicated by a copyright notice that is included in
      or attached to the work (an example is provided in the Appendix below).

      "Derivative Works" shall mean any work, whether in Source or Object
      form, that is based on (or derived from) the Work and for which the
      editorial revisions, annotations, elaborations, or other modifications
      represent, as a whole, an original work of authorship. For the purposes
      of this License, Derivative Works shall not include works that remain
      separable from, or merely link (or bind by name) to the interfaces of,
      the Work and Derivative Works thereof.

      "Contribution" shall mean, as submitted to the Licensor for inclusion
      in the Work by the copyright owner or by an individual or Legal Entity
      authorized to submit on behalf of the copyright owner. For the purposes
      of this definition, "submitted" means any form of electronic, verbal,
      or written communication sent to the Licensor or its representatives,
      including but not limited to communication on electronic mailing lists,
      source code control systems, and issue tracking systems that are managed
      by, or on behalf of, the Licensor for the purpose of discussing and
      improving the Work, but excluding communication that is conspicuously
      marked or designated in writing by the copyright owner as "Not a
      Contribution."

      "Contributor" shall mean Licensor and any Legal Entity on behalf of
      whom a Contribution has been received by the Licensor and included
      within the Work.

   2. Grant of Copyright License. Subject to the terms and conditions of
      this License, each Contributor hereby grants to You a perpetual,
      worldwide, non-exclusive, no-charge, royalty-free, irrevocable
      copyright license to reproduce, prepare Derivative Works of,
      publicly display, publicly perform, sublicense, and distribute the
      Work and such Derivative Works in Source or Object form.

   3. Grant of Patent License. Subject to the terms and conditions of
      this License, each Contributor hereby grants to You a perpetual,
      worldwide, non-exclusive, no-charge, royalty-free, irrevocable
      (except as stated in this section) patent license to make, have made,
      use, offer to sell, sell, import, and otherwise transfer the Work,
      where such license applies only to those patent claims licensable
      by such Contributor that are necessarily infringed by their
      Contribution(s) alone or by the combination of their Contributions
      with the Work to which such Contributions were submitted. If You
      institute patent litigation against any entity (including a
      cross-claim or counterclaim in a lawsuit) alleging that the Work
      or a Contribution incorporated within the Work constitutes direct
      or contributory patent infringement, then any patent licenses
      granted to You under this License for that Work shall terminate
      as of the date such litigation is filed.

   4. Redistribution. You may reproduce and distribute copies of the
      Work or Derivative Works thereof in any medium, with or without
      modifications, and in Source or Object form, provided that You
      meet the following conditions:

      (a) You must give any other recipients of the Work or Derivative
          Works a copy of this License; and

      (b) You must cause any modified files to carry prominent notices
          stating that You changed the files; and

      (c) You must retain, in the Source form of any Derivative Works
          that You distribute, all copyright, patent, trademark, and
          attribution notices from the Source form of the Work,
          excluding those notices that do not pertain to any part of
          the Derivative Works; and

      (d) If the Work includes a "NOTICE" text file as part of its
          distribution, You must include a readable copy of the
          attribution notices contained within such NOTICE file, in
          at least one of the following places: within a NOTICE text
          file distributed as part of the Derivative Works; within
          the Source form or documentation, if provided along with the
          Derivative Works; or, within a display generated by the
          Derivative Works, if and wherever such third-party notices
          normally appear. The contents of the NOTICE file are for
          informational purposes only and do not modify the License.
          You may add Your own attribution notices within Derivative
          Works that You distribute, alongside or in addition to the
          NOTICE text from the Work, provided that such additional
          attribution notices cannot be construed as modifying the License.

      You may add Your own copyright statement to Your modifications and
      may provide additional grant of rights to use, reproduce, modify,
      prepare Derivative Works of, publicly display, publicly perform,
      sublicense, and distribute such modifications and such Derivative
      Works.

   5. Submission of Contributions. Unless You explicitly state otherwise,
      any Contribution intentionally submitted for inclusion in the Work
      by You to the Licensor shall be under the terms and conditions of
      this License, without any additional terms or conditions.
      Notwithstanding the above, nothing herein shall supersede or modify
      the terms of any separate license agreement you may have executed
      with Licensor regarding such Contributions.

   6. Trademarks. This License does not grant permission to use the trade
      names, trademarks, service marks, or product names of the Licensor,
      except as required for reasonable and customary use in describing the
      origin of the Work and reproducing the content of the NOTICE file.

   7. Disclaimer of Warranty. Unless required by applicable law or
      agreed to in writing, Licensor provides the Work (and each
      Contributor provides its Contributions) on an "AS IS" BASIS,
      WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
      implied, including, without limitation, any conditions of TITLE,
      MERCHANTIBILITY, SATISFACTORY QUALITY, or FITNESS FOR A PARTICULAR
      PURPOSE. You are solely responsible for determining the
      appropriateness of using or redistributing the Work and assume any
      risks associated with Your exercise of permissions under this License.

   8. Limitation of Liability. In no event and under no legal theory,
      whether in tort (including negligence), contract, or otherwise,
      unless required by applicable law (such as deliberate and grossly
      negligent acts) or agreed to in writing, shall any Contributor be
      liable to You for damages, including any direct, indirect, special,
      incidental, or exemplary damages of any character arising as a
      result of this License or out of the use or inability to use the
      Work (even if such Contributor has been advised of the possibility
      of such damages).

   9. Accepting Warranty or Additional Liability. While redistributing
      the Work or Derivative Works thereof, You may choose to offer,
      and charge a fee for, acceptance of support, warranty, indemnity,
      or other liability obligations and/or rights consistent with this
      License. However, in accepting such obligations, You may offer such
      obligations only on your own behalf and on your sole responsibility,
      not on behalf of any other Contributor, and only if You agree to
      indemnify, defend, and hold each Contributor harmless for any
      liability incurred by, or claims asserted against, such Contributor
      by reason of your accepting any such warranty or additional liability.

   END OF TERMS AND CONDITIONS

   APPENDIX: How to apply the Apache License to your work. [...]
```

*(The code block above is a truncated reference only. `curl` in Step 1 fetches the complete
text including the full APPENDIX section.)*

- [ ] **Step 2: Verify LICENSE contains no MIT text**

Run:
```bash
grep -i "mit\|permission is hereby granted\|software and associated" LICENSE
```

Expected: no output.

- [ ] **Step 3: Create NOTICE file**

Create `NOTICE` with this exact content:
```
claude-devcontainer
Copyright (c) 2026 PKramek
```

- [ ] **Step 4: Update README.md — license section and contributing section**

In `README.md`, the `## License` section currently reads:
```markdown
## License

MIT
```

Change to:
```markdown
## License

Apache 2.0
```

In `README.md`, the `## Contributing` section currently reads:
```markdown
## Contributing

1. Fork the repository
2. Open in a devcontainer (`.devcontainer/devcontainer.json` is provided)
```

The full Contributing section currently ends with:
```markdown
4. Run `pre-commit run --all-files` before committing
5. Open a pull request
```

Change step 2 and add a new step 3 (renumbering the rest):
```markdown
## Contributing

1. Fork the repository
2. Open in a devcontainer (`.devcontainer/devcontainer.json` runs `pre-commit install`
   automatically), **or** run `pre-commit install` manually after cloning
3. Make your changes
4. Run `pre-commit run --all-files` before committing
5. Open a pull request
```

- [ ] **Step 5: Add `license` field to devcontainer-feature.json**

In `src/claude-code/devcontainer-feature.json`, the current lines 14-15 are:
```json
  "documentationURL": "https://github.com/pkramek/claude-devcontainer#readme",
  "licenseURL": "https://github.com/pkramek/claude-devcontainer/blob/main/LICENSE",
```

Change to:
```json
  "documentationURL": "https://github.com/pkramek/claude-devcontainer#readme",
  "license": "Apache-2.0",
  "licenseURL": "https://github.com/pkramek/claude-devcontainer/blob/main/LICENSE",
```

- [ ] **Step 6: Validate JSON is still valid**

Run:
```bash
python3 -m json.tool src/claude-code/devcontainer-feature.json > /dev/null && echo "OK"
```

Expected: `OK`

- [ ] **Step 7: Verify no MIT references remain in tracked source files**

Run:
```bash
grep -ri '\bMIT\b' --include='*.md' --include='*.json' --include='*.yml' --include='*.yaml' --include='*.sh' .
```

Expected: no output (ignore `.git/` which git grep automatically excludes when using `git grep`).
If any results appear, investigate each one — some may be in third-party lock files or
node_modules (acceptable) but any in `src/`, `README.md`, `LICENSE`, or workflows must be fixed.

- [ ] **Step 8: Run pre-commit on changed files to ensure formatting is clean**

This prevents Task 3's `pre-commit run --all-files` from reformatting these files and
contaminating the Task 3 commit.

Run:
```bash
pre-commit run prettier --files README.md
pre-commit run markdownlint --files README.md
pre-commit run check-json --files src/claude-code/devcontainer-feature.json
```

Expected: all exit 0. If prettier reformats README.md, stage the result before committing.

- [ ] **Step 9: Commit**

```bash
git add LICENSE NOTICE README.md src/claude-code/devcontainer-feature.json
git commit --author="PKramek <peterkramek@gmail.com>" \
  -m "chore: change license from MIT to Apache 2.0"
```

---

## Task 3: Pin Pre-commit Hooks to Commit SHAs

**Files:**
- Modify: `.pre-commit-config.yaml`

**Context:** All five hook repos use mutable version tags. A tag can be force-pushed to
point at malicious code. The fix is to replace each `rev:` tag with the immutable commit
SHA it points to. We resolve the current tags — do NOT use `pre-commit autoupdate --freeze`
as that also upgrades versions and could pull in breaking shfmt formatting changes.
We also add `-w` to shfmt args (explicit write-mode documentation) and add `develop` to
`no-commit-to-branch`.

- [ ] **Step 1: Resolve all five current tags to commit SHAs**

**Important:** Use the `^{}` dereferenced SHA (commit SHA), NOT the tag object SHA.
For annotated tags, `git ls-remote` returns two lines: the tag object SHA and the
`^{}` dereferenced commit SHA. Always use the `^{}` line.
For lightweight tags, only one line is returned — use that one.

Use these one-liners to extract only the correct SHA (the `^{}` dereferenced commit SHA,
falling back to the tag SHA if no `^{}` exists):

```bash
# 1. pre-commit-hooks v6.0.0
git ls-remote https://github.com/pre-commit/pre-commit-hooks refs/tags/v6.0.0 refs/tags/v6.0.0^{} \
  | awk '/\^\{\}$/ {print $1; found=1} END {if (!found) print prev} {prev=$1}'

# 2. shellcheck-precommit v0.11.0
git ls-remote https://github.com/koalaman/shellcheck-precommit refs/tags/v0.11.0 refs/tags/v0.11.0^{} \
  | awk '/\^\{\}$/ {print $1; found=1} END {if (!found) print prev} {prev=$1}'

# 3. pre-commit-shfmt v3.13.0-1
git ls-remote https://github.com/scop/pre-commit-shfmt refs/tags/v3.13.0-1 refs/tags/v3.13.0-1^{} \
  | awk '/\^\{\}$/ {print $1; found=1} END {if (!found) print prev} {prev=$1}'

# 4. mirrors-prettier v4.0.0-alpha.8
git ls-remote https://github.com/pre-commit/mirrors-prettier refs/tags/v4.0.0-alpha.8 refs/tags/v4.0.0-alpha.8^{} \
  | awk '/\^\{\}$/ {print $1; found=1} END {if (!found) print prev} {prev=$1}'

# 5. markdownlint-cli v0.48.0
git ls-remote https://github.com/igorshubovych/markdownlint-cli refs/tags/v0.48.0 refs/tags/v0.48.0^{} \
  | awk '/\^\{\}$/ {print $1; found=1} END {if (!found) print prev} {prev=$1}'
```

Each command prints a single 40-character commit SHA. Record all five before proceeding.

- [ ] **Step 2: Update .pre-commit-config.yaml with resolved SHAs and other changes**

**NEVER run `pre-commit autoupdate` in any form.** It upgrades hook versions AND freezes,
which would silently pull in breaking shfmt v4.x formatting changes. All SHA resolution
must be done manually via `git ls-remote` as done in Step 1.

**Note on shfmt `-w`:** Adding `-w` changes the shfmt hook from check-only mode to
auto-fix (write) mode. This is **intentional** — the goal is auto-formatting on commit.
Without `-w`, the hook only reports errors but does not fix them. The CI lint job continues
to run `shfmt -d` in check-only mode as the enforcement layer.

First, save a backup of the current config to verify no hooks are accidentally dropped:
```bash
cp .pre-commit-config.yaml .pre-commit-config.yaml.bak
```

Replace the entire `.pre-commit-config.yaml` with the following, substituting the actual
SHAs resolved in Step 1 for each `<SHA-OF-vX.Y.Z>` placeholder:

```yaml
repos:
  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: <SHA-OF-v6.0.0> # v6.0.0
    hooks:
      - id: check-json
      - id: check-yaml
      - id: trailing-whitespace
      - id: end-of-file-fixer
      - id: check-merge-conflict
      - id: detect-private-key
      - id: check-added-large-files
        args: ["--maxkb=500"]
      - id: no-commit-to-branch
        args: ["--branch", "main", "--branch", "develop"]

  - repo: https://github.com/koalaman/shellcheck-precommit
    rev: <SHA-OF-v0.11.0> # v0.11.0
    hooks:
      - id: shellcheck
        args: ["--severity=warning"]

  - repo: https://github.com/scop/pre-commit-shfmt
    rev: <SHA-OF-v3.13.0-1> # v3.13.0-1
    hooks:
      - id: shfmt
        args: ["-w", "-i", "4", "-ci"]

  - repo: https://github.com/pre-commit/mirrors-prettier
    rev: <SHA-OF-v4.0.0-alpha.8> # v4.0.0-alpha.8
    hooks:
      - id: prettier
        types_or: [json, yaml, markdown]

  - repo: https://github.com/igorshubovych/markdownlint-cli
    rev: <SHA-OF-v0.48.0> # v0.48.0
    hooks:
      - id: markdownlint
        args: ["--fix"]
```

- [ ] **Step 3: Verify all rev values are 40-character SHAs**

Run:
```bash
grep '^\s*rev:' .pre-commit-config.yaml
```

Expected: every line shows a 40-character hex string, not a version tag. Example:
```
    rev: cef0300de252776ee95f6c2c833b3c4dc39974e3 # v6.0.0
```

If any line still shows a version tag (e.g., `v6.0.0`), go back and fix it.

- [ ] **Step 3b: Verify no hooks were accidentally dropped**

Run a structural diff to ensure only `rev:` lines and the two intentional content changes
(shfmt `-w` added, `no-commit-to-branch` `develop` added) differ:

```bash
diff .pre-commit-config.yaml.bak .pre-commit-config.yaml
```

Expected diff should show:
- 5 `rev:` changes (tags → SHAs)
- 1 `args` change in the `shfmt` hook (adding `-w`)
- 1 `args` change in `no-commit-to-branch` (adding `"--branch", "develop"`)

Any other changes (removed hooks, changed hook IDs, altered args) are unintended. Fix them
before continuing. Clean up the backup after verification:
```bash
rm .pre-commit-config.yaml.bak
```

- [ ] **Step 4: Run pre-commit on all files to verify no formatting regressions**

Run:
```bash
pre-commit run --all-files
```

Expected: all hooks pass (exit 0). If any hook modifies files, it means formatting was
not clean. Stage the changes and re-run until clean. If shfmt rewrites files significantly,
stop — this indicates a version change was introduced. Re-check Step 1 SHA resolution.

- [ ] **Step 5: Verify no-commit-to-branch now protects develop**

Run:
```bash
grep -A2 'no-commit-to-branch' .pre-commit-config.yaml
```

Expected:
```yaml
      - id: no-commit-to-branch
        args: ["--branch", "main", "--branch", "develop"]
```

- [ ] **Step 6: Commit**

```bash
git add .pre-commit-config.yaml
git commit --author="PKramek <peterkramek@gmail.com>" \
  -m "chore: pin pre-commit hooks to commit SHAs, add develop branch protection"
```

---

## Task 4: Fix CI False Positives in test.yml

**Files:**
- Modify: `.github/workflows/test.yml` — three `run:` blocks

**Context:** `devcontainer features test` (CLI v0.85.0) exits 0 even when the feature
install fails inside Docker. The test job steps are reporting success despite the feature
failing to install. The fix greps the captured log output for known failure strings and
exits 1 if any are found. This is a heuristic workaround — comment it clearly so future
maintainers know to revisit it when upgrading the CLI.

Note: Each of the three jobs uses a different log file path:
- `test-scenarios` → `/tmp/scenario-test-output.log`
- `test-image-matrix` → `/tmp/test-output.log`
- `test-arm64` → `/tmp/test-output.log`

- [ ] **Step 1: Fix the test-scenarios job run block**

In `.github/workflows/test.yml`, find the `test-scenarios` job run step (currently line 88):
```yaml
      - name: Run all scenarios
        run: devcontainer features test --project-folder . 2>&1 | tee /tmp/scenario-test-output.log
```

Change to:
```yaml
      - name: Run all scenarios
        run: |
          devcontainer features test --project-folder . 2>&1 | tee /tmp/scenario-test-output.log
          # Workaround: devcontainers/cli@0.85.0 exits 0 even when feature install fails.
          # Grep for known failure strings and fail explicitly. Revisit on CLI upgrade.
          if grep -qE "Exit code [1-9][0-9]*|failed to install|Failed to launch" /tmp/scenario-test-output.log; then
            echo "ERROR: Test output contains failures."
            exit 1
          fi
```

- [ ] **Step 2: Fix the test-image-matrix job run block**

Find the `test-image-matrix` job run step (currently lines 150-155):
```yaml
      - name: Test on ${{ matrix.image }}
        run: |
          devcontainer features test \
            --features claude-code \
            --skip-scenarios \
            --base-image "${{ matrix.image }}" \
            --project-folder . 2>&1 | tee /tmp/test-output.log
```

Change to:
```yaml
      - name: Test on ${{ matrix.image }}
        run: |
          devcontainer features test \
            --features claude-code \
            --skip-scenarios \
            --base-image "${{ matrix.image }}" \
            --project-folder . 2>&1 | tee /tmp/test-output.log
          # Workaround: devcontainers/cli@0.85.0 exits 0 even when feature install fails.
          # Grep for known failure strings and fail explicitly. Revisit on CLI upgrade.
          if grep -qE "Exit code [1-9][0-9]*|failed to install|Failed to launch" /tmp/test-output.log; then
            echo "ERROR: Test output contains failures."
            exit 1
          fi
```

- [ ] **Step 3: Fix the test-arm64 job run block**

Find the `test-arm64` job run step (currently lines 191-196):
```yaml
      - name: Test on ${{ matrix.image }} (arm64)
        run: |
          devcontainer features test \
            --features claude-code \
            --skip-scenarios \
            --base-image "${{ matrix.image }}" \
            --project-folder . 2>&1 | tee /tmp/test-output.log
```

Change to:
```yaml
      - name: Test on ${{ matrix.image }} (arm64)
        run: |
          devcontainer features test \
            --features claude-code \
            --skip-scenarios \
            --base-image "${{ matrix.image }}" \
            --project-folder . 2>&1 | tee /tmp/test-output.log
          # Workaround: devcontainers/cli@0.85.0 exits 0 even when feature install fails.
          # Grep for known failure strings and fail explicitly. Revisit on CLI upgrade.
          if grep -qE "Exit code [1-9][0-9]*|failed to install|Failed to launch" /tmp/test-output.log; then
            echo "ERROR: Test output contains failures."
            exit 1
          fi
```

- [ ] **Step 4: Validate YAML is still valid**

Run:
```bash
python3 -c "import yaml; yaml.safe_load(open('.github/workflows/test.yml'))" && echo "OK"
```

Expected: `OK`

- [ ] **Step 5: Verify all three jobs have the grep check and correct log paths**

Run:
```bash
grep -n "grep -qE\|scenario-test-output\|test-output" .github/workflows/test.yml
```

Expected output (line numbers will vary):
```
88:          if grep -qE "Exit code [1-9][0-9]*|failed to install|Failed to launch" /tmp/scenario-test-output.log; then
151:          if grep -qE "Exit code [1-9][0-9]*|failed to install|Failed to launch" /tmp/test-output.log; then
196:          if grep -qE "Exit code [1-9][0-9]*|failed to install|Failed to launch" /tmp/test-output.log; then
```

Verify: `test-scenarios` uses `scenario-test-output.log`, the other two use `test-output.log`.

- [ ] **Step 6: Run pre-commit on test.yml before committing**

Task 3's `pre-commit run --all-files` did not cover test.yml (it ran before this task).
Run prettier and yaml checks now to ensure the CI file is clean:

```bash
pre-commit run prettier --files .github/workflows/test.yml
pre-commit run check-yaml --files .github/workflows/test.yml
```

Expected: both exit 0. If prettier reformats the file, stage the result before committing.

- [ ] **Step 7: Commit**

```bash
git add .github/workflows/test.yml
git commit --author="PKramek <peterkramek@gmail.com>" \
  -m "ci: detect feature install failures in test output (workaround cli exit-code bug)"
```
