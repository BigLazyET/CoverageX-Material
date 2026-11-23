# CoverageX-Material

CoverageX 的实测项目：SampleLibrary 单元测试和 SampleApi HTTP 请求生成覆盖率，再由 CoverageX 分析已提交分支间的增量。

## 最短流程

在仓库根目录运行：

```bash
bash scripts/generate-report.sh samplelibrary
bash scripts/generate-report.sh sampleapi
```

不传样本名时默认 sampleapi。需要已安装的 dotnet、Git、coveragex、Python3；SampleLibrary 使用项目已有 Code Coverage 数据收集器，SampleApi 还需要 dotnet-coverage 和 curl。初次缺少工具时应明确安装，不由脚本静默替换采集方式。

组合入口会采集、验证新 XML，再报告本轮显式文件；它依赖[公共 Skill](https://github.com/BigLazyET/CoverageX-Agent-Skill)中的 verifier，默认使用相邻仓库路径，可用 COVERAGEX_SKILL_DIR 指向 canonical coveragex-incremental-report 目录。

## 分支与输出

| 设置 | 默认/行为 |
| --- | --- |
| SOURCE_BRANCH / TARGET_BRANCH | foo / main，均需存在且代码已提交 |
| RUNTIME_BRANCH | 默认 SOURCE_BRANCH，当前 HEAD 必须匹配 runtime |
| OUTPUT_DIR | `~/.coveragex/output/<sample>`；每次生成隔离的 run.* 目录 |
| REPORT_DIR | 本轮 XML 所在目录下的 report/，用于两个本地报告脚本 |
| COVERAGEX_EXECUTABLE | 本地报告/组合入口默认 coveragex，可指定现有 launcher |
| COVERAGEX_SKILL_DIR | canonical Skill 目录，组合入口需其 scripts/verify_coverage_xml.py |

例如：

```bash
SOURCE_BRANCH=foo TARGET_BRANCH=main RUNTIME_BRANCH=foo \
  bash scripts/generate-report.sh sampleapi
```

`latest-xml-path` 记录本轮 XML 的明确路径（可能多行）；报告脚本使用 --report-input-files，不扫描混有历史产物的目录。CoverageX 未传 filter-mode 时默认 merge；本脚本没有额外文件/类过滤。

## 分步运行与采集差异

| 脚本 | 用途 |
| --- | --- |
| [generate-report.sh](scripts/generate-report.sh) | 推荐组合入口：采集 → verifier → lreport |
| [samplelibrary-generate-xml.sh](scripts/samplelibrary-generate-xml.sh) | 完整单元测试，已有 Code Coverage 数据收集器输出 Cobertura 和 TRX |
| [sampleapi-generate-xml.sh](scripts/sampleapi-generate-xml.sh) | 构建后启动 DLL、执行8个HTTP请求、导出覆盖率并结束自有会话 |
| [samplelibrary-generate-report.sh](scripts/samplelibrary-generate-report.sh)、[sampleapi-generate-report.sh](scripts/sampleapi-generate-report.sh) | 使用已记录或显式指定的 XML 生成本地报告；单独调用不重复验证新鲜度 |
| [sampleapi-areport.sh](scripts/sampleapi-areport.sh) | 使用 XML 和受管源码生成报告 |

SampleApi 固定监听20000，BASE_URL 默认 `http://localhost:20000`；其他端口或端口被占用时失败，不杀其他进程。默认会话名每次唯一，可通过 SESSION_ID 指定。

应用采集使用已构建的 SampleApi.dll，并为应用 DLL 和 SampleLibrary DLL 各传一次 --include-files，不限于 macOS。COLLECTION_MODE 默认 snapshot：collect → HTTP请求 → snapshot → merge → shutdown；显式 final 模式使用会话最终覆盖率，不执行 snapshot/merge。TARGET_FRAMEWORK 默认 net8.0，其他启动配置以脚本为准。 final 可能包含 shutdown 阶段的额外命中，不能与 snapshot 当作天然等价输入。每轮先执行匹配构建，再直接运行 DLL；阶段耗时以 JSON 行输出到 stderr。

```bash
COLLECTION_MODE=final bash scripts/generate-report.sh sampleapi
```

SampleLibrary 的当前数据收集器路径与现有 Coverlet MSBuild 采集不是同一入口。其他生产者需要已有集成与有效的 sources/filename 映射，不能仅凭 XML 格式名推断正确性。

## areport 的单独约定

sampleapi-areport.sh 默认 REPOSITORY_URL 为 `https://github.com/BigLazyET/CoverageX-Material.git`，不读取 origin；可显式覆盖 URL 和 REPOSITORY_USERNAME/REPOSITORY_PASSWORD。它读取 XML_FILE，否则读取 latest-xml-path，使用命令 coveragex，输出固定到 `~/.coveragex/report/sampleapi-areport` 并清理该报告目录；REPORT_DIR 和 COVERAGEX_EXECUTABLE 不适用于这个单独脚本。

## 真实增量验收分支

[codex/incremental-report-fixture](https://github.com/BigLazyET/CoverageX-Material/tree/codex/incremental-report-fixture) 保留提交2cffe96的控制样本：同文件保留旧类命中，新增代码包含已覆盖/未覆盖路径，使用完整现有 Coverlet 测试和独立验证器核对真实 Git ChangedLines 与行/分支数据。

这是固定历史样本，有自己的脚本版本；复现按该分支末尾的专用验收说明执行，不将其旧通用流程套用到当前 foo 脚本。无需合并该分支来使用本仓库的现行脚本。

## 验证脚本

```bash
for script in scripts/*.sh; do bash -n "$script"; done
python3 -m unittest discover -s scripts -p 'test_*.py'
```

安装、参数和报告限制见 [CoverageX 文档](https://github.com/BigLazyET/CoverageX)。
