#!/bin/bash
# Update repository metadata (description and topics) for all state repos
# Usage: ./update-repo-metadata.sh [config-file] [--test-states state1,state2,...] [--all-states]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PIPELINE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
DEFAULT_CONFIG="$PIPELINE_DIR/chn-openstates-scrape.yml"

# Parse arguments
TEST_STATES=""
ALL_STATES=false
CONFIG_FILE="$DEFAULT_CONFIG"

while [[ $# -gt 0 ]]; do
    case $1 in
        --test-states)
            TEST_STATES="$2"
            shift 2
            ;;
        --all-states)
            ALL_STATES=true
            shift
            ;;
        *)
            # Treat as config file path
            CONFIG_FILE="$1"
            shift
            ;;
    esac
done

# If --all-states is specified, clear TEST_STATES
if [ "$ALL_STATES" = true ]; then
    TEST_STATES=""
fi

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

# Parse locales from config using Python (same as render.py)
echo "📋 Parsing state information..."
TEMP_STATES=$(mktemp)

# Export config file path for Python
export CONFIG_FILE_PATH="$CONFIG_FILE"

# Run Python and capture output properly
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

# Read org and states (using parallel arrays for bash 3.2 compatibility)
# Read entire file content first to avoid subshell issues
STATE_CODES=()
STATE_NAMES=()

# Read file directly (bash 3.2 compatible - avoid variable expansion issues)
STATE_CODES=()
STATE_NAMES=()

# Use file descriptor to read directly (avoids subshell and variable issues)
exec 3< "$TEMP_STATES"
LINE_COUNT=0
while IFS= read -r line <&3; do
    LINE_COUNT=$((LINE_COUNT + 1))
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

echo "   Debug: Processed $LINE_COUNT lines, found ${#STATE_CODES[@]} states"

# Filter to test states if specified (skip if --all-states or no filter)
if [ -n "$TEST_STATES" ]; then
    echo "🧪 Test mode: Filtering to states: $TEST_STATES"
    TEST_STATES_ARRAY=($(echo "$TEST_STATES" | tr ',' ' '))
    FILTERED_CODES=()
    FILTERED_NAMES=()

    # Debug: show array size and first few entries
    TOTAL_STATES=${#STATE_CODES[@]}
    echo "   Debug: Found $TOTAL_STATES total states in config"
    if [ $TOTAL_STATES -gt 0 ]; then
        echo "   Debug: First state code: '${STATE_CODES[0]}', name: '${STATE_NAMES[0]}'"
    fi

    for test_state in "${TEST_STATES_ARRAY[@]}"; do
        test_state=$(echo "$test_state" | tr '[:upper:]' '[:lower:]' | xargs)
        echo "   Debug: Looking for state: '$test_state'"
        found=false
        # Loop through all state codes to find a match (bash 3.2 compatible)
        i=0
        while [ $i -lt $TOTAL_STATES ]; do
            current_code="${STATE_CODES[$i]}"
            if [ "$current_code" = "$test_state" ]; then
                FILTERED_CODES[${#FILTERED_CODES[@]}]="$current_code"
                FILTERED_NAMES[${#FILTERED_NAMES[@]}]="${STATE_NAMES[$i]}"
                found=true
                echo "   Debug: Found match at index $i: '$current_code' = '$test_state'"
                break
            fi
            i=$((i + 1))
        done
        if [ "$found" = false ]; then
            echo "   ⚠️  Warning: State '$test_state' not found in config"
        fi
    done

    if [ ${#FILTERED_CODES[@]} -eq 0 ]; then
        echo "❌ No valid test states found"
        exit 1
    fi

    STATE_CODES=("${FILTERED_CODES[@]}")
    STATE_NAMES=("${FILTERED_NAMES[@]}")
fi

# Check if we have states
if [ ${#STATE_CODES[@]} -eq 0 ]; then
    echo "❌ No states found in config"
    exit 1
fi

echo "   Found ${#STATE_CODES[@]} states to process"
echo ""
read -p "Continue with metadata updates? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cancelled."
    exit 0
fi

SUCCESS_COUNT=0
SKIP_COUNT=0
FAIL_COUNT=0

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

    # Get current description
    CURRENT_DESC=$(gh repo view "$full_repo" --json description -q '.description // ""' 2>/dev/null || echo "")

    # Get current topics (as array for easier checking)
    # The JSON structure is repositoryTopics (array), not repositoryTopics.nodes
    TOPICS_JSON=$(gh repo view "$full_repo" --json repositoryTopics 2>/dev/null || echo '{"repositoryTopics":[]}')
    CURRENT_TOPICS_RAW=$(echo "$TOPICS_JSON" | jq -r '.repositoryTopics[]?.name // empty' 2>/dev/null || echo "")

    if [ -z "$CURRENT_TOPICS_RAW" ]; then
        CURRENT_TOPICS=""
        CURRENT_TOPICS_ARRAY=()
    else
        CURRENT_TOPICS=$(echo "$CURRENT_TOPICS_RAW" | tr '\n' ',' | sed 's/,$//' || echo "")
        CURRENT_TOPICS_ARRAY=($(echo "$CURRENT_TOPICS_RAW" | tr '\n' ' '))
    fi

    # Build new description: full state name with emoji
    NEW_DESC="🏛️ $state_name Legislation"

    # Update description if needed
    UPDATED=false
    if [ "$CURRENT_DESC" != "$NEW_DESC" ]; then
        echo "   ✏️  Updating description: '$CURRENT_DESC' → '$NEW_DESC'"
        if gh repo edit "$full_repo" --description "$NEW_DESC" 2>/dev/null; then
            UPDATED=true
        else
            echo "   ❌ Failed to update description"
            FAIL_COUNT=$((FAIL_COUNT + 1))
            continue
        fi
    else
        echo "   ℹ️  Description already correct: '$NEW_DESC'"
    fi

    # Update topics if needed
    # Only add 'working' if NO topics exist (don't add if topics already exist)
    if [ -z "$CURRENT_TOPICS" ] || [ ${#CURRENT_TOPICS_ARRAY[@]} -eq 0 ]; then
        echo "   🏷️  No topics found, adding 'working'"
        if gh repo edit "$full_repo" --add-topic working 2>/dev/null; then
            UPDATED=true
            echo "   ✅ Added 'working' topic"
        else
            echo "   ❌ Failed to add 'working' topic"
            FAIL_COUNT=$((FAIL_COUNT + 1))
            continue
        fi
    else
        echo "   ℹ️  Topics already exist: $CURRENT_TOPICS (skipping 'working' addition)"
    fi

    if [ "$UPDATED" = true ]; then
        echo "   ✅ Updated successfully"
        SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
    else
        echo "   ℹ️  No changes needed"
        SKIP_COUNT=$((SKIP_COUNT + 1))
    fi

    # Be nice to GitHub API
    sleep 0.5
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 Summary:"
echo "   ✅ Updated: $SUCCESS_COUNT"
echo "   ℹ️  No changes needed: $SKIP_COUNT"
echo "   ❌ Failed: $FAIL_COUNT"
echo ""
echo "🎉 Done! All repos should now have updated metadata."

