# Repo Rename + Branch Setup Design

**Goal:** Rename the repository from `claude-code-devcontainer` to `claude-devcontainer`, push the existing implementation to GitHub, and establish a PR-based GitHub Flow branching strategy with protected `main` and `develop` branches.

**Date:** 2026-04-01

---

## Branch Strategy

GitHub Flow with `develop` as the integration branch:

```
main          ← protected, tagged releases only (v1.0.0, v1.1.0, ...)
  └── develop ← protected, all feature PRs land here
        └── feat/<name> ← short-lived feature branches
```

- All new work: feature branch → PR → `develop`
- Releases: `develop` → PR → `main` → git tag → CI publishes to GHCR
- No direct pushes to `main` or `develop`

---

## Rename Changes

8 occurrences of `claude-code-devcontainer` across 3 files, updated to `claude-devcontainer`:

| File | Change |
|---|---|
| `README.md` | Badge URL + 3× GHCR feature references |
| `src/claude-code/README.md` | 3× GHCR feature references |
| `src/claude-code/devcontainer-feature.json` | `documentationURL` + `licenseURL` |

GHCR reference after rename: `ghcr.io/pkramek/claude-devcontainer/claude-code:1`

Single commit: `chore: rename repo to claude-devcontainer`

---

## Execution Order

1. Apply rename commit on current local branch
2. Rename local branch to `feat/initial-implementation`
3. Add remote: `git@github.com:PKramek/claude-devcontainer.git`
4. Create `main` as an empty orphan branch and push it
5. Create `develop` from `main` and push it
6. Push `feat/initial-implementation` to remote
7. Apply branch protection rulesets (via `gh api`)
8. Open PR: `feat/initial-implementation` → `develop`

---

## Branch Protection Rulesets

Applied via GitHub Repository Rules API (`gh api`). Both rules use enforcement `active`.

### `protect-develop` ruleset

Targets: `refs/heads/develop`

| Rule | Value |
|---|---|
| deletion | blocked |
| non_fast_forward (force push) | blocked |
| required_approving_review_count | 0 |
| dismiss_stale_reviews_on_push | true |
| required_review_thread_resolution | true |
| allowed_merge_methods | `squash` only |
| required_status_checks | `lint` (GitHub Actions, integration_id: 15368) |
| do_not_enforce_on_create | false |
| strict_required_status_checks_policy | false |

### `protect-main` ruleset

Targets: `refs/heads/main`

| Rule | Value |
|---|---|
| deletion | blocked |
| non_fast_forward (force push) | blocked |
| required_approving_review_count | 0 (solo project) |
| dismiss_stale_reviews_on_push | true |
| required_review_thread_resolution | true |
| allowed_merge_methods | `merge` only (preserves squashed history from develop) |
| required_status_checks | `lint` (GitHub Actions, integration_id: 15368) |
| do_not_enforce_on_create | false |
| strict_required_status_checks_policy | false |

No bypass actors (personal repo, owner can merge their own PRs with 0 required reviews).

---

## Protection Rule Payloads

### develop

```json
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
```

### main

```json
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
```

---

## PR Description (Initial Implementation)

Title: `feat: initial Claude Code DevContainer Feature implementation`

Body:
- Universal DevContainer Feature installing Claude Code CLI into any container
- Supports Debian, Ubuntu, Alpine, Arch, Fedora, RHEL, Rocky, Alma, Amazon Linux
- amd64 + arm64 via SHA256-verified Node.js binary tarballs
- Shell completions (bash/zsh/fish), MCP config, mount docs, cache cleanup
- 10 test scenarios + 27-image amd64 CI matrix + 4-image arm64 matrix
- Pre-commit hooks (ShellCheck, shfmt, Prettier, markdownlint)

---

## Files to Delete After Setup

The example protection JSON files are reference material and must not ship in the repo:
- `protect-develop (2).json`
- `protect-master (2).json`
