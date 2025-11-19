# Snapshot Testing Guide

A centralized framework for testing GitHub Actions with file snapshot comparison.

## Overview

This repository uses **snapshot testing** to verify that actions produce the expected output files given specific input files. The framework makes it easy to:

- Test actions by comparing actual output with saved snapshots
- Update snapshots when output changes are intentional
- Catch unintended changes in action output
- Clean up orphaned test files automatically

## Quick Start

### 1. Add Snapshot Tests to Your Action

Copy the template to your action directory:

```bash
cp scripts/snapshot-test-template.sh actions/<your-action>/test.sh
chmod +x actions/<your-action>/test.sh
```

### 2. Customize the Test Script

Edit `actions/<your-action>/test.sh` and update:

1. **Paths**: Set the correct paths for test cases and your action script
2. **Test processor**: Implement how to run your action with test inputs
3. **File patterns**: Update input/output file extensions

Example customization:

```bash
# In test.sh
TEST_CASES_DIR="$SCRIPT_DIR/test-cases"
SNAPSHOTS_DIR="$TEST_CASES_DIR/__snapshots__"
ACTION_SCRIPT="$SCRIPT_DIR/publish.py"

process_test_case() {
    local input_file="$1"
    local basename=$(basename "$input_file" .json)
    local expected_file="$SNAPSHOTS_DIR/${basename}.html"
    local actual_file=$(mktemp)

    # Run your action
    if ! python3 "$ACTION_SCRIPT" < "$input_file" > "$actual_file" 2>&1; then
        echo -e "${SNAPSHOT_RED}✗${SNAPSHOT_NC} Failed to run action"
        rm -f "$actual_file"
        ((SNAPSHOT_FAILED++))
        return 1
    fi

    snapshot_compare "$basename" "$actual_file" "$expected_file"
}
```

### 3. Create Test Cases

Create test input files in `actions/<your-action>/test-cases/`:

```bash
mkdir -p actions/<your-action>/test-cases/__snapshots__
```

Add your test input files:
- `test-cases/example1.json`
- `test-cases/example2.json`
- etc.

### 4. Generate Initial Snapshots

Run the test script in UPDATE mode to generate the initial snapshots:

```bash
cd actions/<your-action>
UPDATE=1 ./test.sh
```

This creates snapshot files in `test-cases/__snapshots__/`:
- `__snapshots__/example1.html`
- `__snapshots__/example2.html`
- etc.

### 5. Run Tests

Run tests to verify your action output matches the snapshots:

```bash
cd actions/<your-action>
./test.sh
```

If all tests pass, you'll see:
```
✓ All tests passed!
```

## Usage Patterns

### Basic File Comparison

The most common pattern - compare a single output file:

```bash
process_test_case() {
    local input_file="$1"
    local basename=$(basename "$input_file" .yml)
    local expected_file="$SNAPSHOTS_DIR/${basename}.html"
    local actual_file=$(mktemp)

    # Generate output
    python3 "$ACTION_SCRIPT" < "$input_file" > "$actual_file"

    # Compare with snapshot
    snapshot_compare "$basename" "$actual_file" "$expected_file"
}
```

### Directory Comparison

For actions that output multiple files:

```bash
process_test_case() {
    local test_name="$1"
    local actual_dir=$(mktemp -d)
    local expected_dir="$SNAPSHOTS_DIR/${test_name}"

    # Generate outputs
    python3 "$ACTION_SCRIPT" --output-dir "$actual_dir"

    # Compare directory with snapshot
    snapshot_compare_dir "$test_name" "$actual_dir" "$expected_dir" "*.json"

    rm -rf "$actual_dir"
}
```

### Custom Test Logic

For complex scenarios, you can implement custom comparison:

