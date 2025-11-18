# Examples

This directory contains example JSON files and their corresponding HTML outputs. These examples serve dual purposes:

1. **Documentation** - Show what the JSON Publisher can do
2. **Test Snapshots** - Used in CI tests to ensure HTML output remains consistent

## Files

### Basic Examples

**`simple.json`** → **`simple.html`**
- Basic JSON with simple types (string, number)
- Demonstrates minimal viable input

**`complex.json`** → **`complex.html`**
- All JSON data types: strings, numbers, floats, booleans, null, arrays, objects
- Shows nested structure handling
- Tests syntax highlighting for each type

**`empty.html`**
- Edge case: empty JSON object `{}`
- Validates graceful handling of minimal data

### Sample Reports

**`sample-report.json`** → **`sample-report.html`**
- Real-world test report example
- Shows typical CI/CD usage scenario
- Demonstrates nested data visualization

## Usage

Run any example through the publisher:

```bash
# Generate HTML from an example
cat simple.json | python3 ../publish.py --mode pages --output my-output.html

# Or use directly
python3 ../publish.py --mode git --output test.json < complex.json
```

## Snapshot Testing

The CI workflow uses these examples as reference snapshots. When you run:

```yaml
- name: Test complex JSON
  run: |
    cat examples/complex.json | python3 publish.py --mode pages --output /tmp/test.html
    diff examples/complex.html /tmp/test.html
```

This ensures the HTML generator produces consistent output.

## Updating Snapshots

If you intentionally change the HTML template, regenerate the snapshots:

```bash
cd examples/

# Regenerate all HTML snapshots
cat simple.json | python3 ../publish.py --mode pages --output simple.html
cat complex.json | python3 ../publish.py --mode pages --output complex.html
echo '{}' | python3 ../publish.py --mode pages --output empty.html
cat sample-report.json | python3 ../publish.py --mode pages --output sample-report.html
```

The CI tests exclude dynamic content when comparing (timestamps, etc.).
