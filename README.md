# 🏛️ Windy Civi: OpenCivicData Blockchain Transformer

## Testing

This repository uses snapshot testing to verify that actions produce expected outputs. See the [Snapshot Testing Guide](docs/SNAPSHOT_TESTING.md) for details on adding tests to actions.

**Quick start:**
```bash
# Run tests for an action
cd actions/report-publisher
./test.sh

# Update snapshots when output changes intentionally
UPDATE=1 ./test.sh
```
