#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE_BRANCH="${SOURCE_BRANCH:-foo}"
TARGET_BRANCH="${TARGET_BRANCH:-main}"
XML_DIR="$HOME/.coveragex/output/samplelibrary"
REPORT_DIR="$HOME/.coveragex/report/samplelibrary"

rm -rf "$REPORT_DIR"
mkdir -p "$REPORT_DIR"

cd "$ROOT_DIR"

coveragex lreport \
    --source "$SOURCE_BRANCH" \
    --target "$TARGET_BRANCH" \
    --source-directory "$ROOT_DIR" \
    --report-input-directories "$XML_DIR" \
    --report-directory "$REPORT_DIR" \
    --report-type Html

echo "SampleLibrary incremental report generated under: $REPORT_DIR"