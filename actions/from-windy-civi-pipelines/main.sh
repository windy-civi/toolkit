#!/bin/bash

# Script to find all JSON files that have 'logs/' in their path from cloned repositories
# Usage: ./get-logs.sh [--git-dir <dir>] [--git-dir=<dir>] [--sort <ASC|DESC>] [--sort=<ASC|DESC>] [--limit <n>] [--limit=<n>] [--join <values>] [--join=<values>] [source1] [source2] [source3] ...
# Example: ./get-logs.sh
# Example: ./get-logs.sh usa il
# Example: ./get-logs.sh --git-dir mydir
# Example: ./get-logs.sh --git-dir=mydir --sort=ASC --limit=10 usa il
# Example: ./get-logs.sh --join=minimal_metadata,sponsors
# Note: This script assumes repositories have already been cloned. Sources are optional - if not provided, searches the entire git directory.
# Note: --join accepts comma-separated values: "minimal_metadata" (title, description, sources) and "sponsors"
# Note: This script requires 'fd' (a Rust-based alternative to find) to be installed

ALLOWED_JOIN_VALUES=("minimal_metadata" "sponsors")

# Set default values
GIT_DIR="tmp/git/windy-civi-pipelines"
SORT_ORDER="DESC"
LIMIT=""
JOIN="minimal_metadata"
SOURCES=()

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --git-dir=*)
      # Handle --git-dir=<value> format
      GIT_DIR="${1#*=}"
      shift
      ;;
    --git-dir)
      # Handle --git-dir <value> format
      if [ -z "$2" ]; then
        echo "Error: --git-dir requires a value"
        exit 1
      fi
      GIT_DIR="$2"
      shift 2
      ;;
    --sort=*)
      # Handle --sort=<value> format
      SORT_ORDER="${1#*=}"
      if [[ "$SORT_ORDER" != "ASC" && "$SORT_ORDER" != "DESC" ]]; then
        echo "Error: --sort must be either ASC or DESC"
        exit 1
      fi
      shift
      ;;
    --sort)
      # Handle --sort <value> format
      if [ -z "$2" ]; then
        echo "Error: --sort requires a value (ASC or DESC)"
        exit 1
      fi
      if [[ "$2" != "ASC" && "$2" != "DESC" ]]; then
        echo "Error: --sort must be either ASC or DESC"
        exit 1
      fi
      SORT_ORDER="$2"
      shift 2
      ;;
    --limit=*)
      # Handle --limit=<value> format
      LIMIT="${1#*=}"
      if ! [[ "$LIMIT" =~ ^[0-9]+$ ]] || [ "$LIMIT" -le 0 ]; then
        echo "Error: --limit must be a positive integer"
        exit 1
      fi
      shift
      ;;
    --limit)
      # Handle --limit <value> format
      if [ -z "$2" ]; then
        echo "Error: --limit requires a value (positive integer)"
        exit 1
      fi
      if ! [[ "$2" =~ ^[0-9]+$ ]] || [ "$2" -le 0 ]; then
        echo "Error: --limit must be a positive integer"
        exit 1
      fi
      LIMIT="$2"
      shift 2
      ;;
    --join=*)
      # Handle --join=<value> format
      JOIN="${1#*=}"
      shift
      ;;
    --join)
      # Handle --join <value> format
      if [ -z "$2" ]; then
        echo "Error: --join requires a value (comma-separated list)"
        exit 1
      fi
      JOIN="$2"
      shift 2
      ;;
    *)
      SOURCES+=("$1")
      shift
      ;;
  esac
done

# Validate join values if provided
if [[ -n "$JOIN" ]]; then
  # Split comma-separated values and validate
  IFS=',' read -ra JOIN_VALUES <<< "$JOIN"
  
  for join_val in "${JOIN_VALUES[@]}"; do
    join_val=$(echo "$join_val" | xargs)  # Trim whitespace
    valid=false
    for allowed in "${ALLOWED_JOIN_VALUES[@]}"; do
      if [[ "$join_val" == "$allowed" ]]; then
        valid=true
        break
      fi
    done
    if [[ "$valid" == false ]]; then
      echo "Error: Invalid join value '$join_val'. Allowed values are: ${ALLOWED_JOIN_VALUES[*]}"
      exit 1
    fi
  done
fi

# Sources are optional - if not provided, we'll search the entire git directory
# No need to exit if no sources are provided

