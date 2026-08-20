---
name: scoop-manifest-maker
description: Create, update, validate, and migrate Scoop bucket manifest files. Use this skill whenever the user mentions creating a new app manifest, adding an application to a Scoop bucket, updating an app version, fixing manifest errors, validating manifest files, or provides download URLs for Windows applications (.exe, .msi, .zip, .7z). Also trigger when the user wants to migrate manifests from other buckets, needs help with Scoop manifest JSON structure, or needs to prevent/fix user data loss after app upgrades (persist, profile, user-data-dir, portable data).
---

# Scoop Manifest Maker

帮助用户创建、更新、验证和迁移 Scoop bucket 清单文件。

## 何时使用此技能

当用户：
- 想要为新应用创建 Scoop 清单
- 提供了应用的下载链接（.exe、.msi、.zip、.7z 等）
- 需要更新现有清单的版本
- 想要修复清单中的错误
- 需要验证清单文件的正确性
- 想要从其他 bucket 迁移清单
- 报告"升级后数据丢失"或需要排查持久化问题

## 清单文件结构

Scoop 清单是 JSON 格式文件，包含以下关键字段：

### 必需字段

- **version**: 应用版本号（字符串）
- **description**: 应用描述（字符串）
- **homepage**: 应用主页 URL（字符串）
- **license**: 许可证信息（字符串或对象）
- **architecture**: 架构特定的下载信息（对象）
  - **64bit** 或 **32bit** 或 **arm64**:
    - **url**: 下载链接（字符串或数组）
    - **hash**: SHA256 哈希值（字符串或数组）

### 常用可选字段

- **extract_dir**: 解压后的目录名
- **bin**: 要添加到 PATH 的可执行文件
- **shortcuts**: 开始菜单快捷方式（数组，每项包含 [路径, 显示名称]）
  - 压缩包应用：路径相对于 $dir，如 `["app.exe", "App Name"]`
  - InnoSetup 应用：路径相对于 extract_dir，如 `["app.exe", "App Name"]`
  - MSI 应用：使用 PFiles 前缀，如 `["PFiles\\AppName\\app.exe", "App Name"]`
- **persist**: 需要持久化的目录或文件
- **pre_install**: 安装前执行的 PowerShell 脚本
- **post_install**: 安装后执行的 PowerShell 脚本
- **pre_uninstall**: 卸载前执行的 PowerShell 脚本
- **installer**: 自定义安装脚本
- **uninstaller**: 自定义卸载脚本
- **innosetup**: 是否为 InnoSetup 安装程序（布尔值）
- **checkver**: 版本检查配置
- **autoupdate**: 自动更新配置

## 工作流程

### 1. 创建新清单

当用户想要创建新清单时：

1. **收集信息**：
   - 应用名称
   - 应用版本
   - 下载 URL（支持多架构）
   - 应用主页
   - 许可证信息
   - 应用描述

2. **计算哈希值**：
   使用 PowerShell 计算 SHA256 哈希：
   ```powershell
   (Get-FileHash -Path <downloaded-file> -Algorithm SHA256).Hash.ToLower()
   ```
   或使用 curl 下载并计算：
   ```bash
   curl -L <url> -o temp_file && sha256sum temp_file
   ```

   对于 GitHub Releases，先用 API 列出资产，只下载需要的文件：
   ```bash
   curl -s https://api.github.com/repos/<owner>/<repo>/releases/latest | jq '{tag_name, assets: [.assets[] | {name, browser_download_url, size}]}'
   curl -sL -o app.zip "<browser_download_url>" && sha256sum app.zip
   ```
   - 下载后**解压检查内部结构**（zip 是否含顶层目录、exe 名、子目录），决定 `extract_dir`、`bin`、`shortcuts`：
     ```bash
     python -c "import zipfile; z=zipfile.ZipFile('app.zip'); print('\n'.join(z.namelist()))"
     ```
   - 哈希值**直接从命令输出复制**，不要手抄（手抄易出错，本次实战中 arm64 哈希就因手抄错一位而返工）。
   - 验证哈希时用 `sha256sum` 输出与清单逐一比对，或运行 `.\bin\checkhashes.ps1`。

3. **生成清单文件**：
   - 创建 JSON 结构
   - 填充必需字段
   - 根据应用类型添加适当的可选字段
   - **分析用户数据存放方式并设计持久化**（见"数据持久化与升级数据安全"章节，这是防止升级丢数据的关键）
   - 遵循 4 空格缩进
   - 使用 UTF-8 编码和 CRLF 换行符

