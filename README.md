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

如果希望在采集过程中按快照方式导出覆盖率结果，可先使用 `dotnet-coverage collect` 启动会话，然后通过 `dotnet-coverage snapshot` 生成覆盖率 XML。典型流程如下：

```bash
dotnet-coverage collect "dotnet run --project ./src/SampleApi" --background --session-id sampleapi-session
```

完成请求测试后，执行：

```bash
dotnet-coverage snapshot sampleapi-session -f cobertura -o ~/.coveragex/output/sampleapi-snapshot.xml
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
	--report-directory ~/.coveragex/incremental-report \
	--report-type Html
```

参数说明：

- `--source`：生成这份覆盖率 XML 时对应的源码分支，通常就是你当前正在测试的分支。
- `--target`：用于做 diff 对比的目标分支，例如 `main`。
- `--source-directory`：必须指向本地 Git working tree 根目录。
- `--report-input-directories`：传入上一步生成 XML 的目录。CoverageX 会扫描该目录顶层的 `*.xml` 文件。
- `--report-directory`：增量覆盖率报告输出目录。

如果你只想传入某一个 XML 文件，也可以改用 `--report-input-files`：

```bash
coveragex lreport \
	--source feature/my-change \
	--target main \
	--source-directory ~/github/CoverageX-Material \
	--report-input-files ~/.coveragex/output/sampleapi-snapshot.xml \
	--report-directory ~/.coveragex/incremental-report \
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
	--report-directory ~/.coveragex/incremental-report \
	--report-type Html
```

### 使用时的关键约束

- CoverageX 不负责生成覆盖率 XML；必须先通过前面的 `dotnet test` 或 `dotnet-coverage` 拿到 XML，再传给 `lreport` 或 `areport`。
- `lreport` 要求当前本地仓库 HEAD 必须与 `runtime-branch` 一致；如果不显式传 `--runtime-branch`，CoverageX 会默认使用 `--source` 作为 `runtime-branch`。
- `source`、`target`、`runtime-branch` 目前都要求传分支名，不会自动帮你 fetch 或 checkout 缺失分支。
- `filter-mode` 支持 `diff`、`merge`、`explicit` 三种模式；如果不需要额外过滤，直接用默认行为即可。
