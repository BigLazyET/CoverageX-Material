#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE_BRANCH="${SOURCE_BRANCH:-foo}"
TARGET_BRANCH="${TARGET_BRANCH:-main}"
OUTPUT_DIR="${OUTPUT_DIR:-$HOME/.coveragex/output/sampleapi}"
if [[ -z "${XML_FILE:-}" ]]; then
    XML_FILE="$(cat "$OUTPUT_DIR/latest-xml-path")"
fi
REPORT_DIR="${REPORT_DIR:-$(dirname "$XML_FILE")/report}"
COVERAGEX_EXECUTABLE="${COVERAGEX_EXECUTABLE:-coveragex}"

mkdir -p "$REPORT_DIR"

cd "$ROOT_DIR"

"$COVERAGEX_EXECUTABLE" lreport \
    --source "$SOURCE_BRANCH" \
    --target "$TARGET_BRANCH" \
    --runtime-branch "${RUNTIME_BRANCH:-$SOURCE_BRANCH}" \
    --source-directory "$ROOT_DIR" \
    --report-input-files "$XML_FILE" \
    --report-directory "$REPORT_DIR" \
    --report-type Html

echo "SampleApi incremental report generated under: $REPORT_DIR"
