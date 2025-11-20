#!/bin/bash
# Test runner for Report Publisher
# Renders snapshots and compares them with committed versions using git diff

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
EXAMPLES_DIR="$SCRIPT_DIR/examples"
SNAPSHOTS_DIR="$EXAMPLES_DIR/__snapshots__"
RENDER_SCRIPT="$SCRIPT_DIR/render-snapshots.sh"
SNAPSHOT_TEST="$REPO_ROOT/scripts/snapshot-test.sh"

# Render snapshots
"$RENDER_SCRIPT"

# Compare snapshots with committed versions using reusable script
echo ""
"$SNAPSHOT_TEST" "$SNAPSHOTS_DIR"