4. **添加自动更新配置**（如果可能）：
   - 对于 GitHub releases: `"checkver": "github"`
   - 其他来源: 配置 `checkver` 的 `url` 和 `regex`
   - 配置 `autoupdate` 的 URL 模板
   - **注意版本号前缀**：若上游 tag 带 `V` 前缀（如 `V1.86`），清单中 `version` 应去掉 `V`（写 `1.86`），`autoupdate` 模板中用 `V$version` 补回。`checkver` 的 `github` 简写会自动去除 tag 的 `v`/`V` 前缀。
   - 多架构时，`autoupdate` 中每个架构都要有对应的 URL 模板，与 `architecture` 保持一一对应。

5. **验证清单**：
   运行验证脚本：
   ```powershell
   .\bin\test.ps1 <manifest-name>
   ```

6. **验证数据持久化（防升级丢数据，必做）**：
   - 安装后运行一次程序，确认 `persist\<app>\` 下有文件产生/更新（而非 %APPDATA%/%LOCALAPPDATA%）
   - 重装模拟升级（重跑 post_install 或 `scoop install <app>.json` 后手动重跑钩子脚本），确认数据仍在、无重复创建
   - 用两种方式启动（shim 命令 + 直接运行 exe），确认用同一份数据
   - 卸载（不带 `-p`）后确认 persist 数据保留

### 2. 更新现有清单

当用户想要更新清单版本时：

1. **读取现有清单**：
   从 `bucket/` 目录读取清单文件

2. **检查新版本**：
   - 使用 `.\bin\checkver.ps1` 自动检查
   - 或手动查找新版本信息

3. **更新字段**：
   - 更新 `version` 字段
   - 更新 `url` 字段（如果 URL 包含版本号）
   - 下载新版本并计算新的 `hash` 值

4. **验证更新**：
   运行测试确保清单仍然有效

### 3. 验证和修复清单

当用户需要验证或修复清单时：

1. **运行验证工具**：
   ```powershell
   .\bin\test.ps1              # 测试所有清单
   .\bin\checkurls.ps1         # 检查 URL 可用性
   .\bin\checkhashes.ps1       # 验证哈希值
   .\bin\formatjson.ps1        # 格式化 JSON
   ```

2. **常见问题检查**：
   - 必需字段是否完整
   - URL 是否可访问
   - 哈希值是否正确
   - JSON 格式是否正确
   - 缩进是否为 4 空格
   - 编码是否为 UTF-8

3. **文件格式检查**（Scoop 官方 bucket 测试会检查，漏掉会红）：
   - **必须 CRLF 换行**（`\r\n`），不能是 LF
   - **必须以换行符结尾**（文件末尾要有空行）
   - 无 UTF-8 BOM（`EF BB BF` 开头）
   - 检查方法：
     ```bash
     # 检查末尾是否有换行（Python 可读）
     python -c "
     data = open('bucket/<app>.json','rb').read()
     print('last byte:', data[-1], '== 0x0A:', data[-1] == 0x0A)
     print('first 3 bytes:', data[:3])
     print('CRLF count:', data.count(b'\r\n'))
     "
     # 转换为 CRLF 并补末尾换行
     python -c "
     data = open('bucket/<app>.json','rb').read()
     data = data.replace(b'\r\n', b'\n').replace(b'\n', b'\r\n')
     if not data.endswith(b'\r\n'):
         data += b'\r\n'
     open('bucket/<app>.json','wb').write(data)
     "
     ```

### 4. 从其他 bucket 迁移清单

当用户想要迁移清单时：

1. **获取源清单**：
   从其他 bucket 或官方仓库获取清单文件

2. **审查和调整**：
   - 检查是否需要修改 URL
   - 验证哈希值
   - 调整路径和配置
   - **重点审查持久化实现**（很多上游清单的持久化是坏的或半成品，见下章）
   - 确保符合当前 bucket 的规范

3. **测试清单**：
   在本地测试安装和卸载

## 清单类型示例

### 简单可执行文件

```json
{
    "version": "1.0.0",
    "description": "应用描述",
    "homepage": "https://example.com",
    "license": "MIT",
    "architecture": {
        "64bit": {
            "url": "https://example.com/app-1.0.0-x64.exe",
            "hash": "abc123..."
        }
    },
    "bin": "app.exe",
    "checkver": "github",
    "autoupdate": {
        "architecture": {
            "64bit": {
                "url": "https://example.com/app-$version-x64.exe"
            }
        }
    }
}
```

### 压缩包应用

```json
{
    "version": "1.0.0",
    "description": "应用描述",
    "homepage": "https://example.com",
    "license": "MIT",
    "architecture": {
        "64bit": {
            "url": "https://example.com/app-1.0.0-win64.zip",
            "hash": "abc123..."
        }
    },
    "extract_dir": "app-1.0.0",
    "bin": "bin\\app.exe",
    "shortcuts": [
        [
            "bin\\app.exe",
            "App Name"
        ]
    ]
}
```

### InnoSetup 安装程序

```json
{
    "version": "1.0.0",
    "description": "应用描述",
    "homepage": "https://example.com",
    "license": "MIT",
    "architecture": {
        "64bit": {
            "url": "https://example.com/app-setup-1.0.0.exe",
            "hash": "abc123..."
        }
    },
    "innosetup": true,
    "extract_dir": "{code_GetDestDir}",
    "shortcuts": [
        [
            "app.exe",
            "App Name"
        ]
    ]
}
```

### MSI 安装程序

```json
{
    "version": "1.0.0",
    "description": "应用描述",
    "homepage": "https://example.com",
    "license": "MIT",
    "architecture": {
        "64bit": {
            "url": "https://example.com/app-1.0.0.msi",
            "hash": "abc123..."
        }
    },
    "installer": {
        "script": "Start-Process msiexec -ArgumentList @('/i', \"`\"$dir\\$fname`\"\", '/qn', '/norestart') -Wait -NoNewWindow"
    },
    "shortcuts": [
        [
            "PFiles\\AppName\\app.exe",
            "App Name"
        ]
    ],
    "uninstaller": {
        "script": [
            "$productCode = Get-ItemProperty 'HKLM:\\Software\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\*' | Where-Object { $_.DisplayName -like '*App Name*' } | Select-Object -ExpandProperty PSChildName",
            "if ($productCode) {",
            "    Start-Process msiexec -ArgumentList @('/x', $productCode, '/qn', '/norestart') -Wait -NoNewWindow",
            "} else {",
            "    warn 'App Name product code not found in registry'",
            "}"
        ]
    }
}
```

## 数据持久化与升级数据安全（核心经验）

> 本章沉淀自 chromium 与 firefox 两个清单的真实事故。**升级后"数据丢失"的根因几乎都不是 scoop 或 persist 机制损坏，而是清单没有把用户数据真正接进 persist**。数据通常没真丢，只是程序读写到了另一份数据。

### 1. 铁律：用户数据必须真正落在 persist 里

- **`persist` 字段存在 ≠ 持久化生效**。程序实际读写路径才是真相。
- scoop 机制：`persist\<app>\<path>` 是真实数据目录；`apps\<app>\<version>\<path>` 通过 junction 链接到它。升级、`scoop cleanup`、卸载（不带 `-p`）都不删 persist 数据。
- `persist` 支持数组形式 `["source", "target"]` 做重定向；解压内容与 persist 同名冲突时 scoop 会把解压内容改名为 `*.original` 保留（不覆盖 persist）。
- 验证方法：安装后运行一次程序，检查 `persist\<app>\` 下是否有文件产生/时间戳更新；同时检查 %APPDATA%/%LOCALAPPDATA% 是否出现平行副本。

### 2. 两种持久化模式与它们的坑

**A. 启动参数型**（Chromium 系：`--user-data-dir`、`-profile` 等）

- 参数必须同时挂在 `bin`（shim 参数）和 `shortcuts` 上，如：
  ```json
  "bin": [["app.exe", "app", "--user-data-dir=\"$dir\\User Data\""]],
  "shortcuts": [["app.exe", "App", "--user-data-dir=\"$dir\\User Data\""]]
  ```
- **致命陷阱（入口分裂）**：裸启动 `app.exe`（资源管理器双击、从版本目录固定任务栏图标、第三方启动器、默认浏览器协议调用）不带参数 → 程序静默回落到 %APPDATA%/%LOCALAPPDATA% 默认位置 → 产生第二套数据。升级后"数据丢失"实际是切换到了另一套数据。
- **任务栏固定图标陷阱**：从版本目录固定图标 → 升级后旧目录被清理 → "软件已不存在"提示 → 重新固定时参数可能丢失 → 再次分裂。快捷方式/图标必须指向 `current` junction（永不失效）。
- 结论：**除非程序所有入口都能带参数，否则优先选注册型方案**。

**B. 全局注册型**（Firefox 系：profiles.ini 等注册文件）

- 注册一次（profile → persist 绝对路径），任何入口启动都用同一份数据，无入口分裂问题。
- **陷阱 1（路径不生效）**：`firefox -CreateProfile "Name <path>"` 在目标目录已存在时不生效。而 scoop 的 `persist_data` 在 `post_install` **之前**运行，persist 目录必然已存在 → profile 实际建到 %APPDATA%，persist 形同虚设（extras 版 firefox.json 的原版缺陷，本仓库已修复）。
- **陷阱 2（重复创建）**：`post_install` 每次升级都会重跑，`-CreateProfile` 非幂等 → 每次升级新建一个 `Scoop-<时间戳>` profile → 数据"丢失"（ScoopInstaller/Extras#4377 同款症状：用户看到多个新 profile）。
- 正确做法：**直接受控写入注册文件**，`IsRelative=0` + 绝对路径指向 persist，且幂等（已有指向 persist 的条目即跳过）。参考本仓库 `bucket/firefox.json` 的 post_install 实现。

### 3. 钩子脚本必须幂等

`post_install` / `pre_install` 在**每次升级时都会重跑**。任何创建、复制、注册逻辑必须：
- 先检查目标是否已存在（如 `Test-Path` persist 下的关键文件），已存在则跳过；
- 不依赖"目录不存在"的假设（persist 目录已由 scoop 提前建好）；
- 从 %APPDATA% 迁移旧数据时：仅首次（persist 为空）执行，且用 **copy 而非 move**（保留源，可逆）；
- 写注册文件（profiles.ini 等）时用绝对路径 + `IsRelative=0`，并保留文件中其他应用的条目。

### 4. 升级数据安全验收清单（新清单必查）

- [ ] 程序实际读写 persist 目录（运行一次验证文件变化，而非只看字段）
- [ ] 所有启动入口（shim、快捷方式、裸启动 exe）使用同一份数据，或文档说明限制
- [ ] 快捷方式/任务栏图标指向 `current` junction，而非版本目录
- [ ] post_install / pre_install 幂等（重跑无副作用、无重复创建）
- [ ] 模拟升级后数据仍在、无重复数据目录（时间戳递增的 profile/数据目录是铁证）
- [ ] 卸载（不带 `-p`）后数据保留，重装可复用
- [ ] %APPDATA%/%LOCALAPPDATA% 无平行数据副本产生

### 5. "升级后数据丢失"排查流程

1. 定位程序实际数据目录：检查 persist、%APPDATA%、%LOCALAPPDATA% 各副本的关键文件（profile 名、Last Version/Last Browser、First Run、最后写入时间戳、文件大小）
2. 对比升级前一刻与升级后各副本的活动时间戳 → 确定升级前后各用的是哪套数据（升级前活跃的副本 = 用户真数据所在）
3. 检查启动入口：shim 参数、快捷方式参数、任务栏固定图标的指向与参数
4. 检查 post_install 是否重复创建（多个时间戳递增的数据目录是铁证）
5. 数据一般没真丢——先找到另一份副本，确认归属后再合并或清理（清理前移到回收站，别永久删除）

## 最佳实践

1. **哈希值计算**：始终计算并验证 SHA256 哈希值，确保下载文件的完整性

2. **版本检查**：尽可能配置 `checkver` 和 `autoupdate`，使清单能够自动更新

3. **多架构支持**：如果应用提供多个架构版本（64bit、32bit、arm64），在清单中都包含进去

4. **持久化数据**：使用 `persist` 字段保存用户配置和数据，**并按"数据持久化与升级数据安全"章节验证它真实生效**（这是本仓库最重视的实践，chromium/firefox 两次事故的根源都是 persist 未真正接上）

5. **快捷方式**：为 GUI 应用添加 `shortcuts` 字段，方便用户访问
   - 格式：`[["路径", "显示名称"]]`，可以包含多个快捷方式
   - 压缩包/InnoSetup：路径相对于应用目录，如 `["app.exe", "App Name"]`
   - MSI 安装包：使用 `PFiles` 前缀指向 Program Files，如 `["PFiles\\AppName\\app.exe", "App Name"]`
   - 快捷方式会自动创建在开始菜单的 Scoop Apps 文件夹中
   - 需要携带数据目录参数的快捷方式，参数中的路径一律用 `$dir`（即 `current` junction），不要写死版本目录

6. **脚本钩子**：使用 `pre_install`、`post_install` 等钩子处理特殊安装需求，**必须幂等**

7. **测试验证**：创建或修改清单后，始终运行 `.\bin\test.ps1` 验证

8. **本地测试**：在提交前本地测试安装和卸载：
   ```bash
   scoop bucket add local-test .
   scoop install local-test/<app-name>
   scoop uninstall <app-name>
   ```
   或跳过 bucket 直接安装清单文件：
   ```bash
   scoop install .\bucket\<app-name>.json
   scoop uninstall <app-name>
   ```
   安装输出中应确认 `Checking hash ... ok`（哈希有效）和 `was installed successfully`；卸载输出应确认快捷方式被移除、`current` 链接被解除。
   **有持久化的应用额外测试**：重装模拟升级后数据不丢；两种启动方式用同一份数据；卸载后 persist 数据保留。

## 实战经验（从 TrafficMonitor 清单创建中沉淀）

创建 GitHub Releases 应用的清单时，按以下顺序操作最省事（本次实战验证过）：

1. `curl -s https://api.github.com/repos/<owner>/<repo>/releases/latest | jq` 拿到 `tag_name` 和全部资产（含 URL、大小），一次看清有哪些架构和版本
2. 只下载清单会用到的 zip，`sha256sum` 计算哈希；**解压检查目录结构**确定 `extract_dir` 和 `shortcuts`
3. 从 GitHub API 或 LICENSE 文件确认许可证（本项目是 "Anti 996 License"，SPDX 无标准 ID，直接写 `"Anti996"`）
4. 写完清单后立即验证三件事：schema 校验通过、CRLF + 末尾换行、哈希与 `sha256sum` 输出逐字一致
5. 直接 `scoop install .\bucket\<app>.json` 实测安装，再 `scoop uninstall` 实测卸载

