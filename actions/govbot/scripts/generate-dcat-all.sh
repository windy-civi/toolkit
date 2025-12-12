#!/usr/bin/env bash
# Generate DCAT data.json files for all repos
# Usage: ./scripts/generate-dcat-all.sh [--dry-run]
# Note: This script is located in actions/govbot/scripts/
# It automatically detects repos in: .govbot/repos, or ~/.govbot/repos

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GOVBOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
TOOLKIT_ROOT="$(cd "$GOVBOT_DIR/../.." && pwd)"

# Default repos directory - can be overridden with REPOS_DIR env var
# Check for common locations
if [ -z "$REPOS_DIR" ]; then
    # Try dev directory first (.govbot/repos in govbot directory)
    if [ -d "$GOVBOT_DIR/.govbot/repos" ]; then
        REPOS_DIR="$GOVBOT_DIR/.govbot/repos"
    # Try home directory
    elif [ -d "$HOME/.govbot/repos" ]; then
        REPOS_DIR="$HOME/.govbot/repos"
    else
        echo "Error: Could not find repos directory"
        echo "Set REPOS_DIR environment variable or ensure repos exist in:"
        echo "  - $GOVBOT_DIR/.govbot/repos"
        echo "  - $HOME/.govbot/repos"
        exit 1
    fi
fi

# Default GitHub org - can be overridden with GITHUB_ORG env var
GITHUB_ORG="${GITHUB_ORG:-chn-openstates-files}"

# Function to get state name from code
get_state_name() {
    local code=$1
    case "$code" in
        "ak") echo "Alaska" ;;
        "al") echo "Alabama" ;;
        "ar") echo "Arkansas" ;;
        "az") echo "Arizona" ;;
        "ca") echo "California" ;;
        "co") echo "Colorado" ;;
        "ct") echo "Connecticut" ;;
        "dc") echo "District of Columbia" ;;
        "de") echo "Delaware" ;;
        "fl") echo "Florida" ;;
        "ga") echo "Georgia" ;;
        "gu") echo "Guam" ;;
        "hi") echo "Hawaii" ;;
        "ia") echo "Iowa" ;;
        "id") echo "Idaho" ;;
        "il") echo "Illinois" ;;
        "in") echo "Indiana" ;;
        "ks") echo "Kansas" ;;
        "ky") echo "Kentucky" ;;
        "la") echo "Louisiana" ;;
        "ma") echo "Massachusetts" ;;
        "md") echo "Maryland" ;;
        "me") echo "Maine" ;;
        "mi") echo "Michigan" ;;
        "mn") echo "Minnesota" ;;
        "mo") echo "Missouri" ;;
        "mp") echo "Northern Mariana Islands" ;;
        "ms") echo "Mississippi" ;;
        "mt") echo "Montana" ;;
        "nc") echo "North Carolina" ;;
        "nd") echo "North Dakota" ;;
        "ne") echo "Nebraska" ;;
        "nh") echo "New Hampshire" ;;
        "nj") echo "New Jersey" ;;
        "nm") echo "New Mexico" ;;
        "nv") echo "Nevada" ;;
        "ny") echo "New York" ;;
        "oh") echo "Ohio" ;;
        "ok") echo "Oklahoma" ;;
        "or") echo "Oregon" ;;
        "pa") echo "Pennsylvania" ;;
        "pr") echo "Puerto Rico" ;;
        "ri") echo "Rhode Island" ;;
        "sc") echo "South Carolina" ;;
        "sd") echo "South Dakota" ;;
        "tn") echo "Tennessee" ;;
        "tx") echo "Texas" ;;
        "usa") echo "Federal" ;;
        "ut") echo "Utah" ;;
        "va") echo "Virginia" ;;
        "vi") echo "Virgin Islands" ;;
        "vt") echo "Vermont" ;;
        "wa") echo "Washington" ;;
        "wi") echo "Wisconsin" ;;
        "wv") echo "West Virginia" ;;
        "wy") echo "Wyoming" ;;
        *) echo "" ;;
    esac
}

echo "🔍 Finding all repos in: $REPOS_DIR"
cd "$REPOS_DIR"
REPOS_DIR_ABS=$(pwd)

total_repos=0
processed_repos=0
failed_repos=0
skipped_repos=0

# Process each repo
for repo_dir in */; do
    repo_name="${repo_dir%/}"
    repo_path="$REPOS_DIR_ABS/$repo_name"
    
    # Skip if not a directory
    if [ ! -d "$repo_path" ]; then
        continue
    fi
    
    # Check if country:us directory exists (indicates it's a valid repo)
    country_dir="$repo_path/country:us"
    if [ ! -d "$country_dir" ]; then
        echo "⏭️  Skipping $repo_name (no country:us directory)"
        skipped_repos=$((skipped_repos + 1))
        continue
    fi
    
    total_repos=$((total_repos + 1))
    
    # Extract locale/state code from repo name
    # Handle both patterns: {locale}-legislation and {locale}-data-pipeline
    locale=""
    if [[ "$repo_name" == *"-legislation" ]]; then
        locale="${repo_name%-legislation}"
    elif [[ "$repo_name" == *"-data-pipeline" ]]; then
        locale="${repo_name%-data-pipeline}"
    else
        # Try to use repo name as-is
        locale="$repo_name"
    fi
    
    # Get state name
    state_name=$(get_state_name "$locale")
    
    if [ -z "$state_name" ]; then
        echo "⚠️  Unknown locale: $locale (repo: $repo_name) - using repo name as title"
        title="$repo_name Legislation"
    else
        title="$state_name Legislation"
    fi
    
    # Build GitHub URL (without .git extension for accessURL)
    repo_url="https://github.com/$GITHUB_ORG/$repo_name"
    
    echo ""
    echo "📦 Processing: $repo_name"
    echo "   Title: $title"
    echo "   URL: $repo_url"
    
    # Run generate-dcat.py script
    if python3 "$SCRIPT_DIR/generate-dcat.py" \
        --repo-root "$repo_path" \
        --title "$title" \
        --repo-url "$repo_url" \
        "$@"; then
        processed_repos=$((processed_repos + 1))
    else
        failed_repos=$((failed_repos + 1))
        echo "❌ Failed to generate DCAT for $repo_name"
    fi
done

echo ""
echo "✅ Completed:"
echo "   Total repos: $total_repos"
echo "   Processed: $processed_repos"
echo "   Failed: $failed_repos"
echo "   Skipped: $skipped_repos"

if [ $failed_repos -gt 0 ]; then
    exit 1
fi
