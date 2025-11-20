#!/bin/bash

SNAPSHOTS_DIR="__snapshots__"
OUTPUT_FILE="$SNAPSHOTS_DIR/output.txt"
GIT_DIR="../sync-windy-civi-pipelines/__snapshots__"

# Create snapshots directory
rm -rf "$SNAPSHOTS_DIR"
mkdir -p "$SNAPSHOTS_DIR"

./main.sh --git-dir $GIT_DIR --output $OUTPUT_FILE --sort DESC --limit 100 > $OUTPUT_FILE