#!/bin/bash

# PROD DATA SEED: We don't run this script on every test run as it is prod data.

SNAPSHOTS_DIR="__snapshots__"
OPENSTATES_DATA_DIR="$SNAPSHOTS_DIR/_working/_data"

rm -rf "$SNAPSHOTS_DIR"
mkdir -p "$SNAPSHOTS_DIR"

# Using wy because its fast
./scrape.sh wy latest "$SNAPSHOTS_DIR"

files=($(find "$SNAPSHOTS_DIR" -type f | sort))
total=${#files[@]}
echo "Initial total count of files: $total"

# Get all file types from schemas directory
# Extract types from schema filenames (e.g., bill.schema.json -> bill)
SCHEMAS_DIR="schemas"
types=()
for schema_file in "$SCHEMAS_DIR"/*.schema.json; do
    if [ -f "$schema_file" ]; then
        basename=$(basename "$schema_file" .schema.json)
        types+=("$basename")
    fi
done

echo "Found types: ${types[*]}"

# For each type, keep only the first 20 files max
for type in "${types[@]}"; do
    echo "Processing type: $type"
    files=($(find "$SNAPSHOTS_DIR" -type f -name "${type}_*.json" | sort))
    total=${#files[@]}
    echo "  Total files for $type: $total"
    
    if [ $total -gt 20 ]; then
        # Keep first 20, delete the rest
        for i in "${!files[@]}"; do
            if [ $i -ge 20 ]; then
                rm -f "${files[$i]}"
            fi
        done
        echo "  Kept 20 files, deleted $((total - 20)) files"
    else
        echo "  Kept all $total files"
    fi
done

# Final count
files=($(find "$SNAPSHOTS_DIR" -type f | sort))
total=${#files[@]}
echo "Final total count of files: $total"
