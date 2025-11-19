#!/bin/bash
# Snapshot Testing Library
# A centralized framework for testing GitHub Actions with file snapshot comparison
#
# Usage:
#   1. Source this library in your action's test.sh: source "$(dirname "$0")/../../scripts/snapshot-test-lib.sh"
#   2. Initialize: snapshot_test_init "Test Name" "$SNAPSHOTS_DIR"
#   3. For each test case, generate output and call: snapshot_compare "test-name" "$actual_file" "$expected_file"
#   4. Clean up orphans: snapshot_cleanup "$EXAMPLES_DIR" "$SNAPSHOTS_DIR" "*.yml" ".html"
#   5. Print summary: snapshot_test_summary
#
# Environment Variables:
#   UPDATE=1    - Update snapshots instead of comparing them

set -e

# Colors for output
export SNAPSHOT_RED='\033[0;31m'
export SNAPSHOT_GREEN='\033[0;32m'
export SNAPSHOT_YELLOW='\033[1;33m'
export SNAPSHOT_BLUE='\033[0;34m'
export SNAPSHOT_NC='\033[0m' # No Color

# Test counters
export SNAPSHOT_PASSED=0
export SNAPSHOT_FAILED=0
export SNAPSHOT_UPDATE_MODE="${UPDATE:-0}"
export SNAPSHOT_DIR=""
export SNAPSHOT_TEST_NAME=""

