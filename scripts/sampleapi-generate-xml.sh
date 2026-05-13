#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
OUTPUT_DIR="$HOME/.coveragex/output/sampleapi"
SESSION_ID="${SESSION_ID:-sampleapi-session}"
BASE_URL="${BASE_URL:-http://localhost:5099}"

rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

cd "$ROOT_DIR"

# 把 collect 放到 shell 后台，否则常驻的 SampleApi 会一直占用前台，脚本不会继续执行。
dotnet-coverage collect --session-id "$SESSION_ID" \
    "dotnet run --project ./src/SampleApi --urls $BASE_URL" &

COLLECT_PID=$!

cleanup() {
    dotnet-coverage shutdown "$SESSION_ID" >/dev/null 2>&1 || true
    wait "$COLLECT_PID" >/dev/null 2>&1 || true
}
trap cleanup EXIT

for _ in {1..30}; do
    if curl -fsS "$BASE_URL/health" >/dev/null 2>&1; then
        break
    fi
    sleep 1
done

curl -fsS "$BASE_URL/health" >/dev/null
curl -fsS "$BASE_URL/calc/mul?a=3&b=4" >/dev/null
curl -fsS "$BASE_URL/calc/div?a=5&b=2" >/dev/null

ITEM_JSON='{"name":"demo-item","value":42}'
CREATE_RESPONSE="$(curl -fsS -H 'Content-Type: application/json' -d "$ITEM_JSON" "$BASE_URL/items")"
ITEM_ID="$(printf '%s' "$CREATE_RESPONSE" | sed -E 's/.*"id":([0-9]+).*/\1/')"

curl -fsS "$BASE_URL/items/$ITEM_ID" >/dev/null
curl -fsS -X PUT -H 'Content-Type: application/json' \
    -d "{\"id\":$ITEM_ID,\"name\":\"demo-item-updated\",\"value\":50}" \
    "$BASE_URL/items/$ITEM_ID" >/dev/null
curl -fsS -X DELETE "$BASE_URL/items/$ITEM_ID" >/dev/null

dotnet-coverage snapshot "$SESSION_ID" \
    -o "$OUTPUT_DIR/sampleapi-snapshot.coverage"

dotnet-coverage merge "$OUTPUT_DIR/sampleapi-snapshot.coverage" \
    -f cobertura \
    -o "$OUTPUT_DIR/sampleapi-snapshot.xml"

dotnet-coverage shutdown "$SESSION_ID" >/dev/null 2>&1 || true
wait "$COLLECT_PID" >/dev/null 2>&1 || true

echo "SampleApi coverage xml generated at: $OUTPUT_DIR/sampleapi-snapshot.xml"