# Manggo Scoop Manifest Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a verified Scoop manifest that installs Manggo 0.7.7 on Windows x64 and preserves its user data across upgrades and uninstallations.

**Architecture:** Add one self-contained JSON manifest under `bucket/`. Scoop downloads and extracts the upstream NSIS installer, exposes `bin\Manggo.exe` via a Start menu shortcut, and uses post-install/post-uninstall hooks to redirect `%LOCALAPPDATA%\Manggo\Manggo` to Scoop's persisted data directory.

**Tech Stack:** Scoop manifest JSON, PowerShell hooks, upstream GitCode release API, 7-Zip, Pester bucket tests.

## Global Constraints

- Create exactly `bucket/manggo.json`; do not alter existing manifests.
- Support only Windows x64 because upstream 0.7.7 publishes only `Manggo-0.7.7-Windows-AMD64.exe`.
- Use the official GitCode release URL and SHA-256 `d9ee20953749778cd3c20c17bfaeb8ce49687e3cceeaf2d3e065e96a27466868` verified from the 83,921,928-byte release artifact.
- Treat the release installer as an NSIS archive using `#/dl.7z`; extracted executable path is `bin\Manggo.exe`.
- Preserve application data at `%LOCALAPPDATA%\Manggo\Manggo` through the manifest’s `persist` directory named `Manggo`.
- Use UTF-8 without BOM, four-space indentation, CRLF line endings, and a final newline as required by `.editorconfig` and `.gitattributes`.
- Do not add a Visual C++ runtime dependency: upstream offers it only as a manual troubleshooting note and the repository has no verified dependency convention for it.

---

### Task 1: Add the Manggo manifest

**Files:**
- Create: `bucket/manggo.json`
- Reference: `bucket/pot.json:1-45`
- Reference: `docs/superpowers/specs/2026-08-12-manggo-scoop-manifest-design.md:16-42`

**Interfaces:**
- Consumes: GitCode release API response at `https://api.gitcode.com/api/v5/repos/Pylogmon/Manggo/releases/latest`, whose `tag_name` is `0.7.7`.
- Produces: Scoop manifest `manggo` installable by `scoop install .\bucket\manggo.json`.

