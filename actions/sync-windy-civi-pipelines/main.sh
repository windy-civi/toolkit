#!/bin/bash

# Script to clone/pull multiple GitHub repositories
# Usage: [TOKEN=<token>] ./clone_repos.sh [--git-dir <dir>] [--git-dir=<dir>] <source1> [source2] [source3] ...
# Example: ./clone_repos.sh usa il
# Example: TOKEN=xxx ./clone_repos.sh --git-dir mydir usa il
# Outputs: directories and repository-count to GITHUB_OUTPUT

# Set default values
TOKEN="${TOKEN:-}"
GIT_DIR="tmp/git/windy-civi-pipelines"

# Initialize arrays
DIRECTORIES=()
REPO_COUNT=0
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
    *)
      SOURCES+=("$1")
      shift
      ;;
  esac
done

# Check if any sources were provided
if [ ${#SOURCES[@]} -eq 0 ]; then
  echo "Error: No sources provided"
  echo "Usage: [TOKEN=<token>] ./clone_repos.sh [--git-dir <dir>] [--git-dir=<dir>] <source1> [source2] [source3] ..."
  exit 1
fi

# Create output directory
mkdir -p "$GIT_DIR"

# Function to clone or pull a single repository
clone_or_pull_repo() {
  local source="$1"
  local repo="windy-civi-pipelines/${source}-data-pipeline"
  local dir="$GIT_DIR/${source}-data-pipeline"
  
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
    
    # Update remote URL if token is provided (in case it wasn't set before)
    if [ -n "$TOKEN" ]; then
      (cd "$dir" && git remote set-url origin "$clone_url")
    fi
    
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
    if ! git clone --depth 1 "$clone_url" "$dir"; then
      echo "Error: Failed to shallow clone repository $repo"
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

