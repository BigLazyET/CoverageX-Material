#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
OUTPUT_DIR="$HOME/.coveragex/output/samplelibrary"

rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

cd "$ROOT_DIR"

# # 测试平台的数据收集器（Data Collector）输出TestResults/<guid>/ 目录结构，对ci流程其实不太友好
# dotnet test ./test/SampleLibrary.UnitTests \
#     --collect "Code Coverage;Format=cobertura" \
#     --results-directory "$OUTPUT_DIR"

# Coverlet 的 MSBuild 集成 方式
dotnet test ./test/SampleLibrary.UnitTests \
  /p:CollectCoverage=true \
  /p:CoverletOutput="$OUTPUT_DIR/" \
  /p:CoverletOutputFormat=cobertura

echo "SampleLibrary coverage xml generated under: $OUTPUT_DIR"
find "$OUTPUT_DIR" -name '*.xml' -print