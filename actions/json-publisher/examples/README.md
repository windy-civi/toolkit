# Examples

This directory contains example GitHub Actions workflows that demonstrate how to use the JSON Publisher. These examples serve dual purposes:

1. **Documentation** - Show real-world usage patterns in GitHub Actions
2. **Test Snapshots** - Used in CI tests to ensure HTML output remains consistent

## Example Workflows

Each `.yml` file is a complete GitHub Actions workflow showing how to use JSON Publisher, with JSON embedded inline.

### `simple.yml` → `simple.html`
Basic usage with simple JSON data.

```yaml
- name: Generate and publish simple report
  run: |
    echo '{
      "test": "simple",
      "value": 123
    }' | python3 actions/json-publisher/publish.py \
      --mode pages \
      --output simple.html
```

### `complex.yml` → `complex.html`
Demonstrates all JSON data types (strings, numbers, booleans, null, arrays, objects).

```yaml
- name: Generate report with all JSON data types
  run: |
    echo '{
      "string": "test",
      "number": 42,
      "boolean": true,
      "null_value": null,
      "array": [1, 2, 3],
      "nested": {"deep": "value"}
    }' | python3 actions/json-publisher/publish.py \
      --mode pages \
      --output complex.html
```

### `empty.yml` → `empty.html`
Edge case: handling empty JSON objects.

### `test-report.yml` → `test-report.html`
Real-world example showing a typical CI test report with nested data.

## File Structure

```
examples/
├── README.md                  # This file
├── simple.yml                 # Example workflow
├── complex.yml                # Example workflow
├── empty.yml                  # Example workflow
├── test-report.yml            # Example workflow
└── test_snapshots/            # Expected HTML outputs
    ├── simple.html
    ├── complex.html
    ├── empty.html
    └── test-report.html
```

## How It Works

1. **Example workflows** (`.yml`) contain the JSON inline - showing exactly how you'd use it in GitHub Actions
2. **HTML snapshots** (`.html`) are the reference outputs used in testing
3. **CI tests** extract the JSON from the workflows, run it, and compare against snapshots

## Using These Examples

Copy any workflow to your `.github/workflows/` directory and modify the JSON to match your data:

```yaml
# .github/workflows/my-report.yml
name: My Custom Report

on: [push]

jobs:
  publish:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Generate my report
        run: |
          echo '{
            "my": "data",
            "goes": "here"
          }' | python3 actions/json-publisher/publish.py \
            --mode pages \
            --output my-report.html
```

## Snapshot Testing

The CI workflow extracts JSON from these examples and validates the output:

```yaml
# From .github/workflows/test-json-publisher.yml
- name: Simple report example
  run: |
    echo '{
      "test": "simple",
      "value": 123
    }' | python3 actions/json-publisher/publish.py \
      --mode pages \
      --output /tmp/simple.html

    diff examples/test_snapshots/simple.html /tmp/simple.html
```

This ensures:
- Examples stay up-to-date and working
- HTML output remains consistent
- No regressions in the generator

## Updating Snapshots

If you intentionally change the HTML template, regenerate snapshots:

```bash
cd examples/

# Simple
echo '{"test": "simple", "value": 123}' | \
  python3 ../publish.py --mode pages --output test_snapshots/simple.html

# Complex
echo '{
  "string": "test",
  "number": 42,
  "boolean": true,
  "null_value": null,
  "array": [1, 2, 3],
  "nested": {"deep": "value"}
}' | python3 ../publish.py --mode pages --output test_snapshots/complex.html

# Empty
echo '{}' | python3 ../publish.py --mode pages --output test_snapshots/empty.html

# Test report
echo '{
  "timestamp": "2025-11-18T10:30:00Z",
  "project": "toolkit",
  "tests": {"total": 127, "passed": 125, "failed": 2}
}' | python3 ../publish.py --mode pages --output test_snapshots/test-report.html
```

The CI tests exclude dynamic content when comparing (timestamps).