## 实战经验（从 chromium/firefox 数据丢失事故中沉淀）

带用户数据的浏览器/应用清单，必须先回答"用户数据在哪、升级后会不会漂移"：

1. **Chromium 系（--user-data-dir 参数型）**：参数只挂 shim/快捷方式 → 裸启动分裂出 %LOCALAPPDATA% 第二份数据。用户"一直用任务栏图标"也可能中招：图标从版本目录固定、升级后失效重建、参数丢失。诊断铁证：%LOCALAPPDATA% 出现平行 profile（Last Version 停留在旧版本）。修复：快捷方式统一指向 `current`，用户只从 shim/快捷方式启动。
2. **Firefox 系（profiles.ini 注册型）**：`-CreateProfile` 路径参数在 persist 目录已存在时不生效 + 升级重跑重复建 profile。诊断铁证：%APPDATA%\Mozilla\Firefox\Profiles 下多个 `Scoop-<时间戳>` 目录。修复：直接幂等写入 profiles.ini（`IsRelative=0` + persist 绝对路径），本仓库 `bucket/firefox.json` 即修复版参考。
3. 排查数据归属用时间戳对比：升级前一刻活跃的副本才是用户真数据；确认后再迁移/合并/清理，清理移入回收站。

## 工具脚本

项目的 `bin/` 目录包含有用的工具：

