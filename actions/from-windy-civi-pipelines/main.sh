#!/bin/bash

# Script to clone/pull multiple GitHub repositories and find all JSON files that have 'logs/' in their path
# Usage: [TOKEN=<token>] ./clone_to_log.sh [--output-dir <dir>] [--output-dir=<dir>] [--sort <ASC|DESC>] [--sort=<ASC|DESC>] [--limit <n>] [--limit=<n>] [--output <file>] [--output=<file>] <source1> [source2] [source3] ...
# Example: ./clone_to_log.sh usa il
# Example: TOKEN=xxx ./clone_to_log.sh --output-dir mydir usa il
# Example: ./clone_to_log.sh --output-dir=mydir --sort=ASC --limit=10 --output=./mylog.log usa il
# Outputs: directories and repository-count to GITHUB_OUTPUT

# Set default values
TOKEN="${TOKEN:-}"
OUTPUT_DIR="logs/windy-civi-pipelines"
SORT_ORDER="DESC"
LIMIT=""
OUTPUT_FILE="./logs/windy-civi-pipelines.log"

# Initialize arrays
DIRECTORIES=()
REPO_COUNT=0
SOURCES=()

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --output-dir=*)
      # Handle --output-dir=<value> format
      OUTPUT_DIR="${1#*=}"
      shift
      ;;
    --output-dir)
      # Handle --output-dir <value> format
      if [ -z "$2" ]; then
        echo "Error: --output-dir requires a value"
        exit 1
      fi
      OUTPUT_DIR="$2"
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
    --output=*)
      # Handle --output=<value> format
      OUTPUT_FILE="${1#*=}"
      shift
      ;;
    --output)
      # Handle --output <value> format
      if [ -z "$2" ]; then
        echo "Error: --output requires a value (file path)"
        exit 1
      fi
      OUTPUT_FILE="$2"
      shift 2
      ;;
    *)
      SOURCES+=("$1")
      shift
      ;;
  esac
done

# Check if any sources were provided
if [ ${#SOURCES[@]} -eq 0 ]; then
  echo "Error: No sources provided"
  echo "Usage: [TOKEN=<token>] ./clone_to_log.sh [--output-dir <dir>] [--output-dir=<dir>] [--sort <ASC|DESC>] [--sort=<ASC|DESC>] [--limit <n>] [--limit=<n>] [--output <file>] [--output=<file>] <source1> [source2] [source3] ..."
  exit 1
fi

# Create output directory
mkdir -p "$OUTPUT_DIR"
mkdir -p "$(dirname "$OUTPUT_FILE")"

# Function to clone or pull a single repository
clone_or_pull_repo() {
  local source="$1"
  local repo="windy-civi-pipelines/${source}-data-pipeline"
  local dir="$OUTPUT_DIR/${source}-data-pipeline"
  
  # Build clone URL - use token if provided, otherwise use public URL
  if [ -n "$TOKEN" ]; then
    clone_url="https://${TOKEN}@github.com/${repo}.git"
  else
    clone_url="https://github.com/${repo}.git"
  fi
  
  # Check if repository already exists
  if [ -d "$dir" ] && [ -d "$dir/.git" ]; then
    echo "Repository already exists: $repo"
    echo "Pulling latest changes from $dir"
    
    # Pull the latest changes
    if ! (cd "$dir" && git pull); then
      echo "Error: Failed to pull repository $repo"
      exit 1
    fi
    
    echo "Successfully pulled $repo"
  else
    echo "Cloning repository: $repo"
    
    # Remove existing directory if it exists (but is not a git repo)
    if [ -d "$dir" ]; then
      echo "Removing existing directory: $dir"
      rm -rf "$dir"
    fi
    
    # Clone the repository with error handling
    if ! git clone "$clone_url" "$dir"; then
      echo "Error: Failed to clone repository $repo"
      exit 1
    fi
    
    # Verify the clone was successful
    if [ ! -d "$dir" ] || [ ! -d "$dir/.git" ]; then
      echo "Error: Repository clone verification failed for $repo"
      exit 1
    fi
    
    echo "Successfully cloned $repo into $dir"
  fi
  
  # Add to directories array
  DIRECTORIES+=("$dir")
  REPO_COUNT=$((REPO_COUNT + 1))
}

# Process each source from command-line arguments
echo "Processing sources: ${SOURCES[*]}"
echo ""

for source in "${SOURCES[@]}"; do
  # Skip empty arguments
  if [ -z "$source" ]; then
    continue
  fi
  
  # Remove any whitespace
  source=$(echo "$source" | xargs)
  
  clone_or_pull_repo "$source"
done

echo ""
echo "Cloning/pulling completed successfully!"
echo "Directories: ${DIRECTORIES[*]}"
echo "Repository count: $REPO_COUNT"
echo ""

# Set outputs if GITHUB_OUTPUT is set
if [ -n "$GITHUB_OUTPUT" ]; then
  IFS=','
  echo "directories=${DIRECTORIES[*]}" >> "$GITHUB_OUTPUT"
  echo "repository-count=$REPO_COUNT" >> "$GITHUB_OUTPUT"
fi

# Now find JSON files with 'logs/' in their path
SEARCH_DIR="$OUTPUT_DIR"

# Check if directory exists
if [ ! -d "$SEARCH_DIR" ]; then
    echo "Error: Search directory does not exist: $SEARCH_DIR"
    exit 1
fi

echo "Finding JSON files with 'logs/' in their path in: $SEARCH_DIR"
echo "Writing to: $OUTPUT_FILE"
echo ""

# Use a temporary file to store items with timestamps for sorting
TMPFILE=$(mktemp)
trap "rm -f '$TMPFILE'" EXIT

# Stream through files one at a time using find
# Process each file immediately and buffer for sorting
# Using find with -path filter is more efficient than piping through grep
find "$SEARCH_DIR" -type f -name "*.json" -path "*/logs/*" | while IFS= read -r line; do
    # Skip empty lines
    if [[ -z "$line" ]]; then
        continue
    fi
    
    # Extract the timestamp from the filename
    # Pattern: .../logs/YYYYMMDDTHHMMSSZ_*.json
    if [[ "$line" =~ /logs/([0-9]{8}T[0-9]{6}Z)_ ]]; then
        timestamp="${BASH_REMATCH[1]}"
        echo "$timestamp|$line" >> "$TMPFILE"
    else
        # If no timestamp found, output with empty timestamp (will sort first/last)
        echo "|$line" >> "$TMPFILE"
    fi
done

# Write the sorted/limited results to the output file as a stream
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
} > "$OUTPUT_FILE" || true

echo ""
echo "Search completed. Results written to: $OUTPUT_FILE"
