#!/usr/bin/env bash

coverage_now() {
    python3 -c 'import time; print(time.monotonic_ns() // 1000000)'
}

WORKFLOW_START="$(coverage_now)"
WORKFLOW_NAME="$(basename "$0" .sh)"
STAGE_START="$WORKFLOW_START"
STAGE_NAME=preflight

finish_stage() {
    local now
    now="$(coverage_now)"
    printf '{"stage":"%s","workflow":"%s","elapsedMs":%s,"exitCode":%s}\n' \
        "$STAGE_NAME" "$WORKFLOW_NAME" "$((now - STAGE_START))" "${1:-0}" >&2
}

start_stage() {
    finish_stage 0
    STAGE_NAME="$1"
    STAGE_START="$(coverage_now)"
}

finish_workflow() {
    finish_stage "$1"
    printf '{"stage":"total","workflow":"%s","elapsedMs":%s,"exitCode":%s}\n' \
        "$WORKFLOW_NAME" "$(( $(coverage_now) - WORKFLOW_START ))" "$1" >&2
}