- `test.ps1` - 验证清单格式和完整性
- `checkver.ps1` - 检查应用版本更新
- `checkhashes.ps1` - 验证文件哈希值
- `checkurls.ps1` - 检查下载 URL 可用性
- `formatjson.ps1` - 格式化 JSON 清单文件
- `auto-pr.ps1` - 自动创建更新 PR

## 注意事项

- 清单文件必须使用 UTF-8 编码
- 使用 CRLF 换行符（Windows 标准）
- JSON 缩进使用 4 个空格
- 哈希值使用小写
- URL 应该是直接下载链接，不是网页链接
- 版本号应该与上游保持一致
- 许可证标识符应该使用 SPDX 标准（如 MIT、GPL-3.0、Apache-2.0）
- 快捷方式路径使用反斜杠 `\\` 作为路径分隔符
- MSI 应用的快捷方式必须使用 `PFiles\\` 前缀，因为 MSI 安装到 Program Files
- 快捷方式的显示名称应该简洁明了，通常使用应用的正式名称
- 脚本里的路径一律用 `$dir` / `$persist_dir` 变量，不要写死版本目录（升级后失效）
- 钩子脚本引用 `$persist_dir` 时注意：`persist_data` 在 `post_install` 之前运行，persist 目录已存在
- 升级后丢数据的根因排查顺序：启动入口 → persist 是否真生效 → 钩子是否幂等 → 数据副本定位

## 输出格式

创建或更新清单后：

1. 将清单文件保存到 `bucket/<app-name>.json`
2. 运行 `.\bin\formatjson.ps1` 格式化
3. 运行 `.\bin\test.ps1 <app-name>` 验证
4. 向用户报告结果，包括：
   - 清单文件路径
   - 验证结果
   - 数据持久化验证结果（persist 真实生效、升级幂等、无入口分裂）
   - 建议的后续步骤（如本地测试命令）
