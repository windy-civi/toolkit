# Test Scraper Action

This action allows you to test changes to the OpenStates scrapers before submitting them upstream.

## How It Works

1. **Builds** a Docker image from your fork/branch of `openstates-scrapers`
2. **Runs** the scraper using the regular `scrape` action
3. **Reports** results without committing data

## Usage

```yaml
- uses: windy-civi/toolkit/actions/test-scraper@main
  with:
    scraper-fork: YOUR_USERNAME
    scraper-branch: fix/mo-empty-title
    state: mo
    github-token: ${{ secrets.GITHUB_TOKEN }}
```

## Inputs

| Input | Required | Description |
|-------|----------|-------------|
| `scraper-fork` | Yes | GitHub user/org with openstates-scrapers fork |
| `scraper-branch` | Yes | Branch name to test |
| `state` | Yes | State abbreviation (e.g., mo, ca, tx) |
| `github-token` | No | GitHub token (defaults to workflow token) |
| `force-update` | No | Force update even if data exists (default: false) |

## Workflow

This action is used by the `openstates-scrape-test` template to create test repositories for each state.

## Benefits

- ✅ **Zero duplication** - Reuses all scrape action logic
- ✅ **Safe testing** - No commits, no side effects
- ✅ **Real environment** - Tests in actual GitHub Actions
- ✅ **Quick feedback** - See results before submitting PRs

## Example Workflow

See `templates/openstates-scrape-test` for a complete workflow template.

