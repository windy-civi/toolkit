#!/bin/bash
# Update workflow files to point to main branch instead of feature branches
# Usage: ./update-workflows-to-main.sh [config-file] [--test-states state1,state2,...]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PIPELINE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
DEFAULT_CONFIG="$PIPELINE_DIR/chn-openstates-scrape.yml"

# Parse arguments
TEST_STATES=""
CONFIG_FILE="$DEFAULT_CONFIG"

while [[ $# -gt 0 ]]; do
    case $1 in
        --test-states)
            TEST_STATES="$2"
            shift 2
            ;;
        *)
            # Treat as config file path
            CONFIG_FILE="$1"
            shift
            ;;
    esac
done

# Check if gh CLI is installed
if ! command -v gh &> /dev/null; then
    echo "❌ GitHub CLI (gh) is not installed"
    echo "Install it: brew install gh"
    exit 1
fi

# Check authentication
echo "🔐 Checking GitHub authentication..."
if ! gh auth status &>/dev/null; then
    echo "❌ Not authenticated with GitHub CLI"
    echo "Run: gh auth login"
    exit 1
fi
echo "   ✅ Authenticated"

# Parse config to get org and locales
echo "📖 Reading config from: $CONFIG_FILE"

# Extract org username
ORG=$(grep -A 1 "^org:" "$CONFIG_FILE" | grep "username:" | sed 's/.*username:[[:space:]]*//' | tr -d '"' | tr -d "'")
if [ -z "$ORG" ]; then
    echo "❌ Could not find org username in config"
    exit 1
fi

echo "🏢 Organization: $ORG"
echo ""

# Parse locales from config using Python
echo "📋 Parsing state information..."
TEMP_STATES=$(mktemp)

export CONFIG_FILE_PATH="$CONFIG_FILE"

python3 << 'PYTHON_SCRIPT' > "$TEMP_STATES"
import os
import sys
import yaml

config_file = os.environ.get('CONFIG_FILE_PATH')
if not config_file:
    print("ERROR: CONFIG_FILE_PATH not set", file=sys.stderr)
    sys.exit(1)

with open(config_file, 'r') as f:
    config = yaml.safe_load(f)

org = config.get('org', {}).get('username', '')
locales = config.get('locales', {})

print(f"ORG={org}")
for code, info in locales.items():
    name = info.get('name', '')
    print(f"{code}:{name}")
PYTHON_SCRIPT

# Read org and states
STATE_CODES=()
STATE_NAMES=()