```bash
process_test_case() {
    local input_file="$1"
    local basename=$(basename "$input_file" .json)

    # Run action and perform custom validation
    local output=$(python3 "$ACTION_SCRIPT" --input "$input_file")

    # Custom checks
    if [[ "$output" != *"expected string"* ]]; then
        echo -e "${SNAPSHOT_RED}✗${SNAPSHOT_NC} Output doesn't contain expected string"
        ((SNAPSHOT_FAILED++))
        return 1
    fi

    ((SNAPSHOT_PASSED++))
    echo -e "${SNAPSHOT_GREEN}✓${SNAPSHOT_NC} Test passed: $basename"
    return 0
}
```

## Library Functions

The centralized library (`scripts/snapshot-test-lib.sh`) provides these functions:

### `snapshot_test_init(test_name, snapshots_dir)`

Initialize the snapshot test environment. Call this once at the start of your test script.

**Parameters:**
- `test_name`: Display name for your test suite (e.g., "Report Publisher Tests")
- `snapshots_dir`: Path to the snapshots directory

**Example:**
```bash
snapshot_test_init "My Action Tests" "$SNAPSHOTS_DIR"
```

### `snapshot_compare(test_name, actual_file, expected_file, [keep_actual])`

Compare an actual output file with the expected snapshot.

**Parameters:**
- `test_name`: Name of this test case (for display)
- `actual_file`: Path to the generated output file
- `expected_file`: Path to the expected snapshot file
- `keep_actual`: (optional) Pass "keep-actual" to not delete the actual file after comparison

**Returns:** 0 if passed, 1 if failed

**Example:**
```bash
snapshot_compare "example1" "/tmp/output.json" "$SNAPSHOTS_DIR/example1.json"
```

### `snapshot_compare_dir(test_name, actual_dir, expected_dir, [pattern])`

Compare the contents of two directories.

**Parameters:**
- `test_name`: Name of this test case (for display)
- `actual_dir`: Path to the directory with generated outputs
- `expected_dir`: Path to the directory with expected snapshots
- `pattern`: (optional) File pattern to compare (e.g., "*.json"), defaults to all files

**Returns:** 0 if passed, 1 if failed

**Example:**
```bash
snapshot_compare_dir "full-output" "/tmp/output" "$SNAPSHOTS_DIR/full-output" "*.json"
```

### `snapshot_cleanup(input_dir, snapshots_dir, input_pattern, snapshot_ext, [exclude])`

Clean up orphaned snapshot files that no longer have corresponding input files.

**Parameters:**
- `input_dir`: Directory containing test input files
- `snapshots_dir`: Directory containing snapshot files
- `input_pattern`: Pattern for input files (e.g., "*.yml")
- `snapshot_ext`: Extension for snapshot files (e.g., ".html")
- `exclude`: (optional) Input filename to exclude (e.g., "workflow-example.yml")

**Example:**
```bash
snapshot_cleanup "$TEST_CASES_DIR" "$SNAPSHOTS_DIR" "*.json" ".out"
```

### `snapshot_test_summary()`

Print test summary and exit with appropriate status code. Call this once at the end of your test script.

**Example:**
```bash
snapshot_test_summary
```

## Environment Variables

### `UPDATE=1`

Run tests in UPDATE mode to regenerate all snapshots:

```bash
UPDATE=1 ./test.sh
```

Use this when:
- Creating initial snapshots for new test cases
- Intentionally changing action output and wanting to update expectations
- Snapshots are out of date after refactoring

## Directory Structure

Recommended structure for action tests:

```
actions/
└── my-action/
    ├── action.yml           # Action definition
    ├── main.py              # Action implementation
    ├── test.sh              # Test runner (from template)
    └── test-cases/          # Test inputs and snapshots
        ├── example1.json    # Test input 1
        ├── example2.json    # Test input 2
        └── __snapshots__/   # Expected outputs
            ├── example1.out # Expected output 1
            └── example2.out # Expected output 2
```

Alternative naming (as used by report-publisher):

```
actions/
└── report-publisher/
    ├── action.yml
    ├── publish.py
    ├── test.sh
    └── examples/           # Test inputs and snapshots
        ├── simple.yml
        ├── complex.yml
        └── __snapshots__/
            ├── simple.html
            └── complex.html
```

