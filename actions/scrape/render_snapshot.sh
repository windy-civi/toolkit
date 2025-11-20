#!/bin/bash

SNAPSHOTS_DIR="__snapshots__"

rm -rf "$SNAPSHOTS_DIR"
mkdir -p "$SNAPSHOTS_DIR"

# Using wy because its fast
./scrape.sh wy latest "$SNAPSHOTS_DIR"

# OK, now LS all the files in __snapshots__
# Keep every 20th file and delete the rest.
files=($(find "$SNAPSHOTS_DIR" -type f | sort))
total=${#files[@]}
echo "Total count of files: $total"
for i in "${!files[@]}"; do
    # Keep every 20th file (1st, 21st, 41st, etc.)
    if [ $((i % 20)) -ne 0 ]; then
        rm -f "${files[$i]}"
    fi
done

files=($(find "$SNAPSHOTS_DIR" -type f | sort))
total=${#files[@]}
echo "Total count of files: $total"
