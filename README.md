# CoverageX-Material
CoverageX Material

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
- `--report-input-directories`：传入一个或多个 XML 目录，多个目录之间用 `;` 分隔。CoverageX 会扫描每个目录顶层的 `*.xml` 文件。
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

如需覆盖默认地址或会话名，可以这样执行：

```bash
BASE_URL=http://localhost:5099 SESSION_ID=sampleapi-session ./scripts/sampleapi-generate-xml.sh
```

如果目标端口已被旧的 `SampleApi`/`dotnet` 进程占用，脚本会先尝试自动释放端口；如果占用者不是 `SampleApi`/`dotnet`，脚本会默认中止，避免误杀其他服务。明确需要强制结束任意占用进程时，可这样执行：

```bash
FORCE_KILL_PORT_CONFLICT=1 ./scripts/sampleapi-generate-xml.sh
```

如需覆盖目标框架，可以这样执行：

```bash
TARGET_FRAMEWORK=net8.0 ./scripts/sampleapi-generate-xml.sh
```

#### 2. 生成覆盖率报告

执行 [scripts/sampleapi-generate-report.sh](/Users/tc/github/CoverageX-Material/scripts/sampleapi-generate-report.sh)：

```bash
SOURCE_BRANCH=feature/my-change TARGET_BRANCH=main ./scripts/sampleapi-generate-report.sh
```

### 补充说明

- 如果当前仓库 HEAD 不在 `SOURCE_BRANCH`，`coveragex lreport` 会直接报错；这时要么先切到对应分支，要么改用 `areport`。
- `SampleApi` 脚本依赖 `curl` 和 `dotnet-coverage`。
- `SampleApi` 的脚本里使用的是 shell 的后台执行 `&`，不是 `dotnet-coverage collect --background`。这是因为这里用的是 `collect` 的命令模式，官方文档中的 `--background` 只适用于 server mode。
- 如果不使用 `&`、第二个终端，或者其它后台运行方式，`dotnet-coverage collect --session-id ... "dotnet run ..."` 会一直占用前台，脚本后续步骤不会自动继续执行。
- `SampleApi` 的控制器路由当前是 `api/...`，例如健康检查是 `/api/health`，计算接口是 `/api/calculator/multiply`、`/api/calculator/divide`，项目条目接口是 `/api/items`。
- `SampleApi` 脚本启动前会检查 `BASE_URL` 对应端口是否已被监听，并优先清理旧的 `SampleApi`/`dotnet` 相关进程；如需无条件清理当前端口占用者，可显式传入 `FORCE_KILL_PORT_CONFLICT=1`。
- `SampleLibrary` 生成的 XML 通常位于 `TestResults` 子目录下，因此脚本使用整个输出目录交给 `coveragex` 扫描更稳妥。
