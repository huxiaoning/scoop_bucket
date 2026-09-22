# Send a URL to YTDownloader by pasting it into the focused main window.
# External Application Button:
#   wt pwsh -NoExit -Command "ytdlpaste [HREF]"
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Url
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($Url)) {
    throw 'A URL is required.'
}

Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class YtDlPasteWin {
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool BringWindowToTop(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] public static extern bool AttachThreadInput(uint idAttach, uint idAttachTo, bool fAttach);
    [DllImport("kernel32.dll")] public static extern uint GetCurrentThreadId();
    [DllImport("user32.dll")] public static extern bool IsIconic(IntPtr hWnd);
}
'@

function Get-YtDownloaderProcess {
    $candidates = @(Get-Process -Name 'YTDownloader' -ErrorAction SilentlyContinue)
    $visible = $candidates | Where-Object { $_.MainWindowHandle -ne 0 -and $_.MainWindowTitle -eq 'ytDownloader' } | Select-Object -First 1
    if ($visible) { return $visible }
    return $null
}

function Start-YtDownloader {
    $command = Get-Command 'ytdownloader' -ErrorAction SilentlyContinue
    if (-not $command) {
        throw 'ytdownloader is not installed. Run: scoop install ytdownloader'
    }
    Start-Process -FilePath $command.Source | Out-Null
}

$process = Get-YtDownloaderProcess
$started = $false
if (-not $process) {
    Start-YtDownloader
    $started = $true

    $deadline = (Get-Date).AddSeconds(20)
    do {
        Start-Sleep -Milliseconds 250
        $process = Get-YtDownloaderProcess
    } while (-not $process -and (Get-Date) -lt $deadline)
}

if (-not $process -or $process.MainWindowHandle -eq 0) {
    throw 'YTDownloader main window did not appear.'
}
$window = [IntPtr]$process.MainWindowHandle


if ($started) {
    Start-Sleep -Seconds 3
}

$foreground = [YtDlPasteWin]::GetForegroundWindow()
$foregroundThread = 0
if ($foreground -ne [IntPtr]::Zero) {
    [void][YtDlPasteWin]::GetWindowThreadProcessId($foreground, [ref]$foregroundThread)
}
$targetThread = 0
[void][YtDlPasteWin]::GetWindowThreadProcessId($window, [ref]$targetThread)
$currentThread = [YtDlPasteWin]::GetCurrentThreadId()

if ($foregroundThread -ne 0 -and $foregroundThread -ne $currentThread) {
    [void][YtDlPasteWin]::AttachThreadInput($currentThread, $foregroundThread, $true)
}
if ($targetThread -ne 0 -and $targetThread -ne $currentThread) {
    [void][YtDlPasteWin]::AttachThreadInput($currentThread, $targetThread, $true)
}
try {
    if ([YtDlPasteWin]::IsIconic($window)) {
        [void][YtDlPasteWin]::ShowWindow($window, 9)
    }
    [void][YtDlPasteWin]::BringWindowToTop($window)
    [void][YtDlPasteWin]::SetForegroundWindow($window)
}
finally {
    if ($foregroundThread -ne 0 -and $foregroundThread -ne $currentThread) {
        [void][YtDlPasteWin]::AttachThreadInput($currentThread, $foregroundThread, $false)
    }
    if ($targetThread -ne 0 -and $targetThread -ne $currentThread) {
        [void][YtDlPasteWin]::AttachThreadInput($currentThread, $targetThread, $false)
    }
}

Start-Sleep -Milliseconds 300
Set-Clipboard -Value $Url
Start-Sleep -Milliseconds 100

Add-Type -AssemblyName System.Windows.Forms
[System.Windows.Forms.SendKeys]::SendWait('^v')