exec 3< "$TEMP_STATES"
while IFS= read -r line <&3; do
    if [[ $line =~ ^ORG=(.+)$ ]]; then
        ORG="${BASH_REMATCH[1]}"
    elif [[ $line =~ ^([^:]+):(.+)$ ]]; then
        STATE_CODE="${BASH_REMATCH[1]}"
        STATE_NAME="${BASH_REMATCH[2]}"
        STATE_CODES[${#STATE_CODES[@]}]="$STATE_CODE"
        STATE_NAMES[${#STATE_NAMES[@]}]="$STATE_NAME"
    fi
done
exec 3<&-

rm -f "$TEMP_STATES"

# Filter to test states if specified
if [ -n "$TEST_STATES" ]; then
    echo "🧪 Test mode: Filtering to states: $TEST_STATES"
    TEST_STATES_ARRAY=($(echo "$TEST_STATES" | tr ',' ' '))
    FILTERED_CODES=()
    FILTERED_NAMES=()

    TOTAL_STATES=${#STATE_CODES[@]}
    for test_state in "${TEST_STATES_ARRAY[@]}"; do
        test_state=$(echo "$test_state" | tr '[:upper:]' '[:lower:]' | xargs)
        i=0
        while [ $i -lt $TOTAL_STATES ]; do
            if [ "${STATE_CODES[$i]}" = "$test_state" ]; then
                FILTERED_CODES[${#FILTERED_CODES[@]}]="${STATE_CODES[$i]}"
                FILTERED_NAMES[${#FILTERED_NAMES[@]}]="${STATE_NAMES[$i]}"
                break
            fi
            i=$((i + 1))
        done
    done

    if [ ${#FILTERED_CODES[@]} -eq 0 ]; then
        echo "❌ No valid test states found"
        exit 1
    fi

    STATE_CODES=("${FILTERED_CODES[@]}")
    STATE_NAMES=("${FILTERED_NAMES[@]}")
fi

if [ ${#STATE_CODES[@]} -eq 0 ]; then
    echo "❌ No states found in config"
    exit 1
fi

echo "   Found ${#STATE_CODES[@]} states to process"
echo ""
read -p "Continue with workflow updates? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cancelled."
    exit 0
fi

SUCCESS_COUNT=0
SKIP_COUNT=0
FAIL_COUNT=0
TEMP_DIR=$(mktemp -d)

# Cleanup function
cleanup() {
    if [ -d "$TEMP_DIR" ]; then
        echo "🧹 Cleaning up temp directory..."
        rm -rf "$TEMP_DIR"
    fi
}
trap cleanup EXIT

for i in "${!STATE_CODES[@]}"; do
    state_code="${STATE_CODES[$i]}"
    state_name="${STATE_NAMES[$i]}"
    repo_name="${state_code}-legislation"
    full_repo="$ORG/$repo_name"

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📍 $state_name ($state_code)"
    echo "   Repository: $full_repo"

    # Check if repo exists
    if ! gh repo view "$full_repo" &>/dev/null; then
        echo "   ⚠️  Repository does not exist, skipping"
        SKIP_COUNT=$((SKIP_COUNT + 1))
        continue
    fi

    # Clone repo temporarily
    REPO_DIR="$TEMP_DIR/$repo_name"
    echo "   📥 Cloning..."

    if ! gh repo clone "$full_repo" "$REPO_DIR" -- --depth 1 --quiet 2>/dev/null; then
        echo "   ❌ Failed to clone repository"
        FAIL_COUNT=$((FAIL_COUNT + 1))
        continue
    fi

    cd "$REPO_DIR"

    # Find workflow files
    WORKFLOW_FILES=$(find .github/workflows -name "*.yml" -o -name "*.yaml" 2>/dev/null || true)

    if [ -z "$WORKFLOW_FILES" ]; then
        echo "   ⚠️  No workflow files found"
        SKIP_COUNT=$((SKIP_COUNT + 1))
        cd "$TEMP_DIR"
        rm -rf "$REPO_DIR"
        continue
    fi

    UPDATED=false
    for workflow_file in $WORKFLOW_FILES; do
        # Check if file uses non-main branches
        if grep -q "windy-civi/toolkit/actions/.*@feature/" "$workflow_file" 2>/dev/null || \
           grep -q "windy-civi/toolkit/actions/.*@.*/" "$workflow_file" 2>/dev/null && \
           ! grep -q "windy-civi/toolkit/actions/.*@main" "$workflow_file" 2>/dev/null; then

            echo "   ✏️  Updating $workflow_file..."

            # Replace any non-main branch references with @main
            sed -i.bak \
                -e "s|windy-civi/toolkit/actions/\([^@]*\)@[^[:space:]]*|windy-civi/toolkit/actions/\1@main|g" \
                "$workflow_file"
            rm -f "$workflow_file.bak"

            UPDATED=true
        fi
    done

    if [ "$UPDATED" = true ]; then
        # Commit and push changes
        git config user.name "github-actions[bot]"
        git config user.email "github-actions[bot]@users.noreply.github.com"
        git add .github/workflows/

        if git diff --staged --quiet; then
            echo "   ℹ️  No changes to commit"
            SKIP_COUNT=$((SKIP_COUNT + 1))
        else
            echo "   💾 Committing updates..."
            git commit -m "fix: update workflow actions to use @main branch

Update all action references from feature branches to @main for consistency."

            echo "   📤 Pushing changes..."
            if git push origin main 2>/dev/null; then
                echo "   ✅ Updated successfully"
                SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
            else
                echo "   ❌ Failed to push"
                FAIL_COUNT=$((FAIL_COUNT + 1))
            fi
        fi
    else
        echo "   ℹ️  All workflows already use @main"
        SKIP_COUNT=$((SKIP_COUNT + 1))
    fi

    # Clean up this repo's temp clone
    cd "$TEMP_DIR"
    rm -rf "$REPO_DIR"

    # Be nice to GitHub API
    sleep 1
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 Summary:"
echo "   ✅ Updated: $SUCCESS_COUNT"
echo "   ℹ️  Already using @main: $SKIP_COUNT"
echo "   ❌ Failed: $FAIL_COUNT"
echo ""
echo "🎉 Done! All workflows should now point to @main."

