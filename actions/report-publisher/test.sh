#!/bin/bash
# Test runner for Report Publisher
# Finds all .yml files in examples/ and compares generated HTML outputs with snapshots in test_snapshots/
# Set UPDATE=1 to update snapshots instead of comparing them

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXAMPLES_DIR="$SCRIPT_DIR/examples"
SNAPSHOTS_DIR="$EXAMPLES_DIR/__snapshots__"
PUBLISHER="$SCRIPT_DIR/publish.py"

# Source the centralized snapshot testing library
source "$SCRIPT_DIR/../../scripts/snapshot-test-lib.sh"

# Extract JSON from a YAML file
extract_json_from_yml() {
    local yml_file="$1"
    local in_run=false
    local in_echo=false
    local json=""
    local indent=""
    
    while IFS= read -r line; do
        # Check if we're entering a run: | block
        if [[ "$line" =~ ^[[:space:]]*run:[[:space:]]*\| ]]; then
            in_run=true
            # Capture the indentation
            indent="${line%%[^[:space:]]*}"
            continue
        fi
        
        # If we're in a run block
        if [ "$in_run" = true ]; then
            # Check if this line starts the echo command
            if [[ "$line" =~ echo[[:space:]]+\' ]]; then
                in_echo=true
                # Extract JSON from this line (everything after echo ')
                local rest="${line#*echo \'}"
                # Check if it ends on the same line
                if [[ "$rest" =~ \'[[:space:]]*\| ]]; then
                    # JSON is on one line
                    json="${rest%\' |*}"
                    break
                else
                    # JSON starts here, continue on next lines
                    json="$rest"
                fi
            elif [ "$in_echo" = true ]; then
                # Check if this line ends the JSON (contains ' |)
                if [[ "$line" =~ \'[[:space:]]*\| ]]; then
                    # Remove the closing quote and pipe
                    local rest="${line%\' |*}"
                    json="${json} ${rest}"
                    break
                else
                    # Continue collecting JSON
                    json="${json} ${line}"
                fi
            fi
            
            # Check if we've left the run block (line with less or equal indentation that's not part of the block)
            if [[ ! "$line" =~ ^${indent}[[:space:]] ]] && [ -n "${line// }" ]; then
                in_run=false
                in_echo=false
            fi
        fi
    done < "$yml_file"
    
    # Clean up the JSON: remove extra spaces and normalize
    json=$(echo "$json" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | tr '\n' ' ' | sed 's/[[:space:]]\+/ /g')
    
    echo "$json"
}

# Process a single YAML file
process_yml_file() {
    local yml_file="$1"
    local basename=$(basename "$yml_file" .yml)
    local expected_file="$SNAPSHOTS_DIR/${basename}.html"
    local actual_file=$(mktemp)

    # Extract JSON from the YAML file
    local json_data=$(extract_json_from_yml "$yml_file")

    if [ -z "$json_data" ]; then
        echo -e "${SNAPSHOT_RED}✗${SNAPSHOT_NC} Failed to extract JSON from $basename.yml"
        rm -f "$actual_file"
        ((SNAPSHOT_FAILED++))
        return 1
    fi

    # Run the publisher to generate actual output
    if ! echo "$json_data" | python3 "$PUBLISHER" --mode pages --output "$actual_file" > /dev/null 2>&1; then
        echo -e "${SNAPSHOT_RED}✗${SNAPSHOT_NC} Failed to generate output for $basename.html"
        rm -f "$actual_file"
        ((SNAPSHOT_FAILED++))
        return 1
    fi

    # Use the centralized snapshot comparison function
    snapshot_compare "$basename.yml" "$actual_file" "$expected_file"
}

# Main function
main() {
    # Initialize snapshot testing
    snapshot_test_init "Report Publisher Test Runner" "$SNAPSHOTS_DIR"

    echo "Looking for .yml files in: $EXAMPLES_DIR"
    echo "Output directory: $SNAPSHOTS_DIR"
    echo ""
    
    # Find all .yml files in examples directory
    local yml_files=()
    while IFS= read -r -d '' file; do
        # Skip workflow-example.yml as it uses a different format
        if [[ "$(basename "$file")" != "workflow-example.yml" ]]; then
            yml_files+=("$file")
        fi
    done < <(find "$EXAMPLES_DIR" -maxdepth 1 -name "*.yml" -type f -print0)
    
    if [ ${#yml_files[@]} -eq 0 ]; then
        echo -e "${YELLOW}No .yml files found in examples directory${NC}"
        exit 0
    fi
    
    echo "Found ${#yml_files[@]} .yml file(s) to process:"
    for file in "${yml_files[@]}"; do
        echo "  - $(basename "$file")"
    done
    echo ""
    
    # Process each YAML file
    for yml_file in "${yml_files[@]}"; do
        process_yml_file "$yml_file" || true  # Continue even if a test fails
    done
    
    # Clean up orphaned snapshot files using centralized function
    snapshot_cleanup "$EXAMPLES_DIR" "$SNAPSHOTS_DIR" "*.yml" ".html" "workflow-example.yml"

    # Print summary and exit
    snapshot_test_summary
}

# Run main function
main
