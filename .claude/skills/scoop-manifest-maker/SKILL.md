---
name: scoop-manifest-maker
description: Create, update, validate, and migrate Scoop bucket manifest files. Use this skill whenever the user mentions creating a new app manifest, adding an application to a Scoop bucket, updating an app version, fixing manifest errors, validating manifest files, or provides download URLs for Windows applications (.exe, .msi, .zip, .7z). Also trigger when the user wants to migrate manifests from other buckets or needs help with Scoop manifest JSON structure.
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

3. **生成清单文件**：
   - 创建 JSON 结构
   - 填充必需字段
   - 根据应用类型添加适当的可选字段
   - 遵循 4 空格缩进
   - 使用 UTF-8 编码和 CRLF 换行符

4. **添加自动更新配置**（如果可能）：
   - 对于 GitHub releases: `"checkver": "github"`
   - 对于其他来源: 配置 `checkver` 的 `url` 和 `regex`
   - 配置 `autoupdate` 的 URL 模板

5. **验证清单**：
   运行验证脚本：
   ```powershell
   .\bin\test.ps1 <manifest-name>
   ```

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

3. **修复问题**：
   根据验证结果修复发现的问题

### 4. 从其他 bucket 迁移清单

当用户想要迁移清单时：

1. **获取源清单**：
   从其他 bucket 或官方仓库获取清单文件

2. **审查和调整**：
   - 检查是否需要修改 URL
   - 验证哈希值
   - 调整路径和配置
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

## 最佳实践

1. **哈希值计算**：始终计算并验证 SHA256 哈希值，确保下载文件的完整性

2. **版本检查**：尽可能配置 `checkver` 和 `autoupdate`，使清单能够自动更新

3. **多架构支持**：如果应用提供多个架构版本（64bit、32bit、arm64），在清单中都包含进去

4. **持久化数据**：使用 `persist` 字段保存用户配置和数据

5. **快捷方式**：为 GUI 应用添加 `shortcuts` 字段，方便用户访问
   - 格式：`[["路径", "显示名称"]]`，可以包含多个快捷方式
   - 压缩包/InnoSetup：路径相对于应用目录，如 `["app.exe", "App Name"]`
   - MSI 安装包：使用 `PFiles` 前缀指向 Program Files，如 `["PFiles\\AppName\\app.exe", "App Name"]`
   - 快捷方式会自动创建在开始菜单的 Scoop Apps 文件夹中

6. **脚本钩子**：使用 `pre_install`、`post_install` 等钩子处理特殊安装需求

7. **测试验证**：创建或修改清单后，始终运行 `.\bin\test.ps1` 验证

8. **本地测试**：在提交前本地测试安装和卸载：
   ```bash
   scoop bucket add local-test .
   scoop install local-test/<app-name>
   scoop uninstall <app-name>
   ```

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

## 输出格式

创建或更新清单后：

1. 将清单文件保存到 `bucket/<app-name>.json`
2. 运行 `.\bin\formatjson.ps1` 格式化
3. 运行 `.\bin\test.ps1 <app-name>` 验证
4. 向用户报告结果，包括：
   - 清单文件路径
   - 验证结果
   - 建议的后续步骤（如本地测试命令）
