#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT_DIR/scripts/coverage-common.sh"
trap 'finish_workflow "$?"' EXIT
SAMPLE="${1:-sampleapi}"
if [[ "$SAMPLE" != sampleapi && "$SAMPLE" != samplelibrary ]]; then
    echo "Usage: bash scripts/generate-report.sh [sampleapi|samplelibrary]" >&2
    exit 1
fi
SKILL_DIR="${COVERAGEX_SKILL_DIR:-$ROOT_DIR/../CoverageX-Agent-Skill/plugins/coveragex-agent-skill/skills/coveragex-incremental-report}"
if [[ ! -f "$SKILL_DIR/scripts/verify_coverage_xml.py" ]]; then
    echo "Set COVERAGEX_SKILL_DIR to the installed coveragex-incremental-report Skill directory." >&2
    exit 1
fi
export SOURCE_BRANCH="${SOURCE_BRANCH:-foo}"
export TARGET_BRANCH="${TARGET_BRANCH:-main}"
export RUNTIME_BRANCH="${RUNTIME_BRANCH:-$SOURCE_BRANCH}"
export OUTPUT_DIR="${OUTPUT_DIR:-$HOME/.coveragex/output/$SAMPLE}"
export COVERAGEX_EXECUTABLE="${COVERAGEX_EXECUTABLE:-coveragex}"
for tool in git dotnet "$COVERAGEX_EXECUTABLE"; do
    command -v "$tool" >/dev/null
done
cd "$ROOT_DIR"
if [[ "$(git symbolic-ref --short HEAD)" != "$RUNTIME_BRANCH" ]]; then
    echo "Current branch must match RUNTIME_BRANCH=$RUNTIME_BRANCH." >&2
    exit 1
fi
git rev-parse --verify "$SOURCE_BRANCH^{commit}" >/dev/null
git rev-parse --verify "$TARGET_BRANCH^{commit}" >/dev/null

start_stage collect
SINCE="$(python3 -c 'import time; print(time.time())')"
bash "$ROOT_DIR/scripts/$SAMPLE-generate-xml.sh"
start_stage verify
INPUTS=()
while IFS= read -r file; do
    [[ -z "$file" ]] || INPUTS+=("$file")
done < "$OUTPUT_DIR/latest-xml-path"
VERIFIED="$(python3 "$SKILL_DIR/scripts/verify_coverage_xml.py" --since "$SINCE" "${INPUTS[@]}")"
export XML_FILES="$(printf '%s' "$VERIFIED" | python3 -c 'import json,sys; print(";".join(json.load(sys.stdin)["files"]))')"
export XML_FILE="$XML_FILES"
start_stage report
bash "$ROOT_DIR/scripts/$SAMPLE-generate-report.sh"