# Check if git directory exists
SEARCH_DIR="$GIT_DIR"
if [ ! -d "$SEARCH_DIR" ]; then
    echo "Error: Git directory does not exist: $SEARCH_DIR"
    echo "Please clone the repositories first before running this script."
    exit 1
fi

SEARCH_DIR_TRIM="${SEARCH_DIR%/}"
if [[ -z "$SEARCH_DIR_TRIM" ]]; then
    SEARCH_DIR_TRIM="/"
fi

# Check if fd is available
if ! command -v fd >/dev/null 2>&1; then
    echo "Error: 'fd' command not found. Please install fd (https://github.com/sharkdp/fd)"
    exit 1
fi

# Optionally verify that expected repository directories exist
for source in "${SOURCES[@]}"; do
    if [ -z "$source" ]; then
        continue
    fi
    source=$(echo "$source" | xargs)
    repo_dir="$SEARCH_DIR/${source}-data-pipeline"
    if [ ! -d "$repo_dir" ]; then
        echo "Warning: Expected repository directory does not exist: $repo_dir" >&2
    fi
done

echo "Finding JSON files with 'logs/' in their path in: $SEARCH_DIR" >&2
echo "" >&2

# Use a temporary file to store file paths with timestamps for sorting
TMPFILE=$(mktemp)
trap "rm -f '$TMPFILE'" EXIT

# First pass: collect file paths with timestamps (without reading JSON contents)
# Stream through files one at a time using fd (Rust-based, faster than find)
fd -t f "\.json$" "$SEARCH_DIR" | grep "/logs/" | while IFS= read -r filepath; do
    # Skip empty lines
    if [[ -z "$filepath" ]]; then
        continue
    fi
    
    # Extract the timestamp from the filename
    # Pattern: .../logs/YYYYMMDDTHHMMSSZ_*.json
    if [[ "$filepath" =~ /logs/([0-9]{8}T[0-9]{6}Z)_ ]]; then
        timestamp="${BASH_REMATCH[1]}"
        echo "$timestamp|$filepath" >> "$TMPFILE"
    else
        # If no timestamp found, output with empty timestamp (will sort first/last)
        echo "|$filepath" >> "$TMPFILE"
    fi
done

