# GitHub Actions Testing Framework

This directory contains a comprehensive testing framework for the GitHub Actions in this repository.

## Overview

The testing framework includes:

1. **GitHub Actions Test Workflow** - Automated tests that run on push/PR
2. **Shell Script Unit Tests** - Tests for individual shell scripts
3. **Test Fixtures** - Mock data and sample files for testing
4. **Local Test Runner** - Script to run tests locally before pushing

## Quick Start

### Running Tests Locally

To run all tests locally:

```bash
./testing/run_tests.sh
```

To run just the shell script tests:

```bash
./testing/test_shell_scripts.sh
```

### Running Tests in GitHub Actions

Tests automatically run on:
- Push to `main` branch
- Push to any `claude/**` branch
- Pull requests that modify actions or tests
- Manual trigger via workflow dispatch

To manually trigger tests:
1. Go to the Actions tab in GitHub
2. Select "Test GitHub Actions" workflow
3. Click "Run workflow"

## Test Structure

### 1. GitHub Actions Test Workflow

Location: `.github/workflows/test-actions.yml`

This workflow includes the following test jobs:

- **test-sources-action**: Tests the sources action (cloning repositories)
- **test-recent-items-action**: Tests the recent-items action with mock data
- **test-shell-tools**: Unit tests for individual shell scripts
- **test-full-pipeline**: Integration test of the complete pipeline
- **test-multiple-sources**: Tests cloning multiple repositories
- **test-summary**: Aggregates results and provides a summary

### 2. Shell Script Unit Tests

Location: `testing/test_shell_scripts.sh`

Tests all shell scripts in `actions/recent-items/tools/`:

- `find_logs_json.sh` - Tests finding JSON files in logs directories
- `filter_recent_logs.sh` - Tests filtering by timestamp
- `sort_logs_by_timestamp.sh` - Tests sorting by timestamp
- `limit_output.sh` - Tests limiting output to N items
- `extract_name.sh` - Tests extracting bill information from JSON
- Full pipeline integration test

### 3. Test Fixtures

Location: `testing/fixtures/`

Mock data and sample files:

- `sample_usa_pipeline_structure.json` - Documents expected directory structure
- `sample_bill_recent.json` - Sample recent bill for testing
- `sample_bill_old.json` - Sample old bill for testing filters

Location: `testing/raw_scraper_samples/`

Real bill samples from OpenStates scraper for integration testing.

## Test Coverage

### Actions Tested

| Action | Unit Tests | Integration Tests | Notes |
|--------|-----------|-------------------|-------|
| sources | ✓ | ✓ | Tests cloning single and multiple repos |
| recent-items | ✓ | ✓ | Tests with mock data |
| scrape | - | - | Requires Docker, tested manually |
| extract | - | - | Requires Python environment |
| format | - | - | Requires Python environment |

### Shell Scripts Tested

| Script | Test Coverage |
|--------|---------------|
| find_logs_json.sh | ✓ Full |
| filter_recent_logs.sh | ✓ Full |
| sort_logs_by_timestamp.sh | ✓ Full |
| limit_output.sh | ✓ Full |
| extract_name.sh | ✓ Full |

## Writing New Tests

### Adding Shell Script Tests

1. Add test function to `testing/test_shell_scripts.sh`:

```bash
test_my_new_feature() {
    echo ""
    echo "Testing my_new_feature.sh"
    echo "-------------------------"

    # Your test here
    OUTPUT=$("$TOOLS_DIR/my_new_feature.sh" "$TEST_DIR")

    if [ condition ]; then
        pass "Test description"
    else
        fail "Test description" "Error message"
    fi
}
```

2. Call your test function in the main section:

```bash
# Run all tests
setup_test_data
test_my_new_feature
# ... other tests
```

### Adding GitHub Actions Tests

1. Add a new job to `.github/workflows/test-actions.yml`:

```yaml
test-my-action:
  runs-on: ubuntu-latest
  name: Test My Action
  steps:
    - name: Checkout
      uses: actions/checkout@v4

    - name: Test My Action
      uses: ./actions/my-action
      with:
        input: "test-value"

    - name: Verify Output
      run: |
        # Verification logic
        echo "✅ Test passed"
```

2. Add the job to the `test-summary` needs list:

```yaml
test-summary:
  needs: [test-sources-action, test-recent-items-action, test-my-action]
```

## Continuous Integration

### What Gets Tested

The test workflow runs automatically when:
- Any file in `actions/` is modified
- Any file in `testing/` is modified
- The test workflow file itself is modified

### Test Results

Test results are available in:
- GitHub Actions tab (workflow runs)
- Pull request checks
- GitHub Actions summary (detailed tables)

## Mock Data Guidelines

### Creating Test Data

When creating mock data for tests:

1. Use realistic data structures matching OpenStates schema
2. Include various edge cases (recent/old, with/without fields)
3. Place in `testing/fixtures/` for reusable fixtures
4. Use timestamps that will age well (relative dates like "1 day ago")

### Using Existing Samples

The `testing/raw_scraper_samples/` directory contains real bill samples. Use these for:
- Integration testing
- Validating against real data structures
- Testing edge cases found in production

## Troubleshooting

### Tests Fail Locally But Pass in CI

- Check for differences in environment (paths, permissions)
- Ensure all test scripts are executable (`chmod +x`)
- Verify you're using the same shell (bash)

### Tests Pass Locally But Fail in CI

- Check for absolute vs relative paths
- Verify all dependencies are installed in CI
- Check for environment-specific issues (temp directories, etc.)

### Shell Script Tests Fail

- Check that tools are executable
- Verify test data is being created correctly
- Look for path issues in temp directory
- Check for differences in date command behavior

## Future Improvements

Potential areas for expansion:

- [ ] Python unit tests for formatter and extractor
- [ ] Docker-based tests for scrape action
- [ ] Performance benchmarks
- [ ] End-to-end tests with real repositories
- [ ] Automated integration tests with data pipelines
- [ ] Code coverage reporting

## Contributing

When adding new actions or modifying existing ones:

1. Write tests first (TDD approach)
2. Run tests locally before pushing
3. Ensure all tests pass in CI
4. Update this README with new test coverage
5. Add test fixtures as needed

## Resources

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Composite Actions](https://docs.github.com/en/actions/creating-actions/creating-a-composite-action)
- [Testing Actions](https://docs.github.com/en/actions/creating-actions/testing-actions)
