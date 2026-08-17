# Ouroboros Scoop 清单实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 新增一个可由 Scoop 安装、升级和卸载的 `ouroboros` 清单，安装上游 `ouroboros-ai` Python CLI，并暴露 `ooo`、`ouroboros`、`ozo` 三个命令。

**Architecture:** 清单依赖 Scoop Main 的 `python`，下载 GitHub Release 的 platform-independent wheel，在 `$dir\venv` 创建私有虚拟环境并安装 `ouroboros-ai[tui]`。Scoop shim 指向该虚拟环境生成的 console-script executable；不使用 pipx，不把包写入全局 Python，也不迁移用户目录数据。

**Tech Stack:** Scoop JSON manifest、PowerShell 5.1、Python 3.12+、pip、GitHub Release API、Pester/Bucket tests。

## Global Constraints

- 上游版本：`0.51.7`；Release tag：`v0.51.7`。
- wheel：`ouroboros_ai-0.51.7-py3-none-any.whl`。
- wheel SHA-256：`87f1e267506bba05690a073e49ba8de8b24b673e7b1352e6c0673a6606db6db0`。
- Python 要求：`>=3.12`；默认安装 `tui` extra，不安装 `[all]`、`[claude]` 或 `[mcp]`。
- 入口：`ooo`、`ouroboros`、`ozo`。
- 原生 Windows 上游状态为实验支持；Codex CLI 原生 Windows 不支持，使用 WSL2。
- 清单使用 UTF-8 无 BOM、4 空格缩进、CRLF 换行并以换行符结尾。
- 不添加 `persist`，不运行上游 `ouroboros uninstall`，不删除用户目录数据。

---

### Task 1: 创建 Ouroboros Scoop 清单

**Files:**
- Create: `bucket/ouroboros.json`
- Reference: `docs/superpowers/specs/2026-08-17-ouroboros-scoop-manifest-design.md`

**Interfaces:**
- Consumes: GitHub Release wheel URL and SHA-256 from the approved design.
- Produces: A manifest whose `installer.script` creates `$dir\venv`, installs the wheel with the `tui` extra, and whose `bin` points to the three generated executables.

- [ ] **Step 1: Reconfirm the release artifact and digest**

Run in PowerShell:

```powershell
$asset = Join-Path $env:TEMP 'ouroboros_ai-0.51.7-py3-none-any.whl'
Invoke-WebRequest -Uri 'https://github.com/Q00/ouroboros/releases/download/v0.51.7/ouroboros_ai-0.51.7-py3-none-any.whl' -OutFile $asset
(Get-FileHash -Path $asset -Algorithm SHA256).Hash.ToLower()
```

Expected: the printed digest is exactly `87f1e267506bba05690a073e49ba8de8b24b673e7b1352e6c0673a6606db6db0`.

- [ ] **Step 2: Write the manifest with the approved install boundary**

Create `bucket/ouroboros.json` with this content:

```json
{
    "version": "0.51.7",
    "description": "Specification-first Agent OS for replayable AI coding workflows.",
    "homepage": "https://github.com/Q00/ouroboros",
    "license": "MIT",
    "depends": "python",
    "url": "https://github.com/Q00/ouroboros/releases/download/v0.51.7/ouroboros_ai-0.51.7-py3-none-any.whl",
    "hash": "87f1e267506bba05690a073e49ba8de8b24b673e7b1352e6c0673a6606db6db0",
    "installer": {
        "script": [
            "& (Join-Path (appdir python) 'current\\python.exe') -m venv (Join-Path $dir 'venv')",
            "& \"$dir\\venv\\Scripts\\python.exe\" -m pip install --disable-pip-version-check --no-cache-dir \"$dir\\$fname[tui]\""
        ]
    },
    "bin": [
        "venv\\Scripts\\ooo.exe",
        "venv\\Scripts\\ouroboros.exe",
        "venv\\Scripts\\ozo.exe"
    ],
    "notes": [
        "首次使用请运行：ouroboros setup",
        "上游将原生 Windows 支持标记为实验状态；Codex CLI 原生 Windows 不支持，建议在 WSL2 中使用。",
        "本清单安装基础 CLI 与 tui profile；Claude、MCP 等 profile 请按实际宿主单独配置。",
        "Scoop 卸载不会调用 ouroboros uninstall，因此不会自动删除用户目录中的配置或数据。"
    ],
    "checkver": {
        "github": "https://github.com/Q00/ouroboros"
    },
    "autoupdate": {
        "url": "https://github.com/Q00/ouroboros/releases/download/v$version/ouroboros_ai-$version-py3-none-any.whl",
        "hash": {
            "url": "https://api.github.com/repos/Q00/ouroboros/releases/tags/v$version",
            "jsonpath": "$.assets[?(@.name == 'ouroboros_ai-$version-py3-none-any.whl')].digest",
            "regex": "sha256:(.*)"
        }
    }
}
```

