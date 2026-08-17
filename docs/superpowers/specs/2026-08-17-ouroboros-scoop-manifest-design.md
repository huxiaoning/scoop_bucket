# Ouroboros Scoop 清单设计

## 目标

在私人 Scoop bucket 中新增 `bucket/ouroboros.json`，使 Windows 用户可以通过 Scoop 安装 Ouroboros 的完整 Python CLI，并通过 Scoop 管理版本、升级和卸载。

本清单的目标入口是 Python 包提供的 `ooo`、`ouroboros` 和 `ozo` 命令，不是发行版中功能不同的 `ouroboros-tui.exe` 原生二进制。

## 上游事实

- 仓库：`https://github.com/Q00/ouroboros`
- 许可证：MIT。
- 当前版本：`0.51.7`，GitHub Release tag 为 `v0.51.7`。
- Python 包：`ouroboros-ai`，要求 Python `>=3.12`。
- Windows 可用发布物：`ouroboros_ai-0.51.7-py3-none-any.whl`。
- 发布物 URL：`https://github.com/Q00/ouroboros/releases/download/v0.51.7/ouroboros_ai-0.51.7-py3-none-any.whl`。
- 当前 wheel SHA-256：`87f1e267506bba05690a073e49ba8de8b24b673e7b1352e6c0673a6606db6db0`。
- `pyproject.toml` 声明的脚本入口为 `ooo = ouroboros.cli.main:app`、`ouroboros = ouroboros.cli.main:app` 和 `ozo = ouroboros.cli.commands.zcode:app`。
- 上游默认安装脚本在未选择宿主时使用 `[tui]` profile；该 profile 支持 Python 3.12–3.14。`[all]` 包含 Claude/MCP 1.x 与 LiteLLM，存在运行时互斥和 Python 版本限制，不适合作为固定 Scoop 默认 profile。
- 上游文档将原生 Windows 标为实验支持；Codex CLI 在原生 Windows 不支持，建议使用 WSL2。终端/TUI 需要 ANSI 支持，`cmd.exe` 不在支持范围内。

## 方案比较

### 方案 A：Scoop 私有虚拟环境（采用）

清单依赖 `python`，将 wheel 下载到应用目录，在 `$dir\venv` 创建虚拟环境，并在其中安装 `ouroboros-ai[tui]`。`bin` 指向虚拟环境生成的三个 Windows console-script executable。

优点：依赖不写入全局 Python；Scoop 的 current 链接、版本切换和应用目录删除可以完整管理运行环境；wheel 为 `py3-none-any`，不需要本地编译。

代价：首次安装仍需从 PyPI 解析并下载 Python 依赖；清单不能替用户选择 Claude、MCP 等互斥 profile。

### 方案 B：调用 pipx

在 `post_install` 中调用 `pipx install`，再通过 pipx 的全局入口暴露命令。

不采用：pipx 环境和入口通常位于 Scoop 应用目录之外，Scoop 更新/卸载的生命周期边界不清晰，容易留下外部状态。

### 方案 C：安装原生 TUI

直接安装 Release 中的 `ouroboros-tui-x86_64-pc-windows-msvc.exe`。

不采用：这是独立的原生 TUI 监视器，不提供 Python 包的完整 `ooo`/`ouroboros` 工作流 CLI，与本次目标不一致。

## 清单结构

`bucket/ouroboros.json` 包含：

- `version`：去掉 tag 前缀的 `0.51.7`。
- `description`、`homepage`、`license`：描述 Agent OS CLI，主页使用上游仓库，许可证为 `MIT`。
- `depends`：`python`，由 Scoop Main bucket 提供 Python `>=3.12` 运行时。
- 顶层 `url` 与 `hash`：下载 GitHub Release wheel，并使用已验证的小写 SHA-256。
- `installer.script`：在 `$dir\venv` 创建虚拟环境，使用该环境的 Python 安装本地 wheel 及其 `tui` extra；不向全局 Python 写入包。
- `bin`：暴露 `venv\Scripts\ooo.exe`、`venv\Scripts\ouroboros.exe` 和 `venv\Scripts\ozo.exe`。
- `notes`：说明首次使用需运行 `ouroboros setup`，并提示原生 Windows 的上游限制、Codex/WSL2 建议及 profile 边界。
- `checkver`：使用 GitHub Release 检查版本。
- `autoupdate`：按 `v$version/ouroboros_ai-$version-py3-none-any.whl` 生成下载 URL；通过 GitHub Release API 中同名 asset 的 `digest` 自动读取 SHA-256。

不添加 `persist`：Ouroboros 的配置和运行数据由上游写在用户目录中，不属于 Scoop 应用目录；清单不擅自迁移或删除用户数据。Scoop 卸载只移除该清单管理的虚拟环境。

## 安装、升级与卸载行为

1. Scoop 安装 `python` 依赖并下载当前 wheel。
2. 清单脚本创建 `$dir\venv`，随后在该环境中解析并安装基础依赖与 `tui` extra。
3. Scoop 根据 `bin` 创建三个 shim；命令实际使用当前版本目录中的虚拟环境。
4. Scoop 更新时在新版本目录重复创建独立虚拟环境，不复用旧版本的绝对路径；旧版本由 Scoop 清理。
5. Scoop 卸载时删除应用目录和虚拟环境，不运行上游 `ouroboros uninstall`，因此不会隐式删除用户目录下的配置、MCP 注册或数据。

## 自动更新

- `checkver`：`github` 简写检查 `https://github.com/Q00/ouroboros` 的稳定 Release，并将 `v0.51.7` 规范化为 `0.51.7`。
- `autoupdate.url`：`https://github.com/Q00/ouroboros/releases/download/v$version/ouroboros_ai-$version-py3-none-any.whl`。
- `autoupdate.hash`：查询 `https://api.github.com/repos/Q00/ouroboros/releases/tags/v$version`，从名称为 `ouroboros_ai-$version-py3-none-any.whl` 的 asset 读取 `digest`，再提取 `sha256:` 后的值。

## 验证

1. 下载当前 wheel，确认 SHA-256 与 `87f1e267506bba05690a073e49ba8de8b24b673e7b1352e6c0673a6606db6db0` 一致。
2. 用 Scoop manifest 测试脚本确认 JSON 可解析、字段合法、URL/hash 配对正确。
3. 检查 UTF-8 无 BOM、4 空格缩进、CRLF 换行和末尾换行。
4. 运行 `scoop install .\bucket\ouroboros.json`，确认 wheel 依赖安装完成且三个命令可运行；至少执行 `ouroboros --version` 与 `ooo --help`。
5. 运行 `scoop update ouroboros` 或使用新版本清单路径，确认命令 shim 指向新版本虚拟环境。
6. 运行 `scoop uninstall ouroboros`，确认应用目录、虚拟环境和三个 shim 被移除，用户目录数据未被清理。

## 非目标

- 不把 `ouroboros-tui.exe` 合并进 Python CLI 清单。
- 不默认安装 `[all]`、`[claude]` 或 `[mcp]` 等需要按宿主选择的 profile。
- 不为原生 Windows 未验证的运行时能力添加额外兼容层或修复脚本。
- 不修改上游项目、既有 bucket 清单或用户目录中的 Ouroboros 数据。
