# Repo Rename + Branch Setup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rename all repo references from `claude-code-devcontainer` to `claude-devcontainer`, set up `main`/`develop`/`feat/initial-implementation` branches on GitHub with protection rulesets, and open the initial PR.

**Architecture:** Single local `main` branch (20 commits) becomes `feat/initial-implementation`. A new orphan `main` and a `develop` branched from it are pushed as empty baseline branches. The PR is opened first so CI runs and reveals the exact status check context name; branch protection rulesets are applied after that is confirmed. The initial PR squash-merges all implementation work into `develop`.

**Tech Stack:** Bash, git, gh CLI, GitHub Rulesets API

**Git author for all commits:** `PKramek <peterkramek@gmail.com>`

**CRITICAL:** No Co-Authored-By, no AI attribution in any commit message.

---

## File Map

| File                                        | Change                                                                           |
| ------------------------------------------- | -------------------------------------------------------------------------------- |
| `README.md`                                 | 10 occurrences: badge image URL + badge link URL + 3× GHCR feature ref (5 total) |
| `src/claude-code/README.md`                 | 3× GHCR feature ref                                                              |
| `src/claude-code/devcontainer-feature.json` | `documentationURL` + `licenseURL` (2 total)                                      |
| `.github/workflows/test.yml`                | Add `develop` to `push.branches` trigger                                         |

---

## Task 1: Update Workflow Push Trigger

**Files:**

- Modify: `.github/workflows/test.yml`

The workflow currently only triggers on push to `main`. `develop` is the integration branch — CI must run on it too.

- [ ] **Step 1: Add `develop` to the push trigger**

Edit `.github/workflows/test.yml`. Change:

```yaml
on:
  pull_request:
  push:
    branches: [main]
```

To:

```yaml
on:
  pull_request:
  push:
    branches: [main, develop]
```

- [ ] **Step 2: Validate YAML**

```bash
python3 -c "import yaml; yaml.safe_load(open('.github/workflows/test.yml'))" && echo "OK"
```

Expected: `OK`

- [ ] **Step 3: Commit**

```bash
git add .github/workflows/test.yml
git commit --author="PKramek <peterkramek@gmail.com>" -m "ci: trigger CI on develop branch push"
```

---

## Task 2: Apply Rename Commit

**Files:**

- Modify: `README.md`
- Modify: `src/claude-code/README.md`
- Modify: `src/claude-code/devcontainer-feature.json`

- [ ] **Step 1: Replace all occurrences in README.md**

```bash
sed -i '' 's|claude-code-devcontainer|claude-devcontainer|g' README.md
```

Verify:

```bash
grep -c "claude-code-devcontainer" README.md
```

Expected: `0`

- [ ] **Step 2: Replace all occurrences in src/claude-code/README.md**

```bash
sed -i '' 's|claude-code-devcontainer|claude-devcontainer|g' src/claude-code/README.md
```

Verify:

```bash
grep -c "claude-code-devcontainer" src/claude-code/README.md
```

Expected: `0`

- [ ] **Step 3: Replace all occurrences in devcontainer-feature.json**

```bash
sed -i '' 's|claude-code-devcontainer|claude-devcontainer|g' src/claude-code/devcontainer-feature.json
```

Verify:

```bash
grep -c "claude-code-devcontainer" src/claude-code/devcontainer-feature.json
```

Expected: `0`

- [ ] **Step 4: Confirm zero remaining occurrences across the whole repo**

```bash
grep -r "claude-code-devcontainer" src/ README.md .github/ --include="*.json" --include="*.md" --include="*.yml"
```

Expected: no output

- [ ] **Step 5: Validate JSON is still valid**

```bash
python3 -m json.tool src/claude-code/devcontainer-feature.json > /dev/null && echo "OK"
```

Expected: `OK`

- [ ] **Step 6: Commit**

```bash
git add README.md src/claude-code/README.md src/claude-code/devcontainer-feature.json
git commit --author="PKramek <peterkramek@gmail.com>" -m "chore: rename repo to claude-devcontainer"
```

---

