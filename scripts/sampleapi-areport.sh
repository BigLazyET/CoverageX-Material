#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE_BRANCH="${SOURCE_BRANCH:-foo}"
TARGET_BRANCH="${TARGET_BRANCH:-main}"
XML_FILE="$HOME/.coveragex/output/sampleapi/sampleapi-snapshot.xml"
REPORT_DIR="$HOME/.coveragex/report/sampleapi-areport"
RUNTIME_BRANCH="${RUNTIME_BRANCH:-$SOURCE_BRANCH}"
REPOSITORY_URL="${REPOSITORY_URL:-https://github.com/BigLazyET/CoverageX-Material.git}"
REPOSITORY_USERNAME="${REPOSITORY_USERNAME:-}"
REPOSITORY_PASSWORD="${REPOSITORY_PASSWORD:-}"

if [[ -z "$REPOSITORY_URL" ]]; then
    echo "REPOSITORY_URL is required for areport. Set it explicitly or configure git remote.origin.url." >&2
    exit 1
fi

if [[ ! -f "$XML_FILE" ]]; then
    echo "Coverage XML not found: $XML_FILE" >&2
    echo "Run ./scripts/sampleapi-generate-xml.sh first." >&2
    exit 1
fi

rm -rf "$REPORT_DIR"
mkdir -p "$REPORT_DIR"

cd "$ROOT_DIR"

command=(
    coveragex areport
    --source "$SOURCE_BRANCH"
    --target "$TARGET_BRANCH"
    --runtime-branch "$RUNTIME_BRANCH"
    --repository-url "$REPOSITORY_URL"
    --report-input-files "$XML_FILE"
    --report-directory "$REPORT_DIR"
    --report-type Html
)

if [[ -n "$REPOSITORY_USERNAME" ]]; then
    command+=(--repository-username "$REPOSITORY_USERNAME")
fi

if [[ -n "$REPOSITORY_PASSWORD" ]]; then
    command+=(--repository-password "$REPOSITORY_PASSWORD")
fi

"${command[@]}"

echo "SampleApi incremental areport generated under: $REPORT_DIR"