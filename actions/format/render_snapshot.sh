
set -euo pipefail

STATE="wy"
INPUT_DIR="../scrape/__snapshots__/_working/_data/wy"
TMP_DIR="./tmp/sanitize"
OUTPUT_DIR="./__snapshots__/$STATE"


rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

cp -r "$INPUT_DIR" "$TMP_DIR"

tmpc="${TMP_DIR}/san_count.txt"
: > "$tmpc"
find "$TMP_DIR" -type f -name "*.json" -print0 | while IFS= read -r -d '' f; do
    jq 'del(..|._id?, .scraped_at?)' "$f" > "$f.tmp" && mv "$f.tmp" "$f"
    echo 1 >> "$tmpc"
done
echo "Sanitized $(wc -l < "$tmpc") files"


# Capture formatter output
python -m pipenv run python main.py \
    --state "$STATE" \
    --openstates-data-folder "$TMP_DIR" \
    --git-repo-folder "$OUTPUT_DIR"