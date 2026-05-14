#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
OUTPUT_DIR="$HOME/.coveragex/output/sampleapi"
SESSION_ID="${SESSION_ID:-sampleapi-session}"
BASE_URL="${BASE_URL:-http://localhost:20000}"
TARGET_FRAMEWORK="${TARGET_FRAMEWORK:-net8.0}"
APP_DLL="$ROOT_DIR/src/SampleApi/bin/Debug/$TARGET_FRAMEWORK/SampleApi.dll"
LIB_DLL="$ROOT_DIR/src/SampleApi/bin/Debug/$TARGET_FRAMEWORK/SampleLibrary.dll"
FORCE_KILL_PORT_CONFLICT="${FORCE_KILL_PORT_CONFLICT:-0}"
PORT="${BASE_URL##*:}"

rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

cd "$ROOT_DIR"

release_port() {
    local pids pid command_line

    pids="$(lsof -nP -tiTCP:"$PORT" -sTCP:LISTEN 2>/dev/null || true)"
    if [[ -z "$pids" ]]; then
        return 0
    fi

    echo "Port $PORT is already in use by:" >&2
    while IFS= read -r pid; do
        [[ -z "$pid" ]] && continue
        command_line="$(ps -p "$pid" -o command= 2>/dev/null || true)"
        echo "  PID $pid: ${command_line:-unknown}" >&2

        if [[ "$command_line" == *"SampleApi"* || "$command_line" == *"dotnet"* || "$FORCE_KILL_PORT_CONFLICT" == "1" ]]; then
            kill "$pid" >/dev/null 2>&1 || true
        else
            echo "Refusing to kill PID $pid automatically. Re-run with FORCE_KILL_PORT_CONFLICT=1 if you want the script to terminate any process using port $PORT." >&2
            return 1
        fi
    done <<< "$pids"

    for _ in {1..20}; do
        if ! lsof -nP -tiTCP:"$PORT" -sTCP:LISTEN >/dev/null 2>&1; then
            return 0
        fi
        sleep 1
    done

    echo "Port $PORT is still in use after termination attempt." >&2
    lsof -nP -iTCP:"$PORT" -sTCP:LISTEN >&2 || true
    return 1
}

release_port

# osx-arm64 上 dotnet-coverage 不支持动态插桩，改用显式静态插桩。
dotnet build ./src/SampleApi

echo "Starting SampleApi coverage collection on $BASE_URL" >&2

dotnet-coverage collect \
    --session-id "$SESSION_ID" \
    --include-files "$APP_DLL" \
    --include-files "$LIB_DLL" \
    -f cobertura \
    dotnet "$APP_DLL" --urls "$BASE_URL" &

COLLECT_PID=$!

cleanup() {
    dotnet-coverage shutdown "$SESSION_ID" >/dev/null 2>&1 || true
    wait "$COLLECT_PID" >/dev/null 2>&1 || true
}
trap cleanup EXIT

started=false
echo "Waiting for SampleApi health endpoint: $BASE_URL/api/health" >&2
for _ in {1..30}; do
    if curl -fsS "$BASE_URL/api/health" >/dev/null 2>&1; then
        started=true
        break
    fi
    sleep 1
done

if [[ "$started" != true ]]; then
    echo "SampleApi did not become healthy at $BASE_URL/api/health" >&2
    exit 1
fi

echo "SampleApi is healthy. Running API exercise requests..." >&2
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

echo "Capturing coverage snapshot..." >&2
dotnet-coverage snapshot "$SESSION_ID" \
    -o "$OUTPUT_DIR/sampleapi-snapshot.coverage"

dotnet-coverage merge "$OUTPUT_DIR/sampleapi-snapshot.coverage" \
    -f cobertura \
    -o "$OUTPUT_DIR/sampleapi-snapshot.xml"

dotnet-coverage shutdown "$SESSION_ID" >/dev/null 2>&1 || true
wait "$COLLECT_PID" >/dev/null 2>&1 || true

echo "SampleApi coverage xml generated at: $OUTPUT_DIR/sampleapi-snapshot.xml"