## Task 3: Set Up Local Branch Structure

No files modified. Pure git branch operations.

- [ ] **Step 1: Rename current local `main` to `feat/initial-implementation`**

```bash
git branch -m main feat/initial-implementation
```

Verify:

```bash
git branch
```

Expected: `* feat/initial-implementation`

- [ ] **Step 2: Create orphan `main` with a single empty init commit**

`git checkout --orphan` stages all files from the previous branch. `git rm -r --cached .` clears the index without touching the working directory. The working tree will have untracked files until Step 4 restores the feature branch.

```bash
git checkout --orphan main
git rm -r --cached . --quiet
git commit --allow-empty --author="PKramek <peterkramek@gmail.com>" -m "chore: initialize repository"
```

Verify:

```bash
git log --oneline
```

Expected: exactly 1 commit — `chore: initialize repository`

- [ ] **Step 3: Create `develop` branched from `main`**

```bash
git checkout -b develop
```

Verify:

```bash
git log --oneline
```

Expected: same single `chore: initialize repository` commit

- [ ] **Step 4: Return to feature branch**

```bash
git checkout feat/initial-implementation
```

Verify:

```bash
git log --oneline | wc -l
```

Expected: `22` (20 original + 1 workflow commit + 1 rename commit)

---

## Task 4: Connect Remote and Push All Branches

- [ ] **Step 1: Add the remote**

```bash
git remote add origin git@github.com:PKramek/claude-devcontainer.git
```

Verify:

```bash
git remote -v
```

Expected:

```
origin  git@github.com:PKramek/claude-devcontainer.git (fetch)
origin  git@github.com:PKramek/claude-devcontainer.git (push)
```

- [ ] **Step 2: Push `main` with tracking**

```bash
git push -u origin main
```

Expected: `Branch 'main' set up to track remote branch 'main' from 'origin'.`

- [ ] **Step 3: Push `develop` with tracking**

```bash
git push -u origin develop
```

Expected: `Branch 'develop' set up to track remote branch 'develop' from 'origin'.`

- [ ] **Step 4: Push `feat/initial-implementation` with tracking**

```bash
git push -u origin feat/initial-implementation
```

Expected: `Branch 'feat/initial-implementation' set up to track remote branch 'feat/initial-implementation' from 'origin'.`

- [ ] **Step 5: Set `develop` as the default branch**

```bash
gh api repos/PKramek/claude-devcontainer \
  --method PATCH \
  --field default_branch=develop \
  --jq '.default_branch'
```

Expected: `develop`

---

## Task 5: Open the Initial PR

Open the PR before applying protection rulesets. This triggers CI and reveals the exact status check context name needed for the rulesets.

- [ ] **Step 1: Open PR from `feat/initial-implementation` → `develop`**

```bash
gh pr create \
  --repo PKramek/claude-devcontainer \
  --base develop \
  --head feat/initial-implementation \
  --title "feat: initial Claude Code DevContainer Feature implementation" \
  --body "$(cat <<'EOF'
## Summary

- Universal DevContainer Feature that installs Claude Code CLI into any container
- Supports Debian, Ubuntu, Alpine, Arch, Fedora, RHEL, Rocky, Alma, Amazon Linux on amd64 + arm64
- SHA256-verified Node.js binary install; distro packages for Alpine/Arch
- Shell completions (bash/zsh/fish), MCP config, mount docs, per-distro cache cleanup
- 10 test scenarios + 27-image amd64 CI matrix + 4-image arm64 matrix
- Pre-commit hooks: ShellCheck, shfmt, Prettier, markdownlint

## Test plan

- [ ] CI lint job passes on this PR
- [ ] `src/claude-code/devcontainer-feature.json` references `claude-devcontainer` (not `claude-code-devcontainer`)
- [ ] `README.md` badge and GHCR refs use `claude-devcontainer`
EOF
)"
```

Expected: PR URL printed, e.g. `https://github.com/PKramek/claude-devcontainer/pull/1`

- [ ] **Step 2: Verify PR opened against correct base**