# Initialize the snapshot test environment
# Args:
#   $1: Test name (e.g., "Report Publisher")
#   $2: Snapshots directory path
snapshot_test_init() {
    local test_name="$1"
    local snapshots_dir="$2"

    SNAPSHOT_TEST_NAME="$test_name"
    SNAPSHOT_DIR="$snapshots_dir"
    SNAPSHOT_PASSED=0
    SNAPSHOT_FAILED=0

    # Ensure snapshots directory exists
    mkdir -p "$SNAPSHOT_DIR"

    # Print header
    echo ""
    local header_width=50
    local padding=$(( (header_width - ${#test_name} - 2) / 2 ))
    local line=$(printf '%*s' "$header_width" | tr ' ' '═')
    echo "╔${line}╗"
    printf "║%*s%s%*s║\n" $padding "" "$test_name" $((header_width - padding - ${#test_name})) ""
    echo "╚${line}╝"
    echo ""

    if [ "$SNAPSHOT_UPDATE_MODE" = "1" ]; then
        echo -e "${SNAPSHOT_YELLOW}Mode: UPDATE (snapshots will be updated)${SNAPSHOT_NC}"
    else
        echo -e "${SNAPSHOT_YELLOW}Mode: TEST (snapshots will be compared)${SNAPSHOT_NC}"
    fi
    echo ""
}

# Compare actual output with expected snapshot
# Args:
#   $1: Test case name (for display)
#   $2: Actual file path
#   $3: Expected file path (snapshot)
#   $4: (optional) "keep-actual" to not delete the actual file after comparison
# Returns:
#   0 if test passed, 1 if failed
snapshot_compare() {
    local test_name="$1"
    local actual_file="$2"
    local expected_file="$3"
    local keep_actual="${4:-}"

    echo -e "${SNAPSHOT_YELLOW}Testing:${SNAPSHOT_NC} $test_name"

    # Check if actual file was generated
    if [ ! -f "$actual_file" ]; then
        echo -e "${SNAPSHOT_RED}✗${SNAPSHOT_NC} Actual output file not found: $actual_file"
        ((SNAPSHOT_FAILED++))
        return 1
    fi

    # Handle missing snapshot
    if [ ! -f "$expected_file" ]; then
        if [ "$SNAPSHOT_UPDATE_MODE" = "1" ]; then
            # Update mode: create the snapshot
            cp "$actual_file" "$expected_file"
            echo -e "${SNAPSHOT_GREEN}✓${SNAPSHOT_NC} Created snapshot: $(basename "$expected_file")"
            [ "$keep_actual" != "keep-actual" ] && rm -f "$actual_file"
            ((SNAPSHOT_PASSED++))
            return 0
        else
            # Test mode: fail with instructions
            echo -e "${SNAPSHOT_RED}✗${SNAPSHOT_NC} Expected snapshot not found: $(basename "$expected_file")"
            echo -e "${SNAPSHOT_YELLOW}  To create the snapshot, run:${SNAPSHOT_NC}"
            echo -e "${SNAPSHOT_YELLOW}    UPDATE=1 ./test.sh${SNAPSHOT_NC}"
            [ "$keep_actual" != "keep-actual" ] && rm -f "$actual_file"
            ((SNAPSHOT_FAILED++))
            return 1
        fi
    fi

    # Compare files
    if diff -q "$expected_file" "$actual_file" > /dev/null 2>&1; then
        echo -e "${SNAPSHOT_GREEN}✓${SNAPSHOT_NC} Snapshot matches: $(basename "$expected_file")"
        [ "$keep_actual" != "keep-actual" ] && rm -f "$actual_file"
        ((SNAPSHOT_PASSED++))
        return 0
    else
        # Snapshots differ
        if [ "$SNAPSHOT_UPDATE_MODE" = "1" ]; then
            # Update mode: update the snapshot
            cp "$actual_file" "$expected_file"
            echo -e "${SNAPSHOT_GREEN}✓${SNAPSHOT_NC} Updated snapshot: $(basename "$expected_file")"
            [ "$keep_actual" != "keep-actual" ] && rm -f "$actual_file"
            ((SNAPSHOT_PASSED++))
            return 0
        else
            # Test mode: fail with instructions
            echo -e "${SNAPSHOT_RED}✗${SNAPSHOT_NC} Snapshot differs: $(basename "$expected_file")"
            echo -e "${SNAPSHOT_YELLOW}  Differences:${SNAPSHOT_NC}"
            diff -u "$expected_file" "$actual_file" || true
            echo -e "${SNAPSHOT_YELLOW}  To update the snapshot, run:${SNAPSHOT_NC}"
            echo -e "${SNAPSHOT_YELLOW}    UPDATE=1 ./test.sh${SNAPSHOT_NC}"
            [ "$keep_actual" != "keep-actual" ] && rm -f "$actual_file"
            ((SNAPSHOT_FAILED++))
            return 1
        fi
    fi
}

# Compare the content of two directories
# Args:
#   $1: Test case name (for display)
#   $2: Actual directory path
#   $3: Expected directory path (snapshot)
#   $4: (optional) File pattern to compare (e.g., "*.json"), default is all files
# Returns:
#   0 if test passed, 1 if failed
snapshot_compare_dir() {
    local test_name="$1"
    local actual_dir="$2"
    local expected_dir="$3"
    local pattern="${4:-*}"

    echo -e "${SNAPSHOT_YELLOW}Testing directory:${SNAPSHOT_NC} $test_name"

    # Check if actual directory exists
    if [ ! -d "$actual_dir" ]; then
        echo -e "${SNAPSHOT_RED}✗${SNAPSHOT_NC} Actual output directory not found: $actual_dir"
        ((SNAPSHOT_FAILED++))
        return 1
    fi

    # Handle missing snapshot directory
    if [ ! -d "$expected_dir" ]; then
        if [ "$SNAPSHOT_UPDATE_MODE" = "1" ]; then
            # Update mode: create the snapshot
            mkdir -p "$expected_dir"
            cp -r "$actual_dir"/$pattern "$expected_dir/" 2>/dev/null || true
            local file_count=$(find "$expected_dir" -type f | wc -l)
            echo -e "${SNAPSHOT_GREEN}✓${SNAPSHOT_NC} Created snapshot directory with $file_count file(s): $(basename "$expected_dir")"
            ((SNAPSHOT_PASSED++))
            return 0
        else
            # Test mode: fail with instructions
            echo -e "${SNAPSHOT_RED}✗${SNAPSHOT_NC} Expected snapshot directory not found: $(basename "$expected_dir")"
            echo -e "${SNAPSHOT_YELLOW}  To create the snapshot, run:${SNAPSHOT_NC}"
            echo -e "${SNAPSHOT_YELLOW}    UPDATE=1 ./test.sh${SNAPSHOT_NC}"
            ((SNAPSHOT_FAILED++))
            return 1
        fi
    fi

    # Compare directory contents
    local diff_result
    if diff_result=$(diff -rq "$expected_dir" "$actual_dir" 2>&1 | grep -E "^(Files|Only)" || true); then
        if [ -z "$diff_result" ]; then
            echo -e "${SNAPSHOT_GREEN}✓${SNAPSHOT_NC} Directory snapshot matches: $(basename "$expected_dir")"
            ((SNAPSHOT_PASSED++))
            return 0
        else
            # Directories differ
            if [ "$SNAPSHOT_UPDATE_MODE" = "1" ]; then
                # Update mode: update the snapshot
                rm -rf "$expected_dir"
                mkdir -p "$expected_dir"
                cp -r "$actual_dir"/$pattern "$expected_dir/" 2>/dev/null || true
                local file_count=$(find "$expected_dir" -type f | wc -l)
                echo -e "${SNAPSHOT_GREEN}✓${SNAPSHOT_NC} Updated snapshot directory with $file_count file(s): $(basename "$expected_dir")"
                ((SNAPSHOT_PASSED++))
                return 0
            else
                # Test mode: fail with instructions
                echo -e "${SNAPSHOT_RED}✗${SNAPSHOT_NC} Directory snapshot differs: $(basename "$expected_dir")"
                echo -e "${SNAPSHOT_YELLOW}  Differences:${SNAPSHOT_NC}"
                echo "$diff_result" | head -20
                local diff_count=$(echo "$diff_result" | wc -l)
                if [ "$diff_count" -gt 20 ]; then
                    echo -e "${SNAPSHOT_YELLOW}  ... and $((diff_count - 20)) more differences${SNAPSHOT_NC}"
                fi
                echo -e "${SNAPSHOT_YELLOW}  To update the snapshot, run:${SNAPSHOT_NC}"
                echo -e "${SNAPSHOT_YELLOW}    UPDATE=1 ./test.sh${SNAPSHOT_NC}"
                ((SNAPSHOT_FAILED++))
                return 1
            fi
        fi
    else
        echo -e "${SNAPSHOT_GREEN}✓${SNAPSHOT_NC} Directory snapshot matches: $(basename "$expected_dir")"
        ((SNAPSHOT_PASSED++))
        return 0
    fi
}

# Clean up orphaned snapshot files
# Args:
#   $1: Input directory (e.g., examples/)
#   $2: Snapshots directory (e.g., examples/__snapshots__/)
#   $3: Input file pattern (e.g., "*.yml")
#   $4: Snapshot file extension (e.g., ".html")
#   $5: (optional) Exclude pattern (basename to skip, e.g., "workflow-example.yml")
snapshot_cleanup() {
    local input_dir="$1"
    local snapshots_dir="$2"
    local input_pattern="$3"
    local snapshot_ext="$4"
    local exclude_pattern="${5:-}"

    echo ""
    echo -e "${SNAPSHOT_YELLOW}Cleaning up orphaned snapshots...${SNAPSHOT_NC}"

    local cleaned=0
    if [ -d "$snapshots_dir" ]; then
        # Get input file extension from pattern
        local input_ext="${input_pattern#*.}"

        while IFS= read -r -d '' snapshot_file; do
            local snapshot_basename=$(basename "$snapshot_file" "$snapshot_ext")
            local corresponding_input="$input_dir/${snapshot_basename}.${input_ext}"

            # Check if corresponding input file exists
            if [ ! -f "$corresponding_input" ] || [[ "$exclude_pattern" != "" && "$(basename "$corresponding_input")" == "$exclude_pattern" ]]; then
                echo -e "${SNAPSHOT_YELLOW}  Removing orphaned:${SNAPSHOT_NC} $(basename "$snapshot_file")"
                rm -f "$snapshot_file"
                ((cleaned++))
            fi
        done < <(find "$snapshots_dir" -maxdepth 1 -name "*${snapshot_ext}" -type f -print0 2>/dev/null || true)
    fi

    if [ $cleaned -eq 0 ]; then
        echo -e "${SNAPSHOT_GREEN}  No orphaned snapshots found${SNAPSHOT_NC}"
    else
        echo -e "${SNAPSHOT_GREEN}  Cleaned up $cleaned orphaned snapshot(s)${SNAPSHOT_NC}"
    fi
}

# Print test summary and exit with appropriate code
snapshot_test_summary() {
    local total=$((SNAPSHOT_PASSED + SNAPSHOT_FAILED))

    echo ""
    echo "========================================="
    echo "Test Summary"
    echo "========================================="
    echo -e "${SNAPSHOT_GREEN}Passed:${SNAPSHOT_NC} $SNAPSHOT_PASSED"
    echo -e "${SNAPSHOT_RED}Failed:${SNAPSHOT_NC} $SNAPSHOT_FAILED"
    echo "Total:  $total"
    echo "========================================="

    if [ $SNAPSHOT_FAILED -eq 0 ]; then
        echo -e "\n${SNAPSHOT_GREEN}✓ All tests passed!${SNAPSHOT_NC}\n"
        exit 0
    else
        echo -e "\n${SNAPSHOT_RED}✗ Some tests failed${SNAPSHOT_NC}\n"
        exit 1
    fi
}

# Helper: Run a test case (wrapper for common pattern)
# Args:
#   $1: Test case name
#   $2: Command to generate output
#   $3: Expected snapshot file
# Returns:
#   0 if test passed, 1 if failed
snapshot_run_test() {
    local test_name="$1"
    local command="$2"
    local expected_file="$3"
    local actual_file=$(mktemp)

    echo -e "${SNAPSHOT_YELLOW}Running:${SNAPSHOT_NC} $test_name"

    # Execute the command and capture output
    if ! eval "$command" > "$actual_file" 2>&1; then
        echo -e "${SNAPSHOT_RED}✗${SNAPSHOT_NC} Failed to execute command for $test_name"
        cat "$actual_file"
        rm -f "$actual_file"
        ((SNAPSHOT_FAILED++))
        return 1
    fi

    # Compare with snapshot
    snapshot_compare "$test_name" "$actual_file" "$expected_file"
}
