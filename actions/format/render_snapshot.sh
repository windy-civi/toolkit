#!/usr/bin/env bash
# Local snapshot renderer - uses main.sh for common logic
# Usage: ./render_snapshot.sh <state> [prod-mocks-dir]
#   state: State code (e.g., wy, id, ri, vt, de, gu)
#   prod-mocks-dir: Optional path to prod-mocks directory (default: auto-detect latest)
set -euo pipefail

# Get the script directory (where this script lives)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Parse arguments
STATE="${1:-}"
PROD_MOCKS_DIR="${2:-}"

# Validate state parameter
if [ -z "$STATE" ]; then
    echo "Usage: $0 <state> [prod-mocks-dir]"
    echo "  state: State code (e.g., wy, id, ri, vt, de, gu)"
    echo "  prod-mocks-dir: Optional path to prod-mocks directory (default: auto-detect latest)"
    echo ""
    echo "Examples:"
    echo "  $0 wy"
    echo "  $0 id ../scrape/prod-mocks-2025-11-25"
    exit 1
fi

# Normalize state to lowercase
STATE=$(echo "$STATE" | tr '[:upper:]' '[:lower:]')

# Configuration
TMP_DIR="./tmp/sanitize"
OUTPUT_DIR="./snapshots/$STATE"

# Determine input directory
if [ -n "$PROD_MOCKS_DIR" ]; then
    # Use provided directory
    INPUT_DIR="$PROD_MOCKS_DIR/_working/_data"
else
    # Auto-detect latest prod-mocks directory
    SCRAPE_DIR="$SCRIPT_DIR/../scrape"
    if [ ! -d "$SCRAPE_DIR" ]; then
        echo "❌ Scrape directory not found: $SCRAPE_DIR"
        exit 1
    fi

    # Find latest prod-mocks directory (sorted by date)
    LATEST_MOCKS=$(find "$SCRAPE_DIR" -maxdepth 1 -type d -name "prod-mocks-*" | sort -r | head -1)

    if [ -z "$LATEST_MOCKS" ]; then
        echo "❌ No prod-mocks directory found in $SCRAPE_DIR"
        echo "   Run actions/scrape/update-mocks-from-production.sh first"
        exit 1
    fi

    INPUT_DIR="$LATEST_MOCKS/_working/_data"
    echo "📂 Auto-detected prod-mocks: $LATEST_MOCKS"
fi

# Validate input directory exists
if [ ! -d "$INPUT_DIR" ]; then
    echo "❌ Input directory not found: $INPUT_DIR"
    exit 1
fi

# Check if state data exists in input directory
STATE_INPUT_DIR="$INPUT_DIR/$STATE"
if [ ! -d "$STATE_INPUT_DIR" ]; then
    echo "❌ State data not found: $STATE_INPUT_DIR"
    echo "   Available states: $(ls -1 "$INPUT_DIR" 2>/dev/null | tr '\n' ' ' || echo 'none')"
    exit 1
fi

echo "📸 Generating snapshot for state: $STATE"
echo "📂 Input directory: $INPUT_DIR"
echo "📁 Output directory: $OUTPUT_DIR"

# Reset snapshots
echo "🧹 Cleaning output directory..."
rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

# Copy the production mocks to temporary directory
echo "📂 Copying input data..."
rm -rf "$TMP_DIR"
mkdir -p "$TMP_DIR"
cp -r "$INPUT_DIR" "$TMP_DIR"

# Run the main formatter script
echo "🚀 Running formatter..."
"$SCRIPT_DIR/main.sh" "$STATE" "$TMP_DIR" "$OUTPUT_DIR"

echo ""
echo "✅ Snapshot generation complete!"
echo "📁 Output saved to: $OUTPUT_DIR"


