# Manggo Scoop 清单设计

## 目标

在私人 Scoop bucket 中新增 `bucket/manggo.json`，使 Windows x64 用户可通过 Scoop 安装 Manggo 0.7.7，并在升级、重装和卸载后保留应用配置与用户数据。

## 上游事实

- 官网：`https://manggo.pylogmon.cn/`
- 版本：`0.7.7`，GitCode latest-release API 与官网当前下载页一致。
- Windows 发布物：`Manggo-0.7.7-Windows-AMD64.exe`，仅提供 AMD64 架构。
- 安装器为可由 Scoop 以 `#/dl.7z` 解包的 Windows 安装包；参考实现的主程序路径为 `bin\Manggo.exe`。
- 应用运行时数据目录为 `%LOCALAPPDATA%\Manggo\Manggo`。
- 官网声明 Windows 运行失败时可能需要 Microsoft Visual C++ x64 运行库；当前 bucket 没有既有运行库依赖惯例，因此清单不额外引入未经验证的依赖字段。

## 清单结构

`bucket/manggo.json` 包含：

- `version`：`0.7.7`。
- `description`、`homepage`、`license`：描述 Manggo 作为桌面翻译与截图 OCR 助手，主页使用官方 HTTPS 地址，许可证标为 `Proprietary`。
- `architecture.64bit`：唯一的可安装架构；包含 GitCode 公开发布 URL、`#/dl.7z` 解包标记，以及从发布物实际下载后计算的 SHA-256 小写值。
- `shortcuts`：为 `bin\Manggo.exe` 创建开始菜单中的 `Manggo` 快捷方式。

## 安装、升级与卸载行为

1. Scoop 解包安装器后，删除 `$PLUGINSDIR` 与 `uninstall.exe`，避免保留无用的安装器残留。
2. `persist` 使用相对名称 `Manggo`。
3. `installer` 在 Scoop 执行内置 `persist` 之前处理 `%LOCALAPPDATA%\Manggo\Manggo`：若 `$persist_dir\Manggo` 尚不存在且运行时目录存在，则先创建 `$persist_dir` 并将运行时目录迁移到该目标。
4. 内置 `persist` 随后建立应用目录与 `$persist_dir\Manggo` 的链接，确保 Scoop 管理此持久化目录。
5. `post_install` 删除任何残留运行时目录，并创建从 `%LOCALAPPDATA%\Manggo\Manggo` 到 `$persist_dir\Manggo` 的目录联接。
6. `post_uninstall` 仅删除运行时目录联接，不删除 Scoop persist 中的真实数据。

此策略使已有非 Scoop 安装的数据在首次 Scoop 安装时迁移，后续版本切换复用相同的数据位置。

## 自动更新

- `checkver` 查询 `https://api.gitcode.com/api/v5/repos/Pylogmon/Manggo/releases/latest`，用 JSONPath `$.tag_name` 读取版本。
- `autoupdate` 在 `architecture.64bit` 内使用 GitCode 发布物命名模板：`Manggo-$version-Windows-AMD64.exe#/dl.7z`。
- 上游目前无 32 位或 ARM64 Windows 发布物，因此不声明虚构的架构支持。

## 验证

1. 下载发布物，计算 SHA-256，并检查解包后存在 `bin\Manggo.exe`。
2. 确认 JSON 可解析、4 空格缩进、UTF-8 无 BOM、CRLF 换行和末尾换行。
3. 运行 `./bin/test.ps1 manggo` 验证 bucket 清单约束。
4. 通过 `scoop install .\bucket\manggo.json` 验证哈希、安装和快捷方式；确认数据目录联接指向 Scoop persist 位置。
5. 通过 `scoop uninstall manggo` 验证卸载不会删除 persist 数据，并移除运行时联接。

## 非目标

- 不创建 macOS 或 Linux 清单。
- 不添加未经上游确认的 Visual C++ 运行库依赖。
- 不修改既有应用清单或 bucket 行为。
