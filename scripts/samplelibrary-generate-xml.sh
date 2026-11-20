#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT_DIR/scripts/coverage-common.sh"
trap 'finish_workflow "$?"' EXIT
OUTPUT_DIR="${OUTPUT_DIR:-$HOME/.coveragex/output/samplelibrary}"

mkdir -p "$OUTPUT_DIR"
OUTPUT_DIR="$(cd "$OUTPUT_DIR" && pwd)"
RUN_DIR="$(mktemp -d "$OUTPUT_DIR/run.XXXXXX")"

cd "$ROOT_DIR"

# 测试平台的数据收集器（Data Collector）输出TestResults/<guid>/ 目录结构
start_stage build-test-export
dotnet test ./test/SampleLibrary.UnitTests \
    --collect "Code Coverage;Format=cobertura" \
    --logger trx \
    --results-directory "$RUN_DIR"

python3 - "$RUN_DIR" <<'PY'
import sys
import xml.etree.ElementTree as ET
from pathlib import Path
root = Path(sys.argv[1])
counters = [ET.parse(p).find('.//{*}Counters') for p in root.rglob('*.trx')]
if not counters or any(c is None for c in counters) or sum(int(c.get('executed', 0)) for c in counters) == 0:
    raise SystemExit('No executed tests; coverage collection is incomplete.')
files = sorted(str(p.resolve()) for p in root.rglob('*.xml'))
if not files:
    raise SystemExit('No coverage XML was produced.')
(root.parent / 'latest-xml-path').write_text('\n'.join(files) + '\n')
PY

# Coverlet 的 MSBuild 集成 方式，这种方式产出的覆盖率xml对coveragex/reportgenerator工具来说不太友好，无法正确识别文件路径，导致增量报告无法生成。
# 后续可以考虑在coveragex/reportgenerator工具中增加对Coverlet MSBuild集成方式产出的xml的支持。
# dotnet test ./test/SampleLibrary.UnitTests \
#   /p:CollectCoverage=true \
#   /p:CoverletOutput="$OUTPUT_DIR/" \
#   /p:CoverletOutputFormat=cobertura

echo "SampleLibrary coverage xml generated under: $RUN_DIR"
cat "$OUTPUT_DIR/latest-xml-path"
