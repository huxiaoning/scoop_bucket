param(
    [Parameter(Mandatory = $true)]
    [string]$Url
)

ytdownloader
Set-Clipboard $Url

Start-Sleep -Seconds 5

$wshell = New-Object -ComObject WScript.Shell
$wshell.SendKeys('^v')