## CI/CD Integration

Add a GitHub Actions workflow to run tests on pull requests:

```yaml
name: Test My Action

on:
  pull_request:
    paths:
      - 'actions/my-action/**'
  workflow_dispatch:

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Set up Python
        uses: actions/setup-python@v5
        with:
          python-version: '3.11'

      - name: Run snapshot tests
        run: |
          cd actions/my-action
          ./test.sh
```

## Examples

### Simple Example: report-publisher

The `report-publisher` action demonstrates the basic pattern:

- **Input**: YAML files with embedded JSON (`examples/*.yml`)
- **Output**: HTML files (`examples/__snapshots__/*.html`)
- **Test**: Extract JSON from YAML, run publisher, compare HTML output

See: `actions/report-publisher/test.sh`

### Advanced Patterns

#### Testing with Multiple Outputs

```bash
process_test_case() {
    local test_name="$1"
    local output_dir=$(mktemp -d)

    # Action generates multiple files
    python3 "$ACTION_SCRIPT" --output "$output_dir"

    # Compare each output file
    for output_file in "$output_dir"/*.json; do
        local basename=$(basename "$output_file")
        snapshot_compare "$test_name/$basename" \
            "$output_file" \
            "$SNAPSHOTS_DIR/${test_name}/${basename}"
    done

    rm -rf "$output_dir"
}
```

#### Testing with File Transformations

```bash
process_test_case() {
    local input_file="$1"
    local basename=$(basename "$input_file" .in)
    local actual_file=$(mktemp)

    # Run transformation
    python3 "$ACTION_SCRIPT" transform "$input_file" > "$actual_file"

    # Normalize output (remove timestamps, etc.)
    sed -i 's/"timestamp": "[^"]*"/"timestamp": "TIMESTAMP"/g' "$actual_file"

    snapshot_compare "$basename" "$actual_file" "$SNAPSHOTS_DIR/${basename}.out"
}
```

## Best Practices

1. **Keep test cases small**: Use minimal input data that still tests the functionality
2. **Test edge cases**: Include tests for empty inputs, errors, and boundary conditions
3. **Normalize dynamic data**: Remove timestamps, IDs, or other dynamic values before comparison
4. **Document test cases**: Add comments explaining what each test verifies
5. **Review snapshot changes**: When updating snapshots, review the diff to ensure changes are intentional
6. **Use meaningful names**: Name test files descriptively (e.g., `empty-input.json`, `large-dataset.json`)

## Troubleshooting

### Tests fail with "snapshot differs"

1. Review the diff shown in the test output
2. If the change is intentional, update snapshots: `UPDATE=1 ./test.sh`
3. If unintentional, fix your action to match the expected output

### Snapshots are created but tests still fail

- Check for non-deterministic output (timestamps, random IDs)
- Normalize such values before comparison
- Ensure line endings are consistent (LF vs CRLF)

### "No test files found"

- Check the file pattern in `find` command matches your test files
- Ensure test files are in the correct directory
- Verify directory paths are correct

### Orphaned snapshots not being cleaned up

- Verify the `snapshot_cleanup` parameters match your file extensions
- Check that input and snapshot filenames correspond correctly
- Ensure the exclude pattern (if any) is correct

## Contributing

When adding new actions to the repository:

1. Copy `scripts/snapshot-test-template.sh` to your action directory
2. Customize the test script for your action
3. Add representative test cases
4. Generate initial snapshots with `UPDATE=1 ./test.sh`
5. Add a CI/CD workflow to run tests automatically
6. Document any special testing considerations in your action's README

## See Also

- [Testing Guide](../.github/TESTING.md) - Overall testing documentation
- [Report Publisher Tests](../actions/report-publisher/test.sh) - Example implementation
- [Snapshot Test Library](../scripts/snapshot-test-lib.sh) - Library source code
