#!/usr/bin/env bash
set -euo pipefail

# California-specific scraper using MySQL dumps
# Usage: scrape-ca.sh <working_dir> <output_dir>
#   working_dir: Working directory for MySQL data
#   output_dir: Output directory for tarball

WORKING_DIR="${1:-$(pwd)}"
OUTPUT_DIR="${2:-$(pwd)}"
STATE="ca"

cd "$WORKING_DIR"
mkdir -p _working/_data _working/_cache

# Log file to capture output
SCRAPE_LOG="${OUTPUT_DIR}/scrape-output.log"
> "$SCRAPE_LOG"

echo "🕷️ Scraping California (MySQL-based)..." | tee -a "$SCRAPE_LOG"

# TODO: California requires special MySQL setup
# According to OpenStates docs:
# 1. Download MySQL dumps: docker-compose run --rm ca-download
# 2. Start MySQL container with the data
# 3. Run scraper: docker-compose run --rm ca-scrape ca bills --fast

echo "⚠️ California scraper requires MySQL setup - not yet implemented" | tee -a "$SCRAPE_LOG"
echo "   See: https://docs.openstates.org/contributing/state-specific/#california-mysql" | tee -a "$SCRAPE_LOG"

# For now, create empty result to indicate CA needs special handling
mkdir -p "${OUTPUT_DIR}/_data/${STATE}"
cat > "${OUTPUT_DIR}/_data/${STATE}/README.txt" <<EOF
California scraper requires special MySQL setup.
This is not yet automated in GitHub Actions.

Manual steps required:
1. docker-compose run --rm ca-download
2. docker-compose run --rm ca-scrape ca bills --fast

See: https://docs.openstates.org/contributing/state-specific/#california-mysql
EOF

# Create summary indicating special handling needed
cat > "${OUTPUT_DIR}/scrape-summary.json" <<EOF
{
  "state": "ca",
  "exit_code": 0,
  "objects": {
    "bill": 0,
    "vote_event": 0,
    "event": 0
  },
  "metadata": {
    "jurisdiction": 0,
    "organization": 0
  },
  "json_files": 0,
  "duration": "N/A",
  "error_count": 1,
  "errors": ["California requires special MySQL setup - not yet automated"]
}
EOF

echo "📊 CA scrape summary written (special handling required)" | tee -a "$SCRAPE_LOG"

# Exit with success to avoid failing the workflow
exit 0

