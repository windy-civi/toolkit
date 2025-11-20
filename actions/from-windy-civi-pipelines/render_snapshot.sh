#!/bin/bash

SNAPSHOTS_DIR="__snapshots__"
OUTPUT_FILE="$SNAPSHOTS_DIR/output.log"
GIT_DIR="tmp/git/windy-civi-pipelines"

# Create snapshots directory
rm -rf "$SNAPSHOTS_DIR"
mkdir -p "$SNAPSHOTS_DIR"

./tools/git-sync-repos.sh --git-dir $GIT_DIR usa il
./tools/get-logs.sh --git-dir $GIT_DIR --output $OUTPUT_FILE --sort DESC --limit 100