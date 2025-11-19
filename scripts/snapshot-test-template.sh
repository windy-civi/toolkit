#!/bin/bash
# Snapshot Test Template
# Copy this template to your action directory and customize it for your action
#
# Usage:
#   1. Copy this file to actions/<your-action>/test.sh
#   2. Make it executable: chmod +x test.sh
#   3. Update the variables below for your action
#   4. Implement the process_test_case function for your action
#   5. Run: ./test.sh
#   6. Update snapshots: UPDATE=1 ./test.sh

set -e

# ============================================================================
# CONFIGURATION - Customize these for your action
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_CASES_DIR="$SCRIPT_DIR/test-cases"           # Directory containing test input files
SNAPSHOTS_DIR="$TEST_CASES_DIR/__snapshots__"     # Directory for expected output snapshots
ACTION_SCRIPT="$SCRIPT_DIR/main.py"               # Your action's main script

# Source the centralized snapshot testing library
source "$SCRIPT_DIR/../../scripts/snapshot-test-lib.sh"

# ============================================================================
# TEST CASE PROCESSOR - Customize this for your action
# ============================================================================

# Process a single test case
# Args:
#   $1: Input file path (e.g., test-cases/example1.json)
# Returns:
#   0 if test passed, 1 if failed
process_test_case() {
    local input_file="$1"
    local basename=$(basename "$input_file" .json)  # Change extension as needed
    local expected_file="$SNAPSHOTS_DIR/${basename}.out"  # Change output extension as needed
    local actual_file=$(mktemp)

    # TODO: Customize this command to run your action
    # Example: Run your action and capture output
    if ! python3 "$ACTION_SCRIPT" --input "$input_file" --output "$actual_file" 2>&1; then
        echo -e "${SNAPSHOT_RED}✗${SNAPSHOT_NC} Failed to run action for $basename"
        rm -f "$actual_file"
        ((SNAPSHOT_FAILED++))
        return 1
    fi

    # Use the centralized snapshot comparison function
    snapshot_compare "$basename" "$actual_file" "$expected_file"
}

# ============================================================================
# MAIN TEST RUNNER - Usually no need to modify this
# ============================================================================

main() {
    # Initialize snapshot testing
    snapshot_test_init "My Action Test Runner" "$SNAPSHOTS_DIR"  # Customize the name

    echo "Looking for test files in: $TEST_CASES_DIR"
    echo "Snapshots directory: $SNAPSHOTS_DIR"
    echo ""

    # Find all test input files (customize the pattern)
    local test_files=()
    while IFS= read -r -d '' file; do
        test_files+=("$file")
    done < <(find "$TEST_CASES_DIR" -maxdepth 1 -name "*.json" -type f -print0)  # Change *.json to your input pattern

    if [ ${#test_files[@]} -eq 0 ]; then
        echo -e "${SNAPSHOT_YELLOW}No test files found in test cases directory${SNAPSHOT_NC}"
        exit 0
    fi

    echo "Found ${#test_files[@]} test file(s) to process:"
    for file in "${test_files[@]}"; do
        echo "  - $(basename "$file")"
    done
    echo ""

    # Process each test file
    for test_file in "${test_files[@]}"; do
        process_test_case "$test_file" || true  # Continue even if a test fails
    done

    # Clean up orphaned snapshot files
    # Args: input_dir, snapshots_dir, input_pattern, snapshot_extension
    snapshot_cleanup "$TEST_CASES_DIR" "$SNAPSHOTS_DIR" "*.json" ".out"  # Customize extensions

    # Print summary and exit
    snapshot_test_summary
}

# Run main function
main