- [ ] **Step 1: Create `bucket/manggo.json` with verified release metadata and install behavior**

  Write this exact manifest body, keeping four-space JSON indentation:

  ```json
  {
      "version": "0.7.7",
      "description": "A desktop translation and screenshot OCR assistant for academic reading, web browsing, and cross-language communication.",
      "homepage": "https://manggo.pylogmon.cn/",
      "license": "Proprietary",
      "architecture": {
          "64bit": {
              "url": "https://gitcode.com/Pylogmon/Manggo/releases/download/0.7.7/Manggo-0.7.7-Windows-AMD64.exe#/dl.7z",
              "hash": "d9ee20953749778cd3c20c17bfaeb8ce49687e3cceeaf2d3e065e96a27466868"
          }
      },
      "shortcuts": [
          [
              "bin\\Manggo.exe",
              "Manggo"
          ]
      ],
      "installer": {
          "script": [
              "$runtimeCache = \"$env:LocalAppData\\Manggo\\Manggo\"",
              "$runtimeCachePersist = \"$persist_dir\\Manggo\"",
              "if (!(Test-Path $runtimeCachePersist) -and (Test-Path $runtimeCache)) {",
              "    New-Item -ItemType Directory -Path $persist_dir -Force | Out-Null",
              "    Move-Item -Path $runtimeCache -Destination $runtimeCachePersist -Force",
              "}"
          ]
      },
      "post_install": [
          "Remove-Item \"$dir\\`$PLUGINSDIR\", \"$dir\\uninstall.exe\" -Force -Recurse -ErrorAction SilentlyContinue",
          "$runtimeCache = \"$env:LocalAppData\\Manggo\\Manggo\"",
          "$runtimeCachePersist = \"$persist_dir\\Manggo\"",
          "Remove-Item -Path $runtimeCache -Force -Recurse -ErrorAction SilentlyContinue",
          "New-DirectoryJunction $runtimeCache $runtimeCachePersist | Out-Null"
      ],
      "post_uninstall": [
          "$runtimeCache = \"$env:LocalAppData\\Manggo\\Manggo\"",
          "Remove-Item -Path $runtimeCache -Force -Recurse -ErrorAction SilentlyContinue"
      ],
      "persist": "Manggo",
      "checkver": {
          "url": "https://api.gitcode.com/api/v5/repos/Pylogmon/Manggo/releases/latest",
          "jsonpath": "$.tag_name"
      },
      "autoupdate": {
          "architecture": {
              "64bit": {
                  "url": "https://gitcode.com/Pylogmon/Manggo/releases/download/$version/Manggo-$version-Windows-AMD64.exe#/dl.7z"
              }
          }
      }
  }
  ```

  `installer` runs before Scoop’s built-in `persist` phase: it migrates an existing non-Scoop runtime directory only when `$persist_dir\Manggo` does not yet exist. Scoop then creates and manages the persisted target. `post_install` removes any remaining runtime directory and creates its directory junction only after the target is available. This ordering avoids deleting existing user data during first Scoop installation. `post_uninstall` removes only the runtime directory junction, so Scoop retains `persist\Manggo`.

- [ ] **Step 2: Validate JSON syntax and required manifest fields**

  Run:

  ```powershell
  Get-Content .\bucket\manggo.json -Raw | ConvertFrom-Json | ConvertTo-Json -Depth 10
  ```

  Expected: exit code `0`; output includes version `0.7.7`, `architecture.64bit.url`, `architecture.64bit.hash`, `persist`, `checkver`, and `autoupdate`.

- [ ] **Step 3: Verify repository file encoding and line-ending constraints**

  Run:

  ```powershell
  $bytes = [System.IO.File]::ReadAllBytes('.\bucket\manggo.json')
  $hasBom = $bytes.Length -ge 3 -and $bytes[0..2] -ceq @(0xEF, 0xBB, 0xBF)
  [pscustomobject]@{
      HasUtf8Bom = $hasBom
      EndsWithCrLf = $bytes[-2] -eq 0x0D -and $bytes[-1] -eq 0x0A
      CrLfCount = ([Text.Encoding]::UTF8.GetString($bytes).Split("`r`n").Count - 1)
      BareLfCount = ([Text.Encoding]::UTF8.GetString($bytes) -split "(?<!`r)`n").Count - 1
  }
  ```

  Expected: `HasUtf8Bom` is `False`, `EndsWithCrLf` is `True`, `CrLfCount` is positive, and `BareLfCount` is `0`.

- [ ] **Step 4: Commit the manifest**

  ```bash
  git add bucket/manggo.json
  git commit -m "manggo: Add version 0.7.7"
  ```

### Task 2: Validate the release artifact and Scoop lifecycle

**Files:**
- Verify: `bucket/manggo.json`
- Reference: `bin/test.ps1:1-15`
- Reference: `Scoop-Bucket.Tests.ps1:1-2`
- Reference: `docs/superpowers/specs/2026-08-12-manggo-scoop-manifest-design.md:44-50`

**Interfaces:**
- Consumes: `bucket/manggo.json` created in Task 1 and Scoop at `F:\Scoop\.scoop\apps\scoop\current`.
- Produces: evidence that the manifest passes bucket validation, download integrity, executable path discovery, persistence linking, and uninstall cleanup.

- [ ] **Step 1: Recompute and compare the upstream artifact hash**

  Run:

  ```powershell
  $manifest = Get-Content .\bucket\manggo.json -Raw | ConvertFrom-Json
  $release = $manifest.architecture.'64bit'
  Invoke-WebRequest -Uri ($release.url -replace '#/dl\.7z$', '') -OutFile .\.tmp\manggo-0.7.7-Windows-AMD64.exe
  $actual = (Get-FileHash .\.tmp\manggo-0.7.7-Windows-AMD64.exe -Algorithm SHA256).Hash.ToLower()
  if ($actual -ne $release.hash) { throw "Manifest hash $($release.hash) does not match downloaded hash $actual" }
  $actual
  ```

  Expected: prints `d9ee20953749778cd3c20c17bfaeb8ce49687e3cceeaf2d3e065e96a27466868` without throwing.

- [ ] **Step 2: Confirm the NSIS archive exposes the shortcut target**

  Run:

  ```powershell
  7z l .\.tmp\manggo-0.7.7-Windows-AMD64.exe | Select-String -SimpleMatch 'bin\Manggo.exe'
  ```

  Expected: one listing line for `bin\Manggo.exe`; this proves the manifest’s `shortcuts` target is valid after `#/dl.7z` extraction.

