# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目概述

这是一个私人 Scoop bucket 仓库，包含 75+ 个 Windows 应用程序清单。Scoop 是 Windows 的命令行包管理器，bucket 是应用清单的集合，用于分发和管理应用程序。

## 目录结构

- `bucket/` - 应用清单文件（JSON 格式），所有应用清单都存放在此目录
- `bin/` - PowerShell 工具脚本，用于测试、验证和自动化
- `deprecated/` - 已弃用的应用清单
- `.github/workflows/` - CI/CD 配置（GitHub Actions）

## 常用命令

### 测试和验证

```powershell
.\bin\test.ps1                  # 运行所有测试（验证清单格式和完整性）
.\bin\checkver.ps1              # 检查应用版本更新
.\bin\checkhashes.ps1           # 验证文件哈希值
.\bin\checkurls.ps1             # 检查下载 URL 可用性
.\bin\formatjson.ps1            # 格式化 JSON 清单文件
.\bin\missing-checkver.ps1      # 检查缺失的版本检查配置
```

### 本地测试 bucket

```bash
scoop bucket add local-test .           # 添加本地 bucket 进行测试
scoop install local-test/<app-name>     # 安装应用测试
scoop uninstall <app-name>              # 卸载应用
```

## 清单文件规范

- **位置**：所有清单文件位于 `bucket/` 目录
- **格式**：JSON 格式
- **必需字段**：`version`, `description`, `homepage`, `license`, `architecture`, `url`, `hash`
- **编码规范**（遵循 `.editorconfig`）：
  - UTF-8 编码
  - CRLF 换行符
  - 4 空格缩进（JSON 文件）
  - YAML 文件使用 2 空格缩进

## CI/CD 工作流

- `ci.yml` - 在 push 和 PR 时自动运行 `bin\test.ps1` 测试
- `pull_request.yml` - 使用 ScoopInstaller/GithubActions 进行 PR 验证
- `excavator.yml` - 自动更新应用版本
- `issues.yml` 和 `issue_comment.yml` - Issue 自动化处理

## 开发工作流程

1. 创建或修改 `bucket/` 目录中的清单文件
2. 运行 `.\bin\formatjson.ps1` 格式化 JSON
3. 运行 `.\bin\test.ps1` 验证清单
4. 本地测试：添加 bucket 并安装/卸载应用
5. 提交 PR（使用 `.github/pull_request_template.md` 模板）

## 关键文件

- `bin/utils.ps1` - 通用工具函数库（包含安装/卸载钩子函数）
- `.editorconfig` - 编码标准配置
- `.github/pull_request_template.md` - PR 模板
