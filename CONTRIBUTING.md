# Contributing

## Development setup

1. Fork and clone
2. Install the git hooks (one-time setup):

   ```bash
   pip install pre-commit
   pre-commit install           # runs on git commit
   pre-commit install --hook-type pre-push  # runs on git push
   ```

   If you open the repo in the devcontainer, this runs automatically.

3. Changes live in `src/claude-code/install.sh` and `test/claude-code/`
4. Open a pull request against `develop`

## Branching model

| Branch pattern | Purpose                   | PR target |
| -------------- | ------------------------- | --------- |
| `feat/*`       | New features              | `develop` |
| `fix/*`        | Bug fixes                 | `develop` |
| `hotfix/*`     | Critical production fixes | `main`    |

- All feature and fix PRs target `develop`. Use squash merges to keep history clean.
- `hotfix/*` branches are the only branches (besides `develop`) allowed to open PRs
  directly to `main`. This is enforced by CI (`source-branch-check.yml`).
- Direct commits to `main` and `develop` are blocked by pre-commit hooks and branch
  protection rules.

## Pre-commit hooks

The following checks run automatically on every `git commit` and `git push`:

| Hook                  | What it checks                                |
| --------------------- | --------------------------------------------- |
| `shellcheck`          | Shell script correctness (warnings and above) |
| `shfmt`               | Shell script formatting (`-i 4 -ci`)          |
| `prettier`            | JSON, YAML, and Markdown formatting           |
| `markdownlint`        | Markdown style rules                          |
| `check-json`          | JSON syntax validity                          |
| `check-yaml`          | YAML syntax validity                          |
| `trailing-whitespace` | No trailing whitespace                        |
| `detect-private-key`  | No accidentally committed secrets             |
| `no-commit-to-branch` | Blocks direct commits to `main` and `develop` |

**Running manually:**

```bash
pre-commit run --all-files        # check everything
pre-commit run prettier           # check one hook
pre-commit run --files src/claude-code/install.sh  # check one file
```

**If a hook fails:** fix the flagged issue and `git add` the changes before retrying.
Prettier and shfmt auto-fix in place — just stage the result. ShellCheck and markdownlint
report what to fix but won't rewrite your code.

## Maintainers

### Advancing main

When `develop` is ready for release, use the **Advance main** workflow:

1. Go to **Actions** → **Advance main** → **Run workflow**
2. The workflow fast-forwards `main` to the current tip of `develop` via the GitHub API
   (no merge commit is created)
3. It verifies that `main` and `develop` point to the same SHA before completing

### Releasing a version

1. Update the `version` field in `src/claude-code/devcontainer-feature.json` as part of
   the work merged to `develop` — this must be done **before** tagging, as the release
   workflow validates that the tag version matches the JSON
2. Advance `main` using the workflow above
3. Tag the release from the updated `main`:

   ```bash
   git checkout main
   git pull origin main
   git tag v<VERSION>
   git push origin v<VERSION>
   ```

4. The `v*` tag push triggers the **Release** workflow, which:
   - Runs ShellCheck validation
   - Smoke-tests against 3 representative base images
   - Verifies the tag version matches `devcontainer-feature.json`
   - Publishes the feature to `ghcr.io/pkramek/claude-devcontainer/claude-code`
   - Verifies the published feature is accessible

Tags are protected — no deletion or force-push.

### Hotfix workflow

For critical fixes that cannot wait for the normal `develop` cycle:

1. Create a `hotfix/*` branch from `main`
2. Make the fix and open a PR targeting `main` — the source-branch-check CI allows
   `hotfix/*` to bypass the `develop`-only gate
3. After the hotfix merges to `main`, tag and release as described above
4. Open a second PR from `hotfix/*` (or from `main`) to `develop` to keep the branches
   in sync

### First release: GHCR visibility

After the first tag push, the GHCR package is created as **private**. To make it public:

1. Go to the repository's **Packages** tab
2. Click the `claude-code` package → **Package settings**
3. Under **Danger Zone**, change visibility to **Public**
