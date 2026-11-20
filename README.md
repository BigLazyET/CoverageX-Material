# CoverageX-Material
CoverageX Material

## 一次调用完成采集与增量报告

工具已安装、本地当前分支与运行时分支一致时：

```bash
bash scripts/generate-report.sh sampleapi
bash scripts/generate-report.sh samplelibrary
```

默认比较 `foo` 与 `main`，可设置 `SOURCE_BRANCH`、`TARGET_BRANCH`、`RUNTIME_BRANCH`。流程先预检 Git 和工具，再采集、校验新鲜 XML，最后用 `lreport` 显式文件参数生成 Html；不 clone、不重复扫描目录。需要 Python 3 和 CoverageX Skill 校验脚本，默认从相邻 `CoverageX-Agent-Skill` 仓库读取；其他安装位置设置 `COVERAGEX_SKILL_DIR`。

API 默认保留请求完成时的 snapshot 口径。明确需要进程结束时的最终覆盖率，可运行：

```bash
COLLECTION_MODE=final bash scripts/generate-report.sh sampleapi
```

final 直接输出 Cobertura XML，省去 snapshot/merge；它可能包含 shutdown 代码的覆盖，不能当成与快照天然等价。两种模式执行相同请求，插桩同样的两个 DLL。每轮都执行匹配的增量构建，随后直接运行 DLL，不用旧产物跳过构建。

采集在 `~/.coveragex/output/<sample>/run.*` 新建目录，不删除历史产物；`latest-xml-path` 记录最近成功的 XML 显式路径，报告默认在该轮目录的 `report/`。可用 `OUTPUT_DIR`、`REPORT_DIR`、`COVERAGEX_EXECUTABLE` 指定临时输出或本地 CLI。各阶段以 JSON 行向 stderr 输出毫秒耗时；dotnet test 内部构建/测试/导出合并计时。

单独的采集/报告脚本仍可使用；组合入口额外验证 XML 新鲜度与结构，失败即停止。SampleLibrary 使用已有 Code Coverage collector，不自动安装或更换采集器。自动检查：

```bash
python3 -m unittest discover -s scripts -p 'test_*.py'
```

## 生成覆盖率 XML

下面提供两种常见方式来生成覆盖率产物 XML，输出格式均以 `cobertura` 为例。

### 方式 1：执行测试项目，一次性生成 XML

适用于直接对 `test` 目录下的测试项目做覆盖率采集，命令执行完成后会一次性输出覆盖率结果。

示例：对 `SampleLibrary.UnitTests` 执行测试并输出 XML：

```bash
dotnet test ./test/SampleLibrary.UnitTests --collect "Code Coverage;Format=cobertura" --results-directory ~/.coveragex/output
```

执行完成后，可在 `~/.coveragex/output` 目录下找到生成的覆盖率 XML 文件。

### 方式 2：通过 dotnet-coverage collect 启动项目，再生成快照 XML

适用于先启动 `src` 目录下的应用项目，再由用户手动或通过脚本对应用发起请求，最后生成覆盖率快照 XML。

例如，启动 `SampleApi` 并采集运行期间的覆盖率：

```bash
dotnet-coverage collect "dotnet run --project ./src/SampleApi" -f cobertura -o ~/.coveragex/output/sampleapi-coverage.xml
```

启动后，保持应用运行，并对 `SampleApi` 发起接口请求进行测试。

如果希望在采集过程中按快照方式导出覆盖率结果，可以给 `collect` 指定 `session-id`，在应用运行过程中调用 `snapshot` 生成中间覆盖率文件，再通过 `merge` 转成 XML。典型流程如下：

```bash
dotnet-coverage collect --session-id sampleapi-session "dotnet run --project ./src/SampleApi"
```

这条命令会一直占用当前终端，直到 `SampleApi` 进程退出，或者后续通过 `dotnet-coverage shutdown sampleapi-session` 结束该会话。如果你希望在一个 shell 脚本里继续执行后续请求和快照导出，就需要把这条命令放到 shell 后台执行，或者拆成两个终端分别操作。

完成请求测试后，先生成快照文件：

```bash
dotnet-coverage snapshot sampleapi-session -o ~/.coveragex/output/sampleapi-snapshot.coverage
```

再把快照文件转换成 cobertura XML：

```bash
dotnet-coverage merge ~/.coveragex/output/sampleapi-snapshot.coverage -f cobertura -o ~/.coveragex/output/sampleapi-snapshot.xml
```

如果本机尚未安装 `dotnet-coverage`，可先执行：

```bash
dotnet tool install --global dotnet-coverage
```

## 生成增量覆盖率报告

