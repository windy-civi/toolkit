#!/usr/bin/env bash
# Generate a DCAT data.json file for a legislative data repository
# Usage: ./scripts/generate-dcat.sh [--dry-run]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLKIT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Default values - adjust these for your repo
REPO_ROOT="${REPO_ROOT:-$(pwd)}"
TITLE="${TITLE:-Legislation}"
REPO_URL="${REPO_URL:-}"

# Check if REPO_URL is set
if [ -z "$REPO_URL" ]; then
    echo "Error: REPO_URL environment variable must be set"
    echo "Example: REPO_URL='https://github.com/chn-openstates-files/il-legislation' ./scripts/generate-dcat.sh"
    exit 1
fi

# Run the Python script
echo "📋 Generating DCAT data.json..."
echo "   Repo Root: $REPO_ROOT"
echo "   Title: $TITLE"
echo "   Repo URL: $REPO_URL"
echo ""

python3 "$SCRIPT_DIR/generate-dcat.py" \
    --repo-root "$REPO_ROOT" \
    --title "$TITLE" \
    --repo-url "$REPO_URL" \
    "$@"
