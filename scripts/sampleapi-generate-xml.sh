#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT_DIR/scripts/coverage-common.sh"
OUTPUT_DIR="${OUTPUT_DIR:-$HOME/.coveragex/output/sampleapi}"
SESSION_ID="${SESSION_ID:-sampleapi-$$-$(date +%s)}"
BASE_URL="${BASE_URL:-http://localhost:20000}"
TARGET_FRAMEWORK="${TARGET_FRAMEWORK:-net8.0}"
CONFIGURATION="${CONFIGURATION:-Debug}"
COLLECTION_MODE="${COLLECTION_MODE:-snapshot}"
APP_DLL="$ROOT_DIR/src/SampleApi/bin/$CONFIGURATION/$TARGET_FRAMEWORK/SampleApi.dll"
LIB_DLL="$ROOT_DIR/src/SampleApi/bin/$CONFIGURATION/$TARGET_FRAMEWORK/SampleLibrary.dll"
PORT="${BASE_URL##*:}"
COLLECT_PID=

cleanup() {
    local status=$?
    trap - EXIT
    if [[ -n "$COLLECT_PID" ]]; then
        dotnet-coverage shutdown "$SESSION_ID" -t 10000 >/dev/null 2>&1 || true
        wait "$COLLECT_PID" >/dev/null 2>&1 || true
    fi
    finish_workflow "$status"
    exit "$status"
}
trap cleanup EXIT

for tool in dotnet dotnet-coverage curl lsof; do
    command -v "$tool" >/dev/null
done
if [[ "$COLLECTION_MODE" != snapshot && "$COLLECTION_MODE" != final ]]; then
    echo "COLLECTION_MODE must be snapshot or final." >&2
    exit 1
fi
if [[ "$PORT" != 20000 ]]; then
    echo "SampleApi currently listens on port 20000; BASE_URL must use that port." >&2
    exit 1
fi
if lsof -nP -tiTCP:"$PORT" -sTCP:LISTEN >/dev/null 2>&1; then
    echo "Port $PORT is already in use; stop its owner before collecting coverage." >&2
    exit 1
fi
mkdir -p "$OUTPUT_DIR"
OUTPUT_DIR="$(cd "$OUTPUT_DIR" && pwd)"
RUN_DIR="$(mktemp -d "$OUTPUT_DIR/run.XXXXXX")"
XML_FILE="$RUN_DIR/sampleapi-$COLLECTION_MODE.xml"
cd "$ROOT_DIR"

# osx-arm64 上 dotnet-coverage 不支持动态插桩，改用显式静态插桩。
start_stage build
dotnet build ./src/SampleApi -c "$CONFIGURATION" -f "$TARGET_FRAMEWORK"

echo "Starting SampleApi coverage collection on $BASE_URL" >&2
start_stage startup
dotnet-coverage collect \
    --session-id "$SESSION_ID" \
    --include-files "$APP_DLL" \
    --include-files "$LIB_DLL" \
    -f cobertura -o "$RUN_DIR/sampleapi-final.xml" \
    dotnet "$APP_DLL" --urls "$BASE_URL" &

COLLECT_PID=$!

started=false
echo "Waiting for SampleApi health endpoint: $BASE_URL/api/health" >&2
for _ in {1..100}; do
    if ! kill -0 "$COLLECT_PID" 2>/dev/null; then
        echo "Coverage collector exited before the application became healthy." >&2
        exit 1
    fi
    if curl -fsS --connect-timeout 1 --max-time 1 "$BASE_URL/api/health" >/dev/null 2>&1; then
        started=true
        break
    fi
    sleep 0.1
done

if [[ "$started" != true ]]; then
    echo "SampleApi did not become healthy at $BASE_URL/api/health" >&2
    exit 1
fi

echo "SampleApi is healthy. Running API exercise requests..." >&2
start_stage requests
curl -fsS "$BASE_URL/api/health" >/dev/null
curl -fsS "$BASE_URL/api/calculator/multiply?a=3&b=4" >/dev/null
curl -fsS "$BASE_URL/api/calculator/divide?a=5&b=2" >/dev/null

ITEM_JSON='{"name":"demo-item","value":42}'
CREATE_RESPONSE="$(curl -fsS -H 'Content-Type: application/json' -d "$ITEM_JSON" "$BASE_URL/api/items")"
ITEM_ID="$(printf '%s' "$CREATE_RESPONSE" | sed -E 's/.*"id":([0-9]+).*/\1/')"

curl -fsS "$BASE_URL/api/items/$ITEM_ID" >/dev/null
curl -fsS -X PUT -H 'Content-Type: application/json' \
    -d "{\"id\":$ITEM_ID,\"name\":\"demo-item-updated\",\"value\":50}" \
    "$BASE_URL/api/items/$ITEM_ID" >/dev/null
curl -fsS -X DELETE "$BASE_URL/api/items/$ITEM_ID" >/dev/null

if [[ "$COLLECTION_MODE" == snapshot ]]; then
    start_stage snapshot
    dotnet-coverage snapshot "$SESSION_ID" -t 10000 -o "$RUN_DIR/sampleapi-snapshot.coverage"
    start_stage xml-export
    dotnet-coverage merge "$RUN_DIR/sampleapi-snapshot.coverage" -f cobertura -o "$XML_FILE"
fi

start_stage shutdown
dotnet-coverage shutdown "$SESSION_ID" -t 10000
COLLECT_STATUS=0
wait "$COLLECT_PID" || COLLECT_STATUS=$?
COLLECT_PID=
# A successful shutdown can terminate the instrumented command with SIGKILL/SIGTERM.
if [[ "$COLLECT_STATUS" != 0 && "$COLLECT_STATUS" != 137 && "$COLLECT_STATUS" != 143 ]]; then
    echo "Coverage collector failed with exit code $COLLECT_STATUS." >&2
    exit "$COLLECT_STATUS"
fi
if [[ ! -s "$XML_FILE" ]]; then
    echo "Coverage XML is missing or empty: $XML_FILE" >&2
    exit 1
fi
printf '%s\n' "$XML_FILE" > "$OUTPUT_DIR/latest-xml-path"
echo "SampleApi $COLLECTION_MODE coverage XML: $XML_FILE"