- [ ] **Step 3: Run the repository bucket test suite**

  Run:

  ```powershell
  .\bin\test.ps1
  ```

  Expected: Pester completes with zero failed tests, including validation of `bucket\manggo.json`. The repository wrapper does not forward an app-name filter to Pester. If the local BuildHelpers/Pester prerequisites are missing, install neither dependency in the manifest; record the local environment failure separately and continue with the direct lifecycle test.

- [ ] **Step 4: Exercise installation and verify persistence linkage**

  Run:

  ```powershell
  scoop install .\bucket\manggo.json
  $runtimeCache = Join-Path $env:LOCALAPPDATA 'Manggo\Manggo'
  $appDir = scoop prefix manggo
  $scoopRoot = Split-Path (Split-Path (Split-Path $appDir -Parent) -Parent) -Parent
  $persistDir = Join-Path $scoopRoot 'persist\manggo\Manggo'
  if (-not (Test-Path (Join-Path $appDir 'bin\Manggo.exe'))) { throw 'Manggo executable was not installed' }
  if (-not (Test-Path $runtimeCache)) { throw 'Manggo runtime cache junction was not created' }
  if (-not (Test-Path $persistDir)) { throw 'Manggo persist directory was not created' }
  Get-Item $runtimeCache | Format-List FullName,LinkType,Target
  ```

  Expected: Scoop reports hash verification and successful installation; `bin\Manggo.exe`, the runtime cache path, and the persistent data path exist. The runtime cache reports a link type and target pointing to the persisted `Manggo` directory.

- [ ] **Step 5: Exercise uninstall without deleting persisted data**

  Run:

  ```powershell
  scoop uninstall manggo
  if (Test-Path $runtimeCache) { throw 'Manggo runtime cache junction remains after uninstall' }
  if (-not (Test-Path $persistDir)) { throw 'Manggo persisted data was deleted during uninstall' }
  ```

  Expected: uninstall succeeds; `%LOCALAPPDATA%\Manggo\Manggo` no longer exists and Scoop’s `persist\manggo\Manggo` remains.

- [ ] **Step 6: Remove only the temporary validation download and commit verification-ready state**

  Run:

  ```powershell
  Remove-Item .\.tmp\manggo-0.7.7-Windows-AMD64.exe -Force
  git status --short
  ```

  Expected: temporary installer is absent; status shows no unintentional validation artifacts. Do not remove any pre-existing files under `.tmp`.

## Self-Review

- **Spec coverage:** Task 1 implements the versioned official URL, hash, shortcut, cleanup hooks, persistence, `checkver`, and `autoupdate`. Task 2 validates artifact integrity, extracted executable path, repository test, installation, persistence linkage, and uninstall behavior.
- **Placeholder scan:** No `TBD`, `TODO`, deferred implementation, ambiguous validation, or undefined interfaces remain.
- **Consistency:** The executable path is consistently `bin\Manggo.exe`; the runtime data path is consistently `%LOCALAPPDATA%\Manggo\Manggo`; persistence is consistently `Manggo`; the release version and SHA-256 are consistently `0.7.7` and `d9ee20953749778cd3c20c17bfaeb8ce49687e3cceeaf2d3e065e96a27466868`.
