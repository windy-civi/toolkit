#!/usr/bin/env bash
# Symlink all log files across all repos and sessions
# Usage: ./scripts/symlink-logs-all.sh [--dry-run]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GOVBOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

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

# Python script is ready to use - no build needed

# Find all session directories
echo "🔍 Finding all sessions across repos..."
cd "$REPOS_DIR"
REPOS_DIR_ABS=$(pwd)

total_sessions=0
processed_sessions=0
failed_sessions=0

# Process each repo
for repo_dir in */; do
    repo_name="${repo_dir%/}"
    repo_path="$REPOS_DIR_ABS/$repo_name"
    
    # Check if country:us directory exists
    country_dir="$repo_path/country:us"
    if [ ! -d "$country_dir" ]; then
        continue
    fi
    
    # Find state directories in this repo (direct children of country:us)
    state_dirs=$(find "$country_dir" -mindepth 1 -maxdepth 1 -type d -name "state:*" 2>/dev/null | sort || true)
    
    if [ -z "$state_dirs" ]; then
        continue
    fi
    
    # Process each state directory
    while IFS= read -r state_dir; do
        if [ ! -d "$state_dir" ]; then
            continue
        fi
        
        # Extract state code from path (e.g., state:il from country:us/state:il)
        state_code=$(basename "$state_dir")
        
        # Find all session directories
        sessions=$(find "$state_dir/sessions" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort || true)
        
        if [ -z "$sessions" ]; then
            continue
        fi
        
        # Process each session
        while IFS= read -r session_dir; do
            if [ ! -d "$session_dir" ]; then
                continue
            fi
            
            session_id=$(basename "$session_dir")
            bills_path="$session_dir/bills"
            
            # Check if this session has bills with logs
            if [ ! -d "$bills_path" ]; then
                continue
            fi
            
            # Check if there are any log files
            log_count=$(find "$bills_path" -type f -path "*/logs/*.json" 2>/dev/null | wc -l | tr -d ' ')
            if [ "$log_count" -eq 0 ]; then
                continue
            fi
            
            total_sessions=$((total_sessions + 1))
            
            target_logs_dir="$session_dir/logs"
            
            echo ""
            echo "📦 Processing: $repo_name / $state_code / $session_id ($log_count log files)"
            
            # Run symlink-logs Python script
            if python3 "$SCRIPT_DIR/symlink-logs.py" \
                --root "$state_dir" \
                --session "$session_id" \
                --target "$target_logs_dir" \
                "$@"; then
                processed_sessions=$((processed_sessions + 1))
            else
                failed_sessions=$((failed_sessions + 1))
                echo "❌ Failed to process $repo_name / $state_code / $session_id"
            fi
            
        done <<< "$sessions"
    done <<< "$state_dirs"
done

echo ""
echo "✅ Completed:"
echo "   Total sessions: $total_sessions"
echo "   Processed: $processed_sessions"
echo "   Failed: $failed_sessions"
