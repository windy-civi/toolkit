#!/usr/bin/env bash
# Symlink all log files from bill directories to a central logs folder
# Usage: ./scripts/symlink-logs.sh [--dry-run]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GOVBOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="${REPO_ROOT:-$GOVBOT_DIR/.test-govbot/repos/il-legislation}"

# Default values
ROOT_DIR="${ROOT_DIR:-$REPO_ROOT/country:us/state:il}"
SESSION="${SESSION:-104th}"
TARGET_DIR="${TARGET_DIR:-$ROOT_DIR/sessions/$SESSION/logs}"

# Run the Python script
echo "🔗 Symlinking log files..."
echo "   Root: $ROOT_DIR"
echo "   Session: $SESSION"
echo "   Target: $TARGET_DIR"
echo ""

python3 "$SCRIPT_DIR/symlink-logs.py" \
    --root "$ROOT_DIR" \
    --session "$SESSION" \
    --target "$TARGET_DIR" \
    "$@"