在上一步拿到覆盖率 XML 之后，可以使用 `coveragex` 基于 Git 分支差异生成增量覆盖率报告。

`coveragex` 目前提供两个相关命令：

- `coveragex lreport`：适用于当前机器已经有本地 Git 工作树的场景。
- `coveragex areport`：适用于只拿到了覆盖率 XML，需要由 CoverageX 维护或复用 runtime source tree 的场景。

### 推荐方式：使用 lreport 生成本地增量覆盖率报告

当前仓库 `CoverageX-Material` 本身就是本地 Git 工作树，因此通常优先使用 `lreport`。

命令示例：

```bash
coveragex lreport \
	--source feature/my-change \
	--target main \
	--source-directory ~/github/CoverageX-Material \
	--report-input-directories ~/.coveragex/output \
	--report-directory ~/.coveragex/report \
	--report-type Html
```

参数说明：

- `--source`：生成这份覆盖率 XML 时对应的源码分支，通常就是你当前正在测试的分支。
- `--target`：用于做 diff 对比的目标分支，例如 `main`。
- `--source-directory`：必须指向本地 Git working tree 根目录。
- `--report-input-directories`：传入一个或多个 XML 目录，多个目录之间用 `;` 分隔。CoverageX 会递归扫描 `*.xml`；确定本轮产物后优先传 `--report-input-files`。
- `--report-directory`：增量覆盖率报告输出目录。

如果你只想传入一个或多个 XML 文件，也可以改用 `--report-input-files`：

```bash
coveragex lreport \
	--source feature/my-change \
	--target main \
	--source-directory ~/github/CoverageX-Material \
	--report-input-files ~/.coveragex/output/sampleapi-snapshot.xml \
	--report-directory ~/.coveragex/report \
	--report-type Html
```

### 另一种方式：使用 areport 基于覆盖率产物生成增量报告

如果当前机器上没有现成的本地工作树，或者你希望让 CoverageX 使用受管的 source tree，也可以使用 `areport`。

命令示例：

```bash
coveragex areport \
	--source feature/my-change \
	--target main \
	--repository-url https://github.com/your-org/CoverageX-Material.git \
	--report-input-directories ~/.coveragex/output \
	--report-directory ~/.coveragex/report \
	--report-type Html
```

### 使用时的关键约束

- CoverageX 不负责生成覆盖率 XML；必须先通过前面的 `dotnet test` 或 `dotnet-coverage` 拿到 XML，再传给 `lreport` 或 `areport`。
- `lreport` 要求当前本地仓库 HEAD 必须与 `runtime-branch` 一致；如果不显式传 `--runtime-branch`，CoverageX 会默认使用 `--source` 作为 `runtime-branch`。
- `source`、`target`、`runtime-branch` 目前都要求传分支名，不会自动帮你 fetch 或 checkout 缺失分支。
- `filter-mode` 支持 `diff`、`merge`、`explicit` 三种模式；如果不需要额外过滤，直接用默认行为即可。

## 实际演练：SampleLibrary 与 SampleApi

下面提供 `scripts` 目录中的现成脚本，演示如何先生成覆盖率 XML，再通过 `coveragex lreport` 生成增量覆盖率报告。

执行前请先确认：

- 当前目录位于仓库根目录 `CoverageX-Material`。
- `coveragex` 命令已可执行。
- 当前 Git 分支就是你要分析的功能分支；如需覆盖默认分支名，可在执行脚本时传入环境变量 `SOURCE_BRANCH`、`TARGET_BRANCH`。
- 初次执行前可先运行 `chmod +x ./scripts/*.sh`。

### SampleLibrary 演练

这个演练使用 `SampleLibrary.UnitTests` 一次性生成 XML，然后基于该 XML 生成 `SampleLibrary` 的增量覆盖率报告。

#### 1. 生成覆盖率 XML

执行 [scripts/samplelibrary-generate-xml.sh](/Users/tc/github/CoverageX-Material/scripts/samplelibrary-generate-xml.sh)：

```bash
./scripts/samplelibrary-generate-xml.sh
```

#### 2. 生成覆盖率报告

执行 [scripts/samplelibrary-generate-report.sh](/Users/tc/github/CoverageX-Material/scripts/samplelibrary-generate-report.sh)：

```bash
SOURCE_BRANCH=feature/my-change TARGET_BRANCH=main ./scripts/samplelibrary-generate-report.sh
```

### SampleApi 演练

这个演练使用 `dotnet-coverage collect` 启动 `SampleApi`，对接口发起真实请求后导出 XML，再基于该 XML 生成 `SampleApi` 的增量覆盖率报告。