# Second pass: sort, filter, then read JSON contents only for selected files
{
    # Sort based on SORT_ORDER
    if [[ "$SORT_ORDER" == "DESC" ]]; then
        sort -r "$TMPFILE"
    else
        sort "$TMPFILE"
    fi
} | cut -d'|' -f2- 2>/dev/null | {
    # Apply limit if specified, otherwise output all
    if [[ -n "$LIMIT" ]]; then
        head -n "$LIMIT"
    else
        cat
    fi
} | while IFS= read -r filepath; do
    # Skip empty lines
    if [[ -z "$filepath" ]]; then
        continue
    fi

    # Determine relative path for filename field
    relative_path="$filepath"
    if [[ "$SEARCH_DIR_TRIM" == "/" ]]; then
        relative_path="${relative_path#/}"
    elif [[ "$relative_path" == "$SEARCH_DIR_TRIM/"* ]]; then
        relative_path="${relative_path#"$SEARCH_DIR_TRIM/"}"
    fi
 
    # Detect vote event files so we can summarize their content
    is_vote_event=false
    if [[ "$relative_path" == *".vote_event."* ]]; then
        is_vote_event=true
    fi
 
    # Check for metadata.json one directory above the log file (similar to extract_name.sh)
    metadata_file=$(dirname "$filepath")/../metadata.json
    has_metadata=false
    if [[ -f "$metadata_file" ]]; then
        has_metadata=true
    fi

    if [[ "$is_vote_event" == true ]]; then
        vote_event_result="unknown"
        if [[ "$relative_path" =~ \.vote_event\.([^.]+)\. ]]; then
            vote_event_result="${BASH_REMATCH[1]}"
        fi

        if command -v jq >/dev/null 2>&1; then
            if [[ -n "$JOIN" && "$has_metadata" == true ]]; then
                join_object='{log: {result: $result}, filename: $filename'
                IFS=',' read -ra JOIN_VALUES <<< "$JOIN"
                for join_val in "${JOIN_VALUES[@]}"; do
                    join_val=$(echo "$join_val" | xargs)  # Trim whitespace
                    case "$join_val" in
                        minimal_metadata)
                            join_object+=", minimal_metadata: (\$metadata[0] | {title, description, sources})"
                            ;;
                        sponsors)
                            join_object+=", sponsors: (\$metadata[0] | {sponsors})"
                            ;;
                    esac
                done
                join_object+="}"
                wrapped_json=$(jq -nc --arg filename "$relative_path" --arg result "$vote_event_result" --slurpfile metadata "$metadata_file" "$join_object" 2>/dev/null)
            else
                wrapped_json=$(jq -nc --arg filename "$relative_path" --arg result "$vote_event_result" '{log: {result: $result}, filename: $filename}' 2>/dev/null)
            fi
        else
            vote_event_result_escaped=$(printf '%s' "$vote_event_result" | sed 's/\\/\\\\/g; s/"/\\"/g')
            log_json="{\"result\":\"$vote_event_result_escaped\"}"
            filename_escaped=$(printf '%s' "$relative_path" | sed 's/\\/\\\\/g; s/"/\\"/g')
            if [[ -n "$JOIN" && "$has_metadata" == true ]]; then
                metadata_content=$(cat "$metadata_file" 2>/dev/null | tr -d '\n' | sed 's/[[:space:]]\+/ /g')
                if [[ -n "$metadata_content" ]]; then
                    wrapped_json="{\"log\":$log_json,\"filename\":\"$filename_escaped\",\"minimal_metadata\":$metadata_content}"
                else
                    wrapped_json="{\"log\":$log_json,\"filename\":\"$filename_escaped\"}"
                fi
            else
                wrapped_json="{\"log\":$log_json,\"filename\":\"$filename_escaped\"}"
            fi
        fi

        if [[ -n "$wrapped_json" ]]; then
            echo "$wrapped_json"
        fi
        continue
    fi

    # Read JSON file contents and wrap in a new object with 'log' key
    # Also join metadata fields if --join is specified
    if command -v jq >/dev/null 2>&1; then
        if [[ -n "$JOIN" && "$has_metadata" == true ]]; then
            # Build jq expression to create keys for each join value
            join_object="{log: ., filename: \$filename"
            IFS=',' read -ra JOIN_VALUES <<< "$JOIN"
            for join_val in "${JOIN_VALUES[@]}"; do
                join_val=$(echo "$join_val" | xargs)  # Trim whitespace
                case "$join_val" in
                    minimal_metadata)
                        join_object+=", minimal_metadata: (\$metadata[0] | {title, description, sources})"
                        ;;
                    sponsors)
                        join_object+=", sponsors: (\$metadata[0] | {sponsors})"
                        ;;
                esac
            done
            join_object+="}"
            
            # Use jq to merge log content and join specified metadata fields
            wrapped_json=$(jq -c --arg filename "$relative_path" --slurpfile metadata "$metadata_file" "$join_object" "$filepath" 2>/dev/null)
        else
            # Use jq to wrap the content in a 'log' key only
            wrapped_json=$(jq -c --arg filename "$relative_path" '{log: ., filename: $filename}' "$filepath" 2>/dev/null)
        fi
    else
        # Fallback: read file, compact it, and manually wrap
        # Note: Without jq, we cannot easily extract specific fields from metadata
        json_content=$(cat "$filepath" 2>/dev/null | tr -d '\n' | sed 's/[[:space:]]\+/ /g')
        filename_escaped=$(printf '%s' "$relative_path" | sed 's/\\/\\\\/g; s/"/\\"/g')
        if [[ -n "$json_content" ]]; then
            if [[ -n "$JOIN" && "$has_metadata" == true ]]; then
                # Read and compact metadata (without jq, we can't easily extract specific fields)
                # This fallback is only used if jq is not available
                # Note: Without jq, we cannot properly extract fields per join value, so this is a simplified fallback
                metadata_content=$(cat "$metadata_file" 2>/dev/null | tr -d '\n' | sed 's/[[:space:]]\+/ /g')
                if [[ -n "$metadata_content" ]]; then
                    # Build minimal_metadata structure - without jq we can't properly extract per-join-value fields
                    # This is a simplified fallback that includes all metadata
                    wrapped_json="{\"log\":$json_content,\"filename\":\"$filename_escaped\",\"minimal_metadata\":$metadata_content}"
                else
                    wrapped_json="{\"log\":$json_content,\"filename\":\"$filename_escaped\"}"
                fi
            else
                # Wrap the JSON content directly (it's already valid JSON)
                wrapped_json="{\"log\":$json_content,\"filename\":\"$filename_escaped\"}"
            fi
        else
            wrapped_json=""
        fi
    fi
    
    # Output wrapped JSON content if successfully read
    if [[ -n "$wrapped_json" ]]; then
        echo "$wrapped_json"
    fi
done
