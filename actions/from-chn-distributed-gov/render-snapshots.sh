#!/bin/bash

SNAPSHOTS_DIR="__snapshots__"
OUTPUT_FILE="$SNAPSHOTS_DIR/output.txt"
GIT_DIR="../sync-windy-civi-pipelines/__snapshots__"

# Create snapshots directory
rm -rf "$SNAPSHOTS_DIR"
mkdir -p "$SNAPSHOTS_DIR"

# Build the Rust binary if it doesn't exist
BINARY="target/release/from-chn-distributed-gov"
if [ ! -f "$BINARY" ]; then
    echo "Building Rust binary..."
    cargo build --release --bin from-chn-distributed-gov
fi

# Run the Rust binary with the same arguments as the original script
# Note: The Rust version outputs JSON to stdout (one per line), errors go to stderr
# We redirect stdout to the output file, stderr remains visible for debugging
"$BINARY" \
    --git-dir "$GIT_DIR" \
    --sort DESC \
    --limit 100 \
    --join minimal_metadata \
    > "$OUTPUT_FILE"