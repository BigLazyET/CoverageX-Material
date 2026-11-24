# CoverageX-Material

CoverageX 的实测项目：通过 dotnet-coverage 启动 SampleApi，用 HTTP 请求触发业务并获取覆盖率快照，再分析已提交分支间的增量。单元/集成测试项目仅用于开发回归，不是采集入口。

## 最短流程

在仓库根目录运行：

```bash
bash scripts/generate-report.sh sampleapi
```

不传样本名时默认 sampleapi。脚本面向具备 Bash、lsof、curl 的 Unix 环境，还需要 dotnet、Git、coveragex、Python3 和 dotnet-coverage；主动采集不使用其他采集器。初次缺少工具时应明确安装，不由脚本静默替换采集方式。跨平台桌面操作使用 CoverageX Desktop，本 Bash 示例不承诺原生 Windows 支持。

组合入口会采集、验证新 XML，再报告本轮显式文件；它依赖[公共 Skill](https://github.com/BigLazyET/CoverageX-Agent-Skill)中的 verifier，默认使用相邻仓库路径，可用 COVERAGEX_SKILL_DIR 指向 canonical coveragex-incremental-report 目录。

## 分支与输出

| 设置 | 默认/行为 |
| --- | --- |
| SOURCE_BRANCH / TARGET_BRANCH | foo / main，均需存在且代码已提交 |
| RUNTIME_BRANCH | 默认 SOURCE_BRANCH，当前 HEAD 必须匹配 runtime |
| OUTPUT_DIR | `~/.coveragex/output/sampleapi`；每次生成隔离的 run.* 目录 |
| REPORT_DIR | 本轮 XML 所在目录下的 report/ |
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
| [sampleapi-generate-xml.sh](scripts/sampleapi-generate-xml.sh) | 构建后启动 DLL、执行8个HTTP请求、导出覆盖率并结束自有会话 |
| [sampleapi-generate-report.sh](scripts/sampleapi-generate-report.sh) | 使用已记录或显式指定的 XML 生成本地报告；单独调用不重复验证新鲜度 |
| [sampleapi-areport.sh](scripts/sampleapi-areport.sh) | 使用 XML 和受管源码生成报告 |

SampleApi 固定监听20000，BASE_URL 默认 `http://localhost:20000`；其他端口或端口被占用时失败，不杀其他进程。默认会话名每次唯一，可通过 SESSION_ID 指定。

应用采集使用已构建的 SampleApi.dll，并为应用 DLL 和 SampleLibrary DLL 各传一次 --include-files，不限于 macOS。COLLECTION_MODE 默认 snapshot：collect → HTTP请求 → snapshot → merge → shutdown；显式 final 模式使用会话最终覆盖率，不执行 snapshot/merge。TARGET_FRAMEWORK 默认 net8.0，其他启动配置以脚本为准。 final 可能包含 shutdown 阶段的额外命中，不能与 snapshot 当作天然等价输入。每轮先执行匹配构建，再直接运行 DLL；阶段耗时以 JSON 行输出到 stderr。

```bash
COLLECTION_MODE=final bash scripts/generate-report.sh sampleapi
```

已有 XML 可由用户采用任意工具生成；报告端仍需验证格式、sources/filename 映射和源码版本，不负责其生产工具的安装或配置。脚本是显式命令行入口；AI/桌面交互仍应在生成报告前确认实际输入。

## areport 的单独约定

sampleapi-areport.sh 默认 REPOSITORY_URL 为 `https://github.com/BigLazyET/CoverageX-Material.git`，不读取 origin；可显式覆盖 URL 和 REPOSITORY_USERNAME/REPOSITORY_PASSWORD。它读取 XML_FILE，否则读取 latest-xml-path，使用命令 coveragex，输出固定到 `~/.coveragex/report/sampleapi-areport` 并清理该报告目录；REPORT_DIR 和 COVERAGEX_EXECUTABLE 不适用于这个单独脚本。

## 真实增量验收分支

[codex/incremental-report-fixture](https://github.com/BigLazyET/CoverageX-Material/tree/codex/incremental-report-fixture) 保留提交 2cffe96 的历史控制样本，其新增业务代码原仅由测试工程触达，不是当前应用采集入口。当前 CoverageX 桌面验收在一次性克隆中追加 HTTP 路由，通过业务请求与 dotnet-coverage 快照核对 ChangedLines、命中/未命中及 CLI/桌面指标，不重写历史提交。

这是固定历史样本，有自己的脚本版本；其旧采集说明不属于现行支持流程。无需合并该分支来使用当前应用脚本。

## 验证脚本

```bash
for script in scripts/*.sh; do bash -n "$script"; done
python3 -m unittest discover -s scripts -p 'test_*.py'
```

安装、参数和报告限制见 [CoverageX 文档](https://github.com/BigLazyET/CoverageX)。
