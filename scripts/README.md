# Shared Scripts

Utility scripts and libraries used across the repository.

## Snapshot Testing

### `snapshot-test-lib.sh`

A centralized library for snapshot testing GitHub Actions. Provides reusable functions for:
- Comparing actual output files with expected snapshots
- Updating snapshots when output changes
- Cleaning up orphaned test files
- Test result reporting

**Documentation:** See [Snapshot Testing Guide](../docs/SNAPSHOT_TESTING.md)

**Quick Start:**
```bash
# Copy the template to your action
cp scripts/snapshot-test-template.sh actions/<your-action>/test.sh
chmod +x actions/<your-action>/test.sh

# Edit test.sh to customize for your action
# Create test cases in actions/<your-action>/test-cases/

# Generate initial snapshots
cd actions/<your-action>
UPDATE=1 ./test.sh

# Run tests
./test.sh
```

### `snapshot-test-template.sh`

Template for creating snapshot tests for actions. Copy and customize for your action.

**Usage:**
1. Copy to your action directory as `test.sh`
2. Update configuration variables
3. Implement the `process_test_case` function
4. Add test input files
5. Generate snapshots with `UPDATE=1 ./test.sh`

## Examples

See existing snapshot tests:
- [Report Publisher Tests](../actions/report-publisher/test.sh) - Complete example

## Contributing

When adding new shared scripts:
- Document the script's purpose and usage in this README
- Add comments and usage examples in the script itself
- Consider creating detailed documentation in `docs/` for complex utilities
