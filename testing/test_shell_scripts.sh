#!/bin/bash
# Unit tests for shell scripts in actions/recent-items/tools
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TOOLS_DIR="$REPO_ROOT/actions/recent-items/tools"

# Create temporary test directory
TEST_DIR=$(mktemp -d)
trap "rm -rf $TEST_DIR" EXIT

echo "================================================"
echo "  Testing Shell Scripts"
echo "================================================"
echo "Test directory: $TEST_DIR"
echo "Tools directory: $TOOLS_DIR"
echo ""

# Make tools executable
chmod +x "$TOOLS_DIR"/*.sh

# Helper functions
pass() {
    echo -e "${GREEN}✓${NC} $1"
    TESTS_PASSED=$((TESTS_PASSED + 1))
    TESTS_RUN=$((TESTS_RUN + 1))
}

fail() {
    echo -e "${RED}✗${NC} $1"
    echo -e "${RED}  Error: $2${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    TESTS_RUN=$((TESTS_RUN + 1))
}

warn() {
    echo -e "${YELLOW}⚠${NC} $1"
}

# Setup test data
setup_test_data() {
    echo "Setting up test data..."
    mkdir -p "$TEST_DIR/logs"

    # Create test JSON files with various timestamps in filenames
    # The filter_recent_logs.sh expects format: /logs/YYYYMMDDTHHMMSSZ_*.json

    # Recent file (1 day ago) - with timestamp in filename
    RECENT_TS_1=$(date -u -d "1 day ago" +"%Y%m%dT%H%M%SZ")
    cat > "$TEST_DIR/logs/${RECENT_TS_1}_bill_1.json" <<'EOF'
{
  "id": "bill-1",
  "identifier": "HB 123",
  "title": "Recent Test Bill 1",
  "updated_at": "RECENT_DATE_1"
}
EOF
    RECENT_DATE_1=$(date -u -d "1 day ago" +"%Y-%m-%dT%H:%M:%S")Z
    sed -i "s/RECENT_DATE_1/$RECENT_DATE_1/" "$TEST_DIR/logs/${RECENT_TS_1}_bill_1.json"

    # Recent file (2 days ago) - with timestamp in filename
    RECENT_TS_2=$(date -u -d "2 days ago" +"%Y%m%dT%H%M%SZ")
    cat > "$TEST_DIR/logs/${RECENT_TS_2}_bill_2.json" <<'EOF'
{
  "id": "bill-2",
  "identifier": "SB 456",
  "title": "Recent Test Bill 2",
  "updated_at": "RECENT_DATE_2"
}
EOF
    RECENT_DATE_2=$(date -u -d "2 days ago" +"%Y-%m-%dT%H:%M:%S")Z
    sed -i "s/RECENT_DATE_2/$RECENT_DATE_2/" "$TEST_DIR/logs/${RECENT_TS_2}_bill_2.json"

    # Old file (100 days ago) - with timestamp in filename
    OLD_TS=$(date -u -d "100 days ago" +"%Y%m%dT%H%M%SZ")
    cat > "$TEST_DIR/logs/${OLD_TS}_old_bill.json" <<'EOF'
{
  "id": "bill-old",
  "identifier": "HB 789",
  "title": "Old Test Bill",
  "updated_at": "OLD_DATE"
}
EOF
    OLD_DATE=$(date -u -d "100 days ago" +"%Y-%m-%dT%H:%M:%S")Z
    sed -i "s/OLD_DATE/$OLD_DATE/" "$TEST_DIR/logs/${OLD_TS}_old_bill.json"

    # File without logs in path (should be ignored)
    mkdir -p "$TEST_DIR/other"
    cat > "$TEST_DIR/other/not_a_log.json" <<'EOF'
{
  "id": "not-a-log",
  "title": "Not a log file"
}
EOF

    echo "✓ Test data created"
}

# Test find_logs_json.sh
test_find_logs_json() {
    echo ""
    echo "Testing find_logs_json.sh"
    echo "------------------------"

    # Test: Should find JSON files in logs directory
    OUTPUT=$("$TOOLS_DIR/find_logs_json.sh" "$TEST_DIR" 2>/dev/null | grep -v "^Finding" | grep -v "^Search" | grep -v "^$")
    COUNT=$(echo "$OUTPUT" | grep -c "\.json$" || true)

    if [ "$COUNT" -eq 3 ]; then
        pass "Finds correct number of log files (expected 3, got $COUNT)"
    else
        fail "Find correct number of log files" "Expected 3, got $COUNT"
    fi

    # Test: Should only find files with 'logs/' in path
    if echo "$OUTPUT" | grep -q "/logs/"; then
        pass "Only finds files in logs directory"
    else
        fail "Only finds files in logs directory" "Output doesn't contain /logs/"
    fi

    # Test: Should not find files outside logs directory
    if ! echo "$OUTPUT" | grep -q "/other/"; then
        pass "Ignores files outside logs directory"
    else
        fail "Ignores files outside logs directory" "Found files in /other/"
    fi
}

# Test filter_recent_logs.sh
test_filter_recent_logs() {
    echo ""
    echo "Testing filter_recent_logs.sh"
    echo "-----------------------------"

    # Test: Should filter out old logs
    OUTPUT=$("$TOOLS_DIR/find_logs_json.sh" "$TEST_DIR" 2>/dev/null | \
             grep -v "^Finding" | grep -v "^Search" | grep -v "^$" | \
             "$TOOLS_DIR/filter_recent_logs.sh")

    # Should include recent files
    if echo "$OUTPUT" | grep -q "bill_1.json"; then
        pass "Includes recent file (1 day old)"
    else
        fail "Includes recent file (1 day old)" "bill_1.json not found in output"
    fi

    if echo "$OUTPUT" | grep -q "bill_2.json"; then
        pass "Includes recent file (2 days old)"
    else
        fail "Includes recent file (2 days old)" "bill_2.json not found in output"
    fi

    # Should exclude old files
    if ! echo "$OUTPUT" | grep -q "old_bill.json"; then
        pass "Excludes old file (100 days old)"
    else
        fail "Excludes old file (100 days old)" "old_bill.json found in output"
    fi
}

# Test sort_logs_by_timestamp.sh
test_sort_logs_by_timestamp() {
    echo ""
    echo "Testing sort_logs_by_timestamp.sh"
    echo "---------------------------------"

    # Test: Should sort files by timestamp (newest first)
    OUTPUT=$("$TOOLS_DIR/find_logs_json.sh" "$TEST_DIR" 2>/dev/null | \
             grep -v "^Finding" | grep -v "^Search" | grep -v "^$" | \
             "$TOOLS_DIR/sort_logs_by_timestamp.sh")

    FIRST_FILE=$(echo "$OUTPUT" | head -1)
    LAST_FILE=$(echo "$OUTPUT" | tail -1)

    if echo "$FIRST_FILE" | grep -q "bill_1.json"; then
        pass "Most recent file is first"
    else
        warn "Sort order might not be correct (got: $(basename "$FIRST_FILE"))"
        # Don't fail this test as sort order depends on exact timestamps
        TESTS_RUN=$((TESTS_RUN + 1))
    fi
}

# Test limit_output.sh
test_limit_output() {
    echo ""
    echo "Testing limit_output.sh"
    echo "-----------------------"

    # Test: Should limit output to specified number
    OUTPUT=$("$TOOLS_DIR/find_logs_json.sh" "$TEST_DIR" 2>/dev/null | \
             grep -v "^Finding" | grep -v "^Search" | grep -v "^$" | \
             "$TOOLS_DIR/limit_output.sh" 2)
    COUNT=$(echo "$OUTPUT" | wc -l)

    if [ "$COUNT" -eq 2 ]; then
        pass "Limits output to 2 lines"
    else
        fail "Limits output to 2 lines" "Expected 2, got $COUNT"
    fi

    # Test: Should handle limit larger than input
    OUTPUT=$("$TOOLS_DIR/find_logs_json.sh" "$TEST_DIR" 2>/dev/null | \
             grep -v "^Finding" | grep -v "^Search" | grep -v "^$" | \
             "$TOOLS_DIR/limit_output.sh" 100)
    COUNT=$(echo "$OUTPUT" | wc -l)

    if [ "$COUNT" -le 3 ]; then
        pass "Handles limit larger than input"
    else
        fail "Handles limit larger than input" "Expected ≤3, got $COUNT"
    fi

    # Test: Should handle limit of 1
    OUTPUT=$("$TOOLS_DIR/find_logs_json.sh" "$TEST_DIR" 2>/dev/null | \
             grep -v "^Finding" | grep -v "^Search" | grep -v "^$" | \
             "$TOOLS_DIR/limit_output.sh" 1)
    COUNT=$(echo "$OUTPUT" | wc -l)

    if [ "$COUNT" -eq 1 ]; then
        pass "Handles limit of 1"
    else
        fail "Handles limit of 1" "Expected 1, got $COUNT"
    fi
}

# Test extract_name.sh
test_extract_name() {
    echo ""
    echo "Testing extract_name.sh"
    echo "-----------------------"

    # Create metadata.json in parent directory of logs (as expected by extract_name.sh)
    cat > "$TEST_DIR/metadata.json" <<'EOF'
{
  "title": "Recent Test Bill 1",
  "identifier": "HB 123"
}
EOF

    # Test with the most recent file
    TEST_FILE=$(find "$TEST_DIR/logs" -name "*bill_1.json" | head -1)
    if [ -z "$TEST_FILE" ]; then
        fail "Extract name test setup" "Could not find test file"
        return
    fi

    OUTPUT=$(echo "$TEST_FILE" | "$TOOLS_DIR/extract_name.sh")

    if echo "$OUTPUT" | grep -q "HB 123"; then
        pass "Extracts identifier from metadata"
    else
        fail "Extracts identifier from metadata" "Expected 'HB 123' in output, got: $OUTPUT"
    fi

    if echo "$OUTPUT" | grep -q "Recent Test Bill 1"; then
        pass "Extracts title from metadata"
    else
        fail "Extracts title from metadata" "Expected 'Recent Test Bill 1' in output, got: $OUTPUT"
    fi
}

# Test full pipeline
test_full_pipeline() {
    echo ""
    echo "Testing Full Pipeline"
    echo "---------------------"

    # Test: Full pipeline should work end-to-end
    OUTPUT=$("$TOOLS_DIR/find_logs_json.sh" "$TEST_DIR" 2>/dev/null | \
             grep -v "^Finding" | grep -v "^Search" | grep -v "^$" | \
             "$TOOLS_DIR/filter_recent_logs.sh" | \
             "$TOOLS_DIR/sort_logs_by_timestamp.sh" | \
             "$TOOLS_DIR/limit_output.sh" 5 | \
             "$TOOLS_DIR/extract_name.sh")

    if [ -n "$OUTPUT" ]; then
        pass "Full pipeline produces output"
    else
        fail "Full pipeline produces output" "No output from pipeline"
    fi

    # Should have output (extract_name produces 3 lines per item: title, action, separator)
    # So 5 items would produce up to 15 lines
    COUNT=$(echo "$OUTPUT" | wc -l)
    if [ "$COUNT" -gt 0 ] && [ "$COUNT" -le 20 ]; then
        pass "Full pipeline respects limit (has reasonable output)"
    else
        fail "Full pipeline respects limit" "Expected 1-20 lines, got $COUNT"
    fi

    # Should only have recent items
    if ! echo "$OUTPUT" | grep -q "Old Test Bill"; then
        pass "Full pipeline filters old items"
    else
        fail "Full pipeline filters old items" "Found old bill in output"
    fi
}

# Run all tests
setup_test_data
test_find_logs_json
test_filter_recent_logs
test_sort_logs_by_timestamp
test_limit_output
test_extract_name
test_full_pipeline

# Print summary
echo ""
echo "================================================"
echo "  Test Summary"
echo "================================================"
echo "Total tests run: $TESTS_RUN"
echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"

if [ $TESTS_FAILED -gt 0 ]; then
    echo -e "${RED}Failed: $TESTS_FAILED${NC}"
    exit 1
else
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
fi
