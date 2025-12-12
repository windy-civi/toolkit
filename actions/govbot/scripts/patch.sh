#!/usr/bin/env bash
# Patch all devbox data: generate DCAT files and symlink logs
# Usage: ./scripts/patch.sh [--dry-run]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "🔧 Patching devbox data..."
echo ""

# Step 1: Generate DCAT data.json files
echo "📋 Step 1: Generating DCAT data.json files..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
"$SCRIPT_DIR/generate-dcat-all.sh" "$@"
echo ""

# Step 2: Symlink log files
echo "🔗 Step 2: Symlinking log files..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
"$SCRIPT_DIR/symlink-logs-all.sh" "$@"
echo ""

echo "✅ All patching completed!"
