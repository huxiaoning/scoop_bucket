# Open YTDownloader and put a URL on the clipboard. The user pastes it.
# External Application Button:
#   wt pwsh -NoExit -Command "ytdlopen [HREF]"
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
public static class YtDlOpenWin {
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

$foreground = [YtDlOpenWin]::GetForegroundWindow()
$foregroundThread = 0
if ($foreground -ne [IntPtr]::Zero) {
    [void][YtDlOpenWin]::GetWindowThreadProcessId($foreground, [ref]$foregroundThread)
}
$targetThread = 0
[void][YtDlOpenWin]::GetWindowThreadProcessId($window, [ref]$targetThread)
$currentThread = [YtDlOpenWin]::GetCurrentThreadId()

if ($foregroundThread -ne 0 -and $foregroundThread -ne $currentThread) {
    [void][YtDlOpenWin]::AttachThreadInput($currentThread, $foregroundThread, $true)
}
if ($targetThread -ne 0 -and $targetThread -ne $currentThread) {
    [void][YtDlOpenWin]::AttachThreadInput($currentThread, $targetThread, $true)
}
try {
    if ([YtDlOpenWin]::IsIconic($window)) {
        [void][YtDlOpenWin]::ShowWindow($window, 9)
    }
    [void][YtDlOpenWin]::BringWindowToTop($window)
    [void][YtDlOpenWin]::SetForegroundWindow($window)
}
finally {
    if ($foregroundThread -ne 0 -and $foregroundThread -ne $currentThread) {
        [void][YtDlOpenWin]::AttachThreadInput($currentThread, $foregroundThread, $false)
    }
    if ($targetThread -ne 0 -and $targetThread -ne $currentThread) {
        [void][YtDlOpenWin]::AttachThreadInput($currentThread, $targetThread, $false)
    }
}

Set-Clipboard -Value $Url