```bash
gh pr view 1 --repo PKramek/claude-devcontainer --json baseRefName,headRefName,title \
  --jq '{base: .baseRefName, head: .headRefName, title: .title}'
```

Expected:

```json
{
  "base": "develop",
  "head": "feat/initial-implementation",
  "title": "feat: initial Claude Code DevContainer Feature implementation"
}
```

- [ ] **Step 3: Wait for CI to complete, then verify the exact check context name**

Wait ~5 minutes for the lint job to run, then:

```bash
gh api repos/PKramek/claude-devcontainer/commits/$(git rev-parse feat/initial-implementation)/check-runs \
  --jq '.check_runs[].name'
```

Note the exact name reported for the lint job. It will be either `lint` or `Test / lint`. Use this value in Task 6 for the `"context"` field.

---

## Task 6: Apply Branch Protection Rulesets

Uses the GitHub Rulesets API (`POST /repos/{owner}/{repo}/rulesets`). Replace `"context": "lint"` with the exact value confirmed in Task 5 Step 3 if different.

- [ ] **Step 1: Apply `protect-develop` ruleset**

```bash
gh api repos/PKramek/claude-devcontainer/rulesets \
  --method POST \
  --header "Content-Type: application/json" \
  --input - << 'EOF'
{
  "name": "protect-develop",
  "target": "branch",
  "enforcement": "active",
  "conditions": {
    "ref_name": {
      "exclude": [],
      "include": ["refs/heads/develop"]
    }
  },
  "rules": [
    { "type": "deletion" },
    { "type": "non_fast_forward" },
    {
      "type": "pull_request",
      "parameters": {
        "required_approving_review_count": 0,
        "dismiss_stale_reviews_on_push": true,
        "required_reviewers": [],
        "require_code_owner_review": false,
        "require_last_push_approval": false,
        "required_review_thread_resolution": true,
        "allowed_merge_methods": ["squash"]
      }
    },
    {
      "type": "required_status_checks",
      "parameters": {
        "strict_required_status_checks_policy": false,
        "do_not_enforce_on_create": false,
        "required_status_checks": [
          { "context": "lint", "integration_id": 15368 }
        ]
      }
    }
  ]
}
EOF
```

Verify the response contains `"name": "protect-develop"` and `"enforcement": "active"`.

- [ ] **Step 2: Apply `protect-main` ruleset**

```bash
gh api repos/PKramek/claude-devcontainer/rulesets \
  --method POST \
  --header "Content-Type: application/json" \
  --input - << 'EOF'
{
  "name": "protect-main",
  "target": "branch",
  "enforcement": "active",
  "conditions": {
    "ref_name": {
      "exclude": [],
      "include": ["refs/heads/main"]
    }
  },
  "rules": [
    { "type": "deletion" },
    { "type": "non_fast_forward" },
    {
      "type": "pull_request",
      "parameters": {
        "required_approving_review_count": 0,
        "dismiss_stale_reviews_on_push": true,
        "required_reviewers": [],
        "require_code_owner_review": false,
        "require_last_push_approval": false,
        "required_review_thread_resolution": true,
        "allowed_merge_methods": ["merge"]
      }
    },
    {
      "type": "required_status_checks",
      "parameters": {
        "strict_required_status_checks_policy": false,
        "do_not_enforce_on_create": false,
        "required_status_checks": [
          { "context": "lint", "integration_id": 15368 }
        ]
      }
    }
  ]
}
EOF
```

Verify the response contains `"name": "protect-main"` and `"enforcement": "active"`.

- [ ] **Step 3: Confirm both rulesets are active**

```bash
gh api repos/PKramek/claude-devcontainer/rulesets --jq '.[].name'
```

Expected:

```
protect-develop
protect-main
```

---

## Task 7: Cleanup

- [ ] **Step 1: Delete the example protection JSON files from disk**

These were reference material and are now gitignored. Delete them:

```bash
rm "protect-develop (2).json" "protect-master (2).json"
```

Verify:

```bash
ls protect-*.json 2>/dev/null || echo "clean"
```

Expected: `clean`
