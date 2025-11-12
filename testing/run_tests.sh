#!/bin/bash
# Master test runner for local testing
# This script runs all tests that don't require GitHub Actions infrastructure

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo ""
echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}  GitHub Actions Test Suite${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""
echo "Repository: $REPO_ROOT"
echo ""

# Track overall results
SUITE_PASSED=0
SUITE_FAILED=0

# Helper functions
run_test_suite() {
    local name="$1"
    local script="$2"

    echo ""
    echo -e "${BLUE}Running: $name${NC}"
    echo "----------------------------------------"

    if [ ! -f "$script" ]; then
        echo -e "${RED}✗ Test script not found: $script${NC}"
        ((SUITE_FAILED++))
        return 1
    fi

    if bash "$script"; then
        echo -e "${GREEN}✓ $name passed${NC}"
        ((SUITE_PASSED++))
        return 0
    else
        echo -e "${RED}✗ $name failed${NC}"
        ((SUITE_FAILED++))
        return 1
    fi
}

# Run shell script tests
run_test_suite "Shell Script Unit Tests" "$SCRIPT_DIR/test_shell_scripts.sh"

# TODO: Add more test suites here as they are created
# run_test_suite "Python Script Tests" "$SCRIPT_DIR/test_python_scripts.py"
# run_test_suite "Integration Tests" "$SCRIPT_DIR/test_integration.sh"

# Print final summary
echo ""
echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}  Test Summary${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""
echo "Test suites passed: ${GREEN}$SUITE_PASSED${NC}"

if [ $SUITE_FAILED -gt 0 ]; then
    echo "Test suites failed: ${RED}$SUITE_FAILED${NC}"
    echo ""
    echo -e "${RED}Overall result: FAILED${NC}"
    exit 1
else
    echo ""
    echo -e "${GREEN}Overall result: ALL TESTS PASSED ✓${NC}"
    exit 0
fi
