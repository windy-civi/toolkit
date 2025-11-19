#!/bin/bash

# Script to run the legislation tools pipeline
# Usage: ACTION_PATH=<path> OUTPUT_FILE=<file> LIMIT=<limit> ./run_pipeline.sh
# Outputs: result_count and output_file to GITHUB_OUTPUT

# Set default values
ACTION_PATH="${ACTION_PATH:-}"
OUTPUT_FILE="${OUTPUT_FILE:-recent_items.txt}"
LIMIT="${LIMIT:-100}"

# Validate required variables
if [ -z "$ACTION_PATH" ]; then
    echo "Error: ACTION_PATH environment variable is required"
    exit 1
fi

echo "=== Running Tools Pipeline ==="

# Run the pipeline: find logs -> filter recent -> sort -> limit -> extract names
cd "$RUNNER_TEMP/usa-data-pipeline"
# List contents of current directory
echo "=== Directory Contents ==="
ls -la
echo "======================="
"$ACTION_PATH/tools/find_logs_json.sh" | \
"$ACTION_PATH/tools/filter_recent_logs.sh" | \
"$ACTION_PATH/tools/sort_logs_by_timestamp.sh" | \
"$ACTION_PATH/tools/limit_output.sh" "$LIMIT" | \
"$ACTION_PATH/tools/extract_name.sh" > "../$OUTPUT_FILE"

echo "=== Pipeline Output ==="
cat "../$OUTPUT_FILE"

# Count results
result_count=$(wc -l < "../$OUTPUT_FILE")
echo "Found $result_count recent legislative activities"

# Set outputs
echo "result_count=$result_count" >> $GITHUB_OUTPUT
echo "output_file=../$OUTPUT_FILE" >> $GITHUB_OUTPUT

