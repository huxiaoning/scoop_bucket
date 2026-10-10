# Put a URL on the clipboard and press YTDownloader's global hotkey (Ctrl+Shift+D)
# so ytDownloader starts downloading the URL from the clipboard.
# Starts ytDownloader first when it is not running.
# Requires the global hotkey to be enabled in ytDownloader preferences
# (default accelerator Ctrl+Shift+D); otherwise the keystroke does nothing.
# External Application Button:
#   wt pwsh -NoExit -Command "ytdownloader-caller '[HREF]'"
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Url
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($Url)) {
    throw 'A URL is required.'
}

Set-Clipboard -Value $Url

function Get-YtDownloaderWindow {
    Get-Process -Name 'YTDownloader' -ErrorAction SilentlyContinue |
        Where-Object { $_.MainWindowHandle -ne 0 -and $_.MainWindowTitle -eq 'ytDownloader' } |
        Select-Object -First 1
}

function Start-YtDownloader {
    $command = Get-Command 'ytdownloader' -ErrorAction SilentlyContinue
    if (-not $command) {
        throw 'ytdownloader is not installed. Run: scoop install ytdownloader'
    }
    Start-Process -FilePath $command.Source | Out-Null
}

if (-not (Get-Process -Name 'YTDownloader' -ErrorAction SilentlyContinue)) {
    Start-YtDownloader

    $deadline = (Get-Date).AddSeconds(20)
    do {
        Start-Sleep -Milliseconds 250
        $window = Get-YtDownloaderWindow
    } while (-not $window -and (Get-Date) -lt $deadline)

    if (-not $window) {
        throw 'YTDownloader main window did not appear.'
    }

    # The renderer registers the global hotkey once the main page has loaded.
    Start-Sleep -Seconds 3
}

Add-Type -AssemblyName System.Windows.Forms
[System.Windows.Forms.SendKeys]::SendWait('^+d')