这里的关键点是：`SampleApi` 属于常驻服务，如果把 `dotnet-coverage collect` 以前台方式执行，脚本会阻塞在这一行，不会继续往下跑。因此下面的脚本使用 shell 的 `&` 把采集进程放到后台，再通过 `shutdown` 显式结束会话。

对于 `macOS arm64`，这里使用的是 `dotnet-coverage collect` 命令模式配合多次传入 `--include-files` 的写法。关键点是每个 DLL 都要单独传一个 `--include-files` 参数，不能用 `;` 拼成一个值交给 shell。

#### 1. 生成覆盖率 XML

执行 [scripts/sampleapi-generate-xml.sh](/Users/tc/github/CoverageX-Material/scripts/sampleapi-generate-xml.sh)：

```bash
./scripts/sampleapi-generate-xml.sh
```

如需指定会话名，可以这样执行：

```bash
SESSION_ID=sampleapi-session bash ./scripts/sampleapi-generate-xml.sh
```

SampleApi 当前在应用中固定监听 20000，脚本拒绝其他端口。端口占用时请先结束其所属进程；脚本不会自动杀死其他应用。默认会话名每次唯一，只清理本轮会话。

如需覆盖目标框架，可以这样执行：

```bash
TARGET_FRAMEWORK=net8.0 ./scripts/sampleapi-generate-xml.sh
```

#### 2. 生成覆盖率报告

执行 [scripts/sampleapi-generate-report.sh](/Users/tc/github/CoverageX-Material/scripts/sampleapi-generate-report.sh)：

```bash
SOURCE_BRANCH=feature/my-change TARGET_BRANCH=main ./scripts/sampleapi-generate-report.sh
```

#### 3. 使用 areport 生成覆盖率报告

如果你希望让 `coveragex` 自己去拉取 `SampleApi` 对应仓库，而不是直接使用当前本地工作树，可以执行 [scripts/sampleapi-areport.sh](/Users/tc/github/CoverageX-Material/scripts/sampleapi-areport.sh)。

这个脚本会复用前一步生成的 `~/.coveragex/output/sampleapi/sampleapi-snapshot.xml`，并通过 `REPOSITORY_URL` 让 `coveragex areport` 去拉取或复用 managed source tree。

示例：

```bash
REPOSITORY_URL=https://github.com/your-org/CoverageX-Material.git SOURCE_BRANCH=feature/my-change TARGET_BRANCH=main ./scripts/sampleapi-areport.sh
```

如果仓库是私有的，还可以附带认证信息：

```bash
REPOSITORY_URL=https://github.com/your-org/CoverageX-Material.git REPOSITORY_USERNAME=your-username REPOSITORY_PASSWORD=your-token SOURCE_BRANCH=feature/my-change TARGET_BRANCH=main ./scripts/sampleapi-areport.sh
```

如需显式指定运行时分支，可以附加 `RUNTIME_BRANCH`：

```bash
REPOSITORY_URL=https://github.com/your-org/CoverageX-Material.git SOURCE_BRANCH=feature/my-change TARGET_BRANCH=main RUNTIME_BRANCH=feature/my-change ./scripts/sampleapi-areport.sh
```

### 补充说明

- 如果当前仓库 HEAD 不在 `SOURCE_BRANCH`，`coveragex lreport` 会直接报错；这时要么先切到对应分支，要么改用 `areport`。
- `SampleApi` 脚本依赖 `curl` 和 `dotnet-coverage`。
- `scripts/sampleapi-areport.sh` 依赖 `coveragex areport`，并且必须能够通过 `REPOSITORY_URL` 拉取到当前项目仓库；未显式传入时，脚本会优先尝试读取当前仓库的 `remote.origin.url`。
- `SampleApi` 的脚本里使用的是 shell 的后台执行 `&`，不是 `dotnet-coverage collect --background`。这是因为这里用的是 `collect` 的命令模式，官方文档中的 `--background` 只适用于 server mode。
- 如果不使用 `&`、第二个终端，或者其它后台运行方式，`dotnet-coverage collect --session-id ... "dotnet run ..."` 会一直占用前台，脚本后续步骤不会自动继续执行。
- `SampleApi` 的控制器路由当前是 `api/...`，例如健康检查是 `/api/health`，计算接口是 `/api/calculator/multiply`、`/api/calculator/divide`，项目条目接口是 `/api/items`。
- `SampleApi` 检查 20000 端口，冲突直接失败，只清理自己拥有的采集会话。
- `SampleLibrary` 记录本轮 XML 显式路径，报告脚本直接传入，不扫描混有旧结果的目录。