The installer must use the venv's Python for `pip`; no command may install into the Scoop `python` prefix or invoke pipx. The wheel remains the only manifest download; pip resolves the package's declared runtime and `tui` dependencies from PyPI.

- [ ] **Step 3: Normalize JSON formatting and line endings**

Run:

```powershell
.\bin\formatjson.ps1 ouroboros
```

Then verify the file is UTF-8 without BOM, uses CRLF, and ends in CRLF:

```powershell
$bytes = [IO.File]::ReadAllBytes('.\bucket\ouroboros.json')
[Text.Encoding]::UTF8.GetString($bytes) | ConvertFrom-Json | Out-Null
[BitConverter]::ToString($bytes[0..2])
$bytes[-2] -eq 13 -and $bytes[-1] -eq 10
```

Expected: JSON parsing succeeds, the first three bytes are not `EF-BB-BF`, and the final expression is `True`.

- [ ] **Step 4: Commit the manifest**

```powershell
git add bucket/ouroboros.json
git commit -m "feat: add Ouroboros Scoop manifest"
```

Expected: one commit containing only `bucket/ouroboros.json`.

### Task 2: Run static manifest and artifact validation

**Files:**
- Test: `bucket/ouroboros.json`
- Use: `bin/test.ps1`, `bin/checkhashes.ps1`, `bin/checkurls.ps1`, `bin/checkver.ps1`

**Interfaces:**
- Consumes: `bucket/ouroboros.json` from Task 1.
- Produces: Passing bucket schema checks, matching hash, reachable URL, and a GitHub checkver result for `0.51.7`.

- [ ] **Step 1: Run the bucket Pester suite for the manifest**

```powershell
.\bin\test.ps1
```

Expected: the Pester run completes with `FailedCount` equal to `0`; no JSON schema or manifest-field failure is reported for `ouroboros`.

- [ ] **Step 2: Recheck the downloaded file against the manifest hash**

```powershell
.\bin\checkhashes.ps1 ouroboros
```

Expected: the wheel download reports an `ok` hash result for `ouroboros`.

- [ ] **Step 3: Check URL reachability and version discovery**

```powershell
.\bin\checkurls.ps1 ouroboros
.\bin\checkver.ps1 ouroboros
```

Expected: the wheel URL is reachable; checkver resolves the current stable version as `0.51.7` and the generated URL contains `v0.51.7/ouroboros_ai-0.51.7-py3-none-any.whl`.

### Task 3: Smoke-test install, command shims, update boundary, and uninstall

**Files:**
- Test: installed `ouroboros` Scoop app and `bucket/ouroboros.json`

**Interfaces:**
- Consumes: validated `bucket/ouroboros.json`.
- Produces: evidence that install creates a private venv and all three entry points work; uninstall removes Scoop-managed files without invoking upstream data deletion.

- [ ] **Step 1: Install the local manifest**

```powershell
scoop install .\bucket\ouroboros.json
```

Expected: Scoop reports a successful install and a valid wheel hash; pip completes dependency resolution inside the app's `venv`.

- [ ] **Step 2: Verify the private venv and three entry points**

```powershell
$appDir = scoop prefix ouroboros
Test-Path (Join-Path $appDir 'current\venv\Scripts\ooo.exe')
Test-Path (Join-Path $appDir 'current\venv\Scripts\ouroboros.exe')
Test-Path (Join-Path $appDir 'current\venv\Scripts\ozo.exe')
ouroboros --version
ooo --help
$ozoHelp = & ozo --help 2>&1
$ozoHelp
```

Expected: all three `Test-Path` calls return `True`; `ouroboros --version` reports `0.51.7`; `ooo --help` and `ozo --help` return successfully.

- [ ] **Step 3: Confirm shims resolve through Scoop's current link**

```powershell
(Get-Command ooo).Source
(Get-Command ouroboros).Source
(Get-Command ozo).Source
```

Expected: each command resolves to a Scoop shim, not a global Python or pipx installation.

- [ ] **Step 4: Uninstall and verify cleanup boundary**

```powershell
scoop uninstall ouroboros
Test-Path (Join-Path $env:SCOOP 'apps\ouroboros')
```

Expected: uninstall succeeds and the app directory test returns `False`; no `ouroboros uninstall` command is invoked and no user-directory cleanup is attempted.

- [ ] **Step 5: Record final verification and leave no test installation**

Run the static checks from Task 2 once more after the final manifest state, then confirm `scoop list ouroboros` no longer reports an installed app. Do not delete or alter any pre-existing `%USERPROFILE%\.ouroboros` data.

Expected: all applicable checks pass, the app is absent from Scoop, and the working tree contains only the intentionally created manifest plus the already committed design/plan documents.
