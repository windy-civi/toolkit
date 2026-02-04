# Pipeline Manager Scripts

Utility scripts for managing state repository metadata and workflows.

## Quick Reference for Future Updates

### Update Repository Metadata

When repos need description or topic updates:

```bash
# Test first on a few states
./update-repo-metadata.sh --test-states wy,ct,tx

# Then update all
./update-repo-metadata.sh --all-states
```

### Update Workflows to Main Branch

When workflows are pointing to feature branches instead of main:

```bash
# Test first
./update-workflows-to-main.sh --test-states wy,ct,tx

# Then update all
./update-workflows-to-main.sh
```

---

## Scripts

### `update-repo-metadata.sh`

Updates repository metadata (description and topics) for state repos.

**What it does:**

- Updates repository description to: `🏛️ {State Name} Legislation`
- Adds 'working' topic if no topics exist (preserves existing topics)

**Usage:**

```bash
./update-repo-metadata.sh [--test-states state1,state2,...] [--all-states]
```

**When to use:**

- New states added that need descriptions/topics
- Repos that got out of sync
- Bulk updates after changes to naming conventions

**Notes:**

- Only adds 'working' topic if repo has NO topics
- Preserves all existing topics (won't override `action-disabled`, etc.)
- Idempotent - safe to run multiple times

---

### `update-workflows-to-main.sh`

Updates workflow files to point to `@main` instead of feature branches.

**What it does:**

- Finds workflow files in each repo
- Updates action references from feature branches (e.g., `@feature/scrape-summary-with-errors`) to `@main`
- Commits and pushes changes

**Usage:**

```bash
./update-workflows-to-main.sh [--test-states state1,state2,...]
```

**When to use:**

- After merging feature branches to main
- When repos are still pointing to old feature branches
- Bulk updates to ensure consistency

**Notes:**

- Clones repos temporarily (cleans up automatically)
- Only updates if non-main branches are found
- Creates commits with clear messages

---

## Requirements

- GitHub CLI (`gh`) installed and authenticated: `gh auth login`
- Python 3 with PyYAML
- Bash 3.2+ (macOS compatible)

## Other Scripts in This Directory

- `update-existing-state-pipelines.sh` - Update state codes in workflows
- `update-extract-workflows-to-main.sh` - Update extract workflows to main
- `update-extraction-summary-step.sh` - Update extraction summary display
- `sync-extract-workflows-from-template.sh` - Sync extract workflows from templates
- `update-schedule-all-repos.sh` - Update workflow schedules
- `bulk-create-state-pipelines.sh` - Create new state repos
- `add-pat-secret-to-repos.sh` - Add PAT secrets to repos